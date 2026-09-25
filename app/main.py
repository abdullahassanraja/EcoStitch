"""EcoStitch FastAPI Application.

Main entrypoint for the garment transformation & upcycling backend.
Step 3 Preprocessing pipeline:
  POST /garments/{garment_id}/preprocess
"""

import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.routers import garments

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

logger = logging.getLogger("ecostitch.main")

app = FastAPI(
    title="EcoStitch Garment Preprocessing API",
    description=(
        "Backend service for EcoStitch sustainable garment transformation. "
        "Handles background removal via rembg, OpenCV reference coin detection, "
        "and Supabase Storage & Database synchronization."
    ),
    version="1.0.0",
)

# Enable CORS for frontend applications (Flutter web, local dev, mobile emulators)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Routers
app.include_router(garments.router)


@app.on_event("startup")
async def startup_event():
    """Pre-warms the rembg neural network session so first user inference has zero latency."""
    logger.info("Pre-warming rembg neural network session for instant zero-latency processing...")
    from app.services.preprocessing import get_rembg_session
    try:
        get_rembg_session()
        logger.info("rembg session pre-warmed and ready!")
    except Exception as e:
        logger.warning(f"rembg pre-warm notice: {e}")


@app.get("/", tags=["General"])
async def root():
    """Root metadata endpoint."""
    return {
        "service": "EcoStitch Preprocessing API",
        "version": "1.0.0",
        "status": "online",
        "docs": "/docs",
    }


@app.get("/health", tags=["General"])
async def health_check():
    """Health check endpoint validating service configuration."""
    has_service_key = (
        bool(settings.SUPABASE_SERVICE_ROLE_KEY)
        and "your-supabase-service-role-key" not in settings.SUPABASE_SERVICE_ROLE_KEY
    )
    return {
        "status": "healthy",
        "supabase_configured": has_service_key,
        "supabase_url": settings.SUPABASE_URL,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
    )
