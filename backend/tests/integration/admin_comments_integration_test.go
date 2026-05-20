//go:build integration
// +build integration

// Phase 6a — admin comment moderation surface.
package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

// TestAdminModerateComment_AdminPath — admin soft-deletes someone else's
// comment via the explicit admin endpoint, moderation_log row is written.
func TestAdminModerateComment_AdminPath(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "AdminMod Sake")
	authorTok, _ := mustRegister(t, srv, "amod_author", "amoda@example.com", "password-123")
	adminTok, adminID := mustRegister(t, srv, "amod_admin", "amodadmin@example.com", "password-123")
	promoteToAdmin(t, adminID)
	ckID := createCheckin(t, srv, authorTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
		map[string]any{"body": "to be removed by admin"})
	if code != http.StatusCreated {
		t.Fatalf("create comment: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	commentID, _ := posted["id"].(string)

	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/comments/"+commentID+"/moderate", adminTok,
		map[string]any{"notes": "harassment"})
	if code != http.StatusNoContent {
		t.Fatalf("moderate: %d body=%s", code, raw)
	}

	var notes *string
	if err := getPool(t).QueryRow(context.Background(), `
SELECT notes FROM moderation_log
WHERE target_type = 'comment' AND target_id = $1;`,
		commentID).Scan(&notes); err != nil {
		t.Fatalf("log query: %v", err)
	}
	if notes == nil || *notes != "harassment" {
		t.Errorf("moderation_log notes=%v", notes)
	}
}

// TestAdminModerateComment_ModeratorPath — moderator (lower role) can
// also moderate per the RequireAnyRole(admin, moderator) gate.
func TestAdminModerateComment_ModeratorPath(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "ModMod Sake")
	authorTok, _ := mustRegister(t, srv, "mmod_author", "mmoda@example.com", "password-123")
	modTok, modID := mustRegister(t, srv, "mmod_mod", "mmodadmin@example.com", "password-123")
	promoteToModerator(t, modID)
	ckID := createCheckin(t, srv, authorTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
		map[string]any{"body": "moderator will remove this"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	commentID, _ := posted["id"].(string)

	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/comments/"+commentID+"/moderate", modTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("mod moderate: %d body=%s", code, raw)
	}
}

// TestAdminModerateComment_RegularUserForbidden — non-admin/moderator
// gets 403 ROLE_REQUIRED.
func TestAdminModerateComment_RegularUserForbidden(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "RegForbid Sake")
	authorTok, _ := mustRegister(t, srv, "rf_author", "rfa@example.com", "password-123")
	regTok, _ := mustRegister(t, srv, "rf_reg", "rfreg@example.com", "password-123")
	ckID := createCheckin(t, srv, authorTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
		map[string]any{"body": "regular user can't moderate this"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	commentID, _ := posted["id"].(string)

	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/comments/"+commentID+"/moderate", regTok, nil)
	if code != http.StatusForbidden {
		t.Errorf("regular user moderate: %d body=%s (want 403)", code, raw)
	}
}

// TestAdminListComments — admin lists visible / deleted comments with
// moderation metadata joined in.
func TestAdminListComments(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "AdminList Sake")
	authorTok, _ := mustRegister(t, srv, "al_author", "ala@example.com", "password-123")
	adminTok, adminID := mustRegister(t, srv, "al_admin", "aladm@example.com", "password-123")
	promoteToAdmin(t, adminID)
	ckID := createCheckin(t, srv, authorTok, bevID)

	// Three comments.
	commentIDs := []string{}
	for i, body := range []string{"first", "second", "third"} {
		code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
			map[string]any{"body": body})
		if code != http.StatusCreated {
			t.Fatalf("create %d: %d body=%s", i, code, raw)
		}
		var p map[string]any
		_ = json.Unmarshal(raw, &p)
		commentIDs = append(commentIDs, p["id"].(string))
	}

	// Soft-delete the middle one via admin endpoint.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/comments/"+commentIDs[1]+"/moderate", adminTok,
		map[string]any{"notes": "test moderation"})
	if code != http.StatusNoContent {
		t.Fatalf("moderate: %d body=%s", code, raw)
	}

	// status=visible (default): 2 rows.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/comments", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("list visible: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 3 {
		t.Errorf("visible page items: %d (want 3 — visible+deleted in default view)", len(page.Items))
	}

	// status=deleted: only the middle one. The join surfaces the notes.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/comments?status=deleted", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("list deleted: %d body=%s", code, raw)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Fatalf("deleted page items: %d (want 1)", len(page.Items))
	}
	notes, _ := page.Items[0]["moderation_notes"].(string)
	if notes != "test moderation" {
		t.Errorf("moderation_notes=%q (want \"test moderation\")", notes)
	}
}

// TestAdminListComments_InvalidStatus — 422 on a bogus status filter.
func TestAdminListComments_InvalidStatus(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "alis_admin", "alisadm@example.com", "password-123")
	promoteToAdmin(t, adminID)

	code, raw := doReq(t, srv, http.MethodGet, "/v1/admin/comments?status=banana", adminTok, nil)
	if code != http.StatusUnprocessableEntity {
		t.Errorf("bad status: %d body=%s (want 422)", code, raw)
	}
}
