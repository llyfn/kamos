//go:build integration
// +build integration

// Integration coverage for GET /v1/users/search. Covers the bigm-backed
// substring + 3-tier ranking contract: validation, soft-delete filtering,
// case-insensitive matching on both username and display_name, tiered
// ordering (exact > prefix > substring) with length-then-recency tie-
// break, and keyset pagination on the (tier, length, created_at, id)
// cursor.
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

// setUserCreatedAt rewrites a user's created_at via SQL so pagination
// tests can pin a reproducible (created_at DESC) tie-break order; the
// registration path stamps NOW() and would otherwise leave all rows
// within microseconds of each other.
func setUserCreatedAt(t *testing.T, userID string, ts time.Time) {
	t.Helper()
	p := getPool(t)
	if _, err := p.Exec(context.Background(),
		`UPDATE users SET created_at = $2 WHERE id = $1;`, userID, ts); err != nil {
		t.Fatalf("setUserCreatedAt: %v", err)
	}
}

// setUserDisplayName rewrites a user's display_name so the tier CASE
// has a display_name distinct from the username for prefix/substring
// tier scenarios.
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
// test stays focused on /v1/users/search filtering behavior.
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

	code, page, raw := doSearch(t, srv, "", "alphabob", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 || page.Items[0].ID != alpha {
		t.Fatalf("username substring: got %+v want single id=%s", page.Items, alpha)
	}

	code, page, raw = doSearch(t, srv, "", "ALPHABOB", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search upper: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 || page.Items[0].ID != alpha {
		t.Fatalf("username upper: got %+v", page.Items)
	}

	code, page, raw = doSearch(t, srv, "", "robert", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search display: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 || page.Items[0].ID != alpha {
		t.Fatalf("display_name substring: got %+v", page.Items)
	}

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

	code, page, raw := doSearch(t, srv, "", "ghostuser", "", 0)
	if code != http.StatusOK {
		t.Fatalf("pre-delete search: %d body=%s", code, raw)
	}
	if len(page.Items) != 1 {
		t.Fatalf("pre-delete: got %d want 1", len(page.Items))
	}

	softDeleteUser(t, uid)

	code, page, raw = doSearch(t, srv, "", "ghostuser", "", 0)
	if code != http.StatusOK {
		t.Fatalf("post-delete search: %d body=%s", code, raw)
	}
	if len(page.Items) != 0 {
		t.Fatalf("post-delete: got %d want 0 (soft-deleted should not surface)", len(page.Items))
	}
}

// TestSearchUsers_TierOrdering — exact match comes first, then prefix
// matches, then pure substring matches. Walked one page at a time to
// also exercise the (tier, length, created_at, id) cursor.
func TestSearchUsers_TierOrdering(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, exact := mustRegister(t, srv, "bob", "bob@example.com", "password-123")
	setUserDisplayName(t, exact, "Exact Match")
	setUserCreatedAt(t, exact, time.Now().Add(-4*time.Hour))

	_, prefix := mustRegister(t, srv, "bobby", "bobby@example.com", "password-123")
	setUserDisplayName(t, prefix, "Prefix Match")
	setUserCreatedAt(t, prefix, time.Now().Add(-3*time.Hour))

	_, substr := mustRegister(t, srv, "subbob", "subbob@example.com", "password-123")
	setUserDisplayName(t, substr, "Substring Match")
	setUserCreatedAt(t, substr, time.Now().Add(-2*time.Hour))

	seen := map[string]int{}
	order := []string{}
	cur := ""
	for i := 0; i < 5; i++ {
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

	if seen[exact] != 1 || seen[prefix] != 1 || seen[substr] != 1 {
		t.Errorf("counts: exact=%d prefix=%d substr=%d (each want 1) — order=%v",
			seen[exact], seen[prefix], seen[substr], order)
	}
	if len(order) != 3 {
		t.Fatalf("emitted %d rows, want 3 — order=%v", len(order), order)
	}
	if order[0] != exact {
		t.Errorf("position 0: got %s want exact=%s (full=%v)", order[0], exact, order)
	}
	if order[1] != prefix {
		t.Errorf("position 1: got %s want prefix=%s (full=%v)", order[1], prefix, order)
	}
	if order[2] != substr {
		t.Errorf("position 2: got %s want substr=%s (full=%v)", order[2], substr, order)
	}
}

// TestSearchUsers_LengthTieBreak — within the same tier (substring), the
// shorter username surfaces first per the (length ASC) tie-break.
func TestSearchUsers_LengthTieBreak(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, shortU := mustRegister(t, srv, "axyzb", "shortu@example.com", "password-123")
	setUserDisplayName(t, shortU, "Short")
	setUserCreatedAt(t, shortU, time.Now().Add(-2*time.Hour))

	_, longU := mustRegister(t, srv, "aaaxyzbbb", "longu@example.com", "password-123")
	setUserDisplayName(t, longU, "Long")
	setUserCreatedAt(t, longU, time.Now().Add(-1*time.Hour))

	code, page, raw := doSearch(t, srv, "", "xyz", "", 0)
	if code != http.StatusOK {
		t.Fatalf("search: %d body=%s", code, raw)
	}
	if len(page.Items) != 2 {
		t.Fatalf("got %d rows, want 2 — body=%s", len(page.Items), raw)
	}
	if page.Items[0].ID != shortU {
		t.Errorf("position 0: got %s want shorter username %s", page.Items[0].ID, shortU)
	}
	if page.Items[1].ID != longU {
		t.Errorf("position 1: got %s want longer username %s", page.Items[1].ID, longU)
	}
}

// TestSearchUsers_LikeMetacharEscaped — `%%` / `__` (≥2 chars so they
// clear the min-2 gate) must NOT match every user. The repo escapes
// LIKE metachars before binding so user-supplied wildcards stay
// literal substrings.
func TestSearchUsers_LikeMetacharEscaped(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, _ = mustRegister(t, srv, "alice", "alice@example.com", "password-123")
	_, _ = mustRegister(t, srv, "bobby", "bobby@example.com", "password-123")

	for _, q := range []string{"%%", "__", `\\`, "%_"} {
		code, page, raw := doSearch(t, srv, "", q, "", 0)
		if code != http.StatusOK {
			t.Fatalf("q=%q: status=%d body=%s", q, code, raw)
		}
		if len(page.Items) != 0 {
			t.Errorf("q=%q: got %d items, want 0 (metachars must not match-all): body=%s",
				q, len(page.Items), raw)
		}
	}
}
