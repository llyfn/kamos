# Code Review Scope — Notifications + Nav Rewrite

- **Scope:** diff
- **Target:** branch `feature/notifications-and-nav-rewrite` vs `main`
- **Date:** 2026-05-26
- **Stack:** Go 1.26 + Flutter (Riverpod/go_router/Dio) + PostgreSQL 18
- **Git ref baseline:** `main` (commit `2bbc041`)
- **Branch HEAD at review time:** `152ad7d`
- **Diff size:** 60 files changed, 4770 insertions, 503 deletions

## Feature summary

KAMOS adds an in-app Notifications feature (SPEC §5.4 rewritten) covering 5 event types — `toast`, `comment`, `follow`, `follow_request`, `follow_approved` — surfaced on a new Notifications bottom-tab. The bottom nav is rewritten from `Feed | Search | + (Check-in) | Lists | Me` to `Feed | Lists | Discover | Notifications | Me`; the center `+` raised button is removed; Search is renamed to Discover (route + label only). The standalone `/inbox` follow-request screen is removed and follow requests are subsumed into the notifications inbox with inline Approve / Decline.

## Layers in the diff

### Database (Phase 1)
- `migrations/019_notifications.sql` — new `notifications` table (id, recipient, type CHECK, actor, check_in_id, comment_id, read_at, created_at) with self-action CHECK, refs-match-type CHECK, partial unique dedupe indexes per type, cursor index, partial unread index. FKs: `recipient`→users CASCADE; `actor`→users SET NULL; `check_in`/`comment`→tables originally SET NULL then changed to CASCADE in 020.
- `migrations/020_notifications_check_in_comment_fk_cascade.sql` — QA-driven follow-up: switch `check_in_id` and `comment_id` FKs to ON DELETE CASCADE (resolves CHECK vs SET-NULL contradiction).

### Backend Go (Phase 2)
- `backend/internal/domain/types_notification.go` — domain types.
- `backend/internal/repository/notifications.go` — repo: Insert (per-type dedupe via ON CONFLICT), ListByRecipient (cursor + LEFT JOIN actor + soft-delete check on actor), CountUnread (partial index), MarkRead (IDOR-scoped), MarkAllRead, DeleteFollowRequestNotification.
- `backend/internal/service/notification_service.go` — Emit* methods with shared `skip()` self-guard helper.
- `backend/internal/handlers/notifications.go` — 3 endpoints: `GET /v1/notifications` (cursor 20/page), `POST /v1/notifications/read` (`ids[]` XOR `all`), `GET /v1/notifications/unread-count`. UUID format validation on mark-read.
- Emit hooks wired into:
  - `service/checkin_service.go` (`ToggleToast`) — emit `toast` in same tx
  - `service/comment_service.go` (`Create`) — emit `comment` in same tx
  - `service/social_service.go` (`Follow`/`Unfollow`/`Approve`/`Decline`) — emit `follow`/`follow_request`/`follow_approved` + DELETE follow_request rows in same tx
- All Tx-aware variants now own the transaction; legacy non-tx repo methods deleted.
- `backend/internal/server/router.go` — 3 routes mounted, rate-limit 1 rps + burst 60 on mark-read.
- `backend/openapi.yaml` — `notifications` tag + 3 endpoints + schemas (Notification, PageOfNotification, MarkReadRequest with oneOf exclusivity, MarkReadResponse, UnreadCountResponse).
- Integration tests: `tests/integration/notifications_integration_test.go` (full lifecycle, IDOR, cursor tamper, soft-delete actor, dedupe, UUID validation).

### Flutter (Phase 3)
- New feature folder `frontend/lib/features/notifications/`:
  - `models/notification.dart` — freezed; hand-written `fromJson` per project precedent.
  - `repository/notification_repository.dart` — Dio bindings.
  - `providers/notification_providers.dart` — Riverpod (list, unread count, mark-read).
  - `screens/notifications_screen.dart` — VisibilityDetector-driven mark-on-scroll (≥50%/500ms + 1s batch), Mark all read header button, pull-to-refresh, infinite scroll.
  - `widgets/notification_row.dart` — type-switched verb row, inline Approve/Decline for `follow_request`, soft-deleted-actor placeholder, animated read↔unread state.
- `frontend/lib/shared/widgets/kamos_tab_bar.dart` — 5-tab rewrite, no FAB, unread dot on Notifications tab driven by `unreadCountProvider`.
- `frontend/lib/app/router.dart` — `/notifications` + `/discover` added; `/inbox`→`/notifications` and `/search`→`/discover` redirects.
- `frontend/lib/app/app.dart` — `_ResumeRefresher` (WidgetsBindingObserver → invalidate `unreadCountProvider` on `AppLifecycleState.resumed`).
- `frontend/lib/core/api/kamos_api.dart` — `KamosNotificationsApi` sub-facade.
- `frontend/lib/features/feed/screens/feed_screen.dart` — removed header bell, rewrote empty state copy.
- `frontend/lib/features/auth/providers/auth_state.dart` — provider invalidation on sign-in / sign-out / onUnauthorized.
- `frontend/lib/features/social/` — removed `inbox_screen.dart` + `social_providers.dart` (dead after subsume).
- `frontend/l10n/intl_{en,ja,ko}.arb` — added 12 notification keys + `tabNotifications` + `tabDiscover`; removed `tabSearch`, `tabCheckIn`, `inboxTitle`, `inboxEmptyTitle`, `inboxEmptyBody`; rewrote `feedEmptyBody` (no `+` reference).
- Tests added: `notification_model_test.dart` (5 types + soft-delete + round-trip), `notification_widgets_test.dart` (10 widget tests), 4 path-wiring smoke tests.

### Design + SPEC + Docs
- `SPEC.md` §5.4 rewritten to enumerate 5 types, read-state rules, UI rules; stale §5.3 comments-deferred line removed.
- `design/notifications_ux.md` (new) — UX spec, row anatomy, i18n appendix, tap targets, /collections route + scroll-to-comments-deferred notes.
- `design/ui_kits/mobile/components/NotificationsScreen.jsx` (new) + `Shell.jsx` + `data.jsx` + `FeedScreen.jsx` + `README.md` + `HANDOFF.md` + `index.html` updated for 5-tab + notifications preview.
- `docs/db/schema.md` §9c (new) + `indexes.md` + `query_patterns.md §16` documenting the table and query patterns including the post-020 CASCADE behavior.

## Phase-level QA already applied

Each layer passed its own QA pass and the resulting MAJORs/MINORs were swept:

- **Phase 1 QA:** 1 MAJOR (CHECK vs FK SET NULL contradiction) → migration 020 fix.
- **Phase 2 QA:** 1 MAJOR (soft-deleted actor PII leak) + 6 MINORs (UUID validation, OpenAPI `oneOf`, dead fallback branches, skip helper extraction, doc drift, test rename) → all resolved.
- **Phase 3 QA:** 0 MAJOR, 8 MINORs → 4 swept in code (NR-01/04/06/08), 2 swept in design doc (NR-02/03 deferred), 2 deferred as judgment calls (NR-05 KamosCard refactor, NR-07 split edge case).

## Reviewer scope guidance

This is the cross-cutting review **before** Phase 5 final integration QA + smoke + PR. Focus on issues that the per-layer QA might have missed because they only saw one layer at a time:

- **Arch:** layer separation between domain / service / repo / handler; whether the same-tx emit pattern scales as more event sources are added; Flutter feature folder coherence; whether the `_ResumeRefresher` placement in `app.dart` is the right home; OpenAPI vs typed Dart bindings drift risk.
- **Security:** the new endpoints (auth scoping, IDOR, oracle attacks via mark-read), the inline Approve/Decline flow using the existing follow-request endpoints, rate-limit adequacy under abuse, soft-deleted-actor data leaks in **other** code paths the diff touched (comments? feed cards?), CSRF for admin (admin is untouched but worth a spot-check), JWT and refresh handling unchanged but verify nothing regressed.
- **Perf:** index coverage under the documented query patterns + worst-case (100k notifications/user); the LEFT JOIN actor cost on hot list path; the VisibilityDetector mark-on-scroll request rate under aggressive scroll; the `_ResumeRefresher` request rate on rapid foreground/background cycles; OpenAPI `oneOf` impact on generated clients.
- **Style:** Go and Dart naming + comment hygiene per CLAUDE.md global ("no comments unless WHY is non-obvious"); dead code (especially after the legacy repo deletions); test coverage gaps; ARB key naming consistency.

Reviewers may cross-reference each other via SendMessage when a finding has implications in another domain.
