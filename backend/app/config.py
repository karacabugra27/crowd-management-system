"""Application configuration loaded from environment variables.

All settings are validated by Pydantic Settings; reading from a `.env`
file is supported for local development.
"""
from functools import lru_cache
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the API."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Database
    DATABASE_URL: str = Field(
        default="postgresql+asyncpg://user:pass@postgres:5432/campus",
        description="Async SQLAlchemy DSN",
    )

    # JWT / Security
    SECRET_KEY: str = Field(default="change-me-in-production")
    ALGORITHM: str = Field(default="HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=30)
    REFRESH_TOKEN_EXPIRE_DAYS: int = Field(default=7)

    # App
    APP_NAME: str = Field(default="Crowd Management API")
    APP_ENV: str = Field(default="development")
    CORS_ORIGINS: str = Field(
        default="*",
        description="Comma-separated origins or '*'. Parsed via `cors_origins` property.",
    )

    # Rate limiting
    RATE_LIMIT_PER_MINUTE: int = Field(default=60)

    @property
    def cors_origins(self) -> List[str]:
        """Return CORS origins as a list."""
        raw = self.CORS_ORIGINS.strip()
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()


settings = get_settings()
