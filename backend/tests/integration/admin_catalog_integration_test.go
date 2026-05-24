//go:build integration
// +build integration

// Stage 8 — admin catalog CRUD (POST/PATCH/DELETE/restore for both
// /v1/admin/beverages and /v1/admin/breweries) + admin user exact-match
// search.
//
// Each end-to-end test:
//  1. registers + promotes an admin user
//  2. drives the new admin route
//  3. asserts the row visible/invisible on the corresponding public
//     endpoint
//  4. asserts the moderation_log row was written in the same tx
//
// Migration prerequisites (014 + 015) must be applied for these to pass
// — the deleted_at column and the expanded moderation_action_type /
// moderation_target_type enums are required.
package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

// seedCategoryID returns the UUID of the seeded `nihonshu` category.
func seedCategoryID(t *testing.T) string {
	t.Helper()
	var id string
	if err := getPool(t).QueryRow(context.Background(),
		`SELECT id FROM beverage_categories WHERE slug='nihonshu' LIMIT 1;`).Scan(&id); err != nil {
		t.Fatalf("seed category: %v", err)
	}
	return id
}

// seedBreweryRow inserts a brewery directly via SQL and returns the id.
// Used as a precondition for beverage tests; the admin endpoints have
// their own dedicated create flow exercised below.
func seedBreweryRow(t *testing.T, enName, jaName string) string {
	t.Helper()
	nameJSON, _ := json.Marshal(map[string]string{"en": enName, "ja": jaName})
	var id string
	if err := getPool(t).QueryRow(context.Background(),
		`INSERT INTO breweries (name_i18n) VALUES ($1::jsonb) RETURNING id;`,
		string(nameJSON)).Scan(&id); err != nil {
		t.Fatalf("seed brewery: %v", err)
	}
	return id
}

// TestAdminBrewery_CreateListSearch — admin creates → public list
// includes the new row → admin FTS search finds it.
func TestAdminBrewery_CreateListSearch(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "cat_admin", "cat_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Create.
	// Migration 016: prefecture is now a slug FK into the `prefectures`
	// reference table; the handler resolves it before the INSERT.
	createBody := map[string]any{
		"name_i18n":       map[string]string{"en": "Dassai Kura", "ja": "獺祭蔵"},
		"prefecture_slug": "yamaguchi",
		"founded_year":    1948,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/breweries", adminTok, createBody)
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var created map[string]any
	_ = json.Unmarshal(raw, &created)
	breweryID, _ := created["id"].(string)
	if breweryID == "" {
		t.Fatalf("no id in create response: %s", raw)
	}

	// Migration 016: the create response nests a `prefecture` object
	// (Prefecture → embedded Region) resolved from the submitted slug.
	pref, ok := created["prefecture"].(map[string]any)
	if !ok {
		t.Fatalf("create response missing nested prefecture: %s", raw)
	}
	if got, _ := pref["slug"].(string); got != "yamaguchi" {
		t.Errorf("prefecture.slug = %q, want yamaguchi", got)
	}
	prefName, _ := pref["name"].(map[string]any)
	if got, _ := prefName["en"].(string); got != "Yamaguchi" {
		t.Errorf("prefecture.name.en = %q, want Yamaguchi", got)
	}
	region, _ := pref["region"].(map[string]any)
	if got, _ := region["slug"].(string); got != "chugoku" {
		t.Errorf("prefecture.region.slug = %q, want chugoku", got)
	}

	// Public list returns the new row.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/breweries", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if !hasID(page.Items, breweryID) {
		t.Errorf("public list missing new brewery %s", breweryID)
	}

	// Admin FTS search hits the GIN index.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/breweries?q=Dassai", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("admin search: %d body=%s", code, raw)
	}
	_ = json.Unmarshal(raw, &page)
	if !hasID(page.Items, breweryID) {
		t.Errorf("admin FTS missed: %s", raw)
	}

	// moderation_log row written with target_type='brewery' action='create'.
	var count int
	if err := getPool(t).QueryRow(context.Background(), `
SELECT COUNT(*) FROM moderation_log
WHERE target_type::text='brewery' AND target_id=$1::uuid
  AND action::text='create' AND moderator_id=$2;`,
		breweryID, adminID).Scan(&count); err != nil {
		t.Fatalf("log count: %v", err)
	}
	if count != 1 {
		t.Errorf("moderation_log count=%d, want 1", count)
	}
}

// TestAdminBrewery_PatchAndRestore — patch then soft-delete then
// restore; verify deleted_at flips and public list excludes the
// tombstoned row.
func TestAdminBrewery_SoftDeleteAndRestore(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "del_admin", "del_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	breweryID := seedBreweryRow(t, "Soon Gone Kura", "もうすぐ消える酒造")

	// Soft-delete.
	code, raw := doReq(t, srv, http.MethodDelete, "/v1/admin/breweries/"+breweryID, adminTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d body=%s", code, raw)
	}

	// Public list excludes.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/breweries", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list: %d", code)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if hasID(page.Items, breweryID) {
		t.Errorf("public list still has tombstoned brewery: %s", raw)
	}

	// Admin list (default) excludes.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/breweries", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("admin list default: %d", code)
	}
	_ = json.Unmarshal(raw, &page)
	if hasID(page.Items, breweryID) {
		t.Errorf("admin list (default) included tombstoned brewery")
	}

	// Admin list with include_deleted=1 includes.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/breweries?include_deleted=1", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("admin list include_deleted: %d", code)
	}
	_ = json.Unmarshal(raw, &page)
	if !hasID(page.Items, breweryID) {
		t.Errorf("admin list include_deleted missing tombstoned brewery: %s", raw)
	}

	// Restore.
	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/breweries/"+breweryID+"/restore", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("restore: %d body=%s", code, raw)
	}

	// Public list now includes again.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/breweries", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list after restore: %d", code)
	}
	_ = json.Unmarshal(raw, &page)
	if !hasID(page.Items, breweryID) {
		t.Errorf("public list still missing restored brewery: %s", raw)
	}

	// moderation_log has both soft_delete + restore for this brewery.
	var rows int
	if err := getPool(t).QueryRow(context.Background(), `
SELECT COUNT(*) FROM moderation_log
WHERE target_type::text='brewery' AND target_id=$1::uuid
  AND action::text IN ('soft_delete','restore');`,
		breweryID).Scan(&rows); err != nil {
		t.Fatalf("log query: %v", err)
	}
	if rows != 2 {
		t.Errorf("moderation_log row count=%d, want 2 (soft_delete+restore)", rows)
	}
}

// TestAdminBrewery_SoftDeletePreflight — DELETE returns 409
// BREWERY_HAS_LIVE_BEVERAGES when a live beverage references the
// brewery.
func TestAdminBrewery_SoftDeletePreflight(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "pre_admin", "pre_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Seed brewery + beverage.
	breweryID := seedBreweryRow(t, "Preflight Kura", "プリ蔵")
	catID := seedCategoryID(t)
	nameJSON, _ := json.Marshal(map[string]string{"en": "Child Sake", "ja": "子供酒"})
	var bevID string
	if err := getPool(t).QueryRow(context.Background(), `
INSERT INTO beverages (brewery_id, category_id, category_slug, name_i18n)
VALUES ($1, $2, 'nihonshu', $3::jsonb) RETURNING id;`,
		breweryID, catID, string(nameJSON)).Scan(&bevID); err != nil {
		t.Fatalf("seed beverage: %v", err)
	}

	code, raw := doReq(t, srv, http.MethodDelete, "/v1/admin/breweries/"+breweryID, adminTok, nil)
	if code != http.StatusConflict {
		t.Fatalf("delete: %d body=%s (want 409)", code, raw)
	}
	var e errBodyShape
	_ = json.Unmarshal(raw, &e)
	if e.Code != "BREWERY_HAS_LIVE_BEVERAGES" {
		t.Errorf("code=%q want BREWERY_HAS_LIVE_BEVERAGES", e.Code)
	}

	// Tombstone the child beverage, then the brewery delete succeeds.
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/admin/beverages/"+bevID, adminTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete child: %d body=%s", code, raw)
	}
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/admin/breweries/"+breweryID, adminTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete brewery: %d body=%s", code, raw)
	}
}

// TestAdminBeverage_CreateUpdateDeleteRestore — full lifecycle.
func TestAdminBeverage_CreateUpdateDeleteRestore(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "bev_admin", "bev_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	breweryID := seedBreweryRow(t, "Test Brewery", "テスト酒造")
	catID := seedCategoryID(t)

	// Create.
	createBody := map[string]any{
		"brewery_id":  breweryID,
		"category_id": catID,
		"name_i18n":   map[string]string{"en": "Junmai Nu", "ja": "純米ヌ"},
		"abv":         15.5,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/beverages", adminTok, createBody)
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var created map[string]any
	_ = json.Unmarshal(raw, &created)
	bevID, _ := created["id"].(string)
	if bevID == "" {
		t.Fatalf("no id in create response: %s", raw)
	}

	// Public list shows the new beverage.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/beverages", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list: %d", code)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if !hasID(page.Items, bevID) {
		t.Errorf("public list missing new beverage %s", bevID)
	}

	// PATCH abv. Migration 016 dropped beverages.prefecture / region —
	// the patch only adjusts the per-beverage abv now; brewery-level
	// locality is curated via PATCH /v1/admin/breweries/{id}.
	patchBody := map[string]any{"abv": 16.0}
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/admin/beverages/"+bevID, adminTok, patchBody)
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}

	// Verify the patch landed via the public detail endpoint.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("public detail: %d body=%s", code, raw)
	}
	var detail map[string]any
	_ = json.Unmarshal(raw, &detail)
	if abv, ok := detail["abv"].(float64); !ok || abv != 16.0 {
		t.Errorf("abv after patch = %v, want 16.0", detail["abv"])
	}

	// DELETE.
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/admin/beverages/"+bevID, adminTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d body=%s", code, raw)
	}

	// Public detail now 404s.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusNotFound {
		t.Fatalf("public detail after delete: %d body=%s (want 404)", code, raw)
	}

	// Public list excludes.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/beverages", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list: %d", code)
	}
	_ = json.Unmarshal(raw, &page)
	if hasID(page.Items, bevID) {
		t.Errorf("public list still includes tombstoned beverage")
	}

	// Admin list with include_deleted=1 includes.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/beverages?include_deleted=1", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("admin list include_deleted: %d", code)
	}
	_ = json.Unmarshal(raw, &page)
	if !hasID(page.Items, bevID) {
		t.Errorf("admin list include_deleted missing tombstoned beverage")
	}

	// Restore.
	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/beverages/"+bevID+"/restore", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("restore: %d body=%s", code, raw)
	}

	// Public detail now 200s again.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/beverages/"+bevID, "", nil)
	if code != http.StatusOK {
		t.Fatalf("public detail after restore: %d body=%s", code, raw)
	}

	// moderation_log has create, update, soft_delete, restore.
	var actions []string
	rows, err := getPool(t).Query(context.Background(), `
SELECT action::text FROM moderation_log
WHERE target_type::text='beverage' AND target_id=$1::uuid
ORDER BY created_at ASC;`, bevID)
	if err != nil {
		t.Fatalf("log query: %v", err)
	}
	defer rows.Close()
	for rows.Next() {
		var a string
		_ = rows.Scan(&a)
		actions = append(actions, a)
	}
	if len(actions) != 4 {
		t.Errorf("moderation_log entries=%v, want 4 (create+update+soft_delete+restore)", actions)
	}
}

// TestAdminBeverage_FTSSearch — admin FTS hits the GIN index.
func TestAdminBeverage_FTSSearch(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "fts_admin", "fts_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Seed two beverages — one matching the search term.
	hit := seedBeverageWithNames(t, "Hakkaisan Junmai", "八海山純米", "")
	miss := seedBeverageWithNames(t, "Other Sake", "他の酒", "")

	code, raw := doReq(t, srv, http.MethodGet, "/v1/admin/beverages?q=Hakkaisan", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("admin FTS: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if !hasID(page.Items, hit) {
		t.Errorf("FTS missed hit %s", hit)
	}
	if hasID(page.Items, miss) {
		t.Errorf("FTS false-positive on %s", miss)
	}
}

// TestAdminBeverage_FindByID — `?id=` short-circuits and returns the
// single hit.
func TestAdminBeverage_FindByID(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "idfind_admin", "idfind_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	bev := seedBeverage(t, "FindMeByID")

	code, raw := doReq(t, srv, http.MethodGet, "/v1/admin/beverages?id="+bev, adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("find by id: %d body=%s", code, raw)
	}
	var page struct {
		Items   []map[string]any `json:"items"`
		HasMore bool             `json:"has_more"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 || page.Items[0]["id"] != bev {
		t.Errorf("find by id mismatch: %s", raw)
	}
	if page.HasMore {
		t.Errorf("has_more should be false for id lookup")
	}
}

// TestAdminUsers_ExactMatchSearch — username/email/id exact lookups
// hit the case-insensitive indexes.
func TestAdminUsers_ExactMatchSearch(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "search_admin", "search_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Seed a target user.
	_, targetID := mustRegister(t, srv, "Yamamoto", "Yama@example.com", "password-123")

	// 1) Exact match by uppercase email resolves via LOWER().
	code, raw := doReq(t, srv, http.MethodGet, "/v1/admin/users?email=YAMA@example.com", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("email search: %d body=%s", code, raw)
	}
	var page struct {
		Items   []map[string]any `json:"items"`
		HasMore bool             `json:"has_more"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 || page.Items[0]["id"] != targetID {
		t.Errorf("email exact: %s", raw)
	}

	// 2) Mixed-case username resolves.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/users?username=YaMaMoTo", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("username search: %d body=%s", code, raw)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 || page.Items[0]["id"] != targetID {
		t.Errorf("username exact: %s", raw)
	}

	// 3) UUID exact resolves.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/users?id="+targetID, adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("id search: %d body=%s", code, raw)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 || page.Items[0]["id"] != targetID {
		t.Errorf("id exact: %s", raw)
	}

	// 4) A miss (UUID-shaped but not present) returns empty.
	code, raw = doReq(t, srv, http.MethodGet,
		"/v1/admin/users?id=00000000-0000-0000-0000-000000000000", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("id miss: %d", code)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 0 {
		t.Errorf("id miss should be empty: %s", raw)
	}

	// 5) Partial substring (not exact) returns empty.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/users?username=Yama", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("substring: %d", code)
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 0 {
		t.Errorf("substring should not match exact: %s", raw)
	}
}

// hasID is a tiny helper for "does this slice contain a row with id == want?"
func hasID(items []map[string]any, want string) bool {
	for _, it := range items {
		if id, _ := it["id"].(string); id == want {
			return true
		}
	}
	return false
}

// TestReferenceRegions_Shape — GET /v1/reference/regions returns the
// full 8-region × 47-prefecture seed graph in canonical sort order.
//
// Asserts:
//   - top-level array length is 8 (Japan's 8 traditional regions)
//   - regions are ordered by sort_order (Hokkaido first, Kyushu_Okinawa
//     last per migration 016 seed data)
//   - every region embeds at least one prefecture
//   - total prefecture count across all regions is 47
//   - prefectures within each region are ordered by sort_order
func TestReferenceRegions_Shape(t *testing.T) {
	srv := newServer(t)
	defer srv.Close()

	code, raw := doReq(t, srv, http.MethodGet, "/v1/reference/regions", "", nil)
	if code != http.StatusOK {
		t.Fatalf("regions: %d body=%s", code, raw)
	}

	var regions []map[string]any
	if err := json.Unmarshal(raw, &regions); err != nil {
		t.Fatalf("decode regions: %v body=%s", err, raw)
	}
	if len(regions) != 8 {
		t.Fatalf("regions len=%d, want 8", len(regions))
	}

	// First region is Hokkaido, last is Kyushu_Okinawa (canonical seed).
	if got, _ := regions[0]["slug"].(string); got != "hokkaido" {
		t.Errorf("regions[0].slug = %q, want hokkaido", got)
	}
	if got, _ := regions[7]["slug"].(string); got != "kyushu_okinawa" {
		t.Errorf("regions[7].slug = %q, want kyushu_okinawa", got)
	}

	// sort_order is monotonically non-decreasing across the regions array.
	var prevRegion float64
	for i, r := range regions {
		so, ok := r["sort_order"].(float64)
		if !ok {
			t.Fatalf("regions[%d] missing sort_order: %v", i, r)
		}
		if i > 0 && so < prevRegion {
			t.Errorf("regions[%d].sort_order=%v < regions[%d].sort_order=%v (not sorted)",
				i, so, i-1, prevRegion)
		}
		prevRegion = so
	}

	// Aggregate prefecture counts + per-region sort_order monotonicity.
	totalPrefs := 0
	for i, r := range regions {
		prefs, ok := r["prefectures"].([]any)
		if !ok || len(prefs) == 0 {
			t.Errorf("regions[%d] (%v) has no prefectures", i, r["slug"])
			continue
		}
		var prevPref float64
		for j, pAny := range prefs {
			p, _ := pAny.(map[string]any)
			so, ok := p["sort_order"].(float64)
			if !ok {
				t.Errorf("regions[%d].prefectures[%d] missing sort_order: %v", i, j, p)
				continue
			}
			if j > 0 && so < prevPref {
				t.Errorf("regions[%d].prefectures[%d].sort_order=%v < prev %v (not sorted)",
					i, j, so, prevPref)
			}
			prevPref = so
		}
		totalPrefs += len(prefs)
	}
	if totalPrefs != 47 {
		t.Errorf("total prefectures = %d, want 47", totalPrefs)
	}
}

// TestAdminBrewery_InvalidPrefectureSlug — POST and PATCH both return
// 422 INVALID_PREFECTURE_SLUG when the slug doesn't resolve. Also
// verifies that an explicit empty slug on Create (which the OpenAPI
// `^[a-z0-9_]+$` pattern disallows) is rejected with the same code so
// the contract and the runtime agree.
func TestAdminBrewery_InvalidPrefectureSlug(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "pref_admin", "pref_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// 1) POST with an unknown slug → 422 INVALID_PREFECTURE_SLUG.
	createBody := map[string]any{
		"name_i18n":       map[string]string{"en": "Atlantis Kura", "ja": "アトランティス酒造"},
		"prefecture_slug": "atlantis",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/breweries", adminTok, createBody)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("create unknown slug: %d body=%s (want 422)", code, raw)
	}
	var e errBodyShape
	_ = json.Unmarshal(raw, &e)
	if e.Code != "INVALID_PREFECTURE_SLUG" {
		t.Errorf("create code=%q want INVALID_PREFECTURE_SLUG (body=%s)", e.Code, raw)
	}

	// 2) PATCH with an unknown slug on a real brewery → same 422.
	breweryID := seedBreweryRow(t, "Patch Target", "パッチ対象")
	patchBody := map[string]any{"prefecture_slug": "atlantis"}
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/admin/breweries/"+breweryID, adminTok, patchBody)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("patch unknown slug: %d body=%s (want 422)", code, raw)
	}
	_ = json.Unmarshal(raw, &e)
	if e.Code != "INVALID_PREFECTURE_SLUG" {
		t.Errorf("patch code=%q want INVALID_PREFECTURE_SLUG (body=%s)", e.Code, raw)
	}

	// 3) POST with explicit empty `prefecture_slug: ""` → 422
	// INVALID_PREFECTURE_SLUG (OpenAPI Create pattern is `^[a-z0-9_]+$`,
	// no empty). The contract is "omit the field if no prefecture is
	// intended".
	emptyBody := map[string]any{
		"name_i18n":       map[string]string{"en": "Empty Slug Kura", "ja": "空スラッグ酒造"},
		"prefecture_slug": "",
	}
	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/breweries", adminTok, emptyBody)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("create empty slug: %d body=%s (want 422)", code, raw)
	}
	_ = json.Unmarshal(raw, &e)
	if e.Code != "INVALID_PREFECTURE_SLUG" {
		t.Errorf("create empty code=%q want INVALID_PREFECTURE_SLUG (body=%s)", e.Code, raw)
	}
}
