// Package middleware — role-based access control (Phase 5a).
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

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/domain"
)

// RoleResolver wraps the user-role lookup. One per server.
type RoleResolver struct {
	db *pgxpool.Pool
}

// NewRoleResolver constructs a resolver bound to the given pool.
func NewRoleResolver(db *pgxpool.Pool) *RoleResolver {
	return &RoleResolver{db: db}
}

// roleOf reads users.role for a live (non-deleted) user. NotFound on miss.
// Exported via the closure inside RequireRole so handlers can stay test-
// friendly (a fake pool / nil resolver is the test-only path).
func (rr *RoleResolver) roleOf(ctx context.Context, userID string) (domain.UserRole, error) {
	const q = `SELECT role::text FROM users WHERE id = $1 AND deleted_at IS NULL;`
	var s string
	if err := rr.db.QueryRow(ctx, q, userID).Scan(&s); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", apierror.ErrNotFound
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
				apierror.WriteError(w, http.StatusInternalServerError, "INTERNAL",
					"role resolver not configured")
				return
			}
			uid := UserIDFromContext(r.Context())
			if uid == "" {
				apierror.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
				return
			}
			role, err := rr.roleOf(r.Context(), uid)
			if err != nil {
				if errors.Is(err, apierror.ErrNotFound) {
					// User was deleted between Auth check and role lookup;
					// treat the same as a revoked token.
					apierror.WriteError(w, http.StatusUnauthorized, "ACCOUNT_DELETED",
						"account deleted")
					return
				}
				apierror.WriteError(w, http.StatusInternalServerError, "INTERNAL",
					"role lookup failed")
				return
			}
			for _, want := range allowed {
				if role == want {
					next.ServeHTTP(w, r)
					return
				}
			}
			apierror.WriteError(w, http.StatusForbidden, "ROLE_REQUIRED",
				"insufficient role")
		})
	}
}
