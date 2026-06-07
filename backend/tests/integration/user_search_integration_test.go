//go:build integration
// +build integration

// Integration coverage for GET /v1/users/search. Covers the
// pg_trgm-similarity contract: validation, soft-delete filtering,
// case-insensitive matching on both username and display_name, and
// similarity-ordered keyset pagination.
package integration

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"
)

// searchPage is a minimal projection of the search response, scoped
// to the fields these tests assert on.
type searchPage struct {
	Items []struct {
		ID          string `json:"id"`
		Username    string `json:"username"`
		DisplayName string `json:"display_name"`
	} `json:"items"`
	NextCursor string `json:"next_cursor"`
	HasMore    bool   `json:"has_more"`
}

func doSearch(t *testing.T, srv *httptest.Server, tok, q, cur string, limit int) (int, searchPage, []byte) {
	t.Helper()
	v := url.Values{}
	v.Set("q", q)
	if cur != "" {
		v.Set("cursor", cur)
	}
	if limit > 0 {
		v.Set("limit", itoa(limit))
	}
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/search?"+v.Encode(), tok, nil)
	var page searchPage
	if code == http.StatusOK {
		if err := json.Unmarshal(raw, &page); err != nil {
			t.Fatalf("decode search: %v body=%s", err, raw)
		}
	}
	return code, page, raw
}

// itoa avoids dragging in strconv at the test package level.
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := false
	if n < 0 {
		neg = true
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

// setUserCreatedAt rewrites a user's created_at via SQL. The keyset
// pagination tests need controlled timestamps so the rank-tier
// interleave is reproducible; the registration path stamps NOW() and
// would otherwise leave all rows within microseconds of each other.
func setUserCreatedAt(t *testing.T, userID string, ts time.Time) {
	t.Helper()
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET created_at = $2 WHERE id = $1;`, userID, ts); err != nil {
		t.Fatalf("setUserCreatedAt: %v", err)
	}
}

// setUserDisplayName rewrites a user's display_name via SQL. The
// rank-2 tier (display_name prefix) needs a display_name distinct
// from the username so the rank CASE picks tier 2, not tier 1.
func setUserDisplayName(t *testing.T, userID, name string) {
	t.Helper()
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET display_name = $2 WHERE id = $1;`, userID, name); err != nil {
		t.Fatalf("setUserDisplayName: %v", err)
	}
}

// softDeleteUser sets deleted_at on a user via SQL, mirroring what the
// handler does on DELETE /v1/users/me. We bypass the handler so the
// test stays focused on /v1/users/search filtering behavior, not the
// soft-delete flow.
func softDeleteUser(t *testing.T, userID string) {
	t.Helper()
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET deleted_at = NOW(),
		                  username_release_at = NOW() + INTERVAL '30 days'
		 WHERE id = $1;`, userID); err != nil {
		t.Fatalf("softDeleteUser: %v", err)
	}
}

// TestSearchUsers_HappyPath — substring match returns the expected
// user across both username and display_name, case-insensitively.
func TestSearchUsers_HappyPath(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, alpha := mustRegister(t, srv, "alphabob", "alphabob@example.com", "password-123")
	setUserDisplayName(t, alpha, "Alpha Robert")

	// Substring on username (lowercased input matches lowercase storage).
	code, page, raw := doSearch(t, srv, "", "alphabob", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 || page.Items[0].ID != alpha {
		t.Fatalf("username substring: got %+v want single id=%s", page.Items, alpha)
	}

	// Case-insensitive on username.
	code, page, raw = doSearch(t, srv, "", "ALPHABOB", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search upper: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 || page.Items[0].ID != alpha {
		t.Fatalf("username upper: got %+v", page.Items)
	}

	// Match on display_name only (not present in username).
	code, page, raw = doSearch(t, srv, "", "robert", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search display: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 || page.Items[0].ID != alpha {
		t.Fatalf("display_name substring: got %+v", page.Items)
	}

	// Case-insensitive on display_name.
	code, page, raw = doSearch(t, srv, "", "ROBERT", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search display upper: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 || page.Items[0].ID != alpha {
		t.Fatalf("display upper: got %+v", page.Items)
	}
}

// TestSearchUsers_QueryTooShort — q must be at least 2 characters.
// Empty, single-character, and whitespace-only queries all fail.
func TestSearchUsers_QueryTooShort(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	cases := []struct{ q string }{
		{""}, {"a"}, {" "}, {" a "},
	}
	for _, tc := range cases {
		code, _, raw := doSearch(t, srv, "", tc.q, "", 0)
		if code != http.StatusBadRequest {
			t.Errorf("q=%q: status=%d want 400 body=%s", tc.q, code, raw)
			continue
		}
		var e errBodyShape
		_ = json.Unmarshal(raw, &e)
		// Empty q fails SanitizeText (REQUIRED), >0-len-but-<2 fails the
		// INVALID_QUERY guard. Both surface as a 400 with a populated code;
		// the test asserts the response shape, not the specific code.
		if e.Code == "" {
			t.Errorf("q=%q: missing error code in %s", tc.q, raw)
		}
	}
}

// TestSearchUsers_SoftDeletedExcluded — a soft-deleted user is filtered
// out of search results even when the query matches their username.
func TestSearchUsers_SoftDeletedExcluded(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, uid := mustRegister(t, srv, "ghostuser", "ghost@example.com", "password-123")

	// Pre-delete: search hits.
	code, page, raw := doSearch(t, srv, "", "ghostuser", "", 0)
	if code != http.StatusOK {
		t.Fatalf("pre-delete search: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 {
		t.Fatalf("pre-delete: got %d want 1", len(page.Items))
	}

	softDeleteUser(t, uid)

	// Post-delete: search misses.
	code, page, raw = doSearch(t, srv, "", "ghostuser", "", 0)
	if code != http.StatusOK {
		t.Fatalf("post-delete search: %d body=%s", code, raw)
	}
	if len(page.Items) != 0 {
		t.Fatalf("post-delete: got %d want 0 (soft-deleted should not surface)", len(page.Items))
	}
}

// TestSearchUsers_PaginationBySimilarity — three users with stepped
// similarities for the query "bobby"; page-by-page keyset must walk
// all three in descending similarity exactly once.
func TestSearchUsers_PaginationBySimilarity(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Exact username match → highest similarity (1.0).
	_, exact := mustRegister(t, srv, "bobby", "bobby@example.com", "password-123")
	setUserDisplayName(t, exact, "Exact Bobby")
	setUserCreatedAt(t, exact, time.Now().Add(-3*time.Hour))

	// Closely related username → mid similarity.
	_, near := mustRegister(t, srv, "bobbyx", "bobbyx@example.com", "password-123")
	setUserDisplayName(t, near, "Near Bobby")
	setUserCreatedAt(t, near, time.Now().Add(-2*time.Hour))

	// display_name match only → lower (still trigram-overlapping).
	_, displ := mustRegister(t, srv, "tableguy", "tableguy@example.com", "password-123")
	setUserDisplayName(t, displ, "Bobby Tables")
	setUserCreatedAt(t, displ, time.Now().Add(-1*time.Hour))

	seen := map[string]int{}
	order := []string{}
	cur := ""
	for i := 0; i < 5; i++ {
		code, page, raw := doSearch(t, srv, "", "bobby", cur, 1)
		if code != http.StatusOK {
			t.Fatalf("page %d: status=%d body=%s", i, code, raw)
		}
		if len(page.Items) == 0 {
			break
		}
		for _, it := range page.Items {
			seen[it.ID]++
			order = append(order, it.ID)
		}
		if !page.HasMore {
			break
		}
		if page.NextCursor == "" {
			t.Fatalf("page %d: has_more=true but next_cursor empty body=%s", i, raw)
		}
		cur = page.NextCursor
	}

	if seen[exact] != 1 || seen[near] != 1 || seen[displ] != 1 {
		t.Errorf("counts: exact=%d near=%d displ=%d (each want 1) — order=%v",
			seen[exact], seen[near], seen[displ], order)
	}
	if len(order) != 3 {
		t.Fatalf("emitted %d rows, want 3 — order=%v", len(order), order)
	}
	// Exact match dominates; tableguy (display-name match) must come
	// after the username matches because GREATEST() picks the username
	// score path for exact + near.
	if order[0] != exact {
		t.Errorf("position 0: got %s want exact=%s (full=%v)", order[0], exact, order)
	}
	if order[2] != displ {
		t.Errorf("position 2: got %s want displ=%s (full=%v)", order[2], displ, order)
	}
}

// TestSearchUsers_TypoTolerance — a single-character typo still hits
// the target via pg_trgm similarity (the previous ILIKE contract
// would have returned zero results here).
func TestSearchUsers_TypoTolerance(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, target := mustRegister(t, srv, "dassai", "dassai@example.com", "password-123")
	setUserDisplayName(t, target, "Dassai User")

	code, page, raw := doSearch(t, srv, "", "dasai", "", 0)
	if code != http.StatusOK {
		t.Fatalf("typo search: %d body=%s", code, raw)
	}
	found := false
	for _, it := range page.Items {
		if it.ID == target {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("dassai missing from typo q=dasai: body=%s", raw)
	}
}
