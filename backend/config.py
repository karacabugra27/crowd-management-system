"""
config.py
---------
Uygulama yapılandırması — env değişkenlerinden okur, Pydantic ile doğrular.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Uygulama ayarları (env'den)."""

    # InfluxDB
    influxdb_url: str = "http://influxdb:8086"
    influxdb_token: str = ""
    influxdb_org: str = "campus"
    influxdb_bucket: str = "occupancy"

    # PostgreSQL
    postgres_url: str = "postgresql://campus:campuspass@postgres:5432/campus"

    # Redis / Celery
    redis_url: str = "redis://redis:6379/0"
    celery_broker_url: str = "redis://redis:6379/0"
    celery_result_backend: str = "redis://redis:6379/1"

    # Firebase
    firebase_credentials_path: str = "/app/firebase-credentials.json"

    # Bildirimler
    notification_cooldown_minutes: int = 15
    notification_check_interval_seconds: int = 60

    # JWT
    secret_key: str = "change-me-in-production-use-a-long-random-string"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 7

    # Loglama
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Tek bir Settings örneği döner (cached)."""
    return Settings()
