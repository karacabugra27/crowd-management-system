"""Tests for /api/auth: register, login, refresh."""
import pytest


@pytest.mark.asyncio
async def test_register_returns_token_pair(client):
    resp = await client.post(
        "/api/auth/register",
        json={"email": "alice@example.com", "password": "hunter2hunter2"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_duplicate_email_is_rejected(client):
    payload = {"email": "dup@example.com", "password": "hunter2hunter2"}
    r1 = await client.post("/api/auth/register", json=payload)
    assert r1.status_code == 201
    r2 = await client.post("/api/auth/register", json=payload)
    assert r2.status_code == 409


@pytest.mark.asyncio
async def test_login_success_and_failure(client):
    await client.post(
        "/api/auth/register",
        json={"email": "bob@example.com", "password": "hunter2hunter2"},
    )

    ok = await client.post(
        "/api/auth/login",
        json={"email": "bob@example.com", "password": "hunter2hunter2"},
    )
    assert ok.status_code == 200
    assert ok.json()["access_token"]

    bad = await client.post(
        "/api/auth/login",
        json={"email": "bob@example.com", "password": "wrong-password!"},
    )
    assert bad.status_code == 401


@pytest.mark.asyncio
async def test_refresh_token_returns_access(client):
    reg = await client.post(
        "/api/auth/register",
        json={"email": "carol@example.com", "password": "hunter2hunter2"},
    )
    refresh = reg.json()["refresh_token"]

    out = await client.post("/api/auth/refresh", json={"refresh_token": refresh})
    assert out.status_code == 200
    assert out.json()["access_token"]


@pytest.mark.asyncio
async def test_refresh_rejects_access_token(client):
    reg = await client.post(
        "/api/auth/register",
        json={"email": "dave@example.com", "password": "hunter2hunter2"},
    )
    access = reg.json()["access_token"]

    out = await client.post("/api/auth/refresh", json={"refresh_token": access})
    assert out.status_code == 401
