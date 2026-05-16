//go:build integration
// +build integration

// Phase 5a admin endpoints — RBAC + beverage-request moderation +
// check-in moderation + user role / suspension.
package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// promoteToAdmin is the test-only escape hatch — admin promotion happens
// out of band in production. Equivalent to running:
//   UPDATE users SET role = 'admin' WHERE id = $1;
func promoteToAdmin(t *testing.T, userID string) {
	t.Helper()
	if _, err := getPool(t).Exec(context.Background(),
		`UPDATE users SET role = 'admin' WHERE id = $1;`, userID); err != nil {
		t.Fatalf("promote admin: %v", err)
	}
}

func promoteToModerator(t *testing.T, userID string) {
	t.Helper()
	if _, err := getPool(t).Exec(context.Background(),
		`UPDATE users SET role = 'moderator' WHERE id = $1;`, userID); err != nil {
		t.Fatalf("promote moderator: %v", err)
	}
}

// loginAfterRolePromotion re-issues a fresh access token after the role
// has changed. Roles aren't in the JWT claims, so any existing token also
// works — but tests sometimes want a "freshly issued" token.
func loginAfterRolePromotion(t *testing.T, srv *httptest.Server, email, password string) string {
	t.Helper()
	return mustLogin(t, srv, email, password)
}

// TestAdmin_RequiresAuth covers the auth gate (no Bearer → 401).
func TestAdmin_RequiresAuth(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	cases := []struct{ method, path string }{
		{http.MethodGet, "/v1/admin/beverage-requests"},
		{http.MethodGet, "/v1/admin/users"},
		{http.MethodPost, "/v1/admin/beverage-requests/00000000-0000-0000-0000-000000000000/approve"},
		{http.MethodPost, "/v1/admin/users/00000000-0000-0000-0000-000000000000/suspend"},
	}
	for _, c := range cases {
		code, raw := doReq(t, srv, c.method, c.path, "", nil)
		if code != http.StatusUnauthorized {
			t.Errorf("%s %s: %d (want 401) body=%s", c.method, c.path, code, raw)
		}
	}
}

// TestAdmin_RoleGate covers the role gate (regular user → 403 ROLE_REQUIRED).
func TestAdmin_RoleGate(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "regular_user", "reg@example.com", "password-123")

	cases := []struct{ method, path string }{
		{http.MethodGet, "/v1/admin/beverage-requests"},
		{http.MethodGet, "/v1/admin/users"},
	}
	for _, c := range cases {
		code, raw := doReq(t, srv, c.method, c.path, tok, nil)
		if code != http.StatusForbidden {
			t.Errorf("%s %s as user: %d (want 403) body=%s", c.method, c.path, code, raw)
			continue
		}
		var e errBodyShape
		_ = json.Unmarshal(raw, &e)
		if e.Code != "ROLE_REQUIRED" {
			t.Errorf("%s %s code=%q (want ROLE_REQUIRED)", c.method, c.path, e.Code)
		}
	}
}

// TestAdmin_AdminOnlyVsModerator — moderator role hits a moderator-allowed
// endpoint (200), but a moderator-attempting an admin-only endpoint gets 403.
func TestAdmin_AdminOnlyVsModerator(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, uid := mustRegister(t, srv, "mod_user", "mod@example.com", "password-123")
	promoteToModerator(t, uid)

	// Moderator-allowed: GET /v1/admin/beverage-requests — should be 200.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/admin/beverage-requests", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("mod list: %d body=%s", code, raw)
	}

	// Admin-only: suspend another user.
	_, otherUID := mustRegister(t, srv, "target_user", "tgt@example.com", "password-123")
	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/users/"+otherUID+"/suspend", tok, nil)
	if code != http.StatusForbidden {
		t.Errorf("mod suspend (admin-only): %d body=%s (want 403)", code, raw)
	}
}

// TestAdmin_ApproveBeverageRequest covers the full approval cycle:
// user submits a payload → admin approves with canonical fields → beverage
// appears in the catalog.
func TestAdmin_ApproveBeverageRequest(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// One regular user submits a request.
	userTok, _ := mustRegister(t, srv, "submitter", "sub@example.com", "password-123")
	submitBody := map[string]any{
		"payload": map[string]any{
			"name_en":      "Test Junmai",
			"name_ja":      "テスト純米",
			"brewery_name": "Test Brewery",
			"abv":          15.5,
		},
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/beverage-requests", userTok, submitBody)
	if code != http.StatusAccepted {
		t.Fatalf("submit: %d body=%s", code, raw)
	}
	var submit map[string]string
	_ = json.Unmarshal(raw, &submit)
	requestID := submit["id"]
	if requestID == "" {
		t.Fatalf("no request id in submit response: %s", raw)
	}

	// An admin reviews + approves it, supplying the canonical fields.
	adminTok, adminID := mustRegister(t, srv, "admin_user", "adm@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// We need a brewery_id and category_id — seed them.
	pool := getPool(t)
	var breweryID, categoryID string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO breweries (name_i18n)
		   VALUES ($1::jsonb)
		   RETURNING id;`,
		`{"en":"Approval Brewery","ja":"承認酒造"}`).Scan(&breweryID); err != nil {
		t.Fatalf("seed brewery: %v", err)
	}
	if err := pool.QueryRow(context.Background(),
		`SELECT id FROM beverage_categories WHERE slug = 'nihonshu';`).Scan(&categoryID); err != nil {
		t.Fatalf("look up category: %v", err)
	}

	approveBody := map[string]any{
		"brewery_id":  breweryID,
		"category_id": categoryID,
		"name_i18n":   map[string]string{"en": "Test Junmai", "ja": "テスト純米"},
		"abv":         15.5,
		"notes":       "approved during smoke test",
	}
	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/admin/beverage-requests/"+requestID+"/approve", adminTok, approveBody)
	if code != http.StatusOK {
		t.Fatalf("approve: %d body=%s", code, raw)
	}
	var approval map[string]string
	_ = json.Unmarshal(raw, &approval)
	if approval["beverage_id"] == "" {
		t.Fatalf("approve missing beverage_id: %s", raw)
	}

	// Beverage must now exist in the catalog.
	var name string
	if err := pool.QueryRow(context.Background(),
		`SELECT name_i18n->>'en' FROM beverages WHERE id = $1;`,
		approval["beverage_id"]).Scan(&name); err != nil {
		t.Fatalf("beverage lookup: %v", err)
	}
	if name != "Test Junmai" {
		t.Errorf("beverage name: %q", name)
	}

	// Status of the original request must be 'approved'.
	var status string
	if err := pool.QueryRow(context.Background(),
		`SELECT status FROM beverage_addition_requests WHERE id = $1;`,
		requestID).Scan(&status); err != nil {
		t.Fatalf("request status: %v", err)
	}
	if status != "approved" {
		t.Errorf("request status: %q", status)
	}

	// Approving twice must 409 (already approved).
	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/admin/beverage-requests/"+requestID+"/approve", adminTok, approveBody)
	if code != http.StatusConflict {
		t.Errorf("double-approve: %d body=%s (want 409)", code, raw)
	}
}

// TestAdmin_RejectBeverageRequest — moderator rejects with notes.
func TestAdmin_RejectBeverageRequest(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	userTok, _ := mustRegister(t, srv, "rej_submitter", "rs@example.com", "password-123")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/beverage-requests", userTok, map[string]any{
		"payload": map[string]any{"name_en": "Bad Submission"},
	})
	if code != http.StatusAccepted {
		t.Fatalf("submit: %d body=%s", code, raw)
	}
	var submit map[string]string
	_ = json.Unmarshal(raw, &submit)
	requestID := submit["id"]

	modTok, modID := mustRegister(t, srv, "rej_mod", "rmod@example.com", "password-123")
	promoteToModerator(t, modID)

	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/admin/beverage-requests/"+requestID+"/reject", modTok, map[string]any{
			"notes": "duplicate of existing beverage",
		})
	if code != http.StatusOK {
		t.Fatalf("reject: %d body=%s", code, raw)
	}
	var body map[string]string
	_ = json.Unmarshal(raw, &body)
	if body["status"] != "rejected" || body["notes"] != "duplicate of existing beverage" {
		t.Errorf("reject body: %s", raw)
	}

	// Rejection should not allow approval afterward.
	code, _ = doReq(t, srv, http.MethodPost,
		"/v1/admin/beverage-requests/"+requestID+"/approve", modTok, map[string]any{
			"brewery_id":  "00000000-0000-0000-0000-000000000000",
			"category_id": "00000000-0000-0000-0000-000000000000",
			"name_i18n":   map[string]string{"en": "x", "ja": "x"},
		})
	// Moderator can't approve at all — 403 fires before status check.
	if code != http.StatusForbidden {
		t.Errorf("mod approve: %d (want 403)", code)
	}
}

// TestAdmin_ModerateCheckin — admin soft-deletes a check-in created by
// another user.
func TestAdmin_ModerateCheckin(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Moderation Sake")
	userTok, _ := mustRegister(t, srv, "checkin_user", "ck@example.com", "password-123")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", userTok, map[string]any{
		"beverage_id": bevID,
		"rating":      4.0,
		"review":      "needs moderation",
	})
	if code != http.StatusCreated {
		t.Fatalf("create check-in: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	checkinID, _ := ci["id"].(string)
	if checkinID == "" {
		t.Fatalf("missing check-in id: %s", raw)
	}

	adminTok, adminID := mustRegister(t, srv, "mod_admin", "mad@example.com", "password-123")
	promoteToAdmin(t, adminID)

	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/admin/check-ins/"+checkinID+"/moderate", adminTok, map[string]any{
			"notes": "rule violation",
		})
	if code != http.StatusNoContent {
		t.Fatalf("moderate: %d body=%s", code, raw)
	}

	// The check-in must be soft-deleted now.
	var deletedAt *string
	if err := getPool(t).QueryRow(context.Background(),
		`SELECT deleted_at::text FROM check_ins WHERE id = $1;`,
		checkinID).Scan(&deletedAt); err != nil {
		t.Fatalf("query deleted_at: %v", err)
	}
	if deletedAt == nil {
		t.Errorf("check-in not soft-deleted")
	}

	// Idempotent: re-moderating an already-deleted check-in is 404.
	code, _ = doReq(t, srv, http.MethodPost,
		"/v1/admin/check-ins/"+checkinID+"/moderate", adminTok, nil)
	if code != http.StatusNotFound {
		t.Errorf("re-moderate: %d (want 404)", code)
	}
}

// TestAdmin_ListUsers — moderator-or-admin can list users; role filter +
// soft-delete inclusion work.
func TestAdmin_ListUsers(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	mustRegister(t, srv, "user_a", "a@example.com", "password-123")
	mustRegister(t, srv, "user_b", "b@example.com", "password-123")
	tok, modID := mustRegister(t, srv, "list_mod", "lm@example.com", "password-123")
	promoteToModerator(t, modID)

	code, raw := doReq(t, srv, http.MethodGet, "/v1/admin/users", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	var page struct {
		Items   []map[string]any `json:"items"`
		HasMore bool             `json:"has_more"`
	}
	if err := json.Unmarshal(raw, &page); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(page.Items) != 3 {
		t.Errorf("items: %d (want 3 including the mod)", len(page.Items))
	}

	// Role filter — mod should be the only `moderator`.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/users?role=moderator", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("list mod-only: %d body=%s", code, raw)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Errorf("filter mod: %d items (want 1)", len(page.Items))
	}
}

// TestAdmin_UpdateUserRole — admin promotes a regular user; the demotion-
// self guard 403s self-demotion.
func TestAdmin_UpdateUserRole(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, targetID := mustRegister(t, srv, "target_role", "tr@example.com", "password-123")
	adminTok, adminID := mustRegister(t, srv, "role_admin", "ra@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Promote target to moderator.
	code, raw := doReq(t, srv, http.MethodPost,
		"/v1/admin/users/"+targetID+"/role", adminTok, map[string]any{"role": "moderator"})
	if code != http.StatusOK {
		t.Fatalf("promote: %d body=%s", code, raw)
	}

	// Self-demotion blocked.
	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/admin/users/"+adminID+"/role", adminTok, map[string]any{"role": "user"})
	if code != http.StatusForbidden {
		t.Errorf("self-demote: %d (want 403) body=%s", code, raw)
	}

	// Invalid role → 422.
	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/admin/users/"+targetID+"/role", adminTok, map[string]any{"role": "supreme"})
	if code != http.StatusUnprocessableEntity {
		t.Errorf("bad role: %d (want 422) body=%s", code, raw)
	}
}

// TestMeIncludesRole — GET /v1/users/me must include role + deleted_at so
// the admin Flutter client can decide whether to show admin UI.
func TestMeIncludesRole(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, uid := mustRegister(t, srv, "me_role", "mr@example.com", "password-123")

	// Fresh user: role should be "user", deleted_at null.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/me", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("/me: %d body=%s", code, raw)
	}
	var me map[string]any
	if err := json.Unmarshal(raw, &me); err != nil {
		t.Fatalf("decode /me: %v", err)
	}
	if me["role"] != "user" {
		t.Errorf("default role: %v (want \"user\")", me["role"])
	}
	if me["deleted_at"] != nil {
		t.Errorf("deleted_at on fresh user: %v (want nil)", me["deleted_at"])
	}

	// Promote and verify the field flips immediately on the next request —
	// the role is read from users.role on every /me request, not cached.
	promoteToAdmin(t, uid)
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/me", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("/me after promotion: %d", code)
	}
	_ = json.Unmarshal(raw, &me)
	if me["role"] != "admin" {
		t.Errorf("post-promotion role: %v (want \"admin\")", me["role"])
	}
}

// TestAdmin_SuspendUserRevokesTokens — admin suspends a user; the user's
// JWT is revoked via the SoftDeleteCache (same SEC-006 path as DeleteMe).
func TestAdmin_SuspendUserRevokesTokens(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	victimTok, victimID := mustRegister(t, srv, "victim_user", "v@example.com", "password-123")
	adminTok, adminID := mustRegister(t, srv, "susp_admin", "sa@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Victim's token works.
	if code, _ := doReq(t, srv, http.MethodGet, "/v1/users/me", victimTok, nil); code != http.StatusOK {
		t.Fatalf("pre-suspend /me: %d", code)
	}

	code, raw := doReq(t, srv, http.MethodPost,
		"/v1/admin/users/"+victimID+"/suspend", adminTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("suspend: %d body=%s", code, raw)
	}

	// Victim's token is now revoked.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/me", victimTok, nil)
	if code != http.StatusUnauthorized {
		t.Errorf("post-suspend /me: %d body=%s (want 401)", code, raw)
	}
	var e errBodyShape
	_ = json.Unmarshal(raw, &e)
	if e.Code != "ACCOUNT_DELETED" {
		t.Errorf("post-suspend code: %q (want ACCOUNT_DELETED)", e.Code)
	}

	// Admin cannot suspend self.
	code, _ = doReq(t, srv, http.MethodPost,
		"/v1/admin/users/"+adminID+"/suspend", adminTok, nil)
	if code != http.StatusForbidden {
		t.Errorf("admin self-suspend: %d (want 403)", code)
	}
}
