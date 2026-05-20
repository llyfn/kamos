//go:build integration
// +build integration

package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

// New users get the SPEC §6.1 default collections seeded for them.
func TestDefaultCollectionsSeeded(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "newbie", "newbie@example.com", "password11")
	code, raw := doReq(t, srv, http.MethodGet, "/v1/collections", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d body=%s", code, raw)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	if err := json.Unmarshal(raw, &page); err != nil {
		t.Fatalf("decode: %v", err)
	}
	names := map[string]bool{}
	for _, c := range page.Items {
		if n, _ := c["name"].(string); n != "" {
			names[n] = true
		}
	}
	if !names["Inventory"] || !names["Wishlist"] {
		t.Errorf("default collections missing: %v", names)
	}
}

// Add a beverage to a collection → list contents includes it.
func TestAddAndListCollectionEntry(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "lister", "lister@example.com", "password11")
	bevID := seedBeverage(t, "ListMe")

	// Find the Wishlist collection id.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/collections", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d", code)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	var collID string
	for _, c := range page.Items {
		if c["name"] == "Wishlist" {
			collID, _ = c["id"].(string)
		}
	}
	if collID == "" {
		t.Fatalf("Wishlist not found in list: %s", raw)
	}

	// Add the beverage to Wishlist.
	code, raw = doReq(t, srv, http.MethodPost, "/v1/collections/"+collID+"/entries", tok, map[string]any{
		"beverage_id": bevID,
		"note":        "to try someday",
	})
	if code != http.StatusNoContent {
		t.Fatalf("add entry: %d body=%s", code, raw)
	}

	// Reading the collection now shows the entry.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections/"+collID, tok, nil)
	if code != http.StatusOK {
		t.Fatalf("get: %d body=%s", code, raw)
	}
	var detail struct {
		Entries struct {
			Items []map[string]any `json:"items"`
		} `json:"entries"`
	}
	if err := json.Unmarshal(raw, &detail); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(detail.Entries.Items) != 1 {
		t.Fatalf("expected 1 entry, got %d body=%s", len(detail.Entries.Items), raw)
	}
	entry := detail.Entries.Items[0]
	bev, _ := entry["beverage"].(map[string]any)
	if bev["id"] != bevID {
		t.Errorf("entry beverage id: %v want %v", bev["id"], bevID)
	}
}

// Delete a collection → it is soft-deleted (deleted_at set) and no longer
// appears in list.
func TestDeleteCollectionSoftDeletes(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "soft", "soft@example.com", "password11")

	// Create a fresh collection (so we don't have to delete a default).
	code, raw := doReq(t, srv, http.MethodPost, "/v1/collections", tok, map[string]string{
		"name": "Cellar",
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var coll map[string]any
	_ = json.Unmarshal(raw, &coll)
	id, _ := coll["id"].(string)
	if id == "" {
		t.Fatalf("no id: %s", raw)
	}

	// Delete it.
	code, _ = doReq(t, srv, http.MethodDelete, "/v1/collections/"+id, tok, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d", code)
	}

	// Verify deleted_at IS NOT NULL in the DB.
	var del bool
	if err := getPool(t).QueryRow(context.Background(),
		`SELECT deleted_at IS NOT NULL FROM collections WHERE id = $1;`, id).Scan(&del); err != nil {
		t.Fatalf("verify: %v", err)
	}
	if !del {
		t.Errorf("deleted_at was not set")
	}

	// And list does not include it.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/collections", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d", code)
	}
	var page struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	for _, c := range page.Items {
		if c["id"] == id {
			t.Errorf("deleted collection still in list: %s", raw)
		}
	}
}
