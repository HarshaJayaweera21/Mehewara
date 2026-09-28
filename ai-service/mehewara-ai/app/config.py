"""
Mehewara AI Service — Centralized Configuration

Uses pydantic-settings to load environment variables from .env file
with type validation and sensible defaults.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # --- LLM Configuration ---
    gemini_api_key: str = "not-set"
    gemini_model: str = "gemini-3.5-flash-lite"

    # --- ASP.NET Core Backend ---
    dotnet_api_base_url: str = "http://localhost:5194"

    internal_ai_api_key: str = ""
    agent4_evidence_timeout_seconds: float = Field(default=10, gt=0, allow_inf_nan=False)
    agent4_review_timeout_seconds: float = Field(default=30, gt=0, allow_inf_nan=False)

    # --- Service Configuration ---
    port: int = 8000
    environment: str = "development"
    cors_origins: str = "http://localhost:5173,http://localhost:5194"

    @property
    def is_development(self) -> bool:
        return self.environment == "development"

    @property
    def cors_origin_list(self) -> list[str]:
        """Parse comma-separated CORS origins into a list."""
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


# Singleton settings instance — import this throughout the app
settings = Settings()
