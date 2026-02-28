"""
Fake-eye / liveness detector.

Uses three complementary checks:
  1. Specular reflection (Purkinje image) — real eyes have bright corneal reflections
  2. LBP texture entropy — printed / screen irises have low entropy patterns
  3. Pupil boundary sharpness — real pupils have sharp Laplacian edges

Any single check failing flags the eye as potentially fake.
Returns a score 0.0 (definitely fake) → 1.0 (definitely real).
"""
import logging

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Thresholds (tuned empirically — adjust for your camera/lighting)
_SPECULAR_MIN_AREA   = 2      # minimum bright spot area in pixels (corneal reflection)
_SPECULAR_THRESHOLD  = 200    # brightness threshold for specular region
_ENTROPY_MIN         = 2.0    # minimum texture entropy for real iris
_SHARPNESS_MIN       = 3.0    # minimum Laplacian variance for real pupil edge


class LivenessDetector:

    def check(self, iris_crop: np.ndarray) -> dict:
        """
        iris_crop: grayscale or BGR uint8 array.
        Returns:
          {
            'is_fake': bool,
            'score': float (0=fake, 1=real),
            'specular_ok': bool,
            'entropy_ok': bool,
            'sharpness_ok': bool,
            'reason': str
          }
        """
        gray = self._to_gray(iris_crop)

        spec_ok  = self._check_specular(gray)
        entr_ok  = self._check_entropy(gray)
        sharp_ok = self._check_sharpness(gray)

        passed = sum([spec_ok, entr_ok, sharp_ok])
        score  = passed / 3.0

        # Need at least 2 of 3 checks to pass
        is_fake = passed < 2

        reasons = []
        if not spec_ok:  reasons.append("no specular reflection")
        if not entr_ok:  reasons.append("low texture entropy")
        if not sharp_ok: reasons.append("blurry pupil boundary")

        return {
            "is_fake":      is_fake,
            "score":        round(score, 3),
            "specular_ok":  spec_ok,
            "entropy_ok":   entr_ok,
            "sharpness_ok": sharp_ok,
            "reason":       ", ".join(reasons) if reasons else "all checks passed",
        }

    # ─── Check 1: Specular reflection ─────────────

    def _check_specular(self, gray: np.ndarray) -> bool:
        """
        Real eyes have bright specular reflections (Purkinje images).
        These appear as small bright spots (area ≥ _SPECULAR_MIN_AREA px).
        Fake eyes (printed / screen w/o glare) typically lack these.
        """
        _, bright = cv2.threshold(gray, _SPECULAR_THRESHOLD, 255, cv2.THRESH_BINARY)
        # Find connected bright regions
        num_labels, _, stats, _ = cv2.connectedComponentsWithStats(bright, connectivity=8)

        # Ignore background (label 0)
        bright_areas = [stats[i, cv2.CC_STAT_AREA] for i in range(1, num_labels)]
        has_reflection = any(a >= _SPECULAR_MIN_AREA for a in bright_areas)
        return has_reflection

    # ─── Check 2: LBP texture entropy ─────────────

    def _check_entropy(self, gray: np.ndarray) -> bool:
        """
        Compute Local Binary Pattern histogram entropy.
        Real irises have complex radial texture → high entropy.
        Flat/printed irises → low entropy.
        """
        lbp = self._lbp(gray)
        hist, _ = np.histogram(lbp, bins=256, range=(0, 256))
        hist = hist.astype(float)
        hist /= (hist.sum() + 1e-9)
        entropy = -np.sum(hist * np.log2(hist + 1e-9))
        return float(entropy) >= _ENTROPY_MIN

    def _lbp(self, gray: np.ndarray) -> np.ndarray:
        """Simple 8-neighbour LBP."""
        h, w = gray.shape
        out  = np.zeros_like(gray, dtype=np.uint8)
        padded = np.pad(gray, 1, mode="edge").astype(np.int16)
        center = padded[1:-1, 1:-1]
        neighbors = [
            padded[0:-2, 0:-2],  # NW
            padded[0:-2, 1:-1],  # N
            padded[0:-2, 2:  ],  # NE
            padded[1:-1, 2:  ],  # E
            padded[2:  , 2:  ],  # SE
            padded[2:  , 1:-1],  # S
            padded[2:  , 0:-2],  # SW
            padded[1:-1, 0:-2],  # W
        ]
        for bit, nb in enumerate(neighbors):
            out |= ((nb >= center).astype(np.uint8) << bit)
        return out

    # ─── Check 3: Pupil boundary sharpness ────────

    def _check_sharpness(self, gray: np.ndarray) -> bool:
        """
        Real pupil edges are sharp (high Laplacian variance).
        Soft/blurry (printed, screen) irises have low variance.
        """
        lap = cv2.Laplacian(gray, cv2.CV_64F)
        variance = float(lap.var())
        return variance >= _SHARPNESS_MIN

    # ─── Utilities ────────────────────────────────

    def _to_gray(self, img: np.ndarray) -> np.ndarray:
        if len(img.shape) == 3 and img.shape[2] == 3:
            return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        if len(img.shape) == 3 and img.shape[2] == 4:
            return cv2.cvtColor(img, cv2.COLOR_BGRA2GRAY)
        return img
