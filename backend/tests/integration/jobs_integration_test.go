//go:build integration
// +build integration

package integration

import (
	"context"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/jobs"
)

// Username-hold cleanup: a soft-deleted user with username_release_at in
// the PAST is renamed to a 'del_<id>' tombstone so the original username
// is freed for re-registration. A held user whose release time is still
// in the future is untouched.
func TestJobUsernameHoldCleanup(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	// Two users: 'expired' (release time 1d ago) and 'fresh' (release in 7d).
	_, expiredID := mustRegister(t, srv, "expired", "expired@example.com", "password1")
	_, freshID := mustRegister(t, srv, "fresh", "fresh@example.com", "password2")

	p := getPool(t)
	ctx := context.Background()
	if _, err := p.Exec(ctx, `
UPDATE users SET deleted_at = NOW() - INTERVAL '40 days',
                 username_release_at = NOW() - INTERVAL '10 days'
WHERE id = $1;`, expiredID); err != nil {
		t.Fatalf("soft-delete expired: %v", err)
	}
	if _, err := p.Exec(ctx, `
UPDATE users SET deleted_at = NOW() - INTERVAL '5 days',
                 username_release_at = NOW() + INTERVAL '25 days'
WHERE id = $1;`, freshID); err != nil {
		t.Fatalf("soft-delete fresh: %v", err)
	}

	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	if err := jobs.JobUsernameHoldCleanup(log)(ctx, p); err != nil {
		t.Fatalf("job: %v", err)
	}

	var expUsername, expDisplay string
	if err := p.QueryRow(ctx, `SELECT username, display_username FROM users WHERE id = $1`,
		expiredID).Scan(&expUsername, &expDisplay); err != nil {
		t.Fatalf("query expired: %v", err)
	}
	if expUsername == "expired" {
		t.Errorf("expired user's username should have been tombstoned, got %q", expUsername)
	}
	if expUsername[:4] != "del_" {
		t.Errorf("tombstone prefix missing: %q", expUsername)
	}
	if expDisplay != expUsername {
		t.Errorf("display_username should match username after tombstone: %q vs %q", expDisplay, expUsername)
	}

	var freshUsername string
	if err := p.QueryRow(ctx, `SELECT username FROM users WHERE id = $1`,
		freshID).Scan(&freshUsername); err != nil {
		t.Fatalf("query fresh: %v", err)
	}
	if freshUsername != "fresh" {
		t.Errorf("non-expired user got renamed: %q", freshUsername)
	}

	// Re-running the job is idempotent (the tombstoned row is skipped).
	if err := jobs.JobUsernameHoldCleanup(log)(ctx, p); err != nil {
		t.Fatalf("idempotent re-run: %v", err)
	}
	var doubleRun string
	if err := p.QueryRow(ctx, `SELECT username FROM users WHERE id = $1`,
		expiredID).Scan(&doubleRun); err != nil {
		t.Fatalf("query after re-run: %v", err)
	}
	if doubleRun != expUsername {
		t.Errorf("idempotency: expected %q, got %q", expUsername, doubleRun)
	}

	// The original 'expired' name is now available for re-registration —
	// the held-set partial index no longer matches it.
	mustRegister(t, srv, "expired", "newexpired@example.com", "password3")
}

// Email-verification cleanup removes rows that expired more than 7 days
// ago. Rows that are merely expired but still within the 7-day grace
// stay put.
func TestJobEmailVerificationCleanup(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	_, userID := mustRegister(t, srv, "tokenowner", "token@example.com", "password1")

	p := getPool(t)
	ctx := context.Background()
	// Seed three tokens with different expires_at values. SEC-004 (migration
	// 010): the DB column is now token_hash (BYTEA SHA-256). We compute the
	// hash from the raw token here so the test mirrors the application path.
	insert := func(token string, expiresOffset time.Duration) {
		hash := auth.HashVerificationToken(token)
		if _, err := p.Exec(ctx, `
INSERT INTO email_verifications (user_id, token_hash, expires_at)
VALUES ($1, $2, NOW() + $3::interval);`, userID, hash, expiresOffset.String()); err != nil {
			t.Fatalf("seed token %q: %v", token, err)
		}
	}
	insert("fresh", 24*time.Hour)             // future expiry → keep
	insert("grace", -3*24*time.Hour)          // expired 3d ago → keep
	insert("oldold", -10*24*time.Hour)        // expired 10d ago → delete

	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	if err := jobs.JobEmailVerificationCleanup(log)(ctx, p); err != nil {
		t.Fatalf("job: %v", err)
	}

	var n int
	if err := p.QueryRow(ctx, `SELECT COUNT(*) FROM email_verifications`).Scan(&n); err != nil {
		t.Fatalf("count: %v", err)
	}
	// Note: register() inserts one verification token of its own + our 3.
	// register's token is fresh, so it survives. Total: register + fresh + grace.
	if n != 3 {
		t.Errorf("expected 3 surviving rows (register + fresh + grace); got %d", n)
	}

	var oldExists bool
	oldHash := auth.HashVerificationToken("oldold")
	if err := p.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM email_verifications WHERE token_hash = $1)`, oldHash).Scan(&oldExists); err != nil {
		t.Fatalf("exists: %v", err)
	}
	if oldExists {
		t.Errorf("oldold token should have been deleted")
	}
}

// Avg-rating sweep: deliberately corrupt a beverage's denormalized
// avg_rating + check_in_count, then run the job; the row should be
// recomputed from the underlying check_ins.
func TestJobAvgRatingSweep(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()
	tok, _ := mustRegister(t, srv, "rater", "rater@example.com", "password1")

	bevID := seedBeverage(t, "Drink")
	// Two rated check-ins via the API — the trigger will keep the
	// beverage row in sync.
	for _, r := range []float64{4.0, 5.0} {
		code, _ := doReq(t, srv, "POST", "/v1/check-ins", tok, map[string]any{
			"beverage_id": bevID,
			"rating":      r,
		})
		if code != 201 {
			t.Fatalf("check-in create: %d", code)
		}
	}

	p := getPool(t)
	ctx := context.Background()
	// Sanity: trigger set avg=4.50, count=2.
	var avg float64
	var cnt int
	if err := p.QueryRow(ctx, `SELECT avg_rating, check_in_count FROM beverages WHERE id = $1`,
		bevID).Scan(&avg, &cnt); err != nil {
		t.Fatalf("read trigger state: %v", err)
	}
	if avg != 4.50 || cnt != 2 {
		t.Fatalf("trigger state: avg=%v cnt=%d", avg, cnt)
	}

	// Corrupt the denormalized columns directly.
	if _, err := p.Exec(ctx,
		`UPDATE beverages SET avg_rating = 1.00, check_in_count = 99 WHERE id = $1`, bevID); err != nil {
		t.Fatalf("corrupt: %v", err)
	}

	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	if err := jobs.JobAvgRatingSweep(log)(ctx, p); err != nil {
		t.Fatalf("job: %v", err)
	}

	if err := p.QueryRow(ctx, `SELECT avg_rating, check_in_count FROM beverages WHERE id = $1`,
		bevID).Scan(&avg, &cnt); err != nil {
		t.Fatalf("read after sweep: %v", err)
	}
	if avg != 4.50 || cnt != 2 {
		t.Errorf("after sweep: avg=%v cnt=%d (want 4.50/2)", avg, cnt)
	}

	// Re-running is a no-op now that the row matches the recomputed values.
	if err := jobs.JobAvgRatingSweep(log)(ctx, p); err != nil {
		t.Fatalf("re-run: %v", err)
	}
}
