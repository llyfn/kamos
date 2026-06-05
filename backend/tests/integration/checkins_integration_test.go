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

// Create a check-in with rating 4.5 and confirm the response round-trips the
// value with one-decimal precision (SPEC §4.2). 4.5 must be a number, not
// a string, and must equal exactly 4.5 — not 4 or 4.49999.
func TestCreateCheckinRatingPrecision(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "rater", "rater@example.com", "password11")
	bevID := seedBeverage(t, "RatingTest")

	code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"rating":      4.5,
		"review":      "good stuff",
	})
	if code != http.StatusCreated {
		t.Fatalf("status=%d body=%s", code, body)
	}
	var ci map[string]any
	if err := json.Unmarshal(body, &ci); err != nil {
		t.Fatalf("decode: %v", err)
	}
	// The body must contain `"rating": 4.5` as a number — verified via the
	// raw text to catch any accidental string-encoding.
	if !strings.Contains(string(body), `"rating":4.5`) {
		t.Errorf("rating round-trip wrong; raw=%s", body)
	}
	if r, ok := ci["rating"].(float64); !ok || r != 4.5 {
		t.Errorf("rating: %v (%T)", ci["rating"], ci["rating"])
	}
}

// SPEC §4.2 (Slice B): the grid is 0.25 steps. Migration 004 widens
// check_ins.rating from NUMERIC(3,1) to NUMERIC(3,2) so the quarter-step
// values survive the round-trip. Pre-004 this test fails because PG
// silently rounds 4.25 → 4.3 / 0.75 → 0.8 on insert.
func TestCreateCheckinRatingQuarterStepRoundTrip(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "quarter", "quarter@example.com", "password11")
	bevID := seedBeverage(t, "QuarterRatingTest")

	cases := []struct {
		name string
		in   float64
		wire string // exact substring expected in the JSON body
	}{
		{"4.25 upper quarter", 4.25, `"rating":4.25`},
		{"0.75 lower quarter", 0.75, `"rating":0.75`},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
				"beverage_id": bevID,
				"rating":      tc.in,
			})
			if code != http.StatusCreated {
				t.Fatalf("status=%d body=%s", code, body)
			}
			if !strings.Contains(string(body), tc.wire) {
				t.Errorf("rating round-trip wrong; want %q in body, got %s", tc.wire, body)
			}
			var ci map[string]any
			if err := json.Unmarshal(body, &ci); err != nil {
				t.Fatalf("decode: %v", err)
			}
			r, ok := ci["rating"].(float64)
			if !ok {
				t.Fatalf("rating type: %T", ci["rating"])
			}
			if r != tc.in {
				t.Errorf("rating: got %v want %v", r, tc.in)
			}
		})
	}
}

// Creating a check-in with 2 photos inline is rejected at the validation
// layer (handler returns 422 before the DB sees it). Slice B / SPEC §4.1
// dropped the submission cap from 4 to 1; the legacy upload endpoint
// (POST /v1/check-ins/{id}/photos) is covered by
// TestAttachUploadedPhotoToCheckin in photos_integration_test.go.
func TestCheckinTwoPhotosInlineRejected(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "two", "two@example.com", "password11")
	bevID := seedBeverage(t, "Two")
	code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"photos":      []string{"a", "b"},
	})
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d body=%s", code, body)
	}
}

// Review text longer than 500 chars must be rejected (SPEC §4.1).
func TestCheckinReviewTooLong(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "wordy", "wordy@example.com", "password11")
	bevID := seedBeverage(t, "Wordy")
	long := strings.Repeat("a", 501)
	code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"review":      long,
	})
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("status=%d body=%s", code, body)
	}
}

// Soft-delete a check-in: subsequent feed reads must not include it.
func TestCheckinSoftDelete(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Two users: a follower (who reads the feed) and a poster (whose check-in
	// is deleted). The follower follows the poster so the poster's row would
	// otherwise appear on the follower's feed.
	tokFollower, _ := mustRegister(t, srv, "follower", "follower@example.com", "password11")
	_, _ = mustRegister(t, srv, "poster", "poster@example.com", "password11")
	tokPoster := mustLogin(t, srv, "poster@example.com", "password11")
	bevID := seedBeverage(t, "SoftDel")

	// follower follows poster (public, instant).
	code, _ := doReq(t, srv, http.MethodPost, "/v1/users/poster/follow", tokFollower, nil)
	if code != http.StatusOK {
		t.Fatalf("follow: %d", code)
	}
	// poster creates a check-in.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tokPoster, map[string]any{
		"beverage_id": bevID,
		"review":      "to be deleted",
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	id, _ := ci["id"].(string)

	// Feed contains it before deletion.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/feed", tokFollower, nil)
	if code != http.StatusOK {
		t.Fatalf("feed: %d", code)
	}
	if !strings.Contains(string(raw), id) {
		t.Fatalf("feed pre-delete missing id=%s body=%s", id, raw)
	}

	// poster deletes the check-in.
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/check-ins/"+id, tokPoster, nil)
	if code != http.StatusNoContent {
		t.Fatalf("delete: %d body=%s", code, raw)
	}

	// Feed must no longer include it.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/feed", tokFollower, nil)
	if code != http.StatusOK {
		t.Fatalf("feed post-delete: %d", code)
	}
	if strings.Contains(string(raw), id) {
		t.Errorf("feed post-delete still contains deleted check-in %s: %s", id, raw)
	}

	// And the row is marked deleted_at IS NOT NULL in the DB.
	var hasDeletedAt bool
	if err := getPool(t).QueryRow(context.Background(),
		`SELECT deleted_at IS NOT NULL FROM check_ins WHERE id = $1;`, id).Scan(&hasDeletedAt); err != nil {
		t.Fatalf("verify: %v", err)
	}
	if !hasDeletedAt {
		t.Errorf("deleted_at was not set on the row")
	}
}
