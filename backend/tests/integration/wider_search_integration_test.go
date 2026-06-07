//go:build integration
// +build integration

// Integration coverage for the bigm-backed search slice (migration 004).
// Verifies:
//   - GET /v1/beverages?q= matches beverage, producer, and prefecture
//     names (the wider-vector capability the 003 slice introduced is
//     preserved end-to-end).
//   - GET /v1/search?q= mirrors the same expansion on the producer branch.
//   - CJK substring queries (Korean + Japanese) hit the bigm index for
//     short, intra-token matches that FTS cannot segment.
//   - Soft-deleted rows stay out of results.
//   - The maintenance triggers re-sweep dependent beverage search_text
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

// seedNamedProducerBeverage inserts one producer + one attached beverage,
// reusing the supplied EN string across all three locales for the simple
// cases. Returns (producerID, beverageID).
func seedNamedProducerBeverage(
	t *testing.T,
	producerEN, beverageEN, prefectureSlug string,
) (string, string) {
	t.Helper()
	return seedNamedProducerBeverageI18n(t,
		producerEN, producerEN, producerEN,
		beverageEN, beverageEN, beverageEN,
		prefectureSlug,
	)
}

// seedNamedProducerBeverageI18n accepts distinct en/ja/ko names. Used by
// the CJK substring tests where the JA + KO strings carry the codepoints
// being searched.
func seedNamedProducerBeverageI18n(
	t *testing.T,
	producerEN, producerJA, producerKO string,
	beverageEN, beverageJA, beverageKO string,
	prefectureSlug string,
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
		"en": producerEN, "ja": producerJA, "ko": producerKO,
	})
	beverageJSON, _ := json.Marshal(map[string]string{
		"en": beverageEN, "ja": beverageJA, "ko": beverageKO,
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

// TestBeverages_KoreanCJKSubstring — `사이` (2-char CJK substring) finds
// `닷사이 39` even though `사이` sits inside an unwhite-spaced Korean
// token. FTS could not segment this; bigm can.
func TestBeverages_KoreanCJKSubstring(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, bevID := seedNamedProducerBeverageI18n(t,
		"Asahi Shuzo", "旭酒造", "아사히 슈조",
		"Dassai 39", "獺祭50", "닷사이 39",
		"yamaguchi",
	)

	code, page, raw := doBeverageSearch(t, srv, "사이")
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
		t.Errorf("beverage %s missing for CJK substring q=사이: body=%s", bevID, raw)
	}
}

// TestBeverages_JapaneseCJKSubstring — `祭` (1-char Japanese substring)
// finds `獺祭50` within an unwhite-spaced Japanese token.
func TestBeverages_JapaneseCJKSubstring(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, bevID := seedNamedProducerBeverageI18n(t,
		"Asahi Shuzo", "旭酒造", "아사히 슈조",
		"Dassai 50", "獺祭50", "닷사이 50",
		"yamaguchi",
	)

	code, page, raw := doBeverageSearch(t, srv, "祭")
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
		t.Errorf("beverage %s missing for Japanese substring q=祭: body=%s", bevID, raw)
	}
}

// TestSearch_ProducerCJKSubstring — /v1/search?type=producer with `富士`
// (cross-token Japanese substring) finds producers whose name contains
// the substring, and excludes unrelated rows.
func TestSearch_ProducerCJKSubstring(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	producerID, _ := seedNamedProducerBeverageI18n(t,
		"Fujimi Brewery", "富士見酒造", "후지미 슈조",
		"House Sake", "House Sake", "House Sake",
		"shizuoka",
	)
	otherID, _ := seedNamedProducerBeverageI18n(t,
		"Unrelated Brewery", "無関係酒造", "무관계 슈조",
		"Some Sake", "Some Sake", "Some Sake",
		"hokkaido",
	)

	v := url.Values{}
	v.Set("q", "富士")
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
	gotTarget, gotOther := false, false
	for _, it := range page.Items {
		if it.Type != "producer" {
			continue
		}
		if it.Producer.ID == producerID {
			gotTarget = true
		}
		if it.Producer.ID == otherID {
			gotOther = true
		}
	}
	if !gotTarget {
		t.Errorf("producer %s missing for /v1/search?type=producer q=富士: body=%s", producerID, raw)
	}
	if gotOther {
		t.Errorf("unrelated producer %s surfaced for q=富士: body=%s", otherID, raw)
	}
}

// TestBeverages_SoftDeletedExcluded — soft-deleted beverages stay out
// of search results.
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
// re-sweep dependent beverages' search_text via the maintenance trigger.
func TestBeverages_ProducerRenameSweep(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	producerID, bevID := seedNamedProducerBeverage(t, "OldName Brewery", "Plain Sake", "yamaguchi")

	code, page, raw := doBeverageSearch(t, srv, "OldName")
	if code != http.StatusOK || len(page.Items) == 0 {
		t.Fatalf("pre-rename: expected hit, body=%s", raw)
	}

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

// TestBeverages_LikeMetacharEscaped — a query of `%` or `_` must NOT
// match every row. The repo escapes LIKE metachars before binding so
// user-supplied wildcards stay literal substrings.
func TestBeverages_LikeMetacharEscaped(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, _ = seedNamedProducerBeverage(t, "Asahi Shuzo", "Junmai Daiginjo", "yamaguchi")
	_, _ = seedNamedProducerBeverage(t, "Other Brewery", "Some Other Sake", "hokkaido")

	for _, q := range []string{"%", "_", "%%"} {
		code, page, raw := doBeverageSearch(t, srv, q)
		if code != http.StatusOK {
			t.Fatalf("q=%q: status=%d body=%s", q, code, raw)
		}
		if len(page.Items) != 0 {
			t.Errorf("q=%q: got %d items, want 0 (metachars must not match-all): body=%s",
				q, len(page.Items), raw)
		}
	}
}

// TestSearch_ProducerBranch — /v1/search?type=producer matches a
// producer by prefecture-name token (the bigm-backed search_text picks
// up the joined prefecture name).
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
