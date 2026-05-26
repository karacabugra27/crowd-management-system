"""Pydantic schemas for occupancy reporting and queries."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ScannerData(BaseModel):
    """Payload posted by a scanner. `mac_hashes` are already SHA-256 hex digests."""

    area_id: int = Field(..., gt=0)
    mac_hashes: List[str] = Field(
        default_factory=list,
        description="SHA-256 hex digests of detected MAC addresses",
    )

    @field_validator("mac_hashes")
    @classmethod
    def _validate_hashes(cls, v: List[str]) -> List[str]:
        """Reject anything that does not look like a SHA-256 hex digest."""
        for h in v:
            if not isinstance(h, str) or len(h) != 64:
                raise ValueError("mac_hashes must be 64-char SHA-256 hex digests")
            try:
                int(h, 16)
            except ValueError as exc:
                raise ValueError("mac_hashes must be hex strings") from exc
        return v


class OccupancyResult(BaseModel):
    """Snapshot returned after a scanner submission."""

    area_id: int
    device_count: int
    occupancy_pct: float
    status: str


class LiveOccupancy(BaseModel):
    """Live occupancy entry — one per area."""

    model_config = ConfigDict(from_attributes=True)

    area_id: int
    area_name: str
    device_count: int
    occupancy_pct: float
    status: str
    last_updated: Optional[datetime] = None


class OccupancyHistoryEntry(BaseModel):
    """Single historical reading."""

    model_config = ConfigDict(from_attributes=True)

    recorded_at: datetime
    device_count: int
    occupancy_pct: float
    status: str


class HeatmapEntry(BaseModel):
    """Map-ready entry combining geolocation + current occupancy."""

    area_id: int
    area_name: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    occupancy_pct: float
    status: str


class OccupancySummary(BaseModel):
    """Aggregate stats for the lifetime of an area."""

    area_id: int
    area_name: str
    avg_occupancy: float
    max_occupancy: float
    peak_hour: Optional[int] = None
    total_records: int
