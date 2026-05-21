#!/usr/bin/env bash
# Phase 5a backend smoke — hits each admin endpoint with a freshly-promoted
# admin user and asserts the response code + a basic body invariant. Runs
# against kamos_local. Requires the API to be running on $API_BASE_URL
# (default http://localhost:8080) and `jq` + `psql` on PATH.
#
# Usage:
#   API_BASE_URL=http://localhost:8080 ./qa_phase5a_smoke.sh
set -euo pipefail

API="${API_BASE_URL:-http://localhost:8080}"
DB="${DATABASE_URL:-postgres://kamos_local@localhost:5432/kamos_local?sslmode=disable}"

# pick a unique username so re-runs don't collide on the live-username index
SUFFIX="$(date +%s)"
USER="phase5a_smoke_${SUFFIX}"
EMAIL="phase5a+${SUFFIX}@example.com"
PASS="phase5a-smoke-password"

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; exit 1; }

req() {
  local method=$1 path=$2 token=$3 body=${4:-}
  local args=(-sS -o /tmp/p5a_body.json -w "%{http_code}" -X "$method" "$API$path")
  if [[ -n "$token" ]]; then args+=(-H "Authorization: Bearer $token"); fi
  if [[ -n "$body" ]]; then args+=(-H "Content-Type: application/json" --data "$body"); fi
  curl "${args[@]}"
}

echo "=== Phase 5a backend smoke ==="
echo "API: $API"

# 1. Register a fresh user.
echo "[1/8] register fresh user"
code=$(req POST "/v1/auth/register" "" \
  "{\"username\":\"$USER\",\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"display_name\":\"P5A\",\"locale\":\"en\"}")
[[ "$code" == "201" ]] || fail "register: $code body=$(cat /tmp/p5a_body.json)"
USERID=$(jq -r '.user.id' /tmp/p5a_body.json)
pass "register USERID=$USERID"

# 2. Promote via direct DB UPDATE.
echo "[2/8] promote to admin (psql)"
psql "$DB" -c "UPDATE users SET role='admin' WHERE id = '$USERID';" >/dev/null
pass "promote ok"

# 3. Log in to get a fresh token (any token would work — roles aren't in JWT).
echo "[3/8] login"
code=$(req POST "/v1/auth/login" "" "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
[[ "$code" == "200" ]] || fail "login: $code body=$(cat /tmp/p5a_body.json)"
TOK=$(jq -r '.access_token' /tmp/p5a_body.json)
pass "login token len=${#TOK}"

# 4. /v1/users/me must include role=admin.
echo "[4/8] /me includes role"
code=$(req GET "/v1/users/me" "$TOK")
[[ "$code" == "200" ]] || fail "/me: $code"
ROLE=$(jq -r '.role' /tmp/p5a_body.json)
[[ "$ROLE" == "admin" ]] || fail "/me role: $ROLE (want admin)"
pass "/me role=admin"

# 5. GET /v1/admin/beverage-requests (moderator-or-admin).
echo "[5/8] list beverage-requests"
code=$(req GET "/v1/admin/beverage-requests" "$TOK")
[[ "$code" == "200" ]] || fail "list beverage-requests: $code body=$(cat /tmp/p5a_body.json)"
jq -e '.items | type == "array"' /tmp/p5a_body.json >/dev/null || fail "items not array"
pass "list beverage-requests"

# 6. GET /v1/admin/users.
echo "[6/8] list users"
code=$(req GET "/v1/admin/users" "$TOK")
[[ "$code" == "200" ]] || fail "list users: $code"
jq -e '.items | length >= 1' /tmp/p5a_body.json >/dev/null || fail "users empty"
pass "list users"

# 7. Approval cycle: submit a beverage-request, then admin approves.
echo "[7/8] approval cycle"
SUB_BODY='{"payload":{"name_en":"Smoke Junmai","name_ja":"スモーク純米","brewery":"smoke brewery"}}'
code=$(req POST "/v1/beverage-requests" "$TOK" "$SUB_BODY")
[[ "$code" == "202" ]] || fail "submit beverage-request: $code"
REQ_ID=$(jq -r '.id' /tmp/p5a_body.json)

# Resolve a brewery_id + category_id.
BREWERY_ID=$(psql -At "$DB" -c "SELECT id FROM breweries LIMIT 1;")
CAT_ID=$(psql -At "$DB" -c "SELECT id FROM beverage_categories WHERE slug='nihonshu';")
APPROVE_BODY=$(cat <<JSON
{
  "brewery_id":"$BREWERY_ID",
  "category_id":"$CAT_ID",
  "name_i18n":{"en":"Smoke Junmai","ja":"スモーク純米"},
  "abv":15.5,
  "notes":"smoke-test approval"
}
JSON
)
code=$(req POST "/v1/admin/beverage-requests/$REQ_ID/approve" "$TOK" "$APPROVE_BODY")
[[ "$code" == "200" ]] || fail "approve: $code body=$(cat /tmp/p5a_body.json)"
BEV_ID=$(jq -r '.beverage_id' /tmp/p5a_body.json)
[[ -n "$BEV_ID" && "$BEV_ID" != "null" ]] || fail "no beverage_id in approve response"
pass "approve created beverage $BEV_ID"

# 8. Self-suspend must 403 (admin can't suspend themselves).
echo "[8/8] self-suspend blocked"
code=$(req POST "/v1/admin/users/$USERID/suspend" "$TOK")
[[ "$code" == "403" ]] || fail "self-suspend: $code (want 403) body=$(cat /tmp/p5a_body.json)"
pass "self-suspend 403"

# Clean up: SUSPEND the admin so a re-run with a stale name doesn't collide
# on the live-username index. The username then enters the 30-day hold.
psql "$DB" -c "UPDATE users SET deleted_at=NOW(), username_release_at=NOW()+INTERVAL '30 days' WHERE id='$USERID';" >/dev/null

echo "=== All Phase 5a smoke checks passed ==="
