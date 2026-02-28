"""
Iris matcher — compares a query SIFT descriptor against all enrolled students.

Uses OpenCV's BFMatcher (Brute-Force Matcher) with Lowe's Ratio Test 
(0.7 ratio) to guarantee robust matches.
Returns the identity of the student with the highest number of "good" matches,
if it exceeds the MATCH_THRESHOLD (empirically set to ~15 good matches).
"""
import logging
import cv2
import numpy as np
from dataclasses import dataclass
from typing import List, Optional

from .feature_extractor import FeatureExtractor

logger = logging.getLogger(__name__)

MATCH_THRESHOLD = 15     # Minimum "good" SIFT keypoint matches to consider identity verified
LOWES_RATIO    = 0.70    # Industry standard for filtering robust matches


@dataclass
class MatchResult:
    matched:    bool
    student_id: Optional[int]
    student_name: Optional[str]
    roll_number: Optional[str]
    confidence: float           # Maps number of good matches to [0.0, 1.0]
    hamming_distance: float     # Legacy field kept for API compatibility, unused.


@dataclass
class EnrolledIris:
    student_id:   int
    student_name: str
    roll_number:  str
    feature_left:  Optional[str]   # JSON holding SIFT descriptor
    feature_right: Optional[str]


class IrisMatcher:

    def __init__(self):
        # BFMatcher for SIFT (L2 norm)
        self._matcher = cv2.BFMatcher(cv2.NORM_L2)

    def match(
        self,
        query_json: str,
        enrolled: List[EnrolledIris],
        use_left: bool = True,     # which eye side is in query
    ) -> MatchResult:
        """
        Compare query JSON descriptors against all enrolled irises using SIFT.
        Returns the best MatchResult based on max good matches.
        """
        query_desc = FeatureExtractor.deserialize_descriptors(query_json)
        
        if query_desc is None or len(query_desc) < 2:
            logger.warning("Query descriptor invalid or too few keypoints.")
            return MatchResult(False, None, None, None, 0.0, 1.0)

        best_matches_count = 0
        best_enr = None

        for enr in enrolled:
            # Pick the stored code for the same eye side
            db_code = enr.feature_left if use_left else enr.feature_right
            if not db_code:
                # Try the other side as fallback
                db_code = enr.feature_right if use_left else enr.feature_left
            if not db_code:
                continue

            db_desc = FeatureExtractor.deserialize_descriptors(db_code)
            if db_desc is None or len(db_desc) < 2:
                continue

            # Compute SIFT matches
            good_matches = self._match_descriptors(query_desc, db_desc)

            if good_matches > best_matches_count:
                best_matches_count = good_matches
                best_enr = enr

        matched = best_matches_count >= MATCH_THRESHOLD
        
        # Calculate a rough confidence (15 matches = ~60%, 25+ matches = 99%)
        confidence = min(1.0, float(best_matches_count) / 25.0)

        if matched and best_enr:
            logger.info(f"MATCH FOUND: {best_enr.student_name} with {best_matches_count} good SIFT matches.")
            return MatchResult(
                matched=True,
                student_id=best_enr.student_id,
                student_name=best_enr.student_name,
                roll_number=best_enr.roll_number,
                confidence=round(confidence, 4),
                hamming_distance=0.0, # Not applicable anymore
            )

        logger.info(f"No match. Best had {best_matches_count}/{MATCH_THRESHOLD} good matches.")
        return MatchResult(
            matched=False,
            student_id=None,
            student_name=None,
            roll_number=None,
            confidence=round(confidence, 4),
            hamming_distance=1.0,
        )

    def _match_descriptors(self, desc_a: np.ndarray, desc_b: np.ndarray) -> int:
        """
        Finds matches between two descriptor sets using knnMatch.
        Applies Lowe's ratio test to filter out weak matches.
        Returns the number of robust 'good' matches.
        """
        if desc_a is None or desc_b is None:
            return 0
        
        try:
            # Keep k=2 for the ratio test
            matches = self._matcher.knnMatch(desc_a, desc_b, k=2)
            
            good_count = 0
            for m_n in matches:
                if len(m_n) != 2:
                    continue
                m, n = m_n
                if m.distance < LOWES_RATIO * n.distance:
                    good_count += 1
            return good_count
        except Exception as e:
            logger.error(f"BFMatcher failed: {e}")
            return 0
