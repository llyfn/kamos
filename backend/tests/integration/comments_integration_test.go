//go:build integration
// +build integration

// Phase 6a — flat comments on check-ins.
package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// createCheckin POSTs /v1/check-ins for the given user and returns the new
// check-in id.
func createCheckin(t *testing.T, srv *httptest.Server, tok, bevID string) string {
	t.Helper()
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"rating":      4.0,
	})
	if code != http.StatusCreated {
		t.Fatalf("create check-in: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	id, _ := ci["id"].(string)
	if id == "" {
		t.Fatalf("missing check-in id: %s", raw)
	}
	return id
}

// TestCreateAndListComments — happy path: alice creates a check-in, bob
// comments, the comment appears in the list with bob's slim user shape.
func TestCreateAndListComments(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Comment Sake")
	aliceTok, _ := mustRegister(t, srv, "alice_c", "ac@example.com", "password-123")
	bobTok, _ := mustRegister(t, srv, "bob_c", "bc@example.com", "password-123")
	ckID := createCheckin(t, srv, aliceTok, bevID)

	// Bob comments.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", bobTok,
		map[string]any{"body": "Tried this last night, loved it."})
	if code != http.StatusCreated {
		t.Fatalf("create comment: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	if posted["check_in_id"] != ckID {
		t.Errorf("check_in_id=%v want %s", posted["check_in_id"], ckID)
	}
	u, _ := posted["user"].(map[string]any)
	if u["username"] != "bob_c" {
		t.Errorf("user.username=%v want bob_c", u["username"])
	}
	if _, hasEmail := u["email"]; hasEmail {
		t.Errorf("user payload leaked email: %s", raw)
	}

	// Anonymous can list comments.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			ID   string `json:"id"`
			Body string `json:"body"`
		} `json:"items"`
		HasMore bool `json:"has_more"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Fatalf("expected 1 comment, got %d: %s", len(page.Items), raw)
	}
	if page.Items[0].Body != "Tried this last night, loved it." {
		t.Errorf("body=%q", page.Items[0].Body)
	}
}

// TestCommentBodyValidation_LengthAndControlChars — table-driven check.
func TestCommentBodyValidation_LengthAndControlChars(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Validation Sake")
	tok, _ := mustRegister(t, srv, "valid_u", "vu@example.com", "password-123")
	ckID := createCheckin(t, srv, tok, bevID)

	cases := []struct {
		name     string
		body     string
		wantCode int
	}{
		{"empty", "", http.StatusUnprocessableEntity},
		{"only_whitespace", "   ", http.StatusUnprocessableEntity},
		{"too_long", strings.Repeat("x", 501), http.StatusUnprocessableEntity},
		{"control_char", "hello\x07world", http.StatusUnprocessableEntity},
		{"nul_byte", "hello\x00world", http.StatusUnprocessableEntity},
		{"valid_500", strings.Repeat("a", 500), http.StatusCreated},
		{"valid_unicode", "Tasted great. 美味しい! 맛있어요!", http.StatusCreated},
		{"valid_with_newline_and_tab", "line one\n\tline two", http.StatusCreated},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", tok,
				map[string]any{"body": c.body})
			if code != c.wantCode {
				t.Errorf("body=%q: code=%d (want %d) body=%s", c.body, code, c.wantCode, raw)
			}
		})
	}
}

// TestDeleteOwnComment — owner can soft-delete.
func TestDeleteOwnComment(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Delete Sake")
	tok, _ := mustRegister(t, srv, "del_owner", "do@example.com", "password-123")
	ckID := createCheckin(t, srv, tok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", tok,
		map[string]any{"body": "self-comment"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	commentID, _ := posted["id"].(string)

	code, raw = doReq(t, srv, http.MethodDelete, "/v1/comments/"+commentID, tok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d body=%s", code, raw)
	}

	// List now empty.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d", code)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 0 {
		t.Errorf("expected 0 comments, got %d: %s", len(page.Items), raw)
	}
}

// TestDeleteOthersComment_ForbiddenForNonAdmin — non-admin cannot soft-delete
// someone else's comment.
func TestDeleteOthersComment_ForbiddenForNonAdmin(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Hostile Sake")
	aTok, _ := mustRegister(t, srv, "victim_c", "vc@example.com", "password-123")
	bTok, _ := mustRegister(t, srv, "attacker_c", "atc@example.com", "password-123")
	ckID := createCheckin(t, srv, aTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", aTok,
		map[string]any{"body": "my comment"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	commentID, _ := posted["id"].(string)

	code, raw = doReq(t, srv, http.MethodDelete, "/v1/comments/"+commentID, bTok, nil)
	if code != http.StatusForbidden {
		t.Errorf("non-admin delete: %d body=%s (want 403)", code, raw)
	}
}

// TestDeleteOthersComment_AllowedForAdmin — admin can soft-delete +
// moderation_log row is written.
func TestDeleteOthersComment_AllowedForAdmin(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Mod Sake")
	userTok, _ := mustRegister(t, srv, "uvictim", "uvictim@example.com", "password-123")
	adminTok, adminID := mustRegister(t, srv, "comment_admin", "ca@example.com", "password-123")
	promoteToAdmin(t, adminID)
	ckID := createCheckin(t, srv, userTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", userTok,
		map[string]any{"body": "to-be-moderated comment"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	commentID, _ := posted["id"].(string)

	code, raw = doReq(t, srv, http.MethodDelete, "/v1/comments/"+commentID, adminTok,
		map[string]any{"notes": "violates community rules"})
	if code != http.StatusNoContent {
		t.Fatalf("admin delete: %d body=%s", code, raw)
	}

	// moderation_log must have one row for this comment.
	var n int
	if err := getPool(t).QueryRow(context.Background(), `
SELECT COUNT(*) FROM moderation_log
WHERE target_type = 'comment' AND target_id = $1 AND action = 'soft_delete';`,
		commentID).Scan(&n); err != nil {
		t.Fatalf("moderation_log query: %v", err)
	}
	if n != 1 {
		t.Errorf("moderation_log rows: %d (want 1)", n)
	}

	// And the notes were persisted.
	var notes *string
	if err := getPool(t).QueryRow(context.Background(), `
SELECT notes FROM moderation_log
WHERE target_type = 'comment' AND target_id = $1;`,
		commentID).Scan(&notes); err != nil {
		t.Fatalf("notes query: %v", err)
	}
	if notes == nil || *notes != "violates community rules" {
		t.Errorf("notes=%v", notes)
	}
}

// TestCommentsOnSoftDeletedCheckin_Cascade — soft-delete of the parent
// check-in cascades to the comments surface:
//   - `GET /v1/check-ins/{id}/comments` now returns 404 once the parent
//     is hidden (a moderator's soft-delete must hide the conversation,
//     not just the check-in body).
//   - The DB-level FK cascade on hard-delete is also verified at the
//     end — comments are physically removed when the parent check-in
//     row is dropped.
//
// Earlier versions of this test asserted that the list endpoint returned
// 200 with the comments visible. That was a privacy bug, not a contract
// — the assertions below pin the corrected behavior.
func TestCommentsOnSoftDeletedCheckin_Cascade(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Cascade Sake")
	authorTok, _ := mustRegister(t, srv, "cascauthor", "cauth@example.com", "password-123")
	adminTok, adminID := mustRegister(t, srv, "casc_admin", "cad@example.com", "password-123")
	promoteToAdmin(t, adminID)
	ckID := createCheckin(t, srv, authorTok, bevID)

	// One comment.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
		map[string]any{"body": "self-comment before delete"})
	if code != http.StatusCreated {
		t.Fatalf("create comment: %d body=%s", code, raw)
	}

	// Admin moderates the parent check-in (soft-delete).
	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/check-ins/"+ckID+"/moderate", adminTok,
		map[string]any{"notes": "removing"})
	if code != http.StatusNoContent {
		t.Fatalf("moderate: %d body=%s", code, raw)
	}

	// Comment list cascades to 404 — comments around a hidden check-in
	// must not leak.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", "", nil)
	if code != http.StatusNotFound {
		t.Errorf("anonymous comments on soft-deleted parent: %d body=%s (want 404)", code, raw)
	}
	// Same for the original author — once a moderator hides the check-in,
	// the comment surface is hidden from everyone.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", authorTok, nil)
	if code != http.StatusNotFound {
		t.Errorf("author comments on soft-deleted parent: %d body=%s (want 404)", code, raw)
	}

	// HARD-delete the parent check-in. CASCADE should now wipe the
	// comment(s).
	if _, err := getPool(t).Exec(context.Background(),
		`DELETE FROM check_ins WHERE id = $1;`, ckID); err != nil {
		t.Fatalf("hard delete parent: %v", err)
	}
	var n int
	if err := getPool(t).QueryRow(context.Background(),
		`SELECT COUNT(*) FROM comments WHERE check_in_id = $1;`, ckID).Scan(&n); err != nil {
		t.Fatalf("count: %v", err)
	}
	if n != 0 {
		t.Errorf("comments after hard-delete parent: %d (want 0 by CASCADE)", n)
	}
}

// TestListComments_PrivateCheckin_404ForNonFollower — when the author of
// the parent check-in is on privacy_mode='private', a non-follower hitting
// `/v1/check-ins/{id}/comments` gets 404 (matches the existing behavior of
// `/v1/check-ins/{id}`). Closes the comment-enumeration privacy leak.
func TestListComments_PrivateCheckin_404ForNonFollower(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Private Sake")
	authorTok, authorID := mustRegister(t, srv, "priv_author", "pa@example.com", "password-123")
	strangerTok, _ := mustRegister(t, srv, "priv_stranger", "ps@example.com", "password-123")

	// Flip author to private.
	if _, err := getPool(t).Exec(context.Background(),
		`UPDATE users SET privacy_mode = 'private' WHERE id = $1;`, authorID); err != nil {
		t.Fatalf("set private: %v", err)
	}

	ckID := createCheckin(t, srv, authorTok, bevID)
	// Author comments on their own check-in.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
		map[string]any{"body": "private musing"})
	if code != http.StatusCreated {
		t.Fatalf("seed comment: %d body=%s", code, raw)
	}

	// Stranger is not an accepted follower → 404.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", strangerTok, nil)
	if code != http.StatusNotFound {
		t.Errorf("non-follower GET private check-in comments: %d body=%s (want 404)", code, raw)
	}

	// Anonymous gets the same 404 — no leak via missing bearer.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", "", nil)
	if code != http.StatusNotFound {
		t.Errorf("anonymous GET private check-in comments: %d body=%s (want 404)", code, raw)
	}
}

// TestListComments_PrivateCheckin_AllowedForFollower — an accepted
// follower of a private user can read the comment thread on the user's
// check-in.
func TestListComments_PrivateCheckin_AllowedForFollower(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Follower Sake")
	authorTok, authorID := mustRegister(t, srv, "fol_author", "fa@example.com", "password-123")
	followerTok, followerID := mustRegister(t, srv, "fol_follower", "ff@example.com", "password-123")

	// Author private, follower is accepted.
	if _, err := getPool(t).Exec(context.Background(),
		`UPDATE users SET privacy_mode = 'private' WHERE id = $1;`, authorID); err != nil {
		t.Fatalf("set private: %v", err)
	}
	if _, err := getPool(t).Exec(context.Background(), `
INSERT INTO follows (follower_id, followed_id, status, accepted_at)
VALUES ($1, $2, 'accepted', NOW());`, followerID, authorID); err != nil {
		t.Fatalf("seed follow: %v", err)
	}

	ckID := createCheckin(t, srv, authorTok, bevID)
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
		map[string]any{"body": "for followers"})
	if code != http.StatusCreated {
		t.Fatalf("seed comment: %d body=%s", code, raw)
	}

	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", followerTok, nil)
	if code != http.StatusOK {
		t.Fatalf("follower GET private check-in comments: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Errorf("follower expects 1 comment, got %d: %s", len(page.Items), raw)
	}
}

// TestListComments_PrivateCheckin_AllowedForOwner — the check-in's own
// author always reads their own comment thread, even while private and
// even with no followers.
func TestListComments_PrivateCheckin_AllowedForOwner(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Owner Private Sake")
	authorTok, authorID := mustRegister(t, srv, "own_author", "oa@example.com", "password-123")
	if _, err := getPool(t).Exec(context.Background(),
		`UPDATE users SET privacy_mode = 'private' WHERE id = $1;`, authorID); err != nil {
		t.Fatalf("set private: %v", err)
	}
	ckID := createCheckin(t, srv, authorTok, bevID)
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", authorTok,
		map[string]any{"body": "for me"})
	if code != http.StatusCreated {
		t.Fatalf("seed comment: %d body=%s", code, raw)
	}

	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", authorTok, nil)
	if code != http.StatusOK {
		t.Fatalf("owner GET own private check-in comments: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Errorf("owner expects 1 comment, got %d: %s", len(page.Items), raw)
	}
}

// TestFeedItemHasCommentCount — feed-projection includes comment_count.
func TestFeedItemHasCommentCount(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "FeedCount Sake")
	authorTok, authorID := mustRegister(t, srv, "feed_author", "fa@example.com", "password-123")
	viewerTok, viewerID := mustRegister(t, srv, "feed_viewer", "fv@example.com", "password-123")

	// Viewer follows author so the check-in shows up on viewer's feed.
	if _, err := getPool(t).Exec(context.Background(), `
INSERT INTO follows (follower_id, followed_id, status, accepted_at)
VALUES ($1, $2, 'accepted', NOW());`,
		viewerID, authorID); err != nil {
		t.Fatalf("seed follow: %v", err)
	}

	ckID := createCheckin(t, srv, authorTok, bevID)

	// Viewer comments twice.
	for i := 0; i < 2; i++ {
		code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", viewerTok,
			map[string]any{"body": "comment from viewer"})
		if code != http.StatusCreated {
			t.Fatalf("create: %d body=%s", code, raw)
		}
	}

	// Hit /v1/feed for the viewer.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/feed", viewerTok, nil)
	if code != http.StatusOK {
		t.Fatalf("feed: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			ID           string `json:"id"`
			CommentCount int    `json:"comment_count"`
		} `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Fatalf("feed items: %d (want 1) body=%s", len(page.Items), raw)
	}
	if page.Items[0].CommentCount != 2 {
		t.Errorf("comment_count: %d (want 2)", page.Items[0].CommentCount)
	}
}

// TestComments_SoftDeletedAuthorPII — SEC-001. When the comment author is
// soft-deleted (users.deleted_at IS NOT NULL), the comment row must still
// surface but the author's username / display_name / avatar MUST NOT
// appear in the wire response. Mirrors the notifications SoftDeletedActor
// test shape.
func TestComments_SoftDeletedAuthorPII(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "PII Sake")
	authorTok, _ := mustRegister(t, srv, "pii_author", "piauth@example.com", "password-123")
	commenterTok, idCommenter := mustRegister(t, srv, "pii_commenter", "picom@example.com", "password-123")
	ckID := createCheckin(t, srv, authorTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", commenterTok,
		map[string]any{"body": "from a soon-to-be-deleted user"})
	if code != http.StatusCreated {
		t.Fatalf("create comment: %d body=%s", code, raw)
	}

	// Soft-delete the commenter — paired columns per users_release_implies_delete CHECK.
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET deleted_at = NOW(), username_release_at = NOW() + INTERVAL '30 days' WHERE id = $1;`,
		idCommenter); err != nil {
		t.Fatalf("soft-delete commenter: %v", err)
	}

	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", authorTok, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	if bytes.Contains(raw, []byte("pii_commenter")) {
		t.Errorf("soft-deleted author's username leaked in list response: %s", raw)
	}
	var page struct {
		Items []struct {
			ID   string         `json:"id"`
			Body string         `json:"body"`
			User map[string]any `json:"user"`
		} `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Fatalf("expected 1 comment, got %d", len(page.Items))
	}
	if page.Items[0].User != nil {
		t.Errorf("user field must be null for soft-deleted author, got %+v", page.Items[0].User)
	}
}

// TestAdminComments_SoftDeletedAuthorPII — SEC-001 admin path. Moderator
// queue must keep the user-id linkage (so admins can navigate to the
// account) but blank the display fields.
func TestAdminComments_SoftDeletedAuthorPII(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Admin PII Sake")
	authorTok, _ := mustRegister(t, srv, "apii_author", "apiauth@example.com", "password-123")
	commenterTok, idCommenter := mustRegister(t, srv, "apii_commenter", "apicom@example.com", "password-123")
	adminTok, adminID := mustRegister(t, srv, "apii_admin", "apiadm@example.com", "password-123")
	promoteToAdmin(t, adminID)
	ckID := createCheckin(t, srv, authorTok, bevID)
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", commenterTok,
		map[string]any{"body": "from a soon-to-be-deleted commenter"})

	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET deleted_at = NOW(), username_release_at = NOW() + INTERVAL '30 days' WHERE id = $1;`,
		idCommenter); err != nil {
		t.Fatalf("soft-delete: %v", err)
	}

	code, raw := doReq(t, srv, http.MethodGet, "/v1/admin/comments", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("admin list: %d body=%s", code, raw)
	}
	if bytes.Contains(raw, []byte("apii_commenter")) {
		t.Errorf("admin list leaked soft-deleted commenter's username: %s", raw)
	}
	// Author of the check-in is still active — that username MAY appear
	// elsewhere in the payload (e.g. if it were embedded). We're only
	// asserting the commenter PII does not appear.
	var page struct {
		Items []struct {
			ID   string `json:"id"`
			User struct {
				ID              string `json:"id"`
				Username        string `json:"username"`
				DisplayName     string `json:"display_name"`
				DisplayUsername string `json:"display_username"`
			} `json:"user"`
		} `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Fatalf("admin items: %d (want 1)", len(page.Items))
	}
	if page.Items[0].User.ID != idCommenter {
		t.Errorf("admin user.id should still link to the soft-deleted account; got %q want %q",
			page.Items[0].User.ID, idCommenter)
	}
	if page.Items[0].User.Username != "" || page.Items[0].User.DisplayName != "" || page.Items[0].User.DisplayUsername != "" {
		t.Errorf("admin display fields must be blanked, got user=%+v", page.Items[0].User)
	}
}

// TestCreateComment_PrivateAccountNonFollower404 — SEC-002. A non-follower
// of a private-account owner cannot post a comment on that owner's
// check-in; the service returns the same 404 the other check-in surfaces
// give them. Without this gate the notification emit would confirm the
// private owner's user-id to an outsider.
func TestCreateComment_PrivateAccountNonFollower404(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "Private Sake")
	authorTok, authorID := mustRegister(t, srv, "priv_author", "pa@example.com", "password-123")
	setUserPrivacy(t, authorID, "private")
	outsiderTok, _ := mustRegister(t, srv, "outsider_c", "oc@example.com", "password-123")
	ckID := createCheckin(t, srv, authorTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", outsiderTok,
		map[string]any{"body": "ill-gotten comment"})
	if code != http.StatusNotFound {
		t.Errorf("non-follower post on private check-in: %d body=%s (want 404)", code, raw)
	}

	// The check-in's owner should see zero comments.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+ckID+"/comments", authorTok, nil)
	if code != http.StatusOK {
		t.Fatalf("owner list: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 0 {
		t.Errorf("owner should see no comments after a rejected post: got %d", len(page.Items))
	}

	// And the owner's notifications inbox is empty (no comment notification
	// leaked through the rejected path).
	code, raw = doReq(t, srv, http.MethodGet, "/v1/notifications", authorTok, nil)
	if code != http.StatusOK {
		t.Fatalf("owner inbox: %d body=%s", code, raw)
	}
	var inbox struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &inbox)
	if len(inbox.Items) != 0 {
		t.Errorf("owner inbox should be empty after a rejected comment: %+v", inbox.Items)
	}
}
