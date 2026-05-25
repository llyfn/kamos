//go:build integration
// +build integration

// In-app notifications inbox (SPEC §5.4).
package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// notificationsPage mirrors the cursor.Page envelope for the inbox.
type notificationsPage struct {
	Items []struct {
		ID    string `json:"id"`
		Type  string `json:"type"`
		Actor *struct {
			ID       string `json:"id"`
			Username string `json:"username"`
		} `json:"actor"`
		CheckInID *string `json:"check_in_id"`
		CommentID *string `json:"comment_id"`
		ReadAt    *string `json:"read_at"`
		CreatedAt string  `json:"created_at"`
	} `json:"items"`
	NextCursor string `json:"next_cursor"`
	HasMore    bool   `json:"has_more"`
}

func listNotifications(t *testing.T, srv *httptest.Server, tok, cursor string) notificationsPage {
	t.Helper()
	path := "/v1/notifications"
	if cursor != "" {
		path += "?cursor=" + cursor
	}
	code, raw := doReq(t, srv, http.MethodGet, path, tok, nil)
	if code != http.StatusOK {
		t.Fatalf("list notifications: %d body=%s", code, raw)
	}
	var p notificationsPage
	if err := json.Unmarshal(raw, &p); err != nil {
		t.Fatalf("decode: %v body=%s", err, raw)
	}
	return p
}

func unreadCount(t *testing.T, srv *httptest.Server, tok string) int {
	t.Helper()
	code, raw := doReq(t, srv, http.MethodGet, "/v1/notifications/unread-count", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("unread-count: %d body=%s", code, raw)
	}
	var resp struct {
		Count int `json:"count"`
	}
	_ = json.Unmarshal(raw, &resp)
	return resp.Count
}

// TestNotifications_ToastEmitsOneRowAfterToggle confirms the dedupe
// invariant: toggling a toast off and back on results in exactly one
// notification row, not two.
func TestNotifications_ToastEmitsOneRowAfterToggle(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, _ := mustRegister(t, srv, "author_n", "an@example.com", "password-123")
	tokFan, _ := mustRegister(t, srv, "fan_n", "fn@example.com", "password-123")
	bevID := seedBeverage(t, "Toast Sake")
	ckID := createCheckin(t, srv, tokAuthor, bevID)

	// Fan toasts → expect one `toast` row in author's inbox.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)
	if code != http.StatusOK {
		t.Fatalf("toast: %d body=%s", code, raw)
	}
	p := listNotifications(t, srv, tokAuthor, "")
	if len(p.Items) != 1 || p.Items[0].Type != "toast" {
		t.Fatalf("after first toast: %+v", p)
	}
	firstID := p.Items[0].ID

	// Untoast.
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)
	// Re-toast.
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)

	p = listNotifications(t, srv, tokAuthor, "")
	if len(p.Items) != 1 {
		t.Fatalf("expected 1 row after toggle, got %d: %+v", len(p.Items), p.Items)
	}
	if p.Items[0].ID != firstID {
		t.Errorf("notification id changed across re-toggle: was %s now %s", firstID, p.Items[0].ID)
	}
}

// TestNotifications_SelfToastNoEmit confirms toasting your own check-in
// produces no notification row (SPEC §5.4 "Self-actions never produce a
// notification").
func TestNotifications_SelfToastNoEmit(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "selftoast", "st@example.com", "password-123")
	bevID := seedBeverage(t, "Self Sake")
	ckID := createCheckin(t, srv, tok, bevID)

	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tok, nil)
	p := listNotifications(t, srv, tok, "")
	if len(p.Items) != 0 {
		t.Errorf("self-toast produced rows: %+v", p.Items)
	}
}

// TestNotifications_CommentEmitsRow confirms a comment emits a `comment`
// notification with the comment_id reference populated.
func TestNotifications_CommentEmitsRow(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, _ := mustRegister(t, srv, "author_cn", "acn@example.com", "password-123")
	tokFan, _ := mustRegister(t, srv, "fan_cn", "fcn@example.com", "password-123")
	bevID := seedBeverage(t, "Comment Sake N")
	ckID := createCheckin(t, srv, tokAuthor, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", tokFan,
		map[string]any{"body": "nice"})
	if code != http.StatusCreated {
		t.Fatalf("comment: %d body=%s", code, raw)
	}
	var posted map[string]any
	_ = json.Unmarshal(raw, &posted)
	commentID, _ := posted["id"].(string)

	p := listNotifications(t, srv, tokAuthor, "")
	if len(p.Items) != 1 {
		t.Fatalf("expected 1 row, got %d", len(p.Items))
	}
	row := p.Items[0]
	if row.Type != "comment" {
		t.Errorf("type=%q want comment", row.Type)
	}
	if row.CommentID == nil || *row.CommentID != commentID {
		t.Errorf("comment_id=%v want %s", row.CommentID, commentID)
	}
	if row.CheckInID == nil || *row.CheckInID != ckID {
		t.Errorf("check_in_id=%v want %s", row.CheckInID, ckID)
	}
}

// TestNotifications_FollowPublicEmitsFollow public account auto-accept
// path emits `follow`.
func TestNotifications_FollowPublicEmitsFollow(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokA, _ := mustRegister(t, srv, "alice_pub", "ap@example.com", "password-123")
	tokB, _ := mustRegister(t, srv, "bob_pub", "bp@example.com", "password-123")

	doReq(t, srv, http.MethodPost, "/v1/users/bob_pub/follow", tokA, nil)
	_ = tokB

	p := listNotifications(t, srv, tokB, "")
	if len(p.Items) != 1 || p.Items[0].Type != "follow" {
		t.Fatalf("expected follow row, got: %+v", p.Items)
	}
	if p.Items[0].Actor == nil || p.Items[0].Actor.Username != "alice_pub" {
		t.Errorf("actor: %+v", p.Items[0].Actor)
	}

	// Re-follow after unfollow: no spam. Same row id (ON CONFLICT DO NOTHING).
	firstID := p.Items[0].ID
	doReq(t, srv, http.MethodDelete, "/v1/users/bob_pub/follow", tokA, nil)
	doReq(t, srv, http.MethodPost, "/v1/users/bob_pub/follow", tokA, nil)

	p = listNotifications(t, srv, tokB, "")
	if len(p.Items) != 1 {
		t.Fatalf("expected still 1 row, got %d", len(p.Items))
	}
	if p.Items[0].ID != firstID {
		t.Errorf("follow id should be stable across re-follow: was %s now %s", firstID, p.Items[0].ID)
	}
}

// TestNotifications_PrivateFollowLifecycle: request → approve.
// Verifies that approve writes a `follow_approved` row to the requester
// AND deletes the `follow_request` row from the approver's inbox.
func TestNotifications_PrivateFollowLifecycle(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokR, _ := mustRegister(t, srv, "requester", "req@example.com", "password-123")
	tokP, idP := mustRegister(t, srv, "private_x", "px@example.com", "password-123")
	setUserPrivacy(t, idP, "private")

	// Requester asks to follow the private account.
	doReq(t, srv, http.MethodPost, "/v1/users/private_x/follow", tokR, nil)

	// Approver's inbox holds one `follow_request` row.
	p := listNotifications(t, srv, tokP, "")
	if len(p.Items) != 1 || p.Items[0].Type != "follow_request" {
		t.Fatalf("approver inbox after request: %+v", p.Items)
	}

	// Resolve requester id to call /approve/{id}.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/requester", "", nil)
	if code != http.StatusOK {
		t.Fatalf("lookup requester: %d", code)
	}
	var prof map[string]any
	_ = json.Unmarshal(raw, &prof)
	reqID, _ := prof["id"].(string)

	doReq(t, srv, http.MethodPost, "/v1/follow-requests/"+reqID+"/approve", tokP, nil)

	// Approver's inbox: the follow_request row is gone.
	p = listNotifications(t, srv, tokP, "")
	for _, it := range p.Items {
		if it.Type == "follow_request" {
			t.Errorf("follow_request row still present on approver inbox after approve: %+v", it)
		}
	}

	// Requester's inbox now holds one `follow_approved` row.
	p = listNotifications(t, srv, tokR, "")
	found := false
	for _, it := range p.Items {
		if it.Type == "follow_approved" {
			found = true
			if it.Actor == nil || it.Actor.Username != "private_x" {
				t.Errorf("follow_approved actor: %+v", it.Actor)
			}
		}
	}
	if !found {
		t.Errorf("requester inbox missing follow_approved: %+v", p.Items)
	}
}

// TestNotifications_PrivateFollowDeclineClearsRequest decline removes the
// follow_request from the decliner's inbox and writes no row on the
// requester's side.
func TestNotifications_PrivateFollowDeclineClearsRequest(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokR, _ := mustRegister(t, srv, "req_d", "rd@example.com", "password-123")
	tokP, idP := mustRegister(t, srv, "priv_d", "pd@example.com", "password-123")
	setUserPrivacy(t, idP, "private")

	doReq(t, srv, http.MethodPost, "/v1/users/priv_d/follow", tokR, nil)
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/req_d", "", nil)
	if code != http.StatusOK {
		t.Fatalf("lookup: %d", code)
	}
	var prof map[string]any
	_ = json.Unmarshal(raw, &prof)
	reqID, _ := prof["id"].(string)

	doReq(t, srv, http.MethodPost, "/v1/follow-requests/"+reqID+"/decline", tokP, nil)

	p := listNotifications(t, srv, tokP, "")
	for _, it := range p.Items {
		if it.Type == "follow_request" {
			t.Errorf("follow_request still present after decline: %+v", it)
		}
	}
	// Requester inbox empty (no follow_approved, no echo of the request).
	p = listNotifications(t, srv, tokR, "")
	if len(p.Items) != 0 {
		t.Errorf("requester inbox should be empty after decline: %+v", p.Items)
	}
}

// TestNotifications_UnfollowPendingClearsRequest: requester withdraws
// (DELETE /follow) before approval → the follow_request row leaves the
// approver's inbox.
func TestNotifications_UnfollowPendingClearsRequest(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokR, _ := mustRegister(t, srv, "req_u", "ru@example.com", "password-123")
	tokP, idP := mustRegister(t, srv, "priv_u", "pu@example.com", "password-123")
	setUserPrivacy(t, idP, "private")

	doReq(t, srv, http.MethodPost, "/v1/users/priv_u/follow", tokR, nil)
	if c := unreadCount(t, srv, tokP); c != 1 {
		t.Fatalf("approver unread before withdraw: %d want 1", c)
	}
	doReq(t, srv, http.MethodDelete, "/v1/users/priv_u/follow", tokR, nil)
	if c := unreadCount(t, srv, tokP); c != 0 {
		t.Errorf("approver unread after withdraw: %d want 0", c)
	}
}

// TestNotifications_MarkReadIDORSafe: a caller cannot mark another user's
// notification read. The endpoint returns 200 with marked=0 (not 404) so
// it can't be used as a probing oracle.
func TestNotifications_MarkReadIDORSafe(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, _ := mustRegister(t, srv, "auth_idor", "ai@example.com", "password-123")
	tokFan, _ := mustRegister(t, srv, "fan_idor", "fi@example.com", "password-123")
	tokAttacker, _ := mustRegister(t, srv, "atk_idor", "atki@example.com", "password-123")
	bevID := seedBeverage(t, "IDOR Sake")
	ckID := createCheckin(t, srv, tokAuthor, bevID)
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)

	p := listNotifications(t, srv, tokAuthor, "")
	if len(p.Items) != 1 {
		t.Fatalf("setup: %d notifications", len(p.Items))
	}
	notifID := p.Items[0].ID

	code, raw := doReq(t, srv, http.MethodPost, "/v1/notifications/read", tokAttacker,
		map[string]any{"ids": []string{notifID}})
	if code != http.StatusOK {
		t.Fatalf("attacker mark-read: %d body=%s", code, raw)
	}
	var resp struct {
		Marked int `json:"marked"`
	}
	_ = json.Unmarshal(raw, &resp)
	if resp.Marked != 0 {
		t.Errorf("attacker marked %d rows belonging to author", resp.Marked)
	}

	// Author's notification remains unread.
	if c := unreadCount(t, srv, tokAuthor); c != 1 {
		t.Errorf("author unread should still be 1, got %d", c)
	}
}

// TestNotifications_MarkAllRead.
func TestNotifications_MarkAllRead(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, _ := mustRegister(t, srv, "author_ma", "ama@example.com", "password-123")
	tokFan, _ := mustRegister(t, srv, "fan_ma", "fma@example.com", "password-123")
	bevID := seedBeverage(t, "MarkAll Sake")
	ckID := createCheckin(t, srv, tokAuthor, bevID)
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", tokFan,
		map[string]any{"body": "great"})

	if c := unreadCount(t, srv, tokAuthor); c != 2 {
		t.Fatalf("setup: unread=%d want 2", c)
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/notifications/read", tokAuthor,
		map[string]any{"all": true})
	if code != http.StatusOK {
		t.Fatalf("mark all: %d body=%s", code, raw)
	}
	if c := unreadCount(t, srv, tokAuthor); c != 0 {
		t.Errorf("after mark-all: unread=%d want 0", c)
	}
}

// TestNotifications_MarkReadRequestValidation: body must have exactly one
// of ids|all, and ids entries must be UUIDs.
func TestNotifications_MarkReadRequestValidation(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "validator_n", "vn@example.com", "password-123")
	cases := []struct {
		name string
		body map[string]any
	}{
		{"empty", map[string]any{}},
		{"both", map[string]any{"all": true, "ids": []string{"00000000-0000-0000-0000-000000000000"}}},
		{"empty_ids", map[string]any{"ids": []string{}}},
		{"non_uuid_id", map[string]any{"ids": []string{"not-a-uuid"}}},
		{"mixed_uuid_and_garbage", map[string]any{"ids": []string{
			"00000000-0000-0000-0000-000000000000", "garbage",
		}}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			code, raw := doReq(t, srv, http.MethodPost, "/v1/notifications/read", tok, c.body)
			if code != http.StatusUnprocessableEntity {
				t.Errorf("body=%v: code=%d body=%s", c.body, code, raw)
			}
		})
	}
}

// TestNotifications_CursorPagination — 21+ rows, page size 20, cursor
// roundtrip and tamper-detect.
func TestNotifications_CursorPagination(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, idAuthor := mustRegister(t, srv, "author_cur", "ac@example.com", "password-123")
	tokFan, _ := mustRegister(t, srv, "fan_cur", "fc@example.com", "password-123")
	_ = idAuthor

	// Author posts 25 check-ins; fan toasts each → 25 notifications.
	bevID := seedBeverage(t, "Cursor Sake")
	for i := 0; i < 25; i++ {
		ckID := createCheckin(t, srv, tokAuthor, bevID)
		doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)
	}

	page1 := listNotifications(t, srv, tokAuthor, "")
	if len(page1.Items) != 20 {
		t.Fatalf("page1: %d rows want 20", len(page1.Items))
	}
	if !page1.HasMore || page1.NextCursor == "" {
		t.Fatalf("page1: has_more=%v cursor=%q", page1.HasMore, page1.NextCursor)
	}
	page2 := listNotifications(t, srv, tokAuthor, page1.NextCursor)
	if len(page2.Items) != 5 {
		t.Fatalf("page2: %d rows want 5", len(page2.Items))
	}
	if page2.HasMore {
		t.Errorf("page2.has_more should be false")
	}

	// Tampered cursor → 400.
	code, raw := doReq(t, srv, http.MethodGet,
		"/v1/notifications?cursor=NOT_SIGNED.NOT_VALID", tokAuthor, nil)
	if code != http.StatusBadRequest {
		t.Errorf("tampered cursor: code=%d body=%s", code, raw)
	}
}

// TestNotifications_HardDeletedActor a hard-deleted actor still surfaces
// as a notification row with actor=null. The FK ON DELETE SET NULL on
// actor_user_id is what produces the null; the row itself survives.
func TestNotifications_HardDeletedActor(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, _ := mustRegister(t, srv, "author_del", "ad@example.com", "password-123")
	tokFan, idFan := mustRegister(t, srv, "fan_del", "fd@example.com", "password-123")
	bevID := seedBeverage(t, "Del Sake")
	ckID := createCheckin(t, srv, tokAuthor, bevID)
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)

	// Hard-delete the fan user — actor_user_id flips to NULL via FK
	// ON DELETE SET NULL.
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`DELETE FROM users WHERE id = $1;`, idFan); err != nil {
		t.Fatalf("hard delete fan: %v", err)
	}

	pg := listNotifications(t, srv, tokAuthor, "")
	if len(pg.Items) != 1 {
		t.Fatalf("got %d rows", len(pg.Items))
	}
	if pg.Items[0].Actor != nil {
		t.Errorf("actor should be null after hard delete, got %+v", pg.Items[0].Actor)
	}
}

// TestNotifications_SoftDeletedActor — SPEC §5.4 PII guarantee.
// After the actor is soft-deleted (users.deleted_at IS NOT NULL), the
// notification row must still surface in the recipient's inbox, but
// actor must be null so the client renders the localized "Deleted user"
// placeholder. The actor's username / display_name MUST NOT appear in
// the response, even though actor_user_id still references a live users
// row (soft-delete does not flip the FK).
func TestNotifications_SoftDeletedActor(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, _ := mustRegister(t, srv, "author_sd", "asd@example.com", "password-123")
	tokFan, idFan := mustRegister(t, srv, "fan_sd", "fsd@example.com", "password-123")
	bevID := seedBeverage(t, "SoftDel Sake")
	ckID := createCheckin(t, srv, tokAuthor, bevID)
	doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/toast", tokFan, nil)

	// Soft-delete: users.deleted_at = NOW(). FK unaffected — the join
	// still matches a live users row.
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET deleted_at = NOW(), username_release_at = NOW() + INTERVAL '30 days' WHERE id = $1;`, idFan); err != nil {
		t.Fatalf("soft delete fan: %v", err)
	}

	// Use the raw wire bytes so we can grep for PII directly.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/notifications", tokAuthor, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	if bytes.Contains(raw, []byte("fan_sd")) {
		t.Errorf("soft-deleted actor's username leaked in response: %s", raw)
	}
	var pg notificationsPage
	_ = json.Unmarshal(raw, &pg)
	if len(pg.Items) != 1 {
		t.Fatalf("got %d rows", len(pg.Items))
	}
	if pg.Items[0].Actor != nil {
		t.Errorf("actor must be null for soft-deleted user, got %+v", pg.Items[0].Actor)
	}
}

// TestNotifications_UnauthedRejected.
func TestNotifications_UnauthedRejected(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	for _, path := range []string{
		"/v1/notifications",
		"/v1/notifications/unread-count",
	} {
		code, _ := doReq(t, srv, http.MethodGet, path, "", nil)
		if code != http.StatusUnauthorized {
			t.Errorf("GET %s unauthed: %d", path, code)
		}
	}
	code, _ := doReq(t, srv, http.MethodPost, "/v1/notifications/read", "", map[string]any{"all": true})
	if code != http.StatusUnauthorized {
		t.Errorf("POST /v1/notifications/read unauthed: %d", code)
	}
}
