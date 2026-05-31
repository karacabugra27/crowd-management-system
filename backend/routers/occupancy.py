"""
routers/occupancy.py
--------------------
Doluluk verisi endpoint'leri (live, history, heatmap).
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from database import get_db
from models import Area, HeatmapItem, OccupancyHistoryPoint, OccupancyLive
from services.influx_service import get_influx_service, occupancy_status

router = APIRouter(prefix="/api/occupancy", tags=["occupancy"])


@router.get(
    "/live",
    response_model=list[OccupancyLive],
    summary="Tüm alanların anlık doluluk verisi",
)
def get_live_occupancy(db: Session = Depends(get_db)) -> list[OccupancyLive]:
    """Tüm alanlar için en güncel doluluk ölçümünü döndürür."""
    latest = get_influx_service().get_latest_for_all()
    areas = db.query(Area).order_by(Area.name).all()

    result: list[OccupancyLive] = []
    for area in areas:
        data = latest.get(area.id, {})
        device_count = int(data.get("device_count", 0))
        occupancy_pct = float(data.get("occupancy_pct", 0.0))
        result.append(
            OccupancyLive(
                area_id=area.id,
                area_name=area.name,
                capacity=area.capacity,
                device_count=device_count,
                occupancy_pct=round(occupancy_pct, 2),
                status=occupancy_status(occupancy_pct),
                last_updated=data.get("last_updated"),
            )
        )
    return result


@router.get(
    "/heatmap",
    response_model=list[HeatmapItem],
    summary="Harita için doluluk verisi",
)
def get_heatmap(db: Session = Depends(get_db)) -> list[HeatmapItem]:
    """Tüm alanların koordinat ve doluluk yüzdesini döndürür."""
    latest = get_influx_service().get_latest_for_all()
    areas = db.query(Area).all()

    result: list[HeatmapItem] = []
    for area in areas:
        pct = float(latest.get(area.id, {}).get("occupancy_pct", 0.0))
        result.append(
            HeatmapItem(
                area_id=area.id,
                area_name=area.name,
                latitude=area.latitude,
                longitude=area.longitude,
                occupancy_pct=round(pct, 2),
                status=occupancy_status(pct),
            )
        )
    return result


@router.get(
    "/{area_id}/history",
    response_model=list[OccupancyHistoryPoint],
    summary="Bir alanın son N saatlik doluluk geçmişi",
)
def get_history(
    area_id: str,
    hours: int = Query(24, ge=1, le=168),
    aggregate_minutes: int = Query(5, ge=1, le=60),
    db: Session = Depends(get_db),
) -> list[OccupancyHistoryPoint]:
    """Belirtilen alanın doluluk geçmişini döndürür."""
    area = db.query(Area).filter(Area.id == area_id).first()
    if not area:
        raise HTTPException(status_code=404, detail="Alan bulunamadı")

    return get_influx_service().get_history(
        area_id=area_id, hours=hours, aggregate_minutes=aggregate_minutes
    )
