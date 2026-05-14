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
_workspace/02_backend/api/    Go REST API
_workspace/02_backend/db/     Schema + migrations (SQL)
_workspace/03_frontend/       Flutter app
docker-compose.yml            Postgres + API for local dev
Makefile                      One-line dev tasks
```

> `backend/` and `frontend/` at the repo root are empty placeholders. Production paths during the MVP build are under `_workspace/`. Promotion happens with the first real deploy.

## 3. Environment variables

Copy `_workspace/02_backend/api/.env.example` to `.env` at the repo root (or wherever your runner reads it). Required keys:

| Key | Purpose | Required |
|---|---|---|
| `DATABASE_URL` | Postgres DSN | yes |
| `JWT_SECRET` | HMAC signing key for JWT, ≥ 32 random bytes | yes |
| `JWT_TTL` | Token lifetime; MVP is long-lived (refresh deferred) | yes (default `720h`) |
| `APP_BASE_URL` | Base URL used in verification-email links | yes |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID (used as ID-token audience) | only if Google sign-in is enabled |
| `GOOGLE_CLIENT_SECRET` | Server-side only; **never ship to the Flutter app** | only if Google sign-in is enabled |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` | Verification email | **production** — dev logs the link instead |

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
cd _workspace/03_frontend
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

Migrations are plain SQL files in `_workspace/02_backend/db/migrations/`, applied in lexicographic order:

```
001_initial.sql          schema (13 tables, CHECKs, triggers, indexes)
002_seed_taxonomy.sql    SPEC §2.1 categories + §4.3 flavor tags
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
cd _workspace/03_frontend
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

1. Create OAuth 2.0 credentials in Google Cloud Console.
2. iOS / Android client → drop the client ID into Flutter's platform-specific config (per `google_sign_in` package docs, pending wiring — see `README_flutter.md`).
3. Web/Server client → set `GOOGLE_CLIENT_ID` on the API. This is the audience the server verifies ID tokens against.
4. `GOOGLE_CLIENT_SECRET` stays server-side. It is not required for ID-token verification but kept in env for any future browser-flow exchange.

> The Flutter app **never** holds the client secret. SPEC invariant — verified by qa-inspector.

## 9. Known deferred items (MVP gaps)

These passed the integration QA as MAJORs, deferred to v1.1:

- **Photo storage** — `POST /v1/check-ins/{id}/photos` takes a URL reference; the actual upload path (presigned-URL pattern with S3 / GCS / R2) is not wired. Flutter has `image_picker` ready but does not yet upload.
- **SMTP** — verification email is written to the API log in dev. Wire `SMTP_*` env vars to a real provider before any public deploy.
- **Refresh tokens** — JWT is long-lived (`JWT_TTL=720h`); on expiry the client re-logs-in. Refresh-token flow is v1.1.

See `_workspace/04_qa/qa_report_final.md` for the full punch list.

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

- [ ] Managed Postgres (RDS / Cloud SQL / Neon) with PITR
- [ ] Real `JWT_SECRET` from secret manager, not env file
- [ ] TLS termination (load balancer or reverse proxy)
- [ ] `sslmode=require` in `DATABASE_URL`
- [ ] S3 (or compat) bucket + presigned-URL endpoint for photos
- [ ] Real SMTP (SES / SendGrid / Postmark)
- [ ] CDN for beverage label images
- [ ] Structured log shipping (slog → Loki/Datadog)
- [ ] Rate limiting on `POST /v1/auth/*`
- [ ] Background job runner for: 30-day username hold cleanup, beverage `avg_rating` integrity sweep, expired email-verification cleanup
- [ ] Crash reporting in Flutter (Sentry / Crashlytics)
