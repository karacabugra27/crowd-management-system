"""Tests for /api/areas — public reads, admin-gated writes."""
import pytest


@pytest.mark.asyncio
async def test_list_empty(client):
    resp = await client.get("/api/areas/")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_create_requires_admin(client):
    # No token at all — should be 401
    resp = await client.post(
        "/api/areas/",
        json={"name": "Library", "floor": 1, "capacity": 100},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_admin_can_create_and_read(admin_client):
    resp = await admin_client.post(
        "/api/areas/",
        json={
            "name": "Library",
            "floor": 1,
            "capacity": 100,
            "latitude": 41.0,
            "longitude": 29.0,
        },
    )
    assert resp.status_code == 201, resp.text
    area = resp.json()
    assert area["id"] >= 1
    assert area["name"] == "Library"
    assert area["is_active"] is True

    listing = await admin_client.get("/api/areas/")
    assert listing.status_code == 200
    assert len(listing.json()) == 1


@pytest.mark.asyncio
async def test_update_and_toggle_active(admin_client):
    created = await admin_client.post(
        "/api/areas/", json={"name": "Lab", "capacity": 50}
    )
    area_id = created.json()["id"]

    upd = await admin_client.put(
        f"/api/areas/{area_id}", json={"capacity": 75, "floor": 2}
    )
    assert upd.status_code == 200
    assert upd.json()["capacity"] == 75
    assert upd.json()["floor"] == 2

    tog = await admin_client.patch(f"/api/areas/{area_id}/toggle-active")
    assert tog.status_code == 200
    assert tog.json()["is_active"] is False


@pytest.mark.asyncio
async def test_delete_area(admin_client):
    created = await admin_client.post(
        "/api/areas/", json={"name": "Cafe", "capacity": 30}
    )
    area_id = created.json()["id"]

    delete = await admin_client.delete(f"/api/areas/{area_id}")
    assert delete.status_code == 204

    missing = await admin_client.get(f"/api/areas/{area_id}")
    assert missing.status_code == 404


@pytest.mark.asyncio
async def test_capacity_must_be_positive(admin_client):
    resp = await admin_client.post(
        "/api/areas/", json={"name": "Bad", "capacity": 0}
    )
    assert resp.status_code == 422
