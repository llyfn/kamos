# Style + Maintainability Findings — Notifications + Nav Rewrite

**Branch:** `feature/notifications-and-nav-rewrite` vs `main`
**Reviewer:** style-reviewer
**Verdict:** 0 HIGH/CRITICAL · 11 MEDIUM · 4 LOW · 3 SUGGESTION

---

## [STYLE-001] SPEC §5.4 contradicts the implementation on `follow_request` retention — MEDIUM

- **Location:** `SPEC.md:207`
- **Finding:** SPEC says "The original `follow_request` row remains after approval; a separate `follow_approved` row is created for the original requester." Code does the opposite — `NotificationService.EmitFollowApproved` deletes the `follow_request` row in the same tx. Integration test `TestNotifications_PrivateFollowLifecycle` asserts deletion. `docs/db/query_patterns.md:672` + migration 019 comments document deletion. SPEC is the only place still claiming the row "remains".
- **Fix:** Rewrite SPEC.md:207 to: "On approval, the original `follow_request` row is removed from the approver's inbox and a `follow_approved` row is created in the original requester's inbox."

## [STYLE-002] design/notifications_ux.md references ARB keys that do not exist (or use a stale prefix) — MEDIUM

- **Location:** `design/notifications_ux.md:246,247,257-261`
- **Finding:** Design doc references 7 ARB keys that don't ship as documented:
  - `notificationsMarkAllError` — only in design + design `data.jsx`; not in ARB. Screen swallows error at `notification_providers.dart:135`; design §3.3 inline-error behavior unimplemented.
  - `notificationsEnd` — design references it; not in ARB.
  - `notificationVerbToast/Comment/Follow/FollowRequest/FollowApproved` — design uses `notification*` prefix; Flutter shipped as `notifVerb*`. 5 drifted names.
- **Fix:** Update `design/notifications_ux.md` §4.2 / §4.3 to use shipped names. Either add missing `notificationsMarkAllError` + `notificationsEnd` keys to all three ARBs and wire them, OR strike both rows with a "deferred" note.

## [STYLE-003] ARB key prefix inconsistency within the notifications feature — MEDIUM

- **Location:** `frontend/l10n/intl_en.arb:222-236` (and `ja` / `ko` mirrors)
- **Finding:** Notifications introduces two prefixes for one feature: `notifications*` for screen-level keys vs `notifVerb*` for per-type templates. Every other feature uses one prefix (`feed*`, `search*`, `auth*`, `checkIn*`, `venuePicker*`, `flavor*`, `settings*`).
- **Fix:** Pick one prefix and rename. Either `notifications*` throughout or `notif*` throughout. Same rename in 3 ARBs + generated code + 7 call sites.

## [STYLE-004] `NotificationRepo` mixes Tx-suffixed and non-suffixed names against established pattern — MEDIUM

- **Location:** `backend/internal/repository/notifications.go:27,42,55,71,83,99`
- **Finding:** Every other repo with both pool-backed and tx-backed variants uses `Tx` suffix on the tx variant (`FollowTx`, `CreateTx`, `ToggleToastTx`). `NotificationRepo` introduces six tx-backed methods (`InsertToast`, `InsertComment`, `InsertFollow`, `InsertFollowRequest`, `InsertFollowApproved`, `DeleteFollowRequest`) without the suffix.
- **Fix:** Rename to `InsertToastTx`, `InsertCommentTx`, `InsertFollowTx`, `InsertFollowRequestTx`, `InsertFollowApprovedTx`, `DeleteFollowRequestTx`. Read paths (`ListByRecipient`, `CountUnread`, `MarkRead`, `MarkAllRead`) stay unsuffixed — they run on the pool.

## [STYLE-005] `domain.NotificationType*` constants are declared but never used — LOW

- **Location:** `backend/internal/domain/types_notification.go:11-17`
- **Finding:** All five `NotificationTypeToast`/`Comment`/`Follow`/`FollowRequest`/`FollowApproved` constants are exported and documented but have zero callers in `backend/`. Repository hardcodes literal type strings.
- **Fix:** Either delete the constant block, or wire one consumer (e.g., a test asserting OpenAPI enum matches constants).

## [STYLE-006] Stale "bell badge → inbox" entries in `design/README.md` — LOW

- **Location:** `design/README.md:188,226`
- **Finding:** Two surviving descriptions reference removed FAB-era UI: `FeedScreen.jsx ... bell badge → inbox` and `| Follow-request inbox (§5.4) | ... InboxScreen.jsx, Primitives.jsx::Badge |`. Nav rewrite removed the bell. `HANDOFF.md:17` correctly describes new state but README coverage table wasn't updated.
- **Fix:** Update line 188 to drop "bell badge → inbox". Update §5.4 coverage row to point at `NotificationsScreen.jsx` + the unread dot.

## [STYLE-007] `docs/db/query_patterns.md` §16h "in its place" wording is misleading — LOW

- **Location:** `docs/db/query_patterns.md:672`
- **Finding:** "The original `follow_request` notification is deleted (see 16i) so it stops showing in the requester's inbox; in its place the requester sees the new `follow_approved` row." Two errors: (1) the `follow_request` row is in the **approver's** inbox, not the requester's; (2) the new `follow_approved` row goes to the **requester's** inbox — no swap, two different inboxes.
- **Fix:** Rewrite: "The approver's `follow_request` notification is deleted (see 16i) so it stops showing in their inbox once the request is resolved. The requester receives a new `follow_approved` row in their own inbox."

## [STYLE-008] No test exercises the 5-tab order on `KamosTabBar` — MEDIUM

- **Location:** `frontend/lib/shared/widgets/kamos_tab_bar.dart` (no test file)
- **Finding:** Bottom-nav rewrite is a visible MVP-vs-post-MVP regression risk. Nothing asserts that `KamosTabBar` renders exactly five tabs in order `Feed · Lists · Discover · Notifications · Me`, or that `_indexFor` returns the right index. Unread-dot logic also untested.
- **Fix:** Add `frontend/test/kamos_tab_bar_test.dart` with three widget tests: (a) renders 5 tabs in order, (b) `_indexFor` maps `/collections`/`/discover`/`/notifications`/`/me`/`/` to 1/2/3/4/0, (c) unread dot present when count>0 / absent when 0.

## [STYLE-009] No test exercises `_ResumeRefresher` lifecycle behavior — MEDIUM

- **Location:** `frontend/lib/app/app.dart:46-78`
- **Finding:** `_ResumeRefresher` is a `WidgetsBindingObserver` whose `didChangeAppLifecycleState(AppLifecycleState.resumed)` invalidates `unreadCountProvider` when authenticated. Third refresh hook from design §3.5 and the only one without coverage.
- **Fix:** Add a widget test that pumps `_ResumeRefresher` with a fake `UnreadCountNotifier`, drives `AppLifecycleState.resumed` via `WidgetsBinding.instance.handleAppLifecycleStateChanged`, asserts `refresh` called once. Sibling test for unauthenticated case (refresh NOT called).

## [STYLE-010] Verb-line ARB strings have no documentation on placeholder presence — LOW

- **Location:** `frontend/l10n/intl_en.arb:227-236` (and `ja` / `ko`)
- **Finding:** `notifVerb*` strings render via `template.split(actorName)` with fallback when `parts.length != 2`. If translator drops `{actor}`, row silently loses actor name. Other placeholder keys in same file (e.g., `feedCardAtVenue`) have descriptions.
- **Fix:** Add `description` on each of 5 `@notifVerb*` entries: "Translator: include `{actor}` exactly once; it renders bold inline."

## [STYLE-011] `notification_providers.dart` swallows three error paths without telemetry — MEDIUM

- **Location:** `frontend/lib/features/notifications/providers/notification_providers.dart:91,113,135,170`
- **Finding:** Four `catch (_)` blocks. Lines 91 (loadMore rollback), 113 (markRead idempotent), 170 (unreadCount fallback) — fine. **Line 135 (markAllRead)** — design §3.3 specifies "rows snap back to unread + inline error appears"; implementation does neither. Silent failure means user thinks "mark all read" worked when it didn't and the unread dot stays on after next refresh.
- **Fix:** Lines 91, 113, 170 leave alone. Line 135 — implement design §3.3 (revert optimistic local patch on failure + emit toast via `apiToastBusProvider`) OR amend design doc to say "swallow silently" explicitly.

## [STYLE-012] `_FollowRequestActions._resolve` swallows error without re-enabling buttons in one path — MEDIUM

- **Location:** `frontend/lib/features/notifications/widgets/notification_row.dart:273-300`
- **Finding:** `try { ... } catch (_) { if (mounted) setState(() => _busy = false); }` is good for network-failure. But on **soft-deleted actor branch** (line 277-281), `_busy` is never set true — method early-returns after `removeLocal`. Comment says "server may have a tombstone-safe path" — code unconditionally skips the API call, so the comment is wrong.
- **Fix:** Either (a) always set `_busy = true` regardless of branch, OR (b) update comment to "Soft-deleted actor — no actor.id to send to the server, so just hide the row locally; underlying notification will be cleaned up server-side by FK cascade."

## [STYLE-013] `MarkReadRequest` IDOR comment duplicated across handler + service — SUGGESTION

- **Location:** `backend/internal/handlers/notifications.go:73-77` AND `backend/internal/service/notification_service.go:140-144`
- **Finding:** Same rationale written twice in different words. Future edits will desync.
- **Fix:** Keep comment on handler (closest to wire contract). Service comment strips to: "Pool-scoped IDOR: SQL WHERE restricts UPDATE to recipient_user_id = $caller (see handler doc for oracle rationale)."

## [STYLE-014] OpenAPI parity test confirms routes but not response-shape parity for new endpoints — LOW

- **Location:** `backend/tests/integration/notifications_integration_test.go` + general OpenAPI parity coverage
- **Finding:** Notifications integration tests cover behavior thoroughly. No test asserts response JSON shape matches `Notification` schema declared in `openapi.yaml:2976`. Schema drift wouldn't fail any test.
- **Fix:** Add Go integration test calling each endpoint asserting unmarshalled response has every required field documented in openapi.yaml. Lightweight option: assert `row.CheckInID != nil && row.CommentID != nil` for comment-type in `TestNotifications_CommentEmitsRow`.

## [STYLE-015] `visibility_detector` dependency added without updated rationale — SUGGESTION

- **Location:** `frontend/pubspec.yaml:36`
- **Finding:** `visibility_detector: ^0.4.0+2` added for mark-on-scroll. CLAUDE.md says "No new dependencies without asking." The dep is justified but neither the skill's baseline list nor an inline rationale was updated.
- **Fix:** Add `visibility_detector` to baseline list in `.claude/skills/flutter-feature/SKILL.md` with one-line rationale OR add rationale as inline comment in pubspec.

## [STYLE-016] Magic shadow color `Color(0x0F0F2350)` duplicated rather than centralized — SUGGESTION

- **Location:** `frontend/lib/features/notifications/widgets/notification_row.dart:57` AND `frontend/lib/shared/widgets/kamos_card.dart:33`
- **Finding:** `NotificationRow` rolls its own card surface with same shadow + radius + border as `KamosCard`. Phase 3 QA flagged as NR-05 (deferred). Shadow color is one symptom; broader issue is two cards diverge by accident.
- **Fix:** Move `Color(0x0F0F2350)` (and 2px-blur + 1px-y-offset) into `KamosTokens` as `t.cardShadow` and use from both widgets. Cross-ref to arch-reviewer for the KamosCard non-reuse decision.

## [STYLE-017] `feedEmptyBody` references "Discover" but screen file still `search_screen.dart` — SUGGESTION

- **Location:** `frontend/l10n/intl_en.arb:18,21` and `frontend/lib/features/search/screens/search_screen.dart`
- **Finding:** ARB copy was updated (Discover); route added (`/discover`); underlying screen file still `search_screen.dart` and import path `features/search/screens/search_screen.dart`. Intentional scope narrowing but creates "where do I find Discover?" friction. `searchHeader` key has value "Discover" — name no longer describes value.
- **Fix:** Either rename directory + file (larger change, out of scope), OR add one-line comment at top of `search_screen.dart` explaining naming carryover. Consider renaming `searchHeader` → `discoverHeader` in next ARB pass.

## [STYLE-018] Test rename inconsistency — `notification_*` vs `comments_section_*` — SUGGESTION

- **Location:** `frontend/test/notification_model_test.dart`, `frontend/test/notification_widgets_test.dart`
- **Finding:** Go integration test is `notifications_integration_test.go` (plural — matches table name); Dart tests are `notification_*` (singular). Mixed convention across Dart tests.
- **Fix:** Optional. If aligning, rename to `notifications_model_test.dart` / `notifications_widgets_test.dart`.

---

## Top 5 findings to action first

1. **[STYLE-001]** — SPEC.md §5.4 line 207 is wrong; SPEC is source of truth and currently contradicts 3 implementation surfaces.
2. **[STYLE-002]** — design/notifications_ux.md references 7 ARB keys that don't exist with those names; engineers using as checklist will silently misimplement (already did — see STYLE-011).
3. **[STYLE-004]** — `NotificationRepo` skipping `Tx` suffix breaks established repository naming pattern.
4. **[STYLE-011]** — `markAllRead` swallows failure silently instead of design-specified snap-back + inline error.
5. **[STYLE-008]** + **[STYLE-009]** — No test covers 5-tab order on `KamosTabBar` or `_ResumeRefresher` lifecycle.

## Cross-domain notes

- **For arch-reviewer:** STYLE-016 — KamosCard non-reuse (phase 3 QA NR-05).
- **For security-reviewer:** none — swallowed errors flagged here are on UX-only paths, no auth implication.
