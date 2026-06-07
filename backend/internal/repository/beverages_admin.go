// beverages_admin.go — admin catalog write paths.
//
// Admin CRUD for producers + beverages plus admin-only listings that can
// include soft-deleted rows. Mutators run inside the caller-supplied tx so
// the moderation_log row commits atomically with the change. Public read
// paths in beverages.go filter `deleted_at IS NULL` on both `beverages`
// and `producers`; admin variants either short-circuit by id or honor
// `IncludeDeleted` to surface tombstones for restore. Search uses the
// bigm-backed `search_text LIKE '%' || $N || '%'` pattern against
// idx_{beverages,producers}_search_bigm; the bound arg is lowered +
// LIKE-escaped at the repo layer via bigmLikeArg.

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
// Producer admin CRUD
// ============================================================================

// ProducerCreateInput is the validated input shape for AdminCreateProducer.
// Pointers carry the "absent" signal — required fields are non-pointer.
//
// Migration 016: locality is captured via PrefectureID (a UUID FK into
// `prefectures`) — the handler resolves a `prefecture_slug` to this id
// before calling Create. nil = no curated prefecture (column NULL).
type ProducerCreateInput struct {
	Name         domain.I18nText
	PrefectureID *string
	FoundedYear  *int
	Website      *string
	Description  *domain.I18nText
	// ImageURL is the public R2 URL the handler resolved from an
	// `image_upload_id` (photo_uploads.id with purpose='producer'). nil
	// means no image was supplied.
	ImageURL *string
}

// ProducerUpdateInput is the partial-update shape for AdminUpdateProducer.
// Every field is a pointer; nil means "leave unchanged". Use an empty
// string for a non-nil PrefectureID (ptr to "") to clear the column to
// NULL — the dynamic SET builder treats this as an explicit clear.
type ProducerUpdateInput struct {
	Name         *domain.I18nText
	PrefectureID *string
	FoundedYear  *int
	Website      *string
	Description  *domain.I18nText
	// ImageURL semantics mirror the other Update fields:
	//   * nil           → leave column unchanged.
	//   * ptr to ""     → clear image_url to NULL.
	//   * ptr to "https…" → set to that URL (resolved server-side from the
	//                     handler's image_upload_id).
	ImageURL *string
}

// AdminProducerListParams scopes the admin producer search.
//
//   - Q (when set) is a case-insensitive substring served by
//     idx_producers_search_bigm.
//   - IDExact short-circuits the cursor and Q to a single PK lookup.
//   - IncludeDeleted = true surfaces soft-deleted rows (admin "trash").
type AdminProducerListParams struct {
	Q              *string
	IDExact        *string
	IncludeDeleted bool
	CursorTs       *time.Time
	CursorID       *string
	Limit          int
}

// AdminProducerRow is the admin-list row shape; mirrors domain.Producer
// but includes the nullable DeletedAt timestamp so the UI can render
// the "tombstoned" badge.
type AdminProducerRow struct {
	domain.Producer
	DeletedAt *time.Time `json:"deleted_at"`
}

// adminProducerSelect projects every column the admin UI needs (i18n
// name + description, beverage_count, deleted_at) plus the nested
// prefecture/region chain via the LEFT JOIN. Migration 016 dropped
// the free-text `producers.prefecture` and `producers.region` columns
// in favor of `prefecture_id`.
const adminProducerSelect = `
SELECT b.id, b.name_i18n, b.founded_year, b.website,
       b.description_i18n, b.image_url, b.created_at, b.beverage_count, b.deleted_at,` + producerPrefectureSelectCols + `
FROM producers b` + producersPrefectureJoinClause

func scanAdminProducer(row pgx.Row) (*AdminProducerRow, error) {
	var out AdminProducerRow
	var nameJSON, descJSON []byte
	var count int
	var pref prefectureScan
	prefArgs := pref.scanArgs()
	args := make([]any, 0, 9+len(prefArgs))
	args = append(args,
		&out.ID, &nameJSON, &out.FoundedYear,
		&out.Website, &descJSON, &out.ImageURL, &out.CreatedAt, &count, &out.DeletedAt,
	)
	args = append(args, prefArgs...)
	if err := row.Scan(args...); err != nil {
		return nil, err
	}
	out.Name, _ = domain.I18nFromJSON(nameJSON)
	if len(descJSON) > 0 {
		d, _ := domain.I18nFromJSON(descJSON)
		out.Description = &d
	}
	out.BeverageCount = &count
	out.Prefecture = pref.toPrefecture()
	return &out, nil
}

// AdminList pages through producers with optional substring + id +
// soft-delete inclusion. IDExact short-circuits to a single-row lookup
// and ignores the cursor (admin "find by UUID").
func (r *ProducerRepo) AdminList(ctx context.Context, p AdminProducerListParams) ([]AdminProducerRow, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}

	if p.IDExact != nil && *p.IDExact != "" {
		sql := adminProducerSelect + ` WHERE b.id = $1::uuid`
		if !p.IncludeDeleted {
			sql += ` AND b.deleted_at IS NULL`
		}
		sql += ` LIMIT 1;`
		row := r.db.QueryRow(ctx, sql, *p.IDExact)
		hit, err := scanAdminProducer(row)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, nil
			}
			return nil, fmt.Errorf("ProducerRepo.AdminList exact: %w", err)
		}
		return []AdminProducerRow{*hit}, nil
	}

	sql := adminProducerSelect + `
WHERE TRUE
  AND ($1::boolean OR b.deleted_at IS NULL)
  AND ($2::text IS NULL OR b.search_text LIKE '%' || $2 || '%')
  AND ($3::timestamptz IS NULL OR (b.created_at, b.id) < ($3::timestamptz, $4::uuid))
ORDER BY b.created_at DESC, b.id DESC
LIMIT $5;`

	rows, err := r.db.Query(ctx, sql, p.IncludeDeleted, bigmLikeArg(p.Q), p.CursorTs, p.CursorID, p.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("ProducerRepo.AdminList: %w", err)
	}
	defer rows.Close()
	out := make([]AdminProducerRow, 0, p.Limit+1)
	for rows.Next() {
		hit, err := scanAdminProducer(rows)
		if err != nil {
			return nil, fmt.Errorf("ProducerRepo.AdminList scan: %w", err)
		}
		out = append(out, *hit)
	}
	return out, rows.Err()
}

// AdminDetail returns one producer by id, including soft-deleted rows.
// Used by the admin GET endpoint which always exposes the deleted_at
// flag — the public Detail filters tombstones out.
func (r *ProducerRepo) AdminDetail(ctx context.Context, id string) (*AdminProducerRow, error) {
	const sql = adminProducerSelect + ` WHERE b.id = $1::uuid LIMIT 1;`
	row := r.db.QueryRow(ctx, sql, id)
	out, err := scanAdminProducer(row)
	if err != nil {
		return nil, wrapNoRows("ProducerRepo.AdminDetail", err)
	}
	return out, nil
}

// Create inserts a producer row inside the supplied tx and returns the
// freshly-scanned row. The handler bundles a moderation_log audit row
// into the same tx for atomic commit. Caller is responsible for
// SanitizeText + range checks (and for resolving `prefecture_slug`
// → `prefecture_id` before calling).
//
// Migration 016: only `prefecture_id` is persisted. The RETURNING
// clause re-fetches via the LEFT JOIN to populate the nested
// prefecture/region in the response.
func (r *ProducerRepo) Create(ctx context.Context, tx pgx.Tx, in ProducerCreateInput) (*AdminProducerRow, error) {
	nameJSON, err := jsonMarshalI18n(in.Name)
	if err != nil {
		return nil, err
	}
	descArg, err := i18nPointerToJSONArg(in.Description)
	if err != nil {
		return nil, err
	}

	// Two-step: INSERT returns the new id, then re-SELECT via the
	// adminProducerSelect projection so the response carries the joined
	// prefecture + region. A single statement with RETURNING cannot
	// easily reach across the prefectures + regions joins.
	const ins = `
INSERT INTO producers (name_i18n, prefecture_id, founded_year, website, description_i18n, image_url)
VALUES ($1::jsonb, $2, $3, $4, $5::jsonb, $6)
RETURNING id;`
	var id string
	if err := tx.QueryRow(ctx, ins,
		string(nameJSON), in.PrefectureID, in.FoundedYear, in.Website, descArg, in.ImageURL,
	).Scan(&id); err != nil {
		return nil, fmt.Errorf("ProducerRepo.Create: %w", err)
	}
	const reselect = adminProducerSelect + ` WHERE b.id = $1::uuid LIMIT 1;`
	out, err := scanAdminProducer(tx.QueryRow(ctx, reselect, id))
	if err != nil {
		return nil, fmt.Errorf("ProducerRepo.Create reselect: %w", err)
	}
	return out, nil
}

// Update applies a partial change to a producer and returns the updated
// row. Only fields whose input pointers are non-nil are touched. The
// row must be live (deleted_at IS NULL) — restoring goes through Restore.
// Runs inside the supplied tx so the moderation_log audit row commits
// atomically with the change.
func (r *ProducerRepo) Update(ctx context.Context, tx pgx.Tx, id string, in ProducerUpdateInput) (*AdminProducerRow, error) {
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
	if in.PrefectureID != nil {
		// Empty string clears the FK (SET prefecture_id = NULL);
		// non-empty assigns the supplied UUID.
		if *in.PrefectureID == "" {
			add("prefecture_id", nil)
		} else {
			add("prefecture_id", *in.PrefectureID)
		}
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
	if in.ImageURL != nil {
		// Empty string clears image_url to NULL; non-empty sets it to
		// the resolved R2 URL.
		if *in.ImageURL == "" {
			add("image_url", nil)
		} else {
			add("image_url", *in.ImageURL)
		}
	}
	if len(sets) == 0 {
		// No-op: return the existing row unchanged. We re-fetch via the
		// tx so a concurrent admin update visible inside the tx is also
		// visible to the caller.
		const reselect = adminProducerSelect + ` WHERE b.id = $1::uuid LIMIT 1;`
		row := tx.QueryRow(ctx, reselect, id)
		out, err := scanAdminProducer(row)
		if err != nil {
			return nil, wrapNoRows("ProducerRepo.Update reselect", err)
		}
		return out, nil
	}
	args = append(args, id)
	sql := fmt.Sprintf(`
UPDATE producers SET %s
WHERE id = $%d AND deleted_at IS NULL
RETURNING id;`, strings.Join(sets, ", "), len(args))

	var updatedID string
	if err := tx.QueryRow(ctx, sql, args...).Scan(&updatedID); err != nil {
		return nil, wrapNoRows("ProducerRepo.Update", err)
	}
	// Reselect via the joined projection so the response carries the
	// nested prefecture/region (RETURNING can't cross the LEFT JOINs).
	const reselect = adminProducerSelect + ` WHERE b.id = $1::uuid LIMIT 1;`
	out, err := scanAdminProducer(tx.QueryRow(ctx, reselect, updatedID))
	if err != nil {
		return nil, wrapNoRows("ProducerRepo.Update reselect", err)
	}
	return out, nil
}

// SoftDelete sets deleted_at = NOW() on the producer row inside the supplied
// transaction (the handler bundles the moderation_log row into the same tx).
// Returns ErrProducerHasLiveBeverages when at least one beverage still
// references this producer with deleted_at IS NULL — the FK is RESTRICT, so
// leaving live children would orphan them from /v1/producers lookups.
func (r *ProducerRepo) SoftDelete(ctx context.Context, tx pgx.Tx, id string) error {
	// Preflight: cheap exists-check on the live partial index. We hold a
	// row-level lock on the producer for the duration of the tx so a
	// concurrent INSERT of a beverage referencing this producer serializes
	// against this UPDATE's RETURNING (the trigger to bump beverage_count
	// would acquire the same row lock).
	var liveChild bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM beverages WHERE producer_id = $1 AND deleted_at IS NULL LIMIT 1);`,
		id,
	).Scan(&liveChild); err != nil {
		return fmt.Errorf("ProducerRepo.SoftDelete preflight: %w", err)
	}
	if liveChild {
		return domain.ErrProducerHasLiveBeverages
	}

	const q = `
UPDATE producers SET deleted_at = NOW()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("ProducerRepo.SoftDelete: %w", err)
	}
	return nil
}

// Restore clears deleted_at on a tombstoned producer row.
func (r *ProducerRepo) Restore(ctx context.Context, tx pgx.Tx, id string) error {
	const q = `
UPDATE producers SET deleted_at = NULL
WHERE id = $1 AND deleted_at IS NOT NULL
RETURNING id;`
	var got string
	if err := tx.QueryRow(ctx, q, id).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("ProducerRepo.Restore: %w", err)
	}
	return nil
}

// ============================================================================
// Beverage admin CRUD
// ============================================================================

// BeverageCreateInput carries the validated payload for AdminCreateBeverage.
// CategoryID drives the category_slug via the existing
// sync_beverage_category_slug trigger — we do NOT set slug here.
//
// Locality is derived through the producer's prefecture_id.
//
// SubcategoryID is the FK into beverage_subcategories. nil means "no
// subcategory" (column NULL). The legacy `Subcategory` (free-text JSONB)
// is still accepted; the handler ignores it when SubcategoryID is
// non-nil, and the dual-source toBeverage fallback only kicks in when
// both the legacy and FK columns are NULL.
type BeverageCreateInput struct {
	ProducerID     string
	CategoryID     string
	Name           domain.I18nText
	Subcategory    *domain.I18nText
	SubcategoryID  *string
	ABV            *float64
	PolishingRatio *int
	FlavorProfile  []string
	Description    *domain.I18nText
	LabelImageURL  *string
}

// BeverageUpdateInput carries the partial-update fields.
//
// SubcategoryID pointer semantics:
//   - nil pointer → leave subcategory_id unchanged.
//   - ptr to ""   → clear subcategory_id to NULL.
//   - ptr to UUID → set subcategory_id to that value (the handler must
//     have validated it points to a row under the beverage's category).
type BeverageUpdateInput struct {
	ProducerID     *string
	CategoryID     *string
	Name           *domain.I18nText
	Subcategory    *domain.I18nText
	SubcategoryID  *string
	ABV            *float64
	PolishingRatio *int
	FlavorProfile  *[]string
	Description    *domain.I18nText
	LabelImageURL  *string
}

// AdminBeverageListParams scopes the admin beverage search. Q is a
// case-insensitive substring (idx_beverages_search_bigm); the other
// filters narrow by category / producer / id-exact / tombstone visibility.
type AdminBeverageListParams struct {
	Q              *string
	ProducerID     *string
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
// badge. Locality comes from the producer's joined prefecture chain via
// producerPrefectureSelectCols.
//
// LEFT JOIN beverage_subcategories so the admin edit modal pre-fills
// the canonical subcategory ref. Legacy b.subcategory_i18n is retained
// for the dual-source fallback (see toBeverage).
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
  b.description_i18n,
  b.label_image_url,
  b.avg_rating,
  b.check_in_count,
  b.flavor_profile,
  b.created_at,
  br.id          AS producer_id,
  br.name_i18n   AS producer_name_i18n,` + producerPrefectureSelectCols + subcategoryJoinCols + `,
  b.deleted_at
FROM beverages b
JOIN producers br ON br.id = b.producer_id
JOIN beverage_categories cat ON cat.id = b.category_id` + producerPrefectureJoinClause + subcategoryJoinClause

func scanAdminBeverage(row pgx.Row) (*AdminBeverageRow, error) {
	var b beverageRow
	var deletedAt *time.Time
	prefArgs := b.producerPref.scanArgs()
	subArgs := b.subcategoryScanArgs()
	args := make([]any, 0, 16+len(prefArgs)+len(subArgs)+1)
	args = append(args,
		&b.id,
		&b.nameJSON,
		&b.subcatJSON,
		&b.categorySlug,
		&b.categoryName,
		&b.categoryID,
		&b.abv,
		&b.polRatio,
		&b.descJSON,
		&b.labelImgURL,
		&b.avgRating,
		&b.checkInCount,
		&b.flavorProfile,
		&b.createdAt,
		&b.producerID,
		&b.producerNameRaw,
	)
	args = append(args, prefArgs...)
	args = append(args, subArgs...)
	args = append(args, &deletedAt)
	if err := row.Scan(args...); err != nil {
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

// AdminList pages through beverages for the admin tooling. Optional Q
// substring, producer/category filters, and IDExact short-circuit.
// Soft-deleted rows are hidden by default; set IncludeDeleted to surface
// them.
func (r *BeverageRepo) AdminList(ctx context.Context, p AdminBeverageListParams) ([]AdminBeverageRow, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}

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
  AND ($2::text IS NULL OR b.search_text LIKE '%' || $2 || '%')
  AND ($3::text IS NULL OR b.producer_id = $3::uuid)
  AND ($4::text IS NULL OR b.category_id = $4::uuid)
  AND ($5::text IS NULL OR b.category_slug = $5)
  AND ($6::timestamptz IS NULL OR (b.created_at, b.id) < ($6::timestamptz, $7::uuid))
ORDER BY b.created_at DESC, b.id DESC
LIMIT $8;`

	rows, err := r.db.Query(ctx, sql,
		p.IncludeDeleted, bigmLikeArg(p.Q), p.ProducerID, p.CategoryID, p.CategorySlug,
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
	//
	// Locality is derived through the producer's prefecture_id, not stored
	// on the beverage row.
	//
	// subcategory_id is the FK; the legacy subcategory_i18n is still
	// written when supplied (for admin requests that opt to send the
	// legacy field for backwards-compat). New admin payloads send only
	// subcategory_id.
	const q = `
INSERT INTO beverages (producer_id, category_id, category_slug, name_i18n,
                       subcategory_i18n, subcategory_id, abv, polishing_ratio,
                       description_i18n, label_image_url, flavor_profile)
VALUES ($1::uuid, $2::uuid, 'nihonshu', $3::jsonb, $4::jsonb, $5, $6, $7,
        $8::jsonb, $9, COALESCE($10, '{}'::text[]))
RETURNING id;`
	var id string
	if err := tx.QueryRow(ctx, q,
		in.ProducerID, in.CategoryID, string(nameJSON), subArg, in.SubcategoryID,
		in.ABV, in.PolishingRatio,
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
	sets, args, err := buildBeverageUpdateSets(in)
	if err != nil {
		return err
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

// buildBeverageUpdateSets translates a partial BeverageUpdateInput into
// the SET-clause fragments + positional args that UPDATE beverages can
// consume. Each non-nil field on the input contributes one clause; an
// all-empty i18n value clears the column.
func buildBeverageUpdateSets(in BeverageUpdateInput) ([]string, []any, error) {
	var (
		sets []string
		args []any
	)
	add := func(col string, val any) {
		args = append(args, val)
		sets = append(sets, fmt.Sprintf("%s = $%d", col, len(args)))
	}
	addI18n := func(col string, val *domain.I18nText) error {
		if val.EN == "" && val.JA == "" && val.KO == "" {
			add(col, nil)
			return nil
		}
		b, err := jsonMarshalI18n(*val)
		if err != nil {
			return err
		}
		add(col, string(b))
		return nil
	}

	if in.ProducerID != nil {
		add("producer_id", *in.ProducerID)
	}
	if in.CategoryID != nil {
		// category_slug is auto-synced by trg_beverages_sync_category_slug.
		add("category_id", *in.CategoryID)
	}
	if in.Name != nil {
		nameJSON, err := jsonMarshalI18n(*in.Name)
		if err != nil {
			return nil, nil, err
		}
		add("name_i18n", string(nameJSON))
	}
	if in.Subcategory != nil {
		if err := addI18n("subcategory_i18n", in.Subcategory); err != nil {
			return nil, nil, err
		}
	}
	if in.SubcategoryID != nil {
		// Empty string clears the FK; non-empty assigns it. The handler
		// validates that the new id belongs to the same category as the
		// beverage (or that the category isn't changing on this PATCH).
		if *in.SubcategoryID == "" {
			add("subcategory_id", nil)
		} else {
			add("subcategory_id", *in.SubcategoryID)
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
	if in.Description != nil {
		if err := addI18n("description_i18n", in.Description); err != nil {
			return nil, nil, err
		}
	}
	if in.LabelImageURL != nil {
		add("label_image_url", *in.LabelImageURL)
	}
	return sets, args, nil
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
