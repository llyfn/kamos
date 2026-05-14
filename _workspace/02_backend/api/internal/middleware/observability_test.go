package middleware

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

// Trace is a transparent pass-through when no OTel provider is configured
// (the global default is a noop tracer). Status code propagates and the
// wrapped handler is invoked.
func TestTraceMiddlewareNoopPassthrough(t *testing.T) {
	var sawCtx bool
	h := Trace(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sawCtx = r.Context() != nil
		w.WriteHeader(http.StatusTeapot)
	}))
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/users/yamamoto", nil)
	h.ServeHTTP(rr, req)
	if !sawCtx {
		t.Errorf("ctx not threaded")
	}
	if rr.Code != http.StatusTeapot {
		t.Errorf("status not propagated: %d", rr.Code)
	}
}

// RecoverWithSentry must convert panics into 500s and the canonical body.
// Sentry is disabled in tests (no DSN), so the only effect should be the
// HTTP write.
func TestRecoverWithSentryConvertsPanic(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := RecoverWithSentry(log)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		panic("kaboom")
	}))
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusInternalServerError {
		t.Fatalf("status: %d", rr.Code)
	}
	if !contains(rr.Body.String(), "INTERNAL") {
		t.Errorf("body missing INTERNAL code: %s", rr.Body.String())
	}
	if !contains(rr.Body.String(), "internal error") {
		t.Errorf("body missing generic message: %s", rr.Body.String())
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
