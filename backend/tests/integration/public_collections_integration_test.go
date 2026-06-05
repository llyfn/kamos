//go:build integration
// +build integration

// Collection visibility (PATCH /v1/collections/{id}) and the per-user
// public listing surface (GET /v1/users/{username}/collections).
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

// TestUpdateCollectionVisibility_RoundTrip — owner toggles public, then
// back to private; each transition is reflected in the per-user public
// listing (GET /v1/users/{username}/collections, anonymous viewer sees
// only public rows).
func TestUpdateCollectionVisibility_RoundTrip(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "vis_owner", "vis@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, tok, "Toggle Me")

	// Initially private — anonymous viewer sees zero rows.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/vis_owner/collections", "", nil)
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

	// Now visible to anonymous viewer.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/vis_owner/collections", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list 2: %d", code)
	}
	if countWithID(raw, id) != 1 {
		t.Errorf("flipped-public collection not in listing: %s", raw)
	}

	// Flip back to private.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, tok,
		map[string]any{"visibility": "private"})
	if code != http.StatusOK {
		t.Fatalf("patch private: %d body=%s", code, raw)
	}

	// Gone from anonymous listing again.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/vis_owner/collections", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list 3: %d", code)
	}
	if countWithID(raw, id) != 0 {
		t.Errorf("re-private collection still visible: %s", raw)
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

	// Verify A's collection is still private (anonymous viewer sees zero).
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/owner_a/collections", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d", code)
	}
	if countWithID(raw, id) != 0 {
		t.Errorf("stranger leaked collection to public listing: %s", raw)
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

// TestGetCollection_OwnerCanReadPrivate — the owner can fetch their own
// private collection (default visibility on a freshly-created row).
func TestGetCollection_OwnerCanReadPrivate(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, uid := mustRegister(t, srv, "go_owner", "go_owner@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, tok, "Owner Private")

	code, raw := doReq(t, srv, http.MethodGet, "/v1/collections/"+id, tok, nil)
	if code != http.StatusOK {
		t.Fatalf("owner read private: %d body=%s", code, raw)
	}
	var c map[string]any
	_ = json.Unmarshal(raw, &c)
	if c["id"] != id {
		t.Errorf("response id=%v want %s", c["id"], id)
	}
	if c["owner_id"] != uid {
		t.Errorf("owner_id=%v want %s", c["owner_id"], uid)
	}
	if c["visibility"] != "private" {
		t.Errorf("visibility=%v want private", c["visibility"])
	}
}

// TestGetCollection_NonOwnerCannotReadPrivate — a non-owner hitting a
// private collection gets 404 (we do not leak existence via 403).
func TestGetCollection_NonOwnerCannotReadPrivate(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	ownerTok, _ := mustRegister(t, srv, "go_priv_owner", "gpo@example.com", "password-123")
	strangerTok, _ := mustRegister(t, srv, "go_priv_stranger", "gps@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, ownerTok, "Strictly Private")

	code, raw := doReq(t, srv, http.MethodGet, "/v1/collections/"+id, strangerTok, nil)
	if code != http.StatusNotFound {
		t.Errorf("stranger GET private: %d body=%s (want 404)", code, raw)
	}
}

// TestGetCollection_AnyoneCanReadPublic — authed non-owner can read a
// collection the owner has flipped to public.
func TestGetCollection_AnyoneCanReadPublic(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	ownerTok, ownerID := mustRegister(t, srv, "go_pub_owner", "gpubo@example.com", "password-123")
	strangerTok, _ := mustRegister(t, srv, "go_pub_stranger", "gpubs@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, ownerTok, "Anyone Can See")

	// Flip to public.
	code, raw := doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, ownerTok,
		map[string]any{"visibility": "public"})
	if code != http.StatusOK {
		t.Fatalf("patch public: %d body=%s", code, raw)
	}

	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections/"+id, strangerTok, nil)
	if code != http.StatusOK {
		t.Fatalf("stranger GET public: %d body=%s", code, raw)
	}
	var c map[string]any
	_ = json.Unmarshal(raw, &c)
	if c["id"] != id {
		t.Errorf("response id=%v want %s", c["id"], id)
	}
	if c["owner_id"] != ownerID {
		t.Errorf("owner_id=%v want %s", c["owner_id"], ownerID)
	}
	if c["visibility"] != "public" {
		t.Errorf("visibility=%v want public", c["visibility"])
	}
}

// TestGetCollection_AnonymousCanReadPublic — anonymous (no bearer) can
// read a public collection. Verifies the route is OptionalAuth and the
// visibility branch admits unauthenticated viewers.
func TestGetCollection_AnonymousCanReadPublic(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	ownerTok, _ := mustRegister(t, srv, "go_anon_owner", "gao@example.com", "password-123")
	id := mustCreateCollectionCompat(t, srv, ownerTok, "Link-Shareable")

	code, raw := doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, ownerTok,
		map[string]any{"visibility": "public"})
	if code != http.StatusOK {
		t.Fatalf("patch public: %d body=%s", code, raw)
	}

	// Anonymous: pass "" as the token.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections/"+id, "", nil)
	if code != http.StatusOK {
		t.Fatalf("anonymous GET public: %d body=%s", code, raw)
	}
	var c map[string]any
	_ = json.Unmarshal(raw, &c)
	if c["id"] != id {
		t.Errorf("response id=%v want %s", c["id"], id)
	}
	if _, hasOwnerID := c["owner_id"]; !hasOwnerID {
		t.Errorf("missing owner_id in anonymous response: %s", raw)
	}
}

// TestGetUserCollections_OwnerSeesPrivate — owner-as-viewer sees both
// public and private rows; non-owner sees only public.
func TestGetUserCollections_OwnerSeesPrivate(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	ownerTok, _ := mustRegister(t, srv, "uc_owner", "ucowner@example.com", "password-123")
	strangerTok, _ := mustRegister(t, srv, "uc_stranger", "ucstr@example.com", "password-123")

	// Both default collections (Inventory, Wishlist) ship private. Add
	// one explicit public collection.
	pubID := mustCreateCollectionCompat(t, srv, ownerTok, "Shareable")
	code, _ := doReq(t, srv, http.MethodPatch, "/v1/collections/"+pubID, ownerTok,
		map[string]any{"visibility": "public"})
	if code != http.StatusOK {
		t.Fatalf("flip public: %d", code)
	}

	// Owner view: sees Inventory + Wishlist + Shareable (3 rows).
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/uc_owner/collections", ownerTok, nil)
	if code != http.StatusOK {
		t.Fatalf("owner list: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 3 {
		t.Errorf("owner sees %d rows, want 3 (2 default private + 1 public): %s", len(page.Items), raw)
	}

	// Stranger view: only the public row.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/uc_owner/collections", strangerTok, nil)
	if code != http.StatusOK {
		t.Fatalf("stranger list: %d body=%s", code, raw)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Errorf("stranger sees %d rows, want 1 (only public): %s", len(page.Items), raw)
	}
	if len(page.Items) == 1 && page.Items[0]["id"] != pubID {
		t.Errorf("stranger sees wrong row: got id=%v want %s", page.Items[0]["id"], pubID)
	}

	// Anonymous viewer: same as stranger (public only).
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/uc_owner/collections", "", nil)
	if code != http.StatusOK {
		t.Fatalf("anon list: %d body=%s", code, raw)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 {
		t.Errorf("anon sees %d rows, want 1: %s", len(page.Items), raw)
	}
}

// TestGetUserCollections_UnknownUser — 404 when the username does not
// resolve to a live user.
func TestGetUserCollections_UnknownUser(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/no_such_user/collections", "", nil)
	if code != http.StatusNotFound {
		t.Errorf("unknown user: %d body=%s (want 404)", code, raw)
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
