"""Unit and integration tests for the Campus Crowd Management API."""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Use in-memory SQLite for tests
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from database import Base, get_db
from main import app

# In-memory test database
TEST_DB_URL = "sqlite:///:memory:"
test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=test_engine)
    app.dependency_overrides[get_db] = override_get_db
    yield
    Base.metadata.drop_all(bind=test_engine)
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def seeded_client(client):
    """Client with seeded area data."""
    from database import Area
    db = TestSessionLocal()
    area = Area(
        name="Test Kütüphane",
        short_name="Test Kütüphane",
        capacity=100,
        floor="1. Kat",
        building="Test Bina",
        icon="📚",
    )
    db.add(area)
    db.commit()
    db.close()
    return client


# ── Root & Health ────────────────────────────────────────────────

def test_root(client):
    res = client.get("/")
    assert res.status_code == 200
    data = res.json()
    assert "system" in data
    assert "Kampüs" in data["system"] or "Campus" in data["system"] or "Akıllı" in data["system"]


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "healthy"


# ── Areas ────────────────────────────────────────────────────────

def test_list_areas_empty(client):
    res = client.get("/areas/")
    assert res.status_code == 200
    assert res.json() == []


def test_list_areas_with_data(seeded_client):
    res = seeded_client.get("/areas/")
    assert res.status_code == 200
    areas = res.json()
    assert len(areas) == 1
    assert areas[0]["name"] == "Test Kütüphane"
    assert areas[0]["capacity"] == 100


def test_get_area_not_found(client):
    res = client.get("/areas/9999")
    assert res.status_code == 404


def test_get_area_found(seeded_client):
    areas = seeded_client.get("/areas/").json()
    area_id = areas[0]["id"]
    res = seeded_client.get(f"/areas/{area_id}")
    assert res.status_code == 200
    assert res.json()["name"] == "Test Kütüphane"


# ── Occupancy ────────────────────────────────────────────────────

def test_live_occupancy_empty(client):
    res = client.get("/occupancy/live")
    assert res.status_code == 200
    assert res.json() == []


def test_ingest_and_live(seeded_client):
    areas = seeded_client.get("/areas/").json()
    area_id = areas[0]["id"]

    # Ingest a reading
    res = seeded_client.post("/occupancy/ingest", json={"area_id": area_id, "device_count": 50})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert data["occupancy_pct"] == 50.0  # 50/100 * 100

    # Live should now show this area
    live = seeded_client.get("/occupancy/live").json()
    assert len(live) == 1
    assert live[0]["device_count"] == 50
    assert live[0]["occupancy_pct"] == 50.0
    assert live[0]["color"] == "yellow"
    assert live[0]["status"] == "Orta"


def test_ingest_bulk(seeded_client):
    areas = seeded_client.get("/areas/").json()
    area_id = areas[0]["id"]

    res = seeded_client.post("/occupancy/ingest/bulk", json=[
        {"area_id": area_id, "device_count": 90},
    ])
    assert res.status_code == 200
    results = res.json()
    assert results[0]["status"] == "ok"
    assert results[0]["occupancy_pct"] == 90.0


def test_ingest_invalid_area(client):
    res = client.post("/occupancy/ingest", json={"area_id": 9999, "device_count": 10})
    assert res.status_code == 404


def test_history_requires_area(seeded_client):
    res = seeded_client.get("/occupancy/history?days=7")
    assert res.status_code == 400


def test_history_returns_data(seeded_client):
    areas = seeded_client.get("/areas/").json()
    area_id = areas[0]["id"]
    seeded_client.post("/occupancy/ingest", json={"area_id": area_id, "device_count": 30})

    res = seeded_client.get(f"/occupancy/history?area_id={area_id}&days=1")
    assert res.status_code == 200
    history = res.json()
    assert len(history) == 1
    assert history[0]["device_count"] == 30


# ── Notifications ────────────────────────────────────────────────

def test_subscribe(seeded_client):
    areas = seeded_client.get("/areas/").json()
    area_id = areas[0]["id"]

    res = seeded_client.post("/notifications/subscribe", json={
        "fcm_token":     "test-token-123",
        "area_id":       area_id,
        "threshold_pct": 70.0,
        "direction":     "above",
    })
    assert res.status_code == 200
    data = res.json()
    assert data["threshold_pct"] == 70.0
    assert data["direction"] == "above"
    assert data["area_name"] == "Test Kütüphane"


def test_subscribe_invalid_direction(seeded_client):
    areas = seeded_client.get("/areas/").json()
    res = seeded_client.post("/notifications/subscribe", json={
        "fcm_token":     "test-token",
        "area_id":       areas[0]["id"],
        "threshold_pct": 70.0,
        "direction":     "sideways",  # invalid
    })
    assert res.status_code == 400


def test_unsubscribe(seeded_client):
    areas = seeded_client.get("/areas/").json()
    area_id = areas[0]["id"]

    sub = seeded_client.post("/notifications/subscribe", json={
        "fcm_token":     "test-token-del",
        "area_id":       area_id,
        "threshold_pct": 50.0,
        "direction":     "below",
    }).json()

    res = seeded_client.delete(f"/notifications/subscribe/{sub['id']}")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


# ── Occupancy Calculator ─────────────────────────────────────────

def test_occupancy_calculation():
    from services.occupancy_calculator import calculate_occupancy, get_occupancy_status, get_occupancy_color

    assert calculate_occupancy(0, 100)   == 0.0
    assert calculate_occupancy(50, 100)  == 50.0
    assert calculate_occupancy(100, 100) == 100.0
    assert calculate_occupancy(150, 100) == 100.0  # Capped

    assert get_occupancy_status(10)  == "Boş"
    assert get_occupancy_status(45)  == "Orta"
    assert get_occupancy_status(75)  == "Dolu"
    assert get_occupancy_status(90)  == "Çok Dolu"

    assert get_occupancy_color(10)  == "green"
    assert get_occupancy_color(45)  == "yellow"
    assert get_occupancy_color(75)  == "orange"
    assert get_occupancy_color(90)  == "red"
