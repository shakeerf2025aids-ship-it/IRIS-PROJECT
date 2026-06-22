import torch

def build_model(device='cpu', pretrained=False):
    try:
        from torchvision.models import efficientnet_b0, EfficientNet_B0_Weights
        weights = EfficientNet_B0_Weights.IMAGENET1K_V1 if pretrained else None
        model = efficientnet_b0(weights=weights)
        in_features = model.classifier[1].in_features
        import torch.nn as nn
        model.classifier = nn.Sequential(nn.Dropout(p=0.2), nn.Linear(in_features, 1))
        model.to(device)
        return model
    except Exception as e:
        raise RuntimeError('Cannot build EfficientNet-B0.') from e

def load_glaucoma_model(model_path: str, device='cpu'):
    model = build_model(device=device, pretrained=False)
    state = torch.load(model_path, map_location=device)
    if 'model_state' in state:
        model.load_state_dict(state['model_state'])
    else:
        model.load_state_dict(state)
    model.eval()
    return model
