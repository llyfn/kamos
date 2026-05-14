//go:build integration
// +build integration

package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

// List → detail → category filter on the beverages endpoint.
func TestBeveragesListAndDetail(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	id1 := seedBeverage(t, "Dassai")
	id2 := seedBeverage(t, "Hakkaisan")

	// List endpoint returns both.
	code, body := doReq(t, srv, http.MethodGet, "/v1/beverages", "", nil)
	if code != http.StatusOK {
		t.Fatalf("list status=%d body=%s", code, body)
	}
	var page struct {
		Items   []map[string]any `json:"items"`
		HasMore bool             `json:"has_more"`
	}
	if err := json.Unmarshal(body, &page); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(page.Items) < 2 {
		t.Fatalf("expected at least 2 items, got %d", len(page.Items))
	}
	ids := map[string]bool{}
	for _, it := range page.Items {
		if id, _ := it["id"].(string); id != "" {
			ids[id] = true
		}
	}
	if !ids[id1] || !ids[id2] {
		t.Errorf("list missing seeded ids: %v", ids)
	}

	// Detail endpoint returns the beverage by id.
	code, body = doReq(t, srv, http.MethodGet, "/v1/beverages/"+id1, "", nil)
	if code != http.StatusOK {
		t.Fatalf("detail status=%d body=%s", code, body)
	}
	var detail map[string]any
	if err := json.Unmarshal(body, &detail); err != nil {
		t.Fatalf("detail decode: %v", err)
	}
	if detail["id"] != id1 {
		t.Errorf("detail id: %v want %v", detail["id"], id1)
	}

	// Filter by category=nihonshu still returns both.
	code, body = doReq(t, srv, http.MethodGet, "/v1/beverages?category=nihonshu", "", nil)
	if code != http.StatusOK {
		t.Fatalf("filter status=%d body=%s", code, body)
	}
	var filtered struct {
		Items []map[string]any `json:"items"`
	}
	if err := json.Unmarshal(body, &filtered); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(filtered.Items) < 2 {
		t.Errorf("filter missing items: %d", len(filtered.Items))
	}

	// Filter by a non-existent category returns an empty page.
	code, body = doReq(t, srv, http.MethodGet, "/v1/beverages?category=nope", "", nil)
	if code != http.StatusOK {
		t.Fatalf("nope-filter status=%d", code)
	}
	var emptyPage struct {
		Items []map[string]any `json:"items"`
	}
	if err := json.Unmarshal(body, &emptyPage); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(emptyPage.Items) != 0 {
		t.Errorf("nope filter should be empty, got %d", len(emptyPage.Items))
	}
}

// SPEC §8 ko fallback: when a beverage has only en+ja names, the response
// MUST surface the en name under the ko key (or the client resolves via the
// returned object). Our API returns the full I18nText object so the client
// resolves on the device, but the server side must NOT serve a wrong-locale
// value as the ko name. Verify: ko key is absent (not the wrong language).
func TestBeverageKoLocaleFallback(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Seed a beverage with NO ko name.
	id := seedBeverageWithNames(t, "EnglishOnly", "日本語のみ", "")
	code, body := doReq(t, srv, http.MethodGet, "/v1/beverages/"+id, "", nil)
	if code != http.StatusOK {
		t.Fatalf("status=%d body=%s", code, body)
	}
	var detail map[string]any
	if err := json.Unmarshal(body, &detail); err != nil {
		t.Fatalf("decode: %v", err)
	}
	name, ok := detail["name"].(map[string]any)
	if !ok {
		t.Fatalf("name is not an object: %v", detail["name"])
	}
	if name["en"] != "EnglishOnly" {
		t.Errorf("name.en: %v", name["en"])
	}
	// ko should be absent (omitempty); critically, it must NOT be set to
	// the ja value or any other wrong-locale text. The client resolves
	// fallback via I18nText.Resolve("ko") → "EnglishOnly".
	if v, found := name["ko"]; found {
		// If present, it must be empty (legal) — never a wrong-locale value.
		if s, _ := v.(string); s != "" && s != "EnglishOnly" {
			t.Errorf("ko fallback should be empty or en; got %q", s)
		}
	}
	// Defence in depth: the Resolve helper would pick en in this case.
	if name["ja"] != "日本語のみ" {
		t.Errorf("ja name not preserved: %v", name["ja"])
	}
	_ = context.Background()
}

// GET /v1/beverages/{id} on an unknown id returns 404.
func TestBeverageDetailNotFound(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	code, _ := doReq(t, srv, http.MethodGet, "/v1/beverages/00000000-0000-0000-0000-000000000000", "", nil)
	if code != http.StatusNotFound {
		t.Fatalf("status=%d", code)
	}
}
