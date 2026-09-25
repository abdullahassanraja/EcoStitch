"""Garment Preprocessing Service for EcoStitch.

Implements high-efficiency image preprocessing pipeline:
1. EXIF orientation correction and dimension optimization.
2. Light & brightness adjustment (LAB color space + adaptive CLAHE + auto-gamma).
3. Neural network background removal (rembg u2netp).
4. Main object isolation: Filters out disconnected background fragments/shadows so ONLY the main garment remains.
5. Zoom framing: Crops tightly to the object bounding box with proportional padding to fit the frame.
6. OpenCV HoughCircles reference coin detection for scale calibration.
"""

import io
import logging
from typing import Optional, Tuple
import cv2
import numpy as np
from PIL import Image, ImageOps
import rembg

logger = logging.getLogger("ecostitch.preprocessing")

_rembg_session = None


def get_rembg_session():
    """Returns the cached u2netp session for fast neural network segmentation."""
    global _rembg_session
    if _rembg_session is None:
        logger.info("[Preprocessing] Initializing rembg u2netp session...")
        _rembg_session = rembg.new_session("u2netp")
    return _rembg_session


def adjust_light_and_brightness(img_rgb: np.ndarray) -> np.ndarray:
    """Applies adaptive lighting and brightness correction in LAB color space.
    
    Uses CLAHE (Contrast Limited Adaptive Histogram Equalization) on the luminance (L) channel
    and dynamic gamma correction to balance lighting and recover shadow/highlight details.
    """
    try:
        # Convert RGB to BGR for OpenCV
        img_bgr = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2BGR)
        
        # Convert to LAB color space
        lab = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2LAB)
        l_channel, a_channel, b_channel = cv2.split(lab)
        
        mean_l = float(np.mean(l_channel))
        
        # 1. Adaptive CLAHE for localized light balancing
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        l_clahe = clahe.apply(l_channel)
        
        # 2. Dynamic gamma correction for underexposed or overexposed photos
        if mean_l < 110:
            # Underexposed: gently boost midtones
            gamma = 0.85
            inv_gamma = 1.0 / gamma
            lut = np.array([((i / 255.0) ** inv_gamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
            l_clahe = cv2.LUT(l_clahe, lut)
        elif mean_l > 190:
            # Overexposed: protect highlights
            gamma = 1.15
            inv_gamma = 1.0 / gamma
            lut = np.array([((i / 255.0) ** inv_gamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
            l_clahe = cv2.LUT(l_clahe, lut)
            
        lab_enhanced = cv2.merge((l_clahe, a_channel, b_channel))
        enhanced_bgr = cv2.cvtColor(lab_enhanced, cv2.COLOR_LAB2BGR)
        return cv2.cvtColor(enhanced_bgr, cv2.COLOR_BGR2RGB)
    except Exception as e:
        logger.warning(f"[Preprocessing] Light adjustment fallback: {e}")
        return img_rgb


def isolate_main_object_and_zoom(cutout_rgba: np.ndarray) -> np.ndarray:
    """Ensures ONLY the main object is left and zooms/crops it to fit the frame.
    
    1. Connected components analysis to identify and retain only the primary garment object,
       eliminating stray background fragments, shadows, or table edges.
    2. Morphological closing to seal internal fabric weave pinholes.
    3. Crops tightly to the object bounding box with proportional padding so it fits
       the frame zoomed and centered.
    """
    h, w = cutout_rgba.shape[:2]
    alpha = cutout_rgba[:, :, 3]
    
    # Threshold alpha for connected components analysis
    thresh = (alpha > 35).astype(np.uint8) * 255
    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(thresh, connectivity=8)
    
    if num_labels > 1:
        # Label 0 is background. Find largest foreground component
        areas = stats[1:, cv2.CC_STAT_AREA]
        largest_idx = int(np.argmax(areas)) + 1
        max_area = stats[largest_idx, cv2.CC_STAT_AREA]
        
        # Keep only the main object (or components >= 12% of the main object if garment has detached parts)
        keep_mask = np.zeros_like(thresh)
        for i in range(1, num_labels):
            if stats[i, cv2.CC_STAT_AREA] >= max_area * 0.12:
                keep_mask[labels == i] = 255
                
        # Morphological closing to close tiny pinholes in fabric weave
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        keep_mask = cv2.morphologyEx(keep_mask, cv2.MORPH_CLOSE, kernel)
        
        # Anti-aliased Gaussian edge smoothing
        blurred_mask = cv2.GaussianBlur(keep_mask, (3, 3), 0)
        cutout_rgba[:, :, 3] = np.minimum(cutout_rgba[:, :, 3], blurred_mask)
    
    # Fit into frame by zooming: crop tightly to object bounding box + 4% safety margin
    alpha_final = cutout_rgba[:, :, 3]
    coords = cv2.findNonZero((alpha_final > 25).astype(np.uint8))
    if coords is not None:
        bx, by, bw, bh = cv2.boundingRect(coords)
        pad_x = max(8, int(bw * 0.04))
        pad_y = max(8, int(bh * 0.04))
        
        x0 = max(0, bx - pad_x)
        y0 = max(0, by - pad_y)
        x1 = min(w, bx + bw + pad_x)
        y1 = min(h, by + bh + pad_y)
        
        cutout_rgba = cutout_rgba[y0:y1, x0:x1]
        
    return cutout_rgba


def preprocess_and_clean_garment(image_bytes: bytes) -> Tuple[bytes, bool, Optional[float]]:
    """Complete preprocessing pipeline:
    1. EXIF auto-orientation.
    2. Dimension optimization (max 1280px) for high efficiency.
    3. Light and brightness adjustment (CLAHE + gamma).
    4. Neural background removal (u2netp).
    5. Main object isolation (filters out all extraneous background blobs).
    6. Zoom framing (tight bounding-box crop with padding).
    7. OpenCV HoughCircles reference coin detection.
    
    Returns:
        (cutout_png_bytes, coin_detected, coin_pixel_diameter)
    """
    try:
        # 1. Load image and correct EXIF orientation
        pil_img = Image.open(io.BytesIO(image_bytes))
        pil_img = ImageOps.exif_transpose(pil_img)
        
        if pil_img.mode != "RGB":
            pil_img = pil_img.convert("RGB")
            
        # 2. Optimize dimensions for ultra-fast inference if image is oversized
        max_dim = 1280
        w, h = pil_img.size
        if max(w, h) > max_dim:
            pil_img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)
            
        # 3. Light & brightness adjustment
        np_rgb = np.array(pil_img)
        enhanced_rgb = adjust_light_and_brightness(np_rgb)
        enhanced_pil = Image.fromarray(enhanced_rgb)
        
        # 4. Neural background removal using cached session
        session = get_rembg_session()
        buf = io.BytesIO()
        enhanced_pil.save(buf, format="PNG")
        
        cutout_raw_bytes = rembg.remove(buf.getvalue(), session=session, post_process_mask=True)
        cutout_pil = Image.open(io.BytesIO(cutout_raw_bytes)).convert("RGBA")
        cutout_rgba = np.array(cutout_pil)
        
        # 5. Isolate main object and fit into frame by zooming
        fitted_rgba = isolate_main_object_and_zoom(cutout_rgba)
        
        # Save output PNG bytes
        out_pil = Image.fromarray(fitted_rgba, "RGBA")
        out_buf = io.BytesIO()
        out_pil.save(out_buf, format="PNG", optimize=True)
        final_cutout_bytes = out_buf.getvalue()
        
        # 6. Coin scale detection on enhanced image
        coin_detected, coin_diameter = detect_reference_coin(image_bytes)
        
        return final_cutout_bytes, coin_detected, coin_diameter
        
    except Exception as e:
        logger.error(f"[Preprocessing] Error in pipeline: {e}")
        # Fallback to standard remove_background if custom pipeline fails
        fallback_cutout = remove_background(image_bytes)
        coin_detected, coin_diameter = detect_reference_coin(image_bytes)
        return fallback_cutout, coin_detected, coin_diameter


def remove_background(image_bytes: bytes) -> bytes:
    """Removes the background from a garment image using rembg (u2net neural network).
    
    Args:
        image_bytes: Raw bytes of the uploaded JPEG/PNG garment image.

    Returns:
        PNG image bytes containing the isolated garment on transparent background.
    """
    try:
        session = get_rembg_session()
        # Ensure EXIF transpose
        pil_img = Image.open(io.BytesIO(image_bytes))
        pil_img = ImageOps.exif_transpose(pil_img)
        buf = io.BytesIO()
        pil_img.save(buf, format="PNG")
        cutout_bytes = rembg.remove(buf.getvalue(), session=session, post_process_mask=True)
        if not cutout_bytes:
            raise ValueError("Background removal returned empty result.")
        return cutout_bytes
    except Exception as e:
        raise RuntimeError(f"rembg background removal failed: {e}") from e


def detect_reference_coin(image_bytes: bytes) -> Tuple[bool, Optional[float]]:
    """Detects a circular reference coin in the garment photo using OpenCV HoughCircles.

    Applies grayscale conversion and Gaussian/median filtering, then searches for
    circular shapes corresponding to a reference coin placed beside the garment.
    """
    try:
        np_buf = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(np_buf, cv2.IMREAD_COLOR)

        if img is None:
            return False, None

        height, width = img.shape[:2]
        min_dim = min(height, width)

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (9, 9), 2)
        blurred = cv2.medianBlur(blurred, 5)

        min_radius = max(12, int(min_dim * 0.015))
        max_radius = max(min_radius + 20, int(min_dim * 0.18))

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
            best_circle = circles_arr[0]
            radius = float(best_circle[2])
            diameter_px = round(radius * 2.0, 2)
            return True, diameter_px

        return False, None

    except Exception as e:
        logger.warning(f"[CoinDetection] Warning during HoughCircles detection: {e}")
        return False, None
