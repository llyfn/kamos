package jobs

import (
	"context"
	"io"
	"log/slog"
	"runtime"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Register + Start runs the job once immediately ("cold start") and then
// every tick. With a 50ms interval and a 120ms wait we should see at
// least two invocations (cold start + at least one tick).
func TestSchedulerColdStartAndTicks(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewScheduler(context.Background(), log, (*pgxpool.Pool)(nil))

	var calls atomic.Int32
	s.Register("noop", 50*time.Millisecond, func(ctx context.Context, _ *pgxpool.Pool) error {
		calls.Add(1)
		return nil
	})
	s.Start()
	time.Sleep(180 * time.Millisecond)
	s.Stop()

	if got := calls.Load(); got < 2 {
		t.Errorf("expected ≥2 invocations (cold start + tick), got %d", got)
	}
}

// Stop signals goroutines via context cancel; they exit and the
// goroutine count returns to the baseline.
func TestSchedulerStopsCleanly(t *testing.T) {
	baseline := runtime.NumGoroutine()

	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewScheduler(context.Background(), log, (*pgxpool.Pool)(nil))
	s.Register("slow", 25*time.Millisecond, func(ctx context.Context, _ *pgxpool.Pool) error {
		return nil
	})
	s.Start()
	time.Sleep(60 * time.Millisecond)
	if got := runtime.NumGoroutine(); got <= baseline {
		t.Errorf("expected goroutine count to grow after Start; baseline=%d got=%d", baseline, got)
	}
	s.Stop()

	// Allow scheduler to release; pause a beat then assert it dropped back.
	// We retry a few times to absorb the runtime's lazy reclaim.
	deadline := time.Now().Add(500 * time.Millisecond)
	for time.Now().Before(deadline) {
		if runtime.NumGoroutine() <= baseline+1 {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Errorf("goroutine leak: baseline=%d, after Stop=%d", baseline, runtime.NumGoroutine())
}

// A job that returns an error keeps the scheduler alive — the next tick
// still fires. This guards the "tick errors do NOT crash the scheduler"
// guarantee in scheduler.go.
func TestSchedulerErrorDoesNotCrash(t *testing.T) {
	log := slog.New(slog.NewTextHandler(io.Discard, nil))
	s := NewScheduler(context.Background(), log, (*pgxpool.Pool)(nil))

	var calls atomic.Int32
	s.Register("flaky", 30*time.Millisecond, func(ctx context.Context, _ *pgxpool.Pool) error {
		calls.Add(1)
		return errFake
	})
	s.Start()
	time.Sleep(120 * time.Millisecond)
	s.Stop()

	if got := calls.Load(); got < 3 {
		t.Errorf("expected scheduler to keep ticking through errors; got %d calls", got)
	}
}

type stringErr string

func (e stringErr) Error() string { return string(e) }

var errFake = stringErr("intentional")
