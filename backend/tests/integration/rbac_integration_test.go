//go:build integration
// +build integration

// Phase 8 (M-5.3) — central RBAC default-deny matrix.
//
// Every admin endpoint mounted under /v1/admin/* MUST require either
// `moderator` or `admin` role. The existing TestAdmin_RoleGate covers
// a sample; this matrix walks every admin route the router currently
// declares, so a future PR that mounts a new admin endpoint without
// `RequireRole` fails CI rather than shipping with an open default.
//
// The route list is hand-maintained — chi exposes a Walk API but the
// surface is small enough that a literal list is easier to grep for
// regressions. Update this list when adding or removing admin routes.

package integration

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

// adminRoute is one admin endpoint we expect to be role-gated. The
// {id} segments are filled with a dummy zero UUID; we never reach the
// handler body (the role gate fires first), so the path's tail can be
// anything route-shaped.
type adminRoute struct {
	method string
	path   string
}

// adminRoutes mirrors backend/internal/server/router.go's /v1/admin
// subtree. Add a row whenever a new admin endpoint is registered.
//
// Mod-or-admin and admin-only endpoints both fail with 403 for a
// `role=user` JWT, so the test does not need to distinguish.
var adminRoutes = []adminRoute{
	// moderator-or-admin
	{http.MethodGet, "/v1/admin/beverage-requests"},
	{http.MethodPost, "/v1/admin/beverage-requests/00000000-0000-0000-0000-000000000000/reject"},
	{http.MethodPost, "/v1/admin/check-ins/00000000-0000-0000-0000-000000000000/moderate"},
	{http.MethodGet, "/v1/admin/users"},
	{http.MethodGet, "/v1/admin/moderation-log"},
	{http.MethodGet, "/v1/admin/comments"},
	{http.MethodPost, "/v1/admin/comments/00000000-0000-0000-0000-000000000000/moderate"},
	// admin-only
	{http.MethodPost, "/v1/admin/beverage-requests/00000000-0000-0000-0000-000000000000/approve"},
	{http.MethodPost, "/v1/admin/users/00000000-0000-0000-0000-000000000000/suspend"},
	{http.MethodPost, "/v1/admin/users/00000000-0000-0000-0000-000000000000/role"},
}

// TestRBACDefaultDeny asserts every admin route in `adminRoutes` rejects
// a `role=user` JWT with 403 ROLE_REQUIRED. A non-403 response signals
// the route is missing its `RequireRole` middleware — a fail-open
// regression.
func TestRBACDefaultDeny(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "rbac_default_deny", "rbac@example.com", "password-123")

	for _, r := range adminRoutes {
		t.Run(r.method+"_"+r.path, func(t *testing.T) {
			// POST routes are guarded by CSRF before the role check fires,
			// but mutating requests without the cookie auth still trip
			// CSRF first (return 403 with CSRF_REQUIRED). The Bearer-token
			// compat path skips CSRF, so the role gate is what answers
			// for our `Authorization: Bearer` test client.
			body := emptyBodyFor(r.method, r.path)
			code, raw := doReq(t, srv, r.method, r.path, tok, body)
			if code != http.StatusForbidden {
				t.Fatalf("%s %s: got %d want 403, body=%s", r.method, r.path, code, raw)
			}
			var e errBodyShape
			_ = json.Unmarshal(raw, &e)
			if e.Code != "ROLE_REQUIRED" {
				t.Errorf("%s %s: code=%q want ROLE_REQUIRED (body=%s)",
					r.method, r.path, e.Code, raw)
			}
		})
	}
}

// emptyBodyFor returns the smallest JSON body that won't trip schema
// validation before the role gate runs. For POSTs that require a body
// (reject + role) we pass a token-shaped value; the request never gets
// past the role check anyway, so the body's content is immaterial.
func emptyBodyFor(method, path string) any {
	if method == http.MethodGet || method == http.MethodDelete {
		return nil
	}
	// Mutating routes — minimal body keeps the JSON decoder happy.
	switch {
	case strings.HasSuffix(path, "/reject"):
		return map[string]any{"notes": "rbac default-deny test"}
	case strings.HasSuffix(path, "/role"):
		return map[string]any{"role": "user"}
	default:
		return map[string]any{}
	}
}
