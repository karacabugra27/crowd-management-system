"""Tests for /api/scanner — API-key auth, occupancy math, broadcast."""
import hashlib

import pytest

from app.models.area import Area
from app.models.scanner import Scanner


def _hash(mac: str) -> str:
    return hashlib.sha256(mac.encode()).hexdigest()


async def _seed_area_and_scanner(
    session_factory, capacity: int = 100
) -> tuple[int, str]:
    async with session_factory() as s:
        area = Area(name="Hall", capacity=capacity, is_active=True)
        s.add(area)
        await s.flush()
        scanner = Scanner(name="sc-1", api_key="test-api-key", area_id=area.id)
        s.add(scanner)
        await s.commit()
        return area.id, scanner.api_key


@pytest.mark.asyncio
async def test_scanner_requires_api_key(client):
    resp = await client.post(
        "/api/scanner/data",
        json={"area_id": 1, "mac_hashes": [_hash("aa")]},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_scanner_data_persists_and_returns_status(client, session_factory):
    area_id, api_key = await _seed_area_and_scanner(session_factory, capacity=10)
    hashes = [_hash(f"aa:bb:cc:{i:02x}") for i in range(8)]  # 80% → high

    resp = await client.post(
        "/api/scanner/data",
        headers={"X-API-Key": api_key},
        json={"area_id": area_id, "mac_hashes": hashes},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["area_id"] == area_id
    assert body["device_count"] == 8
    assert body["occupancy_pct"] == 80.0
    assert body["status"] == "high"


@pytest.mark.asyncio
async def test_duplicate_hashes_are_deduplicated(client, session_factory):
    area_id, api_key = await _seed_area_and_scanner(session_factory, capacity=10)
    same = _hash("aa")
    resp = await client.post(
        "/api/scanner/data",
        headers={"X-API-Key": api_key},
        json={"area_id": area_id, "mac_hashes": [same, same, same]},
    )
    assert resp.status_code == 200
    assert resp.json()["device_count"] == 1


@pytest.mark.asyncio
async def test_invalid_hash_format_rejected(client, session_factory):
    _, api_key = await _seed_area_and_scanner(session_factory)
    resp = await client.post(
        "/api/scanner/data",
        headers={"X-API-Key": api_key},
        json={"area_id": 1, "mac_hashes": ["not-a-hash"]},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_status_classification_boundaries():
    from app.services.occupancy_service import classify_status

    assert classify_status(0) == "empty"
    assert classify_status(30) == "empty"
    assert classify_status(31) == "low"
    assert classify_status(60) == "low"
    assert classify_status(61) == "medium"
    assert classify_status(75) == "medium"
    assert classify_status(76) == "high"
    assert classify_status(90) == "high"
    assert classify_status(91) == "full"
    assert classify_status(100) == "full"
