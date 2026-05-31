"""
main.py
-------
FastAPI giriş noktası.

- CORS açık (geliştirme için *; üretimde sıkılaştırılmalı)
- /api/areas, /api/occupancy/*, /api/users/* route'ları
- WebSocket /ws/occupancy — her 30 saniyede güncel doluluk push'u
- Lifespan: DB init + seed + InfluxDB bağlantı kapatma
"""

from __future__ import annotations

import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Set

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from config import get_settings
from database import SessionLocal, init_db
from models import Area
from routers import areas as areas_router
from routers import auth as auth_router
from routers import bluetooth as bluetooth_router
from routers import occupancy as occupancy_router
from routers import users as users_router
from services.influx_service import (
    get_influx_service,
    occupancy_status,
    shutdown_influx_service,
)

_settings = get_settings()
logging.basicConfig(
    level=_settings.log_level.upper(),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("backend")


# ============================================================
# WebSocket bağlantı yöneticisi
# ============================================================
class ConnectionManager:
    """Aktif WebSocket bağlantılarını yönetir."""

    def __init__(self) -> None:
        self.active: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self.active.add(ws)
        logger.info("WS bağlandı, toplam: %d", len(self.active))

    async def disconnect(self, ws: WebSocket) -> None:
        async with self._lock:
            self.active.discard(ws)
        logger.info("WS koptu, toplam: %d", len(self.active))

    async def broadcast(self, message: dict) -> None:
        """Tüm bağlı istemcilere JSON gönderir, kopanları temizler."""
        dead: list[WebSocket] = []
        for ws in list(self.active):
            try:
                await ws.send_json(message)
            except Exception:  # noqa: BLE001
                dead.append(ws)
        if dead:
            async with self._lock:
                for ws in dead:
                    self.active.discard(ws)


manager = ConnectionManager()


async def _broadcast_loop() -> None:
    """Her 30 saniyede tüm bağlı WS istemcilerine doluluk verisi push'lar."""
    while True:
        try:
            if manager.active:
                payload = _build_live_payload()
                await manager.broadcast({"type": "occupancy.live", "data": payload})
        except Exception:  # noqa: BLE001
            logger.exception("Broadcast döngüsü hatası")
        await asyncio.sleep(3)


def _build_live_payload() -> list[dict]:
    """WebSocket broadcast için canlı doluluk verisini hazırlar."""
    latest = get_influx_service().get_latest_for_all()
    db = SessionLocal()
    try:
        areas = db.query(Area).order_by(Area.name).all()
        out: list[dict] = []
        for area in areas:
            data = latest.get(area.id, {})
            pct = float(data.get("occupancy_pct", 0.0))
            out.append(
                {
                    "area_id": area.id,
                    "area_name": area.name,
                    "capacity": area.capacity,
                    "device_count": int(data.get("device_count", 0)),
                    "occupancy_pct": round(pct, 2),
                    "status": occupancy_status(pct),
                    "last_updated": (
                        data.get("last_updated").isoformat()
                        if data.get("last_updated")
                        else None
                    ),
                }
            )
        return out
    finally:
        db.close()


# ============================================================
# Lifespan
# ============================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Uygulama başlangıç/kapanış."""
    logger.info("Backend başlıyor...")
    # DB tablolarını ve seed verisini hazırla (idempotent)
    try:
        init_db()
        logger.info("DB initialize edildi")
    except Exception:  # noqa: BLE001
        logger.exception("DB init hatası — devam ediliyor")

    broadcast_task = asyncio.create_task(_broadcast_loop())
    try:
        yield
    finally:
        broadcast_task.cancel()
        try:
            await broadcast_task
        except asyncio.CancelledError:
            pass
        shutdown_influx_service()
        logger.info("Backend kapatıldı")


# ============================================================
# App
# ============================================================
app = FastAPI(
    title="Akıllı Kampüs Kalabalık Yönetim Sistemi",
    description="Wi-Fi tabanlı kampüs doluluk takibi ve bildirim API'si",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(areas_router.router)
app.include_router(occupancy_router.router)
app.include_router(users_router.router)
app.include_router(bluetooth_router.router)


@app.get("/", tags=["root"])
def root() -> dict:
    """Sağlık ve sürüm bilgisi."""
    return {
        "service": "campus-occupancy-api",
        "version": "1.0.0",
        "status": "ok",
    }


@app.get("/health", tags=["root"])
def health() -> dict:
    """Liveness probe."""
    return {"status": "ok"}


# ============================================================
# WebSocket
# ============================================================
@app.websocket("/ws/occupancy")
async def ws_occupancy(websocket: WebSocket):
    """
    İstemciye her 30 saniyede güncel doluluk verisi push eder.
    İstemci ilk bağlandığında da hemen anlık veri gönderilir.
    """
    await manager.connect(websocket)
    try:
        # İlk anlık veri
        payload = _build_live_payload()
        await websocket.send_json({"type": "occupancy.live", "data": payload})

        # İstemciden ping vb. gelirse okumaya devam et
        while True:
            try:
                await asyncio.wait_for(websocket.receive_text(), timeout=60)
            except asyncio.TimeoutError:
                # Keepalive — sessiz bekle, broadcast loop'u zaten push'luyor
                continue
    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(websocket)
