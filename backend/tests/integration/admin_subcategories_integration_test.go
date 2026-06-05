//go:build integration
// +build integration

// Slice C — admin CRUD + public read for beverage_subcategories.
package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

// TestAdminSubcategory_CreateListUpdateDelete exercises the round-trip:
// admin creates a subcategory → public list includes it → admin patches
// the row → admin soft-deletes → public list excludes → admin restore.
func TestAdminSubcategory_CreateListUpdateDelete(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "sub_admin", "sub_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Create.
	createBody := map[string]any{
		"category_slug": "nihonshu",
		"slug":          "yamahai",
		"name_i18n":     map[string]string{"en": "Yamahai", "ja": "山廃", "ko": "야마하이"},
		"sort_order":    25,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/subcategories", adminTok, createBody)
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var created map[string]any
	_ = json.Unmarshal(raw, &created)
	id, _ := created["id"].(string)
	if id == "" {
		t.Fatalf("no id in create response: %s", raw)
	}
	if got, _ := created["category_slug"].(string); got != "nihonshu" {
		t.Errorf("create response: category_slug=%q, want nihonshu", got)
	}

	// Public list (no auth) includes the new row.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/subcategories?category=nihonshu", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list: %d body=%s", code, raw)
	}
	var pubList []map[string]any
	_ = json.Unmarshal(raw, &pubList)
	if !hasID(pubList, id) {
		t.Errorf("public list missing new subcategory %s: %s", id, raw)
	}

	// Admin list (incl. live) also sees it.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/admin/subcategories?category=nihonshu", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("admin list: %d body=%s", code, raw)
	}
	var adminList []map[string]any
	_ = json.Unmarshal(raw, &adminList)
	if !hasID(adminList, id) {
		t.Errorf("admin list missing new subcategory")
	}

	// PATCH the sort_order + name.
	patchBody := map[string]any{
		"sort_order": 35,
		"name_i18n":  map[string]string{"en": "Yamahai-shikomi", "ja": "山廃仕込", "ko": "야마하이"},
	}
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/admin/subcategories/"+id, adminTok, patchBody)
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	var patched map[string]any
	_ = json.Unmarshal(raw, &patched)
	if got, _ := patched["sort_order"].(float64); int(got) != 35 {
		t.Errorf("patched sort_order=%v, want 35", patched["sort_order"])
	}

	// Soft-delete (no beverages reference this row yet).
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/admin/subcategories/"+id, adminTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d body=%s", code, raw)
	}

	// Public list excludes the tombstoned row.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/subcategories?category=nihonshu", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list after delete: %d", code)
	}
	_ = json.Unmarshal(raw, &pubList)
	if hasID(pubList, id) {
		t.Errorf("public list still contains tombstoned subcategory %s", id)
	}

	// Restore.
	code, raw = doReq(t, srv, http.MethodPost, "/v1/admin/subcategories/"+id+"/restore", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("restore: %d body=%s", code, raw)
	}

	// moderation_log rows: create + update + soft_delete + restore = 4.
	var count int
	if err := getPool(t).QueryRow(context.Background(), `
SELECT COUNT(*) FROM moderation_log
WHERE target_type::text='subcategory' AND target_id=$1::uuid AND moderator_id=$2;`,
		id, adminID).Scan(&count); err != nil {
		t.Fatalf("log count: %v", err)
	}
	if count != 4 {
		t.Errorf("moderation_log count=%d, want 4", count)
	}
}

// TestAdminSubcategory_DeleteBlockedInUse verifies the in-use guard
// fires when a live beverage still references the subcategory.
func TestAdminSubcategory_DeleteBlockedInUse(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "sub_admin2", "sub_admin2@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Use a seeded subcategory.
	var seededID string
	if err := getPool(t).QueryRow(context.Background(),
		`SELECT id FROM beverage_subcategories WHERE slug='junmai' AND category_slug='nihonshu' LIMIT 1;`,
	).Scan(&seededID); err != nil {
		t.Fatalf("seed subcategory: %v", err)
	}

	// Create a producer + beverage that references it.
	producerID := seedProducerRow(t, "In-Use Kura", "使用中酒造")
	createBev := map[string]any{
		"producer_id":     producerID,
		"category_slug":   "nihonshu",
		"name_i18n":       map[string]string{"en": "Reference Sake", "ja": "参照酒"},
		"subcategory_id":  seededID,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/beverages", adminTok, createBev)
	if code != http.StatusCreated {
		t.Fatalf("create beverage: %d body=%s", code, raw)
	}
	var createdBev map[string]any
	_ = json.Unmarshal(raw, &createdBev)
	// Response must carry the joined subcategory shape (id+slug+name).
	sub, ok := createdBev["subcategory"].(map[string]any)
	if !ok {
		t.Fatalf("create response missing subcategory ref: %s", raw)
	}
	if got, _ := sub["id"].(string); got != seededID {
		t.Errorf("subcategory.id=%q, want %q", got, seededID)
	}
	if got, _ := sub["slug"].(string); got != "junmai" {
		t.Errorf("subcategory.slug=%q, want junmai", got)
	}

	// Deletion of the seeded subcategory now fails with 409 IN_USE.
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/admin/subcategories/"+seededID, adminTok, nil)
	if code != http.StatusConflict {
		t.Fatalf("delete should be 409, got %d body=%s", code, raw)
	}
	var errBody map[string]any
	_ = json.Unmarshal(raw, &errBody)
	if got, _ := errBody["code"].(string); got != "IN_USE" {
		t.Errorf("error code=%q, want IN_USE", got)
	}
}

// TestAdminSubcategory_RejectsCrossCategoryRef checks the
// SUBCATEGORY_CATEGORY_MISMATCH 422 fires when subcategory_id points
// to a row outside the beverage's category.
func TestAdminSubcategory_RejectsCrossCategoryRef(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "sub_admin3", "sub_admin3@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// A shochu subcategory: imo.
	var shochuSubID string
	if err := getPool(t).QueryRow(context.Background(),
		`SELECT id FROM beverage_subcategories WHERE slug='imo' AND category_slug='shochu' LIMIT 1;`,
	).Scan(&shochuSubID); err != nil {
		t.Fatalf("seed lookup: %v", err)
	}

	producerID := seedProducerRow(t, "Mismatch Kura", "ミスマッチ酒造")
	createBev := map[string]any{
		"producer_id":    producerID,
		"category_slug":  "nihonshu",
		"name_i18n":      map[string]string{"en": "Bad Ref", "ja": "誤参照"},
		"subcategory_id": shochuSubID,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/beverages", adminTok, createBev)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d body=%s", code, raw)
	}
	var errBody map[string]any
	_ = json.Unmarshal(raw, &errBody)
	if got, _ := errBody["code"].(string); got != "SUBCATEGORY_CATEGORY_MISMATCH" {
		t.Errorf("error code=%q, want SUBCATEGORY_CATEGORY_MISMATCH (body=%s)", got, raw)
	}
}

// TestAdminFlavorTag_CreateListUpdateDelete exercises the equivalent
// round-trip for the flavor_tags taxonomy table.
func TestAdminFlavorTag_CreateListUpdateDelete(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	adminTok, adminID := mustRegister(t, srv, "ft_admin", "ft_admin@example.com", "password-123")
	promoteToAdmin(t, adminID)

	// Create.
	createBody := map[string]any{
		"slug":       "test_umami",
		"dimension":  "character",
		"name_i18n":  map[string]string{"en": "Umami"},
		"sort_order": 99,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/admin/flavor-tags", adminTok, createBody)
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var created map[string]any
	_ = json.Unmarshal(raw, &created)
	id, _ := created["id"].(string)
	if id == "" {
		t.Fatalf("no id in create response: %s", raw)
	}

	// Public taxonomy includes the new tag.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/flavor-tags", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list: %d body=%s", code, raw)
	}
	var pubList []map[string]any
	_ = json.Unmarshal(raw, &pubList)
	if !hasID(pubList, id) {
		t.Errorf("public list missing new tag %s", id)
	}

	// PATCH dimension + name.
	patchBody := map[string]any{
		"dimension": "finish",
		"name_i18n": map[string]string{"en": "Umami (long finish)"},
	}
	code, raw = doReq(t, srv, http.MethodPatch, "/v1/admin/flavor-tags/"+id, adminTok, patchBody)
	if code != http.StatusOK {
		t.Fatalf("patch: %d body=%s", code, raw)
	}
	var patched map[string]any
	_ = json.Unmarshal(raw, &patched)
	if got, _ := patched["dimension"].(string); got != "finish" {
		t.Errorf("patched dimension=%q, want finish", got)
	}

	// Soft-delete.
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/admin/flavor-tags/"+id, adminTok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d body=%s", code, raw)
	}

	// Public taxonomy excludes the tombstoned tag.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/flavor-tags", "", nil)
	if code != http.StatusOK {
		t.Fatalf("public list after delete: %d", code)
	}
	_ = json.Unmarshal(raw, &pubList)
	if hasID(pubList, id) {
		t.Errorf("public list still contains tombstoned tag %s", id)
	}

	// Restore.
	code, _ = doReq(t, srv, http.MethodPost, "/v1/admin/flavor-tags/"+id+"/restore", adminTok, nil)
	if code != http.StatusOK {
		t.Fatalf("restore: %d", code)
	}

	// moderation_log: 4 rows (create / update / soft_delete / restore).
	var count int
	if err := getPool(t).QueryRow(context.Background(), `
SELECT COUNT(*) FROM moderation_log
WHERE target_type::text='flavor_tag' AND target_id=$1::uuid AND moderator_id=$2;`,
		id, adminID).Scan(&count); err != nil {
		t.Fatalf("log count: %v", err)
	}
	if count != 4 {
		t.Errorf("moderation_log count=%d, want 4", count)
	}
}
