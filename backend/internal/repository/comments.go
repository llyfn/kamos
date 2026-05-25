// Package repository — flat comments on check-ins.
//
// Schema lives in migration 009. The repository here mirrors the patterns
// used by social.go / collections.go: cursor pagination on (created_at,
// id), partial-index-friendly filter on deleted_at IS NULL, slim user
// projection (CheckinUser) embedded in each row.
package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

// CommentRepo wraps the SQL for comments.
type CommentRepo struct{ db *pgxpool.Pool }

// CreateTx inserts a new comment inside the caller's transaction so the
// notification emit can participate in the same atomic write. Returns the
// hydrated comment plus the owner of the parent check-in (so the service
// can emit a notification to the right recipient without a follow-up
// query).
//
// Returns ErrNotFound when checkInID doesn't exist (or is soft-deleted) —
// the FK INSERT would otherwise return a generic SQLSTATE 23503 that gets
// wrapped as 500 by the handler. The pre-check is one indexed PK lookup,
// cheaper than the 23503 path.
func (r *CommentRepo) CreateTx(ctx context.Context, tx pgx.Tx, checkInID, userID, body string) (*domain.Comment, string, error) {
	var ownerID string
	if err := tx.QueryRow(ctx,
		`SELECT user_id FROM check_ins WHERE id = $1 AND deleted_at IS NULL;`,
		checkInID,
	).Scan(&ownerID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, "", domain.ErrNotFound
		}
		return nil, "", fmt.Errorf("CommentRepo.CreateTx parent: %w", err)
	}

	const ins = `
INSERT INTO comments (check_in_id, user_id, body)
VALUES ($1, $2, $3)
RETURNING id, check_in_id, user_id, body, created_at;`
	var (
		id, checkInIDOut, userIDOut, bodyOut string
		createdAt                            time.Time
	)
	if err := tx.QueryRow(ctx, ins, checkInID, userID, body).Scan(
		&id, &checkInIDOut, &userIDOut, &bodyOut, &createdAt,
	); err != nil {
		return nil, "", fmt.Errorf("CommentRepo.CreateTx insert: %w", err)
	}

	var u domain.CheckinUser
	if err := tx.QueryRow(ctx, `
SELECT id, username, display_username, display_name, avatar_url
FROM users WHERE id = $1;`,
		userIDOut,
	).Scan(&u.ID, &u.Username, &u.DisplayUsername, &u.DisplayName, &u.AvatarURL); err != nil {
		return nil, "", fmt.Errorf("CommentRepo.CreateTx hydrate user: %w", err)
	}

	return &domain.Comment{
		ID:        id,
		CheckInID: checkInIDOut,
		User:      &u,
		Body:      bodyOut,
		CreatedAt: createdAt,
	}, ownerID, nil
}

// List returns the comments on a check-in, most-recent-first. Soft-deleted
// rows are filtered out. The slim CheckinUser projection is JOINed so the
// Flutter card can render avatar + name without a second request.
//
// Cursor: (created_at, id). The repository fetches limit+1 and the handler
// computes has_more via cursor.SliceAndCursor.
func (r *CommentRepo) List(
	ctx context.Context,
	checkInID string,
	cursorTs *time.Time,
	cursorID *string,
	limit int,
) ([]domain.Comment, error) {
	if limit <= 0 {
		limit = 20
	}
	// LEFT JOIN — migration 013 (M-12.2) sets comments.user_id ON DELETE
	// SET NULL so the join may have no match when the author was
	// hard-purged. hydrateCommentUser materializes the row only when the
	// joined columns are non-null.
	const q = `
SELECT
 c.id, c.check_in_id, c.body, c.created_at,
 u.id, u.username, u.display_username, u.display_name, u.avatar_url
FROM comments c
LEFT JOIN users u ON u.id = c.user_id
WHERE c.check_in_id = $1
 AND c.deleted_at IS NULL
 AND ($2::timestamptz IS NULL OR (c.created_at, c.id) < ($2::timestamptz, $3::uuid))
ORDER BY c.created_at DESC, c.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, checkInID, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("CommentRepo.List: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Comment, 0, limit+1)
	for rows.Next() {
		var row domain.Comment
		var (
			uID, uUsername, uDisplayUsername, uDisplayName *string
			uAvatarURL                                     *string
		)
		if err := rows.Scan(
			&row.ID, &row.CheckInID, &row.Body, &row.CreatedAt,
			&uID, &uUsername, &uDisplayUsername, &uDisplayName, &uAvatarURL,
		); err != nil {
			return nil, fmt.Errorf("CommentRepo.List scan: %w", err)
		}
		row.User = hydrateCommentUser(uID, uUsername, uDisplayUsername, uDisplayName, uAvatarURL)
		out = append(out, row)
	}
	return out, rows.Err()
}

// hydrateCommentUser maps the LEFT JOINed user columns into a *CheckinUser,
// returning nil when the author was hard-purged (migration 013 — comments
// keep `id+body+timestamps` but `user_id` becomes NULL). The handler /
// service treat nil as "orphaned author"; the Flutter card renders the
// localized commentAuthorDeleted placeholder.
func hydrateCommentUser(id, username, displayUsername, displayName, avatarURL *string) *domain.CheckinUser {
	if id == nil || username == nil {
		return nil
	}
	u := domain.CheckinUser{
		ID:              *id,
		Username:        *username,
		DisplayUsername: stringOrZero(displayUsername),
		DisplayName:     stringOrZero(displayName),
		AvatarURL:       avatarURL,
	}
	return &u
}

func stringOrZero(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// Get fetches a single live (non-soft-deleted) comment with its author
// hydrated. Used by the soft-delete path to authorize the caller
// (own-comment vs admin). The user join is LEFT — an orphaned comment
// (author hard-purged) still returns; callers treat User == nil as
// "owner check cannot pass" so only moderator+ may delete it.
func (r *CommentRepo) Get(ctx context.Context, id string) (*domain.Comment, error) {
	const q = `
SELECT
 c.id, c.check_in_id, c.body, c.created_at, c.deleted_at,
 u.id, u.username, u.display_username, u.display_name, u.avatar_url
FROM comments c
LEFT JOIN users u ON u.id = c.user_id
WHERE c.id = $1;`
	var row domain.Comment
	var deletedAt *time.Time
	var (
		uID, uUsername, uDisplayUsername, uDisplayName *string
		uAvatarURL                                     *string
	)
	if err := r.db.QueryRow(ctx, q, id).Scan(
		&row.ID, &row.CheckInID, &row.Body, &row.CreatedAt, &deletedAt,
		&uID, &uUsername, &uDisplayUsername, &uDisplayName, &uAvatarURL,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, fmt.Errorf("CommentRepo.Get: %w", err)
	}
	if deletedAt != nil {
		// Already soft-deleted — treat as not found.
		return nil, domain.ErrNotFound
	}
	row.DeletedAt = deletedAt
	row.User = hydrateCommentUser(uID, uUsername, uDisplayUsername, uDisplayName, uAvatarURL)
	return &row, nil
}

// SoftDelete marks the comment deleted_at = NOW().
//
// Authorization is the caller's responsibility: the handler decides
// whether viewerID owns the comment or has moderator+ role. The repo
// trusts the caller — we centralize policy in middleware/handlers, not in
// SQL, because admin moderation deliberately bypasses ownership.
//
// When isAdmin is true and moderatorID + notes are non-empty, the same
// transaction writes a moderation_log row (action='soft_delete',
// target_type='comment').
func (r *CommentRepo) SoftDelete(
	ctx context.Context,
	commentID string,
	moderatorID string,
	isAdmin bool,
	notes *string,
) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("CommentRepo.SoftDelete begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const q = `
UPDATE comments SET deleted_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, commentID).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("CommentRepo.SoftDelete: %w", err)
	}

	if isAdmin {
		if err := insertModerationLog(ctx, tx,
			moderatorID,
			"comment", commentID,
			"soft_delete",
			notes,
			nil,
		); err != nil {
			return err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("CommentRepo.SoftDelete commit: %w", err)
	}
	return nil
}

// ListForAdmin pages through comments for the moderator review queue. Set
// `onlyDeleted=true` to surface only the soft-deleted (typically what an
// admin wants to audit), or `false` for the all-comments view.
type AdminCommentRow struct {
	domain.Comment
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
	// ModerationNotes / ModeratedBy / ModeratedAt are joined from the
	// moderation_log; nil for never-moderated rows. We don't expose the
	// moderation_log id — admins don't need a deep-link yet.
	ModerationNotes *string    `json:"moderation_notes,omitempty"`
	ModeratedBy     *string    `json:"moderated_by,omitempty"`
	ModeratedAt     *time.Time `json:"moderated_at,omitempty"`
}

// ListForAdmin returns the admin view of comments with optional moderation
// metadata joined in. Cursor on (created_at, id).
func (r *CommentRepo) ListForAdmin(
	ctx context.Context,
	onlyDeleted bool,
	cursorTs *time.Time,
	cursorID *string,
	limit int,
) ([]AdminCommentRow, error) {
	if limit <= 0 {
		limit = 20
	}
	// LEFT JOIN LATERAL the most recent moderation_log row for the comment.
	// Most comments have zero such rows — LEFT JOIN keeps them in.
	const q = `
SELECT
 c.id, c.check_in_id, c.body, c.created_at, c.deleted_at,
 u.id, u.username, u.display_username, u.display_name, u.avatar_url,
 ml.notes, ml.moderator_id, ml.created_at AS moderated_at
FROM comments c
LEFT JOIN users u ON u.id = c.user_id
LEFT JOIN LATERAL (
 SELECT notes, moderator_id, created_at
 FROM moderation_log
 WHERE target_type = 'comment' AND target_id = c.id
 ORDER BY created_at DESC
 LIMIT 1
) ml ON TRUE
WHERE ($1::boolean IS FALSE OR c.deleted_at IS NOT NULL)
 AND ($2::timestamptz IS NULL OR (c.created_at, c.id) < ($2::timestamptz, $3::uuid))
ORDER BY c.created_at DESC, c.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, onlyDeleted, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("CommentRepo.ListForAdmin: %w", err)
	}
	defer rows.Close()
	out := make([]AdminCommentRow, 0, limit+1)
	for rows.Next() {
		var row AdminCommentRow
		var (
			uID, uUsername, uDisplayUsername, uDisplayName *string
			uAvatarURL                                     *string
		)
		if err := rows.Scan(
			&row.ID, &row.CheckInID, &row.Body, &row.CreatedAt, &row.DeletedAt,
			&uID, &uUsername, &uDisplayUsername, &uDisplayName, &uAvatarURL,
			&row.ModerationNotes, &row.ModeratedBy, &row.ModeratedAt,
		); err != nil {
			return nil, fmt.Errorf("CommentRepo.ListForAdmin scan: %w", err)
		}
		row.User = hydrateCommentUser(uID, uUsername, uDisplayUsername, uDisplayName, uAvatarURL)
		out = append(out, row)
	}
	return out, rows.Err()
}
