import cv2
import numpy as np
from PIL import Image
from typing import List


class ImageQualityAssessor:
    """
    Assesses retinal fundus image quality before glaucoma inference.
    Rejects blurry, dark, overexposed, low-contrast, and screenshot-like images.
    """

    BLUR_THRESHOLD = 80.0           # Laplacian variance; below = blurry
    DARK_THRESHOLD = 35.0           # Mean brightness; below = too dark
    BRIGHT_THRESHOLD = 225.0        # Mean brightness; above = overexposed
    CONTRAST_THRESHOLD = 20.0       # Pixel std dev; below = low contrast
    MIN_DIMENSION = 100             # Minimum width or height in pixels
    SCREENSHOT_ENTROPY_MAX = 4.2    # Shannon entropy; screenshots are structured → low
    GOOD_SCORE_THRESHOLD = 0.55     # Weighted score above this = 'good'

    def assess(self, pil_image: Image.Image) -> dict:
        """
        Args:
            pil_image: PIL Image
        Returns:
            {
              'quality': 'good' | 'poor',
              'score': float (0–1),
              'reasons': List[str],
              'diagnostics': dict
            }
        """
        image = pil_image.convert('RGB')
        img_np = np.array(image, dtype=np.uint8)
        h, w = img_np.shape[:2]

        reasons: List[str] = []
        penalty = 0.0

        # ── Check 1: Minimum resolution ──────────────────────────────────────
        if h < self.MIN_DIMENSION or w < self.MIN_DIMENSION:
            reasons.append(
                f'Image resolution too low ({w}x{h} px). '
                f'Minimum is {self.MIN_DIMENSION}x{self.MIN_DIMENSION} px.'
            )
            penalty += 0.50

        # ── Check 2: Blur (Laplacian variance) ───────────────────────────────
        gray = cv2.cvtColor(img_np, cv2.COLOR_RGB2GRAY)
        blur_score = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        if blur_score < self.BLUR_THRESHOLD:
            reasons.append(
                f'Image is blurry (sharpness score: {blur_score:.1f}; '
                f'required >= {self.BLUR_THRESHOLD}).'
            )
            penalty += 0.30

        # ── Check 3: Brightness ───────────────────────────────────────────────
        mean_brightness = float(gray.mean())
        if mean_brightness < self.DARK_THRESHOLD:
            reasons.append(
                f'Image is too dark (brightness: {mean_brightness:.1f}; '
                f'required >= {self.DARK_THRESHOLD}).'
            )
            penalty += 0.25
        elif mean_brightness > self.BRIGHT_THRESHOLD:
            reasons.append(
                f'Image is overexposed (brightness: {mean_brightness:.1f}; '
                f'maximum {self.BRIGHT_THRESHOLD}).'
            )
            penalty += 0.20

        # ── Check 4: Contrast (pixel std dev) ────────────────────────────────
        contrast = float(gray.std())
        if contrast < self.CONTRAST_THRESHOLD:
            reasons.append(
                f'Image has very low contrast (std: {contrast:.1f}; '
                f'required >= {self.CONTRAST_THRESHOLD}).'
            )
            penalty += 0.20

        # ── Check 5: Screenshot / document detection via Shannon entropy ──────
        hist = cv2.calcHist([gray], [0], None, [256], [0, 256]).flatten()
        hist_norm = hist / (hist.sum() + 1e-7)
        entropy = float(-np.sum(hist_norm * np.log2(hist_norm + 1e-9)))
        if entropy < self.SCREENSHOT_ENTROPY_MAX:
            reasons.append(
                f'Image appears to be a screenshot or document '
                f'(entropy: {entropy:.2f}; expected > {self.SCREENSHOT_ENTROPY_MAX}).'
            )
            penalty += 0.45

        # ── Check 6: Extreme aspect ratio ─────────────────────────────────────
        aspect_ratio = max(h, w) / max(min(h, w), 1)
        if aspect_ratio > 2.5:
            reasons.append(
                f'Unusual aspect ratio ({aspect_ratio:.1f}:1). '
                'Fundus images are roughly square.'
            )
            penalty += 0.20

        score = max(0.0, 1.0 - penalty)
        quality = 'good' if score >= self.GOOD_SCORE_THRESHOLD and not reasons else 'poor'

        return {
            'quality': quality,
            'score': round(score, 3),
            'reasons': reasons,
            'diagnostics': {
                'blur_score': round(blur_score, 2),
                'mean_brightness': round(mean_brightness, 2),
                'contrast_std': round(contrast, 2),
                'entropy': round(entropy, 3),
                'aspect_ratio': round(aspect_ratio, 2),
                'resolution': f'{w}x{h}',
            },
        }


# Module-level singleton
quality_assessor = ImageQualityAssessor()
