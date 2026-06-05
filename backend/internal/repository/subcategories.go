// subcategories.go — admin + public CRUD over beverage_subcategories.
//
// Slice C (migration 005). The public read path (/v1/subcategories) is
// read-only; the admin path mounted under /v1/admin/subcategories owns
// create / update / soft-delete / restore with an "in-use" guard so a
// subcategory still attached to a live beverage cannot be tombstoned.
//
// The handler bundles each mutation with a moderation_log row inside the
// supplied pgx.Tx, mirroring the beverages_admin / producers_admin
// pattern. Cache invalidation is the handler's job (the public list is
// cached per replica + Redis L2).

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

// SubcategoryRepo wraps the beverage_subcategories table.
type SubcategoryRepo struct{ db *pgxpool.Pool }

// AdminSubcategoryRow extends the public Subcategory with admin-only
// fields (deleted_at + a live-beverage count so the admin list page can
// surface "in use by N beverages" without an N+1 fetch).
type AdminSubcategoryRow struct {
	domain.Subcategory
	DeletedAt     *time.Time `json:"deleted_at"`
	BeverageCount int        `json:"beverage_count"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
}

// subcategorySelect projects everything the public response needs.
const subcategorySelect = `
SELECT sc.id, sc.category_id, sc.category_slug, sc.slug, sc.name_i18n, sc.sort_order
FROM beverage_subcategories sc`

// adminSubcategorySelect adds deleted_at, created_at, updated_at, and a
// correlated subquery for the live-beverage count. The subquery hits the
// partial idx_beverages_subcategory_id (WHERE deleted_at IS NULL) so the
// cost is sublinear in the catalog size.
const adminSubcategorySelect = `
SELECT sc.id, sc.category_id, sc.category_slug, sc.slug, sc.name_i18n, sc.sort_order,
       sc.deleted_at, sc.created_at, sc.updated_at,
       (SELECT COUNT(*)::int FROM beverages b
        WHERE b.subcategory_id = sc.id AND b.deleted_at IS NULL) AS beverage_count
FROM beverage_subcategories sc`

func scanSubcategory(row pgx.Row) (domain.Subcategory, error) {
	var s domain.Subcategory
	var nameJSON []byte
	if err := row.Scan(&s.ID, &s.CategoryID, &s.CategorySlug, &s.Slug, &nameJSON, &s.SortOrder); err != nil {
		return domain.Subcategory{}, err
	}
	s.Name, _ = domain.I18nFromJSON(nameJSON)
	return s, nil
}

func scanAdminSubcategory(row pgx.Row) (AdminSubcategoryRow, error) {
	var out AdminSubcategoryRow
	var nameJSON []byte
	if err := row.Scan(
		&out.ID, &out.CategoryID, &out.CategorySlug, &out.Slug, &nameJSON, &out.SortOrder,
		&out.DeletedAt, &out.CreatedAt, &out.UpdatedAt, &out.BeverageCount,
	); err != nil {
		return AdminSubcategoryRow{}, err
	}
	out.Name, _ = domain.I18nFromJSON(nameJSON)
	return out, nil
}

// List returns active subcategories, optionally filtered by category
// slug. Sort order is (category_slug, sort_order, slug) so the dropdown
// in the admin beverage form renders in a predictable order regardless
// of insertion timing.
func (r *SubcategoryRepo) List(ctx context.Context, categorySlug *string) ([]domain.Subcategory, error) {
	const sql = subcategorySelect + `
WHERE sc.deleted_at IS NULL
  AND ($1::text IS NULL OR sc.category_slug = $1)
ORDER BY sc.category_slug, sc.sort_order, sc.slug;`
	rows, err := r.db.Query(ctx, sql, categorySlug)
	if err != nil {
		return nil, fmt.Errorf("SubcategoryRepo.List: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Subcategory, 0)
	for rows.Next() {
		s, err := scanSubcategory(rows)
		if err != nil {
			return nil, fmt.Errorf("SubcategoryRepo.List scan: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// AdminList returns every subcategory (incl. soft-deleted) with usage
// counts. Optional filter by category slug.
func (r *SubcategoryRepo) AdminList(ctx context.Context, categorySlug *string, includeDeleted bool) ([]AdminSubcategoryRow, error) {
	const sql = adminSubcategorySelect + `
WHERE ($1::boolean OR sc.deleted_at IS NULL)
  AND ($2::text IS NULL OR sc.category_slug = $2)
ORDER BY sc.category_slug, sc.sort_order, sc.slug;`
	rows, err := r.db.Query(ctx, sql, includeDeleted, categorySlug)
	if err != nil {
		return nil, fmt.Errorf("SubcategoryRepo.AdminList: %w", err)
	}
	defer rows.Close()
	out := make([]AdminSubcategoryRow, 0)
	for rows.Next() {
		s, err := scanAdminSubcategory(rows)
		if err != nil {
			return nil, fmt.Errorf("SubcategoryRepo.AdminList scan: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// Get returns one subcategory by id (including tombstones — the admin
// edit/restore flow needs to see them). Returns domain.ErrNotFound on
// unknown id.
func (r *SubcategoryRepo) Get(ctx context.Context, id string) (AdminSubcategoryRow, error) {
	const sql = adminSubcategorySelect + ` WHERE sc.id = $1::uuid LIMIT 1;`
	row := r.db.QueryRow(ctx, sql, id)
	s, err := scanAdminSubcategory(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminSubcategoryRow{}, domain.ErrNotFound
		}
		return AdminSubcategoryRow{}, fmt.Errorf("SubcategoryRepo.Get: %w", err)
	}
	return s, nil
}

// SubcategoryCreateInput is the validated payload for Create. Slug is a
// short lowercase identifier (the DB CHECK enforces `^[a-z0-9_]{1,64}$`);
// the trigger syncs category_slug from category_id.
type SubcategoryCreateInput struct {
	CategoryID string
	Slug       string
	Name       domain.I18nText
	SortOrder  int16
}

// Create inserts a new subcategory row inside the supplied tx.
func (r *SubcategoryRepo) Create(ctx context.Context, tx pgx.Tx, in SubcategoryCreateInput) (AdminSubcategoryRow, error) {
	nameJSON, err := jsonMarshalI18n(in.Name)
	if err != nil {
		return AdminSubcategoryRow{}, err
	}
	const ins = `
INSERT INTO beverage_subcategories (category_id, category_slug, slug, name_i18n, sort_order)
VALUES ($1::uuid, '', $2, $3::jsonb, $4)
RETURNING id;`
	// category_slug placeholder — the BEFORE INSERT trigger overwrites it
	// from beverage_categories(category_id).slug. The empty string is
	// rewritten before the row hits the CHECK; we pass any value here
	// (an empty string is fine because the trigger fires BEFORE the CHECK
	// validates the column). The CHECK constraint enforces membership in
	// the allowed list AFTER the trigger runs.
	var id string
	if err := tx.QueryRow(ctx, ins, in.CategoryID, in.Slug, string(nameJSON), in.SortOrder).Scan(&id); err != nil {
		return AdminSubcategoryRow{}, fmt.Errorf("SubcategoryRepo.Create: %w", err)
	}
	return r.getInTx(ctx, tx, id)
}

// SubcategoryUpdateInput carries partial-update fields. Slug + Name +
// SortOrder may be supplied independently. CategoryID changes are NOT
// supported here (moving a subcategory across categories would orphan
// every beverage referencing it; the admin should soft-delete + create
// a new one instead).
type SubcategoryUpdateInput struct {
	Slug      *string
	Name      *domain.I18nText
	SortOrder *int16
}

// Update applies a partial change and returns the updated row.
func (r *SubcategoryRepo) Update(ctx context.Context, tx pgx.Tx, id string, in SubcategoryUpdateInput) (AdminSubcategoryRow, error) {
	var (
		sets []string
		args []any
	)
	add := func(col string, v any) {
		args = append(args, v)
		sets = append(sets, fmt.Sprintf("%s = $%d", col, len(args)))
	}
	if in.Slug != nil {
		add("slug", *in.Slug)
	}
	if in.Name != nil {
		nameJSON, err := jsonMarshalI18n(*in.Name)
		if err != nil {
			return AdminSubcategoryRow{}, err
		}
		add("name_i18n", string(nameJSON))
	}
	if in.SortOrder != nil {
		add("sort_order", *in.SortOrder)
	}
	if len(sets) == 0 {
		// No-op: return the row unchanged.
		return r.getInTx(ctx, tx, id)
	}
	args = append(args, id)
	sql := fmt.Sprintf(`
UPDATE beverage_subcategories SET %s
WHERE id = $%d AND deleted_at IS NULL
RETURNING id;`, strings.Join(sets, ", "), len(args))
	var updatedID string
	if err := tx.QueryRow(ctx, sql, args...).Scan(&updatedID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminSubcategoryRow{}, domain.ErrNotFound
		}
		return AdminSubcategoryRow{}, fmt.Errorf("SubcategoryRepo.Update: %w", err)
	}
	return r.getInTx(ctx, tx, updatedID)
}

// SoftDelete tombstones the row. Returns ErrInUse if any live beverage
// (deleted_at IS NULL) still references it — the FK is ON DELETE SET NULL
// at the DB layer (so a hard delete wouldn't cascade-destroy beverages)
// but the admin "delete" is a soft-delete and we don't want to silently
// orphan live entries. The pre-check uses the partial index for speed.
func (r *SubcategoryRepo) SoftDelete(ctx context.Context, tx pgx.Tx, id string) error {
	var liveCount int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*)::int FROM beverages WHERE subcategory_id = $1::uuid AND deleted_at IS NULL;`,
		id,
	).Scan(&liveCount); err != nil {
		return fmt.Errorf("SubcategoryRepo.SoftDelete preflight: %w", err)
	}
	if liveCount > 0 {
		return fmt.Errorf("%w: subcategory still referenced by %d beverage(s)", domain.ErrInUse, liveCount)
	}
	const q = `
UPDATE beverage_subcategories SET deleted_at = NOW()
WHERE id = $1::uuid AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("SubcategoryRepo.SoftDelete: %w", err)
	}
	return nil
}

// Restore clears deleted_at on a tombstoned subcategory.
func (r *SubcategoryRepo) Restore(ctx context.Context, tx pgx.Tx, id string) error {
	const q = `
UPDATE beverage_subcategories SET deleted_at = NULL
WHERE id = $1::uuid AND deleted_at IS NOT NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("SubcategoryRepo.Restore: %w", err)
	}
	return nil
}

// VerifyForCategory returns nil when the supplied subcategory id exists,
// is not soft-deleted, and belongs to the supplied category_id. Used by
// the admin beverage handler to validate that the subcategory ref the
// client sent is internally consistent (no cross-category links).
//
// Errors:
//   - domain.ErrNotFound: subcategory id doesn't exist or is soft-deleted.
//   - domain.ErrValidation (wrapped): the row exists but its category_id
//     differs from the supplied beverage category — 422 with the wrapped
//     message.
func (r *SubcategoryRepo) VerifyForCategory(ctx context.Context, subcategoryID, categoryID string) error {
	var rowCategoryID string
	const q = `SELECT category_id::text FROM beverage_subcategories WHERE id = $1::uuid AND deleted_at IS NULL;`
	if err := r.db.QueryRow(ctx, q, subcategoryID).Scan(&rowCategoryID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("SubcategoryRepo.VerifyForCategory: %w", err)
	}
	if rowCategoryID != categoryID {
		return fmt.Errorf("%w: subcategory belongs to a different category", domain.ErrValidation)
	}
	return nil
}

// getInTx reads a row by id inside the supplied tx so the caller sees
// its own UPDATE/INSERT result.
func (r *SubcategoryRepo) getInTx(ctx context.Context, tx pgx.Tx, id string) (AdminSubcategoryRow, error) {
	const sql = adminSubcategorySelect + ` WHERE sc.id = $1::uuid LIMIT 1;`
	row := tx.QueryRow(ctx, sql, id)
	s, err := scanAdminSubcategory(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminSubcategoryRow{}, domain.ErrNotFound
		}
		return AdminSubcategoryRow{}, fmt.Errorf("SubcategoryRepo.getInTx: %w", err)
	}
	return s, nil
}
