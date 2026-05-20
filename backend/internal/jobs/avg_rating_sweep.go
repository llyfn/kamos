package jobs

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

// JobAvgRatingSweep recomputes (avg_rating, check_in_count) for every
// beverage from the check_ins table and persists the result only where it
// differs from the stored trigger-maintained values. The trigger keeps
// these in sync in the normal path — this job is a self-heal for edge
// cases (manual DB edits, trigger gaps during long migrations, etc.) per
// the roadmap §1.
//
// Stage 5 (PERF-025): the sweep is now scoped to beverages with
// check-in activity in the last hour via a CTE on
// check_ins.updated_at instead of running the AVG()-over-the-world
// join over the entire catalog every tick. The trigger path already
// handles 100% of the normal case; this job only ever fires for the
// rare drift window, so we don't need to recompute beverages that
// haven't been touched.
func JobAvgRatingSweep(log *slog.Logger) JobFn {
	return func(ctx context.Context, db *pgxpool.Pool) error {
		// Matches recompute_beverage_rating() in 001_initial.sql exactly:
		// avg + count are both taken over check-ins WITH a rating (the
		// trigger's `check_in_count` is "rated check-ins", not "all
		// check-ins"). Diverging from the trigger here would flap rows
		// back and forth every sweep.
		const q = `
WITH affected AS (
  SELECT DISTINCT beverage_id
  FROM check_ins
  WHERE updated_at >= NOW() - INTERVAL '1 hour'
)
UPDATE beverages b
SET avg_rating = sub.avg_rating,
    check_in_count = sub.cnt
FROM (
  SELECT
    a.beverage_id,
    sub2.avg_rating,
    COALESCE(sub2.cnt, 0) AS cnt
  FROM affected a
  LEFT JOIN LATERAL (
    SELECT AVG(rating)::NUMERIC(3,2) AS avg_rating,
           COUNT(*)::INT             AS cnt
    FROM check_ins
    WHERE beverage_id = a.beverage_id
      AND deleted_at IS NULL
      AND rating IS NOT NULL
  ) sub2 ON TRUE
) sub
WHERE b.id = sub.beverage_id
  AND (b.avg_rating     IS DISTINCT FROM sub.avg_rating
    OR b.check_in_count IS DISTINCT FROM sub.cnt);`
		ct, err := db.Exec(ctx, q)
		if err != nil {
			return fmt.Errorf("JobAvgRatingSweep: %w", err)
		}
		corrected := ct.RowsAffected()
		if log != nil {
			log.Info("avg_rating_sweep", "corrected", corrected)
		}
		return nil
	}
}
