"""Supabase Client Service for EcoStitch.

Initializes the Supabase client using the service_role secret key to bypass Row-Level Security
for trusted server-side operations (Storage downloads, cutouts, and status updates).
"""

from typing import Any, Dict, Optional
from supabase import Client, create_client
from app.config import settings

_supabase_client: Optional[Client] = None


def get_supabase_client() -> Client:
    """Returns the singleton Supabase client initialized with the service_role key."""
    global _supabase_client
    if _supabase_client is None:
        if not settings.SUPABASE_SERVICE_ROLE_KEY:
            raise ValueError(
                "SUPABASE_SERVICE_ROLE_KEY is required to initialize the backend Supabase client. "
                "Please configure it in your .env file."
            )
        _supabase_client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    return _supabase_client


def get_garment_by_id(garment_id: str) -> Optional[Dict[str, Any]]:
    """Fetches a garment row from the garments table by ID.

    Returns None if the record does not exist.
    """
    client = get_supabase_client()
    try:
        response = (
            client.from_(settings.GARMENTS_TABLE)
            .select("*")
            .eq("id", garment_id)
            .maybe_single()
            .execute()
        )
        return response.data
    except Exception as e:
        raise RuntimeError(f"Database error while querying garment '{garment_id}': {e}") from e


def update_garment_status(garment_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
    """Updates a garment record in the garments table with the provided fields."""
    client = get_supabase_client()
    try:
        response = (
            client.from_(settings.GARMENTS_TABLE)
            .update(updates)
            .eq("id", garment_id)
            .execute()
        )
        if response.data and len(response.data) > 0:
            return response.data[0]
        return updates
    except Exception as e:
        raise RuntimeError(f"Database error while updating garment '{garment_id}': {e}") from e


def download_garment_image(storage_path: str) -> bytes:
    """Downloads raw image bytes from the garment-images bucket given its storage path.

    Supports relative path (e.g. "{user_id}/{filename}.jpg") or full Supabase URL.
    """
    client = get_supabase_client()
    
    # Clean storage path if a full public or signed URL was stored
    clean_path = storage_path
    if clean_path.startswith("http://") or clean_path.startswith("https://"):
        marker = f"/{settings.STORAGE_BUCKET}/"
        if marker in clean_path:
            clean_path = clean_path.split(marker, 1)[1].split("?")[0]

    try:
        # download returns raw bytes
        image_bytes = client.storage.from_(settings.STORAGE_BUCKET).download(clean_path)
        if not image_bytes:
            raise ValueError(f"Downloaded empty file from storage path: {clean_path}")
        return image_bytes
    except Exception as e:
        raise RuntimeError(
            f"Failed to download image from Supabase Storage bucket '{settings.STORAGE_BUCKET}' "
            f"at path '{clean_path}': {e}"
        ) from e


def upload_cutout_image(storage_path: str, image_bytes: bytes) -> str:
    """Uploads background-removed PNG cutout bytes to Supabase Storage.

    E.g. storage_path: "{user_id}/{garment_id}_cutout.png"
    """
    client = get_supabase_client()
    try:
        client.storage.from_(settings.STORAGE_BUCKET).upload(
            path=storage_path,
            file=image_bytes,
            file_options={"content-type": "image/png", "upsert": "true"},
        )
        return storage_path
    except Exception as e:
        raise RuntimeError(
            f"Failed to upload cutout image to Supabase Storage at '{storage_path}': {e}"
        ) from e
