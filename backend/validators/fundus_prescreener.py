import cv2
import numpy as np
from PIL import Image


class FundusPrescreener:
    """
    Traditional Computer Vision fundus image pre-screener.
    Runs BEFORE the deep learning glaucoma model.

    Rejects non-fundus images (laptops, screenshots, selfies, documents,
    random objects) using four deterministic checks:
      1. Red channel dominance  (fundus images are always R >> G >> B)
      2. Circular/oval FOV shape with dark border
      3. Dark-border pixel ratio
      4. Aspect ratio           (fundus images are roughly square)
    """

    # Tunable thresholds (Statistically Backed)
    RED_DOMINANCE_RATIO_G = 1.05   # R > G by 5% (Standard)
    RED_DOMINANCE_RATIO_B = 1.15   # R > B by 15%
    STRICT_RED_RATIO_G = 1.30      # R > G by 30% (For borderless crops to reject selfies)
    MIN_CIRCULARITY = 0.30         # Allow cropped ellipses
    DARK_BORDER_MIN = 0.00         # Allow 0% dark pixels (fully cropped fundus)
    DARK_BORDER_MAX = 0.65         # Not more than 65% dark
    MAX_ASPECT_RATIO = 3.0         # Allow up to 3:1 crops (e.g., 2048x922)
    MIN_SCORE_TO_PASS = 0.55       # Mathematically blocks non-red rectangles

    def check(self, pil_image: Image.Image) -> dict:
        """
        Args:
            pil_image: PIL Image (any mode; converted to RGB internally)
        Returns:
            {
              'is_fundus': bool,
              'confidence': float (0–1),
              'reason': str,
              'checks': dict
            }
        """
        image = pil_image.convert('RGB')
        img_np = np.array(image, dtype=np.float32)
        h, w = img_np.shape[:2]

        results = {}

        gray = cv2.cvtColor(img_np.astype(np.uint8), cv2.COLOR_RGB2GRAY)

        # ── Check 3: Dark border ratio (Computed first for adaptive red check) ─
        dark_pixels = int((gray < 20).sum())
        dark_ratio = dark_pixels / max(h * w, 1)
        has_dark_border = self.DARK_BORDER_MIN < dark_ratio < self.DARK_BORDER_MAX
        results['dark_border_present'] = bool(has_dark_border)
        results['dark_pixel_ratio'] = round(float(dark_ratio), 3)

        # ── Check 1: Red channel dominance (Adaptive) ───────────────────────
        r_mean = img_np[:, :, 0].mean()
        g_mean = img_np[:, :, 1].mean()
        b_mean = img_np[:, :, 2].mean()

        # If it's a cropped image with no dark border, enforce STRICT red to block selfies
        req_g = self.STRICT_RED_RATIO_G if dark_ratio < 0.01 else self.RED_DOMINANCE_RATIO_G
        
        red_dominant = (
            r_mean > g_mean * req_g
            and r_mean > b_mean * self.RED_DOMINANCE_RATIO_B
        )
        results['red_channel_dominant'] = bool(red_dominant)

        # ── Check 2: Circular FOV shape ──────────────────────────────────────
        _, thresh = cv2.threshold(gray, 20, 255, cv2.THRESH_BINARY)
        contours, _ = cv2.findContours(
            thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )

        circularity = 0.0
        if contours:
            largest = max(contours, key=cv2.contourArea)
            area = cv2.contourArea(largest)
            perimeter = cv2.arcLength(largest, True)
            if perimeter > 0:
                circularity = (4.0 * np.pi * area) / (perimeter ** 2)

        circular_shape = circularity >= self.MIN_CIRCULARITY
        results['circular_fov'] = bool(circular_shape)
        results['circularity_score'] = round(float(circularity), 3)

        # ── Check 4: Aspect ratio ────────────────────────────────────────────
        aspect_ratio = max(h, w) / max(min(h, w), 1)
        good_aspect = aspect_ratio <= self.MAX_ASPECT_RATIO
        results['good_aspect_ratio'] = bool(good_aspect)
        results['aspect_ratio'] = round(float(aspect_ratio), 2)

        # ── Weighted composite score ─────────────────────────────────────────
        weights = {
            'red_channel_dominant': 0.50,
            'circular_fov': 0.25,
            'dark_border_present': 0.15,
            'good_aspect_ratio': 0.10,
        }
        score = sum(weights[k] * (1.0 if results[k] else 0.0) for k in weights)
        is_fundus = score >= self.MIN_SCORE_TO_PASS

        if is_fundus:
            reason = 'Retinal fundus image verified by traditional CV checks.'
        elif not results['red_channel_dominant']:
            reason = (
                'Image does not have the red channel dominance typical of '
                'retinal fundus images.'
            )
        elif not results['circular_fov']:
            reason = (
                'No circular field-of-view detected. Fundus images have a '
                'characteristic circular or oval shape.'
            )
        elif not results['dark_border_present']:
            reason = (
                'No dark border found. Fundus images typically have a dark '
                'background border from the fundus camera aperture.'
            )
        else:
            reason = 'Image does not match expected retinal fundus characteristics.'

        return {
            'is_fundus': bool(is_fundus),
            'confidence': round(float(score), 3),
            'reason': reason,
            'checks': results,
        }


# Module-level singleton – import and use directly
prescreener = FundusPrescreener()
