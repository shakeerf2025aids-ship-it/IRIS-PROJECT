import sys
import os
import torch
import torch.nn as nn
from PIL import Image
import numpy as np

# Adjust paths
sys.path.insert(0, r'C:\Users\SHAKEER F\Documents\IRIS\backend')
from ml.model import load_glaucoma_model
from ml.predict import preprocess_image, predict_with_uncertainty

device = 'cpu'
MODEL_PATH = r'C:\Users\SHAKEER F\Downloads\IRIS DATASETS\models\full_run\best_model_epoch4.pth'

print("=== 1. VERIFY MODEL LOADING ===")
print(f"Model Path: {MODEL_PATH}")
if not os.path.exists(MODEL_PATH):
    print("MODEL NOT FOUND!")
    sys.exit(1)

model = load_glaucoma_model(MODEL_PATH, device=device)
print(f"Model Class: {model.__class__.__name__}")
has_dropout = any(isinstance(m, nn.Dropout) for m in model.modules())
has_bn = any(isinstance(m, nn.BatchNorm2d) for m in model.modules())
print(f"Contains Dropout: {has_dropout}")
print(f"Contains BatchNorm: {has_bn}")

# Check weights
fc_layer = None
for name, module in model.named_modules():
    if isinstance(module, nn.Linear):
        fc_layer = module
        break
if fc_layer:
    w_mean = fc_layer.weight.data.mean().item()
    w_std = fc_layer.weight.data.std().item()
    print(f"FC Weights -> Mean: {w_mean:.4f}, Std: {w_std:.4f}")
else:
    print("FC Layer not found.")

print("\n=== 2. AUDIT PREDICTION LOGIC & BATCHNORM EFFECT ===")
# Create a dummy image
dummy_img = Image.fromarray(np.random.randint(0, 255, (500, 500, 3), dtype=np.uint8))
tensor = preprocess_image(dummy_img).to(device)

print("\nRunning standard evaluation (model.eval()) ...")
model.eval()
with torch.no_grad():
    out_eval = model(tensor)
    if out_eval.ndim > 1 and out_eval.shape[1] == 1:
        out_eval = out_eval.squeeze(1)
    score_eval = torch.sigmoid(out_eval).item()
print(f"Eval Mode Score: {score_eval:.4f}")

print("\nRunning MC Dropout (model.train()) ...")
model.train()
with torch.no_grad():
    out_train = model(tensor)
    if out_train.ndim > 1 and out_train.shape[1] == 1:
        out_train = out_train.squeeze(1)
    score_train = torch.sigmoid(out_train).item()
print(f"Train Mode Score (Batch Size=1): {score_train:.4f}")

print("\nRunning MC Dropout (Only enabling Dropout, freezing BN) ...")
model.eval()
for m in model.modules():
    if m.__class__.__name__.startswith('Dropout'):
        m.train()
with torch.no_grad():
    scores_frozen_bn = []
    for _ in range(5):
        out = model(tensor)
        if out.ndim > 1 and out.shape[1] == 1:
            out = out.squeeze(1)
        scores_frozen_bn.append(torch.sigmoid(out).item())
print(f"Frozen BN Mode Scores: {[round(s, 4) for s in scores_frozen_bn]}")
print(f"Frozen BN Mean: {np.mean(scores_frozen_bn):.4f}")
