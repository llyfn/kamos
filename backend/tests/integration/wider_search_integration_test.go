//go:build integration
// +build integration

// Integration coverage for the wider-search backend slice (migration
// 003). Verifies:
//   - GET /v1/beverages?q= matches producer names and prefecture names.
//   - GET /v1/search?q= mirrors the same expansion across beverage and
//     producer branches.
//   - Misspelled queries hit the pg_trgm fallback.
//   - The maintenance triggers refresh dependent beverage search_tsv
//     rows when a producer is renamed.

package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

type bevSearchPage struct {
	Items []struct {
		ID   string `json:"id"`
		Name struct {
			EN string `json:"en"`
		} `json:"name"`
	} `json:"items"`
	NextCursor string `json:"next_cursor"`
	HasMore    bool   `json:"has_more"`
}

func doBeverageSearch(t *testing.T, srv *httptest.Server, q string) (int, bevSearchPage, []byte) {
	t.Helper()
	v := url.Values{}
	v.Set("q", q)
	code, raw := doReq(t, srv, http.MethodGet, "/v1/beverages?"+v.Encode(), "", nil)
	var page bevSearchPage
	if code == http.StatusOK {
		if err := json.Unmarshal(raw, &page); err != nil {
			t.Fatalf("decode beverages: %v body=%s", err, raw)
		}
	}
	return code, page, raw
}

// seedNamedProducerBeverage inserts one producer with the given names
// + prefecture slug and one beverage attached to it. Returns
// (producerID, beverageID).
func seedNamedProducerBeverage(
	t *testing.T,
	producerEN, beverageEN, prefectureSlug string,
) (string, string) {
	t.Helper()
	p := getPool(t)
	ctx := context.Background()

	var catID string
	if err := p.QueryRow(ctx,
		`SELECT id FROM beverage_categories WHERE slug='nihonshu' LIMIT 1;`).Scan(&catID); err != nil {
		t.Fatalf("category lookup: %v", err)
	}

	var prefID *string
	if prefectureSlug != "" {
		var id string
		if err := p.QueryRow(ctx,
			`SELECT id FROM prefectures WHERE slug=$1 LIMIT 1;`, prefectureSlug).Scan(&id); err != nil {
			t.Fatalf("prefecture lookup %q: %v", prefectureSlug, err)
		}
		prefID = &id
	}

	producerJSON, _ := json.Marshal(map[string]string{
		"en": producerEN, "ja": producerEN, "ko": producerEN,
	})
	beverageJSON, _ := json.Marshal(map[string]string{
		"en": beverageEN, "ja": beverageEN, "ko": beverageEN,
	})

	var producerID string
	if err := p.QueryRow(ctx,
		`INSERT INTO producers (name_i18n, prefecture_id) VALUES ($1::jsonb, $2) RETURNING id;`,
		string(producerJSON), prefID).Scan(&producerID); err != nil {
		t.Fatalf("seed producer: %v", err)
	}
	var bevID string
	if err := p.QueryRow(ctx,
		`INSERT INTO beverages (producer_id, category_id, category_slug, name_i18n)
		 VALUES ($1, $2, 'nihonshu', $3::jsonb) RETURNING id;`,
		producerID, catID, string(beverageJSON)).Scan(&bevID); err != nil {
		t.Fatalf("seed beverage: %v", err)
	}
	return producerID, bevID
}

// TestBeverages_QHitsProducerName — searching the producer name on
// /v1/beverages returns that producer's beverages.
func TestBeverages_QHitsProducerName(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, bevID := seedNamedProducerBeverage(t, "Asahi Shuzo", "Junmai Daiginjo", "yamaguchi")
	_, _ = seedNamedProducerBeverage(t, "Other Brewery", "Some Other Sake", "hokkaido")

	code, page, raw := doBeverageSearch(t, srv, "Asahi")
	if code != http.StatusOK {
		t.Fatalf("search: %d body=%s", code, raw)
	}
	found := false
	for _, it := range page.Items {
		if it.ID == bevID {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("beverage %s not surfaced for producer-name q=Asahi: body=%s", bevID, raw)
	}
}

// TestBeverages_QHitsPrefectureName — searching the prefecture name
// returns beverages from producers in that prefecture.
func TestBeverages_QHitsPrefectureName(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, bevID := seedNamedProducerBeverage(t, "Asahi Shuzo", "Junmai Daiginjo", "yamaguchi")
	_, other := seedNamedProducerBeverage(t, "Other Brewery", "Some Other Sake", "hokkaido")

	code, page, raw := doBeverageSearch(t, srv, "Yamaguchi")
	if code != http.StatusOK {
		t.Fatalf("search: %d body=%s", code, raw)
	}
	gotTarget, gotOther := false, false
	for _, it := range page.Items {
		if it.ID == bevID {
			gotTarget = true
		}
		if it.ID == other {
			gotOther = true
		}
	}
	if !gotTarget {
		t.Errorf("beverage %s missing for prefecture-name q=Yamaguchi: body=%s", bevID, raw)
	}
	if gotOther {
		t.Errorf("hokkaido beverage %s surfaced for q=Yamaguchi: body=%s", other, raw)
	}
}

// TestBeverages_FuzzyFallback — a misspelled query that misses FTS
// falls back to trigram. WHY shorter names: search_tsv concatenates
// name + producer + prefecture across en/ja/ko, so similarity() is
// diluted by haystack length. The fallback works reliably when the
// query is a meaningful share of the full text, which is the realistic
// "did you mean" scenario.
func TestBeverages_FuzzyFallback(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, bevID := seedNamedProducerBeverage(t, "Dassai", "Dassai", "")

	// "Dasai" misspells "Dassai" — websearch_to_tsquery won't find it
	// (the lexeme differs), so the fallback must kick in.
	code, page, raw := doBeverageSearch(t, srv, "Dasai")
	if code != http.StatusOK {
		t.Fatalf("fuzzy search: %d body=%s", code, raw)
	}
	found := false
	for _, it := range page.Items {
		if it.ID == bevID {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("beverage missing from fuzzy q=Dasai (want %s): body=%s", bevID, raw)
	}
	if page.HasMore {
		t.Errorf("fuzzy fallback returned has_more=true; expected one-shot: body=%s", raw)
	}
	if page.NextCursor != "" {
		t.Errorf("fuzzy fallback returned next_cursor=%q; expected empty", page.NextCursor)
	}
}

// TestBeverages_SoftDeletedExcluded — soft-deleted beverages stay
// out of search results.
func TestBeverages_SoftDeletedExcluded(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, bevID := seedNamedProducerBeverage(t, "Ghost Brewery", "Ghost Sake", "yamaguchi")

	code, page, raw := doBeverageSearch(t, srv, "Ghost")
	if code != http.StatusOK {
		t.Fatalf("pre-delete: %d body=%s", code, raw)
	}
	if len(page.Items) == 0 {
		t.Fatalf("pre-delete: expected match for Ghost, body=%s", raw)
	}

	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE beverages SET deleted_at = NOW() WHERE id = $1;`, bevID); err != nil {
		t.Fatalf("soft delete: %v", err)
	}

	code, page, raw = doBeverageSearch(t, srv, "Ghost")
	if code != http.StatusOK {
		t.Fatalf("post-delete: %d body=%s", code, raw)
	}
	for _, it := range page.Items {
		if it.ID == bevID {
			t.Errorf("soft-deleted beverage surfaced: body=%s", raw)
		}
	}
}

// TestBeverages_ProducerRenameSweep — renaming a producer must
// re-sweep dependent beverages' search_tsv (003 trigger contract).
func TestBeverages_ProducerRenameSweep(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	producerID, bevID := seedNamedProducerBeverage(t, "OldName Brewery", "Plain Sake", "yamaguchi")

	// Sanity: pre-rename, searching the old name finds the beverage.
	code, page, raw := doBeverageSearch(t, srv, "OldName")
	if code != http.StatusOK || len(page.Items) == 0 {
		t.Fatalf("pre-rename: expected hit, body=%s", raw)
	}

	// Rename the producer; trigger sweeps the beverage row.
	p := getPool(t)
	newJSON, _ := json.Marshal(map[string]string{
		"en": "RenamedBrewery", "ja": "RenamedBrewery", "ko": "RenamedBrewery",
	})
	if _, err := p.Exec(context.Background(),
		`UPDATE producers SET name_i18n = $1::jsonb WHERE id = $2;`,
		string(newJSON), producerID); err != nil {
		t.Fatalf("rename producer: %v", err)
	}

	code, page, raw = doBeverageSearch(t, srv, "RenamedBrewery")
	if code != http.StatusOK {
		t.Fatalf("post-rename: %d body=%s", code, raw)
	}
	found := false
	for _, it := range page.Items {
		if it.ID == bevID {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("beverage %s missing for post-rename q=RenamedBrewery: body=%s", bevID, raw)
	}
}

// TestSearch_ProducerBranch — /v1/search?type=producer matches a
// producer by prefecture-name token (the FTS expansion picks up the
// joined prefecture).
func TestSearch_ProducerBranch(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	producerID, _ := seedNamedProducerBeverage(t, "Asahi Shuzo", "Anything", "yamaguchi")

	v := url.Values{}
	v.Set("q", "Yamaguchi")
	v.Set("type", "producer")
	code, raw := doReq(t, srv, http.MethodGet, "/v1/search?"+v.Encode(), "", nil)
	if code != http.StatusOK {
		t.Fatalf("search producers: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			Type     string `json:"type"`
			Producer struct {
				ID string `json:"id"`
			} `json:"producer"`
		} `json:"items"`
	}
	if err := json.Unmarshal(raw, &page); err != nil {
		t.Fatalf("decode: %v body=%s", err, raw)
	}
	found := false
	for _, it := range page.Items {
		if it.Type == "producer" && it.Producer.ID == producerID {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("producer %s missing for /v1/search?type=producer q=Yamaguchi: body=%s", producerID, raw)
	}
}
