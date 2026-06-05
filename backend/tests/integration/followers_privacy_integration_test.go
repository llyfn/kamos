//go:build integration
// +build integration

// Privacy gate on followers/following list endpoints. When the target
// user's privacy_mode = 'private', the list surfaces are visible only
// to the target themselves and their accepted followers. Mirrors the
// gate already applied to GET /v1/users/{username} and to the
// user-beverages endpoint.

package integration

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestFollowersPrivateProfileGate — a private user with two accepted
// followers (bob, carol) is queried by `dave` (not following). The
// followers list MUST 403 PRIVATE_PROFILE. Once dave follows alice
// and is approved, the list MUST return 200 with both pre-existing
// followers visible.
func TestFollowersPrivateProfileGate(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, aliceID := mustRegister(t, srv, "alice_p", "ap@example.com", "password-123")
	bobTok, _ := mustRegister(t, srv, "bob_p", "bp@example.com", "password-123")
	carolTok, _ := mustRegister(t, srv, "carol_p", "cp@example.com", "password-123")
	daveTok, _ := mustRegister(t, srv, "dave_p", "dp@example.com", "password-123")

	// bob + carol follow alice while she is still public, so the
	// follow rows land status='accepted' immediately.
	for _, tok := range []string{bobTok, carolTok} {
		code, raw := doReq(t, srv, http.MethodPost, "/v1/users/alice_p/follow", tok, nil)
		if code != http.StatusOK {
			t.Fatalf("follow alice: %d body=%s", code, raw)
		}
	}

	// Flip alice to private. Existing accepted follows remain
	// accepted; future follows arrive as pending.
	setUserPrivacy(t, aliceID, "private")

	// dave (not following) is blocked.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/alice_p/followers", daveTok, nil)
	if code != http.StatusForbidden {
		t.Fatalf("non-follower viewer: got %d body=%s, want 403", code, raw)
	}
	var e map[string]any
	_ = json.Unmarshal(raw, &e)
	if e["code"] != "PRIVATE_PROFILE" {
		t.Errorf("code=%v want PRIVATE_PROFILE", e["code"])
	}

	// Anonymous viewer is also blocked.
	code, _ = doReq(t, srv, http.MethodGet, "/v1/users/alice_p/followers", "", nil)
	if code != http.StatusForbidden {
		t.Errorf("anonymous: got %d, want 403", code)
	}

	// dave requests to follow alice → pending (alice is private).
	code, raw = doReq(t, srv, http.MethodPost, "/v1/users/alice_p/follow", daveTok, nil)
	if code != http.StatusOK {
		t.Fatalf("dave request: %d body=%s", code, raw)
	}
	var resp map[string]any
	_ = json.Unmarshal(raw, &resp)
	if resp["status"] != "pending" {
		t.Errorf("dave request status=%v, want pending", resp["status"])
	}
	// Pending must NOT grant access — only accepted does.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/alice_p/followers", daveTok, nil)
	if code != http.StatusForbidden {
		t.Errorf("pending follower: got %d body=%s, want 403", code, raw)
	}

	// Alice approves dave via /v1/follow-requests/{followerID}/approve.
	aliceTok := mustLogin(t, srv, "ap@example.com", "password-123")
	daveID := lookupPublicUserID(t, srv, "dave_p")
	code, raw = doReq(t, srv, http.MethodPost, "/v1/follow-requests/"+daveID+"/approve", aliceTok, nil)
	if code != http.StatusOK {
		t.Fatalf("approve: %d body=%s", code, raw)
	}

	// Now accepted — dave can list alice's followers.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/alice_p/followers", daveTok, nil)
	if code != http.StatusOK {
		t.Fatalf("accepted follower: got %d body=%s, want 200", code, raw)
	}
	if !strings.Contains(string(raw), `"bob_p"`) || !strings.Contains(string(raw), `"carol_p"`) {
		t.Errorf("expected bob_p + carol_p in followers, got %s", raw)
	}

	// Sanity: alice herself can always list.
	code, _ = doReq(t, srv, http.MethodGet, "/v1/users/alice_p/followers", aliceTok, nil)
	if code != http.StatusOK {
		t.Errorf("self viewer: got %d, want 200", code)
	}
}

// TestFollowingPrivateProfileGate — same gating shape on /following.
// alice (private) follows bob + carol (both public). Non-follower
// dave can't list alice's following; pending dave still can't; once
// approved, dave can.
func TestFollowingPrivateProfileGate(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	aliceTok, aliceID := mustRegister(t, srv, "alice_f", "af@example.com", "password-123")
	mustRegister(t, srv, "bob_f", "bf@example.com", "password-123")
	mustRegister(t, srv, "carol_f", "cf@example.com", "password-123")
	daveTok, _ := mustRegister(t, srv, "dave_f", "df@example.com", "password-123")

	// alice follows bob + carol while public.
	for _, name := range []string{"bob_f", "carol_f"} {
		code, raw := doReq(t, srv, http.MethodPost, "/v1/users/"+name+"/follow", aliceTok, nil)
		if code != http.StatusOK {
			t.Fatalf("alice follow %s: %d body=%s", name, code, raw)
		}
	}

	// Flip alice to private.
	setUserPrivacy(t, aliceID, "private")

	// dave (not following alice) is blocked.
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/alice_f/following", daveTok, nil)
	if code != http.StatusForbidden {
		t.Fatalf("non-follower: got %d body=%s, want 403", code, raw)
	}
	var e map[string]any
	_ = json.Unmarshal(raw, &e)
	if e["code"] != "PRIVATE_PROFILE" {
		t.Errorf("code=%v want PRIVATE_PROFILE", e["code"])
	}

	// dave requests to follow alice → pending → still blocked.
	code, _ = doReq(t, srv, http.MethodPost, "/v1/users/alice_f/follow", daveTok, nil)
	if code != http.StatusOK {
		t.Fatalf("dave request: %d", code)
	}
	code, _ = doReq(t, srv, http.MethodGet, "/v1/users/alice_f/following", daveTok, nil)
	if code != http.StatusForbidden {
		t.Errorf("pending follower: got %d, want 403", code)
	}

	// alice approves dave; dave can now list alice's following.
	daveID := lookupPublicUserID(t, srv, "dave_f")
	code, raw = doReq(t, srv, http.MethodPost, "/v1/follow-requests/"+daveID+"/approve", aliceTok, nil)
	if code != http.StatusOK {
		t.Fatalf("approve: %d body=%s", code, raw)
	}
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/alice_f/following", daveTok, nil)
	if code != http.StatusOK {
		t.Fatalf("accepted follower: got %d body=%s, want 200", code, raw)
	}
	if !strings.Contains(string(raw), `"bob_f"`) || !strings.Contains(string(raw), `"carol_f"`) {
		t.Errorf("expected bob_f + carol_f in following, got %s", raw)
	}
}

// lookupPublicUserID resolves a username to its uuid via GET
// /v1/users/{username}. The follow-request approve route is keyed
// by follower id (not username) so the test needs the lookup.
// Mirrors the inline pattern in social_integration_test.go.
func lookupPublicUserID(t *testing.T, srv *httptest.Server, username string) string {
	t.Helper()
	code, raw := doReq(t, srv, http.MethodGet, "/v1/users/"+username, "", nil)
	if code != http.StatusOK {
		t.Fatalf("lookup %s: %d body=%s", username, code, raw)
	}
	var p map[string]any
	_ = json.Unmarshal(raw, &p)
	id, _ := p["id"].(string)
	if id == "" {
		t.Fatalf("lookup %s: no id in %s", username, raw)
	}
	return id
}
