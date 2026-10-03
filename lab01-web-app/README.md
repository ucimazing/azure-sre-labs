# Lab 01: Web app (FastAPI + Postgres + Redis + Nginx, Docker Compose)

Runs locally on your Mac. No Azure resources, so nothing to bill.

```
curl :8088 -> nginx -> app (FastAPI, ../app) -> postgres (data)
                                             -> redis    (read cache for GET /items/{id})
```

## Run it

```bash
make up      # build + start, waits until every container is healthy
make test    # smoke.sh (curl) + pytest (../app/tests)
make down    # stop (keeps the DB volume). `make nuke` also deletes the volume
```

Other targets: `make ps`, `make logs`, `make psql`, `make redis-cli`.
Port defaults to 8088 (8080 is taken on this Mac). Change `HTTP_PORT` in `.env`.

## Endpoints

| Path | What it tells you |
|---|---|
| `/nginx-health` | Nginx is up (doesn't touch the app) |
| `/healthz` | Liveness: the app process is up. Never checks dependencies |
| `/readyz` | Readiness: 200 if Postgres answers, 503 if not. Redis is reported but optional |
| `/items` CRUD | `GET/POST /items`, `GET/PUT/DELETE /items/{id}`. `X-Cache: HIT/MISS` header on GET by id |

## Break it, then explain it

Do one at a time. Predict the result first, then check. Fix with `docker compose start <svc>`.

1. `docker compose stop redis`, then `curl -i :8088/readyz` and `curl -i :8088/items/1`.
   Expected: still 200. Redis is a cache, so the app degrades instead of failing. Check `make logs` for the warning.
2. `docker compose stop postgres`, then hit `/healthz`, `/readyz`, `/items`.
   Expected: healthz 200, readyz 503, items 503 fast. Why should liveness stay 200 here?
   (Hint: what would Kubernetes do to every pod if liveness failed when the DB is down?)
3. `docker compose stop app`, then `curl -i :8088/healthz`.
   Expected: 504 from Nginx. Which log shows it, nginx or app?
4. `docker compose kill -s SIGKILL postgres` then `docker compose start postgres`. Is your data still there? Why? (Look at the `pgdata` volume.)
5. Cache staleness: `make redis-cli`, then `GET item:1`. Run `UPDATE items ...` directly in `make psql`. What does the API return for 60s, and why? (This is the classic cache invalidation bug.)
