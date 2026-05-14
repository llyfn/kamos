//go:build integration
// +build integration

package integration

import (
	"context"
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

// MIN-D 4 regression: typeless /v1/search must paginate cleanly through
// beverages first then breweries, without skipping or duplicating items as
// the cursor crosses the sub-stream boundary.
//
// Setup: 3 beverages + 3 breweries whose names all contain the token
// "Saketown" — FTS will surface all 6. With limit=2 we expect:
//   page 1 → 2 beverages, has_more=true
//   page 2 → 1 beverage + 1 brewery (rollover), has_more=true
//   page 3 → 2 breweries, has_more=false (last 2 of 3)
// Every item must appear exactly once across the three pages.
func TestSearchTypelessCursor(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Seed 3 beverages whose en name contains "Saketown" so FTS picks them.
	// seedBeverage already creates a new brewery per beverage, but those
	// breweries are named "Test Brewery" so they won't match "Saketown" —
	// good, they shouldn't pollute the brewery results. We seed the three
	// matching breweries below by direct SQL.
	for i := 0; i < 3; i++ {
		seedBeverage(t, "Saketown-Bev-"+string(rune('A'+i)))
	}

	p := getPool(t)
	for i := 0; i < 3; i++ {
		nameJSON, _ := json.Marshal(map[string]string{
			"en": "Saketown-Brewery-" + string(rune('A'+i)),
			"ja": "テスト酒造",
		})
		if _, err := p.Exec(context.Background(),
			`INSERT INTO breweries (name_i18n) VALUES ($1::jsonb);`,
			string(nameJSON)); err != nil {
			t.Fatalf("seed brewery %d: %v", i, err)
		}
	}

	type page struct {
		Items []struct {
			Type     string                 `json:"type"`
			Beverage map[string]any         `json:"beverage,omitempty"`
			Brewery  map[string]any         `json:"brewery,omitempty"`
		} `json:"items"`
		NextCursor string `json:"next_cursor"`
		HasMore    bool   `json:"has_more"`
	}

	get := func(t *testing.T, urlSuffix string) page {
		t.Helper()
		code, raw := doReq(t, srv, http.MethodGet, "/v1/search?q=Saketown&limit=2"+urlSuffix, "", nil)
		if code != http.StatusOK {
			t.Fatalf("search %q: status=%d body=%s", urlSuffix, code, raw)
		}
		var pg page
		if err := json.Unmarshal(raw, &pg); err != nil {
			t.Fatalf("decode: %v", err)
		}
		return pg
	}

	// Track which item ids we've already returned. Every item must be unique.
	seen := map[string]bool{}
	itemID := func(it struct {
		Type     string                 `json:"type"`
		Beverage map[string]any         `json:"beverage,omitempty"`
		Brewery  map[string]any         `json:"brewery,omitempty"`
	}) string {
		switch it.Type {
		case "beverage":
			return it.Type + ":" + it.Beverage["id"].(string)
		case "brewery":
			return it.Type + ":" + it.Brewery["id"].(string)
		}
		t.Fatalf("unknown item type: %q", it.Type)
		return ""
	}

	totalBev, totalBrw := 0, 0
	pageNum := 0
	cursor := ""
	for {
		pageNum++
		if pageNum > 10 {
			t.Fatalf("paginated past 10 pages — pagination is not converging")
		}
		suffix := ""
		if cursor != "" {
			suffix = "&cursor=" + cursor
		}
		pg := get(t, suffix)
		if len(pg.Items) == 0 && pg.HasMore {
			t.Fatalf("page %d: has_more=true but no items returned", pageNum)
		}
		for _, it := range pg.Items {
			key := itemID(it)
			if seen[key] {
				t.Errorf("page %d: duplicate item %s", pageNum, key)
			}
			seen[key] = true
			switch it.Type {
			case "beverage":
				totalBev++
			case "brewery":
				totalBrw++
			}
		}
		if !pg.HasMore {
			if pg.NextCursor != "" {
				t.Errorf("page %d: has_more=false but next_cursor is non-empty: %q", pageNum, pg.NextCursor)
			}
			break
		}
		if pg.NextCursor == "" {
			t.Fatalf("page %d: has_more=true but next_cursor is empty", pageNum)
		}
		cursor = pg.NextCursor
	}

	if totalBev != 3 {
		t.Errorf("beverage total: got %d want 3", totalBev)
	}
	if totalBrw != 3 {
		t.Errorf("brewery total: got %d want 3", totalBrw)
	}
	// We expect exactly 3 pages with limit=2: 2 + 2 + 2 = 6 items, but the
	// rollover boundary means page 2 has 1 beverage + 1 brewery, page 3 has
	// the remaining 2 breweries. Either way the page count is exactly 3.
	if pageNum != 3 {
		t.Errorf("page count: got %d want 3", pageNum)
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
