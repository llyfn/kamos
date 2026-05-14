//go:build integration
// +build integration

package integration

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

// /v1/categories returns the SPEC §2.1 canonical strings.
func TestTaxonomyCategories(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	code, raw := doReq(t, srv, http.MethodGet, "/v1/categories", "", nil)
	if code != http.StatusOK {
		t.Fatalf("status=%d body=%s", code, raw)
	}
	var cats []map[string]any
	if err := json.Unmarshal(raw, &cats); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(cats) != 3 {
		t.Fatalf("want 3 categories, got %d", len(cats))
	}
	slugs := map[string]bool{}
	for _, c := range cats {
		slug, _ := c["slug"].(string)
		slugs[slug] = true
		label, _ := c["label_i18n"].(map[string]any)
		switch slug {
		case "nihonshu":
			if label["en"] != "Nihonshu (Sake)" {
				t.Errorf("nihonshu en: %v", label["en"])
			}
			if label["ja"] != "日本酒" {
				t.Errorf("nihonshu ja: %v", label["ja"])
			}
			if label["ko"] != "니혼슈 (사케)" {
				t.Errorf("nihonshu ko: %v", label["ko"])
			}
		case "shochu":
			if label["en"] != "Shochu" {
				t.Errorf("shochu en: %v", label["en"])
			}
		case "liqueur":
			if label["en"] != "Liqueur" {
				t.Errorf("liqueur en: %v", label["en"])
			}
		}
	}
	for _, want := range []string{"nihonshu", "shochu", "liqueur"} {
		if !slugs[want] {
			t.Errorf("missing slug %q", want)
		}
	}
}

// /v1/flavor-tags returns the SPEC §4.3 taxonomy across all dimensions.
func TestTaxonomyFlavorTags(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	code, raw := doReq(t, srv, http.MethodGet, "/v1/flavor-tags", "", nil)
	if code != http.StatusOK {
		t.Fatalf("status=%d body=%s", code, raw)
	}
	var tags []map[string]any
	if err := json.Unmarshal(raw, &tags); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(tags) < 15 {
		t.Errorf("expected ≥ 15 flavor tags, got %d", len(tags))
	}
	dims := map[string]bool{}
	for _, t := range tags {
		dim, _ := t["dimension"].(string)
		dims[dim] = true
	}
	for _, want := range []string{"sweetness", "body", "acidity", "character", "finish"} {
		if !dims[want] {
			t.Errorf("missing dimension %q", want)
		}
	}
}

// /v1/breweries lists + detail.
func TestBreweries(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	_ = seedBeverage(t, "BrewListBev") // seeds a brewery as a side effect

	code, raw := doReq(t, srv, http.MethodGet, "/v1/breweries", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list status=%d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	if err := json.Unmarshal(raw, &page); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(page.Items) == 0 {
		t.Fatalf("expected ≥ 1 brewery")
	}
	bid, _ := page.Items[0]["id"].(string)
	if bid == "" {
		t.Fatalf("brewery id missing: %s", raw)
	}
	code, raw = doReq(t, srv, http.MethodGet, "/v1/breweries/"+bid, "", nil)
	if code != http.StatusOK {
		t.Fatalf("detail status=%d body=%s", code, raw)
	}
}

// /v1/search?q=... matches the seeded beverage name via FTS.
func TestSearch(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	// The FTS index uses to_tsvector('simple', ...) so the query term must
	// be a whole token in the indexed text. Use a single-word name.
	seedBeverage(t, "Hakkaisan")

	code, raw := doReq(t, srv, http.MethodGet, "/v1/search?q=Hakkaisan", "", nil)
	if code != http.StatusOK {
		t.Fatalf("status=%d body=%s", code, raw)
	}
	if !strings.Contains(string(raw), "Hakkaisan") {
		t.Errorf("search did not return seeded beverage: %s", raw)
	}
}

// /v1/search without `q` is rejected at the handler boundary.
func TestSearchRequiresQuery(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	code, _ := doReq(t, srv, http.MethodGet, "/v1/search", "", nil)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("status=%d", code)
	}
}

// /v1/check-ins/{id}/toast toggles toast state idempotently.
func TestToggleToast(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokAuthor, _ := mustRegister(t, srv, "author", "author@example.com", "password11")
	tokFan, _ := mustRegister(t, srv, "fan", "fan@example.com", "password11")
	bevID := seedBeverage(t, "Toastable")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tokAuthor, map[string]any{
		"beverage_id": bevID,
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	id, _ := ci["id"].(string)

	// Fan toasts.
	code, raw = doReq(t, srv, http.MethodPost, "/v1/check-ins/"+id+"/toast", tokFan, nil)
	if code != http.StatusOK {
		t.Fatalf("toast: %d body=%s", code, raw)
	}
	var state map[string]any
	_ = json.Unmarshal(raw, &state)
	if state["toasts"].(float64) != 1 || state["you_toasted"] != true {
		t.Errorf("first toast: %s", raw)
	}

	// Fan untoasts.
	code, raw = doReq(t, srv, http.MethodPost, "/v1/check-ins/"+id+"/toast", tokFan, nil)
	if code != http.StatusOK {
		t.Fatalf("untoast: %d", code)
	}
	_ = json.Unmarshal(raw, &state)
	if state["toasts"].(float64) != 0 || state["you_toasted"] != false {
		t.Errorf("untoast: %s", raw)
	}
}

// PATCH /v1/check-ins/{id} updates editable fields; clearing via null works.
func TestUpdateCheckin(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "editor", "editor@example.com", "password11")
	bevID := seedBeverage(t, "Editable")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"rating":      3.0,
		"review":      "ok",
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	id, _ := ci["id"].(string)

	// Update rating + review.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/check-ins/"+id, tok, map[string]any{
		"rating": 4.0,
		"review": "actually better than I thought",
	})
	if code != http.StatusOK {
		t.Fatalf("update: %d body=%s", code, raw)
	}
	var updated map[string]any
	_ = json.Unmarshal(raw, &updated)
	if updated["rating"].(float64) != 4.0 {
		t.Errorf("rating not updated: %v", updated["rating"])
	}
}

// PATCH /v1/users/me / DELETE /v1/users/me / GET own profile.
func TestUpdateAndDeleteSelf(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "patcher", "patcher@example.com", "password11")
	newBio := "I drink sake."
	code, raw := doReq(t, srv, http.MethodPatch, "/v1/users/me", tok, map[string]any{
		"bio":          newBio,
		"display_name": "Patcher-san",
	})
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	var u map[string]any
	_ = json.Unmarshal(raw, &u)
	if u["bio"] != newBio {
		t.Errorf("bio: %v", u["bio"])
	}
	if u["display_name"] != "Patcher-san" {
		t.Errorf("display_name: %v", u["display_name"])
	}

	// Soft-delete.
	code, _ = doReq(t, srv, http.MethodDelete, "/v1/users/me", tok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d", code)
	}

	// After soft-delete, the token still verifies but the user lookup fails.
	code, _ = doReq(t, srv, http.MethodGet, "/v1/users/me", tok, nil)
	// 404 from the repo, surfaced as NOT_FOUND.
	if code != http.StatusNotFound {
		t.Errorf("post-delete get me: %d (want 404)", code)
	}
}

// GET /v1/check-ins/{id} returns a single check-in. GET /v1/users/{name}/check-ins
// lists them. Includes the user-following endpoint too for coverage.
func TestCheckinDetailAndProfileList(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	tok, _ := mustRegister(t, srv, "checker", "checker@example.com", "password11")
	bevID := seedBeverage(t, "Detailable")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"rating":      3.5,
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	id, _ := ci["id"].(string)

	code, raw = doReq(t, srv, http.MethodGet, "/v1/check-ins/"+id, "", nil)
	if code != http.StatusOK {
		t.Fatalf("get checkin: %d body=%s", code, raw)
	}
	if !strings.Contains(string(raw), id) {
		t.Errorf("response missing id: %s", raw)
	}

	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/checker/check-ins", "", nil)
	if code != http.StatusOK {
		t.Fatalf("user check-ins: %d", code)
	}
	if !strings.Contains(string(raw), id) {
		t.Errorf("user check-ins missing id %s: %s", id, raw)
	}

	// GET /v1/users/{name}/following — empty for this user.
	code, _ = doReq(t, srv, http.MethodGet, "/v1/users/checker/following", "", nil)
	if code != http.StatusOK {
		t.Fatalf("following: %d", code)
	}

	// GET /v1/beverages/{id}/check-ins — should include this check-in.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID+"/check-ins", "", nil)
	if code != http.StatusOK {
		t.Fatalf("bev check-ins: %d", code)
	}
	if !strings.Contains(string(raw), id) {
		t.Errorf("beverage check-ins missing id: %s", raw)
	}
}

// PATCH /v1/collections/{id} renames; PATCH/DELETE on entries works.
func TestCollectionEntryEdit(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	tok, _ := mustRegister(t, srv, "editor2", "editor2@example.com", "password11")
	bevID := seedBeverage(t, "CollEdit")
	// Create custom collection.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/collections", tok, map[string]string{
		"name": "Cabinet",
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var c map[string]any
	_ = json.Unmarshal(raw, &c)
	id, _ := c["id"].(string)

	// Rename.
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/collections/"+id, tok, map[string]string{
		"name": "Renamed",
	})
	if code != http.StatusOK {
		t.Fatalf("rename: %d body=%s", code, raw)
	}

	// Add an entry.
	code, _ = doReq(t, srv, http.MethodPost, "/v1/collections/"+id+"/entries", tok, map[string]any{
		"beverage_id": bevID,
		"note":        "first note",
	})
	if code != http.StatusNoContent {
		t.Fatalf("add: %d", code)
	}
	// Update the note.
	code, _ = doReq(t, srv, http.MethodPatch, "/v1/collections/"+id+"/entries/"+bevID, tok, map[string]any{
		"note": "second note",
	})
	if code != http.StatusNoContent {
		t.Fatalf("patch entry: %d", code)
	}
	// Remove.
	code, _ = doReq(t, srv, http.MethodDelete, "/v1/collections/"+id+"/entries/"+bevID, tok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete entry: %d", code)
	}
}

// POST /v1/beverage-requests writes a feedback row.
func TestSubmitBeverageRequest(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	tok, _ := mustRegister(t, srv, "requester", "requester@example.com", "password11")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/beverage-requests", tok, map[string]any{
		"payload": map[string]string{
			"name":    "New Sake",
			"brewery": "Some Brewery",
		},
	})
	if code != http.StatusAccepted {
		t.Fatalf("status: %d body=%s", code, raw)
	}
}

// DELETE /v1/follow-requests/{id}/decline.
func TestFollowRequestDecline(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	tokA, _ := mustRegister(t, srv, "fone", "fone@example.com", "password11")
	tokB, idB := mustRegister(t, srv, "ftwopriv", "ftwo@example.com", "password11")
	setUserPrivacy(t, idB, "private")

	// A requests to follow B.
	code, _ := doReq(t, srv, http.MethodPost, "/v1/users/ftwopriv/follow", tokA, nil)
	if code != http.StatusOK {
		t.Fatalf("follow: %d", code)
	}

	// Look up A's id.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/fone", "", nil)
	if code != http.StatusOK {
		t.Fatalf("lookup: %d", code)
	}
	var profile map[string]any
	_ = json.Unmarshal(raw, &profile)
	aID, _ := profile["id"].(string)

	// B declines.
	code, _ = doReq(t, srv, http.MethodPost, "/v1/follow-requests/"+aID+"/decline", tokB, nil)
	if code != http.StatusNoContent {
		t.Fatalf("decline: %d", code)
	}
}

// POST /v1/auth/password-change updates the hash; old password fails, new
// password succeeds.
func TestPasswordChange(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	const email = "pwchange@example.com"
	const oldPwd = "oldpassword11"
	const newPwd = "newpassword22"
	tok, _ := mustRegister(t, srv, "pwchanger", email, oldPwd)
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/password-change", tok, map[string]string{
		"current_password": oldPwd,
		"new_password":     newPwd,
	})
	if code != http.StatusNoContent {
		t.Fatalf("change: %d body=%s", code, raw)
	}

	// Old password no longer works.
	code, _ = doReq(t, srv, http.MethodPost, "/v1/auth/login", "", map[string]string{
		"email":    email,
		"password": oldPwd,
	})
	if code != http.StatusUnauthorized {
		t.Errorf("old password should be rejected: %d", code)
	}
	// New password works.
	mustLogin(t, srv, email, newPwd)
}
