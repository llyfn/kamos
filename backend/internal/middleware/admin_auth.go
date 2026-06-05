// admin_auth.go — admin cookie auth + CSRF middlewares.
//
// AdminAuth: like Auth, but reads the access token from the
// kamos_admin_access cookie first and falls back to Authorization:
// Bearer ...  for backward-compat with the BearerAuth swagger UI flow
// during the transition.
//
// RequireCSRF: double-submit pattern. On POST/PATCH/PUT/DELETE, the
// request must carry an X-CSRF-Token header AND a kamos_admin_csrf
// cookie; both must constant-time-match. GET/HEAD/OPTIONS pass through.
package middleware

import (
	"context"
	"crypto/subtle"
	"net/http"
	"net/url"
	"strings"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/httperr"
)

const (
	adminAccessCookie = "kamos_admin_access"
	adminCSRFCookie   = "kamos_admin_csrf"
	csrfHeader        = "X-CSRF-Token"
)

// AdminAuth resolves the authed user from either the kamos_admin_access
// cookie or an Authorization: Bearer header. SoftDelete revocation
// applies the same way it does in Auth.
//
// Mirrors Auth's nil-safe pattern: a nil signer/cache short-circuits to
// 401 (no silent bypass).
func AdminAuth(s *auth.Signer, softDelete *auth.SoftDeleteCache) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := ""
			if c, err := r.Cookie(adminAccessCookie); err == nil && c.Value != "" {
				token = c.Value
			} else if h := r.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
				token = strings.TrimPrefix(h, "Bearer ")
			}
			if token == "" || s == nil {
				httperr.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
				return
			}
			claims, err := s.Verify(token)
			if err != nil {
				httperr.WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
				return
			}
			if softDelete != nil && softDelete.Contains(claims.UserID) {
				httperr.WriteError(w, http.StatusUnauthorized, "ACCOUNT_DELETED", "account deleted")
				return
			}
			user := &AuthedUser{ID: claims.UserID, Username: claims.Username}
			ctx := context.WithValue(r.Context(), ctxKeyUser, user)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequireCSRF enforces the double-submit token check on cookie-
// authenticated mutating requests. GET / HEAD / OPTIONS skip the check.
// Requests authenticated via Authorization: Bearer (no admin cookie
// present) also skip — CSRF attacks rely on the browser auto-attaching
// cookies, which doesn't happen for Bearer tokens. This keeps the
// existing Bearer-driven mobile + swagger flows working during the
// admin-cookie transition.
//
// Cookie values are URL-decoded before compare so a future change to
// http.SetCookie's escape behavior (or an upstream proxy that
// re-encodes) doesn't break the match. Constant-time compare via
// subtle.ConstantTimeCompare to neutralize timing oracles.
func RequireCSRF(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet, http.MethodHead, http.MethodOptions:
			next.ServeHTTP(w, r)
			return
		}
		// Skip CSRF entirely on Bearer-authed requests with NO admin
		// cookie present. The browser-cookie attack surface only opens
		// up when an authenticated cookie is auto-attached; Bearer
		// tokens have to be explicitly read + set by JS, which is the
		// same surface CSRF is trying to gate.
		if _, err := r.Cookie(adminAccessCookie); err != nil {
			if strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") {
				next.ServeHTTP(w, r)
				return
			}
		}
		header := r.Header.Get(csrfHeader)
		c, err := r.Cookie(adminCSRFCookie)
		if err != nil || c.Value == "" || header == "" {
			httperr.WriteError(w, http.StatusForbidden, "CSRF", "csrf token missing")
			return
		}
		// http.Cookie.Value already drops surrounding quotes; some
		// proxies / older browsers send URL-encoded payloads. Try both.
		cookieVal := c.Value
		if decoded, err := url.QueryUnescape(cookieVal); err == nil {
			cookieVal = decoded
		}
		headerVal := header
		if decoded, err := url.QueryUnescape(headerVal); err == nil {
			headerVal = decoded
		}
		if subtle.ConstantTimeCompare([]byte(cookieVal), []byte(headerVal)) != 1 {
			httperr.WriteError(w, http.StatusForbidden, "CSRF", "csrf token mismatch")
			return
		}
		next.ServeHTTP(w, r)
	})
}
