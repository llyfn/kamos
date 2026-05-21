package cache

import (
	"context"
	"io"
	"log/slog"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// TestNotifyInvalidationRoundTrip exercises NotifyInvalidation end-to-end
// against a real Postgres if INTEGRATION_DATABASE_URL is set. Skipped
// otherwise — the unit tests for routing live alongside the bundle.
func TestNotifyInvalidationRoundTrip(t *testing.T) {
	dsn := os.Getenv("INTEGRATION_DATABASE_URL")
	if dsn == "" {
		t.Skip("INTEGRATION_DATABASE_URL not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	defer pool.Close()

	// Subscribe on a dedicated connection (LISTEN is per-connection).
	listenerAcq, err := pool.Acquire(ctx)
	if err != nil {
		t.Fatalf("acquire: %v", err)
	}
	listener := listenerAcq.Hijack()
	defer func() {
		closeCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = listener.Close(closeCtx)
	}()
	if _, err := listener.Exec(ctx, `LISTEN "`+notifyChannelName()+`"`); err != nil {
		t.Fatalf("LISTEN: %v", err)
	}

	// Publish from the pool.
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	const payload = "beverage:abc"
	NotifyInvalidation(ctx, pool, log, payload)

	waitCtx, waitCancel := context.WithTimeout(ctx, 2*time.Second)
	defer waitCancel()
	n, err := listener.WaitForNotification(waitCtx)
	if err != nil {
		t.Fatalf("WaitForNotification: %v", err)
	}
	if n.Channel != notifyChannelName() {
		t.Fatalf("channel: want %q, got %q", notifyChannelName(), n.Channel)
	}
	if n.Payload != payload {
		t.Fatalf("payload: want %q, got %q", payload, n.Payload)
	}

	_ = pgx.ErrNoRows // keep the pgx import — explicit cross-test marker.
}

func TestNotifyInvalidationSilentOnNilDB(t *testing.T) {
	// nil pool MUST NOT panic; the helper is fire-and-forget for callers
	// in test paths that don't bring up a database.
	NotifyInvalidation(context.Background(), nil, nil, "beverage:x")
}

func TestNotifyInvalidationSilentOnEmptyPayload(t *testing.T) {
	NotifyInvalidation(context.Background(), nil, nil, "")
}
