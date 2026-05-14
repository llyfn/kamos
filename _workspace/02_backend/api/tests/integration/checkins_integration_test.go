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

// 5th photo on a single check-in must be rejected (4 photo cap).
func TestCheckinPhotoCap(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "photog", "photog@example.com", "password11")
	bevID := seedBeverage(t, "Photog")

	// Create a check-in with 4 photo URLs inline (the max).
	code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"photos":      []string{"http://a/1.jpg", "http://a/2.jpg", "http://a/3.jpg", "http://a/4.jpg"},
	})
	if code != http.StatusCreated {
		t.Fatalf("create status=%d body=%s", code, body)
	}
	var ci map[string]any
	if err := json.Unmarshal(body, &ci); err != nil {
		t.Fatalf("decode: %v", err)
	}
	id, _ := ci["id"].(string)
	if id == "" {
		t.Fatalf("missing check-in id: %s", body)
	}

	// Adding a 5th photo via the upload endpoint must be rejected.
	code, body = doReq(t, srv, http.MethodPost, "/v1/check-ins/"+id+"/photos", tok, map[string]string{
		"url": "http://a/5.jpg",
	})
	if code < 400 || code >= 500 {
		t.Fatalf("5th photo: status=%d body=%s (want 4xx)", code, body)
	}
}

// Creating a check-in with 5 photos inline is rejected at the validation
// layer (handler returns 422 before the DB sees it).
func TestCheckinFivePhotosInlineRejected(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "five", "five@example.com", "password11")
	bevID := seedBeverage(t, "Five")
	code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"photos":      []string{"a", "b", "c", "d", "e"},
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
