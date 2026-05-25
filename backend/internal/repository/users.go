package repository

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/domain"
)

type UserRepo struct{ db *pgxpool.Pool }

// CheckUsernameAvailability mirrors query_patterns.md §1 "Username
// availability". Returns ("live"|"held"|"") and the time at which the held
// handle becomes available. Empty state means available.
func (r *UserRepo) CheckUsernameAvailability(ctx context.Context, username string) (state string, availableAt time.Time, err error) {
	const q = `
SELECT
  CASE
    WHEN deleted_at IS NULL THEN 'live'
    WHEN username_release_at IS NULL OR username_release_at > NOW() THEN 'held'
    ELSE 'released'
  END AS state,
  COALESCE(username_release_at, NOW()) AS available_at
FROM users
WHERE username = LOWER($1)
  AND (deleted_at IS NULL OR username_release_at > NOW())
LIMIT 1;`
	row := r.db.QueryRow(ctx, q, username)
	err = row.Scan(&state, &availableAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", time.Time{}, nil
	}
	if err != nil {
		return "", time.Time{}, fmt.Errorf("UserRepo.CheckUsernameAvailability: %w", err)
	}
	return state, availableAt, nil
}

// EmailExists reports whether the email is already taken by a live user.
func (r *UserRepo) EmailExists(ctx context.Context, email string) (bool, error) {
	var exists bool
	const q = `SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(email) = LOWER($1) AND deleted_at IS NULL);`
	if err := r.db.QueryRow(ctx, q, email).Scan(&exists); err != nil {
		return false, fmt.Errorf("UserRepo.EmailExists: %w", err)
	}
	return exists, nil
}

// CreateUserParams carries the registration inputs.
type CreateUserParams struct {
	DisplayUsername string // case preserved; lowercase = username
	Email           string
	EmailVerified   bool
	PasswordHash    *string
	GoogleSub       *string
	DisplayName     string
	AvatarURL       *string
	Bio             *string
	Locale          string
}

// CreateUserWithDefaults inserts the user AND the two default collections in
// one transaction (SPEC §6.1 / §6.8). Returns the canonical user row.
func (r *UserRepo) CreateUserWithDefaults(ctx context.Context, p CreateUserParams) (*domain.User, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("CreateUserWithDefaults: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	user, err := insertUserTx(ctx, tx, p)
	if err != nil {
		return nil, err
	}

	inv, wish := domain.LocalizedDefaultCollections(p.Locale)
	const insColl = `INSERT INTO collections (user_id, name) VALUES ($1, $2), ($1, $3);`
	if _, err := tx.Exec(ctx, insColl, user.ID, inv, wish); err != nil {
		return nil, fmt.Errorf("CreateUserWithDefaults: seed collections: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("CreateUserWithDefaults: commit: %w", err)
	}
	return user, nil
}

func insertUserTx(ctx context.Context, tx pgx.Tx, p CreateUserParams) (*domain.User, error) {
	const q = `
INSERT INTO users (
  username, display_username, email, email_verified,
  password_hash, google_sub,
  display_name, avatar_url, bio,
  locale, privacy_mode
) VALUES (
  LOWER($1), $1, $2, $3,
  $4, $5,
  $6, $7, $8,
  $9, 'public'
)
RETURNING id, username, display_username, email, email_verified,
          display_name, avatar_url, bio, locale, privacy_mode, created_at;`
	var u domain.User
	row := tx.QueryRow(ctx, q,
		p.DisplayUsername, p.Email, p.EmailVerified,
		p.PasswordHash, p.GoogleSub,
		p.DisplayName, p.AvatarURL, p.Bio,
		p.Locale,
	)
	if err := row.Scan(
		&u.ID, &u.Username, &u.DisplayUsername, &u.Email, &u.EmailVerified,
		&u.DisplayName, &u.AvatarURL, &u.Bio, &u.Locale, &u.PrivacyMode, &u.CreatedAt,
	); err != nil {
		// Catch unique-violation on the live partial index — surface as
		// USERNAME_HELD or EMAIL_TAKEN depending on the constraint name.
		msg := err.Error()
		switch {
		case strings.Contains(msg, "idx_users_username_live"):
			return nil, domain.ErrUsernameHeld
		case strings.Contains(msg, "idx_users_email_live"):
			return nil, domain.ErrEmailTaken
		case strings.Contains(msg, "idx_users_google_sub_live"):
			return nil, domain.ErrConflict
		}
		return nil, fmt.Errorf("insertUserTx: %w", err)
	}
	return &u, nil
}

// FindByEmail returns the user with the given email (case-insensitive),
// including the password hash for login verification. NotFound on miss.
type AuthRow struct {
	domain.User
	PasswordHash *string
	GoogleSub    *string
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*AuthRow, error) {
	const q = `
SELECT id, username, display_username, email, email_verified,
       password_hash, google_sub,
       display_name, avatar_url, bio, locale, privacy_mode, created_at
FROM users
WHERE LOWER(email) = LOWER($1) AND deleted_at IS NULL
LIMIT 1;`
	var u AuthRow
	row := r.db.QueryRow(ctx, q, email)
	if err := row.Scan(
		&u.ID, &u.Username, &u.DisplayUsername, &u.Email, &u.EmailVerified,
		&u.PasswordHash, &u.GoogleSub,
		&u.DisplayName, &u.AvatarURL, &u.Bio, &u.Locale, &u.PrivacyMode, &u.CreatedAt,
	); err != nil {
		return nil, wrapNoRows("UserRepo.FindByEmail", err)
	}
	return &u, nil
}

// FindByGoogleSub looks up a live user by their Google subject id.
func (r *UserRepo) FindByGoogleSub(ctx context.Context, sub string) (*domain.User, error) {
	const q = `
SELECT id, username, display_username, email, email_verified,
       display_name, avatar_url, bio, locale, privacy_mode, created_at
FROM users
WHERE google_sub = $1 AND deleted_at IS NULL
LIMIT 1;`
	var u domain.User
	row := r.db.QueryRow(ctx, q, sub)
	if err := row.Scan(
		&u.ID, &u.Username, &u.DisplayUsername, &u.Email, &u.EmailVerified,
		&u.DisplayName, &u.AvatarURL, &u.Bio, &u.Locale, &u.PrivacyMode, &u.CreatedAt,
	); err != nil {
		return nil, wrapNoRows("UserRepo.FindByGoogleSub", err)
	}
	return &u, nil
}

// FindByID returns a live user.
func (r *UserRepo) FindByID(ctx context.Context, id string) (*domain.User, error) {
	const q = `
SELECT id, username, display_username, email, email_verified,
       display_name, avatar_url, bio, locale, privacy_mode, created_at
FROM users
WHERE id = $1 AND deleted_at IS NULL
LIMIT 1;`
	var u domain.User
	row := r.db.QueryRow(ctx, q, id)
	if err := row.Scan(
		&u.ID, &u.Username, &u.DisplayUsername, &u.Email, &u.EmailVerified,
		&u.DisplayName, &u.AvatarURL, &u.Bio, &u.Locale, &u.PrivacyMode, &u.CreatedAt,
	); err != nil {
		return nil, wrapNoRows("UserRepo.FindByID", err)
	}
	return &u, nil
}

// FindMe is like FindByID but additionally returns the user's role and
// deleted_at — surfaced on GET /v1/users/me so the admin client can
// branch on RBAC state and pick up soft-delete signals.
//
// Note: GET /v1/users/me runs behind the SEC-006 revocation cache, so a
// soft-deleted user normally cannot reach this method (the auth middleware
// rejects them first). We still return deleted_at for safety + for the
// brief window before the next cache refresh in the unlikely event of a
// missed Add() call.
type MeRow struct {
	User      domain.User
	Role      domain.UserRole
	DeletedAt *time.Time
}

func (r *UserRepo) FindMe(ctx context.Context, id string) (*MeRow, error) {
	const q = `
SELECT id, username, display_username, email, email_verified,
       display_name, avatar_url, bio, locale, privacy_mode, created_at,
       role::text, deleted_at
FROM users
WHERE id = $1
LIMIT 1;`
	var out MeRow
	var roleStr string
	row := r.db.QueryRow(ctx, q, id)
	if err := row.Scan(
		&out.User.ID, &out.User.Username, &out.User.DisplayUsername,
		&out.User.Email, &out.User.EmailVerified,
		&out.User.DisplayName, &out.User.AvatarURL, &out.User.Bio,
		&out.User.Locale, &out.User.PrivacyMode, &out.User.CreatedAt,
		&roleStr, &out.DeletedAt,
	); err != nil {
		return nil, wrapNoRows("UserRepo.FindMe", err)
	}
	out.Role = domain.UserRole(roleStr)
	if !out.Role.Valid() {
		return nil, fmt.Errorf("UserRepo.FindMe: unknown role %q", roleStr)
	}
	return &out, nil
}

// FindByUsername returns a live user by lowercase handle. NotFound on miss.
func (r *UserRepo) FindByUsername(ctx context.Context, username string) (*domain.User, error) {
	const q = `
SELECT id, username, display_username, email, email_verified,
       display_name, avatar_url, bio, locale, privacy_mode, created_at
FROM users
WHERE username = LOWER($1) AND deleted_at IS NULL
LIMIT 1;`
	var u domain.User
	row := r.db.QueryRow(ctx, q, username)
	if err := row.Scan(
		&u.ID, &u.Username, &u.DisplayUsername, &u.Email, &u.EmailVerified,
		&u.DisplayName, &u.AvatarURL, &u.Bio, &u.Locale, &u.PrivacyMode, &u.CreatedAt,
	); err != nil {
		return nil, wrapNoRows("UserRepo.FindByUsername", err)
	}
	return &u, nil
}

// SearchCursor carries the three values the SearchUsers keyset needs:
// the match rank tier, the row created_at, and the row id. The tier is
// part of the cursor because results are ordered by (rank ASC,
// created_at DESC, id DESC) and a 2-tuple keyset of just (created_at,
// id) misorders pages whenever a later page's leading row sits in a
// later tier than the previous page's trailing row (it would re-emit
// rows from earlier tiers and skip the new tier's older rows). The
// handler bundles this into the opaque cursor envelope; clients never
// see the rank.
type SearchCursor struct {
	Rank      int
	CreatedAt time.Time
	ID        string
}

// SearchRow pairs the projected user with the rank tier it matched in
// so the handler can re-emit that rank into the next cursor.
type SearchRow struct {
	User domain.PublicUser
	Rank int
}

// likeEscaper escapes the three PostgreSQL LIKE metacharacters so the
// user-supplied query is interpreted literally. Without this, a query
// like "a%" matches every username starting with "a"; "_" matches any
// single character; "\" pairs with the next character. The default
// LIKE escape is "\", which our patterns rely on.
var likeEscaper = strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)

// SearchUsers returns a page of live users matching `query`, ranked by
// match quality:
//
//	rank 1 — username has the query as a case-insensitive prefix
//	rank 2 — display_name has the query as a case-insensitive prefix
//	rank 3 — username OR display_name contains the query
//
// Within a rank, results are sorted by (created_at, id) DESC so the
// keyset cursor stays stable. The handler validates query length;
// repository assumes a non-empty trimmed string.
//
// `cursor` is the SearchCursor from the previously-returned next-page
// token (nil for the first page). The keyset predicate is
// (rank > $score OR (rank = $score AND (created_at, id) < ($ts, $id)))
// so the walk advances through the rank tiers without duplicating or
// skipping rows at tier boundaries.
//
// At KAMOS' current scale (users table is small) the ILIKE scan is
// fine; a trigram or pg_trgm index can be layered on later if scan
// time becomes meaningful.
func (r *UserRepo) SearchUsers(
	ctx context.Context,
	query string,
	cur *SearchCursor,
	limit int,
) ([]SearchRow, error) {
	if limit <= 0 {
		limit = 20
	}
	// Escape LIKE wildcards in the user-supplied query so `%` and `_`
	// match literally instead of as metacharacters. Apply this before
	// building the prefix/contains patterns so only our own surrounding
	// `%` carries metacharacter meaning.
	escaped := likeEscaper.Replace(query)
	prefix := escaped + "%"
	contains := "%" + escaped + "%"

	// $5/$6/$7 carry the cursor triple; nil means "first page" and the
	// SQL guard short-circuits the keyset predicate.
	var (
		curRank *int
		curTs   *time.Time
		curID   *string
	)
	if cur != nil {
		curRank = &cur.Rank
		ts := cur.CreatedAt
		curTs = &ts
		id := cur.ID
		curID = &id
	}
	const q = `
SELECT id, username, display_username, display_name, avatar_url, bio,
       locale, privacy_mode, created_at,
       CASE
         WHEN username ILIKE $1     THEN 1
         WHEN display_name ILIKE $1 THEN 2
         ELSE 3
       END AS rank
FROM users
WHERE deleted_at IS NULL
  AND (username ILIKE $2 OR display_name ILIKE $2)
  AND (
    $4::int IS NULL
    OR (CASE
          WHEN username ILIKE $1     THEN 1
          WHEN display_name ILIKE $1 THEN 2
          ELSE 3
        END) > $4::int
    OR ((CASE
          WHEN username ILIKE $1     THEN 1
          WHEN display_name ILIKE $1 THEN 2
          ELSE 3
        END) = $4::int
        AND (created_at, id) < ($5::timestamptz, $6::uuid))
  )
ORDER BY rank ASC, created_at DESC, id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, q,
		prefix, contains, limit+1,
		curRank, curTs, curID,
	)
	if err != nil {
		return nil, fmt.Errorf("UserRepo.SearchUsers: %w", err)
	}
	defer rows.Close()
	out := make([]SearchRow, 0, limit+1)
	for rows.Next() {
		var row SearchRow
		if err := rows.Scan(
			&row.User.ID, &row.User.Username, &row.User.DisplayUsername, &row.User.DisplayName,
			&row.User.AvatarURL, &row.User.Bio, &row.User.Locale, &row.User.PrivacyMode, &row.User.CreatedAt,
			&row.Rank,
		); err != nil {
			return nil, fmt.Errorf("UserRepo.SearchUsers scan: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// LoadPasswordHash returns the hash for an authed user (used by password change).
func (r *UserRepo) LoadPasswordHash(ctx context.Context, id string) (string, error) {
	var h *string
	const q = `SELECT password_hash FROM users WHERE id = $1 AND deleted_at IS NULL;`
	if err := r.db.QueryRow(ctx, q, id).Scan(&h); err != nil {
		return "", wrapNoRows("UserRepo.LoadPasswordHash", err)
	}
	if h == nil {
		return "", domain.ErrNotFound
	}
	return *h, nil
}

// Stats computes the four counters shown on the profile screen.
func (r *UserRepo) Stats(ctx context.Context, userID string) (domain.UserStats, error) {
	var s domain.UserStats
	const q = `
SELECT
  (SELECT COUNT(*) FROM check_ins WHERE user_id = $1 AND deleted_at IS NULL),
  (SELECT COUNT(DISTINCT beverage_id) FROM check_ins WHERE user_id = $1 AND deleted_at IS NULL),
  (SELECT COUNT(*) FROM follows WHERE followed_id = $1 AND status = 'accepted'),
  (SELECT COUNT(*) FROM follows WHERE follower_id = $1 AND status = 'accepted');`
	if err := r.db.QueryRow(ctx, q, userID).Scan(&s.Checkins, &s.Unique, &s.Followers, &s.Following); err != nil {
		return s, fmt.Errorf("UserRepo.Stats: %w", err)
	}
	return s, nil
}

// UpdateMe applies a partial update; only non-nil fields are written.
func (r *UserRepo) UpdateMe(ctx context.Context, id string, p domain.UpdateMeRequest) (*domain.User, error) {
	// COALESCE pattern: pass NULL for unchanged columns.
	const q = `
UPDATE users SET
  display_name = COALESCE($2, display_name),
  bio          = CASE WHEN $3::boolean THEN $4 ELSE bio END,
  avatar_url   = CASE WHEN $5::boolean THEN $6 ELSE avatar_url END,
  locale       = COALESCE($7, locale),
  privacy_mode = COALESCE($8, privacy_mode)
WHERE id = $1 AND deleted_at IS NULL
RETURNING id, username, display_username, email, email_verified,
          display_name, avatar_url, bio, locale, privacy_mode, created_at;`

	// We use the "explicit bool flag" pattern for nullable fields so the
	// client can clear a value (PATCH bio = null) without overwriting on omit.
	var (
		bioSet, bio = false, (*string)(nil)
		avSet, av   = false, (*string)(nil)
	)
	if p.Bio != nil {
		bioSet = true
		bio = p.Bio
		if strings.TrimSpace(*p.Bio) == "" {
			bio = nil
		}
	}
	if p.AvatarURL != nil {
		avSet = true
		av = p.AvatarURL
		if strings.TrimSpace(*p.AvatarURL) == "" {
			av = nil
		}
	}

	var u domain.User
	row := r.db.QueryRow(ctx, q,
		id,
		p.DisplayName,
		bioSet, bio,
		avSet, av,
		p.Locale,
		p.PrivacyMode,
	)
	if err := row.Scan(
		&u.ID, &u.Username, &u.DisplayUsername, &u.Email, &u.EmailVerified,
		&u.DisplayName, &u.AvatarURL, &u.Bio, &u.Locale, &u.PrivacyMode, &u.CreatedAt,
	); err != nil {
		return nil, wrapNoRows("UserRepo.UpdateMe", err)
	}
	return &u, nil
}

// SoftDelete sets deleted_at and the 30-day release time per SPEC §3.3.
func (r *UserRepo) SoftDelete(ctx context.Context, id string) error {
	const q = `
UPDATE users SET
  deleted_at = NOW(),
  username_release_at = NOW() + INTERVAL '30 days'
WHERE id = $1 AND deleted_at IS NULL;`
	ct, err := r.db.Exec(ctx, q, id)
	if err != nil {
		return fmt.Errorf("UserRepo.SoftDelete: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// UpdatePasswordHash rewrites the hash for the given user.
func (r *UserRepo) UpdatePasswordHash(ctx context.Context, id, hash string) error {
	const q = `UPDATE users SET password_hash = $2 WHERE id = $1 AND deleted_at IS NULL;`
	ct, err := r.db.Exec(ctx, q, id, hash)
	if err != nil {
		return fmt.Errorf("UserRepo.UpdatePasswordHash: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// UpdateEmail rewrites the email and clears the verification flag.
func (r *UserRepo) UpdateEmail(ctx context.Context, id, email string) error {
	const q = `UPDATE users SET email = $2, email_verified = FALSE WHERE id = $1 AND deleted_at IS NULL;`
	ct, err := r.db.Exec(ctx, q, id, email)
	if err != nil {
		// Catch email-uniqueness conflicts.
		if strings.Contains(err.Error(), "idx_users_email_live") {
			return domain.ErrEmailTaken
		}
		return fmt.Errorf("UserRepo.UpdateEmail: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

// MarkEmailVerified flips email_verified = TRUE and consumes the token row.
//
// SEC-004 (migration 010): the row is keyed by token_hash, not the raw
// plaintext. The caller passes the raw token from the verification URL
// and we hash it here in lockstep with FindUserByVerificationToken.
func (r *UserRepo) MarkEmailVerified(ctx context.Context, userID, token string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("MarkEmailVerified: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	hash := auth.HashVerificationToken(token)
	const claim = `
UPDATE email_verifications SET used_at = NOW()
WHERE token_hash = $1 AND user_id = $2 AND used_at IS NULL AND expires_at > NOW()
RETURNING id;`
	var rowID string
	if err := tx.QueryRow(ctx, claim, hash, userID).Scan(&rowID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrTokenExpired
		}
		return fmt.Errorf("MarkEmailVerified: claim: %w", err)
	}
	const mark = `UPDATE users SET email_verified = TRUE WHERE id = $1;`
	if _, err := tx.Exec(ctx, mark, userID); err != nil {
		return fmt.Errorf("MarkEmailVerified: mark: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("MarkEmailVerified: commit: %w", err)
	}
	return nil
}

// CreateVerificationToken stores a token row with a 24h expiry.
//
// SEC-004 (migration 010): the DB column is `token_hash` (BYTEA SHA-256);
// the caller still passes the raw token (so the handler can render it into
// the verification email link) and we hash it before insert.
func (r *UserRepo) CreateVerificationToken(ctx context.Context, userID, token string) error {
	hash := auth.HashVerificationToken(token)
	const q = `INSERT INTO email_verifications (user_id, token_hash, expires_at)
              VALUES ($1, $2, NOW() + INTERVAL '24 hours');`
	if _, err := r.db.Exec(ctx, q, userID, hash); err != nil {
		return fmt.Errorf("CreateVerificationToken: %w", err)
	}
	return nil
}

// FindUserByVerificationToken returns the user a token belongs to (if still
// fresh and unused). Looks up by SHA-256 of the raw token (SEC-004).
func (r *UserRepo) FindUserByVerificationToken(ctx context.Context, token string) (string, error) {
	hash := auth.HashVerificationToken(token)
	const q = `
SELECT user_id FROM email_verifications
WHERE token_hash = $1 AND used_at IS NULL AND expires_at > NOW()
LIMIT 1;`
	var id string
	if err := r.db.QueryRow(ctx, q, hash).Scan(&id); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", domain.ErrTokenExpired
		}
		return "", fmt.Errorf("FindUserByVerificationToken: %w", err)
	}
	return id, nil
}
