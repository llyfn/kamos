//go:build integration
// +build integration

// GET /v1/users/{username}/beverages. Distinct-beverage
// aggregation page across a single user's check-ins. Coverage focuses
// on the aggregation correctness, the filter axes, sort default, the
// cursor stability, and the privacy gate.

package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// seedShochuBeverage seeds a separate beverage in the `shochu` category
// for the category-filter test. Mirrors seedBeverage but inserts a
// shochu row so the filter has something to discriminate against.
func seedShochuBeverage(t *testing.T, name string) string {
	t.Helper()
	p := getPool(t)
	ctx := context.Background()
	var catID string
	if err := p.QueryRow(ctx,
		`SELECT id FROM beverage_categories WHERE slug = 'shochu' LIMIT 1;`).Scan(&catID); err != nil {
		t.Fatalf("look up shochu: %v", err)
	}
	nameJSON, _ := json.Marshal(map[string]string{"en": name, "ja": name})
	producerNameJSON, _ := json.Marshal(map[string]string{"en": "Shochu Producer", "ja": "焼酎酒造"})

	var producerID string
	if err := p.QueryRow(ctx, `
INSERT INTO producers (name_i18n) VALUES ($1::jsonb) RETURNING id;`, string(producerNameJSON)).Scan(&producerID); err != nil {
		t.Fatalf("seed shochu producer: %v", err)
	}
	var bevID string
	if err := p.QueryRow(ctx, `
INSERT INTO beverages (producer_id, category_id, category_slug, name_i18n)
VALUES ($1, $2, 'shochu', $3::jsonb) RETURNING id;`,
		producerID, catID, string(nameJSON)).Scan(&bevID); err != nil {
		t.Fatalf("seed shochu beverage: %v", err)
	}
	return bevID
}

// createCheckinWithRatingRaw posts a check-in with the supplied rating.
// `rating` < 0 means "no rating" — the request omits the rating field
// entirely so the column lands NULL.
func createCheckinWithRatingRaw(t *testing.T, srv *httptest.Server, tok, bevID string, rating float64) string {
	t.Helper()
	body := map[string]any{"beverage_id": bevID}
	if rating >= 0 {
		body["rating"] = rating
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, body)
	if code != http.StatusCreated {
		t.Fatalf("create check-in (rating=%v): %d body=%s", rating, code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	id, _ := ci["id"].(string)
	if id == "" {
		t.Fatalf("missing check-in id: %s", raw)
	}
	return id
}

// TestUserBeveragesAggregation — user checks in beverage A three times
// (rating 4.0, 4.5, no-rating) and beverage B once (rating 3.5). The
// response page has 2 rows; A's user_avg = mean(4.0, 4.5) = 4.25 and
// user_count = 3 (the no-rating row still counts toward the "I tried
// this" total); B's user_avg = 3.5 and user_count = 1.
func TestUserBeveragesAggregation(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevA := seedBeverage(t, "Beverage Aggregate A")
	bevB := seedBeverage(t, "Beverage Aggregate B")
	tok, _ := mustRegister(t, srv, "agguser", "agg@example.com", "password-123")

	// A: three check-ins (4.0, 4.5, no-rating).
	createCheckinWithRatingRaw(t, srv, tok, bevA, 4.0)
	createCheckinWithRatingRaw(t, srv, tok, bevA, 4.5)
	createCheckinWithRatingRaw(t, srv, tok, bevA, -1)
	// B: one check-in (3.5).
	createCheckinWithRatingRaw(t, srv, tok, bevB, 3.5)

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/agguser/beverages", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			Beverage struct {
				ID string `json:"id"`
			} `json:"beverage"`
			UserAvgRating    *float64 `json:"user_avg_rating"`
			UserCheckinCount int      `json:"user_checkin_count"`
		} `json:"items"`
		HasMore bool `json:"has_more"`
	}
	if err := json.Unmarshal(raw, &page); err != nil {
		t.Fatalf("decode: %v raw=%s", err, raw)
	}
	if len(page.Items) != 2 {
		t.Fatalf("want 2 rows, got %d: %s", len(page.Items), raw)
	}
	// Default sort is rating DESC. A's avg = 4.25 > B's avg = 3.5,
	// so A is first.
	if page.Items[0].Beverage.ID != bevA {
		t.Errorf("row 0 beverage = %s, want A=%s", page.Items[0].Beverage.ID, bevA)
	}
	if page.Items[0].UserCheckinCount != 3 {
		t.Errorf("A check-in count = %d, want 3", page.Items[0].UserCheckinCount)
	}
	if page.Items[0].UserAvgRating == nil || floatNear(*page.Items[0].UserAvgRating, 4.25, 0.001) == false {
		t.Errorf("A user_avg = %v, want ~4.25", page.Items[0].UserAvgRating)
	}
	if page.Items[1].Beverage.ID != bevB {
		t.Errorf("row 1 beverage = %s, want B=%s", page.Items[1].Beverage.ID, bevB)
	}
	if page.Items[1].UserCheckinCount != 1 {
		t.Errorf("B check-in count = %d, want 1", page.Items[1].UserCheckinCount)
	}
	if page.Items[1].UserAvgRating == nil || floatNear(*page.Items[1].UserAvgRating, 3.5, 0.001) == false {
		t.Errorf("B user_avg = %v, want 3.5", page.Items[1].UserAvgRating)
	}
}

// TestUserBeveragesFilterByCategory — user has check-ins on a
// nihonshu and a shochu beverage. `?category=nihonshu` returns only
// the nihonshu row.
func TestUserBeveragesFilterByCategory(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	nihonshuID := seedBeverage(t, "Nihonshu One")
	shochuID := seedShochuBeverage(t, "Shochu One")
	tok, _ := mustRegister(t, srv, "catfilter", "cf@example.com", "password-123")
	createCheckinWithRatingRaw(t, srv, tok, nihonshuID, 4.0)
	createCheckinWithRatingRaw(t, srv, tok, shochuID, 3.0)

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/catfilter/beverages?category=nihonshu", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	if !strings.Contains(string(raw), nihonshuID) {
		t.Errorf("response missing nihonshu beverage: %s", raw)
	}
	if strings.Contains(string(raw), shochuID) {
		t.Errorf("response unexpectedly contains shochu beverage: %s", raw)
	}
}

// TestUserBeveragesSortDefault — rating DESC NULLS LAST.
// User has three beverages: A (5.0), B (3.5), C (no rating across all
// check-ins). Expected order: A, B, C.
func TestUserBeveragesSortDefault(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	bevA := seedBeverage(t, "Sort Default A")
	bevB := seedBeverage(t, "Sort Default B")
	bevC := seedBeverage(t, "Sort Default C")
	tok, _ := mustRegister(t, srv, "sortuser", "sd@example.com", "password-123")
	createCheckinWithRatingRaw(t, srv, tok, bevA, 5.0)
	createCheckinWithRatingRaw(t, srv, tok, bevB, 3.5)
	createCheckinWithRatingRaw(t, srv, tok, bevC, -1)

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/sortuser/beverages", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			Beverage struct{ ID string } `json:"beverage"`
		} `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 3 {
		t.Fatalf("want 3 rows, got %d: %s", len(page.Items), raw)
	}
	want := []string{bevA, bevB, bevC}
	for i, w := range want {
		if page.Items[i].Beverage.ID != w {
			t.Errorf("row %d = %s, want %s", i, page.Items[i].Beverage.ID, w)
		}
	}
}

// TestUserBeveragesCursor — page size 2, fetch first page + cursor,
// fetch next page, assert no duplicates and the union covers all 3.
func TestUserBeveragesCursor(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	ids := []string{
		seedBeverage(t, "Cursor A"),
		seedBeverage(t, "Cursor B"),
		seedBeverage(t, "Cursor C"),
	}
	tok, _ := mustRegister(t, srv, "curuser", "cu@example.com", "password-123")
	// Ratings 5.0, 4.0, 3.0 so the default rating DESC sort returns
	// A, B, C in that order.
	createCheckinWithRatingRaw(t, srv, tok, ids[0], 5.0)
	createCheckinWithRatingRaw(t, srv, tok, ids[1], 4.0)
	createCheckinWithRatingRaw(t, srv, tok, ids[2], 3.0)

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/curuser/beverages?limit=2", "", nil)
	if code != http.StatusOK {
		t.Fatalf("page1: %d body=%s", code, raw)
	}
	var p1 struct {
		Items []struct {
			Beverage struct{ ID string } `json:"beverage"`
		} `json:"items"`
		NextCursor string `json:"next_cursor"`
		HasMore    bool   `json:"has_more"`
	}
	_ = json.Unmarshal(raw, &p1)
	if len(p1.Items) != 2 || !p1.HasMore || p1.NextCursor == "" {
		t.Fatalf("page1 unexpected shape: %s", raw)
	}

	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/curuser/beverages?limit=2&cursor="+p1.NextCursor, "", nil)
	if code != http.StatusOK {
		t.Fatalf("page2: %d body=%s", code, raw)
	}
	var p2 struct {
		Items []struct {
			Beverage struct{ ID string } `json:"beverage"`
		} `json:"items"`
		HasMore bool `json:"has_more"`
	}
	_ = json.Unmarshal(raw, &p2)
	if len(p2.Items) != 1 {
		t.Fatalf("page2 want 1 row, got %d: %s", len(p2.Items), raw)
	}
	if p2.HasMore {
		t.Errorf("page2 has_more should be false")
	}

	// Union must be all 3 distinct ids, no duplicates.
	seen := map[string]bool{}
	for _, r := range p1.Items {
		seen[r.Beverage.ID] = true
	}
	for _, r := range p2.Items {
		if seen[r.Beverage.ID] {
			t.Errorf("duplicate id across pages: %s", r.Beverage.ID)
		}
		seen[r.Beverage.ID] = true
	}
	if len(seen) != 3 {
		t.Errorf("union size = %d, want 3", len(seen))
	}
}

// TestUserBeveragesPrivateProfile — private user, viewer not following
// → 403 PRIVATE_PROFILE.
func TestUserBeveragesPrivateProfile(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_ = seedBeverage(t, "Private Beverage")
	_, ownerID := mustRegister(t, srv, "shy", "shy@example.com", "password-123")
	setUserPrivacy(t, ownerID, "private")
	viewerTok, _ := mustRegister(t, srv, "nosy", "nosy@example.com", "password-123")

	// Anonymous viewer.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/shy/beverages", "", nil)
	if code != http.StatusForbidden {
		t.Errorf("anonymous: %d body=%s, want 403", code, raw)
	}
	// Authed non-follower.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/shy/beverages", viewerTok, nil)
	if code != http.StatusForbidden {
		t.Errorf("non-follower: %d body=%s, want 403", code, raw)
	}
	var e map[string]any
	_ = json.Unmarshal(raw, &e)
	if e["code"] != "PRIVATE_PROFILE" {
		t.Errorf("code: %v want PRIVATE_PROFILE", e["code"])
	}
}

// floatNear is a small tolerance helper.
func floatNear(a, b, eps float64) bool {
	if a-b < eps && b-a < eps {
		return true
	}
	return false
}
