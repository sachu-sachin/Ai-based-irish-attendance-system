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


class FeatureExtractor:
    """
    Converts a normalized iris crop → SIFT descriptors (JSON base64 string).
    """

    def __init__(self):
        # Initialize SIFT detector
        self._sift = cv2.SIFT_create(nfeatures=500)

    # ─── Public API ───────────────────────────────

    def extract(self, iris_crop: np.ndarray) -> Optional[str]:
        """
        iris_crop: grayscale uint8 array (preferably 200x200 or larger)
        Returns:   JSON string containing base64 encoded descriptors, or None if failed.
        """
        if iris_crop is None or iris_crop.size == 0:
            return None

        # SIFT requires grayscale 8-bit image
        if len(iris_crop.shape) > 2:
            gray = cv2.cvtColor(iris_crop, cv2.COLOR_BGR2GRAY)
        else:
            gray = iris_crop

        # Enhance contrast with CLAHE to help SIFT find more keypoints
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
        gray = clahe.apply(gray)

        # Detect keypoints and compute descriptors
        keypoints, descriptors = self._sift.detectAndCompute(gray, None)

        if descriptors is None or len(descriptors) < 5:
            logger.warning(f"Not enough SIFT features found: {len(keypoints) if keypoints else 0}")
            return None

        # Serialize descriptors to base64 string for database storage
        # SIFT descriptors are float32 arrays of shape (N, 128)
        desc_bytes = descriptors.tobytes()
        desc_b64 = base64.b64encode(desc_bytes).decode('ascii')
        
        # We also store shape to reconstruct the numpy array later
        data = {
            "shape": descriptors.shape,
            "dtype": str(descriptors.dtype),
            "data": desc_b64
        }
        
        return json.dumps(data)

    @staticmethod
    def deserialize_descriptors(json_str: str) -> Optional[np.ndarray]:
        """Convert the JSON string back to a numpy array of SIFT descriptors."""
        try:
            if not json_str:
                return None
            data = json.loads(json_str)
            desc_bytes = base64.b64decode(data["data"])
            dtype = np.dtype(data["dtype"])
            descriptors = np.frombuffer(desc_bytes, dtype=dtype).reshape(data["shape"])
            return descriptors
        except Exception as e:
            logger.error(f"Failed to deserialize descriptors: {e}")
            return None
