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

// Phase 4 venues — three contracts exercised here:
//
//   1. GET /v1/venues/search with no Foursquare key configured → 503
//      VENUE_SEARCH_DISABLED. The test harness never sets FOURSQUARE_API_KEY,
//      so this is the default path on every dev box.
//   2. POST /v1/check-ins with `venue.foursquare_id + name + …` → 201,
//      venue row created on first call, upsert (no duplicate row) on the
//      second with the same fsq id, and the check-in's venue_id FK is set.
//      The check-in response body includes a `venue` projection with
//      id / name / locality / country.
//   3. POST /v1/check-ins with `venue.id = <existing>` → 201, venue_id set;
//      with an empty `{}` venue → 201 and no venue (silent drop per the
//      "permissive on incomplete payloads" decision in CreateCheckin).

// SEC-012: /v1/venues/search must require an Authorization bearer token.
// Regression guard so the route can't accidentally be moved out of the
// authed group.
func TestVenueSearchRequiresAuth(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	code, raw := doReq(t, srv, http.MethodGet, "/v1/venues/search?q=x", "", nil)
	if code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d body=%s", code, raw)
	}
	var e errBodyShape
	if err := json.Unmarshal(raw, &e); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if e.Code != "UNAUTHORIZED" {
		t.Errorf("code: %q (want UNAUTHORIZED)", e.Code)
	}
}

func TestVenueSearchReturns503WhenDisabled(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "venuser", "venuser@example.com", "password11")

	code, raw := doReq(t, srv, http.MethodGet, "/v1/venues/search?q=daikoku", tok, nil)
	if code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503, got %d body=%s", code, raw)
	}
	var e errBodyShape
	if err := json.Unmarshal(raw, &e); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if e.Code != "VENUE_SEARCH_DISABLED" {
		t.Errorf("code: %q (want VENUE_SEARCH_DISABLED)", e.Code)
	}
}

func TestCreateCheckinWithFoursquareVenueUpserts(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "venman", "venman@example.com", "password11")
	bevID := seedBeverage(t, "VenueTest")

	body := map[string]any{
		"beverage_id": bevID,
		"venue": map[string]any{
			"foursquare_id": "fsq-abc-123",
			"name":          "Daikoku",
			"address":       "1-1 Marunouchi",
			"lat":           35.6812,
			"lng":           139.7671,
			"country":       "JP",
			"prefecture":    "Tokyo",
			"locality":      "Chiyoda",
		},
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, body)
	if code != http.StatusCreated {
		t.Fatalf("first checkin: status=%d body=%s", code, raw)
	}

	var ci1 map[string]any
	if err := json.Unmarshal(raw, &ci1); err != nil {
		t.Fatalf("decode: %v", err)
	}
	venue, ok := ci1["venue"].(map[string]any)
	if !ok || venue == nil {
		t.Fatalf("expected venue in response body: %s", raw)
	}
	if venue["name"] != "Daikoku" {
		t.Errorf("venue.name: %v", venue["name"])
	}
	if venue["locality"] != "Chiyoda" {
		t.Errorf("venue.locality: %v", venue["locality"])
	}
	if venue["country"] != "JP" {
		t.Errorf("venue.country: %v", venue["country"])
	}
	firstVenueID, _ := venue["id"].(string)
	if firstVenueID == "" {
		t.Fatalf("missing venue.id: %s", raw)
	}

	// One venue row, one check-in with venue_id set.
	p := getPool(t)
	var venueCount, ciVenueLinked int
	if err := p.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM venues WHERE foursquare_id = $1;`,
		"fsq-abc-123").Scan(&venueCount); err != nil {
		t.Fatalf("count venues: %v", err)
	}
	if venueCount != 1 {
		t.Errorf("venue rows = %d (want 1)", venueCount)
	}
	if err := p.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM check_ins WHERE venue_id IS NOT NULL;`).Scan(&ciVenueLinked); err != nil {
		t.Fatalf("count linked checkins: %v", err)
	}
	if ciVenueLinked != 1 {
		t.Errorf("check-ins with venue_id = %d (want 1)", ciVenueLinked)
	}

	// Second check-in, same fsq id, different claimed name — must reuse the
	// existing row (no duplicate insert) AND keep the original name
	// (first-writer-wins per SEC-002).
	body2 := map[string]any{
		"beverage_id": bevID,
		"venue": map[string]any{
			"foursquare_id": "fsq-abc-123",
			"name":          "Daikoku (renamed)",
			"country":       "JP",
		},
	}
	code, raw = doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, body2)
	if code != http.StatusCreated {
		t.Fatalf("second checkin: status=%d body=%s", code, raw)
	}
	var ci2 map[string]any
	if err := json.Unmarshal(raw, &ci2); err != nil {
		t.Fatalf("decode: %v", err)
	}
	venue2, _ := ci2["venue"].(map[string]any)
	if venue2 == nil {
		t.Fatalf("expected venue on second checkin: %s", raw)
	}
	if venue2["id"] != firstVenueID {
		t.Errorf("upsert produced new id: first=%s second=%v", firstVenueID, venue2["id"])
	}
	if venue2["name"] != "Daikoku" {
		t.Errorf("venue name overwritten: got %v (want Daikoku — first-writer-wins)", venue2["name"])
	}

	// Still exactly one row keyed by the fsq id.
	if err := p.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM venues WHERE foursquare_id = $1;`,
		"fsq-abc-123").Scan(&venueCount); err != nil {
		t.Fatalf("recount venues: %v", err)
	}
	if venueCount != 1 {
		t.Errorf("after upsert venue rows = %d (want 1)", venueCount)
	}
}

func TestCreateCheckinWithExistingVenueID(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "venid", "venid@example.com", "password11")
	bevID := seedBeverage(t, "VenIDTest")

	// Seed a venue directly via SQL.
	p := getPool(t)
	var venueID string
	if err := p.QueryRow(context.Background(), `
INSERT INTO venues (foursquare_id, name, locality, country)
VALUES ('fsq-seeded-1', 'PreExisting Bar', 'Shibuya', 'JP')
RETURNING id;`).Scan(&venueID); err != nil {
		t.Fatalf("seed venue: %v", err)
	}

	body := map[string]any{
		"beverage_id": bevID,
		"venue":       map[string]any{"id": venueID},
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, body)
	if code != http.StatusCreated {
		t.Fatalf("status=%d body=%s", code, raw)
	}
	var ci map[string]any
	if err := json.Unmarshal(raw, &ci); err != nil {
		t.Fatalf("decode: %v", err)
	}
	v, _ := ci["venue"].(map[string]any)
	if v == nil || v["id"] != venueID {
		t.Errorf("venue id mismatch: got %+v want %s", v, venueID)
	}
	if v["name"] != "PreExisting Bar" {
		t.Errorf("venue.name: %v", v["name"])
	}
}

// SEC-001: oversized venue.name (rune length > 200) is rejected with 422
// VALIDATION before any DB write.
func TestCheckinVenueValidation_RejectsOversizedName(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "bigname", "bigname@example.com", "password11")
	bevID := seedBeverage(t, "OversizedName")

	bigName := strings.Repeat("a", 201)
	body := map[string]any{
		"beverage_id": bevID,
		"venue": map[string]any{
			"foursquare_id": "fsq-too-big",
			"name":          bigName,
		},
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, body)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d body=%s", code, raw)
	}
	var e errBodyShape
	if err := json.Unmarshal(raw, &e); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if e.Code != "VALIDATION" {
		t.Errorf("code: %q (want VALIDATION)", e.Code)
	}
}

// SEC-001: ASCII control char (< 0x20, not tab) in venue.name is rejected.
func TestCheckinVenueValidation_RejectsControlChars(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "ctrlchr", "ctrlchr@example.com", "password11")
	bevID := seedBeverage(t, "CtrlChars")

	body := map[string]any{
		"beverage_id": bevID,
		"venue": map[string]any{
			"foursquare_id": "fsq-ctrl",
			"name":          "Bad\x01Name",
		},
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, body)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d body=%s", code, raw)
	}
	var e errBodyShape
	if err := json.Unmarshal(raw, &e); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if e.Code != "VALIDATION" {
		t.Errorf("code: %q (want VALIDATION)", e.Code)
	}
}

// SEC-002: second check-in with the same foursquare_id must NOT overwrite
// the existing venue row's name/address/coords. First-writer-wins.
func TestVenueUpsertIsFirstWriterWins(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok1, _ := mustRegister(t, srv, "first", "first@example.com", "password11")
	tok2, _ := mustRegister(t, srv, "second", "second@example.com", "password11")
	bevID := seedBeverage(t, "FirstWriter")

	originalAddr := "1-1 Marunouchi"
	body1 := map[string]any{
		"beverage_id": bevID,
		"venue": map[string]any{
			"foursquare_id": "fsq-first-writer",
			"name":          "Original",
			"address":       originalAddr,
			"country":       "JP",
		},
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok1, body1)
	if code != http.StatusCreated {
		t.Fatalf("first checkin: status=%d body=%s", code, raw)
	}

	body2 := map[string]any{
		"beverage_id": bevID,
		"venue": map[string]any{
			"foursquare_id": "fsq-first-writer",
			"name":          "Hijacked",
			"address":       "Attacker Plaza",
			"country":       "ZZ",
		},
	}
	code, raw = doReq(t, srv, http.MethodPost, "/v1/check-ins", tok2, body2)
	if code != http.StatusCreated {
		t.Fatalf("second checkin: status=%d body=%s", code, raw)
	}

	// The shared venue row must still hold the original values.
	p := getPool(t)
	var dbName, dbAddr, dbCountry string
	if err := p.QueryRow(context.Background(), `
SELECT name, address, country FROM venues WHERE foursquare_id = $1;`,
		"fsq-first-writer").Scan(&dbName, &dbAddr, &dbCountry); err != nil {
		t.Fatalf("read venue row: %v", err)
	}
	if dbName != "Original" {
		t.Errorf("venue.name = %q (want Original — second writer overwrote)", dbName)
	}
	if dbAddr != originalAddr {
		t.Errorf("venue.address = %q (want %q)", dbAddr, originalAddr)
	}
	if dbCountry != "JP" {
		t.Errorf("venue.country = %q (want JP)", dbCountry)
	}
}

func TestCreateCheckinWithEmptyVenueIsSilentDrop(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "empven", "empven@example.com", "password11")
	bevID := seedBeverage(t, "EmptyVenue")

	body := map[string]any{
		"beverage_id": bevID,
		"venue":       map[string]any{},
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, body)
	if code != http.StatusCreated {
		t.Fatalf("status=%d body=%s", code, raw)
	}
	var ci map[string]any
	if err := json.Unmarshal(raw, &ci); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if _, present := ci["venue"]; present {
		t.Errorf("venue key should be absent on empty payload: %s", raw)
	}
}
