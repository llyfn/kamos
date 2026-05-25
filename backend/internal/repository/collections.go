package repository

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

type CollectionRepo struct{ db *pgxpool.Pool }

// List returns the user's live collections with entry counts.
//
// Stage 5 (PERF-016): entry_count comes from the denormalized column
// on collections (migration 011). The previous query LEFT JOINed
// collection_entries and GROUP BYed c.id per row — that's O(rows) for
// the JOIN scan even on the common case of a user with <20
// collections, where the denormalized column is a single read.
func (r *CollectionRepo) List(ctx context.Context, userID string) ([]domain.Collection, error) {
	const q = `
SELECT c.id, c.user_id, c.name, c.visibility::text, c.created_at, c.updated_at,
       c.entry_count
FROM collections c
WHERE c.user_id = $1 AND c.deleted_at IS NULL
ORDER BY c.created_at ASC;`
	rows, err := r.db.Query(ctx, q, userID)
	if err != nil {
		return nil, fmt.Errorf("CollectionRepo.List: %w", err)
	}
	defer rows.Close()
	var out []domain.Collection
	for rows.Next() {
		var c domain.Collection
		if err := rows.Scan(&c.ID, &c.OwnerID, &c.Name, &c.Visibility, &c.CreatedAt, &c.UpdatedAt, &c.EntryCount); err != nil {
			return nil, fmt.Errorf("CollectionRepo.List scan: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *CollectionRepo) Create(ctx context.Context, userID, name string) (*domain.Collection, error) {
	const q = `
INSERT INTO collections (user_id, name) VALUES ($1, $2)
RETURNING id, user_id, name, visibility::text, created_at, updated_at;`
	var c domain.Collection
	if err := r.db.QueryRow(ctx, q, userID, name).Scan(&c.ID, &c.OwnerID, &c.Name, &c.Visibility, &c.CreatedAt, &c.UpdatedAt); err != nil {
		if strings.Contains(err.Error(), "idx_collections_user_name_live") {
			return nil, domain.ErrConflict
		}
		return nil, fmt.Errorf("CollectionRepo.Create: %w", err)
	}
	return &c, nil
}

// Get returns a single live collection by id, regardless of owner. The
// caller (handler) is responsible for the visibility decision: owners may
// read any of their own rows; non-owners may only read rows where
// `visibility = 'public'`. Returns ErrNotFound for soft-deleted or
// non-existent rows.
//
// widened this function: it was previously owner-scoped at the
// SQL level (WHERE c.user_id = $2), which caused a 404 on the
// discover-tab → detail-screen route for non-owners on public
// collections. Ownership-scoping moved up to the handler so the same
// row can be served to its owner OR to anyone when public.
func (r *CollectionRepo) Get(ctx context.Context, id string) (*domain.Collection, error) {
	const q = `
SELECT c.id, c.user_id, c.name, c.visibility::text, c.created_at, c.updated_at,
       c.entry_count
FROM collections c
WHERE c.id = $1 AND c.deleted_at IS NULL;`
	var c domain.Collection
	if err := r.db.QueryRow(ctx, q, id).Scan(&c.ID, &c.OwnerID, &c.Name, &c.Visibility, &c.CreatedAt, &c.UpdatedAt, &c.EntryCount); err != nil {
		return nil, wrapNoRows("CollectionRepo.Get", err)
	}
	return &c, nil
}

// UpdateCollectionParams carries the fields that PATCH /v1/collections/{id}
// can mutate. Both pointers nil means no-op (the handler rejects that at
// validate time).
type UpdateCollectionParams struct {
	Name       *string
	Visibility *string
}

// Update applies a partial update (name and/or visibility) to a collection
// the caller owns. Returns the refreshed row. ErrNotFound when the row
// doesn't exist / isn't owned by userID. ErrConflict on the name-uniqueness
// index. The entry_count is recomputed via subquery so callers don't have
// to.
func (r *CollectionRepo) Update(ctx context.Context, userID, id string, p UpdateCollectionParams) (*domain.Collection, error) {
	if p.Name == nil && p.Visibility == nil {
		// No-op: still enforce ownership-scoped read here (Get is now
		// owner-agnostic, so we use the owner-scoped GetOwned).
		return r.GetOwned(ctx, userID, id)
	}
	// COALESCE keeps the existing value when the pointer is nil. The cast on
	// $4 lets us pass either a 'private'|'public' literal or NULL — Postgres
	// won't deduce the type otherwise.
	const q = `
UPDATE collections SET
  name       = COALESCE($3, name),
  visibility = COALESCE($4::collection_visibility, visibility)
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id, user_id, name, visibility::text, created_at, updated_at, entry_count;`
	var c domain.Collection
	if err := r.db.QueryRow(ctx, q, id, userID, p.Name, p.Visibility).Scan(
		&c.ID, &c.OwnerID, &c.Name, &c.Visibility, &c.CreatedAt, &c.UpdatedAt, &c.EntryCount,
	); err != nil {
		if strings.Contains(err.Error(), "idx_collections_user_name_live") {
			return nil, domain.ErrConflict
		}
		return nil, wrapNoRows("CollectionRepo.Update", err)
	}
	return &c, nil
}

// GetOwned is the owner-scoped read used by paths that need the
// "must-be-mine" invariant baked in at the SQL level (PATCH no-op
// short-circuit, internal callers). New code should prefer Get + an
// explicit handler-side visibility decision.
func (r *CollectionRepo) GetOwned(ctx context.Context, userID, id string) (*domain.Collection, error) {
	const q = `
SELECT c.id, c.user_id, c.name, c.visibility::text, c.created_at, c.updated_at,
       c.entry_count
FROM collections c
WHERE c.id = $1 AND c.user_id = $2 AND c.deleted_at IS NULL;`
	var c domain.Collection
	if err := r.db.QueryRow(ctx, q, id, userID).Scan(&c.ID, &c.OwnerID, &c.Name, &c.Visibility, &c.CreatedAt, &c.UpdatedAt, &c.EntryCount); err != nil {
		return nil, wrapNoRows("CollectionRepo.GetOwned", err)
	}
	return &c, nil
}

// Rename is retained as a backwards-compatible thin wrapper around Update so
// the existing handler signatures keep working until the next refactor pass.
// New code should call Update directly.
func (r *CollectionRepo) Rename(ctx context.Context, userID, id, name string) (*domain.Collection, error) {
	return r.Update(ctx, userID, id, UpdateCollectionParams{Name: &name})
}

// ListByUser pages a single owner's collections, visibility-gated by
// the viewer's relationship to the owner.
//
//   - When `viewerID == ownerID` (viewer authed as the owner) the caller
//     sees every live collection regardless of visibility.
//   - Otherwise only `visibility = 'public'` rows are returned.
//
// The owner row is NOT joined — callers already resolved the username →
// id before invoking this; the page shape mirrors GET /v1/collections so
// the Flutter side can reuse Collection.fromJson without a
// CollectionWithOwner adapter. Cursor on (created_at, id) DESC.
func (r *CollectionRepo) ListByUser(
	ctx context.Context,
	ownerID string,
	viewerID string,
	cursorTs *time.Time,
	cursorID *string,
	limit int,
) ([]domain.Collection, error) {
	if limit <= 0 {
		limit = 20
	}
	const q = `
SELECT c.id, c.user_id, c.name, c.visibility::text, c.created_at, c.updated_at,
       c.entry_count
FROM collections c
WHERE c.user_id = $1
  AND c.deleted_at IS NULL
  AND ($2::boolean OR c.visibility = 'public')
  AND ($3::timestamptz IS NULL OR (c.created_at, c.id) < ($3::timestamptz, $4::uuid))
ORDER BY c.created_at DESC, c.id DESC
LIMIT $5;`
	isOwner := viewerID != "" && viewerID == ownerID
	rows, err := r.db.Query(ctx, q, ownerID, isOwner, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("CollectionRepo.ListByUser: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Collection, 0, limit+1)
	for rows.Next() {
		var c domain.Collection
		if err := rows.Scan(
			&c.ID, &c.OwnerID, &c.Name, &c.Visibility,
			&c.CreatedAt, &c.UpdatedAt, &c.EntryCount,
		); err != nil {
			return nil, fmt.Errorf("CollectionRepo.ListByUser scan: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// ListPublic pages through the discovery feed of public collections,
// joining the owner row for attribution. Cursor on (created_at, id),
// most-recent-first. Soft-deleted owners are filtered out — the owner
// JOIN is INNER, so a soft-deleted owner's public collection vanishes
// from discovery.
func (r *CollectionRepo) ListPublic(
	ctx context.Context,
	cursorTs *time.Time,
	cursorID *string,
	limit int,
) ([]domain.CollectionWithOwner, error) {
	if limit <= 0 {
		limit = 20
	}
	const q = `
SELECT
  c.id, c.user_id, c.name, c.visibility::text, c.created_at, c.updated_at,
  c.entry_count,
  u.id, u.username, u.display_username, u.display_name, u.avatar_url
FROM collections c
JOIN users u ON u.id = c.user_id AND u.deleted_at IS NULL
WHERE c.visibility = 'public'
  AND c.deleted_at IS NULL
  AND ($1::timestamptz IS NULL OR (c.created_at, c.id) < ($1::timestamptz, $2::uuid))
ORDER BY c.created_at DESC, c.id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, q, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("CollectionRepo.ListPublic: %w", err)
	}
	defer rows.Close()
	out := make([]domain.CollectionWithOwner, 0, limit+1)
	for rows.Next() {
		var row domain.CollectionWithOwner
		if err := rows.Scan(
			&row.ID, &row.OwnerID, &row.Name, &row.Visibility,
			&row.CreatedAt, &row.UpdatedAt, &row.EntryCount,
			&row.Owner.ID, &row.Owner.Username, &row.Owner.DisplayUsername,
			&row.Owner.DisplayName, &row.Owner.AvatarURL,
		); err != nil {
			return nil, fmt.Errorf("CollectionRepo.ListPublic scan: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

func (r *CollectionRepo) SoftDelete(ctx context.Context, userID, id string) error {
	const q = `
UPDATE collections SET deleted_at = NOW()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := r.db.QueryRow(ctx, q, id, userID).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("CollectionRepo.SoftDelete: %w", err)
	}
	return nil
}

// Entries lists entries with the beverage join. Cursor: (added_at, beverage_id).
func (r *CollectionRepo) Entries(ctx context.Context, userID, collectionID string, cursor *time.Time, cursorBeverage *string, limit int) ([]domain.CollectionEntry, error) {
	const q = `
SELECT ce.beverage_id, ce.note, ce.added_at,
       b.name_i18n, b.category_slug, b.label_image_url,
       cat.name_i18n,
       br.id, br.name_i18n,` + breweryPrefectureSelectCols + `
FROM collection_entries ce
JOIN collections c ON c.id = ce.collection_id AND c.user_id = $1 AND c.deleted_at IS NULL
JOIN beverages b ON b.id = ce.beverage_id
JOIN breweries br ON br.id = b.brewery_id
JOIN beverage_categories cat ON cat.id = b.category_id` + breweryPrefectureJoinClause + `
WHERE ce.collection_id = $2
  AND ($3::timestamptz IS NULL OR (ce.added_at, ce.beverage_id) < ($3::timestamptz, $4::uuid))
ORDER BY ce.added_at DESC, ce.beverage_id DESC
LIMIT $5;`
	rows, err := r.db.Query(ctx, q, userID, collectionID, cursor, cursorBeverage, limit+1)
	if err != nil {
		return nil, fmt.Errorf("CollectionRepo.Entries: %w", err)
	}
	defer rows.Close()
	var out []domain.CollectionEntry
	for rows.Next() {
		var e domain.CollectionEntry
		var (
			bevID    string
			bevName  []byte
			bevSlug  string
			bevLabel *string
			catName  []byte
			brwID    string
			brwName  []byte
			brwPref  prefectureScan
		)
		prefArgs := brwPref.scanArgs()
		scanArgs := make([]any, 0, 9+len(prefArgs))
		scanArgs = append(scanArgs, &bevID, &e.Note, &e.AddedAt, &bevName, &bevSlug, &bevLabel, &catName, &brwID, &brwName)
		scanArgs = append(scanArgs, prefArgs...)
		if err := rows.Scan(scanArgs...); err != nil {
			return nil, fmt.Errorf("CollectionRepo.Entries scan: %w", err)
		}
		bn, _ := domain.I18nFromJSON(bevName)
		cn, _ := domain.I18nFromJSON(catName)
		brn, _ := domain.I18nFromJSON(brwName)
		e.Beverage = domain.BeverageRef{
			ID:            bevID,
			Name:          bn,
			Brewery:       domain.BreweryRef{ID: brwID, Name: brn, Prefecture: brwPref.toPrefecture()},
			Category:      domain.CategoryLabel{Slug: bevSlug, LabelI18n: cn},
			LabelImageURL: bevLabel,
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r *CollectionRepo) AddEntry(ctx context.Context, userID, collectionID, beverageID string, note *string) error {
	// Ownership check baked into the INSERT via subselect.
	const q = `
INSERT INTO collection_entries (collection_id, beverage_id, note)
SELECT $1, $2, $3
FROM collections c
WHERE c.id = $1 AND c.user_id = $4 AND c.deleted_at IS NULL
ON CONFLICT (collection_id, beverage_id) DO UPDATE
  SET note = EXCLUDED.note
RETURNING collection_id;`
	var got string
	if err := r.db.QueryRow(ctx, q, collectionID, beverageID, note, userID).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("CollectionRepo.AddEntry: %w", err)
	}
	return nil
}

func (r *CollectionRepo) UpdateEntry(ctx context.Context, userID, collectionID, beverageID string, note *string) error {
	const q = `
UPDATE collection_entries ce SET note = $3
FROM collections c
WHERE ce.collection_id = $1 AND ce.beverage_id = $2
  AND c.id = ce.collection_id AND c.user_id = $4 AND c.deleted_at IS NULL;`
	ct, err := r.db.Exec(ctx, q, collectionID, beverageID, note, userID)
	if err != nil {
		return fmt.Errorf("CollectionRepo.UpdateEntry: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *CollectionRepo) RemoveEntry(ctx context.Context, userID, collectionID, beverageID string) error {
	const q = `
DELETE FROM collection_entries ce
USING collections c
WHERE ce.collection_id = c.id
  AND c.id = $1 AND c.user_id = $3 AND c.deleted_at IS NULL
  AND ce.beverage_id = $2;`
	ct, err := r.db.Exec(ctx, q, collectionID, beverageID, userID)
	if err != nil {
		return fmt.Errorf("CollectionRepo.RemoveEntry: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}
