//go:build integration
// +build integration

package integration

import (
	"encoding/json"
	"net/http"
	"testing"
)

// Hammering /v1/auth/login 12 times in <1s from the same IP must produce
// at least one 429 with the canonical body — the per-IP brute-force
// limit on /v1/auth/* is 5 rps / burst 10.
func TestRateLimitAuthBruteForce(t *testing.T) {
	truncateAll(t)
	srv := newServerWithRateLimit(t)
	defer srv.Close()

	body := map[string]string{"email": "nobody@example.com", "password": "wrong"}
	saw429 := false
	var sample []byte
	for i := 0; i < 12; i++ {
		code, raw := doReq(t, srv, http.MethodPost, "/v1/auth/login", "", body)
		if code == http.StatusTooManyRequests {
			saw429 = true
			sample = raw
			break
		}
	}
	if !saw429 {
		t.Fatalf("expected at least one 429 within 12 rapid login attempts")
	}
	var e map[string]any
	if err := json.Unmarshal(sample, &e); err != nil {
		t.Fatalf("decode 429 body: %v (raw=%s)", err, sample)
	}
	if e["code"] != "RATE_LIMITED" {
		t.Errorf("429 code: got %v want RATE_LIMITED (body=%s)", e["code"], sample)
	}
	if e["error"] != "rate_limited" {
		t.Errorf("429 error: got %v want rate_limited", e["error"])
	}
}
