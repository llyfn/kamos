#!/usr/bin/env bash
# Phase 6 FINAL end-to-end smoke — verifies the integrated public collections
# + flat comments + admin moderation slice across backend, DB, and the
# privacy / cascade / rate-limit edges that the per-layer reports flagged.
#
# Runs 18 checks against kamos_local. Each step's request + response is
# captured to a transcript file for the final QA report.
#
# Usage:
#   API_BASE_URL=http://localhost:8080 ./scripts/smoke.sh
#   (or `make smoke` from the repo root)

set -uo pipefail

API="${API_BASE_URL:-http://localhost:8080}"
DB="${DATABASE_URL:-postgres://kamos_local@localhost:5432/kamos_local?sslmode=disable}"

SUFFIX="$(date +%s)"
ALICE="alice6f_${SUFFIX}"
BOB="bob6f_${SUFFIX}"
CAROL="carol6f_${SUFFIX}"
PASS="phase6final-smoke-pw"

TRANSCRIPT="/tmp/p6_final_transcript.log"
: > "$TRANSCRIPT"

green() { printf "  \033[32mPASS\033[0m  %s\n" "$1" | tee -a "$TRANSCRIPT"; }
red()   { printf "  \033[31mFAIL\033[0m  %s\n" "$1" | tee -a "$TRANSCRIPT"; FAIL_COUNT=$((FAIL_COUNT+1)); }
note()  { printf "  %s\n" "$1" | tee -a "$TRANSCRIPT"; }
header() { printf "\n=== %s ===\n" "$1" | tee -a "$TRANSCRIPT"; }

FAIL_COUNT=0

req() {
  local method=$1 path=$2 token=$3 body=${4:-}
  local args=(-sS -o /tmp/p6_body.json -w "%{http_code}" -X "$method" "$API$path")
  if [[ -n "$token" ]]; then args+=(-H "Authorization: Bearer $token"); fi
  if [[ -n "$body" ]]; then args+=(-H "Content-Type: application/json" --data "$body"); fi
  curl "${args[@]}"
}

header "Phase 6 FINAL smoke"
note "API: $API  DB: $DB  SUFFIX: $SUFFIX"

# 1-2. Register alice, bob, carol.
header "[1/18] register alice, bob, carol"
code=$(req POST "/v1/auth/register" "" \
  "{\"username\":\"$ALICE\",\"email\":\"$ALICE@example.com\",\"password\":\"$PASS\",\"display_name\":\"Alice\",\"locale\":\"en\"}")
[[ "$code" == "201" ]] && ALICE_TOK=$(jq -r '.access_token' /tmp/p6_body.json) && ALICE_ID=$(jq -r '.user.id' /tmp/p6_body.json) && green "alice=$ALICE_ID" || red "alice register $code: $(cat /tmp/p6_body.json)"
code=$(req POST "/v1/auth/register" "" \
  "{\"username\":\"$BOB\",\"email\":\"$BOB@example.com\",\"password\":\"$PASS\",\"display_name\":\"Bob\",\"locale\":\"en\"}")
[[ "$code" == "201" ]] && BOB_TOK=$(jq -r '.access_token' /tmp/p6_body.json) && BOB_ID=$(jq -r '.user.id' /tmp/p6_body.json) && green "bob=$BOB_ID" || red "bob register $code: $(cat /tmp/p6_body.json)"
code=$(req POST "/v1/auth/register" "" \
  "{\"username\":\"$CAROL\",\"email\":\"$CAROL@example.com\",\"password\":\"$PASS\",\"display_name\":\"Carol\",\"locale\":\"en\"}")
[[ "$code" == "201" ]] && CAROL_TOK=$(jq -r '.access_token' /tmp/p6_body.json) && CAROL_ID=$(jq -r '.user.id' /tmp/p6_body.json) && green "carol=$CAROL_ID" || red "carol register $code: $(cat /tmp/p6_body.json)"

# 3. Promote alice to admin via SQL.
header "[2/18] promote alice to admin"
psql -At "$DB" -c "UPDATE users SET role='admin' WHERE username='$ALICE';" >/dev/null && green "alice → admin" || red "promote alice"
ROLE=$(psql -At "$DB" -c "SELECT role FROM users WHERE username='$ALICE';")
[[ "$ROLE" == "admin" ]] && green "verified role=admin" || red "role check got: $ROLE"

# 4. Carol creates a collection (default private), toggles public.
header "[3/18] carol creates a collection (default private)"
code=$(req POST "/v1/collections" "$CAROL_TOK" "{\"name\":\"Carol's Sake Loves $SUFFIX\"}")
[[ "$code" == "201" ]] && CAROL_COL_ID=$(jq -r '.id' /tmp/p6_body.json) && green "col=$CAROL_COL_ID visibility=$(jq -r '.visibility' /tmp/p6_body.json) owner_id=$(jq -r '.owner_id' /tmp/p6_body.json)" || red "create $code: $(cat /tmp/p6_body.json)"
# Verify owner_id == CAROL_ID
WIRE_OWNER=$(jq -r '.owner_id' /tmp/p6_body.json)
[[ "$WIRE_OWNER" == "$CAROL_ID" ]] && green "Collection.owner_id wire == carol.id (BLOCKER fix verified)" || red "owner_id mismatch: wire=$WIRE_OWNER expected=$CAROL_ID"

header "[4/18] carol PATCH visibility→public"
code=$(req PATCH "/v1/collections/$CAROL_COL_ID" "$CAROL_TOK" '{"visibility":"public"}')
[[ "$code" == "200" ]] && [[ "$(jq -r '.visibility' /tmp/p6_body.json)" == "public" ]] && green "visibility=public" || red "patch $code: $(cat /tmp/p6_body.json)"

# 5-6-7-8. Read public collection from various viewers.
header "[5/18] anonymous GET /v1/collections/public lists carol's collection"
code=$(req GET "/v1/collections/public?limit=50" "")
[[ "$code" == "200" ]] && green "list 200"
if jq -e --arg id "$CAROL_COL_ID" '.items | map(.id == $id) | any' /tmp/p6_body.json >/dev/null; then green "carol's collection visible in discovery (anon)"; else red "carol's collection NOT in anon discovery: $(jq '.items | map(.id)' /tmp/p6_body.json)"; fi

header "[6/18] carol GET /v1/collections/{id} (own, public)"
code=$(req GET "/v1/collections/$CAROL_COL_ID" "$CAROL_TOK")
[[ "$code" == "200" ]] && green "owner read 200, owner_id=$(jq -r '.owner_id' /tmp/p6_body.json)" || red "owner read $code"

header "[7/18] bob GET /v1/collections/{id} (non-owner, public)"
code=$(req GET "/v1/collections/$CAROL_COL_ID" "$BOB_TOK")
[[ "$code" == "200" ]] && green "non-owner read 200, owner_id=$(jq -r '.owner_id' /tmp/p6_body.json)" || red "non-owner read $code: $(cat /tmp/p6_body.json)"
WIRE_OWNER=$(jq -r '.owner_id' /tmp/p6_body.json)
[[ "$WIRE_OWNER" == "$CAROL_ID" ]] && green "owner_id visible to non-owner == carol.id" || red "non-owner sees owner_id=$WIRE_OWNER"

header "[8/18] anonymous GET /v1/collections/{id} (public)"
code=$(req GET "/v1/collections/$CAROL_COL_ID" "")
[[ "$code" == "200" ]] && green "anon read 200" || red "anon read $code: $(cat /tmp/p6_body.json)"

# 9-10. Flip back to private; bob 404, discovery empty for this id.
header "[9/18] carol flips visibility→private; bob now gets 404 on detail"
code=$(req PATCH "/v1/collections/$CAROL_COL_ID" "$CAROL_TOK" '{"visibility":"private"}')
[[ "$code" == "200" ]] && green "flip back to private 200"
code=$(req GET "/v1/collections/$CAROL_COL_ID" "$BOB_TOK")
[[ "$code" == "404" ]] && green "non-owner now 404 (private — no leak)" || red "non-owner got $code: $(cat /tmp/p6_body.json)"

header "[10/18] discovery feed no longer lists the now-private collection"
code=$(req GET "/v1/collections/public?limit=50" "")
if jq -e --arg id "$CAROL_COL_ID" '.items | map(.id == $id) | any' /tmp/p6_body.json >/dev/null; then red "still in discovery after flip→private"; else green "gone from discovery"; fi

# 11-13. Bob creates a check-in; carol comments; bob can't delete; carol can.
header "[11/18] bob creates a check-in; carol comments"
BEV_ID=$(psql -At "$DB" -c "SELECT id FROM beverages LIMIT 1;")
if [[ -z "$BEV_ID" || "$BEV_ID" == "null" ]]; then
  PROD_ID=$(psql -At "$DB" -c "INSERT INTO producers (name_i18n) VALUES ('{\"en\":\"Smoke Producer\",\"ja\":\"スモーク酒造\"}'::jsonb) RETURNING id;")
  CAT_ID=$(psql -At "$DB" -c "SELECT id FROM beverage_categories LIMIT 1;")
  BEV_ID=$(psql -At "$DB" -c "INSERT INTO beverages (producer_id, category_id, name_i18n) VALUES ('$PROD_ID','$CAT_ID','{\"en\":\"Smoke Sake\"}'::jsonb) RETURNING id;")
fi
code=$(req POST "/v1/check-ins" "$BOB_TOK" "{\"beverage_id\":\"$BEV_ID\",\"rating\":4.0,\"review\":\"smoke check-in $SUFFIX\"}")
[[ "$code" == "201" ]] && BOB_CHECKIN_ID=$(jq -r '.id' /tmp/p6_body.json) && green "checkin=$BOB_CHECKIN_ID" || red "create checkin $code: $(cat /tmp/p6_body.json)"

code=$(req POST "/v1/check-ins/$BOB_CHECKIN_ID/comments" "$CAROL_TOK" '{"body":"first comment by carol"}')
[[ "$code" == "201" ]] && C1_ID=$(jq -r '.id' /tmp/p6_body.json) && green "carol comment c1=$C1_ID user=$(jq -r '.user.username' /tmp/p6_body.json)" || red "comment $code: $(cat /tmp/p6_body.json)"

# Add a second from bob so ordering can be verified.
code=$(req POST "/v1/check-ins/$BOB_CHECKIN_ID/comments" "$BOB_TOK" '{"body":"bob replies"}')
[[ "$code" == "201" ]] && C2_ID=$(jq -r '.id' /tmp/p6_body.json) && green "bob comment c2=$C2_ID"

# List, verify newest-first.
code=$(req GET "/v1/check-ins/$BOB_CHECKIN_ID/comments" "")
FIRST_ID=$(jq -r '.items[0].id' /tmp/p6_body.json)
[[ "$FIRST_ID" == "$C2_ID" ]] && green "list newest-first: items[0]=c2 (bob, most recent)" || red "ordering: items[0]=$FIRST_ID expected=$C2_ID"

header "[12/18] bob (check-in author, not comment author) deletes carol's comment → 403"
code=$(req DELETE "/v1/comments/$C1_ID" "$BOB_TOK")
[[ "$code" == "403" ]] && green "non-owner+non-admin → 403" || red "got $code: $(cat /tmp/p6_body.json)"

header "[13/18] carol soft-deletes her own comment → 204"
code=$(req DELETE "/v1/comments/$C1_ID" "$CAROL_TOK")
[[ "$code" == "204" ]] && green "owner delete → 204" || red "got $code: $(cat /tmp/p6_body.json)"
# Verify the list no longer surfaces it.
code=$(req GET "/v1/check-ins/$BOB_CHECKIN_ID/comments" "")
HAS_C1=$(jq -r --arg id "$C1_ID" '.items | map(.id == $id) | any' /tmp/p6_body.json)
[[ "$HAS_C1" == "false" ]] && green "soft-deleted comment hidden from list" || red "soft-deleted comment still visible"

# 14. Carol posts a new one. Alice (admin) soft-deletes it; verify moderation_log.
header "[14/18] admin moderation path writes moderation_log"
code=$(req POST "/v1/check-ins/$BOB_CHECKIN_ID/comments" "$CAROL_TOK" '{"body":"another from carol"}')
[[ "$code" == "201" ]] && C3_ID=$(jq -r '.id' /tmp/p6_body.json) && green "carol comment c3=$C3_ID" || red "$code"

code=$(req POST "/v1/admin/comments/$C3_ID/moderate" "$ALICE_TOK" '{"notes":"smoke moderation note"}')
[[ "$code" == "204" ]] && green "admin moderate → 204" || red "got $code: $(cat /tmp/p6_body.json)"

MOD_ROW=$(psql -At "$DB" -c "SELECT moderator_id, target_type, action, notes FROM moderation_log WHERE target_id='$C3_ID' AND target_type='comment' ORDER BY created_at DESC LIMIT 1;")
note "moderation_log row: $MOD_ROW"
echo "$MOD_ROW" | grep -q "$ALICE_ID|comment|delete|smoke moderation note" && green "moderation_log row matches admin action" || red "moderation_log row unexpected: $MOD_ROW"

# 15-16. Privacy gate on comments endpoint.
header "[15/18] bob privacy_mode→private; carol (non-follower) GET comments → 404"
psql -At "$DB" -c "UPDATE users SET privacy_mode='private' WHERE id='$BOB_ID';" >/dev/null && green "bob → private" || red "DB update privacy"
code=$(req GET "/v1/check-ins/$BOB_CHECKIN_ID/comments" "$CAROL_TOK")
[[ "$code" == "404" ]] && green "non-follower gets 404 (MAJOR-1 fix verified)" || red "got $code: $(cat /tmp/p6_body.json)"
# And the owner himself can still see.
code=$(req GET "/v1/check-ins/$BOB_CHECKIN_ID/comments" "$BOB_TOK")
[[ "$code" == "200" ]] && green "owner still 200" || red "owner got $code"

header "[16/18] after follow accepted, carol can see the thread"
# Carol requests to follow bob; because bob is private, follow_requests row is created in 'pending'.
code=$(req POST "/v1/users/$BOB/follow" "$CAROL_TOK")
[[ "$code" == "200" || "$code" == "201" ]] && green "follow request POST → $code" || red "follow $code: $(cat /tmp/p6_body.json)"
FOLLOW_STATUS=$(jq -r '.status // empty' /tmp/p6_body.json)
note "follow status: $FOLLOW_STATUS"
# If pending, bob needs to approve. The follow_request surfaces in the notifications inbox.
# (GET /v1/follow-requests was retired in Phase 4 — the notifications inbox subsumes the listing.)
if [[ "$FOLLOW_STATUS" == "pending" ]]; then
  code=$(req GET "/v1/notifications" "$BOB_TOK")
  note "bob's notifications payload: $(cat /tmp/p6_body.json | head -c 400)"
  REQ_ID=$(jq -r '[.items[] | select(.type == "follow_request") | .actor.id] | first // empty' /tmp/p6_body.json)
  if [[ -n "$REQ_ID" && "$REQ_ID" != "null" ]]; then
    code=$(req POST "/v1/follow-requests/$REQ_ID/approve" "$BOB_TOK")
    [[ "$code" == "200" || "$code" == "204" ]] && green "bob approved follow request → $code" || red "approve $code: $(cat /tmp/p6_body.json)"
  fi
fi

# Re-check comments visibility for carol.
code=$(req GET "/v1/check-ins/$BOB_CHECKIN_ID/comments" "$CAROL_TOK")
[[ "$code" == "200" ]] && green "follower carol can now see comments" || red "follower got $code: $(cat /tmp/p6_body.json)"

# Flip bob back to public for the cascade test cleanliness.
psql -At "$DB" -c "UPDATE users SET privacy_mode='public' WHERE id='$BOB_ID';" >/dev/null

# 17. Bob soft-deletes the check-in → cascade to comment surface.
header "[17/18] bob soft-deletes check-in → comments endpoint 404 (MAJOR-2 fix)"
code=$(req DELETE "/v1/check-ins/$BOB_CHECKIN_ID" "$BOB_TOK")
[[ "$code" == "204" ]] && green "soft-delete checkin → 204" || red "got $code"
code=$(req GET "/v1/check-ins/$BOB_CHECKIN_ID/comments" "")
[[ "$code" == "404" ]] && green "comments endpoint 404 after soft-delete (cascade)" || red "got $code: $(cat /tmp/p6_body.json)"

# 18. Rate-limit smoke: spam comments → 429 after burst exhausted.
header "[18/18] rate-limit smoke (3 rps / burst 6)"
# Need a live (not soft-deleted) check-in. Bob creates a new one.
code=$(req POST "/v1/check-ins" "$BOB_TOK" "{\"beverage_id\":\"$BEV_ID\",\"rating\":3.5,\"review\":\"rl smoke $SUFFIX\"}")
BOB_CHECKIN2=$(jq -r '.id' /tmp/p6_body.json)
note "fresh check-in for RL test: $BOB_CHECKIN2"
# Fire 12 back-to-back comments from bob. First ~6 should succeed (burst),
# subsequent ones should be 429.
RL_OK=0
RL_429=0
for i in $(seq 1 12); do
  code=$(req POST "/v1/check-ins/$BOB_CHECKIN2/comments" "$BOB_TOK" "{\"body\":\"rl probe $i\"}")
  if [[ "$code" == "201" ]]; then RL_OK=$((RL_OK+1)); fi
  if [[ "$code" == "429" ]]; then RL_429=$((RL_429+1)); fi
done
note "burst 12 → 201s=$RL_OK 429s=$RL_429"
# Production starts with the global authed 60/120 limiter, then a per-route
# 3/6 limiter for comments. We expect the burst to short-circuit before all
# 12 succeed. (If rateLimited=false in this build, all will pass — flag it.)
if [[ "$RL_429" -ge 1 ]]; then green "saw $RL_429 × 429 — rate-limiter wired"; else red "no 429 — rateLimited may be off in this build"; fi

# Restore bob's privacy for tidiness.
psql -At "$DB" -c "UPDATE users SET privacy_mode='public' WHERE id='$BOB_ID';" >/dev/null

header "Summary"
note "Failures: $FAIL_COUNT"
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  printf "\n  \033[32m=== Phase 6 FINAL smoke PASSED (18/18) ===\033[0m\n"
  exit 0
else
  printf "\n  \033[31m=== Phase 6 FINAL smoke had %d FAILS ===\033[0m\n" "$FAIL_COUNT"
  exit 1
fi
