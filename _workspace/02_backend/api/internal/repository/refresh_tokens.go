package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// RefreshTokenRepo persists rotating refresh tokens. The raw secret is never
// stored — the application hashes it (SHA-256) before insert, and looks up by
// the same hash on rotation.
type RefreshTokenRepo struct{ db *pgxpool.Pool }

// NewRefreshTokenRepo constructs a refresh-token repository. Exposed so tests
// can build one against a custom pool if needed; production wiring uses
// `repository.New`.
func NewRefreshTokenRepo(pool *pgxpool.Pool) *RefreshTokenRepo {
	return &RefreshTokenRepo{db: pool}
}

// RefreshTokenRow mirrors the columns the handler layer cares about. The
// raw secret + hash are intentionally absent from this struct so that an
// accidental log/marshal cannot leak them.
type RefreshTokenRow struct {
	ID        string
	UserID    string
	ParentID  *string
	FamilyID  string
	IssuedAt  time.Time
	ExpiresAt time.Time
	RevokedAt *time.Time
}

// Insert persists a freshly-issued refresh token. `parentID` is nil for
// first-time logins; on rotation the caller sets it to the predecessor's id.
// `familyID` is the chain-root id — for a brand-new chain pass the empty
// string and the repo will materialize the inserted row's own id as the
// family id.
//
// Returns the new row's id (== familyID for first-time logins).
func (r *RefreshTokenRepo) Insert(
	ctx context.Context,
	userID string,
	hash []byte,
	parentID *string,
	familyID string,
	ttl time.Duration,
) (string, error) {
	expiresAt := time.Now().Add(ttl)

	if familyID == "" {
		// Originating token: insert WITHOUT family_id first, then update so
		// family_id == id. We do this in a single INSERT … RETURNING using a
		// gen_random_uuid() default + an UPDATE; simpler is a two-statement
		// transaction.
		tx, err := r.db.Begin(ctx)
		if err != nil {
			return "", fmt.Errorf("RefreshTokenRepo.Insert begin: %w", err)
		}
		defer func() { _ = tx.Rollback(ctx) }()

		const ins = `
INSERT INTO refresh_tokens (user_id, token_hash, parent_id, family_id, expires_at)
VALUES ($1, $2, $3, gen_random_uuid(), $4)
RETURNING id;`
		var id string
		if err := tx.QueryRow(ctx, ins, userID, hash, parentID, expiresAt).Scan(&id); err != nil {
			return "", fmt.Errorf("RefreshTokenRepo.Insert: %w", err)
		}
		const upd = `UPDATE refresh_tokens SET family_id = id WHERE id = $1;`
		if _, err := tx.Exec(ctx, upd, id); err != nil {
			return "", fmt.Errorf("RefreshTokenRepo.Insert family backfill: %w", err)
		}
		if err := tx.Commit(ctx); err != nil {
			return "", fmt.Errorf("RefreshTokenRepo.Insert commit: %w", err)
		}
		return id, nil
	}

	const q = `
INSERT INTO refresh_tokens (user_id, token_hash, parent_id, family_id, expires_at)
VALUES ($1, $2, $3, $4, $5)
RETURNING id;`
	var id string
	if err := r.db.QueryRow(ctx, q, userID, hash, parentID, familyID, expiresAt).Scan(&id); err != nil {
		return "", fmt.Errorf("RefreshTokenRepo.Insert: %w", err)
	}
	return id, nil
}

// LookupByHash returns the row matching the given hash, regardless of its
// revocation state. The caller is responsible for checking `revoked_at` and
// `expires_at` — re-use detection needs to distinguish "valid", "already
// revoked" (compromise signal), and "expired".
//
// On miss the underlying pgx error is wrapped via wrapNoRows so the caller
// can `errors.Is(err, apierror.ErrNotFound)`.
func (r *RefreshTokenRepo) LookupByHash(ctx context.Context, hash []byte) (*RefreshTokenRow, error) {
	const q = `
SELECT id, user_id, parent_id, family_id, issued_at, expires_at, revoked_at
FROM refresh_tokens
WHERE token_hash = $1
LIMIT 1;`
	var row RefreshTokenRow
	if err := r.db.QueryRow(ctx, q, hash).Scan(
		&row.ID, &row.UserID, &row.ParentID, &row.FamilyID,
		&row.IssuedAt, &row.ExpiresAt, &row.RevokedAt,
	); err != nil {
		return nil, wrapNoRows("RefreshTokenRepo.LookupByHash", err)
	}
	return &row, nil
}

// MarkRevoked sets revoked_at = now() on a single token. Idempotent: a
// token that is already revoked keeps its original revoked_at.
func (r *RefreshTokenRepo) MarkRevoked(ctx context.Context, id string) error {
	const q = `UPDATE refresh_tokens SET revoked_at = NOW() WHERE id = $1 AND revoked_at IS NULL;`
	if _, err := r.db.Exec(ctx, q, id); err != nil {
		return fmt.Errorf("RefreshTokenRepo.MarkRevoked: %w", err)
	}
	return nil
}

// RevokeFamily marks every non-revoked token in a family as revoked. Used by
// the re-use detection path: when a token presented for refresh is already
// revoked, the entire chain (parents, siblings, descendants) is treated as
// compromised. Returns the number of rows updated for the caller's audit log.
func (r *RefreshTokenRepo) RevokeFamily(ctx context.Context, familyID string) (int, error) {
	const q = `
UPDATE refresh_tokens SET revoked_at = NOW()
WHERE family_id = $1 AND revoked_at IS NULL;`
	ct, err := r.db.Exec(ctx, q, familyID)
	if err != nil {
		return 0, fmt.Errorf("RefreshTokenRepo.RevokeFamily: %w", err)
	}
	return int(ct.RowsAffected()), nil
}

// RevokeAllForUser marks every active refresh token for the given user as
// revoked, across all families. Used by /v1/auth/logout without a
// refresh_token (logout-everywhere). Returns the number of rows updated.
func (r *RefreshTokenRepo) RevokeAllForUser(ctx context.Context, userID string) (int, error) {
	const q = `
UPDATE refresh_tokens SET revoked_at = NOW()
WHERE user_id = $1 AND revoked_at IS NULL;`
	ct, err := r.db.Exec(ctx, q, userID)
	if err != nil {
		return 0, fmt.Errorf("RefreshTokenRepo.RevokeAllForUser: %w", err)
	}
	return int(ct.RowsAffected()), nil
}
