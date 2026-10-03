#!/usr/bin/env bash
# Quick end-to-end check through Nginx. Exits non-zero on the first failure.
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8088}"

step() { printf '%-40s' "$1"; }
ok()   { echo "ok"; }

step "nginx /nginx-health";  curl -fsS "$BASE_URL/nginx-health" >/dev/null && ok
step "app /healthz";         curl -fsS "$BASE_URL/healthz" | jq -e '.status=="ok"' >/dev/null && ok
step "app /readyz";          curl -fsS "$BASE_URL/readyz" | jq -e '.checks.postgres=="ok" and .checks.redis=="ok"' >/dev/null && ok
step "POST /items";          id=$(curl -fsS -X POST "$BASE_URL/items" -H 'content-type: application/json' -d '{"name":"smoke"}' | jq -r .id) && ok
step "GET /items/$id (MISS)"; curl -fsSi "$BASE_URL/items/$id" | grep -qi '^x-cache: MISS' && ok
step "GET /items/$id (HIT)";  curl -fsSi "$BASE_URL/items/$id" | grep -qi '^x-cache: HIT' && ok
step "DELETE /items/$id";     curl -fsS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/items/$id" | grep -q 204 && ok
echo "smoke: all passed"
