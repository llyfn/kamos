package jobs

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

// JobUsernameHoldCleanup releases usernames held by soft-deleted users
// past the 30-day SPEC §3.3 hold window. We do this by tombstoning the
// username + display_username to a per-id placeholder ('del_' + 24 hex of
// the user UUID). The schema's CHECK constraints require:
//   - username      ~ ^[a-z0-9_]{3,30}$
//   - display_username ~ ^[A-Za-z0-9_]{3,30}$
//   - LOWER(display_username) = username
//
// The tombstone format (28 chars, lowercase hex + underscore) satisfies
// all three so the renames go through. After this job runs, registration
// queries that hit the `idx_users_username_held` partial index no longer
// find the original username, freeing it for re-use.
//
// Idempotent: tombstoned rows already start with 'del_' so we skip them.
// Returns nil on success even when zero rows are touched.
func JobUsernameHoldCleanup(log *slog.Logger) JobFn {
	return func(ctx context.Context, db *pgxpool.Pool) error {
		const q = `
UPDATE users
SET
  username         = 'del_' || substring(replace(id::text, '-', '') from 1 for 24),
  display_username = 'del_' || substring(replace(id::text, '-', '') from 1 for 24)
WHERE deleted_at IS NOT NULL
  AND username_release_at IS NOT NULL
  AND username_release_at < NOW()
  AND username NOT LIKE 'del\_%' ESCAPE '\';`
		ct, err := db.Exec(ctx, q)
		if err != nil {
			return fmt.Errorf("JobUsernameHoldCleanup: %w", err)
		}
		released := ct.RowsAffected()
		if log != nil {
			log.Info("username_hold_cleanup", "released", released)
		}
		return nil
	}
}
