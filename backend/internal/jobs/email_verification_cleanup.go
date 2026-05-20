package jobs

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
)

// JobEmailVerificationCleanup drops email_verifications rows that expired
// more than 7 days ago. Tokens have a 24h expiry per SPEC §3.1; the extra
// 7-day grace makes the table easy to inspect when chasing down a stale
// verification failure without keeping cruft forever.
func JobEmailVerificationCleanup(log *slog.Logger) JobFn {
	return func(ctx context.Context, db *pgxpool.Pool) error {
		const q = `
DELETE FROM email_verifications
WHERE expires_at < NOW() - INTERVAL '7 days';`
		ct, err := db.Exec(ctx, q)
		if err != nil {
			return fmt.Errorf("JobEmailVerificationCleanup: %w", err)
		}
		deleted := ct.RowsAffected()
		if log != nil {
			log.Info("email_verification_cleanup", "deleted", deleted)
		}
		return nil
	}
}
