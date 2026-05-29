"""Pydantic schemas for scanner administration."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class ScannerCreate(BaseModel):
    """Payload to register a new scanner."""

    name: str = Field(..., min_length=1, max_length=100)
    area_id: Optional[int] = Field(default=None, gt=0)


class ScannerRead(BaseModel):
    """Scanner representation — never returns the API key."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: Optional[str] = None
    area_id: Optional[int] = None
    last_seen: Optional[datetime] = None
    is_active: bool


class ScannerCreated(BaseModel):
    """Returned only once at creation time — contains the plaintext API key."""

    id: int
    name: Optional[str] = None
    api_key: str
