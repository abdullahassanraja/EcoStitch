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
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from app.services.preprocessing import detect_reference_coin, remove_background
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

    # 4. Run rembg background removal
    try:
        cutout_bytes = remove_background(image_bytes)
    except Exception as e:
        error_msg = f"Background removal failed for garment '{garment_id}': {e}"
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

    # 5. Run reference coin detection pass (OpenCV HoughCircles)
    # Does not fail the request if no coin is found
    coin_detected, coin_diameter_px = detect_reference_coin(image_bytes)

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
