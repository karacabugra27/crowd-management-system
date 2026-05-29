"""Tests for /api/occupancy — live, history, heatmap."""
import hashlib

import pytest

from app.models.area import Area
from app.models.occupancy import OccupancyLog
from app.models.scanner import Scanner


def _hash(mac: str) -> str:
    return hashlib.sha256(mac.encode()).hexdigest()


async def _seed(session_factory, *, capacity: int = 100) -> tuple[int, str]:
    async with session_factory() as s:
        area = Area(
            name="Atrium",
            capacity=capacity,
            is_active=True,
            latitude=41.0,
            longitude=29.0,
        )
        s.add(area)
        await s.flush()
        sc = Scanner(name="sc", api_key="k1", area_id=area.id)
        s.add(sc)
        await s.commit()
        return area.id, sc.api_key


@pytest.mark.asyncio
async def test_live_empty_when_no_logs(client, session_factory):
    area_id, _ = await _seed(session_factory)
    resp = await client.get("/api/occupancy/live")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    assert body[0]["area_id"] == area_id
    assert body[0]["device_count"] == 0
    assert body[0]["status"] == "empty"


@pytest.mark.asyncio
async def test_live_reflects_latest_log(client, session_factory):
    area_id, api_key = await _seed(session_factory, capacity=20)
    hashes = [_hash(f"x{i}") for i in range(13)]  # 65% → medium

    post = await client.post(
        "/api/scanner/data",
        headers={"X-API-Key": api_key},
        json={"area_id": area_id, "mac_hashes": hashes},
    )
    assert post.status_code == 200

    one = await client.get(f"/api/occupancy/live/{area_id}")
    assert one.status_code == 200
    body = one.json()
    assert body["device_count"] == 13
    assert body["status"] == "medium"


@pytest.mark.asyncio
async def test_history_returns_recent(client, session_factory):
    area_id, api_key = await _seed(session_factory, capacity=10)
    for _ in range(3):
        await client.post(
            "/api/scanner/data",
            headers={"X-API-Key": api_key},
            json={"area_id": area_id, "mac_hashes": [_hash("a")]},
        )

    hist = await client.get(f"/api/occupancy/history/{area_id}?hours=1")
    assert hist.status_code == 200
    assert len(hist.json()) == 3


@pytest.mark.asyncio
async def test_heatmap_includes_geolocation(client, session_factory):
    await _seed(session_factory)
    resp = await client.get("/api/occupancy/heatmap")
    assert resp.status_code == 200
    body = resp.json()
    assert body[0]["latitude"] == 41.0
    assert body[0]["longitude"] == 29.0


@pytest.mark.asyncio
async def test_live_for_unknown_area_is_404(client):
    resp = await client.get("/api/occupancy/live/9999")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_history_hours_must_be_positive(client, session_factory):
    area_id, _ = await _seed(session_factory)
    resp = await client.get(f"/api/occupancy/history/{area_id}?hours=0")
    assert resp.status_code == 422
