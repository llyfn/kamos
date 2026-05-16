//go:build integration
// +build integration

// Phase 6a — public collections discovery endpoint + visibility patch on
// PATCH /v1/collections/{id}.
package integration

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// mustCreateCollectionCompat POSTs /v1/collections and returns the new id.
// Suffix `Compat` is to avoid colliding with any future test helper that
// might want a richer signature.
func mustCreateCollectionCompat(t *testing.T, srv *httptest.Server, tok, name string) string {
	t.Helper()
	code, raw := doReq(t, srv, http.MethodPost, "/v1/collections", tok, map[string]any{"name": name})
	if code != http.StatusCreated {
		t.Fatalf("create %s: %d body=%s", name, code, raw)
	}
	var c map[string]any
	_ = json.Unmarshal(raw, &c)
	id, _ := c["id"].(string)
	if id == "" {
		t.Fatalf("create %s: no id in %s", name, raw)
	}
	return id
}

// TestListPublicCollections_OnlyShowsPublic — three collections across two
// users; only the one flipped to public appears.
func TestListPublicCollections_OnlyShowsPublic(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Alice: one private, one to-be-public.
	aliceTok, _ := mustRegister(t, srv, "alice_pub", "alice_pub@example.com", "password-123")
	alicePrivate := mustCreateCollectionCompat(t, srv, aliceTok, "Alice Private")
	alicePublic := mustCreateCollectionCompat(t, srv, aliceTok, "Alice Public")

	// Bob: one private.
	bobTok, _ := mustRegister(t, srv, "bob_pub", "bob_pub@example.com", "password-123")
	_ = mustCreateCollectionCompat(t, srv, bobTok, "Bob Private")

	// Flip alicePublic to public.
	code, raw := doReq(t, srv, http.MethodPatch, "/v1/collections/"+alicePublic, aliceTok,
		map[string]any{"visibility": "public"})
	if code != http.StatusOK {
		t.Fatalf("patch alicePublic: %d body=%s", code, raw)
	}

	// Hit /v1/collections/public anonymously.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections/public", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			ID    string `json:"id"`
			Name  string `json:"name"`
			Owner struct {
				Username string `json:"username"`
			} `json:"owner"`
		} `json:"items"`
		HasMore bool `json:"has_more"`
	}
	if err := json.Unmarshal(raw, &page); err != nil {
		t.Fatalf("decode: %v body=%s", err, raw)
	}
	if len(page.Items) != 1 {
		t.Fatalf("expected exactly 1 public collection, got %d: %s", len(page.Items), raw)
	}
	if page.Items[0].ID != alicePublic {
		t.Errorf("returned id=%s want alicePublic=%s", page.Items[0].ID, alicePublic)
	}
	if page.Items[0].Owner.Username != "alice_pub" {
		t.Errorf("owner.username=%q want alice_pub", page.Items[0].Owner.Username)
	}
	// Private collection should NOT appear.
	for _, it := range page.Items {
		if it.ID == alicePrivate {
			t.Errorf("private collection leaked into public feed")
		}
	}
}

// TestUpdateCollectionVisibility_RoundTrip — owner toggles public, then
// back to private; each transition is reflected in the discovery feed.
func TestUpdateCollectionVisibility_RoundTrip(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "vis_owner", "vis@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, tok, "Toggle Me")

	// Initially private — not in public feed.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/collections/public", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list 1: %d", code)
	}
	if countWithID(raw, id) != 0 {
		t.Errorf("private collection visible pre-flip")
	}

	// Flip to public.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, tok,
		map[string]any{"visibility": "public"})
	if code != http.StatusOK {
		t.Fatalf("patch public: %d body=%s", code, raw)
	}
	var c map[string]any
	_ = json.Unmarshal(raw, &c)
	if c["visibility"] != "public" {
		t.Errorf("response visibility=%v want public", c["visibility"])
	}

	// Now in public feed.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections/public", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list 2: %d", code)
	}
	if countWithID(raw, id) != 1 {
		t.Errorf("flipped-public collection not in feed: %s", raw)
	}

	// Flip back to private.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, tok,
		map[string]any{"visibility": "private"})
	if code != http.StatusOK {
		t.Fatalf("patch private: %d body=%s", code, raw)
	}

	// Gone from feed again.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections/public", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list 3: %d", code)
	}
	if countWithID(raw, id) != 0 {
		t.Errorf("re-private collection still in feed: %s", raw)
	}
}

// TestUpdateCollectionVisibility_OnlyOwner — a non-owner cannot flip
// someone else's collection's visibility (404 / not their row).
func TestUpdateCollectionVisibility_OnlyOwner(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	aTok, _ := mustRegister(t, srv, "owner_a", "a@example.com", "password-123")
	bTok, _ := mustRegister(t, srv, "stranger_b", "b@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, aTok, "A's List")

	code, raw := doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, bTok,
		map[string]any{"visibility": "public"})
	// The repo enforces ownership via the WHERE user_id = $2 — non-owners
	// see a 404, not a 403 (we deliberately do not leak existence).
	if code != http.StatusNotFound {
		t.Errorf("stranger PATCH: %d body=%s (want 404)", code, raw)
	}

	// Verify A's collection is still private.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections/public", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d", code)
	}
	if countWithID(raw, id) != 0 {
		t.Errorf("stranger leaked collection to public feed: %s", raw)
	}
}

// TestUpdateCollection_NameAndVisibilityTogether — single PATCH can carry
// both fields.
func TestUpdateCollection_NameAndVisibilityTogether(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "combo_u", "combo@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, tok, "Old Name")
	code, raw := doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, tok,
		map[string]any{"name": "New Name", "visibility": "public"})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	var c map[string]any
	_ = json.Unmarshal(raw, &c)
	if c["name"] != "New Name" {
		t.Errorf("name=%v want New Name", c["name"])
	}
	if c["visibility"] != "public" {
		t.Errorf("visibility=%v want public", c["visibility"])
	}
}

// TestUpdateCollection_EmptyBodyRejected — sending {} is a 422; not a no-op.
func TestUpdateCollection_EmptyBodyRejected(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "empty_u", "empty@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, tok, "Empty Test")
	code, raw := doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, tok, map[string]any{})
	if code != http.StatusUnprocessableEntity {
		t.Errorf("patch {}: %d body=%s (want 422)", code, raw)
	}
}

// countWithID counts how many items in a paginated response carry the given
// id. Used by visibility round-trip tests.
func countWithID(raw []byte, id string) int {
	var page struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	n := 0
	for _, it := range page.Items {
		if it.ID == id {
			n++
		}
	}
	return n
}
