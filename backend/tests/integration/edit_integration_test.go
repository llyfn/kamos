//go:build integration
// +build integration

// Post-creation editability (slice 01): integration coverage for
// PATCH /v1/check-ins/{id} (rating/review/tags/photos + edited_at touch)
// and PATCH /v1/comments/{id} (author-only body edit + edited_at touch).
package integration

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

// patchedCheckin captures the response fields slice 01 cares about.
type patchedCheckin struct {
	ID       string  `json:"id"`
	Rating   *float64 `json:"rating"`
	Review   *string `json:"review"`
	EditedAt *string `json:"edited_at"`
	Photos   []struct {
		URL       string `json:"url"`
		SortOrder int    `json:"sort_order"`
	} `json:"photos"`
	Tags []struct {
		Slug string `json:"slug"`
	} `json:"tags"`
}

func decodeCheckin(t *testing.T, raw []byte) patchedCheckin {
	t.Helper()
	var out patchedCheckin
	if err := json.Unmarshal(raw, &out); err != nil {
		t.Fatalf("decode check-in: %v body=%s", err, raw)
	}
	return out
}

// TestUpdateCheckinTouchesEditedAt — a real PATCH that changes the review
// surface sets edited_at; the create response has it absent.
func TestUpdateCheckinTouchesEditedAt(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "EditBev")
	tok, _ := mustRegister(t, srv, "editor_one", "ed1@example.com", "password-123")

	// Create — edited_at should be null/absent.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"rating":      4.0,
		"review":      "first thoughts",
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	created := decodeCheckin(t, raw)
	if created.EditedAt != nil {
		t.Errorf("create response should have edited_at=null, got %v", *created.EditedAt)
	}

	// PATCH the review → edited_at should populate.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+created.ID, tok, map[string]any{
		"review": "second pass — way better",
	})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	updated := decodeCheckin(t, raw)
	if updated.EditedAt == nil || *updated.EditedAt == "" {
		t.Errorf("edited_at should be set after a real edit; raw=%s", raw)
	}
	if updated.Review == nil || *updated.Review != "second pass — way better" {
		t.Errorf("review not updated: %v", updated.Review)
	}
}

// TestUpdateCheckinNoOpDoesNotTouchEditedAt — a PATCH with no tracked
// field present leaves edited_at alone (slice 01 contract).
func TestUpdateCheckinNoOpDoesNotTouchEditedAt(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "NoOpBev")
	tok, _ := mustRegister(t, srv, "noop_u", "noop@example.com", "password-123")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	created := decodeCheckin(t, raw)

	// PATCH with an empty body — no tracked field present.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+created.ID, tok, map[string]any{})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	updated := decodeCheckin(t, raw)
	if updated.EditedAt != nil {
		t.Errorf("no-op PATCH should not touch edited_at, got %v", *updated.EditedAt)
	}
}

// TestUpdateCheckinPhotoCap — exceeding the 1-photo submission cap via
// add_photos returns 422 PHOTO_CAP_EXCEEDED (Slice B / SPEC §4.1).
func TestUpdateCheckinPhotoCap(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "CapBev")
	tok, uid := mustRegister(t, srv, "caprock", "cap@example.com", "password-123")

	// Create with 1 inline photo so we have 1 attached on the row.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"photos":      []string{"http://a/1.jpg"},
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	created := decodeCheckin(t, raw)

	// Prep 1 pending upload; adding it would push us to 2 → reject.
	p := getPool(t)
	id1 := mustInsertPendingUpload(t, p, uid, "checkins/cap/x1.jpg")

	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+created.ID, tok, map[string]any{
		"add_photos": []string{id1},
	})
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422 PHOTO_CAP_EXCEEDED, got %d body=%s", code, raw)
	}
	var e errBodyShape
	_ = json.Unmarshal(raw, &e)
	if e.Code != "PHOTO_CAP_EXCEEDED" {
		t.Errorf("code=%q want PHOTO_CAP_EXCEEDED; raw=%s", e.Code, raw)
	}
}

// TestUpdateCheckinTagReplacement — present tags replace, absent leaves alone.
func TestUpdateCheckinTagReplacement(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "TagBev")
	tok, _ := mustRegister(t, srv, "tagger", "tg@example.com", "password-123")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"tags":        []string{"floral", "umami"},
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	created := decodeCheckin(t, raw)

	// Absent tags → unchanged.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+created.ID, tok, map[string]any{
		"review": "now with notes",
	})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	got := decodeCheckin(t, raw)
	if len(got.Tags) != len(created.Tags) {
		t.Errorf("tags should be unchanged when absent; before=%d after=%d", len(created.Tags), len(got.Tags))
	}

	// Present tags (empty) → replace with empty.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+created.ID, tok, map[string]any{
		"tags": []string{},
	})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	got = decodeCheckin(t, raw)
	if len(got.Tags) != 0 {
		t.Errorf("empty tags should replace; got %d", len(got.Tags))
	}
}

// TestUpdateCheckinBeverageImmutable — the integration version of the
// handler unit test. Confirms the server returns 422 with the validation
// code even when a real check-in exists.
func TestUpdateCheckinBeverageImmutableIntegration(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "ImmutableBev")
	tok, _ := mustRegister(t, srv, "immut", "im@example.com", "password-123")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	created := decodeCheckin(t, raw)

	otherBev := seedBeverage(t, "OtherBev")
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+created.ID, tok, map[string]any{
		"beverage_id": otherBev,
	})
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d body=%s", code, raw)
	}
	if !strings.Contains(string(raw), "beverage_id") {
		t.Errorf("message should mention beverage_id; raw=%s", raw)
	}
}

// TestUpdateCheckinNonOwnerForbidden — only the author may edit.
func TestUpdateCheckinNonOwnerForbidden(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "OwnerBev")
	aliceTok, _ := mustRegister(t, srv, "owner_a", "oa@example.com", "password-123")
	mallTok, _ := mustRegister(t, srv, "intrudr", "in@example.com", "password-123")

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", aliceTok, map[string]any{
		"beverage_id": bevID,
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	created := decodeCheckin(t, raw)

	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+created.ID, mallTok, map[string]any{
		"review": "I am not the owner",
	})
	if code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d body=%s", code, raw)
	}
}

// TestUpdateCommentTouchesEditedAt — a body edit by the author flips
// edited_at; the create response has it null.
func TestUpdateCommentTouchesEditedAt(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "CommentEditBev")
	aliceTok, _ := mustRegister(t, srv, "author_a", "ca@example.com", "password-123")
	ckID := createCheckin(t, srv, aliceTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", aliceTok,
		map[string]any{"body": "original body"})
	if code != http.StatusCreated {
		t.Fatalf("create comment: %d body=%s", code, raw)
	}
	var created struct {
		ID       string  `json:"id"`
		Body     string  `json:"body"`
		EditedAt *string `json:"edited_at"`
	}
	_ = json.Unmarshal(raw, &created)
	if created.EditedAt != nil {
		t.Errorf("create response should have edited_at=null, got %v", *created.EditedAt)
	}

	code, raw = doReq(t, srv, http.MethodPatch, "/v1/comments/"+created.ID, aliceTok,
		map[string]any{"body": "fixed a typo"})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	var updated struct {
		ID       string  `json:"id"`
		Body     string  `json:"body"`
		EditedAt *string `json:"edited_at"`
	}
	_ = json.Unmarshal(raw, &updated)
	if updated.Body != "fixed a typo" {
		t.Errorf("body not updated: %q", updated.Body)
	}
	if updated.EditedAt == nil || *updated.EditedAt == "" {
		t.Errorf("edited_at should be set after a real edit; raw=%s", raw)
	}
}

// TestUpdateCommentSameBodyNoTouch — a PATCH that submits the existing
// body is a true no-op: edited_at stays null. SQL pattern: §19's
// `body IS DISTINCT FROM $2` CASE.
func TestUpdateCommentSameBodyNoTouch(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "NoTouchBev")
	tok, _ := mustRegister(t, srv, "no_touch", "nt@example.com", "password-123")
	ckID := createCheckin(t, srv, tok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", tok,
		map[string]any{"body": "same body"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var created struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(raw, &created)

	code, raw = doReq(t, srv, http.MethodPatch, "/v1/comments/"+created.ID, tok,
		map[string]any{"body": "same body"})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	var got struct {
		EditedAt *string `json:"edited_at"`
	}
	_ = json.Unmarshal(raw, &got)
	if got.EditedAt != nil {
		t.Errorf("same-body PATCH should not touch edited_at; got %v", *got.EditedAt)
	}
}

// TestUpdateCommentNonAuthor — a non-author hits 404 (we don't leak
// existence to non-authors).
func TestUpdateCommentNonAuthor(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "AuthZBev")
	aliceTok, _ := mustRegister(t, srv, "alice_z", "az@example.com", "password-123")
	bobTok, _ := mustRegister(t, srv, "bob_z", "bz@example.com", "password-123")
	ckID := createCheckin(t, srv, aliceTok, bevID)

	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", aliceTok,
		map[string]any{"body": "alice's note"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var created struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(raw, &created)

	code, raw = doReq(t, srv, http.MethodPatch, "/v1/comments/"+created.ID, bobTok,
		map[string]any{"body": "bob tries to edit"})
	if code != http.StatusNotFound {
		t.Fatalf("non-author should get 404, got %d body=%s", code, raw)
	}
}

// TestUpdateCommentBodySanitization — invalid body (control char) is
// rejected on the edit path the same way it is on create.
func TestUpdateCommentBodySanitization(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevID := seedBeverage(t, "SanitizeBev")
	tok, _ := mustRegister(t, srv, "sanit_u", "sa@example.com", "password-123")
	ckID := createCheckin(t, srv, tok, bevID)
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins/"+ckID+"/comments", tok,
		map[string]any{"body": "clean body"})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var created struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(raw, &created)

	code, raw = doReq(t, srv, http.MethodPatch, "/v1/comments/"+created.ID, tok,
		map[string]any{"body": "nope\x07ctrl"})
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d body=%s", code, raw)
	}
}
