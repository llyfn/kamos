// Package middleware provides cross-cutting HTTP middleware: panic recovery,
// request ID, structured access logging, and JWT auth.
package middleware

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/auth"
)

type ctxKey int

const (
	ctxKeyUser ctxKey = iota
	ctxKeyRequestID
)

// AuthedUser is what UserFromContext returns. We never re-fetch the DB user on
// every request — the JWT claims are authoritative until expiry.
type AuthedUser struct {
	ID       string
	Username string
}

// UserFromContext returns the authenticated user, or nil if the request was
// not authed (e.g., a public-route handler called without Auth middleware).
func UserFromContext(ctx context.Context) *AuthedUser {
	v, _ := ctx.Value(ctxKeyUser).(*AuthedUser)
	return v
}

// UserIDFromContext returns the authed user ID or "" when the request is
// not authed. Convenience wrapper for middleware that doesn't need the
// full AuthedUser.
func UserIDFromContext(ctx context.Context) string {
	if u := UserFromContext(ctx); u != nil {
		return u.ID
	}
	return ""
}

// MustUser returns the authed user or writes 401 and returns nil. Use this in
// handlers that are *supposed* to be behind Auth — it's a defensive backstop.
func MustUser(w http.ResponseWriter, r *http.Request) *AuthedUser {
	u := UserFromContext(r.Context())
	if u == nil {
		apierror.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
		return nil
	}
	return u
}

// RequestIDFromContext returns the per-request id assigned by RequestID.
func RequestIDFromContext(ctx context.Context) string {
	v, _ := ctx.Value(ctxKeyRequestID).(string)
	return v
}

// RequestID assigns a random hex id to every request, available to handlers
// and the access log.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-Id")
		if id == "" {
			b := make([]byte, 8)
			_, _ = rand.Read(b)
			id = hex.EncodeToString(b)
		}
		w.Header().Set("X-Request-Id", id)
		ctx := context.WithValue(r.Context(), ctxKeyRequestID, id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// Recover converts panics into 500s and logs the stack.
func Recover(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					log.Error("panic",
						"err", rec,
						"path", r.URL.Path,
						"method", r.Method,
						"request_id", RequestIDFromContext(r.Context()),
					)
					apierror.WriteError(w, http.StatusInternalServerError, "INTERNAL", "internal error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

// statusRecorder lets the access log report the response code.
type statusRecorder struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}
func (s *statusRecorder) Write(b []byte) (int, error) {
	if s.status == 0 {
		s.status = http.StatusOK
	}
	n, err := s.ResponseWriter.Write(b)
	s.bytes += n
	return n, err
}

// AccessLog logs one structured line per request after the handler returns.
func AccessLog(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			sr := &statusRecorder{ResponseWriter: w}
			next.ServeHTTP(sr, r)
			log.Info("http",
				"method", r.Method,
				"path", r.URL.Path,
				"status", sr.status,
				"dur_ms", time.Since(start).Milliseconds(),
				"bytes", sr.bytes,
				"request_id", RequestIDFromContext(r.Context()),
				"remote", r.RemoteAddr,
			)
		})
	}
}

// Auth verifies the Bearer token using the given signer and injects an
// AuthedUser into the request context.
func Auth(s *auth.Signer) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			if !strings.HasPrefix(h, "Bearer ") {
				apierror.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
				return
			}
			token := strings.TrimPrefix(h, "Bearer ")
			claims, err := s.Verify(token)
			if err != nil {
				apierror.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
				return
			}
			user := &AuthedUser{ID: claims.UserID, Username: claims.Username}
			ctx := context.WithValue(r.Context(), ctxKeyUser, user)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// OptionalAuth attempts to parse a token, but does NOT 401 on failure. Used
// for public endpoints (e.g. GET /v1/users/:username) that show different
// content when the viewer is authed (e.g. follow state).
func OptionalAuth(s *auth.Signer) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			if strings.HasPrefix(h, "Bearer ") {
				if claims, err := s.Verify(strings.TrimPrefix(h, "Bearer ")); err == nil {
					ctx := context.WithValue(r.Context(), ctxKeyUser,
						&AuthedUser{ID: claims.UserID, Username: claims.Username})
					r = r.WithContext(ctx)
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}
