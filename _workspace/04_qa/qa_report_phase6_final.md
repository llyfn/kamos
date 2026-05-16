# QA Report — Phase 6 Final Integration

Date: 2026-05-17
Scope: Phase 6 (public collections + flat comments) end-to-end.
Verdict: **PASS WITH MINOR**

- BLOCKER: 0
- MAJOR: 0 (3 BLOCKER/MAJOR caught by per-layer QA and fixed inline; see commit chain)
- MINOR: carry-overs documented below
- Live smoke: 20/20 PASS end-to-end against `kamos_local`

The original final-QA agent rate-limited at 1:10 AM Asia/Seoul; final verification was completed by the orchestrator (this report) once limits reset. All assertions ran against running kamos_local backend on :18080 with `psql kamos_local` for DB introspection.

---

## Commit range under review

**Layer commits:**
- `f9d3db6` collection visibility toggle (Flutter)
- `042688d` public collections discovery tab (Flutter)
- `52c7d7b` comments on check-ins UI (Flutter)
- `c752d05` comment count badge on feed cards (Flutter)
- `973a942` migration 008 — collections.visibility + moderation_log
- `3e7cf43` migration 009 — flat comments
- `94ee270` public collections discovery + visibility update (backend)
- `3c9f87f` flat comments on check-ins (backend)
- `4158098` admin comments moderation endpoints
- `cc4ac8e` Phase 6a backend smoke + report

**Fix commits (per-layer QA findings, fixed by implementer per the new pattern):**
- `5de6197` Flutter — comment list cursor pagination + correct ordering (MAJOR)
- `d84e056` Flutter — visibility toggle gated to collection owner (MAJOR, shipped with membership-check approximation pending backend owner_id)
- `36c1a19` Backend — expose Collection.owner_id + open GET /v1/collections/{id} to non-owners for public (BLOCKER)
- `28f6403` Backend — enforce parent privacy on GET /v1/check-ins/{id}/comments (MAJOR)
- `0a46426` Backend — GET /v1/check-ins/{id}/comments returns 404 for soft-deleted parent (MAJOR)
- `90f9e2b` Flutter follow-up — direct owner_id compare; approximation removed

**Admin client:**
- `ab44bec` admin OpenAPI codegen regen for Phase 6 endpoints
- `ed7c879` admin comments moderation page

---

## Lens 1 — Backend ↔ Flutter integration

| Check | Result |
|---|---|
| `Collection.owner_id` on wire + Flutter `Collection.ownerId` strict-required | PASS (smoke #3, #7, #8) |
| `GET /v1/collections/{id}` public access for non-owners + anonymous | PASS (smoke #7, #8) |
| Private collection 404s for non-owner + anonymous | PASS (smoke #9) |
| Comment list cursor envelope (newest-first) | PASS (smoke #13) |
| Comment body validation: 1..500 chars + control-char rejection | PASS (backend domain validator + DB CHECK constraint) |
| `comment_count` on `FeedItem` + Flutter feed card badge | PASS (backend projection wired; Flutter consumer renders) |
| ARB parity en/ja/ko | PASS — 211/211/211 after Phase 6 |
| SPEC category strings | PASS (untouched) |

## Lens 2 — Backend ↔ admin web client

| Check | Result |
|---|---|
| `/v1/admin/comments` typed in regenerated `api.d.ts` | PASS (`ab44bec`) |
| RoleGuard on `/comments` (admin or moderator) | PASS (`ed7c879`) |
| `POST /v1/admin/comments/{id}/moderate` body shape `{notes}` | PASS (smoke #16: admin moderates with notes, server returns 204) |
| Status filter UX (Visible/Deleted/All) | PASS per agent's client-filter mapping |

## Lens 3 — Schema invariants

| Check | `kamos_local` | `kamos_test` |
|---|---|---|
| Migration 008 applied (`collections.visibility`, `collection_visibility` enum, `idx_collections_public_recent`, `moderation_log`, `moderation_target_type`, `moderation_action_type`) | present | present (verified during integration test setup) |
| Migration 009 applied (`comments` + length/control-char CHECKs + `idx_comments_checkin_recent`) | present | present |
| Migrations 001-007 unchanged | unchanged | unchanged |
| `moderation_log` rows written in same tx as moderation action | PASS (smoke #17 row appears immediately after #16) |

## Lens 4 — SPEC invariants — 12/12 PASS

| # | Invariant | Status |
|---|---|---|
| 1 | Category strings | PASS (untouched in Phase 6) |
| 2 | Rating scale 0.5–5.0 NUMERIC(3,1) | PASS (untouched) |
| 3 | Username case-insensitive lowercase | PASS (untouched) |
| 4 | Soft-delete account + 30d username hold | PASS (untouched) |
| 5 | Soft-delete check-ins via `deleted_at TIMESTAMPTZ` | PASS — extended to soft-delete comments (smoke #15) and to cascade-hide comments on parent soft-delete (smoke #19) |
| 6 | i18n fallback `ko → en`, `ja → en` | PASS (untouched) |
| 7 | Cursor pagination `{items, next_cursor, has_more}` | PASS — new endpoints (`/v1/collections/public`, `/v1/check-ins/{id}/comments`) use this shape |
| 8 | Feed page size 20 | PASS (untouched) |
| 9 | Check-in caps: review ≤ 500, ≤ 4 photos | PASS — comment body cap of 500 chars mirrors the same rule |
| 10 | Default collections Inventory + Wishlist | PASS (untouched; existing collections defaulted to `visibility='private'`) |
| 11 | JWT in `flutter_secure_storage` | PASS (Flutter untouched; admin client uses localStorage per established convention) |
| 12 | Error response shape `{error, code}` | PASS (smoke #14 `FORBIDDEN`; #9 `NOT_FOUND`; #20 `RATE_LIMITED`) |

## Lens 5 — Live smoke (20/20 PASS against `kamos_local:18080`)

Full transcript from `_workspace/04_qa/qa_phase6_final_smoke.py`:

| # | Step | Result |
|---|---|---|
| 1 | Register alice + bob + carol | PASS |
| 2 | `UPDATE users SET role='admin' WHERE id='<alice>'` | PASS |
| 3 | Carol creates collection — default private, `owner_id` projected | PASS |
| 4 | Carol PATCHes `visibility: "public"` | PASS |
| 5 | `GET /v1/collections/public` includes carol's collection | PASS |
| 6 | Carol `GET` own collection | PASS |
| 7 | Bob `GET` carol's public collection — `owner_id == carol.id` | PASS |
| 8 | Anonymous `GET` public collection | PASS |
| 9 | Carol flips back to private — bob 404, anonymous 404 | PASS |
| 10 | Public discovery no longer lists it | PASS |
| 11 | Bob creates check-in | PASS |
| 12 | Carol comments on bob's check-in | PASS |
| 13 | `GET /v1/check-ins/{id}/comments` envelope `{items, next_cursor, has_more}` | PASS |
| 14 | Bob (check-in owner) cannot delete carol's comment → 403 | PASS |
| 15 | Carol soft-deletes own comment; list filters it out | PASS |
| 16 | Alice (admin) `POST /v1/admin/comments/{id}/moderate` with `{notes}` → 204 | PASS |
| 17 | `moderation_log` row exists: `moderator_id=alice, target_type=comment, action=soft_delete` | PASS |
| 18 | Bob sets `privacy_mode=private`; carol (non-follower) `GET .../comments` → 404; bob (owner) → 200 | PASS |
| 19 | Bob soft-deletes check-in; anyone `GET .../comments` → 404 (cascade) | PASS |
| 20 | Burst 12 × `POST` comments → 4 × 201 then 8 × 429 (rate-limit fires; 3 rps / 6 burst) | PASS |

## Test counts (re-verified)

| Suite | Phase 5 baseline | Phase 6 final | Δ |
|---|---|---|---|
| Backend unit (`go test ./...`) | 125 | **125** | 0 |
| Backend integration | 72 | **96** | +24 |
| Flutter | 56 | **93** | +37 |
| Admin client (Vitest) | 8 | **11** | +3 |
| **Total** | 261 | **325** | **+64** |

`go build ./...` clean; `flutter analyze` clean; `tsc --noEmit` clean; `vite build` clean.

ARB parity: 211/211/211 after Phase 6.

## Outstanding minors (carry-overs only — full sweep next)

From per-layer reports, defer-worthy unless flagged by next phase's QA:
- Flutter — TextField `onChanged` rebuilds form on every keystroke (4-field comment composer is small enough)
- Backend — `Comment.user` shape is `CheckinUser` (slimmer than `PublicUser`); both omit email — confirmed
- Admin client — status filter UX could surface the underlying mapping more transparently (Visible / Deleted / All)

## What's owed by the user

No new vendor signups for Phase 6. Pre-existing items remain:
- Cookbook §C1 Google OAuth (Phase 2)
- §C2 R2, §C3 Resend (Phase 3)
- §C5 Foursquare (Phase 4)
- §C6 Cloudflare Pages — admin hosting (Phase 5)

---

**Net: Phase 6 is ship-ready.**

Next: post-phase MINOR sweep (per the standing pattern), then Phase 7 — Caching (M, ~1 week, driven by Phase 1 Grafana metrics).
