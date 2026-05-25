# Performance Findings — Notifications + Nav Rewrite

**Branch:** `feature/notifications-and-nav-rewrite` vs `main`
**Reviewer:** perf-reviewer
**Verdict:** 0 CRITICAL · 0 HIGH · 3 MEDIUM · 4 LOW. Hot read paths well-indexed, cursor pagination intact, same-tx emit pattern adds negligible overhead. Findings are scale-impact tracking items, not current bottlenecks.

---

## [PERF-001] `MarkAllRead` is unbounded — a power user with 100k unread rows blocks one connection for seconds — MEDIUM

- **Pattern:** Unbounded Query
- **Location:** `backend/internal/repository/notifications.go:227-237` (`MarkAllRead`)
- **Finding:** `UPDATE notifications SET read_at = NOW() WHERE recipient_user_id = $1 AND read_at IS NULL` has no `LIMIT` and acquires a row lock on every matching row in one statement. The partial index `idx_notifications_recipient_unread` covers the row-finding, but the UPDATE itself is still O(unread set). A user who has never opened the inbox could have 10k–100k unread rows.
- **Scale impact:** At ~50k unread/user the UPDATE is on the order of a few hundred ms and holds a pool connection for the duration. At 1M unread (pathological account) it's seconds plus WAL volume. The mark-read rate limit is 1 rps + burst 60, so a malicious caller could trigger ~60 of these back-to-back.
- **Fix:** Cap with `... AND id IN (SELECT id FROM notifications WHERE recipient_user_id = $1 AND read_at IS NULL ORDER BY created_at DESC LIMIT 1000)` and loop until 0 rows affected; the loop returns the cumulative count. Alternative: document and accept (see PERF-002).
- **Cross-ref:** SendMessage to security-reviewer — combined with the 60-request burst limit this is a DB-amplification primitive for a single authenticated user.

## [PERF-002] `notifications` table has no TTL/archive — unbounded growth per recipient — MEDIUM

- **Pattern:** Unbounded Query / Index Bloat
- **Location:** `migrations/019_notifications.sql`; `backend/internal/jobs/` (no notification pruner)
- **Finding:** No scheduled job prunes old notifications. The cursor index `idx_notifications_recipient_created` is dense (not partial), so it grows linearly with user's lifetime activity. Dedupe partial indexes for `toast` / `follow` / `follow_approved` are bounded by `recipient × actor` cardinality (good), but `comment` and `follow_request` (no dedupe) are unbounded per event.
- **Scale impact:** Power recipient at ~10 notifications/day = ~3.7k/year; at 100/day = ~36k/year. The cursor query stays O(log n) for paging, but `MarkAllRead` (PERF-001) and CountUnread degrade with unread-set size.
- **Fix:** Schedule a job in `cmd/worker` (mirror `email_verification_cleanup`) that hard-deletes `notifications WHERE created_at < NOW() - INTERVAL '180 days' AND read_at IS NOT NULL`. Indexes already in place. Document retention window in SPEC §5.4.
- **Note:** `docs/db/indexes.md` already calls out the analogous "consider a TTL/archive process post-MVP" for check_ins. Same pattern applies here.

## [PERF-003] Same-tx emit doubles the lock fan-out of a viral check-in's toast trigger — MEDIUM (Suspected)

- **Pattern:** Algorithmic / Lock contention
- **Location:** `backend/internal/service/checkin_service.go:172-195` (`ToggleToast`) + `migrations/011_counter_caches.sql:122-141` (`trg_toasts_count`)
- **Finding:** A toast on a viral check-in already pays: INSERT into `toasts`, then AFTER trigger fires `UPDATE check_ins SET toast_count = toast_count + 1 WHERE id = $checkin` — exclusive row lock on the source check_in row, hot-row contention point. New code adds, in same tx, INSERT into `notifications` (1 row + 2 index updates: `idx_notifications_recipient_created` + `idx_notifications_toast_unique`). Doesn't touch `check_ins`, so no new lock contention introduced, but tx holds the `check_ins` row lock for one additional INSERT round-trip before COMMIT, widening the contention window on every concurrent toaster.
- **Scale impact:** At 100 concurrent toasters on the same viral check-in (~2ms today), notification INSERT widens each tx by ~0.5–1ms. ~30% longer queue per concurrent toast on the hottest check-in. Acceptable absolute terms.
- **Fix:** None required for MVP. If toast throughput becomes a known hotspot, move the notification emit to an after-commit hook (LISTEN/NOTIFY or outbox table drained by `cmd/worker`) so the source-event tx commits as fast as today. Would break the "same-tx" SPEC §5.4 invariant — only worth doing if profiling confirms a problem.

## [PERF-004] `_ResumeRefresher` has no debounce — rapid foreground/background cycles cause N requests — LOW

- **Pattern:** Flutter Rebuild / Network amplification
- **Location:** `frontend/lib/app/app.dart:54-78` (`_ResumeRefresherState.didChangeAppLifecycleState`)
- **Finding:** Every `AppLifecycleState.resumed` fires `unreadCountProvider.refresh()` unconditionally. On iOS, rapid system suspend/resume (notification-center / control-center pull-down, screen lock toggle) can fire multiple `resumed` callbacks in seconds. Each one is a `GET /v1/notifications/unread-count` round-trip.
- **Scale impact:** 5–10 spurious requests/minute on a fidgety user. Insignificant server-side (~0.5ms/query). Mild concern for battery on cellular. Possibly UX concern if unread count flickers.
- **Fix:** Track `_lastRefresh` and skip if within the last 30s. Or debounce: cancel in-flight refresh if a new resume fires within 1s.

## [PERF-005] VisibilityDetector batch window is fine, but client-side batch size has no cap — LOW

- **Pattern:** Network amplification
- **Location:** `frontend/lib/features/notifications/screens/notifications_screen.dart:94-105` (`_queueMarkRead`, `_flushBatch`)
- **Finding:** 1s batch window collects every id whose dwell timer fired. No upper cap. Pathological: a user rage-scrolls a 1000-item inbox slowly enough to satisfy dwell on every row in 1s window — POST carries 1000 ids (~36KB body). Server's `MarkRead` with `id = ANY($2::uuid[])` handles it, but it's wasteful.
- **Scale impact:** Realistically 10–30 ids/batch for a fast scroller. Pathological case requires both rage-scroll AND dwell-success, which is contradictory.
- **Fix:** If telemetry shows batches >50 ids in production, add `if (_pending.length >= 50) _flushBatch()` inside `_queueMarkRead`. No action needed now.

## [PERF-006] `NotificationRow` is a `ConsumerWidget` that doesn't subscribe — mark-read triggers full-list rebuild — LOW

- **Pattern:** Flutter Rebuild
- **Location:** `frontend/lib/features/notifications/widgets/notification_row.dart:34-86` + `providers/notification_providers.dart:117-125`
- **Finding:** When `markRead([id])` succeeds, the notifier patches the entire `items` list with a new immutable list. The screen's `ref.watch(notificationListProvider)` rebuilds the whole `ListView.separated`. `ListView.builder` only invokes the visible viewport's `itemBuilder` callbacks (bounded by viewport ~6–10 rows). Each `NotificationRow` (as `ConsumerWidget`) re-runs `build`, but only reads from `widget.notification` props — no actual `ref.watch` subscriptions other than implicit from parent. The one waste: `NotificationRow extends ConsumerWidget` — using `StatelessWidget` would avoid `ConsumerStatefulElement` overhead since the row only uses `ref` in `_handleTap`.
- **Scale impact:** None measurable at 20, 100, or 1000 rows (bounded by viewport).
- **Fix:** None required. If ever profiled as janky, convert `NotificationRow` to `StatelessWidget` and pass `VoidCallback onMarkRead` from parent. Phase 3 QA already accepted this trade-off.

## [PERF-007] OpenAPI `MarkReadRequest` `oneOf` impact on generated codegen clients — N/A for KAMOS — LOW (Informational)

- **Pattern:** Other
- **Location:** `backend/openapi.yaml` (`MarkReadRequest` schema)
- **Finding:** `oneOf` is notoriously the worst case for generated-client size in OpenAPI codegen toolchains (openapi-generator, openapi-typescript). Produces discriminated unions + runtime type guards, inflating client SDK size 2–3 KB per oneOf.
- **Scale impact:** Zero for KAMOS — Flutter bindings hand-written. Admin is React but doesn't touch this endpoint.
- **Fix:** None required. If a third party ever consumes our OpenAPI via codegen, consider splitting into two endpoints (`POST /notifications/read/{id}` + `POST /notifications/read-all`).

---

## Index coverage cross-check — PASS

| Query | Index used | Status |
|---|---|---|
| `ListByRecipient` cursor | `idx_notifications_recipient_created (recipient, created_at DESC, id DESC)` | Backward index scan, no sort, no extra filter. PASS |
| `CountUnread` | `idx_notifications_recipient_unread (recipient) WHERE read_at IS NULL` | Index Only Scan. PASS |
| `MarkRead` | `notifications_pkey` for `id = ANY($2)`, planner filters on recipient | Fine at typical batch sizes (≤20). PASS |
| Toast / follow / follow_approved dedupe | Partial uniques | PASS |
| `DeleteFollowRequest` | Cursor index leading on recipient with type+actor as filter | Acceptable. PASS |

LEFT JOIN to `users` on `actor_user_id` uses `users_pkey` — single-digit ms total per page. PASS.

Same-tx emit overhead per source event: +1 INSERT + 2 index entries (~0.5–1ms). Acceptable per PERF-003.
