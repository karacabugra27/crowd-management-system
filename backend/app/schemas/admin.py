"""Pydantic schemas for the admin dashboard."""
from typing import Optional

from pydantic import BaseModel


class AreaOccupancyRef(BaseModel):
    area_id: int
    area_name: str
    occupancy_pct: float


class DashboardStats(BaseModel):
    total_areas: int
    active_areas: int
    total_users: int
    avg_occupancy: float
    busiest_area: Optional[AreaOccupancyRef] = None
    emptiest_area: Optional[AreaOccupancyRef] = None
