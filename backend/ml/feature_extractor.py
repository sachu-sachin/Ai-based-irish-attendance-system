"""
Iris feature extractor using OpenCV SIFT.

Extracts scale-invariant feature transform (SIFT) keypoints and descriptors
from the iris crop.

The SIFT descriptors are serialized into a JSON + base64 string and stored
in the database. We use SIFT because it is robust to scaling, rotation,
and minor translations (off-center crops).
"""
import base64
import json
import logging
from typing import Optional, Tuple

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# Normalization output dimensions (polar iris strip)
# Standard dimensions for iris codes
NORM_HEIGHT = 64
NORM_WIDTH  = 256

# Gabor bank parameters - Expanded for higher uniqueness
_GABOR_FREQS        = [0.1, 0.25]
_GABOR_ORIENTATIONS = [0, np.pi/4, np.pi/2, 3*np.pi/4]
_GABOR_SIGMA        = 2.5
_GABOR_KERNEL_SIZE  = 15


class FeatureExtractor:
    """
    Converts a grayscale iris crop + boundary data → 2048-bit IrisCode (hex string).
    """

    def __init__(self):
        # Initialize SIFT detector
        self._sift = cv2.SIFT_create(nfeatures=500)

    # ─── Public API ───────────────────────────────

    def extract(self, iris_crop: np.ndarray, iris_radius: float = 0.0) -> str:
        """
        iris_crop:   grayscale uint8 array (the ROI from detector)
        iris_radius: actual radius of the iris in pixels inside this crop
        Returns:     hex string representing the 2048-bit IrisCode
        """
        if iris_radius <= 0:
            # Fallback if radius not provided (should not happen with new detector)
            h, w = iris_crop.shape[:2]
            iris_radius = min(h, w) * 0.45

        strip = self._normalize(iris_crop, iris_radius)
        code  = self._gabor_encode(strip)
        return code.hex()

    def hamming_distance(self, hex_a: str, hex_b: str) -> float:
        """
        Fractional Hamming distance between two IrisCodes.
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

    def _normalize(self, iris_crop: np.ndarray, iris_radius: float) -> np.ndarray:
        """
        Scientifically accurate Daugman Rubber Sheet model.
        Maps the iris ring to a fixed-size rectangular strip.
        """
        h, w = iris_crop.shape[:2]
        cx, cy = w / 2, h / 2
        
        # Pupil is typically 35-40% of the iris radius in neutral light
        r_pupil = iris_radius * 0.38
        r_iris  = iris_radius

        strip = np.zeros((NORM_HEIGHT, NORM_WIDTH), dtype=np.uint8)

        # Pre-calculate theta values
        thetas = np.linspace(0, 2 * np.pi, NORM_WIDTH)
        
        for row in range(NORM_HEIGHT):
            # Map radial distance (relative to boundary)
            r_ratio = row / NORM_HEIGHT
            r = r_pupil + (r_iris - r_pupil) * r_ratio
            
            # Vectorized mapping for the row
            xs = cx + r * np.cos(thetas)
            ys = cy + r * np.sin(thetas)
            
            # Sample using bi-linear interpolation (or simple rounding for speed)
            for col in range(NORM_WIDTH):
                xi, yi = int(round(xs[col])), int(round(ys[col]))
                if 0 <= xi < w and 0 <= yi < h:
                    strip[row, col] = iris_crop[yi, xi]
        
        # Post-process strip to enhance features
        strip = cv2.equalizeHist(strip)
        return strip

    # ─── Gabor encoding ───────────────────────────

    def _build_gabor_bank(self):
        kernels = []
        for freq in _GABOR_FREQS:
            for theta in _GABOR_ORIENTATIONS:
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
        Apply Gabor bank and sample uniformly to produce the 2048-bit code.
        8 kernels * 2 (real/imag) = 16 bit-streams.
        2048 / 16 = 128 samples per bit-stream.
        """
        float_strip = strip.astype(np.float32) / 255.0
        final_bits = []

        # We need 128 samples from a 64x256 strip for each filtered image.
        # An 8x16 grid gives 128 points.
        sample_rows = np.linspace(5, NORM_HEIGHT - 5, 8).astype(int)
        sample_cols = np.linspace(5, NORM_WIDTH - 5, 16).astype(int)

        for real_k, imag_k in self._gabor_kernels:
            real_resp = cv2.filter2D(float_strip, cv2.CV_32F, real_k)
            imag_resp = cv2.filter2D(float_strip, cv2.CV_32F, imag_k)
            
            # Sample real part
            for r in sample_rows:
                for c in sample_cols:
                    final_bits.append(1 if real_resp[r, c] > 0 else 0)
            
            # Sample imaginary part
            for r in sample_rows:
                for c in sample_cols:
                    final_bits.append(1 if imag_resp[r, c] > 0 else 0)

        # Pack bits into exactly 256 bytes (2048 bits)
        code_bytes = bytearray()
        for i in range(0, len(final_bits), 8):
            byte = 0
            for j in range(8):
                if i + j < len(final_bits):
                    byte = (byte << 1) | final_bits[i + j]
            code_bytes.append(byte)
            
        # Ensure it's exactly 256 bytes
        return bytes(code_bytes[:256]).ljust(256, b'\x00')
