"""ORM model registry — importing this module ensures all tables register on Base."""
from app.models.area import Area
from app.models.occupancy import OccupancyLog
from app.models.user import User
from app.models.scanner import Scanner

__all__ = ["Area", "OccupancyLog", "User", "Scanner"]
