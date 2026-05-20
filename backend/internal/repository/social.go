package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/domain"
)

type SocialRepo struct{ db *pgxpool.Pool }

// Follow handles both public (instant) and private (request) flows. Returns
// the resulting status ('accepted' or 'pending'). If the relationship already
// exists, the existing status is returned (idempotent).
func (r *SocialRepo) Follow(ctx context.Context, follower, followed string) (string, error) {
	if follower == followed {
		return "", apierror.ErrFollowSelf
	}

	// Determine target privacy.
	var privacy string
	err := r.db.QueryRow(ctx,
		`SELECT privacy_mode FROM users WHERE id = $1 AND deleted_at IS NULL;`, followed,
	).Scan(&privacy)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", apierror.ErrNotFound
	}
	if err != nil {
		return "", fmt.Errorf("Follow lookup: %w", err)
	}

	status := "accepted"
	var acceptedAt *time.Time
	if privacy == "private" {
		status = "pending"
	} else {
		now := time.Now()
		acceptedAt = &now
	}
	const q = `
INSERT INTO follows (follower_id, followed_id, status, accepted_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (follower_id, followed_id) DO NOTHING
RETURNING status;`
	var out string
	err = r.db.QueryRow(ctx, q, follower, followed, status, acceptedAt).Scan(&out)
	if errors.Is(err, pgx.ErrNoRows) {
		// Row already existed — read its current status.
		err = r.db.QueryRow(ctx,
			`SELECT status FROM follows WHERE follower_id = $1 AND followed_id = $2;`,
			follower, followed).Scan(&out)
		if err != nil {
			return "", fmt.Errorf("Follow existing: %w", err)
		}
		return out, nil
	}
	if err != nil {
		return "", fmt.Errorf("Follow insert: %w", err)
	}
	return out, nil
}

// Unfollow deletes the row regardless of status.
func (r *SocialRepo) Unfollow(ctx context.Context, follower, followed string) error {
	const q = `DELETE FROM follows WHERE follower_id = $1 AND followed_id = $2;`
	if _, err := r.db.Exec(ctx, q, follower, followed); err != nil {
		return fmt.Errorf("Unfollow: %w", err)
	}
	return nil
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

// Inbox lists pending follow requests for the current user.
func (r *SocialRepo) Inbox(ctx context.Context, userID string, cursorTs *time.Time, limit int) ([]domain.FollowRequest, error) {
	const q = `
SELECT f.follower_id, u.username, u.display_username, u.display_name, u.avatar_url, u.bio, f.created_at
FROM follows f
JOIN users u ON u.id = f.follower_id AND u.deleted_at IS NULL
WHERE f.followed_id = $1 AND f.status = 'pending'
  AND ($2::timestamptz IS NULL OR f.created_at < $2)
ORDER BY f.created_at DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, q, userID, cursorTs, limit+1)
	if err != nil {
		return nil, fmt.Errorf("Inbox: %w", err)
	}
	defer rows.Close()
	out := make([]domain.FollowRequest, 0, limit+1)
	for rows.Next() {
		var fr domain.FollowRequest
		if err := rows.Scan(&fr.UserID, &fr.Username, &fr.DisplayUsername, &fr.DisplayName, &fr.AvatarURL, &fr.Bio, &fr.CreatedAt); err != nil {
			return nil, fmt.Errorf("Inbox scan: %w", err)
		}
		out = append(out, fr)
	}
	return out, rows.Err()
}

// Approve flips a pending request to accepted.
func (r *SocialRepo) Approve(ctx context.Context, followedID, followerID string) error {
	const q = `
UPDATE follows SET status = 'accepted', accepted_at = NOW()
WHERE follower_id = $1 AND followed_id = $2 AND status = 'pending';`
	ct, err := r.db.Exec(ctx, q, followerID, followedID)
	if err != nil {
		return fmt.Errorf("Approve: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return apierror.ErrNotFound
	}
	return nil
}

// Decline removes a pending request.
func (r *SocialRepo) Decline(ctx context.Context, followedID, followerID string) error {
	const q = `DELETE FROM follows WHERE follower_id = $1 AND followed_id = $2 AND status = 'pending';`
	ct, err := r.db.Exec(ctx, q, followerID, followedID)
	if err != nil {
		return fmt.Errorf("Decline: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return apierror.ErrNotFound
	}
	return nil
}

// Followers / Following — cursor on created_at of the follow row.
type SocialUser struct {
	ID              string  `json:"id"`
	Username        string  `json:"username"`
	DisplayUsername string  `json:"display_username"`
	DisplayName     string  `json:"display_name"`
	AvatarURL       *string `json:"avatar_url"`
	FollowedAt      time.Time `json:"followed_at"`
}

func (r *SocialRepo) Followers(ctx context.Context, userID string, cursorTs *time.Time, limit int) ([]SocialUser, error) {
	const q = `
SELECT u.id, u.username, u.display_username, u.display_name, u.avatar_url, f.accepted_at
FROM follows f
JOIN users u ON u.id = f.follower_id AND u.deleted_at IS NULL
WHERE f.followed_id = $1 AND f.status = 'accepted'
  AND ($2::timestamptz IS NULL OR f.accepted_at < $2)
ORDER BY f.accepted_at DESC NULLS LAST
LIMIT $3;`
	rows, err := r.db.Query(ctx, q, userID, cursorTs, limit+1)
	if err != nil {
		return nil, fmt.Errorf("Followers: %w", err)
	}
	defer rows.Close()
	return scanSocialUsers(rows)
}

func (r *SocialRepo) Following(ctx context.Context, userID string, cursorTs *time.Time, limit int) ([]SocialUser, error) {
	const q = `
SELECT u.id, u.username, u.display_username, u.display_name, u.avatar_url, f.accepted_at
FROM follows f
JOIN users u ON u.id = f.followed_id AND u.deleted_at IS NULL
WHERE f.follower_id = $1 AND f.status = 'accepted'
  AND ($2::timestamptz IS NULL OR f.accepted_at < $2)
ORDER BY f.accepted_at DESC NULLS LAST
LIMIT $3;`
	rows, err := r.db.Query(ctx, q, userID, cursorTs, limit+1)
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
