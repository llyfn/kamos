// Package middleware — role-based access control.
//
// Usage:
//
//	rr := middleware.NewRoleResolver(pool)
//	r.With(rr.RequireRole(domain.RoleAdmin)).Get(...)
//	r.With(rr.RequireRole(domain.RoleModerator, domain.RoleAdmin)).Get(...)
//
// Roles live on users.role (the postgres user_role enum from migration 007)
// and are read with a single PK lookup per admin-scoped request. We do NOT
// bake the role into the JWT claims — that would mean a demotion has to wait
// for the access-token TTL (15 min – 720h depending on env) before taking
// effect. The cost of one indexed SELECT per admin request is well below
// the cost of letting a demoted admin keep their privileges for 15 minutes.
//
// The resolver shares the same nil-safe pattern as Auth: passing a nil
// resolver makes RequireRole a no-op (used by test helpers that exercise
// non-admin routes).
package middleware

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/hashicorp/golang-lru/v2/expirable"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

// RoleResolver wraps the user-role lookup. One per server.
//
// SEC-027 (Stage 4): an in-process LRU + 5s TTL on (user_id → role)
// lookups cuts the hot-admin-endpoint DB pressure from one SELECT per
// request to ~one per 5s per user. The 5s ceiling is the explicit
// staleness window — a demotion via UpdateUserRole / SuspendUser flushes
// the entry immediately via Invalidate, so the cache is staleness-
// bounded in both directions.
type RoleResolver struct {
	db    *pgxpool.Pool
	cache *expirable.LRU[string, domain.UserRole]
}

const (
	roleCacheSize = 10000
	roleCacheTTL  = 5 * time.Second
)

// NewRoleResolver constructs a resolver bound to the given pool.
func NewRoleResolver(db *pgxpool.Pool) *RoleResolver {
	return &RoleResolver{
		db:    db,
		cache: expirable.NewLRU[string, domain.UserRole](roleCacheSize, nil, roleCacheTTL),
	}
}

// GetRole returns the role for the given user, hitting the cache first
// and falling back to the DB. Exported so the service layer can use the
// same single source of truth for role checks outside of the middleware
// (e.g. CommentService.Delete).
func (rr *RoleResolver) GetRole(ctx context.Context, userID string) (domain.UserRole, error) {
	if rr == nil {
		return "", errors.New("RoleResolver.GetRole: not configured")
	}
	if rr.cache != nil {
		if role, ok := rr.cache.Get(userID); ok {
			return role, nil
		}
	}
	if rr.db == nil {
		return "", errors.New("RoleResolver.GetRole: not configured")
	}
	role, err := rr.roleOf(ctx, userID)
	if err != nil {
		return "", err
	}
	if rr.cache != nil {
		rr.cache.Add(userID, role)
	}
	return role, nil
}

// Invalidate evicts the cached role for the given user. Called from
// AdminService.UpdateUserRole and AdminService.SuspendUser after the
// underlying DB write commits so subsequent role checks see the new
// state without waiting for the 5s TTL.
func (rr *RoleResolver) Invalidate(userID string) {
	if rr == nil || rr.cache == nil || userID == "" {
		return
	}
	rr.cache.Remove(userID)
}

// roleOf reads users.role for a live (non-deleted) user. NotFound on miss.
// Exported via the closure inside RequireRole so handlers can stay test-
// friendly (a fake pool / nil resolver is the test-only path).
func (rr *RoleResolver) roleOf(ctx context.Context, userID string) (domain.UserRole, error) {
	const q = `SELECT role::text FROM users WHERE id = $1 AND deleted_at IS NULL;`
	var s string
	if err := rr.db.QueryRow(ctx, q, userID).Scan(&s); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", domain.ErrNotFound
		}
		return "", fmt.Errorf("RoleResolver.roleOf: %w", err)
	}
	role := domain.UserRole(s)
	if !role.Valid() {
		// DB CHECK would have rejected anything else, but be paranoid in
		// case of a future migration that adds a value we don't know.
		return "", fmt.Errorf("RoleResolver.roleOf: unknown role %q", s)
	}
	return role, nil
}

// RequireRole returns a middleware that 403s unless the authed user's
// role matches one of `allowed`. The middleware MUST sit downstream of
// Auth (it reads UserIDFromContext); a missing user is treated as 401
// UNAUTHORIZED, matching the rest of the auth stack.
//
// A nil receiver short-circuits with 500 — RBAC depends on the DB and
// can't be silently bypassed; if you mean "no role check" don't wrap with
// this middleware at all.
func (rr *RoleResolver) RequireRole(allowed ...domain.UserRole) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if rr == nil || rr.db == nil {
				httperr.WriteError(w, http.StatusInternalServerError, "INTERNAL",
					"role resolver not configured")
				return
			}
			uid := UserIDFromContext(r.Context())
			if uid == "" {
				httperr.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
				return
			}
			role, err := rr.GetRole(r.Context(), uid)
			if err != nil {
				if errors.Is(err, domain.ErrNotFound) {
					// User was deleted between Auth check and role lookup;
					// treat the same as a revoked token.
					httperr.WriteError(w, http.StatusUnauthorized, "ACCOUNT_DELETED",
						"account deleted")
					return
				}
				httperr.WriteError(w, http.StatusInternalServerError, "INTERNAL",
					"role lookup failed")
				return
			}
			for _, want := range allowed {
				if role == want {
					next.ServeHTTP(w, r)
					return
				}
			}
			httperr.WriteError(w, http.StatusForbidden, "ROLE_REQUIRED",
				"insufficient role")
		})
	}
}
