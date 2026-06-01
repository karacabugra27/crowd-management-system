"""FastAPI application entry point."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware


class _HealthAccessFilter(logging.Filter):
    """Drop uvicorn access-log lines for the noisy /health probe."""

    def filter(self, record: logging.LogRecord) -> bool:
        msg = record.getMessage()
        return "/health" not in msg


logging.getLogger("uvicorn.access").addFilter(_HealthAccessFilter())

from app.config import settings
from app.core.rate_limiter import limiter
from app.routers import admin, areas, auth, occupancy, scanner, users, websocket


@asynccontextmanager
async def lifespan(app: FastAPI):
    """App startup/shutdown hook — currently a no-op placeholder."""
    yield


def create_app() -> FastAPI:
    """Build and configure the FastAPI app."""
    app = FastAPI(
        title=settings.APP_NAME,
        version="1.0.0",
        description="Smart campus crowd management API",
        lifespan=lifespan,
    )

    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    app.add_middleware(SlowAPIMiddleware)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router)
    app.include_router(scanner.router)
    app.include_router(areas.router)
    app.include_router(occupancy.router)
    app.include_router(users.router)
    app.include_router(admin.router)
    app.include_router(websocket.router)

    @app.get("/health", tags=["meta"])
    async def health() -> dict:
        """Liveness probe."""
        return {"status": "ok", "app": settings.APP_NAME}

    return app


app = create_app()
