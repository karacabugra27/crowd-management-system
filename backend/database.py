from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime

import os

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./campus_crowd.db")

if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
else:
    engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Area(Base):
    __tablename__ = "areas"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    short_name = Column(String, nullable=False)
    capacity = Column(Integer, nullable=False)
    floor = Column(String, nullable=False, default="Zemin")
    building = Column(String, nullable=False)
    icon = Column(String, nullable=False, default="📍")
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    is_active = Column(Boolean, default=True)

    records = relationship("OccupancyRecord", back_populates="area")
    subscriptions = relationship("NotificationSubscription", back_populates="area")


class OccupancyRecord(Base):
    __tablename__ = "occupancy_records"

    id = Column(Integer, primary_key=True, index=True)
    area_id = Column(Integer, ForeignKey("areas.id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    device_count = Column(Integer, nullable=False)
    occupancy_pct = Column(Float, nullable=False)

    area = relationship("Area", back_populates="records")


class NotificationSubscription(Base):
    __tablename__ = "notification_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    fcm_token = Column(String, nullable=False)
    area_id = Column(Integer, ForeignKey("areas.id"), nullable=False)
    threshold_pct = Column(Float, nullable=False, default=80.0)
    direction = Column(String, nullable=False, default="above")  # 'above' | 'below'
    created_at = Column(DateTime, default=datetime.utcnow)

    area = relationship("Area", back_populates="subscriptions")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    Base.metadata.create_all(bind=engine)
