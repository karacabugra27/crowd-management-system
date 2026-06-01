"""FastAPI application entry point for Smart Campus Crowd Management System."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database_firestore import seed_firestore_areas
from routers.areas import router as areas_router
from routers.occupancy import router as occupancy_router
# from routers.notifications import router as notifications_router
# from routers.websocket_router import router as ws_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown lifecycle."""
    logger.info("🚀 Akıllı Kampüs Kalabalık Yönetim Sistemi başlatılıyor...")
    seed_firestore_areas()
    logger.info("✅ Firestore Veritabanı hazır.")
    yield
    logger.info("🛑 Uygulama kapatılıyor.")

app = FastAPI(
    title="Akıllı Kampüs Kalabalık Yönetim Sistemi",
    description=(
        "Kampüs alanlarının (kütüphane, yemekhane, sınıf, laboratuvar) "
        "Wi-Fi bağlı cihaz sayısından doluluk yüzdesi hesaplayan ve "
        "gerçek zamanlı olarak web/mobil üzerinden sunan sistem."
    ),
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

app.include_router(areas_router)
app.include_router(occupancy_router)
# app.include_router(notifications_router)
# app.include_router(ws_router)

@app.get("/", tags=["root"])
def root():
    return {
        "system": "Akıllı Kampüs Kalabalık Yönetim Sistemi",
        "version": "1.0.0",
        "docs": "/docs",
        "endpoints": {
            "areas": "/areas",
            "live_occupancy": "/occupancy/live",
            "library_occupancy": "/occupancy/library",
            "cafeteria_occupancy": "/occupancy/cafeteria",
            "ingest": "/occupancy/ingest"
        },
    }

@app.get("/health", tags=["root"])
def health():
    return {"status": "healthy"}
