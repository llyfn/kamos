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

type SocialRepo struct{ db *pgxpool.Pool }

// FollowTx is the tx-aware variant. Returns the resulting status plus a
// `created` flag — true only when this call INSERTed a fresh `follows` row
// (caller-side condition for emitting a `follow` / `follow_request`
// notification; an idempotent no-op returns created=false).
func (r *SocialRepo) FollowTx(ctx context.Context, tx pgx.Tx, follower, followed string) (status string, created bool, err error) {
	if follower == followed {
		return "", false, domain.ErrFollowSelf
	}

	var privacy string
	err = tx.QueryRow(ctx,
		`SELECT privacy_mode FROM users WHERE id = $1 AND deleted_at IS NULL;`, followed,
	).Scan(&privacy)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", false, domain.ErrNotFound
	}
	if err != nil {
		return "", false, fmt.Errorf("FollowTx lookup: %w", err)
	}

	wantStatus := "accepted"
	var acceptedAt *time.Time
	if privacy == "private" {
		wantStatus = "pending"
	} else {
		now := time.Now()
		acceptedAt = &now
	}
	const q = `
INSERT INTO follows (follower_id, followed_id, status, accepted_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (follower_id, followed_id) DO NOTHING
RETURNING status;`
	err = tx.QueryRow(ctx, q, follower, followed, wantStatus, acceptedAt).Scan(&status)
	if errors.Is(err, pgx.ErrNoRows) {
		err = tx.QueryRow(ctx,
			`SELECT status FROM follows WHERE follower_id = $1 AND followed_id = $2;`,
			follower, followed).Scan(&status)
		if err != nil {
			return "", false, fmt.Errorf("FollowTx existing: %w", err)
		}
		return status, false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("FollowTx insert: %w", err)
	}
	return status, true, nil
}

// UnfollowTx deletes the row inside the caller's tx and returns the
// previous status (empty when no row existed) so the service can decide
// whether to also drop a `follow_request` notification (only when the row
// was `pending` — i.e. the requester withdrew before approval).
func (r *SocialRepo) UnfollowTx(ctx context.Context, tx pgx.Tx, follower, followed string) (prevStatus string, err error) {
	const q = `
DELETE FROM follows
WHERE follower_id = $1 AND followed_id = $2
RETURNING status;`
	err = tx.QueryRow(ctx, q, follower, followed).Scan(&prevStatus)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("UnfollowTx: %w", err)
	}
	return prevStatus, nil
}

// FollowState returns the relationship status of viewer→target, or empty.
func (r *SocialRepo) FollowState(ctx context.Context, viewer, target string) (string, error) {
	const q = `SELECT status FROM follows WHERE follower_id = $1 AND followed_id = $2;`
	var s string
	err := r.db.QueryRow(ctx, q, viewer, target).Scan(&s)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("FollowState: %w", err)
	}
	return s, nil
}

// ApproveTx is the tx-aware variant.
func (r *SocialRepo) ApproveTx(ctx context.Context, tx pgx.Tx, followedID, followerID string) error {
	const q = `
UPDATE follows SET status = 'accepted', accepted_at = NOW()
WHERE follower_id = $1 AND followed_id = $2 AND status = 'pending';`
	ct, err := tx.Exec(ctx, q, followerID, followedID)
	if err != nil {
		return fmt.Errorf("ApproveTx: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// DeclineTx is the tx-aware variant.
func (r *SocialRepo) DeclineTx(ctx context.Context, tx pgx.Tx, followedID, followerID string) error {
	const q = `DELETE FROM follows WHERE follower_id = $1 AND followed_id = $2 AND status = 'pending';`
	ct, err := tx.Exec(ctx, q, followerID, followedID)
	if err != nil {
		return fmt.Errorf("DeclineTx: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// Followers / Following — cursor on created_at of the follow row.
type SocialUser struct {
	ID              string    `json:"id"`
	Username        string    `json:"username"`
	DisplayUsername string    `json:"display_username"`
	DisplayName     string    `json:"display_name"`
	AvatarURL       *string   `json:"avatar_url"`
	FollowedAt      time.Time `json:"followed_at"`
}

// Followers / Following: tuple keyset on (accepted_at, follower_id|
// followed_id) backed by idx_follows_followed_accepted_keyset
// (migration 012). All accepted rows have accepted_at NOT NULL
// (CHECK on the follows table in 001), so the previous
// "NULLS LAST" qualifier is no longer needed.
func (r *SocialRepo) Followers(ctx context.Context, userID string, cursorTs *time.Time, cursorUserID *string, limit int) ([]SocialUser, error) {
	const q = `
SELECT u.id, u.username, u.display_username, u.display_name, u.avatar_url, f.accepted_at
FROM follows f
JOIN users u ON u.id = f.follower_id AND u.deleted_at IS NULL
WHERE f.followed_id = $1 AND f.status = 'accepted'
  AND ($2::timestamptz IS NULL OR (f.accepted_at, f.follower_id) < ($2::timestamptz, $3::uuid))
ORDER BY f.accepted_at DESC, f.follower_id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, userID, cursorTs, cursorUserID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("Followers: %w", err)
	}
	defer rows.Close()
	return scanSocialUsers(rows)
}

func (r *SocialRepo) Following(ctx context.Context, userID string, cursorTs *time.Time, cursorUserID *string, limit int) ([]SocialUser, error) {
	const q = `
SELECT u.id, u.username, u.display_username, u.display_name, u.avatar_url, f.accepted_at
FROM follows f
JOIN users u ON u.id = f.followed_id AND u.deleted_at IS NULL
WHERE f.follower_id = $1 AND f.status = 'accepted'
  AND ($2::timestamptz IS NULL OR (f.accepted_at, f.followed_id) < ($2::timestamptz, $3::uuid))
ORDER BY f.accepted_at DESC, f.followed_id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, userID, cursorTs, cursorUserID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("Following: %w", err)
	}
	defer rows.Close()
	return scanSocialUsers(rows)
}

func scanSocialUsers(rows pgx.Rows) ([]SocialUser, error) {
	var out []SocialUser
	for rows.Next() {
		var su SocialUser
		if err := rows.Scan(&su.ID, &su.Username, &su.DisplayUsername, &su.DisplayName, &su.AvatarURL, &su.FollowedAt); err != nil {
			return nil, fmt.Errorf("scanSocialUsers: %w", err)
		}
		out = append(out, su)
	}
	return out, rows.Err()
}
