// Package auth — soft-deleted user JWT revocation (SEC-006).
//
// Problem: JWT access tokens stay valid until expiry (TTL >= 15 min by SPEC;
// 720h in our local.env for dev convenience). When a user soft-deletes their
// account via DELETE /v1/users/me, their existing access tokens remain usable
// — they can still hit /v1/venues/search (paid Foursquare egress), create
// check-ins, view feed, etc. until the TTL elapses. The user has explicitly
// withdrawn consent; honoring the token would violate that.
//
// Fix: maintain an in-memory set of soft-deleted user IDs whose deleted_at is
// within the JWT TTL window. The Auth middleware consults this set on every
// request and rejects tokens whose subject is in the set with
// 401 ACCOUNT_DELETED.
//
// The set is refreshed every refreshInterval from:
//
//	SELECT id FROM users WHERE deleted_at > now() - $1::interval
//
// where the interval (window) MUST be >= JWT_TTL. We use 30m by default to
// give headroom for clock skew + the eventual refresh-token cleanup job.
// (Local dev runs with JWT_TTL=720h — the window must still be set high
// enough to cover the configured TTL; see cmd/server/main.go where we
// derive window from JWTTTL when it's larger than the floor.)
//
// Updates: the DeleteMe handler calls Add(userID) immediately after the DB
// soft-delete commits, so the very next request with the doomed token is
// rejected without waiting for the next refresh tick.
package auth

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// SoftDeleteCache holds the set of soft-deleted user IDs whose tokens may
// still be in circulation. Reads are O(1) under RLock; writes (Add /
// Refresh) take WLock.
type SoftDeleteCache struct {
	mu              sync.RWMutex
	ids             map[string]struct{}
	db              *pgxpool.Pool
	refreshInterval time.Duration
	window          time.Duration
}

// CacheLogger is the minimal logging interface the cache needs. *slog.Logger
// satisfies it directly. We define a local interface so the auth package
// stays free of a hard slog dependency in test helpers.
type CacheLogger interface {
	Error(msg string, args ...any)
}

// NewSoftDeleteCache builds an empty cache. The caller must run Run(ctx, log)
// in a goroutine to populate it and keep it fresh.
//
//   - refreshInterval: how often Refresh runs. 60s in production.
//   - window: how far back to look for soft-deleted users. MUST be >= JWT_TTL.
func NewSoftDeleteCache(db *pgxpool.Pool, refreshInterval, window time.Duration) *SoftDeleteCache {
	return &SoftDeleteCache{
		ids:             map[string]struct{}{},
		db:              db,
		refreshInterval: refreshInterval,
		window:          window,
	}
}

// Contains reports whether userID is in the soft-deleted set.
func (c *SoftDeleteCache) Contains(userID string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	_, ok := c.ids[userID]
	return ok
}

// Add inserts userID into the set immediately. Called by the DeleteMe
// handler after the soft-delete UPDATE commits, so the doomed token is
// rejected on the very next request rather than waiting up to
// refreshInterval seconds for the next tick.
func (c *SoftDeleteCache) Add(userID string) {
	c.mu.Lock()
	c.ids[userID] = struct{}{}
	c.mu.Unlock()
}

// Refresh rebuilds the set from the DB. The query is supported by the
// idx_users_deleted_at_recent partial index (migration 007).
func (c *SoftDeleteCache) Refresh(ctx context.Context) error {
	// pgx serializes a Go time.Duration as a microsecond integer when
	// passed as INTERVAL, which postgres accepts. Using $1::interval +
	// an integer-microseconds string keeps the query plan stable.
	intervalStr := fmt.Sprintf("%d microseconds", c.window.Microseconds())
	const q = `SELECT id::text FROM users WHERE deleted_at > now() - $1::interval`
	rows, err := c.db.Query(ctx, q, intervalStr)
	if err != nil {
		return fmt.Errorf("SoftDeleteCache.Refresh query: %w", err)
	}
	defer rows.Close()
	next := map[string]struct{}{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return fmt.Errorf("SoftDeleteCache.Refresh scan: %w", err)
		}
		next[id] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("SoftDeleteCache.Refresh rows: %w", err)
	}
	c.mu.Lock()
	c.ids = next
	c.mu.Unlock()
	return nil
}

// Run starts the refresh loop. Returns when ctx is canceled. An initial
// Refresh is attempted synchronously; a failure is logged but does not
// block startup (the cache is empty until the first successful refresh,
// which is safe — a doomed token simply gets one more grace request).
func (c *SoftDeleteCache) Run(ctx context.Context, log CacheLogger) {
	if err := c.Refresh(ctx); err != nil && log != nil {
		log.Error("soft_delete_cache initial refresh failed", "err", err)
	}
	t := time.NewTicker(c.refreshInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := c.Refresh(ctx); err != nil && log != nil {
				log.Error("soft_delete_cache periodic refresh failed", "err", err)
			}
		}
	}
}
