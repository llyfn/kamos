//go:build integration
// +build integration

// SEC-006 — soft-deleted-user JWT revocation.
//
// Verifies the in-memory cache rejects access tokens issued before
// DELETE /v1/users/me as soon as the soft-delete commits, rather than
// waiting for the access-token TTL to expire.
package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/kamos/api/internal/auth"
)

// TestSoftDeleteCacheRevokesActiveToken covers the production code path:
// the DeleteMe handler synchronously Adds the user id to the cache, so the
// very next request with the doomed token is 401 ACCOUNT_DELETED — well
// within the JWT TTL.
func TestSoftDeleteCacheRevokesActiveToken(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Issue a fresh token. The default test JWT_TTL is 1 hour (see
	// buildServer); we'll observe revocation within milliseconds.
	tok, _ := mustRegister(t, srv, "deleted_user", "del@example.com", "password-123")

	// Sanity: token works before delete.
	if code, _ := doReq(t, srv, http.MethodGet, "/v1/users/me", tok, nil); code != http.StatusOK {
		t.Fatalf("pre-delete /me: status %d", code)
	}

	// DeleteMe — the handler calls SoftDelete.Add(uid) after the UPDATE.
	if code, _ := doReq(t, srv, http.MethodDelete, "/v1/users/me", tok, nil); code != http.StatusNoContent {
		t.Fatalf("DeleteMe: status %d", code)
	}

	// Next request with the same token must now be rejected. We are
	// nowhere near the 1h TTL; this proves the cache, not expiry, is
	// doing the work.
	code, body := doReq(t, srv, http.MethodGet, "/v1/users/me", tok, nil)
	if code != http.StatusUnauthorized {
		t.Fatalf("post-delete /me: status %d body=%s", code, body)
	}
	var e errBodyShape
	if err := json.Unmarshal(body, &e); err != nil {
		t.Fatalf("decode err body: %v", err)
	}
	if e.Code != "ACCOUNT_DELETED" {
		t.Fatalf("expected ACCOUNT_DELETED, got %q (body=%s)", e.Code, body)
	}

	// Other authed endpoints must also reject the token (proves the
	// middleware is the source of truth, not a one-off check in DeleteMe).
	code, _ = doReq(t, srv, http.MethodGet, "/v1/feed", tok, nil)
	if code != http.StatusUnauthorized {
		t.Fatalf("post-delete /feed: status %d (token should be revoked)", code)
	}
}

// TestSoftDeleteCacheRefreshRebuildsFromDB covers the recovery path: if
// the API restarts (or the cache is freshly constructed and hasn't seen the
// DeleteMe call), Refresh must rebuild the set from the DB so the doomed
// token still gets rejected after a restart.
func TestSoftDeleteCacheRefreshRebuildsFromDB(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	pool := getPool(t)

	_, uid := mustRegister(t, srv, "refreshed_user", "ref@example.com", "password-123")

	// Bypass the handler — set deleted_at directly. This simulates the
	// "API just started up, has not seen the in-flight delete" scenario.
	const q = `UPDATE users SET deleted_at = NOW(),
                              username_release_at = NOW() + INTERVAL '30 days'
              WHERE id = $1;`
	if _, err := pool.Exec(context.Background(), q, uid); err != nil {
		t.Fatalf("direct soft-delete UPDATE: %v", err)
	}

	// Build a fresh cache with a wide window so the row qualifies.
	cache := auth.NewSoftDeleteCache(pool, time.Minute, 24*time.Hour)
	if cache.Contains(uid) {
		t.Fatalf("brand-new cache should not contain uid yet")
	}
	if err := cache.Refresh(context.Background()); err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if !cache.Contains(uid) {
		t.Fatalf("after Refresh, cache should contain soft-deleted uid")
	}

	// Window narrower than the soft-delete age should NOT include the row.
	// (We just inserted it, so 1ns is functionally "exclude everything".)
	cacheTiny := auth.NewSoftDeleteCache(pool, time.Minute, time.Nanosecond)
	if err := cacheTiny.Refresh(context.Background()); err != nil {
		t.Fatalf("Refresh tiny: %v", err)
	}
	if cacheTiny.Contains(uid) {
		t.Fatalf("with a 1ns window, the row should not be in the cache")
	}
}
