# Lab 01 Runbook

How this stack fails, what it looks like, and how to fix it.
Every symptom below was **observed for real** on 2026-10-04 by breaking the stack on purpose.

```
client → nginx :8088 → app :8000 → db (Postgres :5432)
                                 → redis (cache :6379)
```

| Endpoint | Answered by | Meaning |
|---|---|---|
| `/nginx-health` | Nginx | Nginx is up. Doesn't touch the app |
| `/healthz` | app | **Liveness**: the app process is alive. Never checks dependencies |
| `/readyz` | app | **Readiness**: 200 only if Postgres answers. Redis is reported but optional |

## First 60 seconds of any incident

```bash
docker compose ps                    # what is running, healthy, restarting, exited?
curl -i localhost:8088/nginx-health  # is the front door up?
curl -i localhost:8088/readyz        # can the app reach its dependencies?
docker compose logs --tail=30 <svc>  # read from the BOTTOM up: last line = result, lines above = cause
```

## Quick triage: symptom → where to look

| You see | Who sent it | Most likely cause | Entry |
|---|---|---|---|
| **502** Bad Gateway | Nginx | App refused the connection: app (re)starting or crashed | #0, #3 |
| **504** Gateway Timeout (after ~2 s) | Nginx | App container gone or unreachable | #3 |
| **503** `database unavailable` / readyz `not ready` | App | Postgres down or wrong credentials | #2, #7 |
| readyz 200 but `"redis":"fail…"`, `x-cache` always `MISS` | App | Redis down (app degrades, keeps working) | #1 |
| Old data returned, fixes itself within 60 s | App | Stale cache: data changed outside the API | #5 |
| Nothing answers on :8088 at all, nginx `Restarting` | — | Broken Nginx config | #6 |

**Rule of thumb:** a 502/504 points to the path between Nginx and the app. A 503 points **behind** the app (database).

---

## 0. 502 right after `make up` (found by accident)

- **Symptom:** the first request right after `make up` returns **502**; half a second later it's 200. Nginx log: `connect() failed (111: Connection refused) while connecting to upstream`.
- **Cause:** the `app` service has **no healthcheck**. So `docker compose up --wait` returns as soon as the app container is *running*, before uvicorn is *listening* on :8000. Nginx (`depends_on: condition: service_started`) has the same problem.
- **Fix:** wait a second and retry. **Permanent fix (TODO):** give `app` a healthcheck on `/healthz` (the image has no curl, so use `python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"`), and change Nginx's `depends_on` to `condition: service_healthy`.

## 1. Redis down

- **Break:** `docker compose stop redis`
- **Symptom:**
  - `/readyz` → **200** with `"redis":"fail: ConnectionError"`
  - `GET /items/<id>` → 200, but `x-cache: MISS` **every** time
  - app log: `WARNING:app:cache get failed: Error -2 connecting to redis:6379. Name or service not known.`
- **Cause:** Redis is only a cache. The app catches cache errors and reads from Postgres instead (*graceful degradation*). It's slower under load, but correct. `Name or service not known` = DNS: a stopped container disappears from Docker's DNS.
- **Fix:** `docker compose start redis`. The app reconnects by itself; no app restart needed.

## 2. Postgres down

- **Break:** `docker compose stop db`
- **Symptom:**
  - `/healthz` → **200** (instant)
  - `/readyz` → **503** `{"postgres":"fail: AdminShutdown"}` (instant)
  - `/items` → **503** `{"detail":"database unavailable"}` after **~5 s**
  - app log: `error connecting in 'pool-1': [Errno -2] Name or service not known`
- **Cause:** the app can't serve data without its database, so readiness fails. Liveness must stay 200: if `/healthz` failed, an orchestrator would restart every app container, which doesn't fix the database and causes a **restart storm**. `/items` takes 5 s because the connection pool waits up to 5 s for a connection before giving up.
- **Fix:** `docker compose start db`, wait ~5 s. The app **recovers by itself** (the pool reconnects); no app restart needed.

## 3. App stopped

- **Break:** `docker compose stop app`
- **Symptom:**
  - `/readyz` → **504** Gateway Timeout after **2.0 s**
  - `/nginx-health` → **200** `ok`
  - nginx log: `upstream timed out (110: Operation timed out) while connecting to upstream`
- **Cause:** there is no app to answer, so **Nginx** generates the error. 504 = "no answer within my `proxy_connect_timeout 2s`". If the container exists but uvicorn isn't listening, you get **502** instead (connection refused, see #0). `/nginx-health` still works because Nginx answers it itself.
- **Fix:** `docker compose start app`

## 4. App crashes (process dies on its own)

- **Break:** `docker compose exec app sh -c 'kill 1'`
  (the slim image has no `kill` program; `kill` is a shell built-in, so it must run through `sh`)
- **Symptom:** almost nothing. Requests a second later already return 200. `docker inspect lab01-web-app-app-1 --format '{{.RestartCount}}'` → **1**.
- **Cause:** `restart: unless-stopped` restarts a container whose process exits **on its own**. `docker compose stop` is a *manual* stop, so Docker respects it and leaves the container `Exited (0)` (that's why #3 didn't heal itself).
- **Fix:** none needed. **Watch for:** a restart count that keeps climbing = **crash loop**. Check `docker compose logs app` for the reason.

## 5. Stale cache

- **Break:** `GET` an item twice (now cached, `x-cache: HIT`), then change it directly in the DB:
  `docker compose exec db psql -U app -d app -c "UPDATE items SET name='changed-in-db' WHERE id=<id>"`
- **Symptom:** the API keeps returning the **old** name. After ~60 s it returns `changed-in-db`.
- **Cause:** the app caches each item in Redis for `CACHE_TTL` = 60 s and only clears the cache entry when the change goes **through the API** (`PUT`/`DELETE`). A direct DB write bypasses that, so the cache serves old data until the entry expires.
- **Fix:** wait 60 s, or delete the key: `docker compose exec redis redis-cli DEL item:<id>`. **Lesson:** never change cached data behind the application's back. If you must, clear the cache afterwards.

## 6. Broken Nginx config

- **Break:** delete the `;` after `server app:8000` in `nginx/default.conf`, then `docker compose restart nginx`
- **Symptom:**
  - **all** traffic fails, even though the app is healthy
  - nginx container exits with code 1 and keeps restarting (`docker compose ps` → `Restarting`)
  - nginx log: `[emerg] invalid parameter "keepalive" in /etc/nginx/conf.d/default.conf:8`
- **Cause:** a config error stops Nginx from starting. Note the error points to **line 8**, but the missing `;` is on **line 7**: Nginx reports where it got *confused*, so **always check the line above** too.
- **Fix:** restore the `;`, then `docker compose restart nginx`.
  **Habit:** validate before applying, then reload without downtime:
  ```bash
  docker compose exec nginx nginx -t
  docker compose exec nginx nginx -s reload
  ```

## 7. Database password changed in `.env`

- **Break:** change the password in `.env` (both `POSTGRES_PASSWORD` and inside `DATABASE_URL`), then `make up`
- **Symptom:** `/readyz` → **503**; app log: `FATAL: password authentication failed for user "app"`
- **Cause:** the Postgres image uses `POSTGRES_PASSWORD` **only the first time**, when the data volume is empty. The existing `postgres_data` volume still holds the **old** password. The app now sends the new one, so the DB refuses it.
- **Fix:** put the old password back in `.env` and `make up`.
  To really rotate it: change it inside Postgres first (`ALTER USER app WITH PASSWORD '...'`), then update `.env`.
  Lab only: `make nuke && make up` (deletes all data).

---

## Open improvements

- [ ] App healthcheck + Nginx `depends_on: service_healthy` (fixes #0)
- [ ] Single source for the DB password: build `DATABASE_URL` from `${POSTGRES_PASSWORD}` in compose (makes #7 less likely)
