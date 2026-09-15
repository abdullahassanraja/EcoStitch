"""Configuration and Environment Settings for EcoStitch FastAPI Backend."""

import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file from project root
ROOT_DIR = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT_DIR / ".env"

if ENV_PATH.exists():
    load_dotenv(dotenv_path=ENV_PATH)
else:
    load_dotenv()


class Settings:
    """Application settings loaded from environment variables."""

    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://pxwzpklkpbiycslxytqm.supabase.co")
    SUPABASE_ANON_KEY: str = os.getenv(
        "SUPABASE_ANON_KEY",
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4d3pwa2xrcGJpeWNzbHh5dHFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4ODkzNjQsImV4cCI6MjEwNDQ2NTM2NH0.waPaLKcslvzc6SyTIHDHE2TQaIZ1DcjoERVZ3Om2CLI"
    )
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

    # Storage and Table Names
    STORAGE_BUCKET: str = os.getenv("SUPABASE_STORAGE_BUCKET", "garment-images")
    GARMENTS_TABLE: str = os.getenv("SUPABASE_GARMENTS_TABLE", "garments")

    # Server Settings
    PORT: int = int(os.getenv("PORT", "8000"))
    HOST: str = os.getenv("HOST", "0.0.0.0")

    def validate_keys(self) -> None:
        """Validates that critical Supabase credentials are configured."""
        if not self.SUPABASE_URL or "your-project" in self.SUPABASE_URL:
            raise ValueError(
                "SUPABASE_URL is missing or using placeholder in .env. Please set a valid project URL."
            )
        if not self.SUPABASE_SERVICE_ROLE_KEY or "your-supabase-service-role-key" in self.SUPABASE_SERVICE_ROLE_KEY:
            # We log a clear warning rather than terminating on import so tests/app can still bootstrap
            print(
                "[WARNING] SUPABASE_SERVICE_ROLE_KEY is not set or using placeholder in .env! "
                "Supabase operations requiring service_role bypass will fail until you provide your secret key in .env."
            )


settings = Settings()
settings.validate_keys()
