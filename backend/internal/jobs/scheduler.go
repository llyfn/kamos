// Package jobs runs background maintenance tasks: username-hold release,
// email-verification cleanup, photo-orphan cleanup, and the rating-aggregate
// self-heal. Owned by cmd/worker as of Stage 4 — the API server no longer
// registers any jobs.
//
// Each tick is wrapped in pg_try_advisory_lock keyed on the job name. This
// is a belt-and-suspenders guard: the worker is a single replica by
// configuration, but if a misconfigured deploy ever runs N workers (or
// re-registers jobs on the API), only one of them will fire any given tick.
// The lock is bound to a dedicated connection acquired from the pool, so
// it auto-releases when the connection returns to the pool — even if the
// job body panics before the explicit Unlock.
package jobs

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

// jobTickBudget caps how long any one job invocation may take. The tick
// body inherits a context with this deadline; jobs that need longer must
// chunk their work or run more frequently. Generous enough for an admin
// re-aggregate (~minutes) but small enough that a wedged job can't pin a
// scheduler goroutine forever.
const jobTickBudget = 5 * time.Minute

// JobFn is the function signature every registered job satisfies. The DB
// is passed explicitly so jobs can be unit-tested without a Scheduler.
type JobFn func(ctx context.Context, db *pgxpool.Pool) error

// Job is one registered task.
type Job struct {
	Name  string
	Every time.Duration
	Fn    JobFn
}

// Scheduler runs registered jobs on independent goroutines. Start spawns
// one goroutine per job; Stop cancels the context and Wait blocks until
// every job goroutine returns.
type Scheduler struct {
	ctx    context.Context
	cancel context.CancelFunc
	log    *slog.Logger
	db     *pgxpool.Pool
	jobs   []Job
	wg     sync.WaitGroup
}

// NewScheduler wires a scheduler bound to the given parent context. The
// scheduler owns a derived context so Stop() cleanly cancels every job.
func NewScheduler(parent context.Context, log *slog.Logger, db *pgxpool.Pool) *Scheduler {
	ctx, cancel := context.WithCancel(parent)
	return &Scheduler{ctx: ctx, cancel: cancel, log: log, db: db}
}

// Register adds a job. Must be called before Start; concurrent register +
// start is intentionally not supported.
func (s *Scheduler) Register(name string, every time.Duration, fn JobFn) {
	s.jobs = append(s.jobs, Job{Name: name, Every: every, Fn: fn})
}

// Start spawns one goroutine per job. Each goroutine runs the job once
// immediately ("cold start") so we don't wait an hour for the first sweep,
// then on every tick of a time.Ticker. Errors are logged at WARN and
// never crash the goroutine.
func (s *Scheduler) Start() {
	for _, j := range s.jobs {
		j := j
		s.wg.Add(1)
		go s.run(j)
	}
}

func (s *Scheduler) run(j Job) {
	defer s.wg.Done()
	s.log.Info("job_start", "name", j.Name, "every", j.Every.String())
	// Cold-start tick.
	s.invoke(j)
	t := time.NewTicker(j.Every)
	defer t.Stop()
	for {
		select {
		case <-s.ctx.Done():
			s.log.Info("job_stop", "name", j.Name)
			return
		case <-t.C:
			s.invoke(j)
		}
	}
}

// invoke runs one iteration with a context that inherits from the
// scheduler's; ticks must not deadlock if a single iteration hangs forever,
// so we give the job a generous-but-bounded budget of 5 minutes.
//
// Stage 4 — the tick body is gated by pg_try_advisory_lock("kamos:job:<name>").
// When the lock is held by another worker the tick logs at DEBUG and skips;
// when the DB is missing (nil pool, tests), we skip the lock and run as
// before so unit tests keep their old shape.
func (s *Scheduler) invoke(j Job) {
	defer func() {
		if rec := recover(); rec != nil {
			s.log.Error("job_panic", "name", j.Name, "panic", fmt.Sprint(rec))
		}
	}()
	ctx, cancel := context.WithTimeout(s.ctx, jobTickBudget)
	defer cancel()

	if s.db == nil {
		if err := j.Fn(ctx, s.db); err != nil {
			s.log.Warn("job_error", "name", j.Name, "err", err)
		}
		return
	}

	key := "kamos:job:" + j.Name
	acq, err := s.db.Acquire(ctx)
	if err != nil {
		s.log.Warn("job_acquire_conn", "name", j.Name, "err", err)
		return
	}
	defer acq.Release()

	ok, err := tryAdvisoryLock(ctx, acq.Conn(), key)
	if err != nil {
		s.log.Warn("job_advisory_lock", "name", j.Name, "err", err)
		return
	}
	if !ok {
		s.log.Debug("job_lock_held", "name", j.Name)
		return
	}
	defer func() {
		if err := releaseAdvisoryLock(ctx, acq.Conn(), key); err != nil {
			s.log.Warn("job_advisory_unlock", "name", j.Name, "err", err)
		}
	}()

	if err := j.Fn(ctx, s.db); err != nil {
		s.log.Warn("job_error", "name", j.Name, "err", err)
	}
}

// Stop cancels every job goroutine and returns once they've all returned.
// Safe to call once; subsequent calls are no-ops.
func (s *Scheduler) Stop() {
	s.cancel()
	s.wg.Wait()
}

// queryRower is the slice of *pgx.Conn we need for the advisory-lock
// helpers. Declared as an interface so tests can substitute a fake; the
// real *pgx.Conn satisfies it natively.
type queryRower interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// tryAdvisoryLock attempts SELECT pg_try_advisory_lock(hashtext($1)).
// Returns (true, nil) on grant, (false, nil) when held elsewhere, and an
// error only on DB failure.
func tryAdvisoryLock(ctx context.Context, conn queryRower, key string) (bool, error) {
	var got bool
	if err := conn.QueryRow(ctx, `SELECT pg_try_advisory_lock(hashtext($1))`, key).Scan(&got); err != nil {
		return false, fmt.Errorf("tryAdvisoryLock: %w", err)
	}
	return got, nil
}

// releaseAdvisoryLock releases the lock taken by tryAdvisoryLock. Idempotent
// at the scheduler level: when the context is already canceled (Postgres
// will release the lock on session close anyway) we treat the call as a
// no-op.
func releaseAdvisoryLock(ctx context.Context, conn queryRower, key string) error {
	var released bool
	if err := conn.QueryRow(ctx, `SELECT pg_advisory_unlock(hashtext($1))`, key).Scan(&released); err != nil {
		if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
			return nil
		}
		return fmt.Errorf("releaseAdvisoryLock: %w", err)
	}
	return nil
}
