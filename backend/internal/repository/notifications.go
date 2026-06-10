// In-app notifications (SPEC §5.4). The schema lives in migration 019; the
// canonical SQL is documented in docs/db/query_patterns.md §16. Every emit
// path takes a pgx.Tx so the insert lands in the same transaction as the
// source event (toast / comment / follow). The read paths run on the pool.
package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/spec"
)

// NotificationRepo wraps the SQL for the notifications inbox.
type NotificationRepo struct{ db *pgxpool.Pool }

// InsertToastTx emits a `toast` row. Idempotent via the partial unique index
// (recipient_user_id, actor_user_id, check_in_id) WHERE type='toast'; a
// re-toast after un-toast collapses to ON CONFLICT DO NOTHING.
//
// Self-toast filtering is the caller's responsibility (service layer);
// the DB CHECK notifications_no_self is the backstop.
func (r *NotificationRepo) InsertToastTx(ctx context.Context, tx pgx.Tx, recipientID, actorID, checkInID string) error {
	const q = `
INSERT INTO notifications (recipient_user_id, type, actor_user_id, check_in_id)
VALUES ($1, 'toast', $2, $3)
ON CONFLICT (recipient_user_id, actor_user_id, check_in_id)
  WHERE type = 'toast'
DO NOTHING;`
	if _, err := tx.Exec(ctx, q, recipientID, actorID, checkInID); err != nil {
		return fmt.Errorf("NotificationRepo.InsertToastTx: %w", err)
	}
	return nil
}

// InsertCommentTx emits a `comment` row. No dedupe — every comment is its
// own distinct event.
func (r *NotificationRepo) InsertCommentTx(ctx context.Context, tx pgx.Tx, recipientID, actorID, checkInID, commentID string) error {
	const q = `
INSERT INTO notifications (recipient_user_id, type, actor_user_id, check_in_id, comment_id)
VALUES ($1, 'comment', $2, $3, $4);`
	if _, err := tx.Exec(ctx, q, recipientID, actorID, checkInID, commentID); err != nil {
		return fmt.Errorf("NotificationRepo.InsertCommentTx: %w", err)
	}
	return nil
}

// InsertFollowTx emits a `follow` row for the public auto-accept path.
// Idempotent via the partial unique index (recipient_user_id, actor_user_id)
// WHERE type='follow' — re-following after an unfollow does NOT spam.
func (r *NotificationRepo) InsertFollowTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	const q = `
INSERT INTO notifications (recipient_user_id, type, actor_user_id)
VALUES ($1, 'follow', $2)
ON CONFLICT (recipient_user_id, actor_user_id) WHERE type = 'follow'
DO NOTHING;`
	if _, err := tx.Exec(ctx, q, recipientID, actorID); err != nil {
		return fmt.Errorf("NotificationRepo.InsertFollowTx: %w", err)
	}
	return nil
}

// InsertFollowRequestTx emits a `follow_request` row for the private
// request path. No DB-level dedupe — the service deletes the row on every
// terminal transition (approve / decline / cancel) so a re-request inserts
// cleanly.
func (r *NotificationRepo) InsertFollowRequestTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	const q = `
INSERT INTO notifications (recipient_user_id, type, actor_user_id)
VALUES ($1, 'follow_request', $2);`
	if _, err := tx.Exec(ctx, q, recipientID, actorID); err != nil {
		return fmt.Errorf("NotificationRepo.InsertFollowRequestTx: %w", err)
	}
	return nil
}

// InsertFollowApprovedTx emits a `follow_approved` row for the original
// requester. Idempotent via the partial unique index.
func (r *NotificationRepo) InsertFollowApprovedTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	const q = `
INSERT INTO notifications (recipient_user_id, type, actor_user_id)
VALUES ($1, 'follow_approved', $2)
ON CONFLICT (recipient_user_id, actor_user_id) WHERE type = 'follow_approved'
DO NOTHING;`
	if _, err := tx.Exec(ctx, q, recipientID, actorID); err != nil {
		return fmt.Errorf("NotificationRepo.InsertFollowApprovedTx: %w", err)
	}
	return nil
}

// DeleteFollowRequestTx removes the pending `follow_request` row from the
// recipient's inbox. Called from approve / decline / cancel paths so the
// row stops showing once the request has reached a terminal state.
// Idempotent — zero rows deleted is fine.
func (r *NotificationRepo) DeleteFollowRequestTx(ctx context.Context, tx pgx.Tx, recipientID, actorID string) error {
	const q = `
DELETE FROM notifications
WHERE recipient_user_id = $1
  AND actor_user_id = $2
  AND type = 'follow_request';`
	if _, err := tx.Exec(ctx, q, recipientID, actorID); err != nil {
		return fmt.Errorf("NotificationRepo.DeleteFollowRequestTx: %w", err)
	}
	return nil
}

// ListByRecipient pages through a user's inbox, newest first. Returns
// limit+1 rows so the handler can compute has_more via
// cursor.SliceAndCursor.
//
// SPEC §5.4: actor visibility has two failure modes, both of which leave
// the row present and surface a localized "Deleted user" stub:
//
//   - Hard-delete: the FK ON DELETE SET NULL flips actor_user_id to NULL.
//     The LEFT JOIN then has no match and `u.id` is NULL.
//   - Soft-delete: actor_user_id still points at the row, but
//     u.deleted_at IS NOT NULL. The Go layer treats this as equivalent to
//     the hard-delete case.
//
// The JOIN intentionally does NOT add `AND u.deleted_at IS NULL` — that
// would inner-join-filter the row out instead of stubbing the actor.
func (r *NotificationRepo) ListByRecipient(
	ctx context.Context,
	recipientID string,
	cursorTs *time.Time,
	cursorID *string,
	limit int,
) ([]domain.Notification, error) {
	if limit <= 0 {
		limit = spec.PageSizeDefault
	}
	const q = `
SELECT
  n.id,
  n.type,
  n.actor_user_id,
  u.username,
  u.display_username,
  u.display_name,
  u.avatar_url,
  u.deleted_at,
  n.check_in_id,
  n.comment_id,
  n.read_at,
  n.created_at
FROM notifications n
LEFT JOIN users u ON u.id = n.actor_user_id
WHERE n.recipient_user_id = $1
  AND ($2::timestamptz IS NULL OR (n.created_at, n.id) < ($2::timestamptz, $3::uuid))
ORDER BY n.created_at DESC, n.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, recipientID, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("NotificationRepo.ListByRecipient: %w", err)
	}
	defer rows.Close()

	out := make([]domain.Notification, 0, limit+1)
	for rows.Next() {
		var (
			n                                               domain.Notification
			actorID, username, displayUsername, displayName *string
			avatarURL                                       *string
			actorDeletedAt                                  *time.Time
		)
		if err := rows.Scan(
			&n.ID, &n.Type,
			&actorID, &username, &displayUsername, &displayName, &avatarURL, &actorDeletedAt,
			&n.CheckInID, &n.CommentID, &n.ReadAt, &n.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("NotificationRepo.ListByRecipient scan: %w", err)
		}
		if actorDeletedAt != nil {
			// Soft-deleted actor — drop the join columns so the
			// hydrator returns nil and the client renders "Deleted user".
			n.Actor = nil
		} else {
			n.Actor = hydrateCommentUser(actorID, username, displayUsername, displayName, avatarURL)
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

// CountUnread returns the size of the unread set for the recipient. Backed
// by the partial index idx_notifications_recipient_unread (Index Only Scan).
func (r *NotificationRepo) CountUnread(ctx context.Context, recipientID string) (int, error) {
	const q = `SELECT COUNT(*) FROM notifications WHERE recipient_user_id = $1 AND read_at IS NULL;`
	var n int
	if err := r.db.QueryRow(ctx, q, recipientID).Scan(&n); err != nil {
		return 0, fmt.Errorf("NotificationRepo.CountUnread: %w", err)
	}
	return n, nil
}

// MarkRead sets read_at = NOW() for the supplied ids that belong to the
// recipient. Returns the affected row count. The WHERE clause includes
// `recipient_user_id = $1` so a caller cannot mark another user's
// notification read (IDOR guard). Already-read rows are silently ignored
// so the endpoint is idempotent under retry.
//
// Empty ids list is a no-op returning 0 (the handler rejects empty input
// before calling here, so this guard is defensive).
func (r *NotificationRepo) MarkRead(ctx context.Context, recipientID string, ids []string) (int, error) {
	if len(ids) == 0 {
		return 0, nil
	}
	const q = `
UPDATE notifications
SET read_at = NOW()
WHERE recipient_user_id = $1
  AND id = ANY($2::uuid[])
  AND read_at IS NULL;`
	ct, err := r.db.Exec(ctx, q, recipientID, ids)
	if err != nil {
		return 0, fmt.Errorf("NotificationRepo.MarkRead: %w", err)
	}
	return int(ct.RowsAffected()), nil
}

// MarkAllRead sets read_at = NOW() for every unread notification belonging
// to the recipient. Returns the cumulative affected row count.
//
// PERF-001: chunk the UPDATE in batches of 1000 ids so a recipient with
// tens of thousands of unread rows does not hold a single tx open long
// enough to push lock-wait pressure on concurrent writers. Each chunk
// runs in its own short autocommit Exec; an interrupted call leaves the
// already-marked chunks read (partial success is the right behavior for
// a "mark all" sweep — the user will just re-tap if it failed midway).
func (r *NotificationRepo) MarkAllRead(ctx context.Context, recipientID string) (int, error) {
	const chunkSize = 1000
	const q = `
UPDATE notifications
SET read_at = NOW()
WHERE recipient_user_id = $1
  AND id IN (
    SELECT id FROM notifications
    WHERE recipient_user_id = $1 AND read_at IS NULL
    LIMIT $2
  );`
	total := 0
	for {
		ct, err := r.db.Exec(ctx, q, recipientID, chunkSize)
		if err != nil {
			return total, fmt.Errorf("NotificationRepo.MarkAllRead: %w", err)
		}
		n := int(ct.RowsAffected())
		total += n
		if n < chunkSize {
			break
		}
	}
	return total, nil
}
