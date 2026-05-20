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
	id             string
	nameJSON       []byte
	subcatJSON     []byte
	categorySlug   string
	categoryName   []byte
	categoryID     string
	abv            *float64
	polRatio       *int
	prefecture     *string
	region         *string
	descJSON       []byte
	labelImgURL    *string
	avgRating      *float64
	checkInCount   int
	flavorProfile  []string
	createdAt      time.Time
	breweryID      string
	breweryNameRaw []byte
	breweryRegion  *string
}

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
  b.prefecture,
  b.region,
  b.description_i18n,
  b.label_image_url,
  b.avg_rating,
  b.check_in_count,
  b.flavor_profile,
  b.created_at,
  br.id           AS brewery_id,
  br.name_i18n    AS brewery_name_i18n,
  br.region       AS brewery_region
FROM beverages b
JOIN breweries br ON br.id = b.brewery_id
JOIN beverage_categories cat ON cat.id = b.category_id`

func scanBeverage(row pgx.Row) (*beverageRow, error) {
	var b beverageRow
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
	)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *BeverageRepo) toBeverage(row *beverageRow) (domain.Beverage, error) {
	name, err := domain.I18nFromJSON(row.nameJSON)
	if err != nil {
		return domain.Beverage{}, err
	}
	brewName, err := domain.I18nFromJSON(row.breweryNameRaw)
	if err != nil {
		return domain.Beverage{}, err
	}
	catLabel, err := domain.I18nFromJSON(row.categoryName)
	if err != nil {
		return domain.Beverage{}, err
	}
	out := domain.Beverage{
		ID:             row.id,
		Name:           name,
		Brewery:        domain.Brewery{ID: row.breweryID, Name: brewName, Region: row.breweryRegion},
		Category:       domain.CategoryLabel{Slug: row.categorySlug, LabelI18n: catLabel},
		ABV:            row.abv,
		PolishingRatio: row.polRatio,
		Prefecture:     row.prefecture,
		Region:         row.region,
		FlavorProfile:  row.flavorProfile,
		LabelImageURL:  row.labelImgURL,
		AvgRating:      row.avgRating,
		CheckInCount:   row.checkInCount,
		CreatedAt:      row.createdAt,
	}
	if len(row.subcatJSON) > 0 {
		sub, _ := domain.I18nFromJSON(row.subcatJSON)
		out.Subcategory = &sub
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
func (r *BeverageRepo) List(ctx context.Context, p BeverageListParams) ([]domain.Beverage, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}
	q := beverageSelect + `
WHERE TRUE
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
		bv, err := scanBeverage(rows)
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

// Detail returns one beverage by id along with brewery + category info.
func (r *BeverageRepo) Detail(ctx context.Context, id string) (*domain.Beverage, error) {
	q := beverageSelect + ` WHERE b.id = $1;`
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

// Exists is a cheap presence check.
func (r *BeverageRepo) Exists(ctx context.Context, id string) (bool, error) {
	var exists bool
	if err := r.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM beverages WHERE id = $1);`, id).Scan(&exists); err != nil {
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
	for rows.Next() {
		var s domain.CheckinSummary
		var rating *float64
		if err := rows.Scan(&s.ID, &rating, &s.Review, &s.CreatedAt,
			&s.User.ID, &s.User.Username, &s.User.DisplayUsername, &s.User.DisplayName, &s.User.AvatarURL); err != nil {
			return nil, fmt.Errorf("BeverageRepo.RecentCheckins scan: %w", err)
		}
		s.Rating = rating
		out = append(out, s)
	}
	if err := rows.Err(); err != nil {
		return nil, err
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

// SubmitAdditionRequest writes a row to beverage_addition_requests.
func (r *BeverageRepo) SubmitAdditionRequest(ctx context.Context, userID *string, payload []byte) (string, error) {
	const q = `INSERT INTO beverage_addition_requests (user_id, payload) VALUES ($1, $2::jsonb) RETURNING id;`
	var id string
	if err := r.db.QueryRow(ctx, q, userID, string(payload)).Scan(&id); err != nil {
		return "", fmt.Errorf("SubmitAdditionRequest: %w", err)
	}
	return id, nil
}

// ---- breweries ----

type BreweryRepo struct{ db *pgxpool.Pool }

func (r *BreweryRepo) List(ctx context.Context, q *string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Brewery, error) {
	if limit <= 0 {
		limit = 20
	}
	// Stage 5 (PERF-015): beverage_count comes from the denormalized
	// column on breweries (migration 011) instead of a correlated
	// subquery per row. The ordering switches from id-only (which is
	// pseudo-random for v7 UUIDs) to (created_at DESC, id DESC) so
	// the list paginates in a meaningful order.
	const sql = `
SELECT b.id, b.name_i18n, b.prefecture, b.region, b.founded_year, b.website, b.description_i18n, b.created_at,
       b.beverage_count
FROM breweries b
WHERE ($1::text IS NULL OR
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
		return nil, fmt.Errorf("BreweryRepo.List: %w", err)
	}
	defer rows.Close()
	return scanBreweriesWithCount(rows)
}

func (r *BreweryRepo) Detail(ctx context.Context, id string) (*domain.Brewery, error) {
	const sql = `
SELECT b.id, b.name_i18n, b.prefecture, b.region, b.founded_year, b.website, b.description_i18n, b.created_at,
       b.beverage_count
FROM breweries b WHERE b.id = $1;`
	row := r.db.QueryRow(ctx, sql, id)
	out, err := scanBreweryWithCount(row)
	if err != nil {
		return nil, wrapNoRows("BreweryRepo.Detail", err)
	}
	return out, nil
}

// Beverages lists beverages by brewery, cursor-paginated on
// (created_at, id) so a brewery detail page shows newest first
// instead of the v7-UUID-pseudo-random id order.
func (r *BreweryRepo) Beverages(ctx context.Context, breweryID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Beverage, error) {
	if limit <= 0 {
		limit = 20
	}
	q := beverageSelect + `
WHERE b.brewery_id = $1
  AND ($2::timestamptz IS NULL OR (b.created_at, b.id) < ($2::timestamptz, $3::uuid))
ORDER BY b.created_at DESC, b.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, breweryID, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("BreweryRepo.Beverages: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Beverage, 0, limit+1)
	for rows.Next() {
		bv, err := scanBeverage(rows)
		if err != nil {
			return nil, fmt.Errorf("BreweryRepo.Beverages scan: %w", err)
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

func scanBrewery(row pgx.Row) (*domain.Brewery, error) {
	var b domain.Brewery
	var nameJSON, descJSON []byte
	if err := row.Scan(&b.ID, &nameJSON, &b.Prefecture, &b.Region, &b.FoundedYear, &b.Website, &descJSON, &b.CreatedAt); err != nil {
		return nil, err
	}
	b.Name, _ = domain.I18nFromJSON(nameJSON)
	if len(descJSON) > 0 {
		d, _ := domain.I18nFromJSON(descJSON)
		b.Description = &d
	}
	return &b, nil
}

// scanBreweryWithCount scans the brewery row plus a trailing beverage_count
// column. Used by BreweryRepo.List/Detail; search.go still uses the count-
// free variant.
func scanBreweryWithCount(row pgx.Row) (*domain.Brewery, error) {
	var b domain.Brewery
	var nameJSON, descJSON []byte
	var count int
	if err := row.Scan(&b.ID, &nameJSON, &b.Prefecture, &b.Region, &b.FoundedYear, &b.Website, &descJSON, &b.CreatedAt, &count); err != nil {
		return nil, err
	}
	b.Name, _ = domain.I18nFromJSON(nameJSON)
	if len(descJSON) > 0 {
		d, _ := domain.I18nFromJSON(descJSON)
		b.Description = &d
	}
	b.BeverageCount = &count
	return &b, nil
}

func scanBreweries(rows pgx.Rows) ([]domain.Brewery, error) {
	var out []domain.Brewery
	for rows.Next() {
		b, err := scanBrewery(rows)
		if err != nil {
			return nil, fmt.Errorf("scanBreweries: %w", err)
		}
		out = append(out, *b)
	}
	return out, rows.Err()
}

func scanBreweriesWithCount(rows pgx.Rows) ([]domain.Brewery, error) {
	var out []domain.Brewery
	for rows.Next() {
		b, err := scanBreweryWithCount(rows)
		if err != nil {
			return nil, fmt.Errorf("scanBreweriesWithCount: %w", err)
		}
		out = append(out, *b)
	}
	return out, rows.Err()
}
