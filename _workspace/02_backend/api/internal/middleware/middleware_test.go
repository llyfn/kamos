package middleware

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/kamos/api/internal/auth"
)

// helper: a JSON-decoding wrapper that fails the test on error.
func decodeErr(t *testing.T, body io.Reader) map[string]any {
	t.Helper()
	var v map[string]any
	if err := json.NewDecoder(body).Decode(&v); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	return v
}

// RequestID assigns a header when one is missing, and propagates one when
// it's already provided.
func TestRequestIDMiddleware(t *testing.T) {
	var sawCtx string
	h := RequestID(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sawCtx = RequestIDFromContext(r.Context())
		w.WriteHeader(http.StatusOK)
	}))

	t.Run("assigns when missing", func(t *testing.T) {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/x", nil)
		h.ServeHTTP(rr, req)
		got := rr.Header().Get("X-Request-Id")
		if got == "" {
			t.Errorf("X-Request-Id was not set on the response")
		}
		if sawCtx != got {
			t.Errorf("ctx %q != header %q", sawCtx, got)
		}
	})

	t.Run("propagates incoming header", func(t *testing.T) {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/x", nil)
		req.Header.Set("X-Request-Id", "req-deadbeef")
		h.ServeHTTP(rr, req)
		if got := rr.Header().Get("X-Request-Id"); got != "req-deadbeef" {
			t.Errorf("header propagation: got %q", got)
		}
		if sawCtx != "req-deadbeef" {
			t.Errorf("ctx propagation: got %q", sawCtx)
		}
	})
}

// Recover swallows panics, logs them, and writes 500 + the canonical body.
func TestRecoverMiddleware(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	h := Recover(log)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		panic("kaboom")
	}))
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusInternalServerError {
		t.Fatalf("status: %d", rr.Code)
	}
	body := decodeErr(t, rr.Body)
	if body["code"] != "INTERNAL" {
		t.Errorf("code: %v", body["code"])
	}
	if body["error"] != "internal error" {
		t.Errorf("error message leaked: %v", body["error"])
	}
}

// Auth: missing / malformed / invalid / expired tokens are rejected. A valid
// token populates the request context with the user id and username.
func TestAuthMiddleware(t *testing.T) {
	signer := auth.NewSigner("test-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", time.Hour)
	expiredSigner := auth.NewSigner("test-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", -time.Minute)

	var capturedUser *AuthedUser
	protected := Auth(signer, nil)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		capturedUser = UserFromContext(r.Context())
		w.WriteHeader(http.StatusOK)
	}))

	t.Run("missing Authorization", func(t *testing.T) {
		capturedUser = nil
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		protected.ServeHTTP(rr, req)
		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("status: %d", rr.Code)
		}
		body := decodeErr(t, rr.Body)
		if body["code"] != "UNAUTHORIZED" {
			t.Errorf("code: %v", body["code"])
		}
		if capturedUser != nil {
			t.Errorf("user should not be set on rejection: %+v", capturedUser)
		}
	})

	t.Run("malformed header (no Bearer)", func(t *testing.T) {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("Authorization", "Token abc")
		protected.ServeHTTP(rr, req)
		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("status: %d", rr.Code)
		}
	})

	t.Run("invalid bearer token", func(t *testing.T) {
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("Authorization", "Bearer not.a.real.jwt")
		protected.ServeHTTP(rr, req)
		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("status: %d", rr.Code)
		}
	})

	t.Run("expired token", func(t *testing.T) {
		tok, err := expiredSigner.Sign("u1", "yamamoto")
		if err != nil {
			t.Fatalf("Sign: %v", err)
		}
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("Authorization", "Bearer "+tok)
		protected.ServeHTTP(rr, req)
		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("status: %d", rr.Code)
		}
	})

	t.Run("valid token populates context", func(t *testing.T) {
		capturedUser = nil
		tok, err := signer.Sign("u-42", "yamamoto")
		if err != nil {
			t.Fatalf("Sign: %v", err)
		}
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("Authorization", "Bearer "+tok)
		protected.ServeHTTP(rr, req)
		if rr.Code != http.StatusOK {
			t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
		}
		if capturedUser == nil {
			t.Fatalf("user not in context")
		}
		if capturedUser.ID != "u-42" || capturedUser.Username != "yamamoto" {
			t.Errorf("user: %+v", capturedUser)
		}
	})
}

// OptionalAuth: invalid tokens are silently ignored (the handler still runs
// with a nil user). Valid tokens populate the context like Auth.
func TestOptionalAuthMiddleware(t *testing.T) {
	signer := auth.NewSigner("opt-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", time.Hour)
	var captured *AuthedUser
	h := OptionalAuth(signer, nil)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		captured = UserFromContext(r.Context())
		w.WriteHeader(http.StatusOK)
	}))

	t.Run("no token, handler runs unauthed", func(t *testing.T) {
		captured = nil
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		h.ServeHTTP(rr, req)
		if rr.Code != http.StatusOK {
			t.Fatalf("status: %d", rr.Code)
		}
		if captured != nil {
			t.Errorf("user should be nil for unauthed call: %+v", captured)
		}
	})

	t.Run("invalid token, handler still runs", func(t *testing.T) {
		captured = nil
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("Authorization", "Bearer garbage")
		h.ServeHTTP(rr, req)
		if rr.Code != http.StatusOK {
			t.Fatalf("status: %d", rr.Code)
		}
		if captured != nil {
			t.Errorf("user must remain nil for invalid token")
		}
	})

	t.Run("valid token populates", func(t *testing.T) {
		captured = nil
		tok, err := signer.Sign("u-1", "u")
		if err != nil {
			t.Fatalf("Sign: %v", err)
		}
		rr := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/", nil)
		req.Header.Set("Authorization", "Bearer "+tok)
		h.ServeHTTP(rr, req)
		if captured == nil || captured.ID != "u-1" {
			t.Errorf("user: %+v", captured)
		}
	})
}

// MustUser returns nil and writes 401 when there is no authed user.
func TestMustUser(t *testing.T) {
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	u := MustUser(rr, req)
	if u != nil {
		t.Fatalf("expected nil user")
	}
	if rr.Code != http.StatusUnauthorized {
		t.Errorf("status: %d", rr.Code)
	}
}

// statusRecorder must report 200 when Write is called without WriteHeader.
func TestStatusRecorderDefaultsToOK(t *testing.T) {
	sr := &statusRecorder{ResponseWriter: httptest.NewRecorder()}
	if _, err := sr.Write([]byte("body")); err != nil {
		t.Fatalf("Write: %v", err)
	}
	if sr.status != http.StatusOK {
		t.Errorf("status: %d", sr.status)
	}
	if sr.bytes != 4 {
		t.Errorf("bytes: %d", sr.bytes)
	}
}

// AccessLog runs without panicking and lets the wrapped handler write.
func TestAccessLogMiddleware(t *testing.T) {
	var captured strings.Builder
	log := slog.New(slog.NewTextHandler(&captured, &slog.HandlerOptions{Level: slog.LevelInfo}))
	h := AccessLog(log)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`ok`))
	}))
	rr := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/x", nil)
	h.ServeHTTP(rr, req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("status: %d", rr.Code)
	}
	if !strings.Contains(captured.String(), "http") {
		t.Errorf("expected access log line, got %q", captured.String())
	}
}
