package jobs

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/storage"
)

// orphanLookbackBatch is the per-tick cap. The cleanup is best-effort —
// anything we miss this hour we'll catch the next hour.
const orphanLookbackBatch = 500

// orphanAge is the SPEC threshold (24h) before an unattached upload is
// declared orphaned and its blob deleted.
const orphanAge = 24 * time.Hour

// JobPhotoOrphanCleanup deletes blobs for photo_uploads rows that never
// reached 'attached' within 24h. Runs every hour.
//
// Storage.Delete on the Disabled backend is a no-op so this job is safe to
// register even when R2 is unconfigured — rows still get marked 'orphaned'
// (the row exists locally regardless of bucket state).
func JobPhotoOrphanCleanup(log *slog.Logger, store storage.Storage) JobFn {
	return func(ctx context.Context, db *pgxpool.Pool) error {
		cutoff := time.Now().Add(-orphanAge)

		const list = `
SELECT id, blob_key
FROM photo_uploads
WHERE status IN ('pending', 'uploaded') AND created_at < $1
ORDER BY created_at
LIMIT $2;`
		rows, err := db.Query(ctx, list, cutoff, orphanLookbackBatch)
		if err != nil {
			return fmt.Errorf("JobPhotoOrphanCleanup query: %w", err)
		}
		type cand struct{ id, key string }
		var batch []cand
		for rows.Next() {
			var c cand
			if err := rows.Scan(&c.id, &c.key); err != nil {
				rows.Close()
				return fmt.Errorf("JobPhotoOrphanCleanup scan: %w", err)
			}
			batch = append(batch, c)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return fmt.Errorf("JobPhotoOrphanCleanup rows: %w", err)
		}

		deleted := 0
		for _, c := range batch {
			if err := store.Delete(ctx, c.key); err != nil {
				// Log and continue — a permanent blob-delete failure should
				// not block the row update; the cron will see it next cycle
				// if we don't mark it orphaned.
				if log != nil {
					log.Warn("photo_orphan_cleanup_blob_delete",
						"err", err, "blob_key", c.key, "upload_id", c.id)
				}
				continue
			}
			const upd = `
UPDATE photo_uploads
SET status = 'orphaned', orphaned_at = NOW()
WHERE id = $1 AND status IN ('pending', 'uploaded');`
			if _, err := db.Exec(ctx, upd, c.id); err != nil {
				if log != nil {
					log.Warn("photo_orphan_cleanup_mark", "err", err, "upload_id", c.id)
				}
				continue
			}
			deleted++
		}
		if log != nil {
			log.Info("photo_orphan_cleanup", "deleted", deleted)
		}
		return nil
	}
}
