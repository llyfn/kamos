// beverages_admin.go — admin catalog write paths (Stage 8, migration 014).
//
// Direct admin CRUD for breweries + beverages plus admin-only listings
// that can include soft-deleted rows. Every method here is mounted under
// `/v1/admin` with `RoleAdmin` required in router.go. The mutators are
// designed to run inside the same `pgx.Tx` as `AdminRepo.LogAction` so the
// audit row commits atomically with the change — the handler owns the
// Begin/Commit and threads the *pgx.Tx into each method's `tx` parameter.
//
// Public read paths in beverages.go now filter `deleted_at IS NULL` on
// both `beverages` and `breweries`; the admin variants here either
// short-circuit to a specific row by id or honor an `IncludeDeleted`
// flag so the admin "trash" view can resurface tombstones for restore.
//
// FTS uses `websearch_to_tsquery('simple', $1)` to hit the partial GIN
// indexes built in migration 014. Plain text typed in the admin search
// box becomes a sensible tsquery (quoted phrases, OR operators) without
// the admin having to learn ::tsquery syntax.

package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/kamos/api/internal/domain"
)

// ============================================================================
// Brewery admin CRUD
// ============================================================================

// BreweryCreateInput is the validated input shape for AdminCreateBrewery.
// Pointers carry the "absent" signal — required fields are non-pointer.
type BreweryCreateInput struct {
	Name        domain.I18nText
	Prefecture  *string
	Region      *string
	FoundedYear *int
	Website     *string
	Description *domain.I18nText
}

// BreweryUpdateInput is the partial-update shape for AdminUpdateBrewery.
// Every field is a pointer; nil means "leave unchanged". Use a sentinel
// "" (empty pointer-to-zero-string) to clear a nullable column — the
// dynamic SET builder treats the pointer's presence as the signal.
type BreweryUpdateInput struct {
	Name        *domain.I18nText
	Prefecture  *string
	Region      *string
	FoundedYear *int
	Website     *string
	Description *domain.I18nText
}

// AdminBreweryListParams scopes the admin brewery search.
//
//   - Q (when set) drives FTS via websearch_to_tsquery('simple', $1)
//     against idx_breweries_name_tsv.
//   - IDExact short-circuits the cursor and FTS to a single PK lookup.
//   - IncludeDeleted = true surfaces soft-deleted rows (admin "trash").
type AdminBreweryListParams struct {
	Q              *string
	IDExact        *string
	IncludeDeleted bool
	CursorTs       *time.Time
	CursorID       *string
	Limit          int
}

// AdminBreweryRow is the admin-list row shape; mirrors domain.Brewery
// but includes the nullable DeletedAt timestamp so the UI can render
// the "tombstoned" badge.
type AdminBreweryRow struct {
	domain.Brewery
	DeletedAt *time.Time `json:"deleted_at"`
}

const adminBrewerySelect = `
SELECT b.id, b.name_i18n, b.prefecture, b.region, b.founded_year, b.website,
       b.description_i18n, b.created_at, b.beverage_count, b.deleted_at
FROM breweries b`

func scanAdminBrewery(row pgx.Row) (*AdminBreweryRow, error) {
	var out AdminBreweryRow
	var nameJSON, descJSON []byte
	var count int
	if err := row.Scan(
		&out.ID, &nameJSON, &out.Prefecture, &out.Region, &out.FoundedYear,
		&out.Website, &descJSON, &out.CreatedAt, &count, &out.DeletedAt,
	); err != nil {
		return nil, err
	}
	out.Name, _ = domain.I18nFromJSON(nameJSON)
	if len(descJSON) > 0 {
		d, _ := domain.I18nFromJSON(descJSON)
		out.Description = &d
	}
	out.BeverageCount = &count
	return &out, nil
}

// AdminList pages through breweries with optional FTS + id + soft-delete
// inclusion. IDExact short-circuits to a single-row lookup and ignores
// the cursor (admin "find by UUID").
func (r *BreweryRepo) AdminList(ctx context.Context, p AdminBreweryListParams) ([]AdminBreweryRow, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}

	// Fast path: exact id lookup. Skips FTS + cursor entirely.
	if p.IDExact != nil && *p.IDExact != "" {
		sql := adminBrewerySelect + ` WHERE b.id = $1::uuid`
		if !p.IncludeDeleted {
			sql += ` AND b.deleted_at IS NULL`
		}
		sql += ` LIMIT 1;`
		row := r.db.QueryRow(ctx, sql, *p.IDExact)
		hit, err := scanAdminBrewery(row)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, nil
			}
			return nil, fmt.Errorf("BreweryRepo.AdminList exact: %w", err)
		}
		return []AdminBreweryRow{*hit}, nil
	}

	// FTS uses websearch_to_tsquery so the admin can type quoted phrases
	// and OR/AND operators without learning tsquery syntax.
	sql := adminBrewerySelect + `
WHERE TRUE
  AND ($1::boolean OR b.deleted_at IS NULL)
  AND ($2::text IS NULL OR
       to_tsvector('simple',
         coalesce(b.name_i18n->>'en','') || ' ' ||
         coalesce(b.name_i18n->>'ja','') || ' ' ||
         coalesce(b.name_i18n->>'ko','')
       ) @@ websearch_to_tsquery('simple', $2))
  AND ($3::timestamptz IS NULL OR (b.created_at, b.id) < ($3::timestamptz, $4::uuid))
ORDER BY b.created_at DESC, b.id DESC
LIMIT $5;`

	rows, err := r.db.Query(ctx, sql, p.IncludeDeleted, p.Q, p.CursorTs, p.CursorID, p.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("BreweryRepo.AdminList: %w", err)
	}
	defer rows.Close()
	out := make([]AdminBreweryRow, 0, p.Limit+1)
	for rows.Next() {
		hit, err := scanAdminBrewery(rows)
		if err != nil {
			return nil, fmt.Errorf("BreweryRepo.AdminList scan: %w", err)
		}
		out = append(out, *hit)
	}
	return out, rows.Err()
}

// AdminDetail returns one brewery by id, including soft-deleted rows.
// Used by the admin GET endpoint which always exposes the deleted_at
// flag — the public Detail filters tombstones out.
func (r *BreweryRepo) AdminDetail(ctx context.Context, id string) (*AdminBreweryRow, error) {
	const sql = adminBrewerySelect + ` WHERE b.id = $1::uuid LIMIT 1;`
	row := r.db.QueryRow(ctx, sql, id)
	out, err := scanAdminBrewery(row)
	if err != nil {
		return nil, wrapNoRows("BreweryRepo.AdminDetail", err)
	}
	return out, nil
}

// Create inserts a brewery row and returns the freshly-scanned row.
// Caller is responsible for SanitizeText + range checks.
func (r *BreweryRepo) Create(ctx context.Context, in BreweryCreateInput) (*AdminBreweryRow, error) {
	nameJSON, err := jsonMarshalI18n(in.Name)
	if err != nil {
		return nil, err
	}
	descArg, err := i18nPointerToJSONArg(in.Description)
	if err != nil {
		return nil, err
	}

	const q = `
INSERT INTO breweries (name_i18n, prefecture, region, founded_year, website, description_i18n)
VALUES ($1::jsonb, $2, $3, $4, $5, $6::jsonb)
RETURNING id, name_i18n, prefecture, region, founded_year, website,
          description_i18n, created_at, beverage_count, deleted_at;`
	row := r.db.QueryRow(ctx, q,
		string(nameJSON), in.Prefecture, in.Region, in.FoundedYear, in.Website, descArg,
	)
	out, err := scanAdminBrewery(row)
	if err != nil {
		return nil, fmt.Errorf("BreweryRepo.Create: %w", err)
	}
	return out, nil
}

// Update applies a partial change to a brewery and returns the updated
// row. Only fields whose input pointers are non-nil are touched. The
// row must be live (deleted_at IS NULL) — restoring goes through Restore.
func (r *BreweryRepo) Update(ctx context.Context, id string, in BreweryUpdateInput) (*AdminBreweryRow, error) {
	// Dynamic SET builder. Keeps SQL readable; arg numbering is generated
	// alongside the column list so we never miss-index a placeholder.
	var (
		sets []string
		args []any
	)
	add := func(col string, val any) {
		args = append(args, val)
		sets = append(sets, fmt.Sprintf("%s = $%d", col, len(args)))
	}
	if in.Name != nil {
		nameJSON, err := jsonMarshalI18n(*in.Name)
		if err != nil {
			return nil, err
		}
		// pgx serializes string as text; the column accepts ::jsonb cast.
		add("name_i18n", string(nameJSON))
	}
	if in.Prefecture != nil {
		add("prefecture", *in.Prefecture)
	}
	if in.Region != nil {
		add("region", *in.Region)
	}
	if in.FoundedYear != nil {
		add("founded_year", *in.FoundedYear)
	}
	if in.Website != nil {
		add("website", *in.Website)
	}
	if in.Description != nil {
		// Empty I18n clears the description (NULL). Non-empty serializes
		// to JSONB.
		if in.Description.EN == "" && in.Description.JA == "" && in.Description.KO == "" {
			add("description_i18n", nil)
		} else {
			b, err := jsonMarshalI18n(*in.Description)
			if err != nil {
				return nil, err
			}
			add("description_i18n", string(b))
		}
	}
	if len(sets) == 0 {
		// No-op: return the existing row unchanged (handler can short-circuit).
		return r.AdminDetail(ctx, id)
	}
	args = append(args, id)
	sql := fmt.Sprintf(`
UPDATE breweries SET %s
WHERE id = $%d AND deleted_at IS NULL
RETURNING id, name_i18n, prefecture, region, founded_year, website,
          description_i18n, created_at, beverage_count, deleted_at;`,
		strings.Join(sets, ", "), len(args))

	row := r.db.QueryRow(ctx, sql, args...)
	out, err := scanAdminBrewery(row)
	if err != nil {
		return nil, wrapNoRows("BreweryRepo.Update", err)
	}
	return out, nil
}

// SoftDelete sets deleted_at = NOW() on the brewery row inside the supplied
// transaction (the handler bundles the moderation_log row into the same tx).
// Returns ErrBreweryHasLiveBeverages when at least one beverage still
// references this brewery with deleted_at IS NULL — the FK is RESTRICT, so
// leaving live children would orphan them from /v1/breweries lookups.
func (r *BreweryRepo) SoftDelete(ctx context.Context, tx pgx.Tx, id string) error {
	// Preflight: cheap exists-check on the live partial index. We hold a
	// row-level lock on the brewery for the duration of the tx so a
	// concurrent INSERT of a beverage referencing this brewery serializes
	// against this UPDATE's RETURNING (the trigger to bump beverage_count
	// would acquire the same row lock).
	var liveChild bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM beverages WHERE brewery_id = $1 AND deleted_at IS NULL LIMIT 1);`,
		id,
	).Scan(&liveChild); err != nil {
		return fmt.Errorf("BreweryRepo.SoftDelete preflight: %w", err)
	}
	if liveChild {
		return domain.ErrBreweryHasLiveBeverages
	}

	const q = `
UPDATE breweries SET deleted_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("BreweryRepo.SoftDelete: %w", err)
	}
	return nil
}

// Restore clears deleted_at on a tombstoned brewery row.
func (r *BreweryRepo) Restore(ctx context.Context, tx pgx.Tx, id string) error {
	const q = `
UPDATE breweries SET deleted_at = NULL
WHERE id = $1 AND deleted_at IS NOT NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("BreweryRepo.Restore: %w", err)
	}
	return nil
}

// ============================================================================
// Beverage admin CRUD
// ============================================================================

// BeverageCreateInput carries the validated payload for AdminCreateBeverage.
// CategoryID drives the category_slug via the existing
// sync_beverage_category_slug trigger — we do NOT set slug here.
type BeverageCreateInput struct {
	BreweryID      string
	CategoryID     string
	Name           domain.I18nText
	Subcategory    *domain.I18nText
	ABV            *float64
	PolishingRatio *int
	FlavorProfile  []string
	Prefecture     *string
	Region         *string
	Description    *domain.I18nText
	LabelImageURL  *string
}

// BeverageUpdateInput carries the partial-update fields.
type BeverageUpdateInput struct {
	BreweryID      *string
	CategoryID     *string
	Name           *domain.I18nText
	Subcategory    *domain.I18nText
	ABV            *float64
	PolishingRatio *int
	FlavorProfile  *[]string
	Prefecture     *string
	Region         *string
	Description    *domain.I18nText
	LabelImageURL  *string
}

// AdminBeverageListParams scopes the admin beverage search. Q drives
// the FTS index; the other filters narrow by category / brewery /
// id-exact / tombstone visibility.
type AdminBeverageListParams struct {
	Q              *string
	BreweryID      *string
	CategoryID     *string
	CategorySlug   *string
	IDExact        *string
	IncludeDeleted bool
	CursorTs       *time.Time
	CursorID       *string
	Limit          int
}

// AdminBeverageRow extends the public Beverage shape with deleted_at.
type AdminBeverageRow struct {
	domain.Beverage
	DeletedAt *time.Time `json:"deleted_at"`
}

// adminBeverageSelect is the full projection used by the admin GET +
// admin list, including subcategory_i18n + description_i18n so the
// edit modal can pre-fill every field, plus deleted_at for the tombstone
// badge.
const adminBeverageSelect = `
SELECT
  b.id,
  b.name_i18n,
  b.subcategory_i18n,
  b.category_slug,
  cat.name_i18n  AS category_name_i18n,
  cat.id         AS category_id,
  b.abv,
  b.polishing_ratio,
  b.prefecture,
  b.region,
  b.description_i18n,
  b.label_image_url,
  b.avg_rating,
  b.check_in_count,
  b.flavor_profile,
  b.created_at,
  br.id          AS brewery_id,
  br.name_i18n   AS brewery_name_i18n,
  br.region      AS brewery_region,
  b.deleted_at
FROM beverages b
JOIN breweries br ON br.id = b.brewery_id
JOIN beverage_categories cat ON cat.id = b.category_id`

func scanAdminBeverage(row pgx.Row) (*AdminBeverageRow, error) {
	var b beverageRow
	var deletedAt *time.Time
	err := row.Scan(
		&b.id,
		&b.nameJSON,
		&b.subcatJSON,
		&b.categorySlug,
		&b.categoryName,
		&b.categoryID,
		&b.abv,
		&b.polRatio,
		&b.prefecture,
		&b.region,
		&b.descJSON,
		&b.labelImgURL,
		&b.avgRating,
		&b.checkInCount,
		&b.flavorProfile,
		&b.createdAt,
		&b.breweryID,
		&b.breweryNameRaw,
		&b.breweryRegion,
		&deletedAt,
	)
	if err != nil {
		return nil, err
	}
	// Reuse the toBeverage projection so the admin and public schemas
	// stay in lock-step. The receiver doesn't touch db, so a zero-valued
	// BeverageRepo is fine.
	br := BeverageRepo{}
	d, err := br.toBeverage(&b)
	if err != nil {
		return nil, err
	}
	return &AdminBeverageRow{Beverage: d, DeletedAt: deletedAt}, nil
}

// AdminList pages through beverages for the admin tooling. Optional FTS,
// brewery/category filters, and IDExact short-circuit. Soft-deleted rows
// are hidden by default; set IncludeDeleted to surface them.
func (r *BeverageRepo) AdminList(ctx context.Context, p AdminBeverageListParams) ([]AdminBeverageRow, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}

	// Fast path: exact id lookup ignores cursor + filters.
	if p.IDExact != nil && *p.IDExact != "" {
		sql := adminBeverageSelect + ` WHERE b.id = $1::uuid`
		if !p.IncludeDeleted {
			sql += ` AND b.deleted_at IS NULL`
		}
		sql += ` LIMIT 1;`
		row := r.db.QueryRow(ctx, sql, *p.IDExact)
		hit, err := scanAdminBeverage(row)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, nil
			}
			return nil, fmt.Errorf("BeverageRepo.AdminList exact: %w", err)
		}
		return []AdminBeverageRow{*hit}, nil
	}

	sql := adminBeverageSelect + `
WHERE TRUE
  AND ($1::boolean OR b.deleted_at IS NULL)
  AND ($2::text IS NULL OR
       to_tsvector('simple',
         coalesce(b.name_i18n->>'en','') || ' ' ||
         coalesce(b.name_i18n->>'ja','') || ' ' ||
         coalesce(b.name_i18n->>'ko','')
       ) @@ websearch_to_tsquery('simple', $2))
  AND ($3::text IS NULL OR b.brewery_id = $3::uuid)
  AND ($4::text IS NULL OR b.category_id = $4::uuid)
  AND ($5::text IS NULL OR b.category_slug = $5)
  AND ($6::timestamptz IS NULL OR (b.created_at, b.id) < ($6::timestamptz, $7::uuid))
ORDER BY b.created_at DESC, b.id DESC
LIMIT $8;`

	rows, err := r.db.Query(ctx, sql,
		p.IncludeDeleted, p.Q, p.BreweryID, p.CategoryID, p.CategorySlug,
		p.CursorTs, p.CursorID, p.Limit+1,
	)
	if err != nil {
		return nil, fmt.Errorf("BeverageRepo.AdminList: %w", err)
	}
	defer rows.Close()
	out := make([]AdminBeverageRow, 0, p.Limit+1)
	for rows.Next() {
		hit, err := scanAdminBeverage(rows)
		if err != nil {
			return nil, fmt.Errorf("BeverageRepo.AdminList scan: %w", err)
		}
		out = append(out, *hit)
	}
	return out, rows.Err()
}

// AdminDetail returns one beverage by id, including soft-deleted rows.
func (r *BeverageRepo) AdminDetail(ctx context.Context, id string) (*AdminBeverageRow, error) {
	const sql = adminBeverageSelect + ` WHERE b.id = $1::uuid LIMIT 1;`
	row := r.db.QueryRow(ctx, sql, id)
	out, err := scanAdminBeverage(row)
	if err != nil {
		return nil, wrapNoRows("BeverageRepo.AdminDetail", err)
	}
	return out, nil
}

// Create inserts a beverage row inside the supplied tx (so the handler can
// commit it together with the moderation_log audit row). category_slug is
// resolved by the existing sync_beverage_category_slug trigger.
func (r *BeverageRepo) Create(ctx context.Context, tx pgx.Tx, in BeverageCreateInput) (string, error) {
	nameJSON, err := jsonMarshalI18n(in.Name)
	if err != nil {
		return "", err
	}
	subArg, err := i18nPointerToJSONArg(in.Subcategory)
	if err != nil {
		return "", err
	}
	descArg, err := i18nPointerToJSONArg(in.Description)
	if err != nil {
		return "", err
	}

	// category_slug placeholder — the BEFORE INSERT trigger overwrites it
	// from beverage_categories(category_id).slug. Pass 'nihonshu' so the
	// row passes the CHECK before the trigger fires; the trigger then
	// rewrites it to the correct value.
	const q = `
INSERT INTO beverages (brewery_id, category_id, category_slug, name_i18n,
                       subcategory_i18n, abv, polishing_ratio, prefecture,
                       region, description_i18n, label_image_url, flavor_profile)
VALUES ($1::uuid, $2::uuid, 'nihonshu', $3::jsonb, $4::jsonb, $5, $6, $7,
        $8, $9::jsonb, $10, COALESCE($11, '{}'::text[]))
RETURNING id;`
	var id string
	if err := tx.QueryRow(ctx, q,
		in.BreweryID, in.CategoryID, string(nameJSON), subArg,
		in.ABV, in.PolishingRatio, in.Prefecture, in.Region,
		descArg, in.LabelImageURL, in.FlavorProfile,
	).Scan(&id); err != nil {
		return "", fmt.Errorf("BeverageRepo.Create: %w", err)
	}
	return id, nil
}

// Update applies a partial change inside the supplied tx and returns nothing
// (the handler re-fetches via AdminDetail to surface the canonical row).
// Rejects when the target row is soft-deleted — restore goes through Restore.
func (r *BeverageRepo) Update(ctx context.Context, tx pgx.Tx, id string, in BeverageUpdateInput) error {
	var (
		sets []string
		args []any
	)
	add := func(col string, val any) {
		args = append(args, val)
		sets = append(sets, fmt.Sprintf("%s = $%d", col, len(args)))
	}
	if in.BreweryID != nil {
		add("brewery_id", *in.BreweryID)
	}
	if in.CategoryID != nil {
		// category_slug is auto-synced by trg_beverages_sync_category_slug.
		add("category_id", *in.CategoryID)
	}
	if in.Name != nil {
		nameJSON, err := jsonMarshalI18n(*in.Name)
		if err != nil {
			return err
		}
		add("name_i18n", string(nameJSON))
	}
	if in.Subcategory != nil {
		if in.Subcategory.EN == "" && in.Subcategory.JA == "" && in.Subcategory.KO == "" {
			add("subcategory_i18n", nil)
		} else {
			b, err := jsonMarshalI18n(*in.Subcategory)
			if err != nil {
				return err
			}
			add("subcategory_i18n", string(b))
		}
	}
	if in.ABV != nil {
		add("abv", *in.ABV)
	}
	if in.PolishingRatio != nil {
		add("polishing_ratio", *in.PolishingRatio)
	}
	if in.FlavorProfile != nil {
		add("flavor_profile", *in.FlavorProfile)
	}
	if in.Prefecture != nil {
		add("prefecture", *in.Prefecture)
	}
	if in.Region != nil {
		add("region", *in.Region)
	}
	if in.Description != nil {
		if in.Description.EN == "" && in.Description.JA == "" && in.Description.KO == "" {
			add("description_i18n", nil)
		} else {
			b, err := jsonMarshalI18n(*in.Description)
			if err != nil {
				return err
			}
			add("description_i18n", string(b))
		}
	}
	if in.LabelImageURL != nil {
		add("label_image_url", *in.LabelImageURL)
	}
	if len(sets) == 0 {
		// No-op.
		return nil
	}
	args = append(args, id)
	sql := fmt.Sprintf(`
UPDATE beverages SET %s
WHERE id = $%d AND deleted_at IS NULL
RETURNING id;`, strings.Join(sets, ", "), len(args))

	var got string
	if err := tx.QueryRow(ctx, sql, args...).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("BeverageRepo.Update: %w", err)
	}
	return nil
}

// SoftDelete sets deleted_at = NOW() on a beverage. No preflight — a
// beverage's children (check_ins, collection_entries) keep referencing
// the row by id since the FKs are RESTRICT and the row isn't actually
// deleted.
func (r *BeverageRepo) SoftDelete(ctx context.Context, tx pgx.Tx, id string) error {
	const q = `
UPDATE beverages SET deleted_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("BeverageRepo.SoftDelete: %w", err)
	}
	return nil
}

// Restore clears deleted_at on a tombstoned beverage.
func (r *BeverageRepo) Restore(ctx context.Context, tx pgx.Tx, id string) error {
	const q = `
UPDATE beverages SET deleted_at = NULL
WHERE id = $1 AND deleted_at IS NOT NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("BeverageRepo.Restore: %w", err)
	}
	return nil
}

// ============================================================================
// Helpers
// ============================================================================

// i18nPointerToJSONArg serializes an optional I18nText for a `$N::jsonb`
// placeholder. nil pointer or all-empty fields → nil (SQL NULL); otherwise
// the JSON-encoded blob. We pass *string because pgx serializes nil-string
// and empty-string both as text NULL, but an empty string would hit the
// jsonb cast and raise "invalid input syntax for type json".
func i18nPointerToJSONArg(t *domain.I18nText) (*string, error) {
	if t == nil {
		return nil, nil
	}
	if t.EN == "" && t.JA == "" && t.KO == "" {
		return nil, nil
	}
	b, err := json.Marshal(*t)
	if err != nil {
		return nil, fmt.Errorf("i18nPointerToJSONArg: %w", err)
	}
	s := string(b)
	return &s, nil
}
