# Architecture Findings — Notifications + Nav Rewrite

Reviewer: arch
Scope: branch `feature/notifications-and-nav-rewrite` vs `main` (HEAD `152ad7d`)
Severity scale: HIGH | MEDIUM | LOW (CRITICAL reserved for security)

Severity summary: 0 HIGH · 4 MEDIUM · 4 LOW · 8 total

---

## [ARCH-001] Same-tx emit pattern is open-coded in every source-event service — about to become a maintenance hotspot
- Severity: MEDIUM
- Location:
  - `backend/internal/service/checkin_service.go:172-195` (ToggleToast)
  - `backend/internal/service/comment_service.go:70-93` (Create)
  - `backend/internal/service/social_service.go:44-153` (Follow, Unfollow, Approve, Decline)
- Finding: Five mutating service methods now each repeat the same shape — `s.db.Begin → defer Rollback → repo.XxxTx → s.notifs.EmitYyy → tx.Commit` — with bespoke error-wrap strings (`"... begin"`, `"... emit"`, `"... commit"`). The skip-self-action guard for the emit recipient is also duplicated in two of the callers (`checkin_service.go:186` and `comment_service.go:84`), in addition to the centralized `NotificationService.skip()` backstop. No service abstracts the transactional envelope or the emit-or-skip decision.
- Impact: As SPEC §5.4 grows beyond five event types (push echo in v1.1 is already foreshadowed in `migrations/019_notifications.sql:36-38` and the SPEC §5.4 rewrite), each new event source has to copy the same five-line transaction dance plus the per-recipient skip check, and each new emit recipient has to thread `recipient/actor` plumbing through the repo's Tx return tuple (the `ownerID` plumbing in `CommentRepo.CreateTx` and `CheckinRepo.ToggleToastTx` is already this pattern). When a future "digest" or "outbox" requirement lands (batch emit, retry, push fan-out), every one of these services has to be opened up because the emit is glued inline. The current 4-call surface is the right time to extract the envelope, before there are 8 or 12.
- Suggestion: Introduce a service helper `withTx(ctx, func(tx pgx.Tx) error)` so source-event services no longer own begin/rollback/commit ceremony. Separately, push the `recipient != actor` guard fully into `NotificationService.Emit*` (it is already there as `skip()`) and drop the duplicated caller-side guards — the saved `Emit*` call is one indirect method invocation, not a real cost, and the duplication is now a bug-by-omission risk when a new emit point gets wired without the guard. When the emit set grows past ~6 types, this also lays the groundwork to swap the inline emit for an outbox table written in the same tx (no service signature changes required).
- Cross-ref: relevant to perf review (the LEFT JOIN on hot list path + worst-case 100k row pagination are both downstream of the same data model; an outbox would also remove the inline INSERT from the source-event critical path).

## [ARCH-002] `auth_state.dart` is accumulating cross-feature provider knowledge — a god-invalidator pattern
- Severity: MEDIUM
- Location: `frontend/lib/features/auth/providers/auth_state.dart:15-18,65-69,91-103,110-120`
- Finding: `AuthStateNotifier` now imports 5 sibling feature providers (`collection_providers`, `feed_providers`, `notification_providers`, `profile_providers`) and explicitly invalidates them in 3 lifecycle hooks (`signIn`, `logout`, `onUnauthorized`). This diff added 2 more (`notificationListProvider`, `unreadCountProvider`) and the comment on `signIn` itself enumerates the symmetric list (`meProvider`, `feedProvider`, `collectionsProvider`, …). Each new "viewer-scoped, long-lived" provider in any feature now requires editing the auth feature.
- Impact: Reverses the intended dependency direction — features should depend on auth's session state, not the other way around. Every feature that adds a long-lived provider has to either be remembered by the next auth-state PR or risk holding the previous user's data across a session swap (a real SEC-006-shaped hole). The current diff caught notifications correctly, but the next one will not necessarily.
- Suggestion: Invert via a Riverpod "session scope" pattern: long-lived per-viewer providers register themselves with a registry the auth notifier reads, OR move long-lived caches behind `dioProvider`'s invalidation (which the auth notifier already invalidates) so the cascade is automatic. Short-term, the registry approach is the least invasive — each feature exposes a `Provider<List<ProviderOrFamily>>` of its own session-scoped providers, and `AuthStateNotifier` iterates them. Long-term, prefer `autoDispose` family providers for viewer-scoped data; only the auth flag itself needs to be long-lived.

## [ARCH-003] `KamosTabBar` reads a feature provider directly — shell-to-feature coupling
- Severity: MEDIUM
- Location: `frontend/lib/shared/widgets/kamos_tab_bar.dart:18,38-42,70-75`
- Finding: The shell tab bar (`shared/widgets/`) imports `features/notifications/providers/notification_providers.dart` and `ref.watch(unreadCountProvider)` directly, AND triggers a `refresh()` on tap. The shell now knows the notifications feature's provider name and its lifecycle method.
- Impact: A shared shell widget that imports a feature is a layering inversion. Any future shell — the admin SPA, a tablet layout, a desktop variant — has to either drag the notifications feature with it or refactor this widget. The current placement also makes the tab bar untestable in isolation without wiring a NotificationRepository fake. Worse, the `ref.read(...).refresh()` on `/notifications` tap places notification-refresh-on-tab-focus policy in the shell instead of on the screen that owns it; the screen already has an `initState`/`didChangeDependencies` and a `RefreshIndicator` that could carry the same semantics.
- Suggestion: Two options, equivalent in effort:
  1. (Preferred) Lift unread state into a small `shared/widgets/session_badges_provider.dart` that the notifications feature *writes to* and the tab bar *reads from* — invert the import direction.
  2. Pass the badge state into the tab bar as a parameter from `AppShell`, which already lives in this file and is the natural composition root for shell + feature wiring.
  Either way, drop the tap-side `refresh()` from the tab bar and move it into the notifications screen's lifecycle.

## [ARCH-004] `_ResumeRefresher` lives in `app.dart` but is feature-specific to notifications
- Severity: LOW
- Location: `frontend/lib/app/app.dart:8,33,46-78`
- Finding: `_ResumeRefresher` is a `WidgetsBindingObserver` wrapper that exists solely to invalidate `unreadCountProvider` on `AppLifecycleState.resumed`. It is wired into `MaterialApp.builder` in the same way the generic `_ApiToastListener` is. The class is one feature's policy implemented in the app shell.
- Impact: `app.dart` is the app composition root and should host generic, cross-cutting concerns. Embedding feature-specific resume policy here means every future "refresh on resume" need (feed, profile, unread DM count, etc.) will accumulate as siblings here — and the next reviewer cannot tell which lifecycle hooks are "app shell" and which are "happens to live here because notifications was first."
- Suggestion: Move `_ResumeRefresher` into `frontend/lib/features/notifications/` and have the notifications screen (or feature bootstrap) install/uninstall the observer. If a generic "lifecycle bus" is preferred (multiple features need resume hooks), introduce `app/lifecycle_bus.dart` that fan-outs `AppLifecycleState.resumed` to subscribers — then each feature subscribes itself instead of being hardcoded in `app.dart`. Acceptable to defer if only this one feature ever needs the hook, but document that in the class comment.

## [ARCH-005] Dead `KamosSocialApi.followRequests` + `ApiPaths.followRequests` after inbox removal — feature seam not cleaned up
- Severity: LOW
- Location:
  - `frontend/lib/core/api/kamos_api.dart:105` (`ApiPaths.followRequests`)
  - `frontend/lib/core/api/kamos_api.dart:600-612` (`KamosSocialApi.followRequests`)
- Finding: The Flutter Inbox screen was removed (commit c02477b) and the `KamosNotificationsApi.list` replaced it, but the legacy `social.followRequests` sub-facade method + its path constant remained. No Dart file calls it (verified by grep). The backend endpoint `GET /v1/follow-requests` is also still mounted and exposed via OpenAPI (`backend/internal/server/router.go:283`, `backend/openapi.yaml:1113-1130`), but is now orphaned from the mobile UI — the `follow_request` notifications inbox carries the listing instead.
- Impact: Two dead seams. The Dart dead code will be flagged by `flutter analyze` only if the test or `unused_import`/`unused_element` lints are tuned for it; otherwise it rots. The orphaned backend endpoint is a larger smell — it remains a supported API surface (and integration tests probably still hit it), forcing future schema/cursor changes to maintain it for nobody. If admin is supposed to consume it, that should be documented; if no client consumes it, deprecate it explicitly.
- Suggestion: Delete `KamosSocialApi.followRequests`, `ApiPaths.followRequests`, and the smoke test (none exists for it, already clean). On the backend, decide between (a) remove `GET /v1/follow-requests`, the handler, and the OpenAPI entry, or (b) explicitly mark it deprecated with a sunset date in OpenAPI. Either decision is fine — leaving an undocumented dead endpoint is the bad option.

## [ARCH-006] Comment delete path bypasses `CommentService.Delete` — service layer is inconsistent
- Severity: LOW
- Location:
  - `backend/internal/handlers/comments.go:100-156` (DeleteComment uses repos directly)
  - `backend/internal/service/comment_service.go:98-125` (`CommentService.Delete` exists and does the same orchestration)
  - `backend/internal/handlers/admin_comments.go:79` (AdminModerateComment also direct-repo)
- Finding: This diff swapped `CreateComment` from `Repos.Comments.Create` to `Services.Comment.Create` so the notification emit lands in the same tx — but `DeleteComment` continues to call `h.Repos.Users.GetUserRole` and `h.Repos.Comments.SoftDelete` inline, even though `CommentService.Delete` already encapsulates exactly that logic. The handler reimplementation drifts from the service version (e.g. the handler-side moderation_log write at `comments.go:149-156` happens AFTER `SoftDelete` returns, whereas `CommentService.Delete` returns the isAdminPath flag for the handler to log — close but not identical paths).
- Impact: One aggregate, two paths through it. Future invariants (e.g. "soft-deleting a comment also marks the corresponding `comment` notification read") will be added to the service and silently miss the handler path. The Stage-3 stated goal of "handlers shrink to decode → validate → call → respond" (per `service/services.go:1-10`) is undermined every time a handler reaches past the service into the repo.
- Suggestion: Route `DeleteComment` through `Services.Comment.Delete` in the same shape `CreateComment` was changed in this diff. `AdminModerateComment` similarly. Pre-existing inconsistency, but the notifications refactor's same-tx pattern argues for tightening it now: if a future `comment` notification needs to be soft-deleted alongside the comment, the only place that should live is the service.

## [ARCH-007] OpenAPI `Notification` description has stale doc-drift after migration 020
- Severity: LOW
- Location:
  - `backend/openapi.yaml:2976-2986` (description claims FK is SET NULL but applies only to actor)
  - `frontend/lib/features/notifications/models/notification.dart:1-11` (model header says check_in_id/comment_id are "nullable for the soft-delete case where the referenced check-in itself was removed")
- Finding: After migration 020 changed `notifications.check_in_id` and `notifications.comment_id` to `ON DELETE CASCADE`, two doc strings still describe the pre-020 model:
  1. The OpenAPI `Notification` schema description (line 2979-2982) talks about the SET NULL FK behavior — accurate for `actor` only, but the schema still marks `check_in_id` and `comment_id` `nullable: true`, which now misrepresents the wire shape for `toast` and `comment` types (those columns can never come back as null over the wire — CASCADE deletes the whole notification row).
  2. The Dart model header (`notification.dart:9-11`) claims `check_in_id`/`comment_id` are nullable "for the soft-delete case where the referenced check-in itself was removed." But soft-delete in KAMOS sets `deleted_at` without touching the FK, and hard-delete now CASCADEs the notification row instead of nulling the column. Neither pathway makes the column null at the wire layer.
- Impact: A client generator (or a human writing a new typed binding) will believe `check_in_id` can arrive as `null` on a `toast` row and write defensive branches that can never trigger. Worse, if a future client trusts the description and treats null as "the source was soft-deleted," it will render the wrong UI affordance. This is the same kind of drift that triggered the original migration 020.
- Suggestion: Update the OpenAPI description to reflect the actual rules: actor is SET NULL on hard-delete (renders "Deleted user"); check_in_id / comment_id are CASCADE'd, so a row with the wrong type can never arrive over the wire. Update the Dart model header to match. Optionally, tighten the OpenAPI schema to `nullable: false` on those two columns (the CHECK `notifications_refs_match_type` already guarantees it server-side for the rows where the discriminant requires them).

## [ARCH-008] Cross-feature import: notifications widget reaches into `features/social/`
- Severity: LOW
- Location: `frontend/lib/features/notifications/widgets/notification_row.dart:30,285-289`
- Finding: `NotificationRow` imports `../../social/repository/social_repository.dart` and calls `repo.approve()` / `repo.decline()` directly from a widget for the inline `follow_request` actions. This is a sibling-feature import (notifications → social), which the project's stated convention disallows ("`features/` modules do not import each other; cross-cutting types live in `shared/`" per the arch-review skill checklist).
- Impact: Honestly, the codebase already violates this convention pervasively (see auth → notifications/collections/feed/profile; profile → check_in/feed/social; check_in → beverages/feed/profile/venues/comments). The convention isn't really enforced in this codebase, so this finding is more about *whether to keep the convention at all* than about the notifications feature specifically — but if it stays on the books, the new code should follow it. The right home for the approve/decline action used from the notifications surface is either (a) hoisting `socialRepositoryProvider` to `shared/`, or (b) re-exporting an `approveFollowRequest`/`declineFollowRequest` helper from the notifications feature that calls into social, so the dependency is at the repository (data) layer rather than the widget (presentation) layer.
- Suggestion: Either (a) formally drop the no-cross-feature-imports rule from the arch checklist and update CLAUDE.md / the skill text to match observed reality, OR (b) move follow-request resolution into a small `features/notifications/repository/follow_request_action.dart` that owns the Dio call directly — the notifications feature already owns the user-visible action, the underlying endpoint is shared with the social feature but the *call site* is feature-internal. Pick one; the current state is the worst of both worlds.

---

## Not flagged

- The same-tx `EmitFollowApproved` + inline `DeleteFollowRequest` cleanup in `NotificationService.EmitFollowApproved` (notification_service.go:102-112) is the right shape — the row removal is a property of the approval lifecycle, not a separate concern.
- The `notificationListProvider` AsyncNotifier owning both server-truth list state AND the optimistic local mark-read patch (notification_providers.dart:52-158) is on the line but defensible: the alternative (separate provider for the optimistic patch) splits state across two notifiers and makes consistency harder to reason about. Acceptable for one feature; flag if a second similar pattern appears.
- Hand-written `fromJson` on `KamosNotification` (notification.dart:66-79) follows established project precedent for nullable nested objects (`CheckinUser` in `core/models/beverage.dart` does the same). Drift risk is low because the OpenAPI schema is small (8 fields) and the integration test asserts the wire shape end-to-end. The cumulative codegen-vs-hand divide is a separate concern beyond this diff.
- The router redirects `/inbox`→`/notifications` and `/search`→`/discover` (`frontend/lib/app/router.dart:158-159`) are clean — go_router's static redirects do not allocate a Page, do not show on the stack, and are removable in one line when ready. Not a technical-debt magnet at this scale.
- The `notifications` tag added to OpenAPI (`backend/openapi.yaml:36`) and the dedicated `KamosNotificationsApi` sub-facade (`frontend/lib/core/api/kamos_api.dart:727`) follow the established per-aggregate sub-facade pattern correctly.

## Cross-domain cross-references (for the orchestrator to route)

- ARCH-001 → perf-reviewer: the same-tx emit on the source-event hot path adds one INSERT per write; performance review should look at p95 latency for `ToggleToast`, `CreateComment`, `Follow` after this change. The argument for an outbox in ARCH-001 also intersects with the LEFT JOIN actor cost on the hot list path that the scope flagged for perf.
- ARCH-002 → security-reviewer: the cross-user offline-read hole that auth_state.dart guards against (per its own comment at lines 80-90) is real — if a new feature adds a long-lived provider without registering it on the auth invalidation list, that user's data leaks across a session swap. Worth a SEC spot-check that this diff didn't introduce any new long-lived per-viewer provider that auth_state doesn't invalidate.
- ARCH-006 → security-reviewer: `DeleteComment` doing role resolution inline at the handler layer (rather than via `CommentService.Delete`) is the same pattern that historically harbored SEC-006-style misses. Worth checking the role check in the handler path is equivalent to the service path's check.
- ARCH-007 → none directly, but the OpenAPI/Dart description drift is the kind of small lie that turns into a Flutter `null!` crash if a future contributor trusts the doc.
