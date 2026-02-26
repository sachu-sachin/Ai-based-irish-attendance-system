"""
Iris matcher — compares a query IrisCode against all enrolled students.

Uses fractional Hamming distance on 2048-bit IrisCodes.
Industry threshold: HD < 0.32 = same person (EER ≈ 0.1%).

Rotation shifts: tries ±7 bit-shift rotations to account for
head tilt between enrollment and scan.
"""
import json
import logging
from dataclasses import dataclass
from typing import List, Optional

from .feature_extractor import FeatureExtractor

logger = logging.getLogger(__name__)

MATCH_THRESHOLD  = 0.32   # below this = identity match
MAX_SHIFT_BITS   = 7      # IrisCode rotation compensation (head tilt)


@dataclass
class MatchResult:
    matched:    bool
    student_id: Optional[int]
    student_name: Optional[str]
    roll_number: Optional[str]
    confidence: float           # 0.0–1.0 (1 - hamming_distance / 0.5)
    hamming_distance: float


@dataclass
class EnrolledIris:
    student_id:   int
    student_name: str
    roll_number:  str
    feature_left:  Optional[str]   # hex IrisCode
    feature_right: Optional[str]


class IrisMatcher:

    def __init__(self):
        self._extractor = FeatureExtractor()

    def match(
        self,
        query_hex: str,
        enrolled: List[EnrolledIris],
        use_left: bool = True,     # which eye side is in query
    ) -> MatchResult:
        """
        Compare query_hex against all enrolled irises.
        Returns the best MatchResult.
        """
        best_hd   = 1.0
        best_enr  = None

        for enr in enrolled:
            # Pick the stored code for the same eye side
            db_code = enr.feature_left if use_left else enr.feature_right
            if not db_code:
                # Try the other side as fallback
                db_code = enr.feature_right if use_left else enr.feature_left
            if not db_code:
                continue

            hd = self._min_hd_with_rotation(query_hex, db_code)
            if hd < best_hd:
                best_hd  = hd
                best_enr = enr

        matched = best_hd < MATCH_THRESHOLD
        confidence = max(0.0, 1.0 - best_hd / 0.5)  # normalise to [0,1]

        if matched and best_enr:
            return MatchResult(
                matched=True,
                student_id=best_enr.student_id,
                student_name=best_enr.student_name,
                roll_number=best_enr.roll_number,
                confidence=round(confidence, 4),
                hamming_distance=round(best_hd, 4),
            )

        return MatchResult(
            matched=False,
            student_id=None,
            student_name=None,
            roll_number=None,
            confidence=round(confidence, 4),
            hamming_distance=round(best_hd, 4),
        )

    def _min_hd_with_rotation(self, hex_a: str, hex_b: str) -> float:
        """
        Compute the minimum Hamming distance across ±MAX_SHIFT_BITS
        circular bit-shifts. This corrects for head tilt.
        """
        try:
            a = bytes.fromhex(hex_a)
            b = bytes.fromhex(hex_b)
        except ValueError:
            return 1.0

        if len(a) != len(b):
            return 1.0

        bits_a = self._bytes_to_bits(a)
        bits_b = self._bytes_to_bits(b)
        n      = len(bits_a)

        min_hd = 1.0
        for shift in range(-MAX_SHIFT_BITS, MAX_SHIFT_BITS + 1):
            shifted_b = bits_b[-shift:] + bits_b[:-shift] if shift else bits_b
            diff = sum(x != y for x, y in zip(bits_a, shifted_b))
            hd   = diff / n
            if hd < min_hd:
                min_hd = hd

        return min_hd

    @staticmethod
    def _bytes_to_bits(b: bytes) -> list:
        bits = []
        for byte in b:
            for i in range(7, -1, -1):
                bits.append((byte >> i) & 1)
        return bits
