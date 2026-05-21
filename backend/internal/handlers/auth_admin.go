// auth_admin.go — Stage 4 admin cookie auth.
//
// Three endpoints layered on top of the existing AuthService:
//
//	POST /v1/auth/admin-login   — email+password sign-in; role-gated;
//	                              sets three cookies (access + refresh + csrf).
//	POST /v1/auth/admin-refresh — reads kamos_admin_refresh cookie, rotates
//	                              the refresh token, sets fresh cookies.
//	POST /v1/auth/admin-logout  — revokes the current refresh token and
//	                              clears all three cookies.
//
// Cookie shape:
//
//	kamos_admin_access  HttpOnly, Secure, SameSite=Strict,
//	                    Path=/v1/admin, Max-Age=JWTTTL.
//	                    Value = access JWT.
//	kamos_admin_refresh HttpOnly, Secure, SameSite=Strict,
//	                    Path=/v1/auth/admin-refresh, Max-Age=RefreshTTL.
//	                    Value = raw refresh secret (the hash is stored).
//	kamos_admin_csrf    NOT HttpOnly (JS reads it), Secure, SameSite=Strict,
//	                    Path=/, Max-Age=JWTTTL.
//	                    Value = random 32-byte base64; double-submit pattern.
//
// Secure cookies are gated on `cfg.Env == "production"` OR
// `FORCE_SECURE_COOKIES=1` so dev (http://localhost) can sign in without
// HTTPS. The CSRF cookie's SameSite=Strict belt + the X-CSRF-Token header
// double-submit are the two redundant defenses against CSRF.
package handlers

import (
	"errors"
	"net/http"
	"os"
	"time"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

const (
	adminAccessCookie  = "kamos_admin_access"
	adminRefreshCookie = "kamos_admin_refresh"
	adminCSRFCookie    = "kamos_admin_csrf"

	adminAccessPath  = "/v1/admin"
	adminRefreshPath = "/v1/auth/admin-refresh"
	adminCSRFPath    = "/"
)

// AdminLogin — POST /v1/auth/admin-login.
//
// Validates credentials via AuthService.Login (same email+password +
// timing-safe path as the mobile login), then role-gates: only
// moderator + admin may sign in here. Successful login returns 200 with
// `{ "user": <Me> }` and sets the three cookies above. On failure: 401
// INVALID_CREDENTIAL or 403 ROLE_REQUIRED.
func (h *Handler) AdminLogin(w http.ResponseWriter, r *http.Request) {
	if h.Services == nil || h.Services.Auth == nil {
		httperr.WriteError(w, http.StatusServiceUnavailable, "UNAVAILABLE", "auth service not configured")
		return
	}
	var req domain.LoginRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "AdminLogin decode", err)
		return
	}
	if err := req.Validate(); err != nil {
		h.writeErr(w, "AdminLogin validate", err)
		return
	}
	res, err := h.Services.Auth.Login(r.Context(), req)
	if err != nil {
		if errors.Is(err, domain.ErrInvalidCredential) {
			httperr.WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
			return
		}
		h.writeErr(w, "AdminLogin", err)
		return
	}
	// Role-gate: only moderator + admin may use the admin cookie surface.
	me, err := h.Repos.Users.FindMe(r.Context(), res.User.ID)
	if err != nil {
		h.writeErr(w, "AdminLogin find me", err)
		return
	}
	if me.Role != domain.RoleAdmin && me.Role != domain.RoleModerator {
		// Best-effort: revoke the refresh we just issued so it can't be
		// scraped from the response body and reused on the mobile API.
		_ = h.Services.Auth.Logout(r.Context(), res.User.ID, res.RefreshToken)
		httperr.WriteError(w, http.StatusForbidden, "ROLE_REQUIRED", "admin or moderator role required")
		return
	}
	stats, err := h.Repos.Users.Stats(r.Context(), res.User.ID)
	if err != nil {
		h.writeErr(w, "AdminLogin stats", err)
		return
	}
	csrf, err := randomToken(32)
	if err != nil {
		h.writeErr(w, "AdminLogin csrf", err)
		return
	}
	h.setAdminCookies(w, res.AccessToken, res.RefreshToken, csrf)
	httperr.WriteJSON(w, http.StatusOK, map[string]any{
		"user": domain.Me{
			User:      me.User,
			Stats:     stats,
			Role:      me.Role,
			DeletedAt: me.DeletedAt,
		},
	})
}

// AdminRefresh — POST /v1/auth/admin-refresh.
//
// Reads kamos_admin_refresh cookie, rotates atomically via
// AuthService.RotateRefresh, and replaces all three cookies. Returns 204.
// Mismatched / missing / expired refresh → 401 TOKEN_INVALID +
// cookies cleared.
func (h *Handler) AdminRefresh(w http.ResponseWriter, r *http.Request) {
	if h.Services == nil || h.Services.Auth == nil {
		httperr.WriteError(w, http.StatusServiceUnavailable, "UNAVAILABLE", "auth service not configured")
		return
	}
	c, err := r.Cookie(adminRefreshCookie)
	if err != nil || c.Value == "" {
		httperr.WriteError(w, http.StatusUnauthorized, "TOKEN_INVALID", "missing refresh cookie")
		return
	}
	res, err := h.Services.Auth.RotateRefresh(r.Context(), c.Value)
	if err != nil {
		if errors.Is(err, domain.ErrInvalidCredential) ||
			errors.Is(err, domain.ErrTokenExpired) ||
			errors.Is(err, domain.ErrNotFound) {
			h.clearAdminCookies(w)
			httperr.WriteError(w, http.StatusUnauthorized, "TOKEN_INVALID", "invalid refresh cookie")
			return
		}
		h.writeErr(w, "AdminRefresh", err)
		return
	}
	csrf, err := randomToken(32)
	if err != nil {
		h.writeErr(w, "AdminRefresh csrf", err)
		return
	}
	h.setAdminCookies(w, res.AccessToken, res.RefreshToken, csrf)
	w.WriteHeader(http.StatusNoContent)
}

// AdminLogout — POST /v1/auth/admin-logout (AdminAuth).
//
// Revokes the current refresh token (if presented as a cookie) and
// clears all three cookies. Always returns 204.
func (h *Handler) AdminLogout(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	raw := ""
	if c, err := r.Cookie(adminRefreshCookie); err == nil {
		raw = c.Value
	}
	if h.Services != nil && h.Services.Auth != nil {
		_ = h.Services.Auth.Logout(r.Context(), uid, raw)
	} else {
		// Legacy fallback (tests that don't construct services).
		if raw != "" {
			hash := auth.HashRefreshToken(raw)
			if row, err := h.Repos.RefreshTokens.LookupByHash(r.Context(), hash); err == nil {
				if row.UserID == uid {
					_ = h.Repos.RefreshTokens.MarkRevoked(r.Context(), row.ID)
				}
			}
		}
	}
	h.clearAdminCookies(w)
	w.WriteHeader(http.StatusNoContent)
}

// setAdminCookies writes the three Set-Cookie headers. Secure is gated
// on production or FORCE_SECURE_COOKIES=1 so dev (http://localhost)
// works.
func (h *Handler) setAdminCookies(w http.ResponseWriter, access, refresh, csrf string) {
	secure := h.adminCookieSecure()
	accessTTL := int(h.Cfg.JWTTTL.Seconds())
	refreshTTL := int(h.refreshTTL().Seconds())
	http.SetCookie(w, &http.Cookie{
		Name:     adminAccessCookie,
		Value:    access,
		Path:     adminAccessPath,
		HttpOnly: true,
		Secure:   secure,
		SameSite: http.SameSiteStrictMode,
		MaxAge:   accessTTL,
	})
	http.SetCookie(w, &http.Cookie{
		Name:     adminRefreshCookie,
		Value:    refresh,
		Path:     adminRefreshPath,
		HttpOnly: true,
		Secure:   secure,
		SameSite: http.SameSiteStrictMode,
		MaxAge:   refreshTTL,
	})
	http.SetCookie(w, &http.Cookie{
		Name:     adminCSRFCookie,
		Value:    csrf,
		Path:     adminCSRFPath,
		HttpOnly: false,
		Secure:   secure,
		SameSite: http.SameSiteStrictMode,
		MaxAge:   accessTTL,
	})
}

// clearAdminCookies emits Set-Cookie with Max-Age=0 for each admin
// cookie, matching the original Path so the browser drops them.
func (h *Handler) clearAdminCookies(w http.ResponseWriter) {
	secure := h.adminCookieSecure()
	expired := time.Unix(0, 0)
	for _, c := range []*http.Cookie{
		{Name: adminAccessCookie, Path: adminAccessPath, HttpOnly: true},
		{Name: adminRefreshCookie, Path: adminRefreshPath, HttpOnly: true},
		{Name: adminCSRFCookie, Path: adminCSRFPath, HttpOnly: false},
	} {
		c.Value = ""
		c.MaxAge = -1
		c.Expires = expired
		c.Secure = secure
		c.SameSite = http.SameSiteStrictMode
		http.SetCookie(w, c)
	}
}

// adminCookieSecure returns true when the Secure cookie attribute should
// be set. Production always; dev only when FORCE_SECURE_COOKIES=1.
func (h *Handler) adminCookieSecure() bool {
	if h.Cfg != nil && h.Cfg.Env == "production" {
		return true
	}
	return os.Getenv("FORCE_SECURE_COOKIES") == "1"
}

// refreshTTL is defined in auth_account.go for the mobile path; the
// admin endpoints reuse it.
//
// (Left here as a documentation pointer — no implementation needed.)
