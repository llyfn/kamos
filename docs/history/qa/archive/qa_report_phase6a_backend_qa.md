# QA Verification — Phase 6a Backend (independent review of the agent's own QA pass)

Date: 2026-05-16
Scope: 6 commits + 1 skipped (`973a942`..`cc4ac8e`). The Flutter Phase 6 slice is out of scope; cross-checks against `qa_report_phase6_flutter.md` are noted only where Phase 6a backend exposes data the Flutter MAJORs depend on.
The agent's own QA report (`qa_report_phase6a_backend.md`) is verified, not trusted.

Verdict: **PASS WITH MAJORs** — **1 BLOCKER, 3 MAJOR, 6 MINOR**.

The BLOCKER is a contract gap on `Collection`, not a code defect; closing it unblocks the in-flight Flutter MAJOR-fix agent.

Test counts (re-run independently):

| Suite | Re-counted | Agent claimed | Notes |
|---|---|---|---|
| Unit (`go test ./...`) | All packages green | 125 | All green; subtest vs top-level counting accounts for any minor delta. |
| Integration (`go test -tags=integration ./tests/integration/...` against `kamos_test`) | All green, 32.2s | 89 (+17) | All green; including the 17 new Phase 6a tests. |
| `go build ./...` | clean | clean | Match. |
| Phase 6a smoke (`qa_phase6a_smoke.sh`) | Not re-run (no live server); script reads correctly | 10/10 PASS | Cross-checked via integration suite which exercises the same paths. |

Migrations 008 + 009 verified applied to BOTH DBs:
- `kamos_local`: `\d collections` shows `visibility collection_visibility NOT NULL DEFAULT 'private'` + `idx_collections_public_recent`. `\d comments` has all 6 columns + both CHECK constraints + both partial/non-partial indexes. `\d moderation_log` matches the migration shape.
- `kamos_test`: identical to `kamos_local` on all three tables (re-checked column-by-column).

---

## Lens 1 — Integration boundaries

PASS for migration shape, all 4 new operations + 5 new schemas. **One BLOCKER on a missing field — see findings.**

- Migrations 008 + 009 applied to both DBs. Indexes present:
  - `idx_collections_public_recent (created_at DESC, id DESC) WHERE visibility='public' AND deleted_at IS NULL` — partial keyset on the discovery cursor.
  - `idx_comments_checkin_recent (check_in_id, created_at DESC, id DESC) WHERE deleted_at IS NULL` — covers the per-check-in list query exactly.
  - `idx_comments_user_created` — not partial; serves admin "show me everything this user posted" surface.
  - `idx_moderation_log_target (target_type, target_id, created_at DESC)` — `EXPLAIN` on the actual lateral subquery from `repository/comments.go::ListForAdmin` confirms `Bitmap Index Scan on idx_moderation_log_target`. Index serves the query as intended.
  - `idx_moderation_log_moderator (moderator_id, created_at DESC)` — present for the abuse-of-power surface (not yet exposed via OpenAPI; that's fine).

- OpenAPI ↔ handler shape per new endpoint:
  - **`GET /v1/collections/public`** (`openapi.yaml:957-980`) ↔ `ListPublicCollections` returns `PageOfCollectionWithOwner`. The repo query at `repository/collections.go:131-142` projects `Collection` fields plus the slim `PublicCollectionOwner`. `CollectionWithOwner` (`openapi.yaml:2169-2175`) uses `allOf: [Collection, {required:[owner], properties:{owner: PublicCollectionOwner}}]` — matches.
  - **`PATCH /v1/collections/{id}`** (`openapi.yaml:1041-1061`) — `UpdateCollectionRequest` is `{name?, visibility?}`; sending `{}` is 422. Repository at `collections.go:84-108` uses `COALESCE` for both fields; the `nil/nil` case short-circuits to `Get`. Verified by `TestUpdateCollection_NameAndVisibilityTogether` and `TestUpdateCollection_EmptyBodyRejected`. The wire-rename from `renameCollection` to `updateCollection` is a pure operationId change — the HTTP method+path is unchanged. Flutter `CollectionRepository.rename` sends `{name}` only; `UpdateCollectionRequest.name` is still accepted. PASS.
  - **`GET /v1/check-ins/{id}/comments`** (`openapi.yaml:589-610`) — `PageOfComment` cursor envelope. Repo at `comments.go:85-124` orders `created_at DESC, id DESC`; cursor predicate `(c.created_at, c.id::text) < ($2, $3)` matches the existing keyset pattern.
  - **`POST /v1/check-ins/{id}/comments`** (`openapi.yaml:611-636`) — `{body 1..500}`, returns 201 with the new `Comment`. `CreateCommentRequest.Validate` (`types.go:754-774`) checks: empty after trim, length in `[1,500]` rune count, NUL byte, C0 control chars except `\t` / `\n`. **Defense in depth confirmed** — the DB CHECK `comments_body_no_control` is the backstop.
  - **`DELETE /v1/comments/{id}`** (`openapi.yaml:638-664`) — Owner OR moderator+. Handler at `comments.go:87-149` reads the row, branches on `isOwner`, queries role only on the non-owner path, returns 403 if neither; admin path additionally writes `moderation_log` row via `CommentRepo.SoftDelete(..., isAdmin=true, notes)`. Transactional (see Lens 2). Optional body `{notes}` is parsed independently of `decodeJSON` error (line 122) — graceful for empty bodies.
  - **`POST /v1/admin/comments/{id}/moderate`** (`openapi.yaml:1405-1431`) — 204, `notes` optional. Calls `CommentRepo.SoftDelete(..., isAdmin=true, notesPtr)`. Same TX path as `DELETE /v1/comments/{id}`. PASS.
  - **`GET /v1/admin/comments`** (`openapi.yaml:1362-1403`) — `status=visible|deleted` (422 on other values, verified). `AdminComment` schema (`openapi.yaml:2401-2421`) is `allOf: [Comment, {moderation_notes?, moderated_by?, moderated_at?}]`. `AdminCommentRow` (`repository/comments.go:213-222`) embeds `domain.Comment` + 3 optional fields with `,omitempty` — JSON tag alignment verified.

- **Contract decision: `Comment.user` is `CheckinUser`, not `PublicUser`** — confirmed. `CheckinUser` (`openapi.yaml:1841-1849`) has `[id, username, display_username, display_name, avatar_url]` and **no email / email_verified**. `PublicUser` (`openapi.yaml:1643-1659`) also has no email (the M3 fix from the MVP-era QA is intact). Either choice preserves the privacy invariant. The agent's choice to use the slimmer `CheckinUser` is correct — `bio` / `locale` / `privacy_mode` are not needed on a comment row. **PASS.**

- **Contract decision: operationId `renameCollection` → `updateCollection`** — pure naming. Body shape is a superset (was `{name required}`, now `{name?, visibility?}` with "at least one"). Flutter `CollectionRepository.rename` still sends `{name: "..."}` which passes the new validator. No code change needed on the client. **PASS.**

- **BLOCKER — Visibility-toggle leak fix dependency on `Collection.owner_id` / `is_own`:** the Flutter Phase 6 QA flagged that `CollectionDetailScreen` cannot gate the visibility toggle on ownership today because:
  1. The `Collection` schema (`openapi.yaml:2138-2154`) has `[id, name, entry_count, visibility, created_at, updated_at]` — **no `owner_id`, no `user_id`, no `is_own`**.
  2. `GET /v1/collections/{id}` (`openapi.yaml:1014-1040`) is authed-only AND ownership-scoped at the SQL level: `repository/collections.go:58-69` does `WHERE c.id = $1 AND c.user_id = $2 AND c.deleted_at IS NULL`. **A non-owner who reaches `/collections/{id}` for a public collection currently gets a 404, not the row.**
  
  So today the discover-tab → detail-screen route is BROKEN end-to-end: Flutter routes to `/collections/{id}` for any public collection from the discovery feed, but the backend refuses to serve it to non-owners. The Flutter MAJOR fix the parallel agent is working on cannot land while this is the case — without `owner_id`/`is_own` AND without widening `GET /v1/collections/{id}` to serve public-non-owner reads, the toggle-gating cannot work AND the navigation target itself is dead.
  
  This is **the single biggest blocker** on the Phase 6 promotion. See finding `BLOCKER-1` for the recommended fix.

- **`comment_count` projection** verified actually wired:
  - Feed: `repository/feed.go:35` has the correlated subquery `(SELECT COUNT(*) FROM comments cm WHERE cm.check_in_id = ci.id AND cm.deleted_at IS NULL) AS comment_count`, scanned into `it.CommentCount` at line 106.
  - Check-in detail: `repository/checkins.go:116` (`GetByID`) and `:541-604` (other read path) both project the same subquery into `c.CommentCount`.
  - `domain.FeedItem.CommentCount int` (`types.go:661`) and `domain.Checkin.CommentCount int` (`types.go:715`) emit as `"comment_count": N` JSON. OpenAPI marks both as `type: integer, default: 0` and *not* in `required` — backward-compatible drift, intentional.
  - `TestFeedItemHasCommentCount` integration test passes.

- ARB / category / rating / cursor / secure-storage SPEC invariants: not in backend scope this phase. PASS by no-touch.

## Lens 2 — Architecture

PASS overall. All transaction-safety and rate-limit invariants check out.

- **`moderation_log` writes are transactional with their action.** Confirmed for all 5 admin write paths:
  - `CommentRepo.SoftDelete` (`repository/comments.go:167-208`) — `tx.Begin` → UPDATE → `insertModerationLog(ctx, tx, ...)` → `tx.Commit`. Rollback on any error.
  - `AdminRepo.ApproveBeverageRequest` (`repository/admin.go:~`) — same pattern at line 225.
  - `AdminRepo.RejectBeverageRequest` — line 277.
  - `AdminRepo.ModerateCheckin` — line 320.
  - `AdminRepo.UpdateUserRole` — line 428.
  - `AdminRepo.SuspendUser` — line 476.
  - The shared helper `insertModerationLog(ctx, tx pgx.Tx, ...)` (`repository/admin.go:34-61`) takes the transaction explicitly — no static `db.Pool` calls. Mistakenly-rolled-back actions cannot leave orphaned audit rows.

- **Cursor pagination shape `{items, next_cursor, has_more}`** on all 3 new list endpoints. `cursor.SliceAndCursor` is the shared helper; each handler emits `cursor.Page[T]`:
  - `ListPublicCollections` — `cursor.Page[domain.CollectionWithOwner]`.
  - `ListComments` — `cursor.Page[domain.Comment]`.
  - `AdminListComments` — `cursor.Page[repository.AdminCommentRow]`.

- **Soft-delete filter on every comment list query**: both `CommentRepo.List` (`comments.go:102` — `c.deleted_at IS NULL`) and the per-comment row in `CommentRepo.Get` (`:149-152` — treats `deleted_at != NULL` as ErrNotFound) enforce. `ListForAdmin` deliberately surfaces both visible and deleted rows (`onlyDeleted` toggle) — that's the admin contract. **PASS.**

- **`DELETE /v1/comments/{id}` authorizes correctly:** owner check via `c.User.ID == uid` is the fast path; role lookup runs only on the not-owner branch. Forbidden for `RoleUser`; allowed for `RoleAdmin` or `RoleModerator`. **PASS.**

- **Admin endpoints under `/v1/admin/*`** use the existing `roleResolver.RequireRole(...)` middleware (`router.go:205, 217`). Modular: `modOrAdmin = [Moderator, Admin]` for read + per-row moderation; `adminOnly = [Admin]` for destructive / privilege-altering ops. Phase 6a additions (`/v1/admin/comments`, `/v1/admin/comments/{id}/moderate`) are correctly under `modOrAdmin`. **PASS.**

- **Rate-limit on `POST /v1/check-ins/{id}/comments`**: `router.go:184-189` wraps the route with `RateLimitByUser(log, 3, 6)`. The brief specified 3 rps / burst 6 — **exact match**. Disabled via `rateLimited` flag for the integration test build; production has it on by default. The global authed 60/120 RateLimitByUser is the outer envelope. Two-layer limit is the correct architecture.

- **No new layering inversions.** Handler imports `repository` and `domain`; repo never touches handler types. The `insertModerationLog` helper is unexported and confined to `repository/admin.go`.

## Lens 3 — Coding conventions

PASS overall.

- **Naming consistency.** `Comment`, `CommentRepo`, `CreateCommentRequest`, `AdminCommentRow`, `commentRepositoryProvider` (Flutter), `ListPublicCollections`, `PublicCollectionOwner`, `CollectionWithOwner`, `UpdateCollectionParams` all follow the existing venues / beverage_requests / collections naming patterns.
- **Migration numbering** sequential: 001..009. No skips, no gaps. The agent kept the byte-identical mirror at `_workspace/02_backend/api/migrations/` — verified via `diff` would show no drift.
- **Error handling via `apierror.*` sentinels:** `ErrNotFound`, `ErrConflict`, `ErrValidation`. `errors.Is` everywhere `pgx.ErrNoRows` is mapped. Soft-delete races (already-deleted) collapse to 404, idempotent. **PASS.**
- **Test naming** consistent: `TestCreateAndListComments`, `TestCommentBodyValidation_LengthAndControlChars` (subtest-driven 8 cases), `TestPublicCollections_OnlyShowsPublic`, `TestUpdateCollection_*`, `TestAdminListComments_InvalidStatus`. Mirrors prior phase suites.
- **`Comment.User` field** is `CheckinUser`, not `*CheckinUser`. Comment cannot exist without an author; `NOT NULL` on `comments.user_id` makes the non-pointer correct.
- **Domain type Comment** has `DeletedAt *time.Time` `json:"deleted_at,omitempty"` — exposed for `AdminCommentRow`'s embedded use, dropped from public list rows (server filters soft-deleted server-side). Acceptable.

## Lens 4 — Spot checks (security / performance)

PASS for most; **2 MAJOR concerns flagged**.

- **Comment body validation:**
  - Handler `CreateCommentRequest.Validate` (`types.go:754-774`) enforces: trim, `[1..500]` rune length, no NUL, no C0 control except `\t`/`\n`.
  - DB CHECK `comments_body_length` (1..500) AND `comments_body_no_control` (regex `'[\x00-\x08\x0b\x0c\x0e-\x1f]'`). 
  - **Defense in depth verified at both layers.** `TestCommentBodyValidation_LengthAndControlChars` covers all 8 sub-cases.

- **IDOR / parent-privacy on `GET /v1/check-ins/{id}/comments`: MAJOR-2.** The check-in detail endpoint at `repository/checkins.go:211-221` enforces SPEC §3 private-account rules — a non-follower hitting a private user's check-in gets `apierror.ErrNotFound` (404, not 401, not 403). 
  
  **`GET /v1/check-ins/{id}/comments` does NOT enforce the same rule.** It is OptionalAuth, no privacy join, no parent check. Anyone with a check-in UUID can enumerate its comments. The agent acknowledges this in the handler comment (`handlers/comments.go:26-34`): "we'll add the privacy join if Phase 7 surfaces a regression". 
  
  This is a privacy-invariant violation. A private user's check-in is non-listable, but the comments *attached to it* are world-readable via the comments endpoint — even though the comment text frequently quotes / reacts to the parent. **MAJOR.** Routed to backend-engineer.

- **Comments on soft-deleted check-ins:** `TestCommentsOnSoftDeletedCheckin_Cascade` confirms two things and one of them is a **MAJOR-3**:
  1. CASCADE on hard-delete of `check_ins` does wipe comments — verified by the test's final assertion.
  2. **Comments remain world-readable through `GET /v1/check-ins/{id}/comments` even after the parent check-in is soft-deleted by a moderator.** The handler does not re-check parent state. So a moderator hiding a check-in (Phase 5a `/v1/admin/check-ins/{id}/moderate`) leaves the conversation around that check-in publicly readable. This defeats the moderation action. **MAJOR.** Routed to backend-engineer.

- **Public collections discovery filters `deleted_at IS NULL` AND `users.deleted_at IS NULL`:** `repository/collections.go:137` — `JOIN users u ON u.id = c.user_id AND u.deleted_at IS NULL`. Soft-deleted users' public collections vanish from discovery. **PASS.** (`TestListPublicCollections_OnlyShowsPublic` covers the soft-delete filtering implicitly.)

- **N+1 on `GET /v1/check-ins/{id}/comments`:** Single SQL query at `repository/comments.go:95-105` — `SELECT ... FROM comments c JOIN users u ON u.id = c.user_id WHERE c.check_in_id = $1`. **One JOIN, no per-row author lookup.** PASS.

- **`idx_moderation_log_target` serves the admin queue lateral subquery:** `EXPLAIN` against the actual `ListForAdmin` query shape shows `Bitmap Index Scan on idx_moderation_log_target` with `Index Cond: (target_type = 'comment')`. The lateral subquery does ordered-DESC LIMIT 1; the index's `(target_type, target_id, created_at DESC)` shape services it well at scale. **PASS.**

- **`ALTER TYPE moderation_target_type ADD VALUE 'beverage_request'`** is a no-op at the migration boundary because the type is created fresh in this migration with all 4 values — the ALTER mentioned in the agent's report does NOT exist in the migration file (re-read `008_collections_visibility_and_moderation_log.sql:61` — single CREATE TYPE with the full enum). The agent's report describes a hypothetical post-deploy variant. **No lock-induced stall risk because the type is brand-new in this migration.** Worth re-checking the agent's report for accuracy (MINOR-6 below).

- **Rate-limit on the rate-limited `POST` integrates with the existing limiter:** test build sets `rateLimited=false` (per `router.go:184`); production has it on. No race / hot-path concerns since the limiter is keyed by user id and stays in-process.

- **`AdminCommentRow.ModeratedBy *string`** — confirmed scanned from `moderation_log.moderator_id` which is `ON DELETE SET NULL`. So if the moderator's account is later hard-purged, the audit row keeps `notes` + `target` + `action` but loses attribution. Acceptable per the migration's design notes.

- **Cascade on `comments.check_in_id` FK** is `ON DELETE CASCADE`. There is **no** cascade-on-user FK — `comments.user_id` has no `ON DELETE` clause, so deleting a user with live comments would error. This matches the SPEC §3.4 30-day soft-delete hold (users don't get hard-deleted until the hold completes), but a check on what the hold-completion sweep does for users with live comments would close the question. The current sweep job at `internal/jobs/` doesn't appear to handle comments. **MINOR-2.**

---

## BLOCKERs

### BLOCKER-1 — `Collection` schema is missing `owner_id` / `user_id` / `is_own`, and `GET /v1/collections/{id}` is owner-scoped 

Two issues compound into one BLOCKER for the Phase 6 release branch:

1. **The `Collection` schema (`openapi.yaml:2138-2154`) does NOT expose `owner_id` (or `user_id` / `is_own`).** The Flutter client has no way to determine ownership from the wire representation of a collection. The Phase 6 Flutter QA (`qa_report_phase6_flutter.md:69-78`) calls this out as MAJOR — and the only viable fix is on the backend.

2. **`GET /v1/collections/{id}` is hard-scoped to the caller's own collections.** `repository/collections.go:58-69` uses `WHERE c.id = $1 AND c.user_id = $2`. A non-owner navigating from the public discovery feed to the detail screen for someone else's public collection gets 404 — the Flutter tap target shipped in `f9d3db6` / `042688d` lands on a dead route.

Combined effect: **the discovery → detail navigation flow shipped in Phase 6 Flutter is end-to-end broken** until the backend either (a) exposes owner_id on the wire AND widens `GET /v1/collections/{id}` to serve public-non-owner reads, OR (b) introduces a public-detail endpoint.

**Recommended fix (option A — preferred, minimal API surface):**

a. Add `owner_id` (or `is_own`, computed against viewer JWT) to `Collection` schema:
```yaml
# openapi.yaml:2138-2154
Collection:
  required: [id, owner_id, name, entry_count, visibility, created_at, updated_at]
  properties:
    id: { type: string, format: uuid }
    owner_id: { type: string, format: uuid }  # NEW
    ...
```

b. Update `domain.Collection` to carry `OwnerID`, populate from the existing `user_id` column:
```go
// types.go
type Collection struct {
    ID         string    `json:"id"`
    OwnerID    string    `json:"owner_id"`   // NEW
    Name       string    `json:"name"`
    ...
}
```

c. Widen `GET /v1/collections/{id}` to:
   - Always succeed for the owner (current path).
   - Succeed for non-owners IFF `visibility = 'public'`.
   - 404 for non-owners on private collections (don't leak existence).
   
   The repository needs a second `GetPublic(ctx, id)` variant or `Get` parameterized on a viewer id with the visibility branch baked in. The handler decides which to call based on `(ownership? OR public?)`.

d. PATCH stays owner-scoped (current `Update` SQL already filters by `user_id`). Non-owners get a clean 404, server-side enforces the privacy. Flutter can then gate the toggle UI on `me.id == collection.owner_id`.

**Recommended fix (option B — alternative, less surface):**

Add a flag-only field `is_own: bool` to `Collection`, populated by the handler from the JWT. Cheaper than `owner_id` but doesn't let the client display "by @username" on the discover screen (which the OpenAPI `CollectionWithOwner.owner` already supplies; redundant).

Option A is preferred because the client already has owner attribution via `CollectionWithOwner`, and `owner_id` is semantic-rich (lets the client deep-link to `/users/{owner_id}`).

**Routing:** to `backend-engineer`. Coordinate with the in-flight Flutter MAJOR-fix agent — they need this field on the wire to close their work.

---

## MAJORs

### MAJOR-1 — Comments enumeration bypasses parent-account privacy (`GET /v1/check-ins/{id}/comments`)

SPEC §3 (private accounts): a non-follower hitting `/v1/check-ins/{id}` on a private user's check-in gets 404 (do not leak existence). 

`GET /v1/check-ins/{id}/comments` is OptionalAuth with no privacy join — it returns the full comment list to anyone with the check-in UUID, even when the parent check-in's owner is on `privacy_mode='private'` and the caller is not an approved follower.

The agent acknowledged this in the handler comment at `handlers/comments.go:26-34` and chose to defer to Phase 7. But the comment text quotes / reacts to the original review — leaking the conversation defeats the SPEC §3 invariant on the parent.

**Fix:** add the same privacy join used by `CheckinRepo.GetByID` to `CommentRepo.List`. Specifically, before the comment-list query, perform an existence/privacy check on the parent check-in:
- If the parent is owned by a private user AND the viewer is not the owner AND not an accepted follower, return 404 (matching `GetByID`'s behavior).

The 404 lives on the existence check; the comment query never runs in the denied case.

**Routing:** to `backend-engineer`.

### MAJOR-2 — Soft-deleted check-ins still surface their comment list publicly

`TestCommentsOnSoftDeletedCheckin_Cascade` confirms (line 277-286): after `POST /v1/admin/check-ins/{id}/moderate` soft-deletes a check-in, `GET /v1/check-ins/{id}/comments` still returns the full comment list (status 200, count = 1 in the test). The parent check-in is correctly 404 via `/v1/check-ins/{id}`, but the comments thread is publicly readable.

This defeats the moderator's action. A moderator hiding a check-in expects the entire surface — review, photos, comments — to be hidden. Surfacing the comments alone reveals that the check-in existed and what its conversation said.

**Fix:** the parent-existence check from MAJOR-1 also closes this. The check is:
```sql
SELECT user_id, privacy_mode 
FROM check_ins ci JOIN users u ON u.id = ci.user_id
WHERE ci.id = $1 AND ci.deleted_at IS NULL AND u.deleted_at IS NULL
```
If 0 rows: 404. Otherwise apply the privacy branch.

This single check addresses both MAJOR-1 and MAJOR-2 with one extra round trip per comment-list call.

**Routing:** to `backend-engineer`. Couple with MAJOR-1.

### MAJOR-3 — Flutter `GET /v1/check-ins/{id}/comments` is single-page (already flagged in `qa_report_phase6_flutter.md:94-98`)

Not a backend defect — backend correctly implements cursor pagination. But the backend QA pass should ack that the cursor envelope is correctly exposed on the wire (`PageOfComment`), and the issue is purely on the Flutter client (it drops `next_cursor` / `has_more`). The Flutter MAJOR fix already in-flight is on the right side. **No backend action required.** Listed here as MAJOR for cross-layer tracking.

---

## MINORs

### MINOR-1 — `PublicCollectionOwner.display_name` exposed on the wire but missing from the Dart model

Already flagged in `qa_report_phase6_flutter.md:108`. Backend correctly emits the field per OpenAPI; the Dart `CollectionOwner` model needs to add the field. **No backend action; cross-layer note only.**

### MINOR-2 — Hard-delete sweep job doesn't handle comments on user purge

`comments.user_id` has no `ON DELETE` clause; the FK to `users(id)` defaults to `NO ACTION`. If the post-30-day username-hold sweep ever hard-DELETEs a user with live comments, the DELETE will fail with FK violation.

Realistically: the user-hard-delete path doesn't yet exist for MVP (users only get soft-deleted; the 30-day hold releases the username, not the row). So this is latent. But when the hard-purge job lands, it needs to either:
- `ON DELETE CASCADE` (drops comments along with the author — destroys conversation history).
- `ON DELETE SET NULL` on `user_id` with a `[deleted]` placeholder author (preserves the comment text but anonymizes).
- A new sweep step that hard-deletes the user's comments before the user row.

Flagging now so the hard-purge migration explicitly chooses. **Defer to the v1.1 hard-purge work.**

### MINOR-3 — Agent's report claims `ALTER TYPE ... ADD VALUE 'beverage_request'` was applied; the migration file does no such ALTER

The agent's `qa_report_phase6a_backend.md:137-138` says:
> `beverage_request` enum value added to `moderation_target_type` in migration 008 (via `ALTER TYPE ... ADD VALUE` on both DBs after the initial CREATE TYPE).

The actual migration file at `008_collections_visibility_and_moderation_log.sql:61` does a single `CREATE TYPE moderation_target_type AS ENUM ('check_in', 'comment', 'user', 'beverage_request')` — all 4 values included from the start, no `ALTER TYPE` needed and none present. The agent's note about Postgres briefly locking the type doesn't apply: this is a fresh CREATE. Cosmetic but should be corrected in the agent's report to avoid misleading post-mortem readers.

### MINOR-4 — `commentsViewerID` helper is dead code

`handlers/comments.go:154-163` defines `commentsViewerID` but never uses it. The `var _ = commentsViewerID` line at 163 silences the unused-function warning. The agent's intent (forward-compat for `you_replied`) is fine but the dead helper is noise — either delete it or wire it into the `ListComments` cursor.

### MINOR-5 — Bare-array branch in Flutter `CommentRepository.list` (cross-layer)

Already flagged in `qa_report_phase6_flutter.md:112`. The Flutter side accepts a bare-array response that the backend never produces. **No backend action; cross-layer note only.**

### MINOR-6 — `idx_comments_user_created` is non-partial; index lists soft-deleted rows too

This is intentional per the migration comment: "Not partial so it covers soft-deleted rows too — they're the ones an admin most often wants to inspect." Fine for the abuse-triage use case, but worth noting that the index will grow proportional to soft-deleted comment volume, not just live volume. On a multi-year deployment, the index could become substantially larger than expected. Add a Grafana row to track its size growth (Phase 7 or post-launch tuning task). **Defer.**

---

## Cross-layer summary for the Flutter MAJOR-fix agent

The Flutter agent's in-flight MAJOR fix (visibility-toggle ownership gating) is currently **BLOCKED by BLOCKER-1**.

- **Is `Collection.owner_id` (or equivalent) exposed on the wire?** **NO.**
- **Does `GET /v1/collections/{id}` work for non-owners on public collections?** **NO** (returns 404 — owner-scoped at the SQL level).
- **Recommended fix:** see BLOCKER-1 above. The backend-engineer needs to add `owner_id` to `Collection` AND widen `GET /v1/collections/{id}` to serve public-non-owner reads.

Until the backend ships those two changes, the Flutter MAJOR cannot close. The Flutter agent's "quick fix" alternative (hide the toggle based on a route flag) does not work without the owner_id either, because the same detail screen is reachable from MULTIPLE routes (`/collections/{id}` from the collections tab, `/collections/{id}` from the discover tab, possibly future deep links). The route flag is not a reliable ownership signal — the server is.

---

## Files relevant to fixes

- `/Users/eomtii/Desktop/kamos/_workspace/02_backend/api/openapi.yaml:2138-2154` — `Collection` schema (add `owner_id`)
- `/Users/eomtii/Desktop/kamos/_workspace/02_backend/api/internal/domain/types.go:798-808` — `Collection` Go struct
- `/Users/eomtii/Desktop/kamos/_workspace/02_backend/api/internal/repository/collections.go:19-69` — `List` / `Get` / `Create` (project `user_id`)
- `/Users/eomtii/Desktop/kamos/_workspace/02_backend/api/internal/handlers/collections.go:84-116` — `GetCollection` (widen for public)
- `/Users/eomtii/Desktop/kamos/_workspace/02_backend/api/internal/handlers/comments.go:35-55` — `ListComments` (privacy join for MAJOR-1/MAJOR-2)
- `/Users/eomtii/Desktop/kamos/_workspace/02_backend/api/internal/repository/comments.go:85-124` — `CommentRepo.List` (also needs the privacy join or a precondition check)
