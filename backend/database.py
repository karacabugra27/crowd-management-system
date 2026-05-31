"""
database.py
-----------
PostgreSQL bağlantısı, SQLAlchemy session yönetimi ve seed verisi.
"""

from __future__ import annotations

from contextlib import contextmanager
from typing import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from config import get_settings

settings = get_settings()

engine = create_engine(
    settings.postgres_url,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency — request bazlı DB session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@contextmanager
def session_scope() -> Generator[Session, None, None]:
    """Celery / script kullanımı için context manager session."""
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


def init_db() -> None:
    """
    Veritabanı tablolarını oluşturur ve seed verisini yükler.
    Idempotent — birden fazla çağırılabilir.
    """
    from models import Area  # geç import (döngüsel bağımlılık önleme)

    Base.metadata.create_all(bind=engine)

    # Seed: İnönü Üniversitesi Battalgazi Kampüsü, Malatya
    seed_areas = [
        {
            "id": "kutuphane",
            "name": "Merkez Kütüphane",
            "capacity": 300,
            "latitude": 38.3334154152037,
            "longitude": 38.43970380767402,
            "floor": 1,
        },
        {
            "id": "yemekhane",
            "name": "Yaşam Merkezi Yemekhane",
            "capacity": 250,
            "latitude": 38.33149165728883,
            "longitude": 38.43520602908551,
            "floor": 0,
        },
        {
            "id": "sinif_a",
            "name": "Botanik Cafe",
            "capacity": 80,
            "latitude": 38.33105739256537,
            "longitude": 38.44714016205789,
            "floor": 0,
        },
        {
            "id": "sinif_b",
            "name": "Esenlik Market",
            "capacity": 60,
            "latitude": 38.33102796418538,
            "longitude": 38.44461414379356,
            "floor": 0,
        },
        {
            "id": "laboratuvar",
            "name": "Bilgisayar Mühendisliği Lab",
            "capacity": 40,
            "latitude": 38.3322,
            "longitude": 38.4410,
            "floor": 2,
        },
    ]

    with session_scope() as db:
        existing = {a.id for a in db.query(Area).all()}
        for data in seed_areas:
            if data["id"] in existing:
                continue
            db.add(Area(**data))
