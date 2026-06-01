"""WebSocket router — real-time occupancy broadcast."""
import asyncio
import json
import logging
from datetime import datetime
from typing import List

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from sqlalchemy import desc

from database import SessionLocal, Area, OccupancyRecord
from services.occupancy_calculator import get_occupancy_status, get_occupancy_color

logger = logging.getLogger(__name__)
router = APIRouter(tags=["websocket"])

# Connection manager for broadcasting to all connected clients
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"🔌 WS bağlantısı kuruldu. Toplam: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        logger.info(f"🔌 WS bağlantısı kesildi. Toplam: {len(self.active_connections)}")

    async def broadcast(self, message: dict):
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(json.dumps(message, default=str))
            except Exception:
                disconnected.append(connection)
        for conn in disconnected:
            self.active_connections.remove(conn)


manager = ConnectionManager()


def _build_live_payload(db: Session) -> dict:
    """Build the current live occupancy payload for broadcasting."""
    areas = db.query(Area).filter(Area.is_active == True).all()
    data = []

    for area in areas:
        latest = (
            db.query(OccupancyRecord)
            .filter(OccupancyRecord.area_id == area.id)
            .order_by(desc(OccupancyRecord.timestamp))
            .first()
        )
        if latest:
            data.append({
                "area_id": area.id,
                "area_name": area.name,
                "short_name": area.short_name,
                "building": area.building,
                "icon": area.icon,
                "capacity": area.capacity,
                "device_count": latest.device_count,
                "occupancy_pct": latest.occupancy_pct,
                "status": get_occupancy_status(latest.occupancy_pct),
                "color": get_occupancy_color(latest.occupancy_pct),
                "last_updated": latest.timestamp.isoformat(),
            })

    return {
        "type": "occupancy_update",
        "timestamp": datetime.utcnow().isoformat(),
        "data": data,
    }


@router.websocket("/ws/live")
async def websocket_live(websocket: WebSocket):
    """WebSocket endpoint — sends live occupancy data every 10 seconds."""
    await manager.connect(websocket)
    try:
        # Send immediate snapshot on connect
        db = SessionLocal()
        try:
            payload = _build_live_payload(db)
            await websocket.send_text(json.dumps(payload, default=str))
        finally:
            db.close()

        # Keep-alive loop — broadcast every 10 seconds
        while True:
            await asyncio.sleep(10)
            db = SessionLocal()
            try:
                payload = _build_live_payload(db)
                await websocket.send_text(json.dumps(payload, default=str))
            finally:
                db.close()

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WS error: {e}")
        manager.disconnect(websocket)


async def broadcast_update():
    """Called externally after a new ingest to push updates immediately."""
    if not manager.active_connections:
        return
    db = SessionLocal()
    try:
        payload = _build_live_payload(db)
        await manager.broadcast(payload)
    finally:
        db.close()
