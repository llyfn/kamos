package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

type BeverageRepo struct{ db *pgxpool.Pool }

// catRow is the join-target shape for category lookups (slug + i18n label).
type catRow struct {
	slug     string
	nameJSON []byte
}

// List returns a page of beverages. Cursor uses
// (check_in_count, created_at, id) for the popularity sort — the
// triple keeps the keyset stable even when check_in_count mutates
// under an active cursor (PERF-003). Empty `category` and `q` are
// wildcards.
type BeverageListParams struct {
	Q            *string
	CategorySlug *string
	CursorCount  *int64
	CursorTs     *time.Time
	CursorID     *string
	Limit        int
}

type beverageRow struct {
	id              string
	nameJSON        []byte
	subcatJSON      []byte // legacy free-text JSONB — one-release fallback
	categorySlug    string
	categoryName    []byte
	categoryID      string
	abv             *float64
	polRatio        *int
	descJSON        []byte
	labelImgURL     *string
	avgRating       *float64
	checkInCount    int
	flavorProfile   []string
	createdAt       time.Time
	producerID      string
	producerNameRaw []byte
	producerImgURL  *string
	producerPref    prefectureScan
	// beverage_subcategories JOIN. All five fields are nullable because the
	// JOIN is LEFT (a beverage may have subcategory_id NULL during the
	// dual-source window — see toBeverage for the fallback).
	subID           *string
	subCategoryID   *string
	subCategorySlug *string
	subSlug         *string
	subNameJSON     []byte
	subSortOrder    *int16
}

// subcategoryJoinCols is the comma-prefixed projection of beverage_subcategories
// columns appended to every beverageSelect / beverageListSelect /
// adminBeverageSelect. Defined once to keep the projection consistent.
//
// The JOIN is LEFT — beverages may have subcategory_id NULL during the
// one-release dual-source window after migration 005. When the FK is
// NULL the toBeverage fallback uses the legacy beverages.subcategory_i18n
// JSONB so the response still surfaces the (pre-promotion) free-text
// subcategory.
const subcategoryJoinCols = `,
  sc.id          AS subcategory_id_join,
  sc.category_id AS subcategory_category_id_join,
  sc.category_slug AS subcategory_category_slug_join,
  sc.slug        AS subcategory_slug_join,
  sc.name_i18n   AS subcategory_name_i18n_join,
  sc.sort_order  AS subcategory_sort_order_join`

const subcategoryJoinClause = `
LEFT JOIN beverage_subcategories sc ON sc.id = b.subcategory_id AND sc.deleted_at IS NULL`

// beverageSelect is the full projection used by /v1/beverages/{id}.
// It carries the two i18n JSONB blobs (subcategory_i18n,
// description_i18n) that are needed on the detail screen.
//
// Locality is derived via the producer's prefecture chain (LEFT JOIN
// prefectures + regions on producers.prefecture_id).
//
// The legacy b.subcategory_i18n column is still SELECTed because the
// dual-source fallback in toBeverage reads it when subcategory_id is
// NULL.
const beverageSelect = `
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
  br.id           AS producer_id,
  br.name_i18n    AS producer_name_i18n,
  br.image_url    AS producer_image_url,` + producerPrefectureSelectCols + subcategoryJoinCols + `
FROM beverages b
JOIN producers br ON br.id = b.producer_id
JOIN beverage_categories cat ON cat.id = b.category_id` + producerPrefectureJoinClause + subcategoryJoinClause

// beverageListSelect is the slim projection used by list/search paths:
// it drops the description JSONB and the legacy subcategory_i18n blob
// because list cards only show name + category + producer + counts.
// Dropping the JSONB cuts list-response payload size by ~30%.
// The corresponding scan helper is scanBeverageList.
//
// The joined beverage_subcategories projection is included because list
// cards in admin already need slug/name to render a
// "category · subcategory" overline and the JSONB-free slim subcategory
// shape is small. Legacy b.subcategory_i18n stays excluded.
const beverageListSelect = `
SELECT
  b.id,
  b.name_i18n,
  b.category_slug,
  cat.name_i18n  AS category_name_i18n,
  cat.id         AS category_id,
  b.abv,
  b.polishing_ratio,
  b.label_image_url,
  b.avg_rating,
  b.check_in_count,
  b.flavor_profile,
  b.created_at,
  br.id           AS producer_id,
  br.name_i18n    AS producer_name_i18n,
  br.image_url    AS producer_image_url,` + producerPrefectureSelectCols + subcategoryJoinCols + `
FROM beverages b
JOIN producers br ON br.id = b.producer_id
JOIN beverage_categories cat ON cat.id = b.category_id` + producerPrefectureJoinClause + subcategoryJoinClause

// subcategoryScanArgs returns the 6 pointers that match subcategoryJoinCols
// in order. Centralized so every scanner appends the same slice and
// future tweaks (e.g. adding admin-only columns to the projection) edit
// one spot.
func (b *beverageRow) subcategoryScanArgs() []any {
	return []any{
		&b.subID,
		&b.subCategoryID,
		&b.subCategorySlug,
		&b.subSlug,
		&b.subNameJSON,
		&b.subSortOrder,
	}
}

func scanBeverage(row pgx.Row) (*beverageRow, error) {
	var b beverageRow
	prefArgs := b.producerPref.scanArgs()
	subArgs := b.subcategoryScanArgs()
	args := make([]any, 0, 17+len(prefArgs)+len(subArgs))
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
		&b.producerImgURL,
	)
	args = append(args, prefArgs...)
	args = append(args, subArgs...)
	if err := row.Scan(args...); err != nil {
		return nil, err
	}
	return &b, nil
}

// scanBeverageList matches the column order of beverageListSelect (no
// subcategory_i18n, no description_i18n). The returned beverageRow
// has subcatJSON / descJSON left nil; toBeverage already treats
// len-0 as "absent", so the API response omits those fields. The
// joined subcategory columns ARE populated here so list cards can
// still render the canonical subcategory.
func scanBeverageList(row pgx.Row) (*beverageRow, error) {
	var b beverageRow
	prefArgs := b.producerPref.scanArgs()
	subArgs := b.subcategoryScanArgs()
	args := make([]any, 0, 15+len(prefArgs)+len(subArgs))
	args = append(args,
		&b.id,
		&b.nameJSON,
		&b.categorySlug,
		&b.categoryName,
		&b.categoryID,
		&b.abv,
		&b.polRatio,
		&b.labelImgURL,
		&b.avgRating,
		&b.checkInCount,
		&b.flavorProfile,
		&b.createdAt,
		&b.producerID,
		&b.producerNameRaw,
		&b.producerImgURL,
	)
	args = append(args, prefArgs...)
	args = append(args, subArgs...)
	if err := row.Scan(args...); err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *BeverageRepo) toBeverage(row *beverageRow) (domain.Beverage, error) {
	name, err := domain.I18nFromJSON(row.nameJSON)
	if err != nil {
		return domain.Beverage{}, err
	}
	prodName, err := domain.I18nFromJSON(row.producerNameRaw)
	if err != nil {
		return domain.Beverage{}, err
	}
	catLabel, err := domain.I18nFromJSON(row.categoryName)
	if err != nil {
		return domain.Beverage{}, err
	}
	out := domain.Beverage{
		ID:   row.id,
		Name: name,
		Producer: domain.Producer{
			ID:         row.producerID,
			Name:       prodName,
			Prefecture: row.producerPref.toPrefecture(),
			ImageURL:   row.producerImgURL,
		},
		Category:       domain.CategoryLabel{Slug: row.categorySlug, LabelI18n: catLabel},
		ABV:            row.abv,
		PolishingRatio: row.polRatio,
		FlavorProfile:  row.flavorProfile,
		LabelImageURL:  row.labelImgURL,
		AvgRating:      row.avgRating,
		CheckInCount:   row.checkInCount,
		CreatedAt:      row.createdAt,
	}
	// Dual-source subcategory path:
	//   1. Canonical: beverage_subcategories JOIN populated (subID != nil)
	//      → ship the full Subcategory ref (id, slug, name, sort_order).
	//   2. Legacy fallback: subcategory_id is NULL but the legacy
	//      b.subcategory_i18n JSONB has data → ship a partial Subcategory
	//      ref with only the name populated and empty id/slug.
	switch {
	case row.subID != nil && *row.subID != "":
		name, _ := domain.I18nFromJSON(row.subNameJSON)
		var sort16 int16
		if row.subSortOrder != nil {
			sort16 = *row.subSortOrder
		}
		var catID, catSlug, slug string
		if row.subCategoryID != nil {
			catID = *row.subCategoryID
		}
		if row.subCategorySlug != nil {
			catSlug = *row.subCategorySlug
		}
		if row.subSlug != nil {
			slug = *row.subSlug
		}
		out.Subcategory = &domain.Subcategory{
			ID:           *row.subID,
			CategoryID:   catID,
			CategorySlug: catSlug,
			Slug:         slug,
			Name:         name,
			SortOrder:    sort16,
		}
	case len(row.subcatJSON) > 0:
		// Legacy free-text fallback. The dual-source window closes when
		// the follow-up migration drops beverages.subcategory_i18n; until
		// then we still surface it so existing un-backfilled beverages
		// don't render with an empty subcategory line.
		name, _ := domain.I18nFromJSON(row.subcatJSON)
		out.Subcategory = &domain.Subcategory{Name: name}
	}
	if len(row.descJSON) > 0 {
		desc, _ := domain.I18nFromJSON(row.descJSON)
		out.Description = &desc
	}
	return out, nil
}

// List uses the popularity cursor (check_in_count, created_at, id).
// Set Q to filter by full-text match. q (lexeme) and category_slug
// are optional. The triple keyset is backed by
// idx_beverages_popularity_keyset (migration 012).
//
// Soft-deleted rows are filtered out on the public read path. The
// partial indexes (idx_beverages_* WHERE deleted_at IS NULL) keep
// the planner using index scans without the predicate slowing down
// the hot path.
func (r *BeverageRepo) List(ctx context.Context, p BeverageListParams) ([]domain.Beverage, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}
	q := beverageListSelect + `
WHERE TRUE
  AND b.deleted_at IS NULL
  AND br.deleted_at IS NULL
  AND ($1::text IS NULL OR
       to_tsvector('simple',
         coalesce(b.name_i18n->>'en','') || ' ' ||
         coalesce(b.name_i18n->>'ja','') || ' ' ||
         coalesce(b.name_i18n->>'ko','')
       ) @@ plainto_tsquery('simple', $1))
  AND ($2::text IS NULL OR b.category_slug = $2)
  AND ($3::bigint IS NULL OR
       (b.check_in_count, b.created_at, b.id) <
       ($3::bigint, $4::timestamptz, $5::uuid))
ORDER BY b.check_in_count DESC, b.created_at DESC, b.id DESC
LIMIT $6;`
	rows, err := r.db.Query(ctx, q, p.Q, p.CategorySlug, p.CursorCount, p.CursorTs, p.CursorID, p.Limit+1)
	if err != nil {
		return nil, fmt.Errorf("BeverageRepo.List: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Beverage, 0, p.Limit+1)
	for rows.Next() {
		bv, err := scanBeverageList(rows)
		if err != nil {
			return nil, fmt.Errorf("BeverageRepo.List scan: %w", err)
		}
		d, err := r.toBeverage(bv)
		if err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// Detail returns one beverage by id along with producer + category info.
//
// Soft-deleted rows are treated as not found on the public read path.
// The admin GET handler uses AdminDetail to surface soft-deleted rows so
// an admin can restore them.
func (r *BeverageRepo) Detail(ctx context.Context, id string) (*domain.Beverage, error) {
	q := beverageSelect + ` WHERE b.id = $1 AND b.deleted_at IS NULL AND br.deleted_at IS NULL;`
	row := r.db.QueryRow(ctx, q, id)
	bv, err := scanBeverage(row)
	if err != nil {
		return nil, wrapNoRows("BeverageRepo.Detail", err)
	}
	d, err := r.toBeverage(bv)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// Exists is a cheap presence check. Soft-deleted rows return false so
// callers (check-in create, collection add-entry) cannot reference a
// tombstoned beverage.
func (r *BeverageRepo) Exists(ctx context.Context, id string) (bool, error) {
	var exists bool
	if err := r.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM beverages WHERE id = $1 AND deleted_at IS NULL);`, id).Scan(&exists); err != nil {
		return false, fmt.Errorf("BeverageRepo.Exists: %w", err)
	}
	return exists, nil
}

// AggregatedFlavor implements query_patterns.md §10 aggregated-flavor block.
func (r *BeverageRepo) AggregatedFlavor(ctx context.Context, beverageID string) ([]domain.FlavorAggregate, error) {
	const q = `
SELECT ft.slug, ft.dimension, ft.name_i18n, COUNT(*) AS uses
FROM check_in_flavor_tags cift
JOIN check_ins ci ON ci.id = cift.check_in_id AND ci.deleted_at IS NULL
JOIN flavor_tags ft ON ft.id = cift.flavor_tag_id
WHERE ci.beverage_id = $1
GROUP BY ft.slug, ft.dimension, ft.name_i18n
ORDER BY uses DESC, ft.dimension, ft.slug
LIMIT 12;`
	rows, err := r.db.Query(ctx, q, beverageID)
	if err != nil {
		return nil, fmt.Errorf("AggregatedFlavor: %w", err)
	}
	defer rows.Close()
	var out []domain.FlavorAggregate
	for rows.Next() {
		var a domain.FlavorAggregate
		var nameJSON []byte
		var uses int64
		if err := rows.Scan(&a.Slug, &a.Dimension, &nameJSON, &uses); err != nil {
			return nil, fmt.Errorf("AggregatedFlavor scan: %w", err)
		}
		a.Name, _ = domain.I18nFromJSON(nameJSON)
		a.Uses = int(uses)
		out = append(out, a)
	}
	return out, rows.Err()
}

// RecentCheckins returns the latest (non-deleted) check-ins for a beverage,
// keyset-paginated on (created_at, id). Returns up to limit+1 rows so the
// handler can compute has_more.
func (r *BeverageRepo) RecentCheckins(ctx context.Context, beverageID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.CheckinSummary, error) {
	const q = `
SELECT ci.id, ci.rating, ci.review_text, ci.created_at,
       u.id, u.username, u.display_username, u.display_name, u.avatar_url
FROM check_ins ci
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
WHERE ci.beverage_id = $1
  AND ci.deleted_at IS NULL
  AND ($2::timestamptz IS NULL OR (ci.created_at, ci.id) < ($2::timestamptz, $3::uuid))
ORDER BY ci.created_at DESC, ci.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, beverageID, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("BeverageRepo.RecentCheckins: %w", err)
	}
	defer rows.Close()
	out := make([]domain.CheckinSummary, 0, limit+1)
	ids := make([]string, 0, limit+1)
	for rows.Next() {
		var s domain.CheckinSummary
		var rating *float64
		if err := rows.Scan(&s.ID, &rating, &s.Review, &s.CreatedAt,
			&s.User.ID, &s.User.Username, &s.User.DisplayUsername, &s.User.DisplayName, &s.User.AvatarURL); err != nil {
			return nil, fmt.Errorf("BeverageRepo.RecentCheckins scan: %w", err)
		}
		s.Rating = rating
		out = append(out, s)
		ids = append(ids, s.ID)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	// Batch-hydrate photos and flavor tags so the beverage detail
	// "recent check-ins" strip can render thumbnails + chip arrays
	// inline without a second round trip per row.
	ck := CheckinRepo{db: r.db}
	photos, err := ck.PhotosFor(ctx, ids)
	if err != nil {
		return nil, err
	}
	tags, err := ck.TagsFor(ctx, ids)
	if err != nil {
		return nil, err
	}
	for i := range out {
		out[i].Photos = photos[out[i].ID]
		if out[i].Photos == nil {
			out[i].Photos = []domain.PhotoRef{}
		}
		out[i].Tags = tags[out[i].ID]
		if out[i].Tags == nil {
			out[i].Tags = []domain.FlavorTag{}
		}
	}
	return out, nil
}

// ResolveFlavorTagIDs maps a slice of slugs to their UUIDs. Unknown slugs are
// silently dropped (the handler validated them upstream if it cares).
func (r *BeverageRepo) ResolveFlavorTagIDs(ctx context.Context, slugs []string) ([]string, error) {
	if len(slugs) == 0 {
		return nil, nil
	}
	const q = `SELECT id FROM flavor_tags WHERE slug = ANY($1);`
	rows, err := r.db.Query(ctx, q, slugs)
	if err != nil {
		return nil, fmt.Errorf("ResolveFlavorTagIDs: %w", err)
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("ResolveFlavorTagIDs scan: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// CategoryIDForSlug resolves a beverage_categories.slug → id. Returns
// domain.ErrNotFound when the slug is unknown (the admin handler converts
// that into a 422 INVALID_CATEGORY_SLUG response). Backed by the unique
// index idx_beverage_categories_slug.
func (r *BeverageRepo) CategoryIDForSlug(ctx context.Context, slug string) (string, error) {
	const q = `SELECT id FROM beverage_categories WHERE slug = $1;`
	var id string
	if err := r.db.QueryRow(ctx, q, slug).Scan(&id); err != nil {
		return "", wrapNoRows("BeverageRepo.CategoryIDForSlug", err)
	}
	return id, nil
}

// SubmitAdditionRequest writes a row to beverage_addition_requests.
func (r *BeverageRepo) SubmitAdditionRequest(ctx context.Context, userID *string, payload []byte) (string, error) {
	const q = `INSERT INTO beverage_addition_requests (user_id, payload) VALUES ($1, $2::jsonb) RETURNING id;`
	var id string
	if err := r.db.QueryRow(ctx, q, userID, string(payload)).Scan(&id); err != nil {
		return "", fmt.Errorf("SubmitAdditionRequest: %w", err)
	}
	return id, nil
}

// ---- producers ----

type ProducerRepo struct{ db *pgxpool.Pool }

func (r *ProducerRepo) List(ctx context.Context, q *string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Producer, error) {
	if limit <= 0 {
		limit = 20
	}
	// beverage_count comes from the denormalized column on producers
	// instead of a correlated subquery per row. Ordering is
	// (created_at DESC, id DESC) so the list paginates in a meaningful
	// order (v7 UUIDs are pseudo-random).
	//
	// Soft-deleted rows are excluded from the public catalog. The partial
	// idx_producers_name_tsv keeps FTS index-friendly. Prefecture comes
	// from a LEFT JOIN on prefectures + regions via
	// producers.prefecture_id; nullable.
	const sql = `
SELECT b.id, b.name_i18n, b.founded_year, b.website, b.description_i18n, b.image_url, b.created_at,
       b.beverage_count,` + producerPrefectureSelectCols + `
FROM producers b` + producersPrefectureJoinClause + `
WHERE b.deleted_at IS NULL
  AND ($1::text IS NULL OR
       to_tsvector('simple',
         coalesce(b.name_i18n->>'en','') || ' ' ||
         coalesce(b.name_i18n->>'ja','') || ' ' ||
         coalesce(b.name_i18n->>'ko','')
       ) @@ plainto_tsquery('simple', $1))
  AND ($2::timestamptz IS NULL OR (b.created_at, b.id) < ($2::timestamptz, $3::uuid))
ORDER BY b.created_at DESC, b.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, sql, q, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("ProducerRepo.List: %w", err)
	}
	defer rows.Close()
	return scanProducersWithCount(rows)
}

func (r *ProducerRepo) Detail(ctx context.Context, id string) (*domain.Producer, error) {
	const sql = `
SELECT b.id, b.name_i18n, b.founded_year, b.website, b.description_i18n, b.image_url, b.created_at,
       b.beverage_count,` + producerPrefectureSelectCols + `
FROM producers b` + producersPrefectureJoinClause + `
WHERE b.id = $1 AND b.deleted_at IS NULL;`
	row := r.db.QueryRow(ctx, sql, id)
	out, err := scanProducerWithCount(row)
	if err != nil {
		return nil, wrapNoRows("ProducerRepo.Detail", err)
	}
	return out, nil
}

// Beverages lists beverages by producer, cursor-paginated on
// (created_at, id) so a producer detail page shows newest first
// instead of the v7-UUID-pseudo-random id order. Soft-deleted rows
// are filtered on both joined tables.
func (r *ProducerRepo) Beverages(ctx context.Context, producerID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Beverage, error) {
	if limit <= 0 {
		limit = 20
	}
	q := beverageListSelect + `
WHERE b.producer_id = $1
  AND b.deleted_at IS NULL
  AND br.deleted_at IS NULL
  AND ($2::timestamptz IS NULL OR (b.created_at, b.id) < ($2::timestamptz, $3::uuid))
ORDER BY b.created_at DESC, b.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, producerID, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("ProducerRepo.Beverages: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Beverage, 0, limit+1)
	for rows.Next() {
		bv, err := scanBeverageList(rows)
		if err != nil {
			return nil, fmt.Errorf("ProducerRepo.Beverages scan: %w", err)
		}
		br := BeverageRepo{db: r.db}
		d, err := br.toBeverage(bv)
		if err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// scanProducer scans the count-free producer projection used by
// /v1/search. Column order:
//
//	id, name_i18n, founded_year, website, description_i18n, image_url,
//	created_at, + producerPrefectureSelectCols (8 join columns).
func scanProducer(row pgx.Row) (*domain.Producer, error) {
	var b domain.Producer
	var nameJSON, descJSON []byte
	var pref prefectureScan
	prefArgs := pref.scanArgs()
	args := make([]any, 0, 7+len(prefArgs))
	args = append(args, &b.ID, &nameJSON, &b.FoundedYear, &b.Website, &descJSON, &b.ImageURL, &b.CreatedAt)
	args = append(args, prefArgs...)
	if err := row.Scan(args...); err != nil {
		return nil, err
	}
	b.Name, _ = domain.I18nFromJSON(nameJSON)
	if len(descJSON) > 0 {
		d, _ := domain.I18nFromJSON(descJSON)
		b.Description = &d
	}
	b.Prefecture = pref.toPrefecture()
	return &b, nil
}

// scanProducerWithCount scans the producer row plus a trailing beverage_count
// column. Used by ProducerRepo.List/Detail; search.go still uses the count-
// free variant. Column order:
//
//	id, name_i18n, founded_year, website, description_i18n, image_url,
//	created_at, beverage_count, + producerPrefectureSelectCols (8 join columns).
func scanProducerWithCount(row pgx.Row) (*domain.Producer, error) {
	var b domain.Producer
	var nameJSON, descJSON []byte
	var count int
	var pref prefectureScan
	prefArgs := pref.scanArgs()
	args := make([]any, 0, 8+len(prefArgs))
	args = append(args, &b.ID, &nameJSON, &b.FoundedYear, &b.Website, &descJSON, &b.ImageURL, &b.CreatedAt, &count)
	args = append(args, prefArgs...)
	if err := row.Scan(args...); err != nil {
		return nil, err
	}
	b.Name, _ = domain.I18nFromJSON(nameJSON)
	if len(descJSON) > 0 {
		d, _ := domain.I18nFromJSON(descJSON)
		b.Description = &d
	}
	b.BeverageCount = &count
	b.Prefecture = pref.toPrefecture()
	return &b, nil
}

func scanProducers(rows pgx.Rows) ([]domain.Producer, error) {
	var out []domain.Producer
	for rows.Next() {
		b, err := scanProducer(rows)
		if err != nil {
			return nil, fmt.Errorf("scanProducers: %w", err)
		}
		out = append(out, *b)
	}
	return out, rows.Err()
}

func scanProducersWithCount(rows pgx.Rows) ([]domain.Producer, error) {
	var out []domain.Producer
	for rows.Next() {
		b, err := scanProducerWithCount(rows)
		if err != nil {
			return nil, fmt.Errorf("scanProducersWithCount: %w", err)
		}
		out = append(out, *b)
	}
	return out, rows.Err()
}
