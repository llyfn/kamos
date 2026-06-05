//go:build integration
// +build integration

package integration

import (
	"context"
	"io"
	"log/slog"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/jobs"
)

// TestAdvisoryLockHeldByOne — belt-and-suspenders guard. Two scheduler
// instances pointing at the same DB register the same-named
// job. Only one tick should fire the job body in any given window: the
// other tick acquires a fresh connection, fails pg_try_advisory_lock,
// and skips silently.
//
// We use a short interval (50ms) and let both schedulers run for ~300ms.
// Without the lock, both schedulers would fire on every tick (cold-start
// + ≥5 ticks). With the lock, only one wins per tick.
func TestAdvisoryLockHeldByOne(t *testing.T) {
	pool := getPool(t)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	log := slog.New(slog.NewTextHandler(io.Discard, nil))

	var aCount, bCount atomic.Int32
	// Slow-ish job body: 80ms holds the lock past the next tick of either
	// scheduler so the second instance's tick definitely contends.
	makeJob := func(counter *atomic.Int32) jobs.JobFn {
		return func(_ context.Context, _ *pgxpool.Pool) error {
			counter.Add(1)
			time.Sleep(80 * time.Millisecond)
			return nil
		}
	}

	a := jobs.NewScheduler(ctx, log, pool)
	b := jobs.NewScheduler(ctx, log, pool)
	a.Register("kamos_test_lock_job", 50*time.Millisecond, makeJob(&aCount))
	b.Register("kamos_test_lock_job", 50*time.Millisecond, makeJob(&bCount))
	a.Start()
	b.Start()

	// Let both schedulers tick a few times.
	time.Sleep(350 * time.Millisecond)
	a.Stop()
	b.Stop()

	total := aCount.Load() + bCount.Load()
	// Cold-start of both schedulers happens nearly simultaneously: one
	// wins, the other contends and skips. After that the lock-holding
	// scheduler holds the connection for 80ms, so the loser keeps
	// missing for at least one more tick. We expect significantly fewer
	// total invocations than the without-lock baseline (~12).
	if total == 0 {
		t.Fatalf("neither scheduler ran the job body")
	}
	if total > 8 {
		t.Errorf("expected the advisory lock to suppress concurrent ticks; got %d total invocations (want ≤8)", total)
	}
	if aCount.Load() == 0 && bCount.Load() == 0 {
		t.Errorf("expected at least one scheduler to fire the job body")
	}
	t.Logf("scheduler invocations: a=%d b=%d total=%d", aCount.Load(), bCount.Load(), total)
}
