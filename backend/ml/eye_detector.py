"""
Eye / Iris detector using MediaPipe FaceMesh.

Extracts the iris region from a BGR image (numpy array).
Works with images taken at 1–15m on a mobile camera
(or further with optical zoom).
"""
import logging
import math
from dataclasses import dataclass
from typing import Optional, Tuple

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# MediaPipe iris landmark indices within the 478-point FaceMesh model
# Left eye iris: 468-472, Right eye iris: 473-477
_LEFT_IRIS  = [468, 469, 470, 471, 472]
_RIGHT_IRIS = [473, 474, 475, 476, 477]

# Eye contour landmarks (for cropping context around the iris)
_LEFT_EYE_CONTOUR  = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
_RIGHT_EYE_CONTOUR = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]

IRIS_SIZE = 200  # normalized iris output size in pixels (square)
EYE_PAD   = 2.5  # multiplier around iris radius for the crop


@dataclass
class IrisDetectionResult:
    left_iris:  Optional[np.ndarray]   # grayscale, IRIS_SIZE × IRIS_SIZE
    right_iris: Optional[np.ndarray]
    left_center:  Optional[Tuple[int, int]]
    right_center: Optional[Tuple[int, int]]
    left_radius:  Optional[float]
    right_radius: Optional[float]
    landmarks_found: bool


class EyeDetector:
    """
    Detects and crops iris regions using MediaPipe FaceMesh.
    Lazy-loads the model on first use.
    """

    def __init__(self):
        self._face_mesh = None

    def _load(self):
        if self._face_mesh is not None:
            return
        try:
            import mediapipe as mp
            from mediapipe.tasks import python
            from mediapipe.tasks.python import vision
            import os
            
            model_path = os.path.join(os.path.dirname(__file__), 'face_landmarker.task')
            base_options = python.BaseOptions(model_asset_path=model_path)
            options = vision.FaceLandmarkerOptions(
                base_options=base_options,
                output_face_blendshapes=False,
                output_facial_transformation_matrixes=False,
                num_faces=1
            )
            self._face_mesh = vision.FaceLandmarker.create_from_options(options)
            self._mp = mp
            logger.info("MediaPipe FaceLandmarker loaded (iris mode).")
        except Exception as e:
            logger.warning(f"mediapipe not installed/working — using Haar fallback. Error: {e}")
            self._face_mesh = None

    # ─── Public API ───────────────────────────────

    def detect(self, image_bgr: np.ndarray) -> IrisDetectionResult:
        """
        Detect irises in image_bgr.
        Returns IrisDetectionResult with normalized iris crops.
        """
        self._load()

        if self._face_mesh is not None:
            result = self._detect_mediapipe(image_bgr)
        else:
            result = self._detect_haar(image_bgr)

        return result

    def is_ready(self) -> bool:
        self._load()
        return True  # always ready (has haar fallback)

    # ─── MediaPipe path ───────────────────────────

    def _detect_mediapipe(self, bgr: np.ndarray) -> IrisDetectionResult:
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        h, w = bgr.shape[:2]

        mp_image = self._mp.Image(image_format=self._mp.ImageFormat.SRGB, data=rgb)
        detection_result = self._face_mesh.detect(mp_image)
        
        if not detection_result.face_landmarks:
            return IrisDetectionResult(None, None, None, None, None, None, False)

        lm = detection_result.face_landmarks[0]

        def _px(idx):
            p = lm[idx]
            return int(p.x * w), int(p.y * h)

        # Iris center = first landmark of the iris group
        # Iris radius = mean dist from center to the remaining 4 points
        def _iris_crop(indices):
            cx, cy = _px(indices[0])
            dists = [math.hypot(_px(i)[0]-cx, _px(i)[1]-cy) for i in indices[1:]]
            radius = max(float(np.mean(dists)), 4.0)

            pad = int(radius * EYE_PAD)
            x1 = max(cx - pad, 0)
            y1 = max(cy - pad, 0)
            x2 = min(cx + pad, w)
            y2 = min(cy + pad, h)

            if x2 <= x1 or y2 <= y1:
                return None, (cx, cy), radius

            crop = bgr[y1:y2, x1:x2]
            gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
            # Upscale small iris crops (important for zoomed-out shots)
            gray = cv2.resize(gray, (IRIS_SIZE, IRIS_SIZE), interpolation=cv2.INTER_LANCZOS4)
            # CLAHE for contrast normalisation (helps vary lighting / distance)
            clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
            gray = clahe.apply(gray)
            return gray, (cx, cy), radius

        li, lc, lr = _iris_crop(_LEFT_IRIS)
        ri, rc, rr = _iris_crop(_RIGHT_IRIS)

        return IrisDetectionResult(
            left_iris=li, right_iris=ri,
            left_center=lc, right_center=rc,
            left_radius=lr, right_radius=rr,
            landmarks_found=True,
        )

    # ─── Haar fallback ────────────────────────────

    def _detect_haar(self, bgr: np.ndarray) -> IrisDetectionResult:
        """
        Fallback using OpenCV's Haar eye detector.
        Less accurate but works without mediapipe.
        """
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
        eye_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_eye.xml"
        )
        eyes = eye_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)

        if len(eyes) == 0:
            return IrisDetectionResult(None, None, None, None, None, None, False)

        crops = []
        centers = []
        for (ex, ey, ew, eh) in eyes[:2]:
            crop = gray[ey:ey+eh, ex:ex+ew]
            # Iris is roughly in the middle 60% of the eye rectangle
            ih = int(eh * 0.6)
            iw = int(ew * 0.6)
            iy = int(eh * 0.2)
            ix = int(ew * 0.2)
            iris_crop = crop[iy:iy+ih, ix:ix+iw]
            iris_crop = cv2.resize(iris_crop, (IRIS_SIZE, IRIS_SIZE))
            clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
            iris_crop = clahe.apply(iris_crop)
            crops.append(iris_crop)
            centers.append((ex + ew//2, ey + eh//2))

        left  = crops[0] if len(crops) > 0 else None
        right = crops[1] if len(crops) > 1 else None
        lc    = centers[0] if len(centers) > 0 else None
        rc    = centers[1] if len(centers) > 1 else None

        return IrisDetectionResult(
            left_iris=left, right_iris=right,
            left_center=lc, right_center=rc,
            left_radius=None, right_radius=None,
            landmarks_found=(left is not None),
        )
