package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

type SearchRepo struct{ db *pgxpool.Pool }

// SearchResult is a sum type: only one of Beverage/Producer is non-nil.
type SearchResult struct {
	Type     string           `json:"type"` // 'beverage' | 'producer'
	Beverage *domain.Beverage `json:"beverage,omitempty"`
	Producer *domain.Producer `json:"producer,omitempty"`
}

// SearchBeverages fetches up to limit+1 beverages matching q, keyset-
// paginated by id. `cursorID` is the inclusive-exclusive (`<`) id boundary;
// nil for the first page. On a first-page miss the call rescues with a
// trigram fallback returning up to `limit` rows without a cursor — WHY:
// fuzzy matches are a one-shot rescue for misspellings, not a deep-scroll
// path; the handler emits has_more=false on the fallback page.
func (r *SearchRepo) SearchBeverages(ctx context.Context, q string, cursorID *string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 20
	}
	const bq = beverageListSelect + `
WHERE b.deleted_at IS NULL
  AND br.deleted_at IS NULL
  AND b.search_tsv @@ websearch_to_tsquery('simple', $1)
  AND ($2::text IS NULL OR b.id < $2::uuid)
ORDER BY b.check_in_count DESC, b.id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, bq, q, cursorID, limit+1)
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
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(out) == 0 && cursorID == nil {
		return r.searchBeveragesFuzzy(ctx, q, limit)
	}
	return out, nil
}

func (r *SearchRepo) searchBeveragesFuzzy(ctx context.Context, q string, limit int) ([]SearchResult, error) {
	// WHY <% over %: see BeverageRepo.listFuzzy — search_tsv::text is
	// too long for similarity() to clear the 0.3 threshold on short
	// queries; word_similarity scores against the closest word, which
	// is the desired "did you mean" behavior.
	const bq = beverageListSelect + `
WHERE b.deleted_at IS NULL
  AND br.deleted_at IS NULL
  AND $1 <% b.search_tsv::text
ORDER BY word_similarity($1, b.search_tsv::text) DESC, b.check_in_count DESC, b.id DESC
LIMIT $2;`
	rows, err := r.db.Query(ctx, bq, q, limit)
	if err != nil {
		return nil, fmt.Errorf("SearchBeverages fuzzy: %w", err)
	}
	defer rows.Close()
	brepo := BeverageRepo{db: r.db}
	var out []SearchResult
	for rows.Next() {
		bv, err := scanBeverageList(rows)
		if err != nil {
			return nil, fmt.Errorf("SearchBeverages fuzzy scan: %w", err)
		}
		d, err := brepo.toBeverage(bv)
		if err != nil {
			return nil, err
		}
		out = append(out, SearchResult{Type: "beverage", Beverage: &d})
	}
	return out, rows.Err()
}

// SearchProducers fetches up to limit+1 producers matching q. First-page
// misses fall back to a trigram rescue mirroring SearchBeverages.
func (r *SearchRepo) SearchProducers(ctx context.Context, q string, cursorID *string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 20
	}
	const brq = `
SELECT b.id, b.name_i18n, b.founded_year, b.website, b.description_i18n, b.image_url, b.created_at,` + producerPrefectureSelectCols + `
FROM producers b` + producersPrefectureJoinClause + `
WHERE b.deleted_at IS NULL
  AND b.search_tsv @@ websearch_to_tsquery('simple', $1)
  AND ($2::text IS NULL OR b.id < $2::uuid)
ORDER BY b.id DESC
LIMIT $3;`
	rows, err := r.db.Query(ctx, brq, q, cursorID, limit+1)
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
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(out) == 0 && cursorID == nil {
		return r.searchProducersFuzzy(ctx, q, limit)
	}
	return out, nil
}

func (r *SearchRepo) searchProducersFuzzy(ctx context.Context, q string, limit int) ([]SearchResult, error) {
	// <% over %: see BeverageRepo.listFuzzy for the rationale.
	const brq = `
SELECT b.id, b.name_i18n, b.founded_year, b.website, b.description_i18n, b.image_url, b.created_at,` + producerPrefectureSelectCols + `
FROM producers b` + producersPrefectureJoinClause + `
WHERE b.deleted_at IS NULL
  AND $1 <% b.search_tsv::text
ORDER BY word_similarity($1, b.search_tsv::text) DESC, b.id DESC
LIMIT $2;`
	rows, err := r.db.Query(ctx, brq, q, limit)
	if err != nil {
		return nil, fmt.Errorf("SearchProducers fuzzy: %w", err)
	}
	defer rows.Close()
	var out []SearchResult
	for rows.Next() {
		b, err := scanProducer(rows)
		if err != nil {
			return nil, fmt.Errorf("SearchProducers fuzzy scan: %w", err)
		}
		out = append(out, SearchResult{Type: "producer", Producer: b})
	}
	return out, rows.Err()
}
