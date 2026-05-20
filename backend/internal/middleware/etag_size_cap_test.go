package middleware

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestETagSkipsWhenBodyOverSizeCap — Phase 7a MAJOR-2 regression. The ETag
// middleware must NOT compute a hash for responses larger than
// etagMaxBufBytes. The body must still flush normally; only the ETag
// header is omitted.
func TestETagSkipsWhenBodyOverSizeCap(t *testing.T) {
	// Build a payload one byte over the cap to land on the > branch.
	payload := bytes.Repeat([]byte("x"), etagMaxBufBytes+1)
	h := ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write(payload)
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: want 200; got %d", resp.StatusCode)
	}
	if etag := resp.Header.Get("ETag"); etag != "" {
		t.Fatalf("ETag should be omitted on over-cap body; got %q", etag)
	}

	// Body still flushes intact.
	var got bytes.Buffer
	if _, err := got.ReadFrom(resp.Body); err != nil {
		t.Fatalf("read body: %v", err)
	}
	if got.Len() != len(payload) {
		t.Fatalf("body length: want %d; got %d", len(payload), got.Len())
	}
}

// TestETagComputesAtCapBoundary — a response exactly at etagMaxBufBytes
// still gets an ETag (the cap is strictly >, not >=).
func TestETagComputesAtCapBoundary(t *testing.T) {
	payload := bytes.Repeat([]byte("y"), etagMaxBufBytes)
	h := ETag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write(payload)
	}))
	srv := httptest.NewServer(h)
	defer srv.Close()

	resp, err := http.Get(srv.URL)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: want 200; got %d", resp.StatusCode)
	}
	if etag := resp.Header.Get("ETag"); etag == "" {
		t.Fatalf("expected ETag at boundary (body == cap); got empty")
	}
}
