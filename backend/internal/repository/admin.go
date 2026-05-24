// Package repository — admin queries.
//
// Admin-only access to:
//   - beverage_addition_requests (list / approve / reject)
//   - check_ins (moderate)
//   - users (list / role update / suspend)
//
// The handler layer (handlers/admin) gates each route by middleware.RequireRole
// before touching these methods. We do NOT re-check the role here — keep the
// repository layer focused on SQL.
package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

// AdminRepo wraps administrative SQL.
type AdminRepo struct{ db *pgxpool.Pool }

// LogAction writes a single moderation_log audit row inside the supplied tx.
// Exported so the Stage 8 admin catalog handlers can stamp their mutations
// without going through a service shim. Existing package-internal write
// paths use insertModerationLog (a thin wrapper that drops the receiver) so
// the per-aggregate helpers in this file don't need a *AdminRepo just to
// audit.
func (r *AdminRepo) LogAction(
	ctx context.Context,
	tx pgx.Tx,
	moderatorID string,
	targetType string,
	targetID string,
	action string,
	notes *string,
	metadata map[string]any,
) error {
	return insertModerationLog(ctx, tx, moderatorID, targetType, targetID, action, notes, metadata)
}

// insertModerationLog writes a single audit row inside the supplied tx. Phase
// 6a contract: every admin write path that changes user-visible state writes
// one of these. Callers carry their moderator id explicitly so the audit row
// attributes the action to the actual signed-in admin, not some service
// account. `metadata` is a free-form JSONB; pass nil when not useful.
func insertModerationLog(
	ctx context.Context,
	tx pgx.Tx,
	moderatorID string,
	targetType string,
	targetID string,
	action string,
	notes *string,
	metadata map[string]any,
) error {
	var meta []byte
	if len(metadata) > 0 {
		b, err := json.Marshal(metadata)
		if err != nil {
			return fmt.Errorf("insertModerationLog marshal metadata: %w", err)
		}
		meta = b
	}
	const q = `
INSERT INTO moderation_log
  (moderator_id, target_type, target_id, action, notes, metadata)
VALUES
  ($1, $2::moderation_target_type, $3, $4::moderation_action_type, $5, $6::jsonb);`
	if _, err := tx.Exec(ctx, q, moderatorID, targetType, targetID, action, notes, meta); err != nil {
		return fmt.Errorf("insertModerationLog: %w", err)
	}
	return nil
}

// ============================================================================
// Beverage addition requests
// ============================================================================

// BeverageRequestRow is the admin-list shape for beverage_addition_requests.
type BeverageRequestRow struct {
	ID         string         `json:"id"`
	UserID     *string        `json:"user_id"`
	Username   *string        `json:"username,omitempty"`
	Payload    []byte         `json:"-"`
	PayloadRaw map[string]any `json:"payload"`
	Status     string         `json:"status"`
	ReviewedBy *string        `json:"reviewed_by,omitempty"`
	ReviewedAt *time.Time     `json:"reviewed_at,omitempty"`
	Notes      *string        `json:"notes,omitempty"`
	CreatedAt  time.Time      `json:"created_at"`
}

// ListBeverageRequestsParams supports cursor pagination on (created_at, id).
// statusFilter "" means "all"; otherwise pass 'pending'|'approved'|'rejected'.
type ListBeverageRequestsParams struct {
	StatusFilter string
	CursorTs     *time.Time
	CursorID     *string
	Limit        int
}

// ListBeverageRequests pages through the queue. JOIN against users lets the
// admin UI display "submitted by @username" without a second round trip.
func (r *AdminRepo) ListBeverageRequests(ctx context.Context, p ListBeverageRequestsParams) ([]BeverageRequestRow, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}
	const q = `
SELECT bar.id, bar.user_id, u.display_username,
       bar.payload, bar.status,
       bar.reviewed_by, bar.reviewed_at, bar.notes, bar.created_at
FROM beverage_addition_requests bar
LEFT JOIN users u ON u.id = bar.user_id
WHERE ($1::text = '' OR bar.status = $1)
  AND ($2::timestamptz IS NULL OR (bar.created_at, bar.id) < ($2::timestamptz, $3::uuid))
ORDER BY bar.created_at DESC, bar.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, p.StatusFilter, p.CursorTs, p.CursorID, p.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("AdminRepo.ListBeverageRequests: %w", err)
	}
	defer rows.Close()
	out := make([]BeverageRequestRow, 0, p.Limit+1)
	for rows.Next() {
		var row BeverageRequestRow
		if err := rows.Scan(&row.ID, &row.UserID, &row.Username,
			&row.Payload, &row.Status,
			&row.ReviewedBy, &row.ReviewedAt, &row.Notes, &row.CreatedAt); err != nil {
			return nil, fmt.Errorf("AdminRepo.ListBeverageRequests scan: %w", err)
		}
		// Materialize the JSONB payload so the handler can emit it directly.
		// Errors here would mean the DB has corrupted JSON — surface as 500.
		row.PayloadRaw, err = unmarshalJSONBToMap(row.Payload)
		if err != nil {
			return nil, fmt.Errorf("AdminRepo.ListBeverageRequests payload: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// ApproveBeverageRequestParams carries the canonical beverage fields the
// admin fills in based on the original request payload.
//
// Migration 016 dropped beverages.prefecture / beverages.region — the
// beverage's locality is now derived through the brewery's prefecture
// chain, so there are no per-beverage geo fields to set here. If the
// admin needs to recurate the brewery's prefecture they do it via
// PATCH /v1/admin/breweries/{id} before approving.
type ApproveBeverageRequestParams struct {
	RequestID       string
	BreweryID       string
	CategoryID      string
	NameI18n        domain.I18nText
	Subcategory     *domain.I18nText
	ABV             *float64
	PolishingRatio  *int
	LabelImageURL   *string
	FlavorProfile   []string
	DescriptionI18n *domain.I18nText
	ReviewerID      string
	Notes           *string
}

// ApproveBeverageRequest creates the beverage row and marks the request
// approved in one transaction. Returns the new beverage_id.
// 409 CONFLICT if the request is not in 'pending' state.
func (r *AdminRepo) ApproveBeverageRequest(ctx context.Context, p ApproveBeverageRequestParams) (string, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return "", fmt.Errorf("ApproveBeverageRequest begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Lock the request row and verify pending.
	var status, categorySlug string
	const lockReq = `SELECT status FROM beverage_addition_requests WHERE id = $1 FOR UPDATE;`
	if err := tx.QueryRow(ctx, lockReq, p.RequestID).Scan(&status); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", domain.ErrNotFound
		}
		return "", fmt.Errorf("ApproveBeverageRequest lock: %w", err)
	}
	if status != "pending" {
		return "", fmt.Errorf("ApproveBeverageRequest: %w (status=%s)", domain.ErrConflict, status)
	}

	// Resolve category slug from the category id — beverages CHECK
	// requires (slug, id) to be consistent.
	if err := tx.QueryRow(ctx,
		`SELECT slug FROM beverage_categories WHERE id = $1;`,
		p.CategoryID).Scan(&categorySlug); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", fmt.Errorf("ApproveBeverageRequest: %w (category)", domain.ErrValidation)
		}
		return "", fmt.Errorf("ApproveBeverageRequest category lookup: %w", err)
	}

	nameJSON, err := jsonMarshalI18n(p.NameI18n)
	if err != nil {
		return "", err
	}
	// subcategory + description: pass a *string so absent → SQL NULL,
	// present → JSONB literal. pgx serializes nil-string and empty-string
	// both as text NULL when the column accepts NULL, but the `::jsonb`
	// cast on an empty string would raise "invalid input syntax for type
	// json" — keeping each nullable here.
	var subJSON, descJSON *string
	if p.Subcategory != nil {
		b, err := jsonMarshalI18n(*p.Subcategory)
		if err != nil {
			return "", err
		}
		s := string(b)
		subJSON = &s
	}
	if p.DescriptionI18n != nil {
		b, err := jsonMarshalI18n(*p.DescriptionI18n)
		if err != nil {
			return "", err
		}
		s := string(b)
		descJSON = &s
	}

	const insBev = `
INSERT INTO beverages (brewery_id, category_id, category_slug, name_i18n,
                       subcategory_i18n, abv, polishing_ratio,
                       label_image_url, flavor_profile, description_i18n)
VALUES ($1, $2, $3, $4::jsonb, $5::jsonb, $6, $7, $8, COALESCE($9, '{}'::text[]), $10::jsonb)
RETURNING id;`
	var bevID string
	if err := tx.QueryRow(ctx, insBev,
		p.BreweryID, p.CategoryID, categorySlug, string(nameJSON),
		subJSON, p.ABV, p.PolishingRatio,
		p.LabelImageURL, p.FlavorProfile, descJSON,
	).Scan(&bevID); err != nil {
		return "", fmt.Errorf("ApproveBeverageRequest insert beverage: %w", err)
	}

	const updReq = `
UPDATE beverage_addition_requests
SET status = 'approved', reviewed_by = $2, reviewed_at = NOW(), notes = $3
WHERE id = $1;`
	if _, err := tx.Exec(ctx, updReq, p.RequestID, p.ReviewerID, p.Notes); err != nil {
		return "", fmt.Errorf("ApproveBeverageRequest update request: %w", err)
	}

	// Audit: every admin moderation action is logged. The new
	// beverage_id is recorded in metadata so the admin UI can deep-link
	// from the audit row to the produced canonical beverage.
	if err := insertModerationLog(ctx, tx,
		p.ReviewerID,
		"beverage_request", p.RequestID,
		"approve",
		p.Notes,
		map[string]any{"beverage_id": bevID},
	); err != nil {
		return "", err
	}

	if err := tx.Commit(ctx); err != nil {
		return "", fmt.Errorf("ApproveBeverageRequest commit: %w", err)
	}
	return bevID, nil
}

// RejectBeverageRequest marks the request rejected with the given notes.
// 409 CONFLICT if the row is not in 'pending' state. Writes a
// moderation_log row in the same transaction.
func (r *AdminRepo) RejectBeverageRequest(ctx context.Context, requestID, reviewerID, notes string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("RejectBeverageRequest begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const q = `
UPDATE beverage_addition_requests
SET status = 'rejected', reviewed_by = $2, reviewed_at = NOW(), notes = $3
WHERE id = $1 AND status = 'pending'
RETURNING id;`
	var id string
	if err := tx.QueryRow(ctx, q, requestID, reviewerID, notes).Scan(&id); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Could be missing OR already non-pending; distinguish for a
			// clearer error.
			var status string
			if err2 := tx.QueryRow(ctx,
				`SELECT status FROM beverage_addition_requests WHERE id = $1;`,
				requestID).Scan(&status); err2 != nil {
				if errors.Is(err2, pgx.ErrNoRows) {
					return domain.ErrNotFound
				}
				return fmt.Errorf("RejectBeverageRequest status probe: %w", err2)
			}
			return fmt.Errorf("RejectBeverageRequest: %w (status=%s)", domain.ErrConflict, status)
		}
		return fmt.Errorf("RejectBeverageRequest: %w", err)
	}

	notesPtr := &notes
	if err := insertModerationLog(ctx, tx,
		reviewerID,
		"beverage_request", requestID,
		"reject",
		notesPtr,
		nil,
	); err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("RejectBeverageRequest commit: %w", err)
	}
	return nil
}

// ============================================================================
// Check-in moderation
// ============================================================================

// ModerateCheckin soft-deletes a check-in regardless of owner, attributing
// the action to the moderator. Writes a moderation_log row in the same
// transaction so the structured slog line is mirrored to a queryable
// audit table. `notes` is optional — pass nil to omit.
func (r *AdminRepo) ModerateCheckin(ctx context.Context, checkinID, moderatorID string, notes *string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("ModerateCheckin begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const q = `
UPDATE check_ins SET deleted_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, checkinID).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("ModerateCheckin: %w", err)
	}

	if err := insertModerationLog(ctx, tx,
		moderatorID,
		"check_in", checkinID,
		"soft_delete",
		notes,
		nil,
	); err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("ModerateCheckin commit: %w", err)
	}
	return nil
}

// ============================================================================
// User admin
// ============================================================================

// AdminUserRow is the list shape for GET /v1/admin/users.
type AdminUserRow struct {
	ID              string     `json:"id"`
	Username        string     `json:"username"`
	DisplayUsername string     `json:"display_username"`
	Email           string     `json:"email"`
	EmailVerified   bool       `json:"email_verified"`
	Role            string     `json:"role"`
	CreatedAt       time.Time  `json:"created_at"`
	DeletedAt       *time.Time `json:"deleted_at"`
}

// ListUsersParams supports cursor pagination on (created_at, id) plus
// filters for role and "include soft-deleted".
//
// Stage 8 (admin catalog CRUD): three exact-match fields short-circuit
// the cursor to a single indexed lookup. UsernameExact and EmailExact
// case-fold to LOWER() to hit idx_users_username_live /
// idx_users_email_live; IDExact walks the PK. When any of the three is
// set, the rest of the filter set is ignored and at most one row comes
// back (has_more = false at the handler).
type ListUsersParams struct {
	RoleFilter     string
	IncludeDeleted bool
	UsernameExact  *string
	EmailExact     *string
	IDExact        *string
	CursorTs       *time.Time
	CursorID       *string
	Limit          int
}

// ListUsers pages through users; soft-deleted users are excluded by
// default. Caller must already have moderator+ role.
func (r *AdminRepo) ListUsers(ctx context.Context, p ListUsersParams) ([]AdminUserRow, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}

	// Fast paths: any exact-match field collapses to a single PK / unique
	// hit. We honor IncludeDeleted on the fast path too so an admin
	// looking up a tombstoned account by id can still find it.
	if p.IDExact != nil && *p.IDExact != "" {
		return r.listUsersExact(ctx, "id = $1::uuid", *p.IDExact, p.IncludeDeleted)
	}
	if p.UsernameExact != nil && *p.UsernameExact != "" {
		// LOWER(username) hits idx_users_username_live (case-insensitive
		// unique partial index from migration 006).
		return r.listUsersExact(ctx, "LOWER(username) = LOWER($1)", *p.UsernameExact, p.IncludeDeleted)
	}
	if p.EmailExact != nil && *p.EmailExact != "" {
		return r.listUsersExact(ctx, "LOWER(email) = LOWER($1)", *p.EmailExact, p.IncludeDeleted)
	}

	const q = `
SELECT id, username, display_username, email, email_verified,
       role::text, created_at, deleted_at
FROM users
WHERE ($1::boolean OR deleted_at IS NULL)
  AND ($2::text = '' OR role::text = $2)
  AND ($3::timestamptz IS NULL OR (created_at, id) < ($3::timestamptz, $4::uuid))
ORDER BY created_at DESC, id DESC
LIMIT $5;`
	rows, err := r.db.Query(ctx, q, p.IncludeDeleted, p.RoleFilter, p.CursorTs, p.CursorID, p.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("AdminRepo.ListUsers: %w", err)
	}
	defer rows.Close()
	out := make([]AdminUserRow, 0, p.Limit+1)
	for rows.Next() {
		var u AdminUserRow
		if err := rows.Scan(&u.ID, &u.Username, &u.DisplayUsername,
			&u.Email, &u.EmailVerified, &u.Role, &u.CreatedAt, &u.DeletedAt); err != nil {
			return nil, fmt.Errorf("AdminRepo.ListUsers scan: %w", err)
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// listUsersExact is the shared implementation for the three exact-match
// fast paths. `whereExpr` is interpolated as the WHERE predicate (always
// a literal column reference + $1, never user-controlled). The arg is
// always $1; includeDeleted toggles the deleted_at filter.
func (r *AdminRepo) listUsersExact(ctx context.Context, whereExpr, arg string, includeDeleted bool) ([]AdminUserRow, error) {
	live := ""
	if !includeDeleted {
		live = " AND deleted_at IS NULL"
	}
	q := `
SELECT id, username, display_username, email, email_verified,
       role::text, created_at, deleted_at
FROM users
WHERE ` + whereExpr + live + `
LIMIT 1;`
	rows, err := r.db.Query(ctx, q, arg)
	if err != nil {
		return nil, fmt.Errorf("AdminRepo.ListUsers exact: %w", err)
	}
	defer rows.Close()
	out := make([]AdminUserRow, 0, 1)
	for rows.Next() {
		var u AdminUserRow
		if err := rows.Scan(&u.ID, &u.Username, &u.DisplayUsername,
			&u.Email, &u.EmailVerified, &u.Role, &u.CreatedAt, &u.DeletedAt); err != nil {
			return nil, fmt.Errorf("AdminRepo.ListUsers exact scan: %w", err)
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// UpdateUserRole rewrites the role column. Validates against the enum.
// Writes a moderation_log row in the same transaction with metadata
// {"old_role","new_role"} so the audit UI can show before/after.
func (r *AdminRepo) UpdateUserRole(ctx context.Context, userID, moderatorID string, role domain.UserRole) error {
	if !role.Valid() {
		return fmt.Errorf("UpdateUserRole: %w (role=%s)", domain.ErrValidation, role)
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("UpdateUserRole begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Capture old role for the audit before the rewrite.
	var oldRole string
	if err := tx.QueryRow(ctx,
		`SELECT role::text FROM users WHERE id = $1 AND deleted_at IS NULL;`,
		userID,
	).Scan(&oldRole); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("UpdateUserRole lookup: %w", err)
	}

	const q = `UPDATE users SET role = $2::user_role WHERE id = $1 AND deleted_at IS NULL;`
	ct, err := tx.Exec(ctx, q, userID, string(role))
	if err != nil {
		return fmt.Errorf("UpdateUserRole: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}

	if err := insertModerationLog(ctx, tx,
		moderatorID,
		"user", userID,
		"role_change",
		nil,
		map[string]any{"old_role": oldRole, "new_role": string(role)},
	); err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("UpdateUserRole commit: %w", err)
	}
	return nil
}

// SuspendUser is admin-initiated soft-delete: marks deleted_at and starts
// the 30-day username hold. Returns ErrNotFound when the user doesn't
// exist or was already suspended. Writes a moderation_log row in the
// same transaction with metadata {"username_release_at": "..."} for
// post-hoc audit.
func (r *AdminRepo) SuspendUser(ctx context.Context, userID, moderatorID string) error {
	// Role is reset to 'user' BEFORE soft-deleting so that future un-suspend
	// tooling (post-MVP) cannot auto-restore admin/moderator privileges. The
	// deleted_at + username_release_at pair handles the 30-day username hold
	// per SPEC §3.4; the role reset is the security half of the same action.
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("SuspendUser begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const q = `
UPDATE users SET
  deleted_at = NOW(),
  username_release_at = NOW() + INTERVAL '30 days',
  role = 'user'::user_role
WHERE id = $1 AND deleted_at IS NULL
RETURNING username_release_at;`
	var releaseAt time.Time
	if err := tx.QueryRow(ctx, q, userID).Scan(&releaseAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("SuspendUser: %w", err)
	}

	if err := insertModerationLog(ctx, tx,
		moderatorID,
		"user", userID,
		"suspend",
		nil,
		map[string]any{"username_release_at": releaseAt.UTC().Format(time.RFC3339)},
	); err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("SuspendUser commit: %w", err)
	}
	return nil
}

// GetUserRole returns the role for a live user. Used by /v1/users/me.
func (r *UserRepo) GetUserRole(ctx context.Context, userID string) (domain.UserRole, error) {
	const q = `SELECT role::text FROM users WHERE id = $1 AND deleted_at IS NULL;`
	var s string
	if err := r.db.QueryRow(ctx, q, userID).Scan(&s); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", domain.ErrNotFound
		}
		return "", fmt.Errorf("GetUserRole: %w", err)
	}
	role := domain.UserRole(s)
	if !role.Valid() {
		return "", fmt.Errorf("GetUserRole: unknown role %q", s)
	}
	return role, nil
}
