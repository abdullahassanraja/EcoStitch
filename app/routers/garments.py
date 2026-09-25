"""Garments Router for EcoStitch.

Implements Step 3: POST /garments/{garment_id}/preprocess
- Fetches uploaded image from Supabase Storage
- Runs rembg background removal
- Performs OpenCV HoughCircles coin detection
- Uploads transparent cutout back to storage
- Updates database status and metadata
"""

import logging
from typing import Optional
from fastapi import APIRouter, BackgroundTasks, HTTPException, status
from pydantic import BaseModel, Field

from app.services.preprocessing import (
    detect_reference_coin,
    preprocess_and_clean_garment,
    remove_background,
)
from app.services.supabase_client import (
    download_garment_image,
    get_garment_by_id,
    update_garment_status,
    upload_cutout_image,
)

logger = logging.getLogger("ecostitch.garments")
router = APIRouter(prefix="/garments", tags=["Garments Preprocessing"])


class PreprocessResponse(BaseModel):
    """Response payload returned upon completing garment preprocessing."""

    garment_id: str = Field(..., description="Unique ID of the garment record")
    status: str = Field(..., description="Processing status, e.g. 'preprocessed'")
    reference_object_detected: bool = Field(
        ..., description="True if a reference coin was detected in frame"
    )
    reference_object_pixel_diameter: Optional[float] = Field(
        None, description="Diameter of the detected reference coin in pixels"
    )
    cutout_image_url: Optional[str] = Field(
        None, description="Storage path of the background-removed PNG cutout"
    )


import uuid


def is_valid_uuid(val: str) -> bool:
    """Checks if string is a valid UUID."""
    try:
        uuid.UUID(str(val))
        return True
    except (ValueError, AttributeError, TypeError):
        return False


@router.post(
    "/{garment_id}/preprocess",
    response_model=PreprocessResponse,
    status_code=status.HTTP_200_OK,
    summary="Preprocess garment image (background removal & coin detection)",
    responses={
        404: {"description": "Garment not found in database"},
        400: {"description": "Garment record has no image_url"},
        500: {"description": "Image download or rembg background removal failed"},
    },
)
async def preprocess_garment(garment_id: str) -> PreprocessResponse:
    """Executes the Step 3 Preprocessing Pipeline for an uploaded garment:

    1. Retrieves garment record from Supabase table 'garments'.
    2. Updates status to 'preprocessing'.
    3. Downloads raw image bytes from storage bucket 'garment-images'.
    4. Removes the background using rembg (producing a PNG cutout).
    5. Detects a circular reference coin using OpenCV HoughCircles.
    6. Uploads the cutout back to storage as {user_id}/{garment_id}_cutout.png.
    7. Updates garment row to status='preprocessed' with metadata.
    8. Returns preprocessing results.
    """
    if not is_valid_uuid(garment_id):
        logger.warning(f"Garment ID '{garment_id}' is not a valid UUID format.")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Garment '{garment_id}' was not found in the database (invalid UUID).",
        )

    # 1. Look up garment row in Supabase database
    try:
        garment = get_garment_by_id(garment_id)
    except Exception as e:
        logger.error(f"Error querying garment {garment_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database query failed: {e}",
        )

    if not garment:
        logger.warning(f"Garment not found: {garment_id}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Garment with ID '{garment_id}' was not found in the database.",
        )

    storage_path = garment.get("image_url")
    if not storage_path:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Garment '{garment_id}' has no associated 'image_url' (storage path).",
        )

    user_id = garment.get("user_id") or "anonymous"

    # 2. Update status to 'preprocessing' in the database
    try:
        update_garment_status(
            garment_id,
            {"status": "preprocessing", "error_message": None},
        )
    except Exception as e:
        logger.error(f"Failed to update status to 'preprocessing': {e}")
        # Non-fatal if DB is temporarily slow, but we proceed with pipeline

    # 3. Download image bytes from Supabase Storage
    try:
        image_bytes = download_garment_image(storage_path)
    except Exception as e:
        error_msg = f"Failed to download garment image from storage path '{storage_path}': {e}"
        logger.error(error_msg)
        # Update garment record to failure state so it doesn't stay stuck
        try:
            update_garment_status(
                garment_id,
                {"status": "preprocessing_failed", "error_message": error_msg},
            )
        except Exception as db_err:
            logger.error(f"Failed to update error status: {db_err}")

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=error_msg,
        )

    # 4. Run preprocessing pipeline (light/brightness adjustment, rembg, object isolation, zoom framing & coin detection)
    try:
        cutout_bytes, coin_detected, coin_diameter_px = preprocess_and_clean_garment(image_bytes)
    except Exception as e:
        error_msg = f"Garment preprocessing failed for garment '{garment_id}': {e}"
        logger.error(error_msg)
        try:
            update_garment_status(
                garment_id,
                {"status": "preprocessing_failed", "error_message": error_msg},
            )
        except Exception as db_err:
            logger.error(f"Failed to update error status: {db_err}")

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=error_msg,
        )

    # 6. Upload cutout image to Supabase Storage ({user_id}/{garment_id}_cutout.png)
    # Maintain user folder structure
    clean_storage_path = storage_path.split("?")[0]
    if "/" in clean_storage_path and not clean_storage_path.startswith("http"):
        folder_prefix = clean_storage_path.rsplit("/", 1)[0]
    else:
        folder_prefix = user_id

    cutout_storage_path = f"{folder_prefix}/{garment_id}_cutout.png"

    try:
        upload_cutout_image(cutout_storage_path, cutout_bytes)
    except Exception as e:
        error_msg = f"Failed to upload cutout image to '{cutout_storage_path}': {e}"
        logger.error(error_msg)
        try:
            update_garment_status(
                garment_id,
                {"status": "preprocessing_failed", "error_message": error_msg},
            )
        except Exception as db_err:
            logger.error(f"Failed to update error status: {db_err}")

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=error_msg,
        )

    # 7. Update database record to 'preprocessed'
    update_payload = {
        "status": "preprocessed",
        "cutout_image_url": cutout_storage_path,
        "reference_object_detected": coin_detected,
        "reference_object_pixel_diameter": coin_diameter_px,
        "error_message": None,
    }

    try:
        update_garment_status(garment_id, update_payload)
    except Exception as e:
        logger.error(f"Failed to record final preprocessed status: {e}")
        # Even if DB update fails here, image is processed & uploaded

    # 8. Return JSON Response
    return PreprocessResponse(
        garment_id=garment_id,
        status="preprocessed",
        reference_object_detected=coin_detected,
        reference_object_pixel_diameter=coin_diameter_px,
        cutout_image_url=cutout_storage_path,
    )


class DirectPreprocessRequest(BaseModel):
    """Payload for directly preprocessing an image payload."""
    image_data: str = Field(..., description="DataURL or base64 encoded image string")
    garment_id: Optional[str] = Field(None, description="Optional associated garment identifier")


class DirectPreprocessResponse(BaseModel):
    """Direct preprocessing response with dataURL and metadata."""
    status: str = "preprocessed"
    garment_id: Optional[str] = None
    reference_object_detected: bool = False
    reference_object_pixel_diameter: Optional[float] = None
    cutout_data_url: str = Field(..., description="DataURL of the isolated PNG garment cutout")
    cutout_storage_path: Optional[str] = None


@router.post(
    "/preprocess-image",
    response_model=DirectPreprocessResponse,
    status_code=status.HTTP_200_OK,
    summary="Directly preprocess image bytes with lighting adjustment, object isolation, zoom framing, and rembg",
)
async def preprocess_image_direct(
    payload: DirectPreprocessRequest,
    background_tasks: BackgroundTasks,
) -> DirectPreprocessResponse:
    """Preprocesses an image directly sent from the web or mobile frontend:

    1. Decodes DataURL/base64 string to raw image bytes.
    2. Corrects EXIF orientation and normalizes resolution.
    3. Adjusts light & brightness (LAB adaptive CLAHE + auto-gamma).
    4. Runs neural network background removal (rembg u2netp).
    5. Isolates the main garment object (discarding stray table/background artifacts).
    6. Fits into frame by zoom-cropping around the bounding box.
    7. Detects reference coin via OpenCV HoughCircles.
    8. Encodes cutout to data:image/png;base64,... format for instant display.
    9. Enqueues non-blocking Supabase Storage upload in background tasks.
    """
    import base64

    # 1. Parse raw image bytes
    raw_str = payload.image_data
    if "," in raw_str:
        raw_str = raw_str.split(",", 1)[1]

    try:
        image_bytes = base64.b64decode(raw_str)
    except Exception as e:
        logger.error(f"Failed to decode base64 image data: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid base64 image data: {e}",
        )

    # 2. Run full preprocessing pipeline
    try:
        cutout_bytes, coin_detected, coin_diameter_px = preprocess_and_clean_garment(image_bytes)
    except Exception as e:
        logger.error(f"Image preprocessing pipeline failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI image preprocessing failed: {e}",
        )

    # 3. Convert cutout bytes to DataURL
    b64_cutout = base64.b64encode(cutout_bytes).decode("utf-8")
    cutout_data_url = f"data:image/png;base64,{b64_cutout}"

    # 4. Asynchronous non-blocking background storage sync if garment_id provided
    storage_path = None
    if payload.garment_id:
        storage_path = f"processed/{payload.garment_id}_cutout.png"
        background_tasks.add_task(upload_cutout_image, storage_path, cutout_bytes)

    return DirectPreprocessResponse(
        status="preprocessed",
        garment_id=payload.garment_id,
        reference_object_detected=coin_detected,
        reference_object_pixel_diameter=coin_diameter_px,
        cutout_data_url=cutout_data_url,
        cutout_storage_path=storage_path,
    )

