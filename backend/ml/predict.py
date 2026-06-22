import albumentations as A
from albumentations.pytorch import ToTensorV2
from PIL import Image
import numpy as np
import torch

IMAGE_SIZE = 224


def get_inference_transform():
    return A.Compose([
        A.Resize(height=IMAGE_SIZE, width=IMAGE_SIZE, p=1.0),
        A.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
        ToTensorV2(),
    ])


def preprocess_image(image: Image.Image):
    image = image.convert('RGB')
    image_np = np.array(image)
    transform = get_inference_transform()
    augmented = transform(image=image_np)
    tensor = augmented['image']
    return tensor.unsqueeze(0)


def _classify_confidence(mean_score: float, uncertainty: float) -> dict:
    """
    Medical-grade confidence classification.
    Returns level, label, clinical action text, and show_diagnosis flag.

    Decision rules (in priority order):
      1. High internal uncertainty (MC Dropout std > 0.15) → Uncertain
      2. Score in borderline zone (0.40–0.60) → Borderline
      3. Absolute distance from 0.5 boundary determines tier
    """
    # High MC Dropout std → model is internally contradictory → uncertain
    if uncertainty > 0.15:
        return {
            'level': 'uncertain',
            'label': 'Uncertain',
            'action': (
                'Model could not reach a reliable conclusion. '
                'Please refer to an ophthalmologist for examination.'
            ),
            'show_diagnosis': False,
        }

    # Score too close to the 0.5 boundary → borderline
    if 0.40 <= mean_score <= 0.60:
        return {
            'level': 'borderline',
            'label': 'Borderline',
            'action': (
                'Result is borderline. A clinical fundus examination '
                'by an ophthalmologist is required.'
            ),
            'show_diagnosis': False,
        }

    # Absolute distance from the decision boundary
    abs_score = mean_score if mean_score > 0.5 else (1.0 - mean_score)

    if abs_score < 0.70:
        return {
            'level': 'low',
            'label': 'Low Confidence',
            'action': 'Seek ophthalmologist confirmation before any decision.',
            'show_diagnosis': True,
        }
    elif abs_score < 0.85:
        return {
            'level': 'moderate',
            'label': 'Moderate Confidence',
            'action': 'Clinical follow-up and ophthalmologist review is recommended.',
            'show_diagnosis': True,
        }
    elif abs_score < 0.95:
        return {
            'level': 'high',
            'label': 'High Confidence',
            'action': 'Standard clinical review by an ophthalmologist is recommended.',
            'show_diagnosis': True,
        }
    else:
        return {
            'level': 'very_high',
            'label': 'Very High Confidence',
            'action': (
                'Very high confidence result. '
                'Mandatory clinician verification is required before any action.'
            ),
            'show_diagnosis': True,
        }


import logging

logger = logging.getLogger(__name__)

def enable_mc_dropout(model):
    dropout_count = 0
    bn_count = 0
    for module in model.modules():
        if isinstance(module, torch.nn.Dropout):
            module.train()
            dropout_count += 1
        elif isinstance(module, (torch.nn.BatchNorm1d, torch.nn.BatchNorm2d, torch.nn.BatchNorm3d)):
            bn_count += 1
    logger.info(f"MC Dropout debug: Activated {dropout_count} Dropout layers. Frozen {bn_count} BatchNorm layers.")

def predict_with_uncertainty(
    model,
    image_tensor,
    device: str = 'cpu',
    n_passes: int = 20,
) -> dict:
    """
    Monte Carlo Dropout inference.

    Enables dropout layers at inference time and runs n_passes forward passes.
    High standard deviation (uncertainty > 0.15) indicates an out-of-distribution
    or ambiguous input — the result is flagged as 'uncertain' and no diagnosis
    is returned.

    Args:
        model:        Loaded EfficientNet-B0 glaucoma model.
        image_tensor: Preprocessed image tensor (1, C, H, W).
        device:       'cpu' or 'cuda'.
        n_passes:     Number of stochastic forward passes (default 20).

    Returns:
        {
          'predicted_class':   int  (-1 = uncertain/borderline, 0 = Normal, 1 = Glaucoma),
          'confidence_score':  float,
          'uncertainty':       float (MC Dropout std dev across n_passes),
          'risk_status':       str,
          'confidence_level':  str,
          'confidence_label':  str,
          'confidence_action': str,
          'show_diagnosis':    bool,
          'mc_passes':         int,
        }
    """
    image_tensor = image_tensor.to(device)
    scores = []

    model.eval()
    enable_mc_dropout(model)
    try:
        with torch.no_grad():
            for _ in range(n_passes):
                out = model(image_tensor)
                if out.ndim > 1 and out.shape[1] == 1:
                    out = out.squeeze(1)
                score = torch.sigmoid(out).item()
                scores.append(score)
    finally:
        model.eval()

    mean_score = float(np.mean(scores))
    uncertainty = float(np.std(scores))

    confidence_info = _classify_confidence(mean_score, uncertainty)

    if confidence_info['show_diagnosis']:
        predicted_class = 1 if mean_score > 0.5 else 0
        risk_status = 'Glaucoma' if predicted_class == 1 else 'Normal'
    else:
        predicted_class = -1
        risk_status = confidence_info['level'].capitalize()

    return {
        'predicted_class': predicted_class,
        'confidence_score': round(mean_score, 4),
        'uncertainty': round(uncertainty, 4),
        'risk_status': risk_status,
        'confidence_level': confidence_info['level'],
        'confidence_label': confidence_info['label'],
        'confidence_action': confidence_info['action'],
        'show_diagnosis': confidence_info['show_diagnosis'],
        'mc_passes': n_passes,
    }


def predict(model, image_tensor, device: str = 'cpu') -> dict:
    """Single-pass wrapper kept for backward compatibility. Use predict_with_uncertainty() in production."""
    return predict_with_uncertainty(model, image_tensor, device=device, n_passes=1)
