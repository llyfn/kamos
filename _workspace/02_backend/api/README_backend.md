# KAMOS — Backend

Go 1.24 REST API for KAMOS. PostgreSQL 15+ backend, JWT auth, Google OAuth, cursor-paginated lists, full i18n.

## Stack

- Go 1.24+
- `chi` v5 router
- `pgx/v5` directly (no ORM)
- `golang-jwt/v5` (HS256)
- `golang.org/x/crypto/bcrypt`
- `google.golang.org/api/idtoken` (Google ID-token verification)
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
  middleware/               request id, recover, access log, JWT auth
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
| Beverages / breweries | 5 |
| Check-ins (CRUD + photo + toast) | 6 |
| Feed | 1 |
| Social (follow + inbox) | 5 |
| Collections + entries | 8 |
| Search | 1 |
| Taxonomy + feedback | 3 |
| **Total** | **43** |

Every list endpoint returns the canonical `{ items, next_cursor, has_more }` shape. Error responses are uniformly `{ "error": "...", "code": "..." }`.

## Local development

### 1. Start PostgreSQL

```bash
docker run --rm -d --name kamos-pg \
  -e POSTGRES_USER=kamos -e POSTGRES_PASSWORD=kamos -e POSTGRES_DB=kamos \
  -p 5432:5432 postgres:15
```

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

```bash
cp .env.example .env
# fill in JWT_SECRET (openssl rand -base64 48), optionally GOOGLE_CLIENT_ID
set -a; source .env; set +a
```

### 4. Run

```bash
go run ./cmd/server
```

The server listens on `:8080`. Health check:

```bash
curl http://localhost:8080/health
```

## Testing

```bash
go test ./...
```

Integration tests against a real PostgreSQL DB are the standard for this repo — see `_workspace/04_qa` for the QA cross-check.

## Verification

Pre-merge checks the maintainer should run:

```bash
go build ./...
go vet ./...
go test ./...
```

## Auth notes

- JWT is HS256 with the server `JWT_SECRET`. TTL is `JWT_TTL` (default 720h). Refresh is deferred to v1.1 per SPEC; clients re-login on expiry.
- Google OAuth: the Flutter client sends the ID token to `POST /v1/auth/google`. The server validates it against Google's published JWKS using `idtoken.Validate` with `GOOGLE_CLIENT_ID` as the audience. The client secret is NOT used for ID-token validation — it is kept in `.env` only for completeness of OAuth2 if a future server-side flow is added.
- The Flutter app must store the JWT in `flutter_secure_storage` only (SPEC §6.9).

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
- `// TODO`: localized default-collection names. HANDOFF.md does not pin localized strings; we use English ("Inventory" / "Wishlist") across all locales for now. See `domain.LocalizedDefaultCollections`.
- `// CONFIGURE`: `GOOGLE_CLIENT_ID` must be set before Google sign-in works. The verifier rejects with a clear error if unset.
