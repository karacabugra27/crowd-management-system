"""Pydantic schemas for the Area resource."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class AreaBase(BaseModel):
    """Fields shared by create/update/read operations."""

    name: str = Field(..., min_length=1, max_length=100)
    floor: Optional[int] = None
    capacity: int = Field(..., gt=0, description="Maximum device/people count")
    latitude: Optional[float] = Field(default=None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(default=None, ge=-180.0, le=180.0)


class AreaCreate(AreaBase):
    """Payload accepted by `POST /api/areas`."""


class AreaUpdate(BaseModel):
    """Partial update — all fields optional."""

    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    floor: Optional[int] = None
    capacity: Optional[int] = Field(default=None, gt=0)
    latitude: Optional[float] = Field(default=None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(default=None, ge=-180.0, le=180.0)
    is_active: Optional[bool] = None


class AreaRead(AreaBase):
    """Representation returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    is_active: bool
    created_at: datetime
