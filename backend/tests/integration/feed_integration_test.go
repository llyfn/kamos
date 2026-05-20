//go:build integration
// +build integration

package integration

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"testing"
)

// 3 users post check-ins, the viewer follows them, the feed paginates with
// the canonical {items, next_cursor, has_more} shape. Page size is 20 per
// SPEC §5.2.
func TestFeedCursorPagination(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// 4 users: 1 viewer + 3 posters.
	tokViewer, _ := mustRegister(t, srv, "viewer", "viewer@example.com", "password11")
	for i := 1; i <= 3; i++ {
		uname := fmt.Sprintf("poster%d", i)
		email := fmt.Sprintf("poster%d@example.com", i)
		mustRegister(t, srv, uname, email, "password11")
		// follower follows posterN
		code, _ := doReq(t, srv, http.MethodPost, "/v1/users/"+uname+"/follow", tokViewer, nil)
		if code != http.StatusOK {
			t.Fatalf("follow %s: %d", uname, code)
		}
	}
	// Each poster creates 25 check-ins on a single beverage.
	bevID := seedBeverage(t, "FeedBev")
	for i := 1; i <= 3; i++ {
		uname := fmt.Sprintf("poster%d", i)
		email := fmt.Sprintf("poster%d@example.com", i)
		tok := mustLogin(t, srv, email, "password11")
		for j := 0; j < 25; j++ {
			code, body := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
				"beverage_id": bevID,
				"review":      fmt.Sprintf("%s-%d", uname, j),
			})
			if code != http.StatusCreated {
				t.Fatalf("create checkin %s-%d: %d body=%s", uname, j, code, body)
			}
		}
	}

	// Total visible to the viewer: 75 check-ins.
	type page struct {
		Items      []map[string]any `json:"items"`
		NextCursor string           `json:"next_cursor"`
		HasMore    bool             `json:"has_more"`
	}
	// First page.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/feed", tokViewer, nil)
	if code != http.StatusOK {
		t.Fatalf("feed page1: %d body=%s", code, raw)
	}
	var p1 page
	if err := json.Unmarshal(raw, &p1); err != nil {
		t.Fatalf("decode p1: %v", err)
	}
	if len(p1.Items) != 20 {
		t.Fatalf("page1 size: got %d want 20", len(p1.Items))
	}
	if !p1.HasMore {
		t.Errorf("page1 has_more should be true")
	}
	if p1.NextCursor == "" {
		t.Errorf("page1 next_cursor empty")
	}

	// Follow the cursors until exhaustion. Expect 75 total items, 3 full
	// pages of 20 + a final page of 15.
	total := len(p1.Items)
	seen := map[string]bool{}
	for _, it := range p1.Items {
		id, _ := it["id"].(string)
		seen[id] = true
	}
	cursor := p1.NextCursor
	hasMore := p1.HasMore
	for hasMore {
		path := "/v1/feed?cursor=" + url.QueryEscape(cursor)
		code, raw = doReq(t, srv, http.MethodGet, path, tokViewer, nil)
		if code != http.StatusOK {
			t.Fatalf("feed cursor=%s: %d body=%s", cursor, code, raw)
		}
		var p page
		if err := json.Unmarshal(raw, &p); err != nil {
			t.Fatalf("decode: %v", err)
		}
		for _, it := range p.Items {
			id, _ := it["id"].(string)
			if seen[id] {
				t.Errorf("duplicate feed item across pages: %s", id)
			}
			seen[id] = true
		}
		total += len(p.Items)
		cursor = p.NextCursor
		hasMore = p.HasMore
	}
	if total != 75 {
		t.Errorf("total feed items: got %d want 75", total)
	}
}

// The viewer's own check-ins MUST NOT appear in their feed (SPEC §5.2).
func TestFeedExcludesSelf(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "soloact", "solo@example.com", "password11")
	bevID := seedBeverage(t, "SelfBev")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok, map[string]any{
		"beverage_id": bevID,
		"review":      "self check-in",
	})
	if code != http.StatusCreated {
		t.Fatalf("create: %d body=%s", code, raw)
	}
	var ci map[string]any
	_ = json.Unmarshal(raw, &ci)
	myID, _ := ci["id"].(string)
	code, raw = doReq(t, srv, http.MethodGet, "/v1/feed", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("feed: %d", code)
	}
	var p struct {
		Items []map[string]any `json:"items"`
	}
	_ = json.Unmarshal(raw, &p)
	for _, it := range p.Items {
		if it["id"] == myID {
			t.Errorf("feed includes own check-in: %s", myID)
		}
	}
}
