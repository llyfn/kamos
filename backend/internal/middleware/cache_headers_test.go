package middleware

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCacheControlSetsHeader(t *testing.T) {
	value := "public, max-age=600"
	h := CacheControl(value)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if got := resp.Header.Get("Cache-Control"); got != value {
		t.Fatalf("Cache-Control: want %q got %q", value, got)
	}
}

func TestETagFirstRequestReturns200WithHeader(t *testing.T) {
	h := ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"hello":"world"}`))
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: want 200 got %d", resp.StatusCode)
	}
	if resp.Header.Get("ETag") == "" {
		t.Fatalf("expected ETag header set")
	}
}

func TestETagIfNoneMatchReturns304(t *testing.T) {
	h := ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"hello":"world"}`))
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	// First request — capture the ETag.
	resp1, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("first get: %v", err)
	}
	defer resp1.Body.Close()
	etag := resp1.Header.Get("ETag")
	if etag == "" {
		t.Fatal("first response missing ETag")
	}

	// Second request with If-None-Match — expect 304.
	req, err := http.NewRequest(http.MethodGet, srv.URL, nil)
	if err != nil {
		t.Fatalf("new req: %v", err)
	}
	req.Header.Set("If-None-Match", etag)
	resp2, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("second get: %v", err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusNotModified {
		t.Fatalf("expected 304, got %d", resp2.StatusCode)
	}
	if got := resp2.Header.Get("ETag"); got != etag {
		t.Fatalf("304 missing/wrong ETag: want %q got %q", etag, got)
	}
}

func TestETagChangesWhenBodyChanges(t *testing.T) {
	var body string = `{"v":1}`
	h := ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(body))
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp1, _ := http.Get(srv.URL)
	tag1 := resp1.Header.Get("ETag")
	resp1.Body.Close()
	if tag1 == "" {
		t.Fatal("missing tag1")
	}

	body = `{"v":2}`
	resp2, _ := http.Get(srv.URL)
	tag2 := resp2.Header.Get("ETag")
	resp2.Body.Close()
	if tag2 == "" {
		t.Fatal("missing tag2")
	}

	if tag1 == tag2 {
		t.Fatalf("expected different ETags on changed body; both %q", tag1)
	}

	// Stale If-None-Match → 200 again, not 304.
	req, _ := http.NewRequest(http.MethodGet, srv.URL, nil)
	req.Header.Set("If-None-Match", tag1)
	resp3, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("third request: %v", err)
	}
	defer resp3.Body.Close()
	if resp3.StatusCode != http.StatusOK {
		t.Fatalf("stale ETag should not 304; got %d", resp3.StatusCode)
	}
}

func TestETagSkipsOnNonGet(t *testing.T) {
	h := ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{}`))
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	req, _ := http.NewRequest(http.MethodPost, srv.URL, nil)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.Header.Get("ETag") != "" {
		t.Fatalf("POST response should not carry ETag")
	}
}

func TestETagSkipsOn4xx(t *testing.T) {
	h := ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"error":"not found"}`))
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("expected 404; got %d", resp.StatusCode)
	}
	if resp.Header.Get("ETag") != "" {
		t.Fatalf("4xx response should not carry ETag")
	}
}

func TestNoStoreSetsHeader(t *testing.T) {
	h := NoStore(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true}`))
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	got := resp.Header.Get("Cache-Control")
	if got != "no-store, no-cache, must-revalidate, max-age=0" {
		t.Fatalf("Cache-Control: unexpected value %q", got)
	}
}

// TestNoStoreThenCacheControlOverrides asserts the chain order: when both
// NoStore and CacheControl wrap the same handler with NoStore outermost
// (the router's per-group default) and CacheControl innermost (the
// per-route opt-in), the inner CacheControl wins because both set the
// header BEFORE calling next.ServeHTTP.
func TestNoStoreThenCacheControlOverrides(t *testing.T) {
	override := "public, max-age=300, stale-while-revalidate=86400"
	h := NoStore(CacheControl(override)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{}`))
	})))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if got := resp.Header.Get("Cache-Control"); got != override {
		t.Fatalf("Cache-Control: want %q got %q", override, got)
	}
}

// Smoke-check the combination — Cache-Control sits on a 304 too.
func TestCacheControlSurvives304(t *testing.T) {
	value := "public, max-age=60"
	h := CacheControl(value)(ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(fmt.Sprintf(`{"id":%d}`, 42)))
	})))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp1, _ := http.Get(srv.URL)
	etag := resp1.Header.Get("ETag")
	resp1.Body.Close()

	req, _ := http.NewRequest(http.MethodGet, srv.URL, nil)
	req.Header.Set("If-None-Match", etag)
	resp2, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("conditional Do: %v", err)
	}
	defer resp2.Body.Close()
	if resp2.StatusCode != http.StatusNotModified {
		t.Fatalf("expected 304; got %d", resp2.StatusCode)
	}
	if got := resp2.Header.Get("Cache-Control"); got != value {
		t.Fatalf("304 lost Cache-Control: want %q got %q", value, got)
	}
}
