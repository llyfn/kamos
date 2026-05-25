package jobs

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

// JobNotificationPrune hard-deletes notifications older than 180 days
// that the recipient has already marked read. Unread rows are preserved
// regardless of age — they are the recipient's pending TODOs and the UI
// surfaces them with the unread dot.
//
// 180 days mirrors SPEC §5.4 retention and matches Untappd's published
// inbox window. Matches the email_verification_cleanup pattern: the
// scheduler tick is already wrapped in pg_try_advisory_lock so a
// misconfigured deploy that runs the worker in multiple replicas still
// only fires the body once.
func JobNotificationPrune(log *slog.Logger) JobFn {
	return func(ctx context.Context, db *pgxpool.Pool) error {
		const q = `
DELETE FROM notifications
WHERE created_at < NOW() - INTERVAL '180 days'
  AND read_at IS NOT NULL;`
		ct, err := db.Exec(ctx, q)
		if err != nil {
			return fmt.Errorf("JobNotificationPrune: %w", err)
		}
		deleted := ct.RowsAffected()
		if log != nil {
			log.Info("notification_prune", "deleted", deleted)
		}
		return nil
	}
}
