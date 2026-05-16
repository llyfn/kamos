package foursquare

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestDisabled(t *testing.T) {
	c := New("")
	if !c.Disabled() {
		t.Fatal("expected Disabled() true with empty key")
	}
	_, err := c.Search(context.Background(), SearchOptions{Query: "anything"})
	if !errors.Is(err, ErrDisabled) {
		t.Fatalf("expected ErrDisabled, got %v", err)
	}
}

func TestSearchDecodesAndCaches(t *testing.T) {
	var hits atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		if r.Header.Get("Authorization") != "test-key" {
			t.Errorf("auth header: %q (want %q)", r.Header.Get("Authorization"), "test-key")
		}
		if r.Header.Get("Accept-Language") != "ja" {
			t.Errorf("accept-language: %q", r.Header.Get("Accept-Language"))
		}
		if got := r.URL.Query().Get("query"); got != "daikoku" {
			t.Errorf("query param: %q", got)
		}
		if got := r.URL.Query().Get("ll"); got != "35.681236,139.767125" {
			t.Errorf("ll param: %q", got)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
		  "results": [{
		    "fsq_id": "abc123",
		    "name": "Daikoku",
		    "geocodes": { "main": { "latitude": 35.6812, "longitude": 139.7671 } },
		    "location": {
		      "address": "1-1 Marunouchi",
		      "country": "JP",
		      "region": "Tokyo",
		      "locality": "Chiyoda"
		    }
		  }]
		}`))
	}))
	defer srv.Close()

	c := newWithBase(t, "test-key", srv.URL)

	lat := 35.681236
	lng := 139.767125
	opts := SearchOptions{Query: "daikoku", Lat: &lat, Lng: &lng, Locale: "ja", Limit: 10}

	got, err := c.Search(context.Background(), opts)
	if err != nil {
		t.Fatalf("first search: %v", err)
	}
	if len(got) != 1 || got[0].FoursquareID != "abc123" || got[0].Name != "Daikoku" {
		t.Fatalf("unexpected places: %+v", got)
	}
	if got[0].Country != "JP" || got[0].Prefecture != "Tokyo" || got[0].Locality != "Chiyoda" {
		t.Errorf("location mapping wrong: %+v", got[0])
	}

	// Cache hit — should NOT bump upstream call count.
	if _, err := c.Search(context.Background(), opts); err != nil {
		t.Fatalf("second search: %v", err)
	}
	if hits.Load() != 1 {
		t.Errorf("upstream hits = %d (want 1, cache miss?)", hits.Load())
	}
}

func TestAuthFailureNotCached(t *testing.T) {
	var hits atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits.Add(1)
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"message":"unauthorized"}`))
	}))
	defer srv.Close()

	c := newWithBase(t, "bad-key", srv.URL)
	opts := SearchOptions{Query: "x", Limit: 5}

	_, err := c.Search(context.Background(), opts)
	if err == nil {
		t.Fatal("expected auth error")
	}
	if !errors.Is(err, ErrAuth) {
		t.Errorf("expected errors.Is(err, ErrAuth), got %v", err)
	}
	// Second call must also reach upstream — auth failures aren't cached.
	_, _ = c.Search(context.Background(), opts)
	if hits.Load() != 2 {
		t.Errorf("upstream hits = %d (want 2)", hits.Load())
	}
}

// SEC-003: New TrimSpace's the API key so accidental whitespace in env vars
// doesn't surface as a 401 from Foursquare.
func TestNewTrimsAPIKey(t *testing.T) {
	c := New(" key-with-spaces  ")
	if c.apiKey != "key-with-spaces" {
		t.Errorf("apiKey: %q (want %q)", c.apiKey, "key-with-spaces")
	}
	if c.Disabled() {
		t.Errorf("Disabled() = true after TrimSpace (expected false)")
	}
}

// Whitespace-only key trims to empty → Disabled client.
func TestNewWhitespaceKeyIsDisabled(t *testing.T) {
	c := New("   ")
	if !c.Disabled() {
		t.Errorf("Disabled() = false (want true for whitespace-only key)")
	}
}

func TestRetryOn5xx(t *testing.T) {
	var hits atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := hits.Add(1)
		if n == 1 {
			w.WriteHeader(http.StatusBadGateway)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"results":[]}`))
	}))
	defer srv.Close()

	c := newWithBase(t, "key", srv.URL)
	if _, err := c.Search(context.Background(), SearchOptions{Query: "x", Limit: 5}); err != nil {
		t.Fatalf("search: %v", err)
	}
	if hits.Load() != 2 {
		t.Errorf("hits = %d (want 2: original + 1 retry)", hits.Load())
	}
}

func TestRateLimitedSurfacesTypedError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer srv.Close()

	c := newWithBase(t, "key", srv.URL)
	_, err := c.Search(context.Background(), SearchOptions{Query: "x"})
	if !errors.Is(err, ErrRateLimited) {
		t.Fatalf("expected ErrRateLimited, got %v", err)
	}
}

func TestCacheKey(t *testing.T) {
	lat := 35.6812
	lng := 139.7671
	a := cacheKey(SearchOptions{Query: "  Daikoku  ", Lat: &lat, Lng: &lng, Locale: "ja", Limit: 10})
	b := cacheKey(SearchOptions{Query: "daikoku", Lat: &lat, Lng: &lng, Locale: "ja", Limit: 10})
	if a != b {
		t.Errorf("cache key should be case- and trim-insensitive: %q vs %q", a, b)
	}
}

// newWithBase points the test client at httptest by swapping the apiBase
// const for the lifetime of the test via a package-private hook.
func newWithBase(t *testing.T, apiKey, base string) *Client {
	t.Helper()
	c := New(apiKey)
	// Wrap the transport so every outbound request is rewritten to the
	// httptest server. Keeps the const apiBase intact (avoids a global swap)
	// while still exercising the real net/http path.
	c.http = &http.Client{
		Timeout: httpTimeout,
		Transport: rewriteTransport{
			base:   base,
			inner:  http.DefaultTransport,
		},
	}
	return c
}

type rewriteTransport struct {
	base  string
	inner http.RoundTripper
}

func (rt rewriteTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	// Rewrite scheme+host to the test server. Path + query are preserved
	// so the client's own URL assembly is what gets exercised.
	clone := *req
	clone.URL = &(*req.URL)
	clone.URL.Scheme = "http"
	idx := strings.Index(rt.base, "://")
	if idx >= 0 {
		clone.URL.Host = rt.base[idx+3:]
	}
	return rt.inner.RoundTrip(&clone)
}

// Guard against a future regression in retryBackoff that would slow tests
// noticeably — fail fast at >1s.
func TestRetryBackoffIsShort(t *testing.T) {
	if retryBackoff > time.Second {
		t.Fatalf("retryBackoff too long: %v", retryBackoff)
	}
}
