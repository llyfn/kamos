// flavor_tags.go — admin CRUD over the flavor_tags taxonomy table.
//
// Slice C (migration 006 adds flavor_tags.deleted_at). The public
// /v1/flavor-tags endpoint stays cached + read-only via TaxonomyRepo;
// the admin CRUD here is mounted under /v1/admin/flavor-tags and goes
// through the same moderator-cookie + CSRF gate as the rest of /admin.
//
// Delete is soft (sets deleted_at) and is blocked by an in-use guard
// against check_in_flavor_tags so a tag with check-in history cannot
// be silently tombstoned.

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

// FlavorTagRepo wraps the flavor_tags table.
type FlavorTagRepo struct{ db *pgxpool.Pool }

// AdminFlavorTagRow is the admin-list shape: the public FlavorTag plus
// nullable deleted_at, timestamps, and a usage count from
// check_in_flavor_tags so the admin list can render "in use by N
// check-ins" without an N+1 fetch.
type AdminFlavorTagRow struct {
	domain.FlavorTag
	SortOrder  int16      `json:"sort_order"`
	DeletedAt  *time.Time `json:"deleted_at"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
	UsageCount int        `json:"usage_count"`
}

const adminFlavorTagSelect = `
SELECT ft.id, ft.slug, ft.dimension, ft.name_i18n, ft.sort_order,
       ft.deleted_at, ft.created_at, ft.updated_at,
       (SELECT COUNT(*)::int FROM check_in_flavor_tags cift
        WHERE cift.flavor_tag_id = ft.id) AS usage_count
FROM flavor_tags ft`

func scanAdminFlavorTag(row pgx.Row) (AdminFlavorTagRow, error) {
	var out AdminFlavorTagRow
	var nameJSON []byte
	if err := row.Scan(
		&out.ID, &out.Slug, &out.Dimension, &nameJSON, &out.SortOrder,
		&out.DeletedAt, &out.CreatedAt, &out.UpdatedAt, &out.UsageCount,
	); err != nil {
		return AdminFlavorTagRow{}, err
	}
	out.Name, _ = domain.I18nFromJSON(nameJSON)
	return out, nil
}

// AdminList returns every tag (incl. soft-deleted by default). Optional
// dimension filter narrows the result to one of the SPEC §4.3 buckets.
func (r *FlavorTagRepo) AdminList(ctx context.Context, dimension *string, includeDeleted bool) ([]AdminFlavorTagRow, error) {
	const sql = adminFlavorTagSelect + `
WHERE ($1::boolean OR ft.deleted_at IS NULL)
  AND ($2::text IS NULL OR ft.dimension = $2)
ORDER BY ft.dimension, ft.sort_order, ft.slug;`
	rows, err := r.db.Query(ctx, sql, includeDeleted, dimension)
	if err != nil {
		return nil, fmt.Errorf("FlavorTagRepo.AdminList: %w", err)
	}
	defer rows.Close()
	out := make([]AdminFlavorTagRow, 0)
	for rows.Next() {
		t, err := scanAdminFlavorTag(rows)
		if err != nil {
			return nil, fmt.Errorf("FlavorTagRepo.AdminList scan: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// Get returns one tag by id, including soft-deleted (admin restore).
func (r *FlavorTagRepo) Get(ctx context.Context, id string) (AdminFlavorTagRow, error) {
	const sql = adminFlavorTagSelect + ` WHERE ft.id = $1::uuid LIMIT 1;`
	row := r.db.QueryRow(ctx, sql, id)
	t, err := scanAdminFlavorTag(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminFlavorTagRow{}, domain.ErrNotFound
		}
		return AdminFlavorTagRow{}, fmt.Errorf("FlavorTagRepo.Get: %w", err)
	}
	return t, nil
}

// FlavorTagCreateInput is the validated payload for Create.
type FlavorTagCreateInput struct {
	Slug      string
	Dimension string
	Name      domain.I18nText
	SortOrder int16
}

// Create inserts a new flavor_tags row.
func (r *FlavorTagRepo) Create(ctx context.Context, tx pgx.Tx, in FlavorTagCreateInput) (AdminFlavorTagRow, error) {
	nameJSON, err := jsonMarshalI18n(in.Name)
	if err != nil {
		return AdminFlavorTagRow{}, err
	}
	const ins = `
INSERT INTO flavor_tags (slug, dimension, name_i18n, sort_order)
VALUES ($1, $2, $3::jsonb, $4)
RETURNING id;`
	var id string
	if err := tx.QueryRow(ctx, ins, in.Slug, in.Dimension, string(nameJSON), in.SortOrder).Scan(&id); err != nil {
		return AdminFlavorTagRow{}, fmt.Errorf("FlavorTagRepo.Create: %w", err)
	}
	return r.getInTx(ctx, tx, id)
}

// FlavorTagUpdateInput carries partial-update fields. Slug, Dimension,
// Name, and SortOrder may all be updated independently.
type FlavorTagUpdateInput struct {
	Slug      *string
	Dimension *string
	Name      *domain.I18nText
	SortOrder *int16
}

// Update applies a partial change and returns the updated row.
func (r *FlavorTagRepo) Update(ctx context.Context, tx pgx.Tx, id string, in FlavorTagUpdateInput) (AdminFlavorTagRow, error) {
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
	if in.Dimension != nil {
		add("dimension", *in.Dimension)
	}
	if in.Name != nil {
		nameJSON, err := jsonMarshalI18n(*in.Name)
		if err != nil {
			return AdminFlavorTagRow{}, err
		}
		add("name_i18n", string(nameJSON))
	}
	if in.SortOrder != nil {
		add("sort_order", *in.SortOrder)
	}
	if len(sets) == 0 {
		return r.getInTx(ctx, tx, id)
	}
	args = append(args, id)
	sql := fmt.Sprintf(`
UPDATE flavor_tags SET %s
WHERE id = $%d AND deleted_at IS NULL
RETURNING id;`, strings.Join(sets, ", "), len(args))
	var updatedID string
	if err := tx.QueryRow(ctx, sql, args...).Scan(&updatedID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminFlavorTagRow{}, domain.ErrNotFound
		}
		return AdminFlavorTagRow{}, fmt.Errorf("FlavorTagRepo.Update: %w", err)
	}
	return r.getInTx(ctx, tx, updatedID)
}

// SoftDelete tombstones the row. Returns ErrInUse when at least one
// check-in still references the tag (FK is ON DELETE RESTRICT so a hard
// delete would also fail). The pre-check is correlated against the
// composite PK on check_in_flavor_tags so the lookup is cheap.
//
// We also block when any beverage references the tag via beverages.flavor_profile
// (the legacy text[] column) — the FK is on the junction table, not on
// the array, so a tag present only in the array would orphan. The check
// uses the @> operator against `flavor_profile`; cost is O(catalog) but
// the catalog is small (hundreds at most).
func (r *FlavorTagRepo) SoftDelete(ctx context.Context, tx pgx.Tx, id string) error {
	// Resolve slug first so we can scan beverages.flavor_profile.
	var slug string
	if err := tx.QueryRow(ctx, `SELECT slug FROM flavor_tags WHERE id = $1::uuid;`, id).Scan(&slug); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("FlavorTagRepo.SoftDelete lookup: %w", err)
	}
	var checkInUsage int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*)::int FROM check_in_flavor_tags WHERE flavor_tag_id = $1::uuid;`,
		id,
	).Scan(&checkInUsage); err != nil {
		return fmt.Errorf("FlavorTagRepo.SoftDelete check-in preflight: %w", err)
	}
	if checkInUsage > 0 {
		return fmt.Errorf("%w: flavor tag still attached to %d check-in(s)", domain.ErrInUse, checkInUsage)
	}
	var beverageUsage int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*)::int FROM beverages WHERE deleted_at IS NULL AND flavor_profile @> ARRAY[$1]::text[];`,
		slug,
	).Scan(&beverageUsage); err != nil {
		return fmt.Errorf("FlavorTagRepo.SoftDelete beverage preflight: %w", err)
	}
	if beverageUsage > 0 {
		return fmt.Errorf("%w: flavor tag still listed on %d beverage(s)", domain.ErrInUse, beverageUsage)
	}
	const q = `
UPDATE flavor_tags SET deleted_at = NOW()
WHERE id = $1::uuid AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("FlavorTagRepo.SoftDelete: %w", err)
	}
	return nil
}

// Restore clears deleted_at on a tombstoned tag.
func (r *FlavorTagRepo) Restore(ctx context.Context, tx pgx.Tx, id string) error {
	const q = `
UPDATE flavor_tags SET deleted_at = NULL
WHERE id = $1::uuid AND deleted_at IS NOT NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("FlavorTagRepo.Restore: %w", err)
	}
	return nil
}

func (r *FlavorTagRepo) getInTx(ctx context.Context, tx pgx.Tx, id string) (AdminFlavorTagRow, error) {
	const sql = adminFlavorTagSelect + ` WHERE ft.id = $1::uuid LIMIT 1;`
	row := tx.QueryRow(ctx, sql, id)
	t, err := scanAdminFlavorTag(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AdminFlavorTagRow{}, domain.ErrNotFound
		}
		return AdminFlavorTagRow{}, fmt.Errorf("FlavorTagRepo.getInTx: %w", err)
	}
	return t, nil
}
