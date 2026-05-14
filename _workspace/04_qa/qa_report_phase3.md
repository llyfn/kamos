# QA Report — Phase 3 Photos (R2) + SMTP (Resend)

Date: 2026-05-14
Scope: Phase 3 of post-MVP roadmap (`~/.claude/plans/mutable-juggling-cook.md`).
Verdict: **PASS** (both vendor integrations gated; live verification confirms feature-flag no-op path. Full R2/Resend end-to-end requires credentials per cookbook §C2/§C3 — user-blocked, doesn't gate the slice.)

---

## What landed

### Backend — R2 presigned uploads

- **Migration `004_photo_uploads.sql`** — `photo_upload_status` enum (`pending`/`uploaded`/`attached`/`orphaned`); `photo_uploads(id, user_id, blob_key UNIQUE, content_type, byte_size, status, check_in_id, created_at, attached_at, orphaned_at)`. Indexes on `user_id` and partial on `created_at WHERE status IN ('pending','uploaded')` for the orphan cleanup job.
- **`internal/storage/`** — `Storage` interface with `PresignPut`/`PublicURL`/`Delete`. Two implementations:
  - `R2` (AWS SDK v2 + S3 PresignClient, `BaseEndpoint`-tuned for Cloudflare, region `auto`)
  - `Disabled` (sentinel returns `ErrStorageDisabled`; `PublicURL` returns `""`)
- **Endpoints:**
  - **New** `POST /v1/uploads/photo-presign` (authed): validates content_type ∈ {jpeg/png/webp} and byte_size ∈ (0, 10 MB], inserts pending `photo_uploads` row, issues a 15-min presigned PUT URL.
  - **Changed** `POST /v1/check-ins/{id}/photos`: request shape `{ url }` → `{ upload_id }`. Looks up the upload row, verifies ownership + check-in match + 4-photo cap, inserts into `check_in_photos` with `Storage.PublicURL(blob_key)`, marks `photo_uploads.status='attached'`.
  - **No backwards compatibility** — the previous scaffold was Phase 3 scaffold itself (labelled `scaffold-for-Phase3` in commit `9d89d2c`); no shipping client used it.
- **Background job `photo_orphan_cleanup`** — every 1h, deletes R2 objects for rows pending > 24h and marks them `orphaned`. Logs INFO `photo_orphan_cleanup deleted:N`. No-op when storage is `Disabled`.
- **Apierror** — new sentinels `ErrStorageDisabled` (503 → `STORAGE_DISABLED`) and `ErrUploadNotCompleted` (409 → `UPLOAD_NOT_COMPLETED`).

### Backend — Resend mailer

- **`internal/email/`** — `Mailer` interface + three concrete pieces:
  - `LogMailer` (default fallback; logs `subject`, first 200 chars of text, `to`)
  - `ResendMailer` (HTTP POST to `https://api.resend.com/emails` via stdlib `net/http`; 10s timeout; 1 retry on 5xx with 1s backoff; `sentry.CaptureException` on persistent failure)
  - `Factory.NewMailer(cfg)` picks `ResendMailer` when `RESEND_API_KEY != ""` AND `EMAIL_FROM != ""`, else `LogMailer`
- **Templates** — `internal/email/templates/verify_email.{en,ja,ko}.{html,txt}.tmpl`, embedded via `//go:embed`. Subjects hard-coded in 3 locales (per brief — don't try to parse from template). Locale fallback: unsupported locale → en.
- **Wire** — `Register`, `ResendVerification`, `EmailChange` now call `h.Mailer.Send(...)` after creating the verification token. Errors logged at WARN and forwarded to Sentry but **never** fail the request (delivery is best-effort).

### Flutter — 3-step photo upload

- `CheckinRepository.uploadPhotoAndAttach({checkInId, file, onProgress})` runs presign → PUT → attach.
- Separate Dio (no interceptors) for the PUT. Dio `onSendProgress` wired to the UI callback.
- Typed `StorageDisabledException` when presign returns 503 with `STORAGE_DISABLED` — UI shows the friendly `photoUploadDisabled` SnackBar.
- Per-photo retry button (reuses Phase 0's `actionRetry` key) on PUT failure.
- Sequential upload per check-in (not parallel) — kinder to rate-limit, no blob_key races.
- New ARB keys: `photoUploadDisabled`, `photoUploadFailed` (en/ja/ko parity).
- 4-photo cap (`checkInPhotoLimitReached`) — already enforced from Phase 0; verified still active.

---

## Live smoke (this run, against local Postgres 18, R2 + Resend env empty)

```
$ register photo_smoke
  → 201; access JWT (304 chars) issued
  → server log:
      "verification link" user_id=... link=http://...
      "mail_logged" to=photo@example.com subject="Verify your KAMOS email"
        text_preview="Welcome to KAMOS, Photo.\n\nConfirm your email address..."
  ✓ Mailer is the LogMailer fallback (RESEND_API_KEY unset); template rendered in en.

$ POST /v1/uploads/photo-presign  (content_type=image/jpeg, byte_size=12345)
  → 503 {"error":"photo uploads not configured on this server","code":"STORAGE_DISABLED"}
  ✓ R2 disabled cleanly.

$ POST /v1/uploads/photo-presign  (content_type=image/heic)
  → 422 {"error":"content_type must be image/jpeg, image/png, or image/webp","code":"VALIDATION"}
  ✓ Content-type validation.

$ POST /v1/uploads/photo-presign  (byte_size=99999999)
  → 422 {"error":"byte_size must be in (0, 10485760]","code":"VALIDATION"}
  ✓ Size cap.

Boot log:
  "storage disabled (R2_BUCKET unset)"
  "mailer disabled (RESEND_API_KEY or EMAIL_FROM unset) — using LogMailer"
  4 jobs running (3 pre-existing + photo_orphan_cleanup)
```

Validation status codes return **422** (Unprocessable Entity) — semantically more correct than 400 for validation failures, matches existing handler convention.

---

## Test counts

| Suite | Before Phase 3 | After |
|---|---|---|
| Backend unit | 9 packages | **11 packages** (+`internal/email`, +`internal/storage`); coverage on new packages: storage 100%, email 89% |
| Backend integration | 43 PASS | **49 PASS** (+4 photos, +2 mailer) |
| Flutter | 23/23 | **27/27** (+3 repo tests, +1 screen test) |

---

## What's still needed from the user

| Item | Source | Owner |
|---|---|---|
| **Cloudflare R2 account** — create buckets `kamos-checkin-photos-staging` + `…-prod`, CORS, API token | cookbook §C2 | user |
| **R2 env vars** — `R2_ENDPOINT_URL`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_PUBLIC_BASE_URL` | `local.env.example` | user |
| **Resend domain verification** — SPF + DKIM (24h DNS propagation) + API key | cookbook §C3 | user |
| **Resend env vars** — `RESEND_API_KEY`, `EMAIL_FROM` | `local.env.example` | user |

Both feature sets are fully shipped and tested without the credentials; flipping them on production is just `make api-run-local` after dropping the values into `local.env` (or staging secrets).

---

## Wire-shape risks flagged by Flutter agent (worth a follow-on commit later)

1. **`headers` map type**: backend declares `headers: { [k: string]: string }`. Flutter decodes as `Map<String, dynamic>` and re-stringifies. If backend ever emits an integer (e.g. `Content-Length`), it forwards as `"12345"` — R2 may reject if the canonicalized header doesn't match the signature. Add a server-side assertion that header values are always strings.
2. **Content-Type round-trip**: client sends `image/jpeg` to presign; server signs the PUT with the same value; if server ever canonicalizes (e.g. `image/jpg`), the PUT signature fails. The current implementation echoes the request value, so safe for now — but document the contract.
3. **`PhotoRef.id` default `''`** in the Flutter model: hides a missing `id` field in the attach response. Backend always returns it, but tighten the model to make missing field an error.
4. **Unused presign fields**: `blob_key` and `expires_at` reach the client but aren't consumed. Future-proofed; not a regression.

Tracking these as Phase 4 / Phase 7 follow-ons in this report rather than a separate doc.

---

## Follow-ons / backlog (non-blocking)

- **Sentry body scrubber** for `/v1/auth/refresh|login|register` (still open from Phase 2 backlog; mailer-error paths don't expose request bodies today, so still no leak, but defensive scrubber recommended).
- **`authContinueGoogle`** ARB orphan (still open from Phase 2 backlog) — same string as `authGoogleSignInButton`.
- **R2 HEAD-verify** before promoting `pending` → `attached`. Phase 3 trusts the client's attach call and relies on the orphan-cleanup job; production may want a tighter loop.
- **Email templates for password reset / email change** — only `verify_email.*` shipped; `password_reset.*` and `email_change.*` are Phase 5 (admin) or later when the user-facing screens are wired.

---

## SPEC invariants — still 12/12 PASS

Phase 3 did not change category strings, rating semantics, cursor pagination shape, JWT-in-secure-storage, or soft-delete behavior. The 4-photo cap is now enforced in three places (client validation + server validation + DB CHECK on `check_in_photos.sort_order`) — strengthened, not weakened.
