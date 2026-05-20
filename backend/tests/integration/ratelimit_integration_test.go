//go:build integration
// +build integration

package integration

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"sync"
	"testing"
)

// Hammering /v1/auth/login from the same IP must produce at least one 429
// with the canonical body — the per-IP brute-force limit on /v1/auth/*
// is 5 rps / burst 10.
//
// Note: SEC-018 made the login "not found" path do a bcrypt compare to
// equalize timing, so 12 sequential calls now take ~3s, well above the
// limiter's 1s refill window. We fire them in parallel so the burst is
// exhausted before any refill happens.
func TestRateLimitAuthBruteForce(t *testing.T) {
	truncateAll(t)
	srv := newServerWithRateLimit(t)
	defer srv.Close()

	body, _ := json.Marshal(map[string]string{"email": "nobody@example.com", "password": "wrong"})

	const N = 24
	type res struct {
		code int
		body []byte
	}
	out := make(chan res, N)
	start := make(chan struct{})
	var wg sync.WaitGroup
	wg.Add(N)
	for i := 0; i < N; i++ {
		go func() {
			defer wg.Done()
			<-start
			req, _ := http.NewRequest(http.MethodPost, srv.URL+"/v1/auth/login", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				out <- res{code: -1}
				return
			}
			defer resp.Body.Close()
			raw, _ := io.ReadAll(resp.Body)
			out <- res{code: resp.StatusCode, body: raw}
		}()
	}
	close(start)
	wg.Wait()
	close(out)

	saw429 := false
	var sample []byte
	for r := range out {
		if r.code == http.StatusTooManyRequests {
			saw429 = true
			sample = r.body
		}
	}
	if !saw429 {
		t.Fatalf("expected at least one 429 across %d concurrent login attempts", N)
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
