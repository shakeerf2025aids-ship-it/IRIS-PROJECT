from PIL import Image
import numpy as np
import cv2
import sys
import os

sys.path.insert(0, r'C:\Users\SHAKEER F\Documents\IRIS\backend')
from validators.fundus_prescreener import prescreener

# Generate test images
images = {}

# 1. Perfect Fundus (reddish circle with black border)
img = np.zeros((500, 500, 3), dtype=np.uint8)
cv2.circle(img, (250, 250), 200, (180, 80, 50), -1)
images['perfect_fundus'] = Image.fromarray(img)

# 2. Cropped Hospital Export (no black border, rectangular 16:9, red)
img = np.full((1080, 1920, 3), [160, 70, 50], dtype=np.uint8)
images['hospital_crop'] = Image.fromarray(img)

# 3. Mobile Transferred (compressed, poor AWB, less red dominance)
img = np.full((800, 800, 3), [130, 128, 120], dtype=np.uint8)
cv2.circle(img, (400, 400), 380, (140, 130, 110), -1)
images['mobile_awb'] = Image.fromarray(img)

# 4. Laptop Photo (bluish/white screen)
img = np.full((1080, 1920, 3), [200, 220, 240], dtype=np.uint8)
images['laptop_photo'] = Image.fromarray(img)

# 5. Screenshot (white background)
img = np.full((1080, 1920, 3), [255, 255, 255], dtype=np.uint8)
images['screenshot'] = Image.fromarray(img)

# 6. Selfie (skin tone)
img = np.full((1920, 1080, 3), [210, 170, 140], dtype=np.uint8)
images['selfie'] = Image.fromarray(img)

print('=== PRESCREENER AUDIT ===\n')

results = {}
for name, pil_img in images.items():
    res = prescreener.check(pil_img)
    print(f'## REJECTION REPORT: {name.upper()}')
    print(f"is_fundus: {res.get('is_fundus')}")
    print(f"confidence: {res.get('confidence')}")
    print(f"reason: {res.get('reason')}")
    print('Feature Values & Thresholds:')
    for k, v in res.get('checks', {}).items():
        print(f'  {k}: {v}')
    print('-'*40)
