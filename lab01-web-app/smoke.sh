#!/usr/bin/env bash
# Quick end-to-end check. Exits non-zero on the first failure.
#   EXPECT_NGINX=0  target has no nginx in front (e.g. App Service)
#   EXPECT_REDIS=0  target runs without the Redis cache
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8088}"
EXPECT_NGINX="${EXPECT_NGINX:-1}"
EXPECT_REDIS="${EXPECT_REDIS:-1}"

step() { printf '%-40s' "$1"; }
ok()   { echo "ok"; }

echo "target: $BASE_URL"
if [[ $EXPECT_NGINX == 1 ]]; then
  step "nginx /nginx-health"; curl -fsS "$BASE_URL/nginx-health" >/dev/null && ok
fi
step "app /healthz";  curl -fsS "$BASE_URL/healthz" | jq -e '.status=="ok"' >/dev/null && ok
if [[ $EXPECT_REDIS == 1 ]]; then
  step "app /readyz (postgres+redis)"; curl -fsS "$BASE_URL/readyz" | jq -e '.checks.postgres=="ok" and .checks.redis=="ok"' >/dev/null && ok
else
  step "app /readyz (postgres)";       curl -fsS "$BASE_URL/readyz" | jq -e '.checks.postgres=="ok"' >/dev/null && ok
fi
step "POST /items"; id=$(curl -fsS -X POST "$BASE_URL/items" -H 'content-type: application/json' -d '{"name":"smoke"}' | jq -r .id) && ok
step "GET /items/$id"; curl -fsSi "$BASE_URL/items/$id" | grep -qi '^x-cache: MISS' && ok
if [[ $EXPECT_REDIS == 1 ]]; then
  step "GET /items/$id (cache HIT)"; curl -fsSi "$BASE_URL/items/$id" | grep -qi '^x-cache: HIT' && ok
fi
step "DELETE /items/$id"; curl -fsS -o /dev/null -w '%{http_code}' -X DELETE "$BASE_URL/items/$id" | grep -q 204 && ok
echo "smoke: all passed"
