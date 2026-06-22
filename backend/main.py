from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import io
import uuid
import hashlib
import torch
import os
import sys
import time
import logging
from datetime import datetime, timezone
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials, firestore

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Always resolve paths relative to this file, not the CWD ──────────────────
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BACKEND_DIR)

# ── Firebase Admin SDK ────────────────────────────────────────────────────────
try:
    firebase_admin.get_app()
except ValueError:
    try:
        project_id = os.getenv('FIREBASE_PROJECT_ID', 'iris-glaucoma')
        # Resolve service account path relative to this file — fixes the
        # "file not found" bug when uvicorn is started from the project root.
        cred_path = os.getenv(
            'GOOGLE_APPLICATION_CREDENTIALS',
            os.path.join(BACKEND_DIR, 'serviceAccountKey.json'),
        )
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred, options={'projectId': project_id})
            logger.info('Firebase Admin SDK initialized with service account credentials.')
        else:
            logger.warning(f'Service account not found at {cred_path}. Using ADC.')
            firebase_admin.initialize_app(options={'projectId': project_id})
    except Exception as e:
        logger.warning(f'Firebase Admin SDK init warning: {e}')

from ml.model import load_glaucoma_model
from ml.predict import preprocess_image, predict_with_uncertainty
from validators.fundus_prescreener import prescreener
from ml.quality_assessor import quality_assessor

app = FastAPI(title='IRIS Prediction API — Medical Screening System')

# ── CORS ──────────────────────────────────────────────────────────────────────
CORS_ORIGINS_ENV = os.getenv('CORS_ORIGINS', '*')
if CORS_ORIGINS_ENV == '*':
    allow_origins = ['*']
else:
    allow_origins = [o.strip() for o in CORS_ORIGINS_ENV.split(',') if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=os.getenv('CORS_METHODS', '*').split(','),
    allow_headers=os.getenv('CORS_HEADERS', '*').split(','),
)

security = HTTPBearer(auto_error=False)

# ── Device and model configuration ───────────────────────────────────────────
device = os.getenv('DEVICE', 'cuda' if torch.cuda.is_available() else 'cpu')
if device == 'auto':
    device = 'cuda' if torch.cuda.is_available() else 'cpu'

MODEL_PATH = os.getenv(
    'MODEL_PATH',
    r'C:\Users\SHAKEER F\Downloads\IRIS DATASETS\models\full_run\best_model_epoch4.pth',
)
MAX_FILE_SIZE_MB = int(os.getenv('MAX_FILE_SIZE_MB', '10'))
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024
MC_PASSES = int(os.getenv('MC_DROPOUT_PASSES', '20'))

model = None
db = None


@app.on_event('startup')
def startup():
    global model, db
    if not os.path.exists(MODEL_PATH):
        raise RuntimeError(f'Trained model not found at {MODEL_PATH}')
    model = load_glaucoma_model(MODEL_PATH, device=device)
    logger.info(f'Glaucoma model loaded on {device}.')
    try:
        db = firestore.client()
        logger.info('Firestore client initialized for audit logging.')
    except Exception as e:
        logger.warning(f'Firestore client init failed (audit logging disabled): {e}')
        db = None


# ── Authentication ────────────────────────────────────────────────────────────
def verify_token(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> dict:
    auth_enabled = os.getenv('AUTH_ENABLED', 'true').lower() == 'true'

    if not auth_enabled:
        return {'uid': 'development_user', 'email': 'dev@example.com'}

    if credentials is None:
        logger.warning('AUTH: No Authorization header received.')
        raise HTTPException(
            status_code=401,
            detail='Authorization header missing. Send: Authorization: Bearer <token>',
        )

    token = credentials.credentials
    try:
        decoded_token = firebase_auth.verify_id_token(token)
        logger.info(f"AUTH: Token verified for UID: {decoded_token.get('uid')}")
        return decoded_token
    except Exception as e:
        print('==== FIREBASE TOKEN DEBUG ====')
        print('Exception Type:', type(e).__name__)
        print('Exception:', repr(e))
        print('Exception String:', str(e))
        print('==============================')
        logger.warning(f'AUTH: Token verification failed: {e}')
        raise HTTPException(
            status_code=401,
            detail=f'Invalid or expired authentication token. Error: {str(e)}',
        )


# ── Audit logging ─────────────────────────────────────────────────────────────
def _write_audit_log(
    audit_id: str,
    user_id: str,
    image_hash: str,
    result: dict,
) -> None:
    """Write prediction audit record to Firestore. Fire-and-forget; never raises."""
    if db is None:
        return
    try:
        doc = {
            'audit_id': audit_id,
            'user_id': user_id,
            'image_hash_sha256': image_hash,
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'predicted_class': result.get('predicted_class'),
            'confidence_score': result.get('confidence_score'),
            'uncertainty': result.get('uncertainty'),
            'risk_status': result.get('risk_status'),
            'confidence_level': result.get('confidence_level'),
            'show_diagnosis': result.get('show_diagnosis'),
            'fundus_confidence': result.get('_fundus_confidence'),
            'quality_score': result.get('_quality_score'),
            'mc_passes': result.get('mc_passes'),
        }
        db.collection('audit_logs').document(audit_id).set(doc)
        logger.info(f'Audit log written: {audit_id}')
    except Exception as e:
        logger.warning(f'Audit log write failed (non-fatal): {e}')


# ── /predict endpoint ─────────────────────────────────────────────────────────
@app.post('/predict')
async def predict_endpoint(
    image: UploadFile = File(...),
    user_info: dict = Depends(verify_token),
):
    audit_id = str(uuid.uuid4())
    t0 = time.time()
    logger.info(f'[{audit_id}] /predict request received')

    # ── GATE 1: File-level validation ──────────────────────────────────────
    if not image.content_type.startswith('image/'):
        logger.error(f'[{audit_id}] Invalid MIME type: {image.content_type}')
        raise HTTPException(status_code=400, detail='File provided is not an image.')

    contents = await image.read()
    image_hash = hashlib.sha256(contents).hexdigest()
    logger.info(
        f'[{audit_id}] File: {image.filename}, '
        f'size: {len(contents)} bytes, '
        f'sha256: {image_hash[:16]}...'
    )

    if len(contents) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f'File size exceeds the {MAX_FILE_SIZE_MB} MB limit.',
        )

    try:
        pil_image = Image.open(io.BytesIO(contents))
        pil_image.verify()
        pil_image = Image.open(io.BytesIO(contents)).convert('RGB')
    except Exception as e:
        logger.error(f'[{audit_id}] PIL decode failed: {e}')
        raise HTTPException(status_code=400, detail='Invalid or corrupted image file.')

    logger.info(
        f'[{audit_id}] Image decoded: {pil_image.size[0]}x{pil_image.size[1]}, '
        f'+{time.time() - t0:.3f}s'
    )

    # ── GATE 2: Traditional CV fundus pre-screen ───────────────────────────
    try:
        fundus_result = prescreener.check(pil_image)
    except Exception as e:
        logger.error(f'[{audit_id}] Fundus prescreener error: {e}')
        # Fail open on prescreener crash — do not block inference
        fundus_result = {
            'is_fundus': True,
            'confidence': 1.0,
            'reason': 'prescreener_error',
            'checks': {},
        }

    logger.info(
        f'[{audit_id}] Fundus check: is_fundus={fundus_result["is_fundus"]}, '
        f'confidence={fundus_result["confidence"]}'
    )

    # ── GATE 3: Image quality assessment ───────────────────────────────────
    try:
        quality_result = quality_assessor.assess(pil_image)
    except Exception as e:
        logger.error(f'[{audit_id}] Quality assessor error: {e}')
        quality_result = {'quality': 'good', 'score': 1.0, 'reasons': [], 'diagnostics': {}}

    logger.info(
        f'[{audit_id}] Quality: {quality_result["quality"]}, '
        f'score={quality_result["score"]}'
    )

    # ── GATE 4: Validation Enforcement ────────────────────────
    if not fundus_result['is_fundus']:
        logger.warning(f'[{audit_id}] REJECTED: Not a fundus image. Reason: {fundus_result["reason"]}')
        raise HTTPException(
            status_code=422,
            detail={
                'error': 'not_fundus',
                'message': 'Invalid Image Detected. Please upload a clear retinal fundus image for glaucoma analysis.',
                'reason': fundus_result['reason'],
                'fundus_confidence': fundus_result['confidence'],
                'checks': fundus_result['checks'],
            },
        )

    quality_warning = None
    if quality_result['quality'] == 'poor':
        logger.warning(f'[{audit_id}] DEMO WARNING: Poor quality. Score: {quality_result["score"]}, Reasons: {quality_result["reasons"]}')
        quality_warning = "Low image quality. Prediction may be less reliable."

    # ── GATE 4: MC Dropout glaucoma inference ─────────────────────────────
    try:
        tensor = preprocess_image(pil_image)
        result = predict_with_uncertainty(
            model, tensor, device=device, n_passes=MC_PASSES
        )
    except Exception as e:
        logger.error(f'[{audit_id}] Inference error: {e}')
        raise HTTPException(status_code=500, detail=f'Inference error: {str(e)}')

    logger.info(
        f'[{audit_id}] Inference: class={result["predicted_class"]}, '
        f'score={result["confidence_score"]}, '
        f'uncertainty={result["uncertainty"]}, '
        f'level={result["confidence_level"]}, '
        f'+{time.time() - t0:.3f}s'
    )

    # ── GATE 5: Uncertainty / borderline gate ──────────────────────────────
    result['_fundus_confidence'] = fundus_result['confidence']
    result['_quality_score'] = quality_result['score']

    if not result['show_diagnosis']:
        level = result['confidence_level']
        logger.warning(
            f'[{audit_id}] Prediction suppressed ({level}): '
            f'uncertainty={result["uncertainty"]}'
        )
        _write_audit_log(audit_id, user_info.get('uid', 'unknown'), image_hash, result)
        raise HTTPException(
            status_code=422,
            detail={
                'error': level,
                'message': result['confidence_action'],
                'confidence_score': result['confidence_score'],
                'uncertainty': result['uncertainty'],
                'confidence_level': level,
            },
        )

    # ── Audit log and assemble final response ─────────────────────────────
    _write_audit_log(audit_id, user_info.get('uid', 'unknown'), image_hash, result)

    response_payload = {
        'audit_id': audit_id,
        'predicted_class': result['predicted_class'],
        'confidence_score': result['confidence_score'],
        'uncertainty': result['uncertainty'],
        'risk_status': result['risk_status'],
        'confidence_level': result['confidence_level'],
        'confidence_label': result['confidence_label'],
        'confidence_action': result['confidence_action'],
        'show_diagnosis': result['show_diagnosis'],
        'warning': quality_warning,
        'fundus_verification': {
            'is_fundus': fundus_result['is_fundus'],
            'confidence': fundus_result['confidence'],
        },
        'quality': {
            'quality': quality_result['quality'],
            'score': quality_result['score'],
        },
        'disclaimer': (
            'FOR RESEARCH AND SCREENING USE ONLY. NOT A MEDICAL DIAGNOSIS.'
        ),
        'processing_time_ms': round((time.time() - t0) * 1000),
    }

    logger.info(
        f'[{audit_id}] Response: {result["risk_status"]} '
        f'({result["confidence_level"]}), '
        f'{response_payload["processing_time_ms"]} ms'
    )
    return JSONResponse(content=response_payload)


@app.get('/health')
def health_check():
    return {
        'status': 'healthy',
        'model_loaded': model is not None,
        'firestore_connected': db is not None,
    }
