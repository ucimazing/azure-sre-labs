"""Shared lab app: a tiny items CRUD API backed by Postgres, with a Redis read cache.

Config (env vars):
  DATABASE_URL   postgresql://user:pass@host:5432/db   (required)
  REDIS_URL      redis://host:6379/0                    (optional; cache is skipped if unset or down)
  CACHE_TTL      seconds a cached item lives (default 60)
"""
import json
import logging
import os
import socket
from contextlib import asynccontextmanager

import redis
import psycopg
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool, PoolTimeout
from pydantic import BaseModel, Field

log = logging.getLogger("app")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))

DATABASE_URL = os.environ["DATABASE_URL"]
REDIS_URL = os.getenv("REDIS_URL")
CACHE_TTL = int(os.getenv("CACHE_TTL", "60"))
HOSTNAME = socket.gethostname()

SCHEMA = """
CREATE TABLE IF NOT EXISTS items (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""

pool = ConnectionPool(DATABASE_URL, min_size=1, max_size=10, open=False, timeout=5,
                      kwargs={"row_factory": dict_row})
cache = redis.Redis.from_url(REDIS_URL, socket_timeout=1, socket_connect_timeout=1,
                             decode_responses=True) if REDIS_URL else None


@asynccontextmanager
async def lifespan(_: FastAPI):
    pool.open(wait=True, timeout=30)
    with pool.connection() as conn:
        conn.execute(SCHEMA)
    yield
    pool.close()


app = FastAPI(title="sre-lab-app", lifespan=lifespan)


@app.exception_handler(PoolTimeout)
@app.exception_handler(psycopg.OperationalError)
def db_unavailable(_: Request, exc: Exception):
    log.error("database unavailable: %s", exc)
    return JSONResponse({"detail": "database unavailable"}, status_code=503)


class ItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=2000)


class Item(ItemIn):
    id: int
    created_at: str


def _row(r: dict) -> dict:
    return {**r, "created_at": r["created_at"].isoformat()}


def _cache_get(key: str):
    if not cache:
        return None
    try:
        v = cache.get(key)
        return json.loads(v) if v else None
    except redis.RedisError as e:
        log.warning("cache get failed: %s", e)
        return None


def _cache_set(key: str, value: dict):
    if not cache:
        return
    try:
        cache.setex(key, CACHE_TTL, json.dumps(value))
    except redis.RedisError as e:
        log.warning("cache set failed: %s", e)


def _cache_del(key: str):
    if not cache:
        return
    try:
        cache.delete(key)
    except redis.RedisError as e:
        log.warning("cache delete failed: %s", e)


@app.get("/healthz")
def healthz():
    """Liveness: the process is up. Does not touch dependencies."""
    return {"status": "ok", "host": HOSTNAME}


@app.get("/readyz")
def readyz(response: Response):
    """Readiness: Postgres must answer. Redis is reported but optional."""
    checks = {}
    try:
        with pool.connection(timeout=2) as conn:
            conn.execute("SELECT 1")
        checks["postgres"] = "ok"
    except Exception as e:
        checks["postgres"] = f"fail: {e.__class__.__name__}"
    if cache:
        try:
            cache.ping()
            checks["redis"] = "ok"
        except redis.RedisError as e:
            checks["redis"] = f"fail: {e.__class__.__name__}"
    ready = checks["postgres"] == "ok"
    response.status_code = 200 if ready else 503
    return {"status": "ready" if ready else "not ready", "host": HOSTNAME, "checks": checks}


@app.get("/items", response_model=list[Item])
def list_items(limit: int = 100):
    with pool.connection() as conn:
        rows = conn.execute("SELECT * FROM items ORDER BY id LIMIT %s", (limit,)).fetchall()
    return [_row(r) for r in rows]


@app.post("/items", response_model=Item, status_code=201)
def create_item(item: ItemIn):
    with pool.connection() as conn:
        r = conn.execute(
            "INSERT INTO items (name, description) VALUES (%s, %s) RETURNING *",
            (item.name, item.description),
        ).fetchone()
    return _row(r)


@app.get("/items/{item_id}", response_model=Item)
def get_item(item_id: int, response: Response):
    key = f"item:{item_id}"
    hit = _cache_get(key)
    if hit:
        response.headers["X-Cache"] = "HIT"
        return hit
    with pool.connection() as conn:
        r = conn.execute("SELECT * FROM items WHERE id = %s", (item_id,)).fetchone()
    if not r:
        raise HTTPException(404, "item not found")
    out = _row(r)
    _cache_set(key, out)
    response.headers["X-Cache"] = "MISS"
    return out


@app.put("/items/{item_id}", response_model=Item)
def update_item(item_id: int, item: ItemIn):
    with pool.connection() as conn:
        r = conn.execute(
            "UPDATE items SET name = %s, description = %s WHERE id = %s RETURNING *",
            (item.name, item.description, item_id),
        ).fetchone()
    if not r:
        raise HTTPException(404, "item not found")
    _cache_del(f"item:{item_id}")
    return _row(r)


@app.delete("/items/{item_id}", status_code=204)
def delete_item(item_id: int):
    with pool.connection() as conn:
        n = conn.execute("DELETE FROM items WHERE id = %s", (item_id,)).rowcount
    if not n:
        raise HTTPException(404, "item not found")
    _cache_del(f"item:{item_id}")
    return Response(status_code=204)
