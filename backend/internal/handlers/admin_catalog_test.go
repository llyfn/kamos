// External-package tests for the Stage 8 admin catalog HTTP boundary.
// Internal-package unit tests for the request validators live in
// admin_catalog_internal_test.go (so they can call the package-private
// AdminBeverageCreate.Validate etc. directly without a server).
//
// These tests exercise only what fires BEFORE any DB access — the auth
// gate. Role-gated and CSRF-gated paths need a DB-backed user.role
// lookup, which lives in the integration suite.
package handlers_test

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// adminCatalogRoutes is the table of admin catalog endpoints we care
// about for the auth gate.
var adminCatalogRoutes = []struct {
	method, path string
}{
	{http.MethodGet, "/v1/admin/beverages"},
	{http.MethodGet, "/v1/admin/beverages/00000000-0000-0000-0000-000000000000"},
	{http.MethodPost, "/v1/admin/beverages"},
	{http.MethodPatch, "/v1/admin/beverages/00000000-0000-0000-0000-000000000000"},
	{http.MethodDelete, "/v1/admin/beverages/00000000-0000-0000-0000-000000000000"},
	{http.MethodPost, "/v1/admin/beverages/00000000-0000-0000-0000-000000000000/restore"},
	{http.MethodGet, "/v1/admin/breweries"},
	{http.MethodGet, "/v1/admin/breweries/00000000-0000-0000-0000-000000000000"},
	{http.MethodPost, "/v1/admin/breweries"},
	{http.MethodPatch, "/v1/admin/breweries/00000000-0000-0000-0000-000000000000"},
	{http.MethodDelete, "/v1/admin/breweries/00000000-0000-0000-0000-000000000000"},
	{http.MethodPost, "/v1/admin/breweries/00000000-0000-0000-0000-000000000000/restore"},
}

// TestAdminCatalogRequiresAuth — every admin catalog route returns 401
// when called without a Bearer token. The auth middleware fires before
// any role check.
func TestAdminCatalogRequiresAuth(t *testing.T) {
	srv, _ := newTestServer(t)
	for _, route := range adminCatalogRoutes {
		route := route
		t.Run(route.method+" "+route.path, func(t *testing.T) {
			rr := httptest.NewRecorder()
			req := httptest.NewRequest(route.method, route.path, nil)
			srv.ServeHTTP(rr, req)
			if rr.Code != http.StatusUnauthorized {
				t.Fatalf("status: %d body=%s", rr.Code, rr.Body.String())
			}
			body := decodeErrBody(t, rr.Body)
			if body.Code != "UNAUTHORIZED" {
				t.Errorf("code: %q want UNAUTHORIZED", body.Code)
			}
		})
	}
}
