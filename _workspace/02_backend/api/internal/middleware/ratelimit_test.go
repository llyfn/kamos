package middleware

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// helper: build a chain of RateLimitByIP and run N sequential requests
// from the same RemoteAddr. Returns the observed status codes.
func ipChain(t *testing.T, rps float64, burst int, n int) []int {
	t.Helper()
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	final := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	h := RateLimitByIP(log, rps, burst)(final)
	out := make([]int, n)
	for i := 0; i < n; i++ {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/x", nil)
		req.RemoteAddr = "10.0.0.1:55555"
		h.ServeHTTP(rr, req)
		out[i] = rr.Code
	}
	return out
}

// Burst is honored exactly: the first `burst` requests pass; the next is
// rejected with 429.
func TestRateLimitByIP_BurstThenReject(t *testing.T) {
	codes := ipChain(t, 1, 10, 11)
	for i := 0; i < 10; i++ {
		if codes[i] != http.StatusOK {
			t.Errorf("req %d: got %d want 200", i+1, codes[i])
		}
	}
	if codes[10] != http.StatusTooManyRequests {
		t.Errorf("req 11: got %d want 429", codes[10])
	}
}

// 429 response carries the correct body shape and Retry-After header.
func TestRateLimitByIP_BodyAndHeader(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := RateLimitByIP(log, 1, 1)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// Burn the single token.
	rr1 := httptest.NewRecorder()
	req1 := httptest.NewRequest(http.MethodGet, "/x", nil)
	req1.RemoteAddr = "10.0.0.2:1"
	h.ServeHTTP(rr1, req1)
	if rr1.Code != http.StatusOK {
		t.Fatalf("first req: %d", rr1.Code)
	}

	// Second request is rate-limited.
	rr2 := httptest.NewRecorder()
	req2 := httptest.NewRequest(http.MethodGet, "/x", nil)
	req2.RemoteAddr = "10.0.0.2:1"
	h.ServeHTTP(rr2, req2)
	if rr2.Code != http.StatusTooManyRequests {
		t.Fatalf("second req: %d", rr2.Code)
	}
	if got := rr2.Header().Get("Retry-After"); got != "1" {
		t.Errorf("Retry-After: %q", got)
	}
	var body map[string]any
	if err := json.Unmarshal(rr2.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["code"] != "RATE_LIMITED" {
		t.Errorf("code: %v", body["code"])
	}
	if body["error"] != "rate_limited" {
		t.Errorf("error: %v", body["error"])
	}
}

// After waiting roughly one token-interval, a fresh token is available
// and the next request passes. We pick 2 rps so the wait is 500ms +
// padding rather than the full second.
func TestRateLimitByIP_RefillsAfterWait(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := RateLimitByIP(log, 2, 1)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	send := func() int {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/x", nil)
		req.RemoteAddr = "10.0.0.3:1"
		h.ServeHTTP(rr, req)
		return rr.Code
	}
	if c := send(); c != http.StatusOK {
		t.Fatalf("first: %d", c)
	}
	if c := send(); c != http.StatusTooManyRequests {
		t.Fatalf("immediate second should fail: %d", c)
	}
	// 2 rps → ~500ms refill interval; wait ~750ms to be safe.
	time.Sleep(750 * time.Millisecond)
	if c := send(); c != http.StatusOK {
		t.Errorf("after wait: got %d want 200", c)
	}
}

// Per-user limit is keyed on the AuthedUser in the request context, not
// the IP. Two callers with different user ids each get their own bucket.
func TestRateLimitByUser_PerUserBucket(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	final := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	h := RateLimitByUser(log, 1, 2)(final)

	withUser := func(id string) *http.Request {
		req := httptest.NewRequest(http.MethodGet, "/x", nil)
		ctx := context.WithValue(req.Context(), ctxKeyUser, &AuthedUser{ID: id})
		return req.WithContext(ctx)
	}

	// User A burns both tokens.
	for i := 0; i < 2; i++ {
		rr := httptest.NewRecorder()
		h.ServeHTTP(rr, withUser("user-A"))
		if rr.Code != http.StatusOK {
			t.Fatalf("user-A req %d: %d", i, rr.Code)
		}
	}
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, withUser("user-A"))
	if rr.Code != http.StatusTooManyRequests {
		t.Errorf("user-A third req: got %d want 429", rr.Code)
	}

	// User B's bucket is independent — first request still passes.
	rr2 := httptest.NewRecorder()
	h.ServeHTTP(rr2, withUser("user-B"))
	if rr2.Code != http.StatusOK {
		t.Errorf("user-B first req: got %d want 200", rr2.Code)
	}
}

// Unauthed requests pass through without consuming a token — IP limits
// handle anonymous traffic.
func TestRateLimitByUser_UnauthedIsNoOp(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := RateLimitByUser(log, 1, 1)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	for i := 0; i < 5; i++ {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/x", nil)
		h.ServeHTTP(rr, req)
		if rr.Code != http.StatusOK {
			t.Errorf("unauthed call %d should not be rate-limited: %d", i, rr.Code)
		}
	}
}

// clientIP strips the port. Tests both the happy path and the malformed
// fallback (raw RemoteAddr returned).
func TestClientIPStripsPort(t *testing.T) {
	r := httptest.NewRequest(http.MethodGet, "/x", nil)
	r.RemoteAddr = "192.168.1.99:33010"
	if ip := clientIP(r); ip != "192.168.1.99" {
		t.Errorf("clientIP: %q", ip)
	}
	r.RemoteAddr = "ipv6-style-no-port"
	if ip := clientIP(r); ip == "" {
		t.Errorf("fallback: empty")
	}
}
