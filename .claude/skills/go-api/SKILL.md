---
name: go-api
description: "KAMOS Go REST API skill. Use this to implement Go HTTP handlers, middleware, JWT and Google OAuth, the pgx-based repository layer, and the openapi.yaml spec for KAMOS. Invoke whenever Go backend, API endpoint, handler, repository, middleware, auth, or OpenAPI work is requested. Triggers: Go, backend, API, handler, middleware, JWT, OAuth, repository, endpoint, openapi."
---

# Go API Skill

Implements the KAMOS Go REST API: HTTP handlers, middleware stack, auth (JWT + Google OAuth), `pgx/v5` repository layer, and the OpenAPI 3.1 spec.

## Project structure

```
backend/
├── cmd/server/main.go      — HTTP listener bootstrap, config load, router wiring
├── cmd/worker/main.go      — background-job scheduler (single replica)
├── internal/
│   ├── config/             — Config struct, env loading
│   ├── handlers/           — HTTP handlers (one file per aggregate)
│   ├── middleware/         — auth, cors, logger, ratelimit, etag, otel, admin cookie + CSRF
│   ├── domain/             — request/response types + validate.SanitizeText
│   ├── repository/         — pgx-based DB access
│   ├── service/            — orchestration, transactions, cache invalidation
│   ├── auth/               — JWT + Google + soft-deleted-user cache
│   ├── cache/              — Backend interface (InProcess + Redis + notify)
│   ├── cursor/             — HMAC-signed cursor envelopes
│   ├── httperr/            — domain error → HTTP mapping
│   ├── jobs/               — scheduler + jobs (pg_try_advisory_lock-wrapped)
│   └── observability/      — Sentry + OTel + Prometheus wiring
├── openapi.yaml
├── .env.example
└── README_backend.md
```

Migrations live at the repo root in `migrations/` (sibling of `backend/`). Write Go production code to `backend/`. There is no workspace fallback.

## Conventions

- Go 1.22+, `chi` router, `pgx/v5` directly (no ORM), stdlib `net/http`
- Handler signature: `func(w http.ResponseWriter, r *http.Request)` — no framework-specific types
- Repository signature: `func(ctx context.Context, ...) (T, error)` — context first, always
- Errors: wrap with `fmt.Errorf("FuncName: %w", err)`; sentinel errors in domain layer (`ErrNotFound`, `ErrConflict`, `ErrForbidden`)
- Config: a single `Config` struct loaded from env at startup; never `os.Getenv` in business logic
- No secrets committed; use `.env.example`
- Tests: table-driven unit tests in service layer; integration tests in `_test` packages against a real test PostgreSQL

## SPEC invariants the API enforces

These come from `SPEC.md` and must be enforced in handlers / validators, not deferred to the client:

| SPEC | Invariant | Where enforced |
|---|---|---|
| §3.2 | Username 3–30 chars, alphanumeric + `_`, lowercase | Registration handler validation; DB CHECK is backstop |
| §3.3 | Account delete holds username 30 days | Delete handler sets `deleted_at` + `username_release_at = now() + interval '30 days'` |
| §4.1 | Review text ≤ 500 chars, ≤ 4 photos | Check-in handler validates before insert |
| §4.2 | Rating 0.5–5.0 in 0.5 steps, optional | Validation: nil-or-(in range and `*2 == floor(*2)`) |
| §4.4 | Beverage cannot change after check-in submit | PATCH handler rejects `beverage_id` field |
| §5.1 | Private profile: follow returns `pending`, content gated to accepted followers | Follow handler + every read of private user content |
| §5.2 | Cursor pagination, page size 20 | Every list endpoint |
| §5.3 | One toast per user per check-in | `INSERT ... ON CONFLICT DO NOTHING` or unique constraint |
| §6.1 | New user gets Inventory + Wishlist collections | Registration handler creates them in the same transaction as the user |
| §8 | i18n fallback: missing locale → `en` | Beverage/producer name resolution helper used by every read endpoint |

## Handler pattern

```go
// internal/handlers/checkins.go
func (h *Handler) CreateCheckin(w http.ResponseWriter, r *http.Request) {
    user := middleware.UserFromContext(r.Context())
    if user == nil { respondError(w, http.StatusUnauthorized, "unauthorized"); return }

    var req CreateCheckinRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid body"); return
    }
    if err := req.Validate(); err != nil {     // SPEC §4.1, §4.2 enforced here
        respondError(w, http.StatusUnprocessableEntity, err.Error()); return
    }

    ci, err := h.svc.CreateCheckin(r.Context(), user.ID, req.ToInput())
    switch {
    case errors.Is(err, apierror.ErrBeverageNotFound):
        respondError(w, http.StatusNotFound, "beverage not found")
    case err != nil:
        h.log.Error("CreateCheckin", "err", err)
        respondError(w, http.StatusInternalServerError, "internal error")
    default:
        respondJSON(w, http.StatusCreated, ci)
    }
}
```

Helpers in `handler/response.go`:

```go
func respondJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    _ = json.NewEncoder(w).Encode(v)
}
func respondError(w http.ResponseWriter, status int, msg string) {
    respondJSON(w, status, map[string]string{"error": msg, "code": http.StatusText(status)})
}
```

## Repository pattern

```go
// internal/repository/checkins.go
type CheckinRepo struct{ db *pgxpool.Pool }

func (r *CheckinRepo) GetByID(ctx context.Context, id string) (*model.Checkin, error) {
    row := r.db.QueryRow(ctx, `
        SELECT id, user_id, beverage_id, rating, review_text, created_at
        FROM check_ins WHERE id = $1 AND deleted_at IS NULL`, id)
    var c model.Checkin
    err := row.Scan(&c.ID, &c.UserID, &c.BeverageID, &c.Rating, &c.ReviewText, &c.CreatedAt)
    if errors.Is(err, pgx.ErrNoRows) { return nil, apierror.ErrNotFound }
    if err != nil { return nil, fmt.Errorf("CheckinRepo.GetByID: %w", err) }
    return &c, nil
}
```

Use the SQL from `docs/db/query_patterns.md` directly — db-architect tunes those queries; do not rewrite them.

**Substring search — `LIKE` metacharacter escape is mandatory.** Project invariant per `.claude/CLAUDE.md` "Search invariants": any user-supplied query string flowing into a `LIKE` clause must pass through `repository.bigmLikeArg(q)` (lowercases + escapes `\`, `%`, `_`) before binding. Skipping this is a correctness bug — a query containing `%` would otherwise match everything. The canonical shape is `search_text LIKE '%' || $1 || '%'` with `$1 = bigmLikeArg(rawQuery)`. One query plan per endpoint; no FTS-or-trigram fallback orchestration. User search uses the 3-tier ranking (exact / prefix / substring) packed into the existing HMAC cursor envelope — see `repository.SearchUsers` for the template.

## Cursor pagination helper

Encapsulate the cursor logic so every list handler uses it identically:

```go
// pkg/cursor/cursor.go
type Cursor struct {
    CreatedAt time.Time `json:"c"`
    ID        string    `json:"i"`
}

func Encode(c Cursor) string  // base64(json(c))
func Decode(s string) (Cursor, error)

// Response:
type Page[T any] struct {
    Items      []T    `json:"items"`
    NextCursor string `json:"next_cursor,omitempty"`
    HasMore    bool   `json:"has_more"`
}
```

Every list endpoint returns `Page[T]`. Never return a bare JSON array.

## Authentication

### JWT

```go
// pkg/jwt/jwt.go
type Claims struct {
    UserID   string `json:"uid"`
    Username string `json:"username"`
    jwt.RegisteredClaims
}

func Sign(userID, username, secret string, ttl time.Duration) (string, error)
func Verify(tokenStr, secret string) (*Claims, error)   // explicit alg check, reject "none"
```

Middleware:

```go
func Auth(secret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
            if token == "" { respondError(w, 401, "unauthorized"); return }
            claims, err := jwt.Verify(token, secret)
            if err != nil { respondError(w, 401, "unauthorized"); return }
            ctx := context.WithValue(r.Context(), ctxKeyUser, claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

### Google OAuth

`POST /auth/google` — accept the Google ID token from the Flutter client, verify it via `oauth2/v3/tokeninfo` or a JWKS-based local verify, check `aud` matches the configured client ID, then upsert user by `google_sub` and issue your own JWT.

The Google **client secret** is never in the Flutter app. Only the client ID is shipped.

## Endpoint surface (MVP per SPEC)

```
POST   /auth/google                     issue JWT from Google id_token
POST   /auth/email/register             register, send verification mail
POST   /auth/email/verify               consume verification token
POST   /auth/login                      email + password login
POST   /auth/logout                     invalidate token (client-side; optionally a server-side denylist)

GET    /beverages                       list/search (cursor)
GET    /beverages/:id                   detail (with flavor profile + recent check-ins)
GET    /producers/:id                   producer detail with beverage list

POST   /checkins                        create (auth)
GET    /checkins/:id                    detail
PATCH  /checkins/:id                    edit (auth, owner only; cannot change beverage_id)
DELETE /checkins/:id                    soft-delete (auth, owner only)
POST   /checkins/:id/toast              toast / un-toast (auth)

GET    /feed                            following feed (cursor, page 20)

GET    /users/:username                 public profile (respects privacy)
GET    /users/:username/checkins        user check-ins (respects privacy)
POST   /users/:username/follow          follow (returns pending if target is private)
DELETE /users/:username/follow          unfollow

GET    /users/me                        authenticated user
PATCH  /users/me                        update display name, bio, avatar, locale, privacy
DELETE /users/me                        soft-delete account

GET    /notifications                   inbox (cursor, SPEC §5.4)
POST   /notifications/read               mark read (ids[] | all)
GET    /notifications/unread-count       unread dot signal
POST   /follow-requests/:id/approve      approve a follow request (called from notification row)
POST   /follow-requests/:id/decline      decline a follow request

GET    /users/me/collections            list own collections
POST   /users/me/collections            create
PATCH  /users/me/collections/:id        rename
DELETE /users/me/collections/:id        delete (soft)
POST   /users/me/collections/:id/items  add beverage
DELETE /users/me/collections/:id/items/:beverage_id  remove beverage
```

Every route except `/auth/*`, `GET /beverages*`, `GET /producers/*`, and `GET /users/:username` (when public) requires the auth middleware.

## Response conventions

- `200 OK` — success with body
- `201 Created` — resource creation
- `204 No Content` — successful delete
- `400 Bad Request` — malformed request
- `401 Unauthorized` — missing/invalid token
- `403 Forbidden` — authenticated but not allowed (e.g., editing another user's check-in)
- `404 Not Found` — resource not found *or* hidden by privacy
- `409 Conflict` — uniqueness violation (username taken, follow already exists)
- `422 Unprocessable Entity` — validation failure (caps, format)
- Lists: always wrapped in `{ items, next_cursor, has_more }` — never bare arrays

Error body shape: `{ "error": "human message", "code": "MACHINE_CODE" }`

## OpenAPI

Write `openapi.yaml` (3.1) covering every endpoint:

- `operationId` per route
- Request body schema (refs)
- Response schemas for `200`, `400`, `401`, `403`, `404`, `422`
- `security: [bearerAuth: []]` on protected routes
- Component schemas for `Beverage`, `Producer`, `Checkin`, `User`, `Collection`, `Page<T>`, `Error`

Keep `openapi.yaml` in sync with handlers as the source of truth — qa-inspector will grep both.

## Config

```go
type Config struct {
    Port               string
    DatabaseURL        string
    JWTSecret          string
    JWTTTL             time.Duration
    GoogleClientID     string
    GoogleClientSecret string
    SMTPHost           string
    SMTPPort           int
    SMTPUser           string
    SMTPPass           string
    AppBaseURL         string  // for verification email links
}
```

`.env.example`:

```
PORT=8080
DATABASE_URL=postgres://kamos:password@localhost:5432/kamos?sslmode=disable
JWT_SECRET=change-me-in-production
JWT_TTL=720h
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
APP_BASE_URL=http://localhost:3000
```

## Output checklist

- [ ] Every endpoint above is implemented or stubbed with a TODO referencing the missing dependency
- [ ] Every list endpoint uses cursor pagination via `pkg/cursor`
- [ ] Auth middleware applied to every protected route
- [ ] Owner check on every PATCH/DELETE of user-owned resources (defense against IDOR)
- [ ] `openapi.yaml` validates with a parser; `operationId` unique
- [ ] Validation enforces SPEC caps (review 500, bio 200, photos 4, rating 0.5 steps)
- [ ] Default Inventory + Wishlist created in registration handler (same transaction)
- [ ] i18n fallback helper used in every beverage/producer read
- [ ] `.env.example` complete; no secrets in code
