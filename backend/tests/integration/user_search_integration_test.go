//go:build integration
// +build integration

// Integration coverage for GET /v1/users/search. The previous round
// shipped the endpoint with no integration tests, then QA caught a
// keyset-pagination bug that crossed rank tiers incorrectly. This
// suite locks in the fix plus the surrounding contract — validation,
// soft-delete filtering, LIKE wildcard escaping, and case-insensitive
// matching on both username and display_name.
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

// TestSearchUsers_PaginationAcrossRankTiers — the regression QA caught.
// Three users, three rank tiers, three pages of limit=1. The buggy
// 2-tuple keyset would either skip the rank-3 user or duplicate the
// rank-1 user; the fix walks all three exactly once in (rank, ts DESC)
// order.
func TestSearchUsers_PaginationAcrossRankTiers(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Rank 1 (username prefix "bob") with the OLDEST created_at — so
	// (created_at, id) DESC would visit it last and the old code would
	// re-emit it on page 2 once the keyset crossed into rank-2 territory.
	_, bobby := mustRegister(t, srv, "bobby", "bobby@example.com", "password-123")
	setUserDisplayName(t, bobby, "Bobby Tables")
	setUserCreatedAt(t, bobby, time.Now().Add(-3*time.Hour))

	// Rank 2 (display_name prefix "bob"), middle timestamp. Username
	// "johnny" so it doesn't hit rank 1.
	_, johnny := mustRegister(t, srv, "johnny", "johnny@example.com", "password-123")
	setUserDisplayName(t, johnny, "Bob Johnson")
	setUserCreatedAt(t, johnny, time.Now().Add(-2*time.Hour))

	// Rank 3 (contains "bob" in display_name only), newest timestamp.
	// Username "xyzed" so it doesn't hit rank 1; display_name "Rob Bobson"
	// matches the contains pattern but not the prefix.
	_, xyzed := mustRegister(t, srv, "xyzed", "xyzed@example.com", "password-123")
	setUserDisplayName(t, xyzed, "Rob Bobson")
	setUserCreatedAt(t, xyzed, time.Now().Add(-1*time.Hour))

	// Walk three pages, limit=1.
	seen := map[string]int{}
	order := []string{}
	cur := ""
	for i := 0; i < 5; i++ { // upper bound; we expect to finish in 3.
		code, page, raw := doSearch(t, srv, "", "bob", cur, 1)
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

	// Every user surfaced exactly once.
	if seen[bobby] != 1 || seen[johnny] != 1 || seen[xyzed] != 1 {
		t.Errorf("counts: bobby=%d johnny=%d xyzed=%d (each want 1) — order=%v",
			seen[bobby], seen[johnny], seen[xyzed], order)
	}

	// Rank order: bobby (rank 1) → johnny (rank 2) → xyzed (rank 3).
	want := []string{bobby, johnny, xyzed}
	if len(order) != 3 {
		t.Fatalf("emitted %d rows, want 3 — order=%v", len(order), order)
	}
	for i, id := range want {
		if order[i] != id {
			t.Errorf("position %d: got %s want %s — full order=%v", i, order[i], id, order)
		}
	}
}

// TestSearchUsers_LikeWildcardEscape — `%` and `_` are literal in the
// query, not wildcards. Without escaping, q="a%" matches every user
// whose username starts with "a"; with escaping it matches only users
// whose username literally contains "a%".
func TestSearchUsers_LikeWildcardEscape(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, alice := mustRegister(t, srv, "alice", "alice@example.com", "password-123")
	_, _ = mustRegister(t, srv, "bob", "bob@example.com", "password-123")

	// Sanity check: bare "a" prefix would hit alice (and possibly anyone
	// starting with 'a'); we don't assert on this. The point of this
	// test is that "a%" should NOT match alice because alice's username
	// has no literal "%" in it.
	code, page, raw := doSearch(t, srv, "", "a%", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search a%%: %d body=%s", code, raw)
	}
	for _, it := range page.Items {
		if it.ID == alice {
			t.Errorf("alice surfaced for q=%q — %% was treated as wildcard. body=%s", "a%", raw)
		}
	}

	// Underscore is also a SQL LIKE wildcard ("any single char"). Same
	// test: "ali_e" must not match "alice".
	code, page, raw = doSearch(t, srv, "", "ali_e", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search ali_e: %d body=%s", code, raw)
	}
	for _, it := range page.Items {
		if it.ID == alice {
			t.Errorf("alice surfaced for q=%q — _ was treated as wildcard. body=%s", "ali_e", raw)
		}
	}

	// Positive control: searching the literal "alice" still works
	// (confirms the escape doesn't break ordinary substring matches).
	code, page, raw = doSearch(t, srv, "", "alice", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search alice: %d body=%s", code, raw)
	}
	hit := false
	for _, it := range page.Items {
		if it.ID == alice {
			hit = true
			break
		}
	}
	if !hit {
		t.Errorf("alice missing from positive-control search: body=%s", raw)
	}
}
