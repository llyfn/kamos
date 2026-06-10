package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/spec"
)

type SearchRepo struct{ db *pgxpool.Pool }

// SearchResult is a sum type: only one of Beverage/Producer is non-nil.
type SearchResult struct {
	Type     string           `json:"type"` // 'beverage' | 'producer'
	Beverage *domain.Beverage `json:"beverage,omitempty"`
	Producer *domain.Producer `json:"producer,omitempty"`
}

// SearchBeverages fetches up to limit+1 beverages matching q via the
// bigm substring pattern, keyset-paginated on id. cursorID is the
// exclusive (`<`) id boundary; nil for the first page.
func (r *SearchRepo) SearchBeverages(ctx context.Context, q string, cursorID *string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = spec.PageSizeDefault
	}
	const bq = beverageListSelect + `
WHERE b.deleted_at IS NULL
  AND br.deleted_at IS NULL
  AND b.search_text LIKE '%' || $1 || '%'
  AND ($2::text IS NULL OR b.id < $2::uuid)
ORDER BY b.check_in_count DESC, b.id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, bq, bigmLikeArg(&q), cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("SearchBeverages: %w", err)
	}
	defer rows.Close()
	brepo := BeverageRepo{db: r.db}
	var out []SearchResult
	for rows.Next() {
		bv, err := scanBeverageList(rows)
		if err != nil {
			return nil, fmt.Errorf("SearchBeverages scan: %w", err)
		}
		d, err := brepo.toBeverage(bv)
		if err != nil {
			return nil, err
		}
		out = append(out, SearchResult{Type: "beverage", Beverage: &d})
	}
	return out, rows.Err()
}

// SearchProducers fetches up to limit+1 producers matching q via the
// bigm substring pattern.
func (r *SearchRepo) SearchProducers(ctx context.Context, q string, cursorID *string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = spec.PageSizeDefault
	}
	const brq = `
SELECT b.id, b.name_i18n, b.founded_year, b.website, b.description_i18n, b.image_url, b.created_at,` + producerPrefectureSelectCols + `
FROM producers b` + producersPrefectureJoinClause + `
WHERE b.deleted_at IS NULL
  AND b.search_text LIKE '%' || $1 || '%'
  AND ($2::text IS NULL OR b.id < $2::uuid)
ORDER BY b.id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, brq, bigmLikeArg(&q), cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("SearchProducers: %w", err)
	}
	defer rows.Close()
	var out []SearchResult
	for rows.Next() {
		b, err := scanProducer(rows)
		if err != nil {
			return nil, fmt.Errorf("SearchProducers scan: %w", err)
		}
		out = append(out, SearchResult{Type: "producer", Producer: b})
	}
	return out, rows.Err()
}
