//go:build integration
// +build integration

package integration

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

// Public flow: follow → followers list includes the follower → unfollow.
func TestFollowAndUnfollow(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokA, _ := mustRegister(t, srv, "usera", "a@example.com", "password11")
	mustRegister(t, srv, "userb", "b@example.com", "password11")

	// A follows B → status=accepted (B is public by default).
	code, raw := doReq(t, srv, http.MethodPost, "/v1/users/userb/follow", tokA, nil)
	if code != http.StatusOK {
		t.Fatalf("follow: %d body=%s", code, raw)
	}
	var follow map[string]any
	_ = json.Unmarshal(raw, &follow)
	if follow["status"] != "accepted" {
		t.Errorf("follow status: %v", follow["status"])
	}

	// B's public profile now shows A as a follower.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/userb/followers", "", nil)
	if code != http.StatusOK {
		t.Fatalf("followers: %d body=%s", code, raw)
	}
	if !strings.Contains(string(raw), `"usera"`) {
		t.Errorf("followers list missing 'usera': %s", raw)
	}

	// A unfollows B.
	code, raw = doReq(t, srv, http.MethodDelete, "/v1/users/userb/follow", tokA, nil)
	if code != http.StatusNoContent {
		t.Fatalf("unfollow: %d body=%s", code, raw)
	}

	// Followers list no longer contains A.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/userb/followers", "", nil)
	if code != http.StatusOK {
		t.Fatalf("followers post: %d", code)
	}
	if strings.Contains(string(raw), `"usera"`) {
		t.Errorf("followers list still contains 'usera' after unfollow: %s", raw)
	}
}

// Private profile follow-request flow: A follows private B → status=pending;
// B sees the request in the inbox; B approves → A is now an accepted
// follower.
func TestFollowRequestFlowPrivate(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tokA, _ := mustRegister(t, srv, "follower", "follower@example.com", "password11")
	tokB, idB := mustRegister(t, srv, "private", "private@example.com", "password11")
	setUserPrivacy(t, idB, "private")
	_ = tokB

	// A requests to follow private B → status=pending.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/users/private/follow", tokA, nil)
	if code != http.StatusOK {
		t.Fatalf("follow private: %d body=%s", code, raw)
	}
	var resp map[string]any
	_ = json.Unmarshal(raw, &resp)
	if resp["status"] != "pending" {
		t.Errorf("status: %v want pending", resp["status"])
	}

	// B reads their follow-request inbox and sees A.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/follow-requests", tokB, nil)
	if code != http.StatusOK {
		t.Fatalf("inbox: %d body=%s", code, raw)
	}
	if !strings.Contains(string(raw), `"follower"`) {
		t.Errorf("inbox missing 'follower': %s", raw)
	}

	// Look up A's id to call /approve/{id}.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/follower", "", nil)
	if code != http.StatusOK {
		t.Fatalf("lookup A: %d", code)
	}
	var aProfile map[string]any
	_ = json.Unmarshal(raw, &aProfile)
	aID, _ := aProfile["id"].(string)
	if aID == "" {
		t.Fatalf("could not find A's id: %s", raw)
	}

	// B approves → request is accepted.
	code, raw = doReq(t, srv, http.MethodPost, "/v1/follow-requests/"+aID+"/approve", tokB, nil)
	if code != http.StatusOK {
		t.Fatalf("approve: %d body=%s", code, raw)
	}
	var approveResp map[string]any
	_ = json.Unmarshal(raw, &approveResp)
	if approveResp["status"] != "accepted" {
		t.Errorf("approve status: %v", approveResp["status"])
	}

	// B's followers list now includes A.
	code, raw = doReq(t, srv, http.MethodGet, "/v1/users/private/followers", tokB, nil)
	if code != http.StatusOK {
		t.Fatalf("followers post-approve: %d", code)
	}
	if !strings.Contains(string(raw), `"follower"`) {
		t.Errorf("followers missing 'follower' after approval: %s", raw)
	}
}

// Following yourself is rejected with 422 FOLLOW_SELF.
func TestFollowSelfRejected(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "lonely", "lonely@example.com", "password11")
	code, raw := doReq(t, srv, http.MethodPost, "/v1/users/lonely/follow", tok, nil)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("status: %d body=%s", code, raw)
	}
	var e map[string]any
	_ = json.Unmarshal(raw, &e)
	if e["code"] != "FOLLOW_SELF" {
		t.Errorf("code: %v", e["code"])
	}
}
