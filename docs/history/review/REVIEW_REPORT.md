# Code Review Report — Notifications + Nav Rewrite

**Date:** 2026-05-26
**Scope:** branch `feature/notifications-and-nav-rewrite` vs `main`, HEAD `152ad7d` (post-Phase-3 + sweeps)
**Reviewers:** architecture · security · performance · style

---

## Executive Summary

| Domain | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| Architecture | 0 | 0 | 4 | 4 |
| Security | 0 | **1** | 3 | 2 |
| Performance | 0 | 0 | 3 | 4 |
| Style | — | 0 | 11 | 7 |
| **Total** | **0** | **1** | **21** | **17** |

**Must-fix before merge:** **SEC-001** (HIGH).

The branch is structurally sound — phase-level QA already passed for each layer with sweeps applied. This cross-cutting pass surfaced one HIGH (a pre-existing soft-delete PII leak in `comments.go` that the branch didn't introduce but whose fix is now obviously required since the identical bug was caught and patched on the new notifications path), a cluster of bundle-friendly MEDIUMs across all four domains, and a set of architectural observations that are correct but lower-urgency.

---

## Critical & High Priority

### **[SEC-001] Soft-deleted comment author PII leaks in comment list responses — HIGH**

- `backend/internal/repository/comments.go:98-108`, `:164-194`, `:277-294`
- `CommentRepo.List` / `Get` / `ListForAdmin` all `LEFT JOIN users` without filtering `u.deleted_at IS NULL`; the scan doesn't pull `u.deleted_at`. Soft-deleted users surface username / display_name / avatar to every reader of every thread they previously commented on. **Identical pattern to the notifications PII leak Phase 2 QA caught and fixed in commit `a3388b6`.** The branch touched `comments.go` (added `CreateTx`) but didn't apply the same fix on read paths in this file.
- Fix: select `u.deleted_at` and return nil actor when non-null. Mirror the `notifications.ListByRecipient` fix exactly. Apply to all three methods; the admin variant keeps user-id linkage for moderation but blanks display fields.
- Cross-domain: same root cause as **ARCH-001/006** (sibling write paths diverge on cross-cutting concerns) and recurrence of the **Phase 2 QA MAJOR** (same bug class).

---

## Medium Priority — Bundle into post-review sweep

### Security

- **[SEC-002] `CreateComment` skips check-in visibility gate, newly amplified by notifications** — `backend/internal/service/comment_service.go:70-93`. `ToggleToastTx` calls `r.checkVisibility`; `CommentService.Create` doesn't. Pre-existing gap, now meaningful because the notification emit confirms targeting succeeded and surfaces harassment to the inbox. Fix: call `s.checkins.AssertViewerCanSeeCheckin` in `CommentService.Create` before tx. **[Cross-ref ARCH-006: same shape — sibling paths drift on the same aggregate.]**
- **[SEC-003] `POST /v1/notifications/read` accepts unbounded `ids[]`** — `handlers/notifications.go:78-119`, `openapi.yaml:3011`. UUID validated per-entry but no length cap; ~26k UUIDs per request × burst 60. Fix: `if len(req.IDs) > 100 { httperr.WriteValidation(...) }` + `maxItems: 100` in OpenAPI.

### Performance

- **[PERF-001] `MarkAllRead` UPDATE is unbounded** — `repository/notifications.go:227-237`. Power user with 100k unread blocks one connection for hundreds of ms. Mark-read burst 60 amplifies. Fix: chunk via `... AND id IN (SELECT id ... ORDER BY created_at DESC LIMIT 1000)` loop, returning cumulative count.
- **[PERF-002] No TTL/archive job on `notifications`** — `migrations/019_notifications.sql`; no notification pruner. Cursor index grows linearly with lifetime activity. Fix: add a `cmd/worker` job that hard-deletes `WHERE created_at < NOW() - INTERVAL '180 days' AND read_at IS NOT NULL`. Document retention window in SPEC §5.4.
- **[PERF-003] Same-tx emit lengthens row-lock window on hot check-ins** — `service/checkin_service.go:172-195` + `migrations/011_counter_caches.sql`. Adds ~0.5–1 ms to each tx on a viral toast. Acceptable for MVP. Defer; revisit only if profiling confirms. **[Cross-ref ARCH-001: same architectural fact, perf angle.]**

### Architecture

- **[ARCH-001] Same-tx emit pattern is open-coded across 5 service methods** — `service/{checkin,comment,social}_service.go`. Suggest extracting a `withTx(ctx, fn)` envelope before event types grow beyond 5. Self-action guard already duplicated in 2 callers + `NotificationService.skip()` backstop. Defer; capture as backlog (recommended cleanup when v1.1 push echo lands).
- **[ARCH-002] `auth_state.dart` god-invalidator** — `frontend/lib/features/auth/providers/auth_state.dart:15-18`. Imports 5 sibling feature providers; each new viewer-scoped provider must be remembered here or risks SEC-006-shape leak across session swap. Suggest registry inversion. Defer; capture as backlog. **[Cross-ref security: this is the recurring class of cross-user data leak.]**
- **[ARCH-003] `KamosTabBar` (shell) imports a feature provider directly** — `frontend/lib/shared/widgets/kamos_tab_bar.dart:18`. Shell→feature layering inversion. Suggest either a shared `session_badges_provider` or passing badge state in as a parameter from `AppShell`. Defer; capture as backlog.

### Style

- **[STYLE-001] SPEC §5.4 contradicts the implementation on `follow_request` retention** — `SPEC.md:207`. SPEC claims the row "remains" after approval; code deletes it. SPEC is source-of-truth per CLAUDE.md, but it's the only place still wrong. Fix (orchestrator-owned, SPEC edit).
- **[STYLE-002] design/notifications_ux.md references 7 ARB keys that don't exist with those names** — `design/notifications_ux.md:246-261`. `notifications*` vs shipped `notifVerb*`; `notificationsMarkAllError` + `notificationsEnd` never added. Fix (orchestrator-owned, design doc edit). **[Cross-ref STYLE-011: missing `notificationsMarkAllError` key is downstream of the same drift.]**
- **[STYLE-003] ARB prefix inconsistency: `notifications*` (screen-level) vs `notifVerb*` (per-type templates)** — `frontend/l10n/intl_en.arb:222-236`. Every other feature uses a single prefix. Pick one and rename across 3 ARBs + generated + 7 call sites. Fix (Flutter).
- **[STYLE-004] `NotificationRepo` skips `Tx` suffix on tx-backed methods** — `repository/notifications.go:27-99`. Every other repo with both variants uses the suffix. Mechanical rename: `Insert{Toast,Comment,Follow,FollowRequest,FollowApproved} → Insert*Tx`; `DeleteFollowRequest → DeleteFollowRequestTx`. Fix (backend).
- **[STYLE-008] No test for 5-tab order on `KamosTabBar`** — `frontend/lib/shared/widgets/kamos_tab_bar.dart` (no test file). High-regression-risk surface. Fix: add `frontend/test/kamos_tab_bar_test.dart` with order + indexFor + unread-dot tests. Fix (Flutter).
- **[STYLE-009] No test for `_ResumeRefresher` lifecycle** — `frontend/lib/app/app.dart:46-78`. Drive `AppLifecycleState.resumed`; assert refresh called once when authed / not called when not. Fix (Flutter).
- **[STYLE-011] `markAllRead` swallows failure silently instead of design-specified snap-back + inline error** — `frontend/lib/features/notifications/providers/notification_providers.dart:135`. Bundle with STYLE-002 (missing ARB key) — fix together. Fix (Flutter).
- **[STYLE-012] `_FollowRequestActions._resolve` button busy-state asymmetry** — `frontend/lib/features/notifications/widgets/notification_row.dart:273-300`. On soft-deleted actor branch, `_busy` never set true; double-tap could re-fire `removeLocal`. Stale comment too. Fix (Flutter): either always set `_busy = true` or update the comment to reflect actual behavior.

---

## Low Priority

### Architecture

- **[ARCH-004]** `_ResumeRefresher` is notifications-specific but lives in `app.dart`. Move to feature folder or extract a generic lifecycle bus. Defer; document in class comment.
- **[ARCH-005]** Dead `KamosSocialApi.followRequests` + `ApiPaths.followRequests` after inbox removal; backend endpoint `GET /v1/follow-requests` still mounted but orphaned from mobile UI. Fix (Flutter): delete the dead Dart facade method + path. **Decide:** keep backend endpoint (admin? future?) or sunset.
- **[ARCH-006]** `DeleteComment` + `AdminModerateComment` bypass `CommentService.Delete`. Aggregate has two paths. Fix (backend): route through service. **[Cross-ref SEC-002: same sibling-divergence smell.]**
- **[ARCH-007]** OpenAPI `Notification` schema description + Dart model header are pre-020 doc-drift (still describe SET NULL behavior for `check_in_id`/`comment_id` which are now CASCADE). Fix (backend): update both descriptions.
- **[ARCH-008]** `NotificationRow` imports `features/social/social_repository.dart` directly — cross-feature widget import. Codebase already pervasively violates the no-cross-feature-imports rule; either drop the rule from the skill checklist or fix here. Defer.

### Security

- **[SEC-004]** `_FollowRequestActions` row-resolution-race silent failure — `notification_row.dart:269-300`. Defense-in-depth UX. Fix (Flutter): surface `ErrNotFound` as toast.
- **[SEC-005]** Sentinel actor stub renders unverified display name — no actual XSS (Flutter Text doesn't interpret markup); informational only.

### Performance

- **[PERF-004]** `_ResumeRefresher` has no debounce; rapid background/foreground fires N requests. Fix (Flutter): track `_lastRefresh`, skip if within 30s.
- **[PERF-005]** VisibilityDetector client-side batch has no upper cap. Pathological dwell-everything-in-1s could send 1000+ ids. Defer (telemetry-gated).
- **[PERF-006]** `NotificationRow extends ConsumerWidget` but doesn't subscribe; harmless ConsumerStatefulElement overhead. Defer.
- **[PERF-007]** OpenAPI `oneOf` generated-client bloat — N/A for KAMOS (hand-written bindings). Informational.

### Style

- **[STYLE-005]** Unused `domain.NotificationType*` constants. Delete or wire a consumer.
- **[STYLE-006]** Stale "bell badge → inbox" entries in `design/README.md:188,226`. Fix (orchestrator).
- **[STYLE-007]** `docs/db/query_patterns.md §16h` "in its place" wording mixes up approver/requester inboxes. Fix (backend or orchestrator).
- **[STYLE-010]** No `@notifVerb*.description` documenting that translators must include `{actor}`. Fix (Flutter).
- **[STYLE-013]** `MarkReadRequest` IDOR comment duplicated handler↔service. Fix (backend).
- **[STYLE-014]** No OpenAPI response-shape parity test; only route/verb parity exists. Defer (separate test infrastructure task).
- **[STYLE-015]** `visibility_detector` added without dep rationale comment. Fix (Flutter).
- **[STYLE-016]** Magic shadow `Color(0x0F0F2350)` duplicated in NotificationRow + KamosCard. Defer per Phase 3 QA NR-05.
- **[STYLE-017]** `feedEmptyBody` says "Discover" but file is `search_screen.dart`. Add a one-line comment at top of `search_screen.dart`. Fix (Flutter).
- **[STYLE-018]** Test file naming inconsistency `notification_*` vs `notifications_integration`. Defer (cosmetic).

---

## Cross-Domain Findings

### CD-1: "LEFT JOIN actor without `deleted_at` filter" is a recurring failure mode
- Cited in: **SEC-001 (HIGH)** + Phase 2 QA MAJOR (already fixed in `a3388b6`) + ARCH cross-ref ("scanActor helper" suggestion)
- Same incident class hit twice on this branch (notifications was caught and fixed; comments wasn't). Suggests a repo-level helper: `scanActor(deletedAt *time.Time, ...) *domain.CheckinUser` that normalizes the soft-delete→nil pattern. Beyond the SEC-001 hot-fix, audit other LEFT JOIN actor sites (feed, profile, comment list — already covered; what else?) and adopt the helper.

### CD-2: Sibling write-path divergence on the same aggregate
- Cited in: **SEC-002** (visibility gate missing on `CreateComment` but present on `ToggleToast`) + **ARCH-006** (`DeleteComment` bypasses service while `CreateComment` doesn't)
- Same root: the comments aggregate has multiple ingress points and they don't all do the same things. The branch fixed one (CreateComment now goes through service for same-tx emit). The fixes for SEC-002 + ARCH-006 should land together — both move logic into `CommentService` so the next invariant (e.g., visibility, moderation, audit log, future per-action notification) has exactly one home.

### CD-3: Same-tx emit pattern — architectural shape vs perf cost
- Cited in: **ARCH-001 (MEDIUM)** + **PERF-003 (MEDIUM, suspected)**
- Two angles on the same code: ARCH says "extract the envelope before more event types are added"; PERF says "the inline INSERT lengthens the row-lock window on viral toasts." If/when an outbox lands, both findings collapse — defer together.

### CD-4: Doc drift on post-020 FK CASCADE behavior
- Cited in: **ARCH-007** (OpenAPI `Notification` description + Dart model header) + **STYLE-007** (query_patterns.md §16h approver/requester confusion) + **STYLE-001** (SPEC §5.4 follow_request retention) + Phase 2 QA MINOR 5 (schema.md drift, mostly already swept)
- A constellation of small lies across 4 files. Fix all in one doc-drift sweep — they're each a 1–5 line edit.

### CD-5: markAllRead UX gap
- Cited in: **STYLE-002** (missing `notificationsMarkAllError` ARB key) + **STYLE-011** (silent error swallow contradicting design §3.3)
- Same incident: design specifies an inline error; ARB key wasn't added; provider silently swallows. Fix together: pick whether to ship design §3.3 (add key, wire toast, revert local patch on failure) or amend the design doc to say "swallow silently."

---

## Recommended Fix Order

### Round 1 — Before merge

1. **SEC-001 (HIGH)** — `comments.go` soft-delete actor PII (mirror `a3388b6` fix). MUST.

### Round 2 — Post-review sweep (bundle in one or two passes per implementer)

#### Backend (route to backend-engineer)
2. SEC-002 — visibility gate on `CommentService.Create`
3. SEC-003 — cap `ids[]` at 100 + OpenAPI `maxItems`
4. PERF-001 — chunk `MarkAllRead` loop (cap 1000/iter)
5. PERF-002 — TTL/archive job for `notifications` in `cmd/worker` (mirror `email_verification_cleanup`)
6. STYLE-004 — rename `Insert*` → `Insert*Tx`, `DeleteFollowRequest` → `DeleteFollowRequestTx`
7. ARCH-006 — route `DeleteComment` + `AdminModerateComment` through `CommentService`
8. ARCH-007 — update OpenAPI `Notification` description + Dart model header for post-020 CASCADE
9. STYLE-005 — delete unused `domain.NotificationType*` constants
10. STYLE-013 — dedup the IDOR comment between handler + service

#### Flutter (route to flutter-engineer)
11. STYLE-003 — unify ARB prefix (`notifVerb*` → `notificationsVerb*` or `notif*` throughout)
12. STYLE-008 — `frontend/test/kamos_tab_bar_test.dart` (5-tab order + indexFor + unread dot)
13. STYLE-009 — widget test for `_ResumeRefresher` (resumed/auth gating)
14. STYLE-010 — `@notifVerb*.description` for translator guidance
15. STYLE-011 + STYLE-002 missing key — wire design §3.3 (snap-back + inline error toast on markAllRead failure)
16. STYLE-012 — fix `_FollowRequestActions` busy-state asymmetry + stale comment
17. SEC-004 — surface `ErrNotFound` as toast in `_FollowRequestActions`
18. PERF-004 — debounce `_ResumeRefresher` (30s suppression)
19. ARCH-005 — delete dead `KamosSocialApi.followRequests` + `ApiPaths.followRequests`
20. STYLE-015 — inline rationale for `visibility_detector` dep
21. STYLE-017 — one-line comment at top of `search_screen.dart` explaining the Discover renaming carryover

#### Orchestrator (handle directly)
22. STYLE-001 — fix SPEC.md:207 (follow_request retention contradiction)
23. STYLE-002 — update `design/notifications_ux.md` ARB key names to match shipped (`notifVerb*`)
24. STYLE-006 — fix stale bell entries in `design/README.md:188,226`
25. STYLE-007 — fix `docs/db/query_patterns.md §16h` approver/requester swap

### Backlog (defer; capture as follow-up issues, do NOT fix in this sweep)

- ARCH-001 — extract same-tx envelope helper (revisit when push echo lands or event count exceeds ~8)
- ARCH-002 — invert `auth_state.dart` god-invalidator via session-scope registry
- ARCH-003 — invert `KamosTabBar` shell→feature import
- ARCH-004 — `_ResumeRefresher` placement (or generic lifecycle bus)
- ARCH-008 — cross-feature widget import (or formally drop the rule)
- PERF-003 — same-tx lock contention (only if profiling shows a problem)
- PERF-005/006/007 — pathological/N-A items
- SEC-005 — informational
- STYLE-014 — OpenAPI response-shape parity test infrastructure
- STYLE-016 — KamosCard extension (Phase 3 QA NR-05 already deferred)
- STYLE-018 — test file naming

---

## Full Findings

- Architecture: `docs/history/review/arch_findings.md` (8 findings, 0H/4M/4L)
- Security: `docs/history/review/security_findings.md` (6 findings, 0C/1H/3M/2L)
- Performance: `docs/history/review/perf_findings.md` (7 findings, 0C/0H/3M/4L)
- Style: `docs/history/review/style_findings.md` (18 findings, 0H/11M/4L/3S)
