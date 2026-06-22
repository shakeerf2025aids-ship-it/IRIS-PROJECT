"""
FastAPI Backend for IRIS Glaucoma Detection
Production-ready server with configuration from environment variables
"""
import os
import sys
import time
import logging
import json
from pathlib import Path
from typing import Optional

import torch
from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import io
from dotenv import load_dotenv
from pydantic_settings import BaseSettings

try:
    import firebase_admin
    from firebase_admin import auth as firebase_auth
    from firebase_admin import credentials as firebase_credentials
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False
    firebase_admin = None
    firebase_auth = None

# Load environment variables
load_dotenv()

# Add current dir to sys path for absolute imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ml.model import load_glaucoma_model
from ml.predict import preprocess_image, predict


# ============================================================================
# Configuration Management
# ============================================================================

class Settings(BaseSettings):
    """Application settings from environment variables"""
    
    # Environment
    environment: str = os.getenv("ENVIRONMENT", "development")
    
    # API
    api_host: str = os.getenv("API_HOST", "0.0.0.0")
    api_port: int = int(os.getenv("API_PORT", 8000))
    api_workers: int = int(os.getenv("API_WORKERS", 1))
    
    # CORS
    cors_origins: str = os.getenv("CORS_ORIGINS", "http://localhost:8000")
    cors_credentials: bool = os.getenv("CORS_CREDENTIALS", "true").lower() == "true"
    cors_methods: list = ["*"]
    cors_headers: list = ["*"]
    
    # Model
    model_path: str = os.getenv("MODEL_PATH", "ml/models/best_model_epoch4.pth")
    device: str = os.getenv("DEVICE", "auto")
    
    # Logging
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
    log_format: str = os.getenv("LOG_FORMAT", "json")  # json or text
    
    # Authentication
    auth_enabled: bool = os.getenv("AUTH_ENABLED", "true").lower() == "true"
    auth_provider: str = os.getenv("AUTH_PROVIDER", "firebase")
    
    # Performance
    inference_timeout_seconds: int = int(os.getenv("INFERENCE_TIMEOUT_SECONDS", 30))
    max_file_size_mb: int = int(os.getenv("MAX_FILE_SIZE_MB", 50))
    
    class Config:
        env_file = ".env"
        case_sensitive = False


# ============================================================================
# Logging Setup
# ============================================================================

def setup_logging(settings: Settings) -> logging.Logger:
    """Configure logging based on settings"""
    
    class JSONFormatter(logging.Formatter):
        """JSON formatter for structured logging"""
        def format(self, record):
            log_obj = {
                "timestamp": self.formatTime(record),
                "level": record.levelname,
                "logger": record.name,
                "message": record.getMessage(),
                "module": record.module,
                "function": record.funcName,
                "line": record.lineno,
            }
            if record.exc_info:
                log_obj["exception"] = self.formatException(record.exc_info)
            return json.dumps(log_obj)
    
    logger = logging.getLogger("iris_api")
    logger.setLevel(getattr(logging, settings.log_level))
    
    # Console handler
    handler = logging.StreamHandler()
    
    if settings.log_format == "json":
        formatter = JSONFormatter()
    else:
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
    
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    
    return logger


# Initialize settings and logger
settings = Settings()
logger = setup_logging(settings)

logger.info(f"IRIS Glaucoma API starting in {settings.environment} mode")
logger.info(f"Model path: {settings.model_path}")
logger.info(f"Device: {settings.device}")


# ============================================================================
# Device Configuration
# ============================================================================

def get_device() -> str:
    """Determine which device to use for inference"""
    if settings.device == "auto":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    else:
        device = settings.device
    
    if device == "cuda" and not torch.cuda.is_available():
        logger.warning("CUDA requested but not available, falling back to CPU")
        device = "cpu"
    
    return device


# ============================================================================
# Model Loading
# ============================================================================

def load_model_from_path(model_path: str, device: str):
    """Load model from local file path"""
    if not os.path.exists(model_path):
        raise RuntimeError(
            f"Model file not found at {model_path}. "
            f"Please ensure the model is available at this path."
        )
    
    logger.info(f"Loading model from {model_path}")
    model = load_glaucoma_model(model_path, device=device)
    logger.info(f"Model loaded successfully on {device}")
    return model


def resolve_model_path() -> str:
    """Resolve the actual model path (local or remote)"""
    
    # Check if it's a relative path (local file)
    if not settings.model_path.startswith(("s3://", "hf://", "http")):
        # Convert to absolute path relative to backend directory
        backend_dir = os.path.dirname(os.path.abspath(__file__))
        abs_path = os.path.join(backend_dir, settings.model_path)
        return abs_path
    
    # For remote paths, you would implement S3, HuggingFace, etc.
    # For now, we only support local files
    raise NotImplementedError(
        f"Remote model paths not yet implemented. Use local file paths."
    )


# ============================================================================
# FastAPI Application
# ============================================================================

app = FastAPI(
    title="IRIS Glaucoma Prediction API",
    description="ML-powered glaucoma detection system",
    version="1.0.0",
)

# Add CORS middleware
cors_origins = [origin.strip() for origin in settings.cors_origins.split(",")]
logger.info(f"CORS origins configured: {cors_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins if settings.environment != "production" else ["https://your-app.com"],
    allow_credentials=settings.cors_credentials,
    allow_methods=settings.cors_methods,
    allow_headers=settings.cors_headers,
)

# Security
security = HTTPBearer(auto_error=False)

# Global model state
device = get_device()
model = None


# ============================================================================
# Startup/Shutdown Events
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Initialize model and Firebase on application startup"""
    global model
    try:
        logger.info("Starting up IRIS API...")
        
        # Initialize Firebase if available
        if FIREBASE_AVAILABLE and settings.auth_provider == "firebase":
            try:
                if not firebase_admin._apps:
                    # Try to initialize Firebase from environment or use default credentials
                    firebase_admin.initialize_app()
                logger.info("✓ Firebase initialized successfully")
            except Exception as e:
                logger.warning(f"Firebase initialization failed (will use mock token validation): {e}")
        
        model_path = resolve_model_path()
        model = load_model_from_path(model_path, device)
        logger.info("✓ Model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model during startup: {e}", exc_info=True)
        raise


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down IRIS API...")
    global model
    if model is not None:
        del model
        torch.cuda.empty_cache()
    logger.info("✓ Cleanup completed")


# ============================================================================
# Authentication
# ============================================================================

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> str:
    """Verify authentication token"""
    
    if not settings.auth_enabled:
        return "anonymous"
    
    # Handle missing Authorization header (auto_error=False means credentials can be None)
    if credentials is None:
        logger.warning("AUTH: No Authorization header received")
        raise HTTPException(
            status_code=401,
            detail="Authorization header missing. Send: Authorization: Bearer <token>"
        )
    
    token = credentials.credentials
    logger.info(f"AUTH: Token received, length={len(token)}, prefix={token[:20]}...")
    
    # Development mode: accept any non-empty token
    if settings.environment == "development":
        if not token or token == "invalid":
            raise HTTPException(
                status_code=401,
                detail="Invalid or missing authentication token"
            )
        logger.info(f"AUTH: Development mode — token accepted ✓")
        return token
    
    # Production mode: implement proper JWT validation
    if settings.auth_provider == "firebase":
        # Verify Firebase JWT token
        if not FIREBASE_AVAILABLE or firebase_auth is None:
            logger.warning("Firebase not available, falling back to mock validation")
            if not token or token == "invalid":
                raise HTTPException(
                    status_code=401,
                    detail="Invalid or missing authentication token"
                )
            return token
        
        try:
            # Verify Firebase ID token
            decoded_token = firebase_auth.verify_id_token(token)
            uid = decoded_token.get('uid')
            
            if not uid:
                logger.warning("Firebase token decoded but no UID found")
                raise HTTPException(
                    status_code=401,
                    detail="Invalid authentication token (no user ID)"
                )
            
            logger.info(f"Token verified successfully for user: {uid}")
            return uid
            
        except firebase_auth.InvalidIdTokenError as e:
            logger.warning(f"Invalid Firebase ID token: {e}")
            raise HTTPException(
                status_code=401,
                detail="Invalid authentication token"
            )
        except firebase_auth.ExpiredIdTokenError as e:
            logger.warning(f"Expired Firebase ID token: {e}")
            raise HTTPException(
                status_code=401,
                detail="Authentication token expired"
            )
        except firebase_auth.RevokedIdTokenError as e:
            logger.warning(f"Revoked Firebase ID token: {e}")
            raise HTTPException(
                status_code=401,
                detail="Authentication token revoked"
            )
        except Exception as e:
            logger.error(f"Firebase token verification error: {e}", exc_info=True)
            raise HTTPException(
                status_code=401,
                detail="Authentication verification failed"
            )
    
    raise HTTPException(status_code=401, detail="Authentication provider not configured")


# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "environment": settings.environment,
        "model_loaded": model is not None,
        "device": device,
    }


@app.post("/predict")
async def predict_endpoint(
    image: UploadFile = File(...),
    token: str = Depends(verify_token)
):
    """
    Predict glaucoma risk from eye image
    
    Returns:
        {
            "predicted_class": 0 or 1,
            "confidence_score": 0.0-1.0,
            "risk_status": "Normal" or "Glaucoma",
            "processing_time_ms": float
        }
    """
    
    if model is None:
        logger.error("Model not loaded")
        raise HTTPException(
            status_code=500,
            detail="Model not available. Service is starting up."
        )
    
    start_time = time.time()
    logger.info(f"Received prediction request from token: {token[:10]}...")
    
    try:
        # Validate content type
        if not image.content_type or not image.content_type.startswith("image/"):
            logger.warning(f"Invalid content type: {image.content_type}")
            raise HTTPException(
                status_code=400,
                detail=f"Expected image file, got {image.content_type}"
            )
        
        # Validate file size
        image_data = await image.read()
        file_size_mb = len(image_data) / (1024 * 1024)
        if file_size_mb > settings.max_file_size_mb:
            logger.warning(f"File too large: {file_size_mb:.2f}MB")
            raise HTTPException(
                status_code=413,
                detail=f"File size {file_size_mb:.2f}MB exceeds limit of {settings.max_file_size_mb}MB"
            )
        
        read_time = time.time() - start_time
        logger.info(f"Image read: {len(image_data)} bytes in {read_time:.3f}s")
        
        # Decode image
        try:
            pil_image = Image.open(io.BytesIO(image_data))
        except Exception as e:
            logger.error(f"Failed to decode image: {e}")
            raise HTTPException(
                status_code=400,
                detail="Invalid or corrupted image file"
            )
        
        decode_time = time.time() - start_time
        logger.info(f"Image decoded in {decode_time:.3f}s")
        
        # Preprocess
        try:
            tensor = preprocess_image(pil_image)
        except Exception as e:
            logger.error(f"Image preprocessing failed: {e}")
            raise HTTPException(
                status_code=400,
                detail="Image preprocessing failed"
            )
        
        preprocess_time = time.time() - start_time
        logger.info(f"Image preprocessed in {preprocess_time:.3f}s")
        
        # Inference
        try:
            result = predict(model, tensor, device=device)
        except Exception as e:
            logger.error(f"Model inference failed: {e}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail="Model inference failed"
            )
        
        inference_time = time.time() - start_time
        
        # Add processing time
        result["processing_time_ms"] = round(inference_time * 1000, 2)
        
        logger.info(
            f"Prediction complete in {inference_time:.3f}s: "
            f"class={result['predicted_class']}, "
            f"confidence={result['confidence_score']:.3f}, "
            f"status={result['risk_status']}"
        )
        
        return JSONResponse(content=result)
    
    except HTTPException:
        raise
    
    except Exception as e:
        elapsed_time = time.time() - start_time
        logger.error(
            f"Unexpected error during prediction (took {elapsed_time:.3f}s): {e}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred during prediction"
        )


# ============================================================================
# Informational Endpoints
# ============================================================================

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "name": "IRIS Glaucoma Prediction API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
        "predict": "/predict",
    }


@app.get("/info")
async def info():
    """Get API information and configuration"""
    return {
        "environment": settings.environment,
        "device": device,
        "model_path": settings.model_path if settings.environment == "development" else "***",
        "model_loaded": model is not None,
        "max_file_size_mb": settings.max_file_size_mb,
        "cors_origins": cors_origins if settings.environment == "development" else ["configured"],
    }


# ============================================================================
# Error Handlers
# ============================================================================

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Global exception handler"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "error": str(exc) if settings.environment == "development" else None,
        }
    )


if __name__ == "__main__":
    import uvicorn
    
    logger.info(f"Starting Uvicorn on {settings.api_host}:{settings.api_port}")
    
    uvicorn.run(
        app,
        host=settings.api_host,
        port=settings.api_port,
        workers=settings.api_workers if settings.environment == "production" else 1,
        log_level=settings.log_level.lower(),
    )
