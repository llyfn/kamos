package cache

import (
	"context"
	"io"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

// TestInvalidatorBustsBundleOnNotify exercises the full
// Invalidator.Start → NOTIFY → bundle.InvalidatePrefix dance against a
// real Postgres. Skipped when INTEGRATION_DATABASE_URL is not set.
func TestInvalidatorBustsBundleOnNotify(t *testing.T) {
	dsn := os.Getenv("INTEGRATION_DATABASE_URL")
	if dsn == "" {
		t.Skip("INTEGRATION_DATABASE_URL not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	defer pool.Close()

	bundle := NewCaches()
	const bevID = "11111111-1111-1111-1111-111111111111"
	bundle.BeverageDetail.Set(bevID+":en", domain.BeverageDetail{
		Beverage: domain.Beverage{ID: bevID},
	})
	if _, ok := bundle.BeverageDetail.Get(bevID + ":en"); !ok {
		t.Fatalf("seed: bundle Get should hit")
	}

	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	inv := NewInvalidator(pool, bundle, log)
	// Snappy backoff so transient errors don't waste the test budget.
	inv.minBackoff = 50 * time.Millisecond
	inv.maxBackoff = 200 * time.Millisecond

	invCtx, invCancel := context.WithCancel(ctx)
	defer invCancel()
	done := make(chan struct{})
	go func() {
		inv.Start(invCtx)
		close(done)
	}()
	defer func() {
		inv.Stop()
		invCancel()
		<-done
	}()

	// Tiny race window between Start() spawning and LISTEN completing on
	// the held connection. Poll the bundle until either the entry
	// disappears or the deadline fires.
	NotifyInvalidation(ctx, pool, log, "beverage:"+bevID)

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if _, ok := bundle.BeverageDetail.Get(bevID + ":en"); !ok {
			return // success
		}
		// Re-publish in case the listener was not yet connected when we
		// first fired. This is idempotent.
		NotifyInvalidation(ctx, pool, log, "beverage:"+bevID)
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("invalidator did not bust bundle entry within 2s")
}

func TestInvalidatorNilSafe(t *testing.T) {
	// Nil receivers must not panic; Start is a no-op.
	var inv *Invalidator
	inv.Start(context.Background())
	inv.Stop()
}
