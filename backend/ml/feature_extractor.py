"""
Iris feature extractor.

Implements Daugman's rubber-sheet normalization followed by
a Gabor filter bank to produce a compact binary IrisCode.

The IrisCode is stored as a hex string in the database.
Hamming distance < 0.32 = match (industry standard threshold).
"""
import logging

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Normalization output dimensions (polar iris strip)
NORM_HEIGHT = 64   # radial samples
NORM_WIDTH  = 512  # angular samples (must be multiple of 8)

# Gabor bank parameters
_GABOR_FREQS       = [0.1, 0.2]   # cycles / pixel (relative to NORM_WIDTH)
_GABOR_ORIENTATIONS = [0, np.pi / 2]   # 0° and 90°
_GABOR_SIGMA       = 3.0
_GABOR_KERNEL_SIZE = 9


class FeatureExtractor:
    """
    Converts a normalized 64×64 iris crop → 2048-bit IrisCode (hex string).
    """

    def __init__(self):
        self._gabor_kernels = self._build_gabor_bank()

    # ─── Public API ───────────────────────────────

    def extract(self, iris_crop: np.ndarray) -> str:
        """
        iris_crop: grayscale uint8 array (any size, will be resized)
        Returns:   hex string representing the 2048-bit IrisCode
        """
        strip = self._normalize(iris_crop)
        code  = self._gabor_encode(strip)
        return code.hex()

    def hamming_distance(self, hex_a: str, hex_b: str) -> float:
        """
        Fractional Hamming distance between two IrisCodes.
        Returns 0.0 (identical) → 0.5 (random). Match if < 0.32.
        """
        try:
            a = bytes.fromhex(hex_a)
            b = bytes.fromhex(hex_b)
        except ValueError:
            return 1.0

        if len(a) != len(b):
            return 1.0

        xor = bytes(x ^ y for x, y in zip(a, b))
        bits_diff = sum(bin(byte).count("1") for byte in xor)
        total_bits = len(a) * 8
        return bits_diff / total_bits if total_bits > 0 else 1.0

    # ─── Daugman normalization ─────────────────────

    def _normalize(self, iris_crop: np.ndarray) -> np.ndarray:
        """
        Map iris crop to a rectangular polar-coordinate strip.
        Uses a simplified rubber-sheet model centered on the crop.
        """
        h, w = iris_crop.shape[:2]
        cx, cy = w / 2, h / 2
        # Rough pupil radius = 30% of crop, outer iris radius = 45%
        r_pupil = min(h, w) * 0.30
        r_iris  = min(h, w) * 0.45

        strip = np.zeros((NORM_HEIGHT, NORM_WIDTH), dtype=np.uint8)

        for row in range(NORM_HEIGHT):
            r = r_pupil + (r_iris - r_pupil) * (row / NORM_HEIGHT)
            for col in range(NORM_WIDTH):
                theta = 2 * np.pi * col / NORM_WIDTH
                x = cx + r * np.cos(theta)
                y = cy + r * np.sin(theta)
                xi, yi = int(round(x)), int(round(y))
                if 0 <= xi < w and 0 <= yi < h:
                    strip[row, col] = iris_crop[yi, xi]

        return strip

    # ─── Gabor encoding ───────────────────────────

    def _build_gabor_bank(self):
        kernels = []
        for freq in _GABOR_FREQS:
            for theta in _GABOR_ORIENTATIONS:
                # Real and imaginary Gabor kernels
                ksize = (_GABOR_KERNEL_SIZE, _GABOR_KERNEL_SIZE)
                real_k = cv2.getGaborKernel(
                    ksize, _GABOR_SIGMA, theta,
                    1.0 / freq, 0.5, 0, ktype=cv2.CV_32F
                )
                imag_k = cv2.getGaborKernel(
                    ksize, _GABOR_SIGMA, theta,
                    1.0 / freq, 0.5, np.pi / 2, ktype=cv2.CV_32F
                )
                kernels.append((real_k, imag_k))
        return kernels

    def _gabor_encode(self, strip: np.ndarray) -> bytes:
        """
        Apply Gabor bank to the strip → binarize real/imag responses → IrisCode.
        """
        float_strip = strip.astype(np.float32) / 255.0
        bits = []

        for real_k, imag_k in self._gabor_kernels:
            real_resp = cv2.filter2D(float_strip, cv2.CV_32F, real_k)
            imag_resp = cv2.filter2D(float_strip, cv2.CV_32F, imag_k)
            bits.extend((real_resp > 0).flatten().astype(np.uint8).tolist())
            bits.extend((imag_resp > 0).flatten().astype(np.uint8).tolist())

        # Pack bits into bytes (truncate / pad to 2048 bits = 256 bytes)
        target_bits = 2048
        bits = bits[:target_bits]
        while len(bits) < target_bits:
            bits.append(0)

        code_bytes = bytearray()
        for i in range(0, len(bits), 8):
            byte = 0
            for j in range(8):
                byte = (byte << 1) | bits[i + j]
            code_bytes.append(byte)

        return bytes(code_bytes)
