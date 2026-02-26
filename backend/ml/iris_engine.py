"""
IrisEngine — main orchestrator for the iris recognition pipeline.

Usage:
    engine = IrisEngine()

    # Enrollment (called during student registration)
    features = engine.enroll(image_bytes)
    # → {"feature_left": "abc123...", "feature_right": "def456..."}

    # Scanning (called during attendance)
    result = engine.scan(image_bytes, enrolled_list)
    # → ScanResult(matched, student_id, confidence, is_fake_eye, ...)
"""
import logging
from dataclasses import dataclass
from typing import List, Optional

import cv2
import numpy as np

from .eye_detector    import EyeDetector
from .feature_extractor import FeatureExtractor
from .liveness_detector import LivenessDetector
from .iris_matcher    import IrisMatcher, EnrolledIris, MatchResult

logger = logging.getLogger(__name__)


@dataclass
class ScanResult:
    matched:      bool
    student_id:   Optional[int]
    student_name: Optional[str]
    roll_number:  Optional[str]
    confidence:   float
    is_fake_eye:  bool
    liveness_score: float
    hamming_distance: float
    eye_detected: bool
    message:      str


@dataclass
class EnrollResult:
    success:        bool
    feature_left:   Optional[str]   # hex IrisCode
    feature_right:  Optional[str]
    message:        str


class IrisEngine:
    """
    Singleton-friendly iris recognition engine.
    All heavy models are lazy-loaded on first use.
    """

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._detector  = EyeDetector()
        self._extractor = FeatureExtractor()
        self._liveness  = LivenessDetector()
        self._matcher   = IrisMatcher()
        self._initialized = True
        logger.info("IrisEngine initialized.")

    # ─── Public API ───────────────────────────────

    def is_ready(self) -> bool:
        return self._initialized

    def enroll(self, image_bytes: bytes) -> EnrollResult:
        """
        Extract iris features from an enrollment image.
        Returns hex IrisCodes for left and right eyes.
        """
        bgr = self._decode(image_bytes)
        if bgr is None:
            return EnrollResult(False, None, None, "Could not decode image")

        det = self._detector.detect(bgr)
        if not det.landmarks_found:
            return EnrollResult(False, None, None, "No face/eye detected in image")

        feat_left  = self._extractor.extract(det.left_iris)  if det.left_iris  is not None else None
        feat_right = self._extractor.extract(det.right_iris) if det.right_iris is not None else None

        if feat_left is None and feat_right is None:
            return EnrollResult(False, None, None, "Could not extract iris features")

        return EnrollResult(
            success=True,
            feature_left=feat_left,
            feature_right=feat_right,
            message="Enrollment successful",
        )

    def scan(
        self,
        image_bytes: bytes,
        enrolled: List[EnrolledIris],
    ) -> ScanResult:
        """
        Full scan pipeline:
          1. Detect iris in image
          2. Liveness check
          3. Extract features
          4. Match against enrolled DB
          5. Return ScanResult
        """
        bgr = self._decode(image_bytes)
        if bgr is None:
            return ScanResult(
                matched=False, student_id=None, student_name=None,
                roll_number=None, confidence=0.0, is_fake_eye=False,
                liveness_score=0.0, hamming_distance=1.0,
                eye_detected=False, message="Could not decode image",
            )

        # Step 1: Detect eyes
        det = self._detector.detect(bgr)
        if not det.landmarks_found:
            return ScanResult(
                matched=False, student_id=None, student_name=None,
                roll_number=None, confidence=0.0, is_fake_eye=False,
                liveness_score=0.0, hamming_distance=1.0,
                eye_detected=False, message="No face detected in image. Please move closer.",
            )

        # Step 2: Liveness check (use whichever eye is available)
        iris_for_liveness = det.left_iris if det.left_iris is not None else det.right_iris
        liveness = self._liveness.check(iris_for_liveness)

        if liveness["is_fake"]:
            logger.warning(f"Fake eye detected: {liveness['reason']}")
            return ScanResult(
                matched=False, student_id=None, student_name=None,
                roll_number=None, confidence=0.0, is_fake_eye=True,
                liveness_score=liveness["score"], hamming_distance=1.0,
                eye_detected=True,
                message=f"Fake eye detected: {liveness['reason']}",
            )

        # Step 3: Feature extraction
        feat_left  = self._extractor.extract(det.left_iris)  if det.left_iris  is not None else None
        feat_right = self._extractor.extract(det.right_iris) if det.right_iris is not None else None

        if feat_left is None and feat_right is None:
            return ScanResult(
                matched=False, student_id=None, student_name=None,
                roll_number=None, confidence=0.0, is_fake_eye=False,
                liveness_score=liveness["score"], hamming_distance=1.0,
                eye_detected=True, message="Feature extraction failed",
            )

        if not enrolled:
            return ScanResult(
                matched=False, student_id=None, student_name=None,
                roll_number=None, confidence=0.0, is_fake_eye=False,
                liveness_score=liveness["score"], hamming_distance=1.0,
                eye_detected=True, message="No enrolled students to match against",
            )

        # Step 4: Match — try both eyes, take best result
        results = []
        if feat_left:
            r = self._matcher.match(feat_left, enrolled, use_left=True)
            results.append(r)
        if feat_right:
            r = self._matcher.match(feat_right, enrolled, use_left=False)
            results.append(r)

        best = max(results, key=lambda r: r.confidence)

        if best.matched:
            msg = f"Matched: {best.student_name} ({best.roll_number}) — {best.confidence*100:.1f}% confidence"
        else:
            msg = f"No match found (best HD={best.hamming_distance:.3f}, threshold=0.32)"

        return ScanResult(
            matched=best.matched,
            student_id=best.student_id,
            student_name=best.student_name,
            roll_number=best.roll_number,
            confidence=best.confidence,
            is_fake_eye=False,
            liveness_score=liveness["score"],
            hamming_distance=best.hamming_distance,
            eye_detected=True,
            message=msg,
        )

    # ─── Utility ──────────────────────────────────

    def _decode(self, image_bytes: bytes) -> Optional[np.ndarray]:
        try:
            arr = np.frombuffer(image_bytes, dtype=np.uint8)
            bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            if bgr is None:
                return None
            # Resize very large images to speed up processing
            h, w = bgr.shape[:2]
            if max(h, w) > 1200:
                scale = 1200 / max(h, w)
                bgr = cv2.resize(bgr, (int(w*scale), int(h*scale)))
            return bgr
        except Exception as e:
            logger.error(f"Image decode error: {e}")
            return None
