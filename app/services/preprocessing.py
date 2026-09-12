"""Garment Preprocessing Service for EcoStitch.

Implements:
1. rembg background removal (producing clean transparent garment cutouts).
2. OpenCV HoughCircles reference coin detection (measuring coin pixel diameter for real-world scaling).
"""

from typing import Optional, Tuple
import cv2
import numpy as np
from rembg import remove


def remove_background(image_bytes: bytes) -> bytes:
    """Removes the background from a garment image using rembg (u2net model).

    Args:
        image_bytes: Raw bytes of the uploaded JPEG/PNG garment image.

    Returns:
        PNG image bytes containing the isolated garment on transparent background.

    Raises:
        Exception: If rembg fails to process the image.
    """
    try:
        cutout_bytes = remove(image_bytes)
        if not cutout_bytes:
            raise ValueError("Background removal returned empty result.")
        return cutout_bytes
    except Exception as e:
        raise RuntimeError(f"rembg background removal failed: {e}") from e


def detect_reference_coin(image_bytes: bytes) -> Tuple[bool, Optional[float]]:
    """Detects a circular reference coin in the garment photo using OpenCV HoughCircles.

    Applies grayscale conversion and Gaussian/median filtering, then searches for
    circular shapes corresponding to a reference coin placed beside the garment.

    Args:
        image_bytes: Raw bytes of the original captured image.

    Returns:
        A tuple of (detected: bool, pixel_diameter: Optional[float]).
        If detected, pixel_diameter is the measured diameter in pixels.
        If not detected, returns (False, None) without failing the request.
    """
    try:
        # 1. Decode raw bytes to OpenCV BGR image
        np_buf = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(np_buf, cv2.IMREAD_COLOR)

        if img is None:
            return False, None

        height, width = img.shape[:2]
        min_dim = min(height, width)

        # 2. Convert to Grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        # 3. Apply Gaussian Blur to reduce high-frequency noise and false circles
        blurred = cv2.GaussianBlur(gray, (9, 9), 2)
        # Secondary median blur to suppress texture artifacts from fabric weave
        blurred = cv2.medianBlur(blurred, 5)

        # 4. Adaptive coin radius bounds based on image resolution
        # A coin typically spans between 1.5% and 15% of the image's minimum dimension
        min_radius = max(12, int(min_dim * 0.015))
        max_radius = max(min_radius + 20, int(min_dim * 0.18))

        # 5. Detect circles via Hough Circle Transform
        # First pass: High confidence threshold (param2=38)
        circles = cv2.HoughCircles(
            blurred,
            cv2.HOUGH_GRADIENT,
            dp=1.2,
            minDist=max(30, int(min_dim * 0.05)),
            param1=100,
            param2=38,
            minRadius=min_radius,
            maxRadius=max_radius,
        )

        # Second pass: Fallback if lighting is low or coin has subtle rim contrast
        if circles is None or len(circles) == 0:
            circles = cv2.HoughCircles(
                blurred,
                cv2.HOUGH_GRADIENT,
                dp=1.2,
                minDist=max(30, int(min_dim * 0.05)),
                param1=90,
                param2=28,
                minRadius=min_radius,
                maxRadius=max_radius,
            )

        if circles is not None and len(circles) > 0:
            circles_arr = np.round(circles[0, :]).astype(float)

            # Pick the most prominent candidate circle
            best_circle = circles_arr[0]
            radius = float(best_circle[2])
            diameter_px = round(radius * 2.0, 2)

            return True, diameter_px

        return False, None

    except Exception as e:
        # Coin detection failure should not abort the whole request
        print(f"[CoinDetection] Warning during HoughCircles detection: {e}")
        return False, None
