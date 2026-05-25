# KAMOS — Backend

Go 1.26 REST API for KAMOS. PostgreSQL 18+ backend, JWT auth, Google OAuth, cursor-paginated lists, full i18n.

## Stack

- Go 1.26+
- `chi` v5 router
- `pgx/v5` directly (no ORM)
- `golang-jwt/v5` (HS256)
- `golang.org/x/crypto/bcrypt`
- `google.golang.org/api/idtoken` (Google ID-token verification)
- `joho/godotenv` (local.env auto-loading in non-production)
- Stdlib `log/slog`

## Layout

```
cmd/server/main.go          process entrypoint, graceful shutdown
internal/
  apierror/                 sentinel errors + canonical response shape
  auth/                     JWT signer + Google ID-token verifier + bcrypt
  config/                   env loading
  cursor/                   keyset cursor encode/decode + Page[T]
  domain/                   request/response types + Validate() methods
  handlers/                 HTTP handlers, one file per domain
  jobs/                     in-process background scheduler + 3 maintenance jobs
  middleware/               request id, recover, access log, JWT auth, rate-limit, OTel trace
  observability/            OTel traces+metrics + Sentry init (feature-flag gated)
  repository/               pgx-backed data access
  server/                   chi router wiring
openapi.yaml                OpenAPI 3.1 contract
.env.example
migrations/                 (mirror of ../db/migrations)
```

## Endpoint surface (counts)

| Domain | Endpoints |
|---|---|
| Auth | 7 |
| Users (me + public profile + lists) | 7 |
| Beverages / producers | 5 |
| Check-ins (CRUD + photo + toast) | 6 |
| Feed | 1 |
| Social (follow + inbox) | 5 |
| Collections + entries | 8 |
| Search | 1 |
| Taxonomy + feedback | 3 |
| Venues (Phase 4) | 1 |
| **Total** | **44** |

Every list endpoint returns the canonical `{ items, next_cursor, has_more }` shape. Error responses are uniformly `{ "error": "...", "code": "..." }`.

## Local development

### 1. Start PostgreSQL 18

```bash
docker run --rm -d --name kamos-pg \
  -e POSTGRES_USER=kamos -e POSTGRES_PASSWORD=kamos -e POSTGRES_DB=kamos \
  -p 5432:5432 postgres:18
```

Or use a host install of Postgres 18 — that is what `local.env.example` assumes.

### 2. Apply migrations

```bash
export DATABASE_URL=postgres://kamos:kamos@localhost:5432/kamos?sslmode=disable
psql "$DATABASE_URL" -f ../db/migrations/001_initial.sql
psql "$DATABASE_URL" -f ../db/migrations/002_seed_taxonomy.sql
```

Verify:

```bash
psql "$DATABASE_URL" -c "SELECT slug, name_i18n FROM beverage_categories ORDER BY sort_order;"
```

### 3. Configure env

Two options:

**Option A — `local.env` at the repo root (recommended for local dev).**
The binary auto-loads `local.env` in non-production environments. Real env
vars always override; godotenv is non-overriding.

```bash
cp local.env.example local.env   # at repo root
# fill JWT_SECRET (openssl rand -base64 48), DATABASE_URL, etc.
```

**Option B — explicit shell sourcing.**

```bash
cp .env.example .env
set -a; source .env; set +a
```

### 4. Run

```bash
make api-run-local        # auto-sources local.env from repo root
# or directly:
go run ./cmd/server
```

The server listens on `:8080`. Health check:

```bash
curl http://localhost:8080/health
```

## Testing

### Unit tests (no DB)

```bash
go test ./...
go test -cover ./...
make api-test            # shorthand
```

The unit suite uses the stdlib `testing` package only — no testify, no mocks
of the pgx driver. Handler tests live in `internal/handlers/handlers_test.go`
as an external `handlers_test` package so they can drive the real chi router
through `server.New`; routes are exercised at auth/validation boundaries that
short-circuit before any repository call. Repository success paths are
covered by the integration suite below.

### Integration tests (real Postgres 18)

```bash
INTEGRATION_DATABASE_URL=postgres://kamos_local@localhost:5432/kamos_test?sslmode=disable \
JWT_SECRET=$(openssl rand -base64 48) \
APP_ENV=test \
APP_BASE_URL=http://localhost:8080 \
go test -tags=integration -count=1 ./tests/integration/...

# Or via Makefile (auto-sources local.env):
make api-test-int
```

Each test wipes the user-data tables (every table except `beverage_categories`
and `flavor_tags`) before running so order is not significant. The build tag
`integration` keeps these tests out of the default `go test` run.

## Verification

Pre-merge checks the maintainer should run:

```bash
go build ./...
go vet ./...
go test -cover ./...
make api-test-int        # if Postgres 18 is available
```

## Observability

All four vendor knobs are **optional** — leave them blank and the SDKs are never initialized. The server boots cleanly with no warnings and no degraded behavior, which means you can use this codebase end-to-end before signing up for OTel / Sentry.

| Env | Default | Effect when unset |
|---|---|---|
| `APP_VERSION` | `dev` | Spans + Sentry release tagged `dev` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | _empty_ | OTel disabled at boot (`otel disabled` log line) |
| `OTEL_EXPORTER_OTLP_HEADERS` | _empty_ | No auth headers; only meaningful with the endpoint set |
| `SENTRY_DSN` | _empty_ | Sentry disabled at boot (`sentry disabled` log line) |

Spans wrap every HTTP request with a name like `HTTP GET /v1/users/{username}` (chi route pattern → bounded cardinality). One business metric is emitted today (`checkins_created_total` counter); add more in `internal/observability/` as new domains warrant it.

Sentry is errors-only: panics caught by `RecoverWithSentry` middleware get forwarded with the request context. Traces stay on OTel, so we don't double-bill events.

## Rate limiting

Three layers configured in `internal/server/router.go`:

| Scope | rps | burst |
|---|---|---|
| Global per-IP | 30 | 60 |
| Per-IP on `/v1/auth/*` | 5 | 10 |
| Per-user on authed routes | 60 | 120 |

A throttled request returns `429` with `{"error":"rate_limited","code":"RATE_LIMITED"}` plus `Retry-After: 1`. The token-bucket state is an in-memory `sync.Map` with a 10-minute idle-eviction janitor.

Set `RATE_LIMIT_DISABLED=1` to bypass all three limits — useful for stress tests and the integration suite's high-fanout cases. Production MUST leave this unset.

## Background jobs

In-process scheduler (`internal/jobs/`) — no separate binary. Three maintenance jobs registered in `cmd/server/main.go`:

| Job | Interval | What it does |
|---|---|---|
| `username_hold_cleanup` | 1h | Tombstones usernames of users soft-deleted >30 days ago (SPEC §3.3) |
| `email_verification_cleanup` | 6h | Drops `email_verifications` rows expired >7 days ago |
| `avg_rating_sweep` | 24h | Self-heals `beverages.avg_rating` + `check_in_count` from `check_ins` (in case the trigger drifts) |

Each job runs **once on startup** ("cold start") so a fresh deploy doesn't wait an hour for the first sweep. Tick errors are logged at WARN; they never crash the scheduler.

## Auth notes

- JWT is HS256 with the server `JWT_SECRET`. Access-token TTL is `JWT_TTL` (default `15m` as of Phase 2 — formerly `720h`).
- Google OAuth: the Flutter client sends the ID token to `POST /v1/auth/google`. The server validates it against Google's published JWKS using `idtoken.Validate` with `GOOGLE_CLIENT_ID` as the audience. The client secret is NOT used for ID-token validation — it is kept in `.env` only for completeness of OAuth2 if a future server-side flow is added.
- The Flutter app must store both the access token AND the raw refresh secret in `flutter_secure_storage` only (SPEC §6.9).

## Tokens (Phase 2)

| Token | Default TTL | Storage | Rotates? |
|---|---|---|---|
| Access (`access_token`) | `JWT_TTL` (default **15m**) | HS256 JWT signed with `JWT_SECRET`; carried in `Authorization: Bearer …` | No — re-issue on refresh |
| Refresh (`refresh_token`) | `REFRESH_TTL` (default **720h** = 30 days) | DB row `refresh_tokens.token_hash` holds **only** the SHA-256 hash of the raw secret. The client sends the raw base64-rawurl 43-char secret. | **Yes** — every call to `POST /v1/auth/refresh` revokes the presented token and issues a new pair. |

**Rotation chain.** Each refresh token belongs to a `family_id` (the originating token's id). Rotations link to their predecessor via `parent_id`.

**Re-use detection.** When `POST /v1/auth/refresh` is called with a token that is already revoked (i.e., a previous rotation already happened), the server revokes every active token in the entire family and returns `401 TOKEN_INVALID`. The handler logs `refresh_token_reuse_detected` at WARN with `user_id` + `family_id`. Expiry of a still-valid token is benign and returns `401 TOKEN_EXPIRED` without family-wide revocation.

**Logout.** `POST /v1/auth/logout` (authed). With a body `{"refresh_token": "..."}` only that single token is revoked (single-device sign-out). With an empty body every active refresh token for the authed user is revoked (sign-out-everywhere). Always 204.

## Photo upload (MVP decision)

`POST /v1/check-ins/{id}/photos` accepts `{ "url": "..." }` for MVP. The URL is expected to point at an already-uploaded image (typical pattern: client requests a presigned upload URL from a future `/uploads` endpoint, posts the image directly to blob storage, then sends the resulting public URL here). Multipart inline upload is deferred — the API surface is storage-agnostic. The DB caps the photo count at 4 via `sort_order BETWEEN 0 AND 3` + UNIQUE; the repository checks before inserting.

## SPEC traceability

- Cursor pagination on every list (SPEC §5.2 / §6.6) — `internal/cursor`.
- Rating 0.5–5.0 in 0.5 steps (SPEC §4.2 / §6.2) — `domain.ValidRating`.
- Review ≤ 500 chars (SPEC §4.1 / §6.7) — `domain.CreateCheckinRequest.Validate`.
- Photos ≤ 4 per check-in (SPEC §4.1 / §6.7) — `repository.CheckinRepo.AddPhoto`, `Create`.
- Username 3–30, lowercase storage, 30-day hold (SPEC §3.2 / §3.3 / §6.3 / §6.4) — `domain.RegisterRequest`, `UserRepo.CreateUserWithDefaults`, `SoftDelete`.
- Default `Inventory` + `Wishlist` (SPEC §6.1 / §6.8) — `UserRepo.CreateUserWithDefaults` seeds both in the same `pgx.Tx`.
- Category strings (SPEC §2.1) — served from the DB lookup table; never abbreviated in code.
- Soft-delete filters (SPEC §6.4) — every list query carries `WHERE deleted_at IS NULL`.
- i18n fallback (SPEC §6.5) — `domain.I18nText.Resolve` + `query_patterns.md §13`.
- Self exclusion in feed (SPEC §5.2) — `repository.FeedRepo.Page` adds `ci.user_id <> $1`.
- Privacy gate for feed / check-in / toast (SPEC §5.1) — `CheckinRepo.checkVisibility`, FeedRepo's JOIN on accepted follows.
- Toast one-per-user-per-checkin (SPEC §5.3) — composite PK + `CheckinRepo.ToggleToast`.

## Open items

- `// TODO`: SMTP wiring for verification email — currently the link is logged.
- `// CONFIGURE`: `GOOGLE_CLIENT_ID` must be set before Google sign-in works. The verifier rejects with a clear error if unset.
