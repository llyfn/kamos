# QA Report — Backend (Phase 2 incremental)

Date: 2026-05-11
Scope: All backend modules — auth, users, beverages, breweries, check-ins, feed, social, collections, search, taxonomy. Schema, OpenAPI, Go source.
Status: **PASS WITH MINOR**

Verdict rationale: every SPEC invariant required for MVP scaffolding is enforced at the correct layer (handler validation + DB CHECK + repository ownership). `go build`, `go vet`, and `go test` all clean. No BLOCKERs. Two MAJORs relate to MVP-deferred work (SMTP send, blob storage) that were explicitly punted by the backend-engineer; both have stubs called out in comments. Several MINORs are JSON-tag / OpenAPI cosmetic mismatches that the Flutter side will need to be aware of when generating models.

---

## BLOCKERs

(none)

---

## MAJORs

### Issue: Photo upload is URL-by-reference; no blob-storage strategy or `/uploads` endpoint exists

- Severity: MAJOR (deferred to production wiring; OK for MVP scaffolding)
- Boundary: `internal/handlers/checkins.go:174` ↔ `openapi.yaml /v1/check-ins/{id}/photos`
- SPEC reference: §4.1 (photos), no SPEC contract for storage strategy
- Problem: `POST /v1/check-ins/{id}/photos` accepts `{ "url": "..." }` and stores the string as-is. There is no validation that the URL is reachable, no presigned-URL endpoint for the Flutter client to upload through, no orphan-cleanup, and no signed URL or domain allowlist. The 4-cap is enforced; the storage layer is not. Backend-engineer flagged this explicitly in `README_backend.md` "Photo upload (MVP decision)".
- Fix: not pre-launch; document as `backend-engineer` punch list before public beta. The Flutter side must mirror by accepting a URL field; do not implement multipart upload now.

### Issue: Verification email is logged, not sent

- Severity: MAJOR (deferred — MVP can use the logged link manually)
- Boundary: `internal/handlers/auth.go:75-80`, `:295-298`, `:370-373`
- SPEC reference: §3.1 (24h verification link)
- Problem: SMTP sender is a `// TODO`. `Register`, `ResendVerification`, and `EmailChange` all create the token row but only `Log.Info(...)` the link. Dev environments can click the logged URL; production cannot ship like this.
- Fix: wire SMTP via `cfg.SMTPHost/Port/User/Pass` before any public deploy. Out of scope for Phase 3 frontend start — Flutter can be developed and tested against this server today.

---

## MINORs

### Issue: `domain.Brewery.BeverageCount` field is not in the OpenAPI schema

- Severity: MINOR
- Boundary: `internal/domain/types.go:271` ↔ `openapi.yaml#/components/schemas/Brewery`
- Problem: `BeverageCount *int json:"beverage_count,omitempty"` exists in the Go struct but the OpenAPI `Brewery` schema does not list it. It is never populated by the repository, so the field is always omitted in practice — but the contract drift is a future bug.
- Fix: `backend-engineer` — either delete the unused field or add it to the OpenAPI schema and populate it in `BreweryRepo.Detail`.

### Issue: `omitempty` on nullable JSON tags conflicts with OpenAPI `nullable: true`

- Severity: MINOR
- Boundary: `internal/domain/types.go:265-271` (Brewery), `:284-294` (Beverage), `:213` (UpdateMeRequest) ↔ `openapi.yaml` Brewery, Beverage, UpdateMeRequest
- Problem: Fields like `Brewery.Prefecture *string json:"prefecture,omitempty"` will emit no key at all when nil. The OpenAPI schema declares the same field `nullable: true`, which strongly suggests the contract is "present-and-null" rather than "absent". For required-or-absent fields this is fine; for nullable ones the client will see two states for the same semantic. Affects all `*string`/`*int`/`*I18nText` fields with `omitempty` whose OpenAPI counterpart is `nullable: true`.
- Fix: `backend-engineer` — for fields the OpenAPI marks `nullable: true`, drop `,omitempty` so JSON encodes `"prefecture": null`. Alternatively, change the OpenAPI to drop `nullable` and rely on absence (then leave `omitempty`). Pick one and apply consistently.
- Impact on Flutter: the model parser must accept both `null` and absent. Tolerated by `freezed`/`json_serializable` with `@JsonKey(includeIfNull: false)` patterns, but worth flagging now so it doesn't surface as a Flutter parse bug.

### Issue: I18nText `KO,omitempty` will drop empty Korean strings from responses

- Severity: MINOR
- Boundary: `internal/domain/types.go:30` ↔ `openapi.yaml#/components/schemas/I18nText`
- Problem: `KO string json:"ko,omitempty"` causes empty `ko` strings to be omitted entirely from the response (different from "null"). OpenAPI defines `ko` as optional (only `en` is required), so absence is contractually OK and matches the SPEC §8 client-side fallback expectation. No bug — but the Flutter layer must treat "ko key missing" identically to "ko key empty".
- Fix: no code change required; ensure Flutter `I18n.resolve(locale)` treats both as "fall back to en". The handoff message in `01_design/HANDOFF.md` already calls this out.

### Issue: Search returns up to `limit+1` rows per type (beverage + brewery), so a typeless query can exceed `limit` total

- Severity: MINOR
- Boundary: `internal/repository/search.go:22-87` ↔ `openapi.yaml /v1/search`
- Problem: When `type` is omitted, the repo runs both the beverage and brewery sub-queries, each with `LIMIT $3 = limit+1`, then concatenates. `SliceAndCursor` then truncates to `limit`. The next-cursor encodes only the last *item's* id; on the following request the beverage and brewery sub-queries each filter by `id < cursor` which mixes id-spaces across two tables. This works (UUIDs are globally unique strings) but the cursor semantics are imprecise: the brewery sub-query could "skip ahead" of where the beverage page truly ended.
- Fix: `backend-engineer` — either (a) split the endpoint into `/search/beverages` and `/search/breweries`, or (b) keep the mixed endpoint but encode a per-type cursor in the opaque token (e.g. `{bev_id, brw_id}`), or (c) accept the approximation and document the limitation in OpenAPI. Not blocking — typeless search is rare and the result quality is fine within a single page; just won't paginate cleanly past page 1.

### Issue: `decodeJSON` uses `DisallowUnknownFields`, but `UpdateCheckin` re-decodes via `json.Unmarshal` (non-strict) on the fallback path

- Severity: MINOR
- Boundary: `internal/handlers/checkins.go:107-112`
- Problem: After the strict decode fails (because of `clear_*` fields not declared in the type), the code falls back to `json.Unmarshal(rawBytes, &req)` which silently ignores unknown fields. This is the right outcome (the fallback is the point), but the wider effect is that clients can send arbitrary extra fields on a PATCH and not get a 4xx, which is inconsistent with strict decode elsewhere.
- Fix: `backend-engineer` — declare `ClearRating`, `ClearReview`, `ClearPrice` on `UpdateCheckinRequest` (already done at `types.go:412/414/417`) so the strict decode succeeds. The double-decode path becomes dead and can be removed. Behavior is the same; the dead code is the bug.

### Issue: `LocalizedDefaultCollections` returns English for all locales

- Severity: MINOR (intentional; flagged in code)
- Boundary: `internal/domain/types.go:660-666`
- SPEC reference: §6.1
- Problem: The function is a deliberate stub — every locale gets `"Inventory"` / `"Wishlist"`. Designer has not pinned localized strings; the SPEC says these collections are renameable so users can fix themselves.
- Fix: `designer` to confirm localized strings for ja and ko; `backend-engineer` to switch on `locale` once received. Not blocking Flutter.

### Issue: `GoogleClientSecret` is read into `Config` but never used

- Severity: MINOR
- Boundary: `internal/config/config.go:20,39`
- Problem: `GoogleClientSecret` is loaded from env but the codebase never references it. The `.env.example` and config comments explain it is kept for "completeness of OAuth2 if a future server-side flow is added", which is reasonable, but the unused field is dead weight today.
- Fix: optional. `backend-engineer` may leave it as documentation. The SPEC invariant (the secret never reaches the Flutter app) is satisfied — the secret is server-side env only and is not in any handler response or log.

### Issue: `UpdateMeRequest.AvatarURL` and `Bio` have `omitempty` plus null-clearing semantics

- Severity: MINOR
- Boundary: `internal/domain/types.go:212-215` ↔ `openapi.yaml#/components/schemas/UpdateMeRequest`
- Problem: The PATCH /v1/users/me handler distinguishes "omitted" (don't change) from "null/empty" (clear the value) using the explicit `bioSet`/`avSet` booleans in the repository. The Go field tag `bio,omitempty` would marshal empty string as missing on the *response* side — but for *request* decoding this is fine. The OpenAPI doesn't document the clear-by-null semantics; clients won't know they can null out a bio via PATCH.
- Fix: `backend-engineer` to add a note to the OpenAPI `UpdateMeRequest` description: "send `null` to clear an optional field (bio, avatar_url); omit to leave unchanged".

### Issue: Domain `User` struct exposes `Email` and `EmailVerified` on public lookups

- Severity: MINOR
- Boundary: `internal/handlers/users.go:82-109` ↔ `openapi.yaml#/components/schemas/User`
- Problem: `publicProfile` embeds `domain.User`, which includes `email` and `email_verified`. The OpenAPI `User` schema also lists those as required. This means `GET /v1/users/{username}` returns the target user's email to any caller. SPEC §3.2 does not explicitly say email is private, but exposing it to unauthenticated viewers is unconventional and a privacy hazard.
- Fix: `backend-engineer` — split into `User` (private, for `/users/me`) and `PublicUser` (no email) in both the domain types and the OpenAPI schema. Or zero out the email in the `publicProfile` response. Flag for product to confirm.

---

## Stub inventory

| File:line | Marker | Summary |
|---|---|---|
| `internal/auth/jwt.go:98` | CONFIGURE | `GOOGLE_CLIENT_ID` must be set before Google sign-in works; verifier returns clear error if unset. |
| `internal/handlers/auth.go:75` | TODO | Wire SMTP sender. Currently logs verification link. Same comment at `:295` (ResendVerification) and `:370` (EmailChange) but only one explicit `// TODO`. |
| `internal/handlers/checkins.go:183` | CONFIGURE | Photo storage strategy — see `README_backend.md` "Photo upload" before wiring real uploads. |
| `internal/domain/types.go:655` | CONFIGURE / FLAG | `LocalizedDefaultCollections` — English names for all locales until designer pins ja/ko strings. |
| `internal/domain/types.go:661` | TODO(designer) | Same — confirm localized default-collection names. |

No `// STUB` or `// FIXME` markers found.

---

## SPEC invariant audit (PASS detail)

Every check listed in the prompt was verified directly against source. Headline results:

| Invariant | Status | Evidence |
|---|---|---|
| Rating 0.5–5.0 in 0.5 steps, optional | PASS | DB `CHECK ((rating * 10)::int % 5 = 0)` in `001_initial.sql:364-370`. Handler validation in `domain.ValidRating` at `types.go:349-362`. Type is `*float64` everywhere. OpenAPI uses `type: number, minimum: 0.5, maximum: 5.0`. |
| Review text ≤ 500 chars | PASS | DB `CHECK char_length(review_text) <= 500`. Handler validates with runes in `CreateCheckinRequest.Validate` (`types.go:371`) and `UpdateCheckinRequest.Validate` (`types.go:429`). |
| Username regex `^[A-Za-z0-9_]{3,30}$`, lowercase storage, display preserved | PASS | Handler regex `usernameRE` at `types.go:102`. Lowercase storage via `INSERT … LOWER($1), $1` at `repository/users.go:103`. Two columns `username` + `display_username` with coherence CHECK. |
| Photo cap ≤ 4 enforced in handler | PASS | `CreateCheckinRequest.Validate` rejects `len(Photos) > 4` at `types.go:374`. `CheckinRepo.Create` loop guards `i >= 4` at `checkins.go:67`. `AddPhoto` counts existing rows before insert at `checkins.go:400`. DB `sort_order BETWEEN 0 AND 3` + UNIQUE is the backstop. |
| Cursor pagination on every list | PASS | All 11 list endpoints in `router.go` use `cursor.Cursor`/`cursor.Page[T]`. Response shape `{ items, next_cursor, has_more }`. Zero occurrences of `OFFSET` or `?page=` in handlers or repos. OpenAPI explicitly forbids offset in the top-level description. |
| Soft-delete filtering | PASS | 41 `deleted_at IS NULL` clauses across `repository/*.go`. `users`, `check_ins`, `collections` queries all filter; `beverages`/`breweries` correctly omit (no soft-delete). |
| Default `Inventory` + `Wishlist` in same tx as user creation | PASS | `UserRepo.CreateUserWithDefaults` at `repository/users.go:70-92`. Two-row INSERT inside the transaction; on failure the user insert rolls back. Applies to both email/password (auth.go:55) and Google OAuth (auth.go:232) registration paths. |
| JWT middleware on every non-public route | PASS | `router.go` groups every authed surface (me, feed, write-paths, social, collections) under `middleware.Auth(signer)`. Public reads (taxonomy, beverages, breweries, search, profile, user check-ins, check-in detail) use bare or `OptionalAuth`. |
| Google OAuth: server verifies ID token, client secret never exposed | PASS | `auth.GoogleVerifier.Verify` uses `idtoken.Validate` with the configured client *ID* as audience (`auth/jwt.go:101`). `GoogleClientSecret` is read into `Config` but never used or returned in any response. `.env.example` documents the boundary. |
| Error response shape `{ error, code }` | PASS | `apierror.WriteError` is the only error-write path; canonical body shape enforced everywhere. Verified across all 10 handler files. |
| Category strings character-exact (§2.1) | PASS | `migrations/002_seed_taxonomy.sql:14-22` has the three required rows verbatim: `Nihonshu (Sake)` / `日本酒` / `니혼슈 (사케)`, `Shochu` / `焼酎` / `쇼츄`, `Liqueur` / `リキュール` / `리큐어`. No locale strings hardcoded in Go — `taxonomy.go` reads them from the DB. |
| i18n: API returns JSONB shape verbatim, no pre-resolve | PASS | `I18nText` struct has `en`, `ja`, `ko`; handlers return it as-is. `Resolve` method exists for internal use but is not called in any response path. Client owns locale selection per HANDOFF. |

---

## Verification summary

```bash
$ go build ./...
(clean, no output)

$ go vet ./...
(clean, no output)

$ go test ./...
ok    github.com/kamos/api/internal/auth     (cached)
ok    github.com/kamos/api/internal/cursor   (cached)
ok    github.com/kamos/api/internal/domain   (cached)
(no test files in handlers/repository/middleware/server/apierror/config/cmd — acceptable for MVP scaffolding; integration tests are deferred per CLAUDE.md)
```

No runtime DB tests were executed (qa-inspector operates on source, not running services). Recommend `backend-engineer` run a smoke `psql -f migrations/001_initial.sql && psql -f migrations/002_seed_taxonomy.sql` against a fresh database before Phase 3 starts, to catch any DDL ordering issue not visible from static review.

---

## Routing of MAJOR/MINOR fixes

| Owner | Items |
|---|---|
| `backend-engineer` | All MAJORs (deferred), MINOR #1 (BeverageCount field), MINOR #2 (omitempty vs nullable), MINOR #4 (search cursor), MINOR #5 (dead double-decode), MINOR #7 (UpdateMe null docs), MINOR #8 (public profile email leak) |
| `designer` | MINOR #6 (localized default collection names — Inventory/Wishlist ja/ko strings) |
| `flutter-engineer` (informational, not a fix) | Be aware of omitempty-vs-null on Brewery / Beverage optional fields; handle `ko` key absent identically to `ko` key empty. |

None of these block Phase 3 frontend start. The Flutter team can build against `openapi.yaml` as-is; the MAJORs are production-readiness items, not contract gaps.
