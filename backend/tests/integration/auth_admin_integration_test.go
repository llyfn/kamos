//go:build integration
// +build integration

// Stage 4 — admin cookie auth + CSRF + logout. These tests need
// AuthService wired (the admin-login handler requires h.Services.Auth)
// so they construct a server via newServerWithServices.
package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/handlers"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/server"
)

// newServerWithServices brings up the same chi router as newServer but
// with the service bundle pre-wired so the admin cookie endpoints can
// run end-to-end.
func newServerWithServices(t *testing.T) *httptest.Server {
	t.Helper()
	p := getPool(t)
	cfg := &config.Config{
		AppBaseURL:        "http://localhost",
		JWTSecret:         "integration-secret-please-replace-aaaaaaaaaaaa",
		CursorSecret:      "integration-cursor-secret-please-replace-aaaaaaaaaa",
		JWTTTL:            time.Hour,
		RefreshTTL:        30 * 24 * time.Hour,
		Env:               "test",
		RateLimitDisabled: true,
	}
	cursor.SetSigningKey([]byte(cfg.CursorSecret))
	signer := auth.NewSigner(cfg.JWTSecret, cfg.JWTTTL)
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	repos := repository.New(p)
	google := auth.NewGoogleVerifier("")
	softDelete := auth.NewSoftDeleteCache(p, 30*time.Second, cfg.JWTTTL+time.Hour)
	h := handlers.New(cfg, log, repos, signer, google).
		WithSoftDeleteCache(softDelete).
		EnsureServices()
	mux := server.New(log, signer, softDelete, h)
	return httptest.NewServer(mux)
}

func adminLoginCookies(t *testing.T, srv *httptest.Server, email, password string) []*http.Cookie {
	t.Helper()
	body, _ := json.Marshal(map[string]string{"email": email, "password": password})
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/auth/admin-login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("admin-login: %v", err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("admin-login status=%d body=%s", resp.StatusCode, raw)
	}
	return resp.Cookies()
}

func findCookie(cookies []*http.Cookie, name string) *http.Cookie {
	for _, c := range cookies {
		if c.Name == name {
			return c
		}
	}
	return nil
}

// TestAdminCookieAuth — full happy path: admin-login sets three cookies
// and returns a body with a `user` field; subsequent GET /v1/admin/users
// with the cookies → 200; without cookies → 401.
func TestAdminCookieAuth(t *testing.T) {
	truncateAll(t)
	srv := newServerWithServices(t)
	defer srv.Close()

	const email = "admin@example.com"
	const password = "password-12345"
	_, uid := mustRegister(t, srv, "admin_user", email, password)
	promoteToAdmin(t, uid)

	cookies := adminLoginCookies(t, srv, email, password)
	for _, name := range []string{"kamos_admin_access", "kamos_admin_refresh", "kamos_admin_csrf"} {
		if findCookie(cookies, name) == nil {
			t.Fatalf("missing cookie %s", name)
		}
	}

	// GET /v1/admin/users with cookies attached → 200.
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/v1/admin/users", nil)
	if access := findCookie(cookies, "kamos_admin_access"); access != nil {
		req.AddCookie(access)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("with cookies status=%d, want 200", resp.StatusCode)
	}

	// Without cookies → 401.
	resp2, err := http.Get(srv.URL + "/v1/admin/users")
	if err != nil {
		t.Fatalf("get nocookie: %v", err)
	}
	resp2.Body.Close()
	if resp2.StatusCode != http.StatusUnauthorized {
		t.Fatalf("no cookies status=%d, want 401", resp2.StatusCode)
	}
}

// TestAdminCSRFRejection — POST/PATCH/DELETE on /v1/admin with cookies
// must carry a matching X-CSRF-Token header. Missing → 403; mismatch →
// 403; match → 200 (or 422 / 400 depending on body, but NOT 403).
func TestAdminCSRFRejection(t *testing.T) {
	truncateAll(t)
	srv := newServerWithServices(t)
	defer srv.Close()

	const email = "admin2@example.com"
	const password = "password-12345"
	_, uid := mustRegister(t, srv, "admin_user2", email, password)
	promoteToAdmin(t, uid)
	_, targetUID := mustRegister(t, srv, "target_user", "target@example.com", "password-12345")

	cookies := adminLoginCookies(t, srv, email, password)
	access := findCookie(cookies, "kamos_admin_access")
	csrf := findCookie(cookies, "kamos_admin_csrf")
	if access == nil || csrf == nil {
		t.Fatalf("missing cookies (access=%v csrf=%v)", access != nil, csrf != nil)
	}

	// POST without X-CSRF-Token → 403.
	postPath := "/v1/admin/users/" + targetUID + "/suspend"
	req, _ := http.NewRequest(http.MethodPost, srv.URL+postPath, nil)
	req.AddCookie(access)
	req.AddCookie(csrf)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("post nocsrf: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("missing csrf status=%d, want 403", resp.StatusCode)
	}

	// POST with mismatched X-CSRF-Token → 403.
	req2, _ := http.NewRequest(http.MethodPost, srv.URL+postPath, nil)
	req2.AddCookie(access)
	req2.AddCookie(csrf)
	req2.Header.Set("X-CSRF-Token", "wrong-token")
	resp2, err := http.DefaultClient.Do(req2)
	if err != nil {
		t.Fatalf("post badcsrf: %v", err)
	}
	resp2.Body.Close()
	if resp2.StatusCode != http.StatusForbidden {
		t.Fatalf("mismatched csrf status=%d, want 403", resp2.StatusCode)
	}

	// POST with matching X-CSRF-Token → 204 (suspend returns no content).
	req3, _ := http.NewRequest(http.MethodPost, srv.URL+postPath, nil)
	req3.AddCookie(access)
	req3.AddCookie(csrf)
	req3.Header.Set("X-CSRF-Token", csrf.Value)
	resp3, err := http.DefaultClient.Do(req3)
	if err != nil {
		t.Fatalf("post goodcsrf: %v", err)
	}
	body3, _ := io.ReadAll(resp3.Body)
	resp3.Body.Close()
	if resp3.StatusCode != http.StatusNoContent {
		t.Fatalf("good csrf suspend status=%d body=%s", resp3.StatusCode, body3)
	}
}

// TestAdminLogoutClearsCookies — admin-logout returns 204, emits
// Set-Cookie headers with Max-Age=-1 (effective delete), and revokes
// the refresh token in the DB.
func TestAdminLogoutClearsCookies(t *testing.T) {
	truncateAll(t)
	srv := newServerWithServices(t)
	defer srv.Close()

	const email = "admin3@example.com"
	const password = "password-12345"
	_, uid := mustRegister(t, srv, "admin_user3", email, password)
	promoteToAdmin(t, uid)

	cookies := adminLoginCookies(t, srv, email, password)
	access := findCookie(cookies, "kamos_admin_access")
	refresh := findCookie(cookies, "kamos_admin_refresh")
	csrf := findCookie(cookies, "kamos_admin_csrf")
	if access == nil || refresh == nil || csrf == nil {
		t.Fatalf("login: missing cookies")
	}

	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/auth/admin-logout", nil)
	req.AddCookie(access)
	req.AddCookie(refresh)
	req.AddCookie(csrf)
	req.Header.Set("X-CSRF-Token", csrf.Value)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("logout: %v", err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("logout status=%d body=%s", resp.StatusCode, body)
	}
	// Response cookies should be set with MaxAge=-1 (deletion).
	for _, name := range []string{"kamos_admin_access", "kamos_admin_refresh", "kamos_admin_csrf"} {
		if c := findCookie(resp.Cookies(), name); c == nil || c.MaxAge >= 0 {
			t.Fatalf("logout did not delete cookie %s (got %+v)", name, c)
		}
	}

	// The refresh token row in the DB should have revoked_at set.
	pool := getPool(t)
	var revokedAt *time.Time
	row := pool.QueryRow(context.Background(),
		`SELECT revoked_at FROM refresh_tokens WHERE user_id = $1 ORDER BY issued_at DESC LIMIT 1;`, uid)
	if err := row.Scan(&revokedAt); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if revokedAt == nil {
		t.Fatalf("refresh token was not revoked")
	}
}
