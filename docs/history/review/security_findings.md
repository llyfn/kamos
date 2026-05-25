# Security Findings — Notifications + Nav Rewrite

**Branch:** `feature/notifications-and-nav-rewrite` vs `main`
**Reviewer:** security-reviewer
**Verdict:** 0 CRITICAL · 1 HIGH · 3 MEDIUM · 2 LOW

---

## [SEC-001] Soft-deleted comment author PII leaks in comment list responses — HIGH

- **OWASP:** A01 Broken Access Control / A04 Insecure Design
- **Location:** `backend/internal/repository/comments.go:98-108` (`CommentRepo.List`), `comments.go:164-194` (`CommentRepo.Get`), `comments.go:277-294` (`CommentRepo.ListForAdmin`)
- **Finding:** All three queries `LEFT JOIN users u ON u.id = c.user_id` without filtering `u.deleted_at IS NULL`, and the scan does not pull `u.deleted_at`. Soft-deleted users — accounts within the 30-day username-hold window per SPEC §6 — still surface their username, display_username, display_name, and avatar_url to every viewer of a comment thread. **Exact same bug Phase 2 QA caught and fixed for `notifications.ListByRecipient` (commit a3388b6).** The same pattern was missed in the comments path that this branch also touched (it added `CreateTx`, exercising the same file).
- **Attack scenario:** A user soft-deletes their account intending the username-hold to obscure their identity. Any reader of any check-in they previously commented on still sees their full profile (name + avatar). An adversary who knew the user pre-deletion can confirm a deletion happened, but more importantly can scrape display data via the comment surface for the 30-day window.
- **Fix:** Mirror the notifications fix. Select `u.deleted_at` and in the Go scan, if `actorDeletedAt != nil` set `row.User = nil` so the row hydrates as "Deleted user" the way `hydrateCommentUser` already supports for the hard-purge case. Apply to `List`, `Get`, and `ListForAdmin` (admin variant should still surface original user ID for moderation linkage but blank the display fields).
- **Cross-reference for arch:** "LEFT JOIN users without deleted_at filter" is a recurring failure mode. Consider a repo-level helper (`scanActor(*time.Time, ...)`) that normalizes the soft-delete → nil pattern across every actor join site.

## [SEC-002] CreateComment endpoint skips parent check-in privacy gate, now amplified by notifications — MEDIUM

- **OWASP:** A01 Broken Access Control
- **Location:** `backend/internal/handlers/comments.go:66-87` (`CreateComment`), `backend/internal/service/comment_service.go:70-93` (`CommentService.Create`), `backend/internal/repository/comments.go:31-75` (`CreateTx`)
- **Finding:** `POST /v1/check-ins/{id}/comments` only verifies that the parent check-in exists and is not soft-deleted. It does NOT call `AssertViewerCanSeeCheckin`. The corresponding `ListComments` handler (lines 33-61) DOES call the gate. The mutating sibling diverges. This was pre-existing, but **this branch's notification emit makes the gap newly meaningful**: when a non-follower comments on a private user's check-in, the private user now receives a `comment` notification revealing that an unauthorized viewer obtained their check-in id and posted to it.
- **Attack scenario:** Attacker obtains a check-in UUID belonging to a private profile (forwarded deep link, leaked screenshot URL). Pre-branch: silent comment-pollution. Post-branch: every comment fires a notification "@attacker commented on your check-in" — confirming targeting succeeded and surfacing harassment content directly into inbox without the owner having opened the comment thread. The toast path IS gated (`ToggleToastTx` calls `r.checkVisibility` at `checkins.go:402`).
- **Fix:** In `CommentService.Create` (or in `CreateTx`), call `s.checkins.AssertViewerCanSeeCheckin(ctx, checkInID, userID)` before opening the transaction. Returns `ErrNotFound` for non-followers of private profiles, matching the established 404-on-private convention.
- **Cross-reference for arch:** Toast and comment are sibling write paths against the same parent resource; one gates visibility, one doesn't. The branch fixed the same-tx invariant but not the same-gate invariant.

## [SEC-003] `POST /v1/notifications/read` accepts unbounded `ids[]` array — request amplification + DB load — MEDIUM

- **OWASP:** A04 Insecure Design
- **Location:** `backend/internal/handlers/notifications.go:78-119`, `backend/openapi.yaml:3011-3032` (`MarkReadRequest`), `backend/internal/server/router.go:294-296` (rate-limit)
- **Finding:** The handler validates each `ids` entry as UUID but does not cap array length. The /v1 group's `MaxBytes(1 << 20)` allows ~26,000 UUIDs per request. Mark-read endpoint per-user rate limit is 1 rps + burst 60, so an attacker holding a single authed JWT can fire ~60 requests × 26k UUIDs = 1.5M UUID parses + 60 × `UPDATE ... id = ANY($2::uuid[])` per ~minute. IDOR-safe (UPDATE scopes by recipient_user_id) but each request burns tx + array deserialization. OpenAPI asserts `minItems: 1` but no `maxItems`. Phase 2 integration tests don't exercise oversized batch.
- **Attack scenario:** A single low-privilege account scripts the mark-read endpoint with maximum-sized random-UUID batches to exhaust DB connection time and Go GC on API replicas. Each request returns `{"marked": 0}` — no data leak — but upstream tax on legitimate users is real. The legitimate Flutter client only batches up to one page of inbox (≤20 ids) per call per design `_kMarkReadBatchWindow = 1s`, so a sensible cap at e.g. 100 ids is non-disruptive.
- **Fix:** Add `if len(req.IDs) > 100 { httperr.WriteValidation(w, "ids cannot exceed 100 entries"); return }` in `MarkNotificationsRead`. Mirror with `maxItems: 100` in OpenAPI `MarkReadRequest` first variant. Optionally tighten per-user rate limit on this route from `burst 60` to `burst 20`.

## [SEC-004] `_FollowRequestActions` re-uses a server-stale `actor.id` after row resolution race — LOW

- **OWASP:** A07 Auth & Session Failures (defensive)
- **Location:** `frontend/lib/features/notifications/widgets/notification_row.dart:269-300`
- **Finding:** Inline Approve/Decline buttons call `repo.approve(actor.id)` / `repo.decline(actor.id)` where `actor.id` is the original requester's UUID lifted from the notification payload. If the same user opens the inbox on two devices, the second click POSTs to `/v1/follow-requests/{actor.id}/approve` and the server's `ApproveTx` returns `ErrNotFound`. The Flutter catch block at line 297 sets `_busy = false` silently — user sees the button re-enable with no toast.
- **Attack scenario:** Not directly exploitable. Defense-in-depth: a confused user clicking through stale notifications cannot distinguish "I just approved you" from "your request was already gone".
- **Fix:** Surface the ErrNotFound case as a toast ("Request no longer pending"). Server side already correct.

## [SEC-005] Sentinel actor stub renders unverified actor display name from API response — LOW (informational)

- **OWASP:** A03 Injection (XSS — defense-in-depth note)
- **Location:** `frontend/lib/features/notifications/widgets/notification_row.dart:118-184`, `models/notification.dart:66-79`
- **Finding:** `NotificationRow` renders `actor.displayName` / `actor.displayUsername` via `Text.rich`. Flutter `Text` doesn't interpret markup — no XSS. Verb template splitter (`_template`) splits on rendered `actorName` to bold the actor span. Edge case where actor's display name contains template surrounding characters → graceful fallback to plain weight.
- **Attack scenario:** Cosmetic display-name spoofing only. SPEC `domain.SanitizeText` already rejects control/bidi codepoints.
- **Fix:** None required.

---

## Spot-checks that PASSED

- **Cursor envelope:** carries no recipient/actor ID. No user-enumeration timing oracle.
- **IDOR on mark-read:** SQL filters by `recipient_user_id = $1`. Integration test confirmed.
- **Approve/Decline reachability:** scoped by `followed_id = $2 (uid) AND status = 'pending'`. No horizontal escalation.
- **Cascade migration 020:** `ON DELETE CASCADE` for `check_in_id` / `comment_id` wipes orphan rows. No audit-trail requirement in SPEC §5.4 or §11 violated.
- **`_ResumeRefresher`:** gated on `auth.isAuthenticated` — no requests while signed out.
- **Flutter secure storage:** unchanged.
- **Admin auth / CSRF:** untouched, no risk introduced.
- **ARB key removals:** no dangling references.
- **JWT/refresh handling:** untouched.

---

## Cross-reviewer notes

- **For arch-reviewer:** SEC-001 and SEC-002 both point at the same architectural problem — sibling repository methods diverge on cross-cutting concerns (visibility gate, soft-delete actor handling). Suggest extraction of a `gates.assertCanViewCheckin(ctx, viewer, checkInID) → ErrNotFound` service helper and a `scanActor(deletedAt *time.Time, ...) *domain.CheckinUser` helper.
- **For perf-reviewer:** SEC-003 fix is cheap (O(1) length check). No perf coordination needed.
- **For style-reviewer:** SEC-004 is downstream of "swallowed error masks user-visible state" smell.
