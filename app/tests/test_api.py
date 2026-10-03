"""Integration tests: run against a live stack (default: Lab 1 nginx on :8088).

    BASE_URL=http://localhost:8088 pytest -q app/tests
"""
import os
import uuid

import httpx
import pytest

BASE_URL = os.getenv("BASE_URL", "http://localhost:8088")


@pytest.fixture(scope="module")
def client():
    with httpx.Client(base_url=BASE_URL, timeout=5) as c:
        yield c


def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_readyz(client):
    r = client.get("/readyz")
    assert r.status_code == 200
    assert r.json()["checks"]["postgres"] == "ok"


def test_crud_and_cache(client):
    name = f"test-{uuid.uuid4().hex[:8]}"
    r = client.post("/items", json={"name": name, "description": "d"})
    assert r.status_code == 201
    item_id = r.json()["id"]

    r = client.get(f"/items/{item_id}")
    assert r.status_code == 200 and r.json()["name"] == name
    assert r.headers["x-cache"] == "MISS"
    assert client.get(f"/items/{item_id}").headers["x-cache"] == "HIT"

    r = client.put(f"/items/{item_id}", json={"name": name + "-v2"})
    assert r.status_code == 200
    r = client.get(f"/items/{item_id}")
    assert r.json()["name"] == name + "-v2", "update must invalidate the cache"
    assert r.headers["x-cache"] == "MISS"

    assert any(i["id"] == item_id for i in client.get("/items").json())

    assert client.delete(f"/items/{item_id}").status_code == 204
    assert client.get(f"/items/{item_id}").status_code == 404
    assert client.delete(f"/items/{item_id}").status_code == 404


def test_validation(client):
    assert client.post("/items", json={"name": ""}).status_code == 422
    assert client.post("/items", json={}).status_code == 422
