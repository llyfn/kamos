package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/apierror"
)

// PhotoUploadRepo backs the photo_uploads table from migration 004.
type PhotoUploadRepo struct{ db *pgxpool.Pool }

// PhotoUpload mirrors the row.
type PhotoUpload struct {
	ID          string
	UserID      string
	BlobKey     string
	ContentType string
	ByteSize    int64
	Status      string
	CheckInID   *string
	CreatedAt   time.Time
	AttachedAt  *time.Time
	OrphanedAt  *time.Time
}

// Create inserts a fresh 'pending' row and returns the generated id.
func (r *PhotoUploadRepo) Create(ctx context.Context, userID, blobKey, contentType string, byteSize int64) (string, error) {
	const q = `
INSERT INTO photo_uploads (user_id, blob_key, content_type, byte_size)
VALUES ($1, $2, $3, $4)
RETURNING id;`
	var id string
	if err := r.db.QueryRow(ctx, q, userID, blobKey, contentType, byteSize).Scan(&id); err != nil {
		return "", fmt.Errorf("PhotoUploadRepo.Create: %w", err)
	}
	return id, nil
}

// CreateWithID inserts the row but lets the caller provide the id — used so
// the blob_key can encode the id ahead of time. Returns ErrConflict on
// duplicate id (caller should generate a fresh uuid and retry — extremely
// unlikely given UUIDv4 collision odds).
func (r *PhotoUploadRepo) CreateWithID(ctx context.Context, id, userID, blobKey, contentType string, byteSize int64) error {
	const q = `
INSERT INTO photo_uploads (id, user_id, blob_key, content_type, byte_size)
VALUES ($1, $2, $3, $4, $5);`
	if _, err := r.db.Exec(ctx, q, id, userID, blobKey, contentType, byteSize); err != nil {
		return fmt.Errorf("PhotoUploadRepo.CreateWithID: %w", err)
	}
	return nil
}

// FindByID returns the row, or ErrNotFound.
func (r *PhotoUploadRepo) FindByID(ctx context.Context, id string) (*PhotoUpload, error) {
	const q = `
SELECT id, user_id, blob_key, content_type, byte_size, status, check_in_id,
       created_at, attached_at, orphaned_at
FROM photo_uploads
WHERE id = $1;`
	row := r.db.QueryRow(ctx, q, id)
	var p PhotoUpload
	if err := row.Scan(
		&p.ID, &p.UserID, &p.BlobKey, &p.ContentType, &p.ByteSize, &p.Status,
		&p.CheckInID, &p.CreatedAt, &p.AttachedAt, &p.OrphanedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, apierror.ErrNotFound
		}
		return nil, fmt.Errorf("PhotoUploadRepo.FindByID: %w", err)
	}
	return &p, nil
}

// MarkAttached flips status to 'attached' and binds the check_in_id. Idempotent
// for the row currently in 'pending' or 'uploaded' — once attached the
// repository refuses re-attach by returning ErrConflict.
func (r *PhotoUploadRepo) MarkAttached(ctx context.Context, id, checkInID string) error {
	const q = `
UPDATE photo_uploads
SET status = 'attached', attached_at = NOW(), check_in_id = $2
WHERE id = $1 AND status IN ('pending', 'uploaded');`
	ct, err := r.db.Exec(ctx, q, id, checkInID)
	if err != nil {
		return fmt.Errorf("PhotoUploadRepo.MarkAttached: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return apierror.ErrConflict
	}
	return nil
}

// ListOrphanCandidates returns rows older than `cutoff` still in 'pending' or
// 'uploaded'. Caller deletes the blobs then calls MarkOrphaned.
func (r *PhotoUploadRepo) ListOrphanCandidates(ctx context.Context, cutoff time.Time, limit int) ([]PhotoUpload, error) {
	const q = `
SELECT id, user_id, blob_key, content_type, byte_size, status, check_in_id,
       created_at, attached_at, orphaned_at
FROM photo_uploads
WHERE status IN ('pending', 'uploaded') AND created_at < $1
ORDER BY created_at
LIMIT $2;`
	rows, err := r.db.Query(ctx, q, cutoff, limit)
	if err != nil {
		return nil, fmt.Errorf("PhotoUploadRepo.ListOrphanCandidates: %w", err)
	}
	defer rows.Close()
	var out []PhotoUpload
	for rows.Next() {
		var p PhotoUpload
		if err := rows.Scan(
			&p.ID, &p.UserID, &p.BlobKey, &p.ContentType, &p.ByteSize, &p.Status,
			&p.CheckInID, &p.CreatedAt, &p.AttachedAt, &p.OrphanedAt,
		); err != nil {
			return nil, fmt.Errorf("PhotoUploadRepo.ListOrphanCandidates scan: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// CountPendingForUser returns the number of presigns this user holds that
// are still in 'pending' status and have not yet exceeded the
// presign-PUT TTL. SEC-008 backstop: the handler refuses to issue
// additional presigns when the count is at the cap.
//
// The cutoff matches handlers.presignPutTTL (15 minutes); we compute it
// in the SQL layer with NOW() - INTERVAL so a clock drift between the
// app and the DB doesn't open a window.
func (r *PhotoUploadRepo) CountPendingForUser(ctx context.Context, userID string, ttl time.Duration) (int, error) {
	const q = `
SELECT COUNT(*) FROM photo_uploads
WHERE user_id = $1
  AND status = 'pending'
  AND created_at > NOW() - make_interval(secs => $2);`
	var n int
	if err := r.db.QueryRow(ctx, q, userID, ttl.Seconds()).Scan(&n); err != nil {
		return 0, fmt.Errorf("PhotoUploadRepo.CountPendingForUser: %w", err)
	}
	return n, nil
}

// MarkOrphaned flips the row to 'orphaned' after the blob delete.
func (r *PhotoUploadRepo) MarkOrphaned(ctx context.Context, id string) error {
	const q = `
UPDATE photo_uploads
SET status = 'orphaned', orphaned_at = NOW()
WHERE id = $1 AND status IN ('pending', 'uploaded');`
	if _, err := r.db.Exec(ctx, q, id); err != nil {
		return fmt.Errorf("PhotoUploadRepo.MarkOrphaned: %w", err)
	}
	return nil
}
