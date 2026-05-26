"""/api/scanner — endpoints called by physical scanner devices."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_scanner_by_api_key
from app.models.scanner import Scanner
from app.schemas.occupancy import OccupancyResult, ScannerData
from app.services import occupancy_service

router = APIRouter(prefix="/api/scanner", tags=["scanner"])


@router.post(
    "/data",
    response_model=OccupancyResult,
    summary="Ingest a batch of MAC hashes from an authenticated scanner",
)
async def ingest_scanner_data(
    payload: ScannerData,
    db: AsyncSession = Depends(get_db),
    scanner: Scanner = Depends(get_scanner_by_api_key),
) -> OccupancyResult:
    """Convert MAC hashes into a device count, persist, and broadcast."""
    return await occupancy_service.record_scanner_reading(
        db, area_id=payload.area_id, mac_hashes=payload.mac_hashes
    )
