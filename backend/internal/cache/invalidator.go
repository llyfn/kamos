package cache

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Invalidator subscribes to Postgres NOTIFY events on the
// kamos_cache_invalidate channel and routes each payload to
// bundle.InvalidatePrefix on its local replica. The dance is needed
// because pgxpool.Pool reuses connections — LISTEN registrations are
// per-connection and would silently drop the moment the pool recycled
// the listener. We acquire one connection at start, Hijack() it out of
// the pool, and keep it for the invalidator's entire lifetime.
//
// Cross-replica timing: NOTIFY → backend forwarding → WaitForNotification
// is single-digit milliseconds under nominal conditions. Paired with
// per-replica L1 (Caches) + L2 (Backend), the eventual-consistency
// window is well under 1s.
type Invalidator struct {
	pool   *pgxpool.Pool
	bundle *Caches
	log    *slog.Logger

	// backoff caps reconnect storms. Start at 500ms and double up to 30s.
	minBackoff time.Duration
	maxBackoff time.Duration

	// mu guards conn during Stop / loop reconnect handoff.
	mu     sync.Mutex
	conn   *pgx.Conn
	closed bool
}

// NewInvalidator wires the invalidator with sensible defaults. The
// returned value is inert until Start is called.
func NewInvalidator(pool *pgxpool.Pool, bundle *Caches, log *slog.Logger) *Invalidator {
	return &Invalidator{
		pool:       pool,
		bundle:     bundle,
		log:        log,
		minBackoff: 500 * time.Millisecond,
		maxBackoff: 30 * time.Second,
	}
}

// Start blocks on the LISTEN loop until ctx is canceled. Intended to run
// in its own goroutine. On connection failure the loop sleeps with
// exponential backoff (500ms → 30s) and reconnects. ctx cancellation
// drains the connection and returns nil.
func (inv *Invalidator) Start(ctx context.Context) {
	if inv == nil || inv.pool == nil || inv.bundle == nil {
		return
	}
	backoff := inv.minBackoff
	for {
		if ctx.Err() != nil {
			return
		}
		err := inv.runOnce(ctx)
		if err == nil || errors.Is(err, context.Canceled) {
			return
		}
		if inv.log != nil {
			inv.log.Warn("cache_invalidator_disconnected",
				"err", err, "backoff", backoff.String())
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
		}
		backoff *= 2
		if backoff > inv.maxBackoff {
			backoff = inv.maxBackoff
		}
	}
}

// runOnce acquires + hijacks one connection and pumps WaitForNotification
// until ctx is canceled or the connection errors out. Any error other
// than context.Canceled becomes the trigger for the outer reconnect.
func (inv *Invalidator) runOnce(ctx context.Context) error {
	acquired, err := inv.pool.Acquire(ctx)
	if err != nil {
		return fmt.Errorf("Invalidator.runOnce acquire: %w", err)
	}
	// Hijack() detaches the underlying *pgx.Conn from the pool so the
	// pool can never recycle our listener mid-flight. We close it
	// ourselves when the loop exits.
	conn := acquired.Hijack()

	inv.mu.Lock()
	if inv.closed {
		inv.mu.Unlock()
		//nolint:contextcheck // teardown: no request ctx here; this is a background listener closing its hijacked conn.
		_ = conn.Close(context.Background())
		return context.Canceled
	}
	inv.conn = conn
	inv.mu.Unlock()
	//nolint:contextcheck // teardown closure: conn.Close must run on a fresh ctx even when the loop ctx is already done.
	defer func() {
		inv.mu.Lock()
		inv.conn = nil
		inv.mu.Unlock()
		closeCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = conn.Close(closeCtx)
	}()

	// LISTEN registration is per-connection. The channel name is
	// quoted so that a future rename can include hyphens without
	// breaking the SQL.
	listenSQL := fmt.Sprintf(`LISTEN "%s"`, notifyChannelName())
	if _, err := conn.Exec(ctx, listenSQL); err != nil {
		return fmt.Errorf("Invalidator.runOnce listen: %w", err)
	}
	if inv.log != nil {
		inv.log.Info("cache_invalidator_listening", "channel", notifyChannelName())
	}

	// Reset the backoff to the floor on every successful LISTEN.
	for {
		n, err := conn.WaitForNotification(ctx)
		if err != nil {
			if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
				return context.Canceled
			}
			return fmt.Errorf("Invalidator.runOnce wait: %w", err)
		}
		if n == nil {
			continue
		}
		// Defensive: only react to our channel. pgx already filters by
		// connection but we double-check in case a future migration
		// fan-outs additional channels onto the same listener.
		if n.Channel != notifyChannelName() {
			continue
		}
		inv.bundle.InvalidatePrefix(n.Payload)
		if inv.log != nil {
			inv.log.Debug("cache_invalidator_busted",
				"payload", n.Payload, "pid", n.PID)
		}
	}
}

// Stop signals the loop to exit and closes the held connection. Safe to
// call from any goroutine; safe to call multiple times. Stop does NOT
// wait for Start to return — callers that need a synchronous handoff
// should run Start under their own WaitGroup.
func (inv *Invalidator) Stop() {
	if inv == nil {
		return
	}
	inv.mu.Lock()
	defer inv.mu.Unlock()
	if inv.closed {
		return
	}
	inv.closed = true
	if inv.conn != nil {
		closeCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = inv.conn.Close(closeCtx)
		inv.conn = nil
	}
}
