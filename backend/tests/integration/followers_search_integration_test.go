//go:build integration
// +build integration

// followers / following ?q= prefix search. Optional case-insensitive
// prefix filter against (username, display_name).

package integration

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

// TestFollowersWithQuery — five followers; ?q=ali matches only alice.
func TestFollowersWithQuery(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Target whose follower list we'll query.
	mustRegister(t, srv, "target", "target@example.com", "password-123")

	// Five distinct followers. Names chosen so prefix `ali` matches
	// only alice.
	followers := []struct{ name, email string }{
		{"alice", "alice@example.com"},
		{"bob", "bob@example.com"},
		{"carol", "carol@example.com"},
		{"dan", "dan@example.com"},
		{"erin", "erin@example.com"},
	}
	for _, f := range followers {
		tok, _ := mustRegister(t, srv, f.name, f.email, "password-123")
		code, raw := doReq(t, srv, http.MethodPost, "/v1/users/target/follow", tok, nil)
		if code != http.StatusOK {
			t.Fatalf("%s follow: %d body=%s", f.name, code, raw)
		}
	}

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/target/followers?q=ali", "", nil)
	if code != http.StatusOK {
		t.Fatalf("followers q: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			Username string `json:"username"`
		} `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 1 || page.Items[0].Username != "alice" {
		t.Errorf("want exactly alice, got %s", raw)
	}
}

// TestFollowingWithQuery — five users target follows; ?q=al matches
// only alice + alvin.
func TestFollowingWithQuery(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "leader", "leader@example.com", "password-123")
	follows := []struct{ name, email string }{
		{"alice", "alice2@example.com"},
		{"alvin", "alvin@example.com"},
		{"bob", "bob2@example.com"},
		{"carol", "carol2@example.com"},
		{"dan", "dan2@example.com"},
	}
	for _, f := range follows {
		mustRegister(t, srv, f.name, f.email, "password-123")
		code, raw := doReq(t, srv, http.MethodPost, "/v1/users/"+f.name+"/follow", tok, nil)
		if code != http.StatusOK {
			t.Fatalf("follow %s: %d body=%s", f.name, code, raw)
		}
	}

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/leader/following?q=al", "", nil)
	if code != http.StatusOK {
		t.Fatalf("following q: %d body=%s", code, raw)
	}
	var page struct {
		Items []struct {
			Username string `json:"username"`
		} `json:"items"`
	}
	_ = json.Unmarshal(raw, &page)
	if len(page.Items) != 2 {
		t.Fatalf("want 2 hits, got %d: %s", len(page.Items), raw)
	}
	got := map[string]bool{}
	for _, it := range page.Items {
		got[it.Username] = true
	}
	if !got["alice"] || !got["alvin"] {
		t.Errorf("want alice+alvin, got %v", got)
	}
}

// TestFollowersQueryCaseInsensitive — uppercase `q=AL` still matches
// lowercase alice.
func TestFollowersQueryCaseInsensitive(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	mustRegister(t, srv, "target_ci", "tci@example.com", "password-123")
	tok, _ := mustRegister(t, srv, "alice_ci", "ali_ci@example.com", "password-123")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/users/target_ci/follow", tok, nil)
	if code != http.StatusOK {
		t.Fatalf("follow: %d body=%s", code, raw)
	}

	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/target_ci/followers?q=AL", "", nil)
	if code != http.StatusOK {
		t.Fatalf("uppercase q: %d body=%s", code, raw)
	}
	if !strings.Contains(string(raw), `"alice_ci"`) {
		t.Errorf("uppercase q should match lowercase username: %s", raw)
	}
}

// TestFollowersQueryEscapesLikeMetacharacters — q with a literal `%`
// should NOT match anything (no usernames contain a percent sign).
// Without escaping, "al%" would wildcard-match every name starting
// with "al".
func TestFollowersQueryEscapesLikeMetacharacters(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	mustRegister(t, srv, "target_esc", "tes@example.com", "password-123")
	// Two followers whose names start with "al" — if % were treated
	// as a wildcard the response would return both.
	for _, f := range []struct{ name, email string }{
		{"alice_esc", "ali_esc@example.com"},
		{"alvin_esc", "alvin_esc@example.com"},
	} {
		tok, _ := mustRegister(t, srv, f.name, f.email, "password-123")
		code, raw := doReq(t, srv, http.MethodPost, "/v1/users/target_esc/follow", tok, nil)
		if code != http.StatusOK {
			t.Fatalf("follow %s: %d body=%s", f.name, code, raw)
		}
	}

	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/target_esc/followers?q=al%25", "", nil)
	// `al%25` is URL-encoded `al%`. Server-side the literal `%` must
	// be escaped so the LIKE pattern becomes `al\%%` — no username
	// matches.
	if code != http.StatusOK {
		t.Fatalf("escape q: %d body=%s", code, raw)
	}
	if strings.Contains(string(raw), `"alice_esc"`) || strings.Contains(string(raw), `"alvin_esc"`) {
		t.Errorf("literal `%%` leaked as a wildcard: %s", raw)
	}
}
