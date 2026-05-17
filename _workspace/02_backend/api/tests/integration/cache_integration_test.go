//go:build integration
// +build integration

package integration

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/cache"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/handlers"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/server"
)

// newServerWithCache builds the same router shape as newServer but wires
// the Phase 7 LRU bundle so we can observe hit/miss counters and
// invalidation behavior. Rate limiting stays OFF (same justification as
// newServer).
func newServerWithCache(t *testing.T) (*httptest.Server, *cache.Caches) {
	t.Helper()
	p := getPool(t)
	cfg := &config.Config{
		AppBaseURL:        "http://localhost",
		JWTSecret:         "integration-secret-please-replace-aaaaaaaaaaaa",
		JWTTTL:            time.Hour,
		RefreshTTL:        30 * 24 * time.Hour,
		Env:               "test",
		RateLimitDisabled: true,
	}
	signer := auth.NewSigner(cfg.JWTSecret, cfg.JWTTTL)
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	repos := repository.New(p)
	google := auth.NewGoogleVerifier("")
	softDelete := auth.NewSoftDeleteCache(p, 30*time.Second, cfg.JWTTTL+time.Hour)
	caches := cache.NewCaches()
	h := handlers.New(cfg, log, repos, signer, google).
		WithSoftDeleteCache(softDelete).
		WithCaches(caches)
	mux := server.New(log, signer, softDelete, h)
	return httptest.NewServer(mux), caches
}

// TestCategoriesCacheHits — first GET misses (populates), second GET hits.
// The named LRU's Stats() counter is the assertion.
func TestCategoriesCacheHits(t *testing.T) {
	truncateAll(t)
	srv, caches := newServerWithCache(t)
	defer srv.Close()

	// First request — cache miss → populates.
	code1, _ := doReq(t, srv, http.MethodGet, "/v1/categories", "", nil)
	if code1 != http.StatusOK {
		t.Fatalf("first GET /v1/categories status=%d", code1)
	}
	hits, misses := caches.Categories.Stats()
	if hits != 0 || misses != 1 {
		t.Fatalf("after first request: hits=%d misses=%d (want 0,1)", hits, misses)
	}

	// Second request — same Accept-Language path → cache hit.
	code2, _ := doReq(t, srv, http.MethodGet, "/v1/categories", "", nil)
	if code2 != http.StatusOK {
		t.Fatalf("second GET /v1/categories status=%d", code2)
	}
	hits, misses = caches.Categories.Stats()
	if hits != 1 || misses != 1 {
		t.Fatalf("after second request: hits=%d misses=%d (want 1,1)", hits, misses)
	}
}

// TestBeverageDetailCacheInvalidatesOnCheckin — GET /v1/beverages/{id} populates
// the cache. POST /v1/check-ins under the same beverage_id must bust the
// entry, so a subsequent GET re-queries the DB and reflects the new
// check_in_count.
func TestBeverageDetailCacheInvalidatesOnCheckin(t *testing.T) {
	truncateAll(t)
	srv, caches := newServerWithCache(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "drinker", "drinker@example.com", "password11")
	bevID := seedBeverage(t, "CacheTest")

	// Prime the cache.
	code, body := doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("prime GET status=%d body=%s", code, body)
	}
	var primed map[string]any
	if err := json.Unmarshal(body, &primed); err != nil {
		t.Fatalf("decode primed: %v", err)
	}
	primedCount, _ := primed["check_in_count"].(float64)
	if primedCount != 0 {
		t.Fatalf("primed check_in_count=%v want 0", primed["check_in_count"])
	}

	// Confirm the cache has one entry.
	_, misses := caches.BeverageDetail.Stats()
	if misses != 1 {
		t.Fatalf("expected 1 BeverageDetail miss after prime; got %d", misses)
	}

	// Second GET — cache hit.
	code, _ = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("warm GET status=%d", code)
	}
	hits, _ := caches.BeverageDetail.Stats()
	if hits != 1 {
		t.Fatalf("expected 1 BeverageDetail hit after warm GET; got %d", hits)
	}

	// Create a check-in — handler MUST bust the cache.
	code, body = doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"rating":      4.5,
	})
	if code != http.StatusCreated {
		t.Fatalf("create check-in status=%d body=%s", code, body)
	}

	// Third GET — must be a MISS (entry was invalidated), and must return
	// the updated check_in_count.
	code, body = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("post-checkin GET status=%d body=%s", code, body)
	}
	var after map[string]any
	if err := json.Unmarshal(body, &after); err != nil {
		t.Fatalf("decode after: %v", err)
	}
	afterCount, _ := after["check_in_count"].(float64)
	if afterCount != 1 {
		t.Fatalf("post-checkin check_in_count=%v want 1 (cache likely served stale)", after["check_in_count"])
	}
	hits, misses = caches.BeverageDetail.Stats()
	if misses != 2 {
		t.Fatalf("expected 2 BeverageDetail misses after invalidation; got %d (hits=%d)", misses, hits)
	}
}

// TestBeverageDetailCacheInvalidatesOnDelete — soft-deleting a check-in
// must also bust the cache (avg_rating + check_in_count drop back down).
func TestBeverageDetailCacheInvalidatesOnDelete(t *testing.T) {
	truncateAll(t)
	srv, caches := newServerWithCache(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "delter", "delter@example.com", "password11")
	bevID := seedBeverage(t, "DeleteTest")

	// Create a check-in.
	code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"rating":      5.0,
	})
	if code != http.StatusCreated {
		t.Fatalf("create check-in status=%d body=%s", code, body)
	}
	var ci map[string]any
	_ = json.Unmarshal(body, &ci)
	checkinID, _ := ci["id"].(string)
	if checkinID == "" {
		t.Fatalf("missing check-in id: %s", body)
	}

	// Prime the cache with check_in_count=1.
	code, _ = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("prime GET status=%d", code)
	}

	// Soft-delete the check-in.
	code, body = doReq(t, srv, http.MethodDelete, "/v1/check-ins/"+checkinID, tok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete status=%d body=%s", code, body)
	}

	// Next GET must re-query and reflect check_in_count=0.
	code, body = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("post-delete GET status=%d body=%s", code, body)
	}
	var after map[string]any
	_ = json.Unmarshal(body, &after)
	afterCount, _ := after["check_in_count"].(float64)
	if afterCount != 0 {
		t.Fatalf("post-delete check_in_count=%v want 0 (cache served stale)", after["check_in_count"])
	}
	if _, misses := caches.BeverageDetail.Stats(); misses < 2 {
		t.Fatalf("expected at least 2 misses after invalidation; got %d", misses)
	}
}

// TestAdminModerateCheckinInvalidatesBeverageDetailCache — Phase 7a BLOCKER-1
// regression. A moderator soft-deletes a check-in via the admin surface; the
// public beverage page must reflect the action immediately (avg_rating and
// check_in_count recomputed by the trigger, cache busted by the handler).
func TestAdminModerateCheckinInvalidatesBeverageDetailCache(t *testing.T) {
	truncateAll(t)
	srv, caches := newServerWithCache(t)
	defer srv.Close()

	bevID := seedBeverage(t, "ModerationCache")
	userTok, _ := mustRegister(t, srv, "mod_target", "mt@example.com", "password11")

	// Create a check-in with a known rating so the aggregate is observable.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", userTok, map[string]any{
		"beverage_id": bevID,
		"rating":      4.0,
	})
	if code != http.StatusCreated {
		t.Fatalf("create check-in: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	checkinID, _ := ci["id"].(string)
	if checkinID == "" {
		t.Fatalf("missing check-in id: %s", raw)
	}

	// Prime the cache — avg_rating=4.0, check_in_count=1.
	code, body := doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("prime GET status=%d body=%s", code, body)
	}
	var primed map[string]any
	_ = json.Unmarshal(body, &primed)
	primedCount, _ := primed["check_in_count"].(float64)
	if primedCount != 1 {
		t.Fatalf("primed check_in_count=%v want 1", primed["check_in_count"])
	}

	// Confirm a warm read hits the LRU.
	code, _ = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("warm GET status=%d", code)
	}
	hits, _ := caches.BeverageDetail.Stats()
	if hits < 1 {
		t.Fatalf("expected at least 1 BeverageDetail hit after warm GET; got %d", hits)
	}

	// Promote an admin and moderate the check-in.
	adminTok, adminID := mustRegister(t, srv, "moderator_x", "modx@example.com", "password11")
	promoteToAdmin(t, adminID)
	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/admin/check-ins/"+checkinID+"/moderate", adminTok, map[string]any{
			"notes": "test rule violation",
		})
	if code != http.StatusNoContent {
		t.Fatalf("moderate: %d body=%s", code, raw)
	}

	// Next public GET must be a MISS — the cache was busted — and must reflect
	// the trigger-recomputed aggregates (the only check-in is gone, so
	// check_in_count drops to 0).
	missesBefore := func() int64 { _, m := caches.BeverageDetail.Stats(); return m }()
	code, body = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("post-moderate GET status=%d body=%s", code, body)
	}
	var after map[string]any
	_ = json.Unmarshal(body, &after)
	afterCount, _ := after["check_in_count"].(float64)
	if afterCount != 0 {
		t.Fatalf("post-moderate check_in_count=%v want 0 (cache likely served stale)", after["check_in_count"])
	}
	missesAfter := func() int64 { _, m := caches.BeverageDetail.Stats(); return m }()
	if missesAfter <= missesBefore {
		t.Fatalf("expected another BeverageDetail miss after moderation; misses %d → %d", missesBefore, missesAfter)
	}
}

// TestCategoriesETagShortCircuits — first GET captures the ETag, second GET
// with If-None-Match returns 304 + an empty body.
func TestCategoriesETagShortCircuits(t *testing.T) {
	truncateAll(t)
	srv, _ := newServerWithCache(t)
	defer srv.Close()

	resp1, err := http.Get(srv.URL + "/v1/categories")
	if err != nil {
		t.Fatalf("first get: %v", err)
	}
	etag := resp1.Header.Get("ETag")
	resp1.Body.Close()
	if etag == "" {
		t.Fatal("first response missing ETag")
	}
	if cc := resp1.Header.Get("Cache-Control"); cc == "" {
		t.Fatalf("expected Cache-Control header; got empty")
	}

	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/categories", nil)
	req.Header.Set("If-None-Match", etag)
	resp2, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("second get: %v", err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusNotModified {
		t.Fatalf("expected 304; got %d", resp2.StatusCode)
	}
}
