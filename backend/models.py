"""
models.py
---------
SQLAlchemy ORM modelleri ve Pydantic şemaları.

ORM modelleri (PostgreSQL):
  - Area: kampüs alan tanımları
  - User: FCM token sahibi kullanıcı
  - NotificationPreference: kullanıcı bildirim tercihleri
  - NotificationLog: gönderilen bildirim kaydı (cooldown için)

Pydantic şemaları (API request/response):
  - AreaOut, OccupancyLive, OccupancyHistoryPoint, HeatmapItem,
    UserRegisterRequest, PreferenceItem, PreferencesUpdateRequest,
    UserOut, NotificationOut
"""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from database import Base


# ============================================================
# ORM Modelleri
# ============================================================


class Area(Base):
    """Bir kampüs alanı (kütüphane, yemekhane, sınıf, lab)."""

    __tablename__ = "areas"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    capacity = Column(Integer, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    floor = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class User(Base):
    """FCM token sahibi mobil kullanıcı."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    fcm_token = Column(String, unique=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    preferences = relationship(
        "NotificationPreference",
        back_populates="user",
        cascade="all, delete-orphan",
    )


class NotificationPreference(Base):
    """Kullanıcının bir alan için bildirim eşiği."""

    __tablename__ = "notification_preferences"
    __table_args__ = (UniqueConstraint("user_id", "area_id", name="uq_user_area"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    area_id = Column(
        String, ForeignKey("areas.id", ondelete="CASCADE"), nullable=False
    )
    threshold_pct = Column(Integer, nullable=False, default=80)
    notify_when = Column(String, nullable=False, default="above")  # "above" | "below"
    enabled = Column(Integer, nullable=False, default=1)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="preferences")


class NotificationLog(Base):
    """Gönderilen bildirim kaydı — cooldown ve audit için."""

    __tablename__ = "notification_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    area_id = Column(String, ForeignKey("areas.id", ondelete="CASCADE"))
    occupancy_pct = Column(Float, nullable=False)
    message = Column(String, nullable=False)
    sent_at = Column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )


# ============================================================
# Pydantic Şemaları
# ============================================================

OccupancyStatus = Literal["empty", "low", "medium", "high", "full"]


class AreaOut(BaseModel):
    """API yanıtında alan bilgisi."""

    id: str
    name: str
    capacity: int
    latitude: float
    longitude: float
    floor: int

    model_config = ConfigDict(from_attributes=True)


class OccupancyLive(BaseModel):
    """Bir alanın anlık doluluk verisi."""

    area_id: str
    area_name: str
    capacity: int
    device_count: int
    occupancy_pct: float
    status: OccupancyStatus
    last_updated: datetime | None


class OccupancyHistoryPoint(BaseModel):
    """Geçmiş doluluk veri noktası."""

    timestamp: datetime
    device_count: int
    occupancy_pct: float


class HeatmapItem(BaseModel):
    """Harita için renk kodlu doluluk öğesi."""

    area_id: str
    area_name: str
    latitude: float
    longitude: float
    occupancy_pct: float
    status: OccupancyStatus


class PreferenceItem(BaseModel):
    """Tek bir alan için bildirim tercihi."""

    area_id: str
    threshold_pct: int = Field(ge=0, le=100)
    notify_when: Literal["above", "below"] = "above"
    enabled: bool = True


class UserRegisterRequest(BaseModel):
    """Kullanıcı kayıt isteği."""

    fcm_token: str = Field(min_length=8)
    preferences: list[PreferenceItem] = Field(default_factory=list)


class PreferencesUpdateRequest(BaseModel):
    """Bildirim tercihleri güncelleme."""

    fcm_token: str
    preferences: list[PreferenceItem]


class UserOut(BaseModel):
    """API yanıtında kullanıcı bilgisi."""

    id: int
    fcm_token: str
    preferences: list[PreferenceItem]


class NotificationOut(BaseModel):
    """Gönderilen bildirim kaydı yanıtı."""

    area_id: str
    occupancy_pct: float
    message: str
    sent_at: datetime
