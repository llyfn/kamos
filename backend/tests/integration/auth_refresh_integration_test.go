//go:build integration
// +build integration

package integration

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"
)

// doRefresh exchanges a refresh token for a new pair, returning the
// (status, parsed authResponse, raw body) tuple.
func doRefresh(t *testing.T, srvURL, refresh string) (int, authResponse, []byte) {
	t.Helper()
	body, _ := json.Marshal(map[string]string{"refresh_token": refresh})
	req, err := http.NewRequest(http.MethodPost, srvURL+"/v1/auth/refresh", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("new req: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer resp.Body.Close()
	raw := readAll(t, resp.Body)
	var out authResponse
	_ = json.Unmarshal(raw, &out)
	return resp.StatusCode, out, raw
}

func readAll(t *testing.T, r interface{ Read(p []byte) (int, error) }) []byte {
	t.Helper()
	buf := make([]byte, 0, 1024)
	tmp := make([]byte, 1024)
	for {
		n, err := r.Read(tmp)
		if n > 0 {
			buf = append(buf, tmp[:n]...)
		}
		if err != nil {
			break
		}
	}
	return buf
}

// TestRefreshRoundTrip — happy path:
//
//	register → access + refresh issued
//	exchange refresh → new access + refresh
//	re-use the OLD refresh → 401, family revoked, WARN log emitted, the
//	second-generation refresh ALSO no longer works (family burned).
func TestRefreshRoundTrip(t *testing.T) {
	truncateAll(t)
	var logs bytes.Buffer
	srv := buildServerWithTTL(t, true, time.Hour, 30*24*time.Hour, &logs)
	defer srv.Close()

	const (
		uname = "rotator"
		email = "rotator@example.com"
		pwd   = "hunter2hunter2"
	)
	// Register issues the original pair.
	body := map[string]any{
		"username":     uname,
		"email":        email,
		"password":     pwd,
		"display_name": uname,
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, raw)
	}
	var ar authResponse
	if err := json.Unmarshal(raw, &ar); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if ar.AccessToken == "" || ar.RefreshToken == "" {
		t.Fatalf("missing token(s) in register response: %s", raw)
	}
	if len(ar.RefreshToken) != 43 {
		t.Errorf("refresh_token length: got %d want 43", len(ar.RefreshToken))
	}
	if ar.RefreshExpiresIn <= 0 {
		t.Errorf("refresh_expires_in: %d", ar.RefreshExpiresIn)
	}
	if ar.TokenType != "Bearer" {
		t.Errorf("token_type: %q", ar.TokenType)
	}

	// Exchange the refresh — should issue a fresh access + refresh, with the
	// refresh being a different secret.
	code, ar2, raw := doRefresh(t, srv.URL, ar.RefreshToken)
	if code != http.StatusOK {
		t.Fatalf("refresh: %d %s", code, raw)
	}
	if ar2.AccessToken == "" || ar2.RefreshToken == "" {
		t.Fatalf("refresh response missing fields: %s", raw)
	}
	if ar2.RefreshToken == ar.RefreshToken {
		t.Fatalf("rotation returned the same refresh token")
	}

	// Re-use the OLD (already revoked) token → 401 + family-wide revoke.
	code, _, raw = doRefresh(t, srv.URL, ar.RefreshToken)
	if code != http.StatusUnauthorized {
		t.Fatalf("re-use should be 401, got %d %s", code, raw)
	}

	// The WARN log line must mention re-use detection.
	if !strings.Contains(logs.String(), "refresh_token_reuse_detected") {
		t.Errorf("expected refresh_token_reuse_detected in logs, got:\n%s", logs.String())
	}

	// The newer refresh (ar2) should now also be revoked (family burned).
	code, _, raw = doRefresh(t, srv.URL, ar2.RefreshToken)
	if code != http.StatusUnauthorized {
		t.Fatalf("post-reuse, family-burned refresh should be 401, got %d %s", code, raw)
	}
}

// TestRefreshExpiry — a token issued with TTL=1s is rejected after sleeping
// past expiry. No family revocation (expiry is benign, not theft).
func TestRefreshExpiry(t *testing.T) {
	truncateAll(t)
	srv := buildServerWithTTL(t, true, time.Hour, 1*time.Second, nil)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "expiree", "expire@example.com", "hunter2hunter2")
	_ = tok
	// Pull the refresh out of register by re-doing the call so we capture it.
	// (mustRegister discards the response body beyond access_token.)
	body := map[string]any{
		"username":     "expiree2",
		"email":        "expire2@example.com",
		"password":     "hunter2hunter2",
		"display_name": "expiree2",
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, raw)
	}
	var ar authResponse
	_ = json.Unmarshal(raw, &ar)
	if ar.RefreshToken == "" {
		t.Fatalf("missing refresh_token")
	}

	// Sleep past TTL.
	time.Sleep(2 * time.Second)

	code, _, raw = doRefresh(t, srv.URL, ar.RefreshToken)
	if code != http.StatusUnauthorized {
		t.Fatalf("expired refresh should be 401, got %d %s", code, raw)
	}
	// The error code should be TOKEN_EXPIRED (distinguishable from
	// TOKEN_INVALID for the client UX).
	var e map[string]any
	_ = json.Unmarshal(raw, &e)
	if got := e["code"]; got != "TOKEN_EXPIRED" {
		t.Errorf("code: got %v want TOKEN_EXPIRED", got)
	}
}

// TestLogoutSingleToken — POST /v1/auth/logout with a refresh_token revokes
// ONLY that token; other refresh tokens for the same user keep working.
func TestLogoutSingleToken(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Two parallel "device" sessions for the same user via register+login.
	body := map[string]any{
		"username":     "twodev",
		"email":        "twodev@example.com",
		"password":     "hunter2hunter2",
		"display_name": "twodev",
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, raw)
	}
	var deviceA authResponse
	_ = json.Unmarshal(raw, &deviceA)

	// Login again to issue an independent refresh-token family for "device B".
	code, raw = doReq(t, srv, http.MethodPost, "/v1/auth/login", "", map[string]string{
		"email":    "twodev@example.com",
		"password": "hunter2hunter2",
	})
	if code != http.StatusOK {
		t.Fatalf("login: %d %s", code, raw)
	}
	var deviceB authResponse
	_ = json.Unmarshal(raw, &deviceB)

	if deviceA.RefreshToken == deviceB.RefreshToken {
		t.Fatalf("two sessions issued the same refresh token")
	}

	// Logout device A (with its refresh_token).
	logoutBody := map[string]string{"refresh_token": deviceA.RefreshToken}
	code, raw = doReq(t, srv, http.MethodPost, "/v1/auth/logout", deviceA.AccessToken, logoutBody)
	if code != http.StatusNoContent {
		t.Fatalf("logout A: %d %s", code, raw)
	}

	// Device A's refresh is now dead.
	code, _, raw = doRefresh(t, srv.URL, deviceA.RefreshToken)
	if code != http.StatusUnauthorized {
		t.Fatalf("device A refresh should be 401 after logout, got %d %s", code, raw)
	}

	// Device B's refresh still works.
	code, ar, raw := doRefresh(t, srv.URL, deviceB.RefreshToken)
	if code != http.StatusOK {
		t.Fatalf("device B refresh should still work, got %d %s", code, raw)
	}
	if ar.AccessToken == "" || ar.RefreshToken == "" {
		t.Fatalf("device B rotation missing fields")
	}
}

// TestLogoutAllTokens — POST /v1/auth/logout without a body revokes every
// active refresh token for the user.
func TestLogoutAllTokens(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	body := map[string]any{
		"username":     "allgone",
		"email":        "allgone@example.com",
		"password":     "hunter2hunter2",
		"display_name": "allgone",
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, raw)
	}
	var deviceA authResponse
	_ = json.Unmarshal(raw, &deviceA)

	code, raw = doReq(t, srv, http.MethodPost, "/v1/auth/login", "", map[string]string{
		"email":    "allgone@example.com",
		"password": "hunter2hunter2",
	})
	if code != http.StatusOK {
		t.Fatalf("login: %d %s", code, raw)
	}
	var deviceB authResponse
	_ = json.Unmarshal(raw, &deviceB)

	// POST /v1/auth/logout with no body (using deviceA's access_token).
	req, err := http.NewRequest(http.MethodPost, srv.URL+"/v1/auth/logout", nil)
	if err != nil {
		t.Fatalf("new req: %v", err)
	}
	req.Header.Set("Authorization", "Bearer "+deviceA.AccessToken)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("logout all: %d", resp.StatusCode)
	}

	// Both devices' refresh tokens must be dead.
	if code, _, _ := doRefresh(t, srv.URL, deviceA.RefreshToken); code != http.StatusUnauthorized {
		t.Errorf("deviceA refresh after logout-all: %d", code)
	}
	if code, _, _ := doRefresh(t, srv.URL, deviceB.RefreshToken); code != http.StatusUnauthorized {
		t.Errorf("deviceB refresh after logout-all: %d", code)
	}
}

// TestRefreshTokenRotationRace — SEC-010. N concurrent refreshes against
// the same predecessor must result in exactly one successor; the other
// N-1 receive TOKEN_INVALID. Previously these would each insert a
// successor with the predecessor (un-revoked) under read-committed
// isolation, producing N valid children. The RotateAtomic single-tx
// UPDATE … WHERE revoked_at IS NULL closes the window.
func TestRefreshTokenRotationRace(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	body := map[string]any{
		"username":     "racer",
		"email":        "racer@example.com",
		"password":     "hunter2hunter2",
		"display_name": "racer",
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, raw)
	}
	var arA authResponse
	_ = json.Unmarshal(raw, &arA)

	const N = 8
	type res struct {
		code int
		ar   authResponse
	}
	results := make(chan res, N)
	// Bar the goroutines all start at the same time.
	start := make(chan struct{})
	for i := 0; i < N; i++ {
		go func() {
			<-start
			code, ar, _ := doRefresh(t, srv.URL, arA.RefreshToken)
			results <- res{code: code, ar: ar}
		}()
	}
	close(start)

	wins := 0
	losses := 0
	for i := 0; i < N; i++ {
		r := <-results
		switch r.code {
		case http.StatusOK:
			wins++
			if r.ar.RefreshToken == "" {
				t.Fatalf("winner missing refresh_token")
			}
		case http.StatusUnauthorized:
			losses++
		default:
			t.Fatalf("unexpected status %d on concurrent refresh", r.code)
		}
	}
	if wins != 1 {
		t.Fatalf("expected exactly 1 successful rotation, got %d (%d losses)", wins, losses)
	}
	if losses != N-1 {
		t.Fatalf("expected %d losing rotations, got %d", N-1, losses)
	}
}

// TestVerificationTokenLookupByHash — SEC-004. The verify-email flow must
// claim the row by token_hash; the DB must not retain the plaintext.
// We verify by:
//  1. Registering a user (which creates a verification token row).
//  2. Asserting the row has a non-null token_hash and that the table
//     schema no longer carries a `token` column at all (migration 010
//     dropped it).
//  3. Posting a tampered token through /v1/auth/verify-email and
//     asserting 410 TOKEN_EXPIRED — proof that lookup is by hash.
func TestVerificationTokenLookupByHash(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	body := map[string]any{
		"username":     "verifier",
		"email":        "verifier@example.com",
		"password":     "hunter2hunter2",
		"display_name": "verifier",
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, raw)
	}

	p := getPool(t)
	// Schema check — the column must be gone.
	var hasTokenColumn bool
	if err := p.QueryRow(context.Background(), `
SELECT EXISTS(
  SELECT 1 FROM information_schema.columns
  WHERE table_name = 'email_verifications' AND column_name = 'token'
);`).Scan(&hasTokenColumn); err != nil {
		t.Fatalf("schema query: %v", err)
	}
	if hasTokenColumn {
		t.Fatalf("email_verifications still has the plaintext token column; migration 010 not applied")
	}

	// At least one row exists with a non-null token_hash.
	var hashCount int
	if err := p.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM email_verifications WHERE token_hash IS NOT NULL;`).Scan(&hashCount); err != nil {
		t.Fatalf("hash count: %v", err)
	}
	if hashCount == 0 {
		t.Fatalf("no email_verifications rows with token_hash")
	}

	// A made-up token must be rejected with 410 TOKEN_EXPIRED (which is
	// how domain.ErrTokenExpired maps).
	code, raw = doReq(t, srv, http.MethodPost, "/v1/auth/verify-email", "",
		map[string]string{"token": "definitely-not-the-real-token"})
	if code != http.StatusGone {
		t.Fatalf("bogus verify token: expected 410, got %d %s", code, raw)
	}
}

// TestRefreshCompromiseDetection — chain A → B → C; after C is the active
// leaf, replay B → 401, entire family revoked, neither B nor C usable.
func TestRefreshCompromiseDetection(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	body := map[string]any{
		"username":     "chained",
		"email":        "chained@example.com",
		"password":     "hunter2hunter2",
		"display_name": "chained",
		"locale":       "en",
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/register", "", body)
	if code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, raw)
	}
	var arA authResponse
	_ = json.Unmarshal(raw, &arA)

	// A → B
	code, arB, raw := doRefresh(t, srv.URL, arA.RefreshToken)
	if code != http.StatusOK {
		t.Fatalf("A→B refresh: %d %s", code, raw)
	}
	// B → C
	code, arC, raw := doRefresh(t, srv.URL, arB.RefreshToken)
	if code != http.StatusOK {
		t.Fatalf("B→C refresh: %d %s", code, raw)
	}
	if arC.RefreshToken == arB.RefreshToken || arC.RefreshToken == arA.RefreshToken {
		t.Fatalf("rotation produced a non-unique token")
	}

	// Adversary replays B (already revoked by the A→B rotation).
	code, _, raw = doRefresh(t, srv.URL, arB.RefreshToken)
	if code != http.StatusUnauthorized {
		t.Fatalf("replay B should 401, got %d %s", code, raw)
	}

	// Family is now burned: C must also be rejected.
	code, _, raw = doRefresh(t, srv.URL, arC.RefreshToken)
	if code != http.StatusUnauthorized {
		t.Fatalf("post-compromise C should 401, got %d %s", code, raw)
	}
	// And A is already revoked from the first rotation — still 401.
	code, _, raw = doRefresh(t, srv.URL, arA.RefreshToken)
	if code != http.StatusUnauthorized {
		t.Fatalf("A should remain 401, got %d %s", code, raw)
	}
}
