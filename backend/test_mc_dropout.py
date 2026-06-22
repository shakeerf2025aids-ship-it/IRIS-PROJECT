import sys
import os
import torch
from PIL import Image
import numpy as np

sys.path.insert(0, r'C:\Users\SHAKEER F\Documents\IRIS\backend')
from ml.model import load_glaucoma_model
from ml.predict import preprocess_image, predict_with_uncertainty

device = 'cpu'
MODEL_PATH = r'C:\Users\SHAKEER F\Downloads\IRIS DATASETS\models\full_run\best_model_epoch4.pth'
DATA_DIR = r'C:\Users\SHAKEER F\Downloads\IRIS DATASETS'

print("Loading model...")
model = load_glaucoma_model(MODEL_PATH, device=device)

# Find one normal and one glaucoma image
normal_dir = os.path.join(DATA_DIR, "val", "0_Normal")
glaucoma_dir = os.path.join(DATA_DIR, "val", "1_Glaucoma")

normal_img_path = None
if os.path.exists(normal_dir):
    for f in os.listdir(normal_dir):
        if f.endswith((".jpg", ".jpeg", ".png")):
            normal_img_path = os.path.join(normal_dir, f)
            break

glaucoma_img_path = None
if os.path.exists(glaucoma_dir):
    for f in os.listdir(glaucoma_dir):
        if f.endswith((".jpg", ".jpeg", ".png")):
            glaucoma_img_path = os.path.join(glaucoma_dir, f)
            break

def generate_synthetic(is_glaucoma=False):
    # Just creating something so the code runs if the dataset is missing.
    # We will use red channels heavily to pretend it's a fundus.
    img = np.zeros((224, 224, 3), dtype=np.uint8)
    img[:, :, 0] = np.random.randint(100, 200, (224, 224))
    if is_glaucoma:
        # maybe add a brighter disk
        img[100:150, 100:150, 0] = 250
    return Image.fromarray(img)

def run_test(name, path, is_glaucoma):
    print(f"\n--- Testing {name} ---")
    if path and os.path.exists(path):
        print(f"Using image: {path}")
        img = Image.open(path)
    else:
        print("Real image not found, using synthetic.")
        img = generate_synthetic(is_glaucoma)
    
    tensor = preprocess_image(img).to(device)
    
    # Old logic simulation
    print("Old Logic Simulation (model.train()):")
    model.train()
    scores_old = []
    with torch.no_grad():
        for _ in range(20):
            out = model(tensor)
            if out.ndim > 1 and out.shape[1] == 1:
                out = out.squeeze(1)
            scores_old.append(torch.sigmoid(out).item())
    old_mean = np.mean(scores_old)
    old_std = np.std(scores_old)
    print(f"  Old Mean Prob: {old_mean:.4f}")
    print(f"  Old Uncertainty: {old_std:.4f}")
    
    # New logic
    print("New Logic (predict_with_uncertainty):")
    result = predict_with_uncertainty(model, tensor, device=device, n_passes=20)
    print(f"  New Mean Prob: {result['confidence_score']:.4f}")
    print(f"  New Uncertainty: {result['uncertainty']:.4f}")
    print(f"  Predicted Class: {result['predicted_class']} ({result['risk_status']})")
    
run_test("Normal Image", normal_img_path, False)
run_test("Glaucoma Image", glaucoma_img_path, True)
