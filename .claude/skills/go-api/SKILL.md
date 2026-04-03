---
name: go-api
description: "KAMOS Go backend API development skill. Use this to implement Go REST API handlers, middleware, JWT auth, Google OAuth, repository layer with pgx, and OpenAPI spec for the KAMOS platform. Invoke whenever Go backend, API handler, authentication, middleware, or endpoint implementation is requested."
---

# Go API Skill

Implements the KAMOS Go REST API: HTTP handlers, middleware stack, auth, repository layer, and OpenAPI spec.

## Project Structure

```
backend/
├── cmd/api/
│   └── main.go          — server bootstrap, config loading, router setup
├── internal/
│   ├── config/          — Config struct, env loading
│   ├── handler/         — HTTP handlers (one file per domain: auth.go, beverages.go, checkins.go, ...)
│   ├── middleware/       — auth.go, cors.go, logger.go, ratelimit.go
│   ├── model/           — domain structs matching DB entities
│   ├── repository/      — DB access layer (pgx/v5)
│   ├── service/         — business logic (optional layer for complex ops)
│   └── apierror/        — sentinel errors + JSON error response helpers
├── pkg/
│   └── jwt/             — token sign/verify helpers
├── migrations/          — symlink or copy from db-architect output
├── openapi.yaml
├── .env.example
└── README_backend.md
```

## Handler Pattern

```go
// internal/handler/beverages.go
func (h *Handler) GetBeverage(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    bev, err := h.repo.GetBeverage(r.Context(), id)
    if errors.Is(err, repository.ErrNotFound) {
        respondError(w, http.StatusNotFound, "beverage not found")
        return
    }
    if err != nil {
        respondError(w, http.StatusInternalServerError, "internal error")
        return
    }
    respondJSON(w, http.StatusOK, bev)
}
```

Helper functions in `handler/response.go`:
```go
func respondJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(v)
}
func respondError(w http.ResponseWriter, status int, msg string) {
    respondJSON(w, status, map[string]string{"error": msg})
}
```

## Repository Pattern

```go
// internal/repository/beverages.go
type BeverageRepository struct { db *pgxpool.Pool }

func (r *BeverageRepository) GetBeverage(ctx context.Context, id string) (*model.Beverage, error) {
    row := r.db.QueryRow(ctx, `SELECT id, name_i18n, ... FROM beverages WHERE id = $1`, id)
    var b model.Beverage
    if err := row.Scan(&b.ID, &b.NameI18n, ...); err != nil {
        if errors.Is(err, pgx.ErrNoRows) { return nil, ErrNotFound }
        return nil, fmt.Errorf("GetBeverage: %w", err)
    }
    return &b, nil
}
```

Use query patterns from `_workspace/02_backend/db/query_patterns.md` directly.

## Authentication

### JWT

```go
// pkg/jwt/jwt.go
type Claims struct {
    UserID   string `json:"uid"`
    Username string `json:"username"`
    jwt.RegisteredClaims
}
func Sign(userID, username, secret string, ttl time.Duration) (string, error) { ... }
func Verify(tokenStr, secret string) (*Claims, error) { ... }
```

Middleware injects claims into context:
```go
func Auth(secret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
            claims, err := jwt.Verify(token, secret)
            if err != nil { respondError(w, 401, "unauthorized"); return }
            ctx := context.WithValue(r.Context(), ctxKeyUser, claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

### Google OAuth

```go
// POST /auth/google — receive id_token from Flutter Google Sign-In
// Verify id_token with Google tokeninfo endpoint or google-auth-library
// Upsert user by google_sub → return JWT
```

## API Response Conventions

- Success: `200 OK` with JSON body; `201 Created` for new resources; `204 No Content` for deletes
- Pagination: cursor-based
  ```json
  { "items": [...], "next_cursor": "base64string", "has_more": true }
  ```
- Errors:
  ```json
  { "error": "human readable message", "code": "MACHINE_CODE" }
  ```
- All list responses are wrapped (never return a bare JSON array)

## OpenAPI Spec

Write `openapi.yaml` covering all endpoints. Each path must include:
- `operationId`
- Request body schema (if applicable)
- Response schemas (200, 400, 401, 404)
- Security requirements (`bearerAuth`)

Flutter engineer uses this to generate or write Dart models.

## Config

```go
type Config struct {
    Port          string
    DatabaseURL   string
    JWTSecret     string
    GoogleClientID string
    GoogleClientSecret string
}
// Load from environment: PORT, DATABASE_URL, JWT_SECRET, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
```

## Environment Setup

`.env.example`:
```
PORT=8080
DATABASE_URL=postgres://kamos:password@localhost:5432/kamos?sslmode=disable
JWT_SECRET=change-me-in-production
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
```
