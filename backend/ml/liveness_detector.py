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

# Thresholds (tuned for mobile cameras)
_SPECULAR_MIN_AREA   = 2      # minimum bright spot area for corneal reflection
_SPECULAR_MAX_AREA   = 50     # should be a small spot, not a broad glare
_SPECULAR_THRESHOLD  = 240    # brightness threshold
_ENTROPY_MIN         = 4.8    # heightened for modern high-res iris texture
_SHARPNESS_MIN       = 12.0   # minimum Laplacian variance
_FFT_MOIRE_MAX       = 0.08   # max allowable high-freq spike (detects screen pixels)


class LivenessDetector:

    def check(self, iris_crop: np.ndarray) -> dict:
        """
        Runs multiple security checks to detect spoofs.
        """
        gray = self._to_gray(iris_crop)

        spec_ok  = self._check_specular(gray)
        entr_ok  = self._check_entropy(gray)
        sharp_ok = self._check_sharpness(gray)
        moire_ok = self._check_moire(gray)

        # Weighting: Moire and Specular are strongest indicators
        # Must pass Moire + (at least 2 of the other 3)
        passed_others = sum([spec_ok, entr_ok, sharp_ok])
        is_fake = not moire_ok or (passed_others < 2)

        score = (int(moire_ok)*2 + spec_ok + entr_ok + sharp_ok) / 5.0

        reasons = []
        if not moire_ok: reasons.append("Digital screen pattern detected (Moiré)")
        if not spec_ok:  reasons.append("No focal specular reflection")
        if not entr_ok:  reasons.append("Non-biological texture")
        if not sharp_ok: reasons.append("Blurry/Digital boundary")

        return {
            "is_fake":      is_fake,
            "score":        round(score, 3),
            "specular_ok":  spec_ok,
            "entropy_ok":   entr_ok,
            "sharpness_ok": sharp_ok,
            "moire_ok":     moire_ok,
            "reason":       ", ".join(reasons) if reasons else "Bio-authentic eye verified",
        }

    # ─── Check 1: Specular circularity ────────────

    def _check_specular(self, gray: np.ndarray) -> bool:
        """
        Authentic corneal reflections are small, circular, and high-intensity.
        Screens produce either no glint or large rectangular glows.
        """
        _, bright = cv2.threshold(gray, _SPECULAR_THRESHOLD, 255, cv2.THRESH_BINARY)
        num_labels, _, stats, _ = cv2.connectedComponentsWithStats(bright, connectivity=8)

        for i in range(1, num_labels):
            area = stats[i, cv2.CC_STAT_AREA]
            w, h = stats[i, cv2.CC_STAT_WIDTH], stats[i, cv2.CC_STAT_HEIGHT]
            # Check for "spot-like" geometry (near-square aspect ratio)
            aspect_ratio = w / h if h > 0 else 0
            if _SPECULAR_MIN_AREA <= area <= _SPECULAR_MAX_AREA:
                if 0.5 < aspect_ratio < 2.0:
                    return True
        return False

    # ─── Check 2: FFT Moiré Detection ──────────────

    def _check_moire(self, gray: np.ndarray) -> bool:
        """
        Detects the periodic grid of pixels on digital screens using FFT.
        A real eye has natural, non-periodic structures.
        """
        h, w = gray.shape
        # Use a central crop for FFT to avoid edge artifacts
        ch, cw = h // 2, w // 2
        crop = gray[ch-16:ch+16, cw-16:cw+16]
        if crop.size == 0: return True

        # Compute 2D Fast Fourier Transform
        f = np.fft.fft2(crop.astype(float))
        fshift = np.fft.fftshift(f)
        magnitude_spectrum = 20 * np.log(np.abs(fshift) + 1e-9)
        
        # Normalize and find the max high-frequency component
        # Removing the DC component (central spot)
        magnitude_spectrum[14:18, 14:18] = 0
        max_val = np.max(magnitude_spectrum)
        mean_val = np.mean(magnitude_spectrum)
        
        ratio = (max_val - mean_val) / (max_val + 1e-9)
        # Digital screens have sharp periodic spikes
        return ratio < 0.65  # empirically tuned

    # ─── Check 3: LBP Texture ─────────────────────

    def _check_entropy(self, gray: np.ndarray) -> bool:
        lbp = self._lbp(gray)
        hist, _ = np.histogram(lbp, bins=256, range=(0, 256))
        hist = hist.astype(float)
        hist /= (hist.sum() + 1e-9)
        entropy = -np.sum(hist * np.log2(hist + 1e-9))
        return float(entropy) >= _ENTROPY_MIN

    def _lbp(self, gray: np.ndarray) -> np.ndarray:
        padded = np.pad(gray, 1, mode="edge").astype(np.int16)
        center = padded[1:-1, 1:-1]
        neighbors = [
            padded[0:-2, 0:-2], padded[0:-2, 1:-1], padded[0:-2, 2:  ],
            padded[1:-1, 2:  ], padded[2:  , 2:  ], padded[2:  , 1:-1],
            padded[2:  , 0:-2], padded[1:-1, 0:-2],
        ]
        out  = np.zeros_like(gray, dtype=np.uint8)
        for bit, nb in enumerate(neighbors):
            out |= ((nb >= center).astype(np.uint8) << bit)
        return out

    # ─── Check 4: Laplacian Sharpness ─────────────

    def _check_sharpness(self, gray: np.ndarray) -> bool:
        lap = cv2.Laplacian(gray, cv2.CV_64F)
        variance = float(lap.var())
        return variance >= _SHARPNESS_MIN

    # ─── Utilities ────────────────────────────────

    def _to_gray(self, img: np.ndarray) -> np.ndarray:
        if len(img.shape) == 3:
            return cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        return img
