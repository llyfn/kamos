# KAMOS — Deployment

Local-development and staging deployment notes for the KAMOS MVP. Production hardening (TLS, managed Postgres, S3 photo storage, real SMTP, monitoring) is out of scope for this document and tracked separately.

## 1. Prerequisites

| Tool | Version |
|---|---|
| Docker (Engine + Compose v2) | 24+ |
| Go | 1.26+ |
| Flutter | stable channel |
| PostgreSQL client (`psql`) | 18+ — used by `make db-migrate` |
| Xcode (iOS build) | 15+ on macOS |
| Android Studio / SDK | API 26+ |

## 2. Repository layout (deploy-relevant)

```
backend/                      Go REST API
migrations/                   Schema + migrations (SQL)
frontend/                     Flutter app
admin/                        React admin web client
design/                       Design system (tokens, kit)
docs/                         Long-form docs (db/, history/, runbooks)
scripts/                      Operational scripts (smoke, e2e)
docker-compose.yml            Postgres + API for local dev
Makefile                      One-line dev tasks
```

## 3. Environment variables

Copy `backend/.env.example` to `.env` at the repo root (or wherever your runner reads it). Required keys:

| Key | Purpose | Required |
|---|---|---|
| `DATABASE_URL` | Postgres DSN | yes |
| `JWT_SECRET` | HMAC signing key for JWT, ≥ 32 random bytes | yes |
| `JWT_TTL` | Access-token lifetime. Phase 2 (rotating refresh tokens) lowered the default to `15m`; the env var still wins. | yes (default `15m`) |
| `REFRESH_TTL` | Refresh-token lifetime. Long-lived but revocable; rotated on every `POST /v1/auth/refresh`. | yes (default `720h` = 30 days) |
| `APP_BASE_URL` | Base URL used in verification-email links | yes |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID (used as ID-token audience) | only if Google sign-in is enabled |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` | Verification email | **production** — dev logs the link instead |
| `APP_VERSION` | Reported as `service.version` on OTel spans + Sentry release tag | optional (default `dev`) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP/HTTP host for traces + metrics (e.g. `otlp-gateway-prod-eu-west-2.grafana.net`). Empty disables OTel entirely. | optional |
| `OTEL_EXPORTER_OTLP_HEADERS` | `"k1=v1,k2=v2"` headers — usually a single `Authorization=Basic …` line | optional |
| `SENTRY_DSN` | Sentry project DSN. Empty disables Sentry; only panics are forwarded (OTel ships traces). | optional |
| `RATE_LIMIT_DISABLED` | Set to `1` to bypass rate limits (local stress / unusual tooling only). Production MUST leave this unset. | optional |
| `R2_ENDPOINT_URL` | Cloudflare R2 gateway URL (e.g. `https://<account-id>.r2.cloudflarestorage.com`). | optional — empty disables photo uploads |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | R2 access key pair. | optional |
| `R2_BUCKET` | Bucket holding check-in photos (e.g. `kamos-checkin-photos-staging`). Empty disables the feature: `POST /v1/uploads/photo-presign` returns `503 STORAGE_DISABLED`. | optional |
| `R2_PUBLIC_BASE_URL` | Public CDN / custom-domain URL used in `photo_url` on responses (e.g. `https://photos.kamos.app`). | optional |
| `RESEND_API_KEY` | Resend API key for verification email. Empty → LogMailer (link logged at INFO). | optional |
| `EMAIL_FROM` | `From:` address used by ResendMailer (e.g. `no-reply@kamos.app`). Required when `RESEND_API_KEY` is set. | optional |
| `FOURSQUARE_API_KEY` | Foursquare Places API key (Phase 4 venue tag). Empty disables `GET /v1/venues/search` (503 `VENUE_SEARCH_DISABLED`). Check-in `venue.foursquare_id` upsert path is independent and still works without it. | optional |
| `CURSOR_SECRET` | HMAC key for keyset-pagination cursor envelopes (≥ 32 bytes). Required in production; dev derives one from `JWT_SECRET` if unset. Tampered cursors → `400 INVALID_CURSOR`. | **production** |
| `CACHE_BACKEND` | `in_process` (default) or `redis`. Selecting `redis` enables cross-replica L2; `in_process` keeps each replica's LRU isolated (still coherent via `pg_notify`). | optional |
| `CACHE_REDIS_URL` | `rediss://...` DSN for the Redis L2 cache. Required when `CACHE_BACKEND=redis` — startup fails otherwise. | only if `CACHE_BACKEND=redis` |
| `CORS_ALLOWED_ORIGINS` | Comma-separated allowlist for admin SPA origins. Dev default `http://localhost:5173`; production requires explicit list. | **production** |

**Rate-limit defaults** (set in `internal/server/router.go`):

| Scope | Rate (rps) | Burst |
|---|---|---|
| Global per-IP | 30 | 60 |
| Per-IP on `/v1/auth/*` (brute-force mitigation) | 5 | 10 |
| Per-user on authed routes (post-Auth middleware) | 60 | 120 |

A rejected request returns `429 Too Many Requests` with `{"error":"rate_limited","code":"RATE_LIMITED"}` and `Retry-After: 1`.

**Vendor signup is OPTIONAL.** Every observability key above can be left blank; the server boots cleanly with the SDK never initialized. No warnings, no degraded behavior. Wire one of OTEL/Sentry up only after creating the corresponding account.

> **`local.env` auto-loading:** when `APP_ENV != "production"` the server walks up from CWD looking for `local.env` and loads it before reading env vars. Real env vars always win (godotenv is non-overriding). `local.env` is gitignored; commit `local.env.example` instead.

Generate a JWT secret:

```sh
openssl rand -base64 48
```

## 4. Quick start — local

### Option A — fully Dockerized

```sh
# 1. start postgres + api (api builds via docker)
make up

# 2. wait for healthy, then in another shell:
make db-migrate         # applies 001_initial.sql + 002_seed_taxonomy.sql

# 3. flutter app — runs against http://localhost:8080
cd frontend
flutter pub get
flutter run --dart-define=KAMOS_API_BASE_URL=http://localhost:8080
```

### Option B — host Postgres 18, host Go

```sh
# Copy the template, then fill in JWT_SECRET and any other secrets.
cp local.env.example local.env

# Run the API against the local Postgres pointed at by DATABASE_URL in
# local.env. The server auto-loads local.env in non-production.
make api-run-local
```

For Android emulator, replace `localhost` with `10.0.2.2`. For iOS simulator, `localhost` works.

## 5. Database

Migrations are plain SQL files in `migrations/`, applied in lexicographic order:

```
001_initial.sql                              schema (13 tables, CHECKs, triggers, indexes)
002_seed_taxonomy.sql                        SPEC §2.1 categories + §4.3 flavor tags
003_refresh_tokens.sql                       Phase 2 — rotating refresh tokens + family revocation
004_photo_uploads.sql                        Phase 3 — photo_uploads table (R2 presigned-URL flow)
005_venues.sql                               Phase 4 — venues table + check_ins.venue_id FK
006_venue_value_constraints.sql              Phase 4 cleanup — venue CHECKs + first-writer-wins upsert
007_user_role_and_soft_delete_index.sql      Phase 5 — users.role enum + idx_users_deleted_at_recent
008_collections_visibility_and_moderation_log.sql  Phase 6 — collection_visibility enum + moderation_log
009_comments.sql                             Phase 6 — flat comments table + length/control-char CHECKs
```

Apply:

```sh
make db-migrate                                       # uses local PSQL_URL
# or against a remote:
PSQL_URL='postgres://user:pass@host:5432/kamos?sslmode=require' make db-migrate
```

Migrations are **append-only**. Never edit a deployed migration; add `003_*.sql`.

`docker-compose.yml` mounts `migrations/` into the Postgres image's `docker-entrypoint-initdb.d`, so a brand-new compose stack auto-applies them on first start. `make db-migrate` is for upgrading an existing database.

## 6. Backend

Local run without docker:

```sh
make api-run            # cd into api dir + go run ./cmd/server
```

Tests:

```sh
make api-test           # go test ./...
make api-build          # go build ./...
```

Health check: `GET /healthz` → `200`.

## 7. Flutter app

```sh
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs    # if regenerating freezed/json_serializable
flutter analyze
flutter test
flutter run --dart-define=KAMOS_API_BASE_URL=https://api.example.com
```

iOS notes:
- `ios/Runner/Info.plist` already declares EN / JA / KO locales and camera/photo permission strings.
- Min iOS: 13.

Android notes:
- `minSdk = 26` in `android/app/build.gradle.kts`.
- Photo permissions are runtime-prompted by `image_picker`.

## 8. Google OAuth setup

Phase 2 shipped end-to-end Google sign-in wiring (`google_sign_in ^7.2.0` on Flutter, `internal/auth/google.go` on the API). It is gated behind a Flutter `--dart-define` flag so debug builds without platform config remain runnable.

1. Create OAuth 2.0 credentials in Google Cloud Console — one Web/Server, one iOS, one Android client ID (see cookbook §C1 in the roadmap).
2. Drop the iOS client ID into `ios/Runner/Info.plist` and the Android client ID into `android/app/build.gradle.kts` per `google_sign_in` docs. Reference: `frontend/README_flutter.md`.
3. Set `GOOGLE_CLIENT_ID` on the API to the **Web/Server** client ID — this is the audience the server verifies ID tokens against.
4. Run the app with `--dart-define=KAMOS_GOOGLE_SIGN_IN_ENABLED=true` to surface the Google button.

> The Flutter app **never** holds a client secret, and neither does the API: the ID-token verification flow used here does not require one. SPEC invariant — verified by qa-inspector.

## 9. Vendor-gated features

Phase 0–7 of the post-MVP roadmap shipped end-to-end. Every external-vendor integration is implemented behind a feature flag that reads the relevant env var; leaving the var empty makes the feature gracefully OFF.

| Feature | Phase | Gate | OFF behavior |
|---|---|---|---|
| Refresh tokens + Google OAuth | 2 | `GOOGLE_CLIENT_ID` (server) + `--dart-define=KAMOS_GOOGLE_SIGN_IN_ENABLED=true` (client) | Email/password login still works; Google button is hidden when disabled. Cookbook §C1. |
| Photo storage (Cloudflare R2 presigned URLs) | 3 | `R2_*` env block | `POST /v1/uploads/photo-presign` → `503 STORAGE_DISABLED`. Cookbook §C2. |
| Verification + change-email outbound mail (Resend) | 3 | `RESEND_API_KEY` + `EMAIL_FROM` | LogMailer logs the rendered template + link at INFO. Cookbook §C3. |
| OTel + Sentry (Go + Flutter) | 1 | `OTEL_EXPORTER_OTLP_ENDPOINT` + `OTEL_EXPORTER_OTLP_HEADERS` + `SENTRY_DSN` | SDKs never initialize; no spans/events emitted. Cookbook §C4. |
| Venue tag (Foursquare Places API) | 4 | `FOURSQUARE_API_KEY` | `GET /v1/venues/search` → `503 VENUE_SEARCH_DISABLED`. Check-in `venue.foursquare_id` upsert works without the key. Cookbook §C5. |
| Admin web client hosting (Cloudflare Pages) | 5 | Pages project + `VITE_API_BASE_URL` | Admin client compiles locally; deployment uses any static host. Cookbook §C6. |

The QA punch lists per phase live at `docs/history/qa/qa_report_phase{0..7}*.md` (per-layer + final). The historical MVP report is `docs/history/qa/qa_report_final.md`.

## 10. Verification — full integration smoke

After `make up && make db-migrate`:

```sh
# 1. register
curl -X POST http://localhost:8080/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"smoketest","email":"smoke@example.com","password":"hunter2hunter2","display_name":"Smoke","locale":"en"}'

# 2. login → capture JWT (OAuth2-style response: access_token, token_type, expires_in)
TOKEN=$(curl -sX POST http://localhost:8080/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"smoke@example.com","password":"hunter2hunter2"}' | jq -r .access_token)

# 3. read taxonomy (category strings should be character-exact SPEC §2.1)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/v1/categories

# 4. read own profile (should include email)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/v1/users/me

# 5. read public profile of self by username (must NOT include email)
curl http://localhost:8080/v1/users/smoketest
```

Step 5 is the M3 fix verification — `email` must not appear in the response.

## 11. Make targets reference

```
make help              List all targets
make up                docker compose up (postgres + api)
make down              docker compose down
make db-migrate        Apply all SQL migrations
make db-reset          DROP + recreate db (confirmation prompted)
make api-run           Run Go API locally
make api-run-local     Run Go API with local.env auto-sourced
make api-test          go test ./... (unit only)
make api-test-unit     Alias for api-test
make api-test-int      go test -tags=integration (real Postgres 18)
make api-build         go build ./...
make flutter-run       Run Flutter app
make flutter-test      flutter test
make flutter-analyze   flutter analyze
make check             Build + unit-test backend, integration when INTEGRATION_DATABASE_URL is set, analyze + test frontend
```

## 12. Production hardening checklist (post-MVP)

Shipped end-to-end (implementation present in the repo):

- [x] Rate limiting on `POST /v1/auth/*` *(token-bucket per IP, 5 rps / burst 10; per-user + per-IP layered; Phase 1)*
- [x] Background job runner *(in-process scheduler at `internal/jobs/`: username-hold cleanup, `avg_rating` sweep, expired email-verification cleanup, photo-orphan cleanup; Phase 1 + 3)*
- [x] Refresh-token rotation with family revocation + re-use detection *(Phase 2)*
- [x] Flutter Sentry SDK *(`sentry_flutter ^9.20.0`; Phase 1, no-op when DSN empty)*
- [x] Photo storage presigned-URL handler *(`internal/storage/r2.go` + `POST /v1/uploads/photo-presign`; Phase 3, gated on `R2_*` env)*
- [x] Outbound mail with HTML/text templates per locale *(`internal/email/`; Phase 3, gated on `RESEND_API_KEY`)*
- [x] Optional venue tagging via Foursquare *(`internal/foursquare/`; Phase 4, gated on `FOURSQUARE_API_KEY`)*
- [x] Admin web client + RBAC *(React 19 / Vite 6 at `admin/`; `RequireRole` middleware; Phase 5, hosting gated on Cloudflare Pages project)*
- [x] Public collections + flat comments + admin moderation *(Phase 6)*
- [x] HTTP `Cache-Control` + strong ETag + LRU + singleflight on read-heavy routes; `cache_requests_total` Prom metric + Grafana panel JSON *(Phase 7)*

Vendor credentials still owed by the operator (flip-the-switch only):

- [ ] Google OAuth client IDs (web + iOS + Android) — cookbook §C1
- [ ] Cloudflare R2 bucket + API token — cookbook §C2
- [ ] Resend API key + verified `EMAIL_FROM` domain — cookbook §C3
- [ ] Sentry DSNs + OTLP endpoint/headers — cookbook §C4
- [ ] Foursquare Places API key — cookbook §C5
- [ ] Cloudflare Pages project for admin client hosting — cookbook §C6 — wired by [`docs/runbooks/staging-deploy.md`](docs/runbooks/staging-deploy.md) §1.4

Infra outside the codebase:

- [x] **Dev environment on Fly.io (NRT)** — `kamos-dev` app + Fly Postgres 18 + Upstash Redis; auto-deploy via [`.github/workflows/deploy-dev.yml`](.github/workflows/deploy-dev.yml); runbook at [`docs/runbooks/staging-deploy.md`](docs/runbooks/staging-deploy.md).
- [ ] Production: managed Postgres 18 (RDS / Cloud SQL / Neon) with PITR
- [ ] `JWT_SECRET` from a secret manager, not env file
- [ ] TLS termination (load balancer or reverse proxy) — dev: Fly edge handles TLS via `flyctl certs`
- [ ] `sslmode=require` in `DATABASE_URL`
- [ ] CDN for beverage label images
- [ ] Structured log shipping (slog → Loki / Datadog)
- [x] **`APP_VERSION` populated per deploy** — dev pipeline stages `APP_VERSION=<git-sha>` on every `flyctl deploy` (see `deploy-dev.yml`).
