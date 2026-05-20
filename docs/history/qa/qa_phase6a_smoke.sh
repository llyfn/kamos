#!/usr/bin/env bash
# Phase 6a backend smoke — exercises public collections + flat comments +
# moderation_log + visibility flow end-to-end against kamos_local.
#
# Requires the API to be running on $API_BASE_URL (default
# http://localhost:8080) and `jq` + `psql` + `curl` on PATH. Will create
# fresh users on each run so it's safe to invoke repeatedly.
#
# Usage:
#   API_BASE_URL=http://localhost:8080 ./qa_phase6a_smoke.sh
set -euo pipefail

API="${API_BASE_URL:-http://localhost:8080}"
DB="${DATABASE_URL:-postgres://kamos_local@localhost:5432/kamos_local?sslmode=disable}"

# Per-run suffix prevents collision on the live-username unique index. Each
# rerun produces a fresh set of test users.
SUFFIX="$(date +%s)"
ALICE="alice6a_${SUFFIX}"
BOB="bob6a_${SUFFIX}"
PASS="phase6a-smoke-password"

pass() { printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; exit 1; }

req() {
  local method=$1 path=$2 token=$3 body=${4:-}
  local args=(-sS -o /tmp/p6a_body.json -w "%{http_code}" -X "$method" "$API$path")
  if [[ -n "$token" ]]; then args+=(-H "Authorization: Bearer $token"); fi
  if [[ -n "$body" ]]; then args+=(-H "Content-Type: application/json" --data "$body"); fi
  curl "${args[@]}"
}

echo "=== Phase 6a backend smoke ==="
echo "API: $API"
echo "DB:  $DB"

# 1. Register Alice + Bob.
echo "[1/10] register alice + bob"
code=$(req POST "/v1/auth/register" "" \
  "{\"username\":\"$ALICE\",\"email\":\"$ALICE@example.com\",\"password\":\"$PASS\",\"display_name\":\"Alice\",\"locale\":\"en\"}")
[[ "$code" == "201" ]] || fail "alice register: $code body=$(cat /tmp/p6a_body.json)"
ALICE_TOK=$(jq -r '.access_token' /tmp/p6a_body.json)
ALICE_ID=$(jq -r '.user.id' /tmp/p6a_body.json)

code=$(req POST "/v1/auth/register" "" \
  "{\"username\":\"$BOB\",\"email\":\"$BOB@example.com\",\"password\":\"$PASS\",\"display_name\":\"Bob\",\"locale\":\"en\"}")
[[ "$code" == "201" ]] || fail "bob register: $code body=$(cat /tmp/p6a_body.json)"
BOB_TOK=$(jq -r '.access_token' /tmp/p6a_body.json)
BOB_ID=$(jq -r '.user.id' /tmp/p6a_body.json)
pass "alice=$ALICE_ID bob=$BOB_ID"

# 2. Alice creates a check-in. Pick any existing beverage_id (seed catalog
# guaranteed to have at least the three categories' seed beverages? — if
# not, fall back to creating one via direct SQL).
echo "[2/10] alice creates a check-in"
BEV_ID=$(psql -At "$DB" -c "SELECT id FROM beverages LIMIT 1;" || true)
if [[ -z "$BEV_ID" || "$BEV_ID" == "null" ]]; then
  # Bootstrap a beverage if the seed didn't produce one.
  BREW_ID=$(psql -At "$DB" -c "INSERT INTO breweries (name_i18n) VALUES ('{\"en\":\"Smoke Brewery\",\"ja\":\"スモーク酒造\"}'::jsonb) RETURNING id;")
  CAT_ID=$(psql -At "$DB" -c "SELECT id FROM beverage_categories WHERE slug='nihonshu';")
  BEV_ID=$(psql -At "$DB" -c "INSERT INTO beverages (brewery_id, category_id, category_slug, name_i18n) VALUES ('$BREW_ID', '$CAT_ID', 'nihonshu', '{\"en\":\"Smoke Sake\",\"ja\":\"スモーク酒\"}'::jsonb) RETURNING id;")
fi
code=$(req POST "/v1/check-ins" "$ALICE_TOK" \
  "{\"beverage_id\":\"$BEV_ID\",\"rating\":4.0,\"review\":\"smoke test\"}")
[[ "$code" == "201" ]] || fail "create check-in: $code body=$(cat /tmp/p6a_body.json)"
CK_ID=$(jq -r '.id' /tmp/p6a_body.json)
pass "check-in=$CK_ID"

# 3. Bob comments on it.
echo "[3/10] bob comments"
code=$(req POST "/v1/check-ins/$CK_ID/comments" "$BOB_TOK" \
  "{\"body\":\"Tried this last night, loved it!\"}")
[[ "$code" == "201" ]] || fail "create comment: $code body=$(cat /tmp/p6a_body.json)"
COMMENT_ID=$(jq -r '.id' /tmp/p6a_body.json)
pass "comment=$COMMENT_ID"

# 4. Comment appears in list (anonymous read).
echo "[4/10] comment in list (anon)"
code=$(req GET "/v1/check-ins/$CK_ID/comments" "")
[[ "$code" == "200" ]] || fail "list: $code"
N=$(jq '.items | length' /tmp/p6a_body.json)
[[ "$N" == "1" ]] || fail "items: $N (want 1)"
BODY=$(jq -r '.items[0].body' /tmp/p6a_body.json)
[[ "$BODY" == "Tried this last night, loved it!" ]] || fail "body mismatch: $BODY"
pass "comment in list"

# 5. Alice's feed shows comment_count: 1.
# We need Alice following someone whose check-in is on her feed. Since the
# feed shows others' check-ins (ci.user_id <> $1), and only Bob commented
# on Alice's check-in, we'll instead promote Bob → Alice's feed by having
# Alice follow Bob, then create a Bob check-in + Alice comment. Simpler:
# directly assert the comment_count via the user-checkins endpoint, which
# is exposed for the same Checkin shape with comment_count projected.
echo "[5/10] check-in detail shows comment_count=1"
code=$(req GET "/v1/check-ins/$CK_ID" "")
[[ "$code" == "200" ]] || fail "get check-in: $code"
CC=$(jq -r '.comment_count' /tmp/p6a_body.json)
[[ "$CC" == "1" ]] || fail "comment_count: $CC (want 1)"
pass "comment_count=1 on detail"

# 6. Bob soft-deletes his own comment; list now empty.
echo "[6/10] bob deletes own comment"
code=$(req DELETE "/v1/comments/$COMMENT_ID" "$BOB_TOK")
[[ "$code" == "204" ]] || fail "delete: $code body=$(cat /tmp/p6a_body.json)"
code=$(req GET "/v1/check-ins/$CK_ID/comments" "")
[[ "$code" == "200" ]] || fail "list 2: $code"
N=$(jq '.items | length' /tmp/p6a_body.json)
[[ "$N" == "0" ]] || fail "items after delete: $N (want 0)"
pass "own-comment deletion"

# 7. New bob comment, admin (promoted alice) soft-deletes, moderation_log row exists.
echo "[7/10] admin-moderate path + moderation_log row"
code=$(req POST "/v1/check-ins/$CK_ID/comments" "$BOB_TOK" \
  "{\"body\":\"second comment to be moderated\"}")
[[ "$code" == "201" ]] || fail "create comment 2: $code"
COMMENT2_ID=$(jq -r '.id' /tmp/p6a_body.json)
# Promote alice to admin.
psql "$DB" -c "UPDATE users SET role='admin' WHERE id = '$ALICE_ID';" >/dev/null
# Alice deletes Bob's comment via admin endpoint.
code=$(req POST "/v1/admin/comments/$COMMENT2_ID/moderate" "$ALICE_TOK" \
  "{\"notes\":\"phase 6a smoke moderation\"}")
[[ "$code" == "204" ]] || fail "admin moderate: $code body=$(cat /tmp/p6a_body.json)"
# Assert moderation_log row exists.
LOG_N=$(psql -At "$DB" -c "SELECT COUNT(*) FROM moderation_log WHERE target_type='comment' AND target_id='$COMMENT2_ID';")
[[ "$LOG_N" == "1" ]] || fail "moderation_log rows: $LOG_N (want 1)"
LOG_NOTES=$(psql -At "$DB" -c "SELECT notes FROM moderation_log WHERE target_id='$COMMENT2_ID';")
[[ "$LOG_NOTES" == "phase 6a smoke moderation" ]] || fail "log notes: $LOG_NOTES"
pass "moderation_log row + notes persisted"

# 8. Alice creates + flips a collection public; /v1/collections/public lists it.
echo "[8/10] alice flips collection public"
code=$(req POST "/v1/collections" "$ALICE_TOK" "{\"name\":\"Smoke Picks $SUFFIX\"}")
[[ "$code" == "201" ]] || fail "create collection: $code body=$(cat /tmp/p6a_body.json)"
COLL_ID=$(jq -r '.id' /tmp/p6a_body.json)
code=$(req PATCH "/v1/collections/$COLL_ID" "$ALICE_TOK" "{\"visibility\":\"public\"}")
[[ "$code" == "200" ]] || fail "flip public: $code body=$(cat /tmp/p6a_body.json)"
# Anonymous discovery feed call.
code=$(req GET "/v1/collections/public" "")
[[ "$code" == "200" ]] || fail "discovery: $code"
FOUND=$(jq --arg id "$COLL_ID" '[.items[] | select(.id == $id)] | length' /tmp/p6a_body.json)
[[ "$FOUND" == "1" ]] || fail "discovery did not show collection (found=$FOUND)"
pass "public discovery shows collection"

# 9. Alice flips it back private; gone from discovery.
echo "[9/10] alice flips it back private"
code=$(req PATCH "/v1/collections/$COLL_ID" "$ALICE_TOK" "{\"visibility\":\"private\"}")
[[ "$code" == "200" ]] || fail "flip private: $code"
code=$(req GET "/v1/collections/public" "")
[[ "$code" == "200" ]] || fail "discovery 2: $code"
FOUND=$(jq --arg id "$COLL_ID" '[.items[] | select(.id == $id)] | length' /tmp/p6a_body.json)
[[ "$FOUND" == "0" ]] || fail "private collection still in discovery (found=$FOUND)"
pass "private removed from discovery"

# 10. Anonymous reads on both public surfaces.
echo "[10/10] anon reads on public surfaces"
code=$(req GET "/v1/collections/public" "")
[[ "$code" == "200" ]] || fail "anon discovery: $code"
code=$(req GET "/v1/check-ins/$CK_ID/comments" "")
[[ "$code" == "200" ]] || fail "anon comments list: $code"
pass "anonymous reads"

echo "=== Phase 6a backend smoke PASSED ==="
