// Package jobs runs in-process background maintenance tasks: username-hold
// release, email-verification cleanup, and the rating-aggregate self-heal.
// In-process (not a separate binary) per the post-MVP roadmap.
package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

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
func (s *Scheduler) invoke(j Job) {
	defer func() {
		if rec := recover(); rec != nil {
			s.log.Error("job_panic", "name", j.Name, "panic", fmt.Sprint(rec))
		}
	}()
	ctx, cancel := context.WithTimeout(s.ctx, 5*time.Minute)
	defer cancel()
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
