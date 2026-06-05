package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

// UserBeverageRepo serves GET /v1/users/{username}/beverages — the
// distinct-beverage aggregation page across a single user's check-ins.
type UserBeverageRepo struct{ db *pgxpool.Pool }

// UserBeverageSort enumerates the four allowed sort axes for the
// user-beverages endpoint. The handler validates the request param
// against this set so a typo can't fall through to a panic.
type UserBeverageSort string

const (
	// SortUserBeverageRating sorts by the user's average rating, DESC,
	// NULLS LAST. Beverages where every one of the user's check-ins is
	// rating-less drop to the bottom of the page.
	SortUserBeverageRating UserBeverageSort = "rating"
	// SortUserBeverageProducer sorts by the producer's UUID (stable
	// surrogate for "group by producer"). ASC by default.
	SortUserBeverageProducer UserBeverageSort = "producer"
	// SortUserBeverageCategory sorts by category_slug. ASC by default.
	SortUserBeverageCategory UserBeverageSort = "category"
	// SortUserBeverageLastCheckin sorts by the user's most-recent
	// check-in on each beverage. DESC by default.
	SortUserBeverageLastCheckin UserBeverageSort = "last_checkin"
)

// UserBeverageRatingCursorScale is the integer multiplier the rating
// cursor uses to preserve sub-step precision in a single int64. The
// AVG of N 0.5-step ratings can land on awkward decimals (e.g.
// (4.5 + 4.0 + 4.0) / 3 = 4.166…) — three decimal places are plenty
// to keep the keyset stable. The SQL multiplies user_avg by the same
// scale and casts to bigint so the on-wire cursor value compares
// exactly to the column.
const UserBeverageRatingCursorScale = 1000

// UserBeverageRatingNullSentinel is the cursor value the encoder uses
// when the previous page's tail row had a NULL user_avg. -1 is safe:
// rating × scale is always non-negative for valid ratings.
const UserBeverageRatingNullSentinel int64 = -1

// UserBeveragesParams bundles the handler-validated inputs for one
// page request. Pointers hold "absent vs present"; the SQL guards
// with IS NULL so an absent filter is a wildcard. The Cursor* fields
// together form the keyset tail of the previous page.
type UserBeveragesParams struct {
	UserID       string
	CategorySlug *string
	ProducerID   *string
	MinRating    *float64
	Sort         UserBeverageSort
	SortDescDir  bool // true means DESC; false means ASC

	// Cursor decoded fields. Empty/nil for the first page.
	CursorRatingScaled *int64     // user_avg × UserBeverageRatingCursorScale or NullSentinel
	CursorTimestamp    *time.Time // last_checkin_at for the last-checkin sort
	CursorStringSort   *string    // producer_id (uuid) / category_slug for those sorts
	CursorID           *string    // beverage_id tiebreaker

	Limit int
}

// ListUserBeverages runs the aggregation page query. Single SQL
// statement, no N+1 — the per-row beverage projection joins
// `producers + beverage_categories + prefectures` in the same
// statement so caller-side hydration is unnecessary.
//
// Index coverage: the aggregation's WHERE / GROUP BY is satisfied by
// idx_check_ins_user_beverage (migration 007). Without that index the
// query falls back to a scan over idx_check_ins_user_created followed
// by an in-memory HashAggregate — fine at low user-check-in counts,
// but the explicit composite keeps the plan tight as users approach
// the four-figure check-in mark.
func (r *UserBeverageRepo) ListUserBeverages(ctx context.Context, p UserBeveragesParams) ([]domain.UserBeverageRow, error) {
	if p.Limit <= 0 {
		p.Limit = 20
	}

	orderBy, keyset := userBeverageSortClauses(p)

	q := `
WITH u AS (
  SELECT
    beverage_id,
    AVG(rating) FILTER (WHERE rating IS NOT NULL) AS user_avg,
    COUNT(*)                                       AS user_count,
    MAX(created_at)                                AS last_at
  FROM check_ins
  WHERE user_id = $1 AND deleted_at IS NULL
  GROUP BY beverage_id
)
SELECT
  b.id,
  b.name_i18n,
  b.category_slug,
  cat.name_i18n          AS category_name_i18n,
  b.label_image_url,
  br.id                  AS producer_id,
  br.name_i18n           AS producer_name_i18n,
  br.image_url           AS producer_image_url,` + producerPrefectureSelectCols + `,
  u.user_avg,
  u.user_count,
  u.last_at,
  b.avg_rating           AS global_avg,
  b.check_in_count       AS global_count
FROM u
JOIN beverages b           ON b.id = u.beverage_id AND b.deleted_at IS NULL
JOIN producers br          ON br.id = b.producer_id AND br.deleted_at IS NULL
JOIN beverage_categories cat ON cat.id = b.category_id` + producerPrefectureJoinClause + `
WHERE TRUE
  -- Type anchors for the optional keyset placeholders: pgx can't infer
  -- the SQL type of a Go nil unless the placeholder is referenced in
  -- the statement with an explicit cast. The keyset only references a
  -- subset of $5..$8 depending on the active sort axis; these no-op
  -- IS NULL OR IS NOT NULL clauses anchor every type so an unused
  -- placeholder doesn't 42P18 the prepared-statement.
  AND ($5::bigint IS NULL OR $5::bigint IS NOT NULL)
  AND ($6::timestamptz IS NULL OR $6::timestamptz IS NOT NULL)
  AND ($7::text IS NULL OR $7::text IS NOT NULL)
  AND ($8::uuid IS NULL OR $8::uuid IS NOT NULL)
  AND ($2::text IS NULL OR b.category_slug = $2)
  AND ($3::uuid IS NULL OR b.producer_id = $3)
  AND ($4::numeric IS NULL OR u.user_avg IS NOT NULL AND u.user_avg >= $4)
  ` + keyset + `
ORDER BY ` + orderBy + `
LIMIT $9;`

	rows, err := r.db.Query(ctx, q,
		p.UserID,             // $1
		p.CategorySlug,       // $2
		p.ProducerID,         // $3
		p.MinRating,          // $4
		p.CursorRatingScaled, // $5  — used by `rating` sort
		p.CursorTimestamp,    // $6  — used by `last_checkin` sort
		p.CursorStringSort,   // $7  — used by `producer` / `category` sort
		p.CursorID,           // $8  — beverage_id tiebreaker
		p.Limit+1,            // $9
	)
	if err != nil {
		return nil, fmt.Errorf("UserBeverageRepo.ListUserBeverages: %w", err)
	}
	defer rows.Close()

	out := make([]domain.UserBeverageRow, 0, p.Limit+1)
	for rows.Next() {
		row, err := scanUserBeverageRow(rows)
		if err != nil {
			return nil, fmt.Errorf("UserBeverageRepo.ListUserBeverages scan: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// scanUserBeverageRow reads one row of the user-beverages projection
// — beverage ref + per-user aggregates + global aggregates — into a
// hydrated domain.UserBeverageRow. The column order MUST match the
// SELECT list in ListUserBeverages.
func scanUserBeverageRow(rows rowScanner) (domain.UserBeverageRow, error) {
	var (
		row                                 domain.UserBeverageRow
		bevID                               string
		bevNameRaw, catNameRaw, prodNameRaw []byte
		bevSlug                             string
		bevLabelURL                         *string
		prodID                              string
		prodImgURL                          *string
		prodPref                            prefectureScan
		userAvg                             *float64
		userCount                           int64
		lastAt                              time.Time
		globalAvg                           *float64
		globalCount                         int64
	)
	prefArgs := prodPref.scanArgs()
	scanArgs := make([]any, 0, 13+len(prefArgs))
	scanArgs = append(scanArgs,
		&bevID,
		&bevNameRaw,
		&bevSlug,
		&catNameRaw,
		&bevLabelURL,
		&prodID,
		&prodNameRaw,
		&prodImgURL,
	)
	scanArgs = append(scanArgs, prefArgs...)
	scanArgs = append(scanArgs,
		&userAvg,
		&userCount,
		&lastAt,
		&globalAvg,
		&globalCount,
	)
	if err := rows.Scan(scanArgs...); err != nil {
		return row, err
	}
	bevName, _ := domain.I18nFromJSON(bevNameRaw)
	catName, _ := domain.I18nFromJSON(catNameRaw)
	prodName, _ := domain.I18nFromJSON(prodNameRaw)
	row.Beverage = domain.BeverageRef{
		ID:   bevID,
		Name: bevName,
		Producer: domain.ProducerRef{
			ID:         prodID,
			Name:       prodName,
			Prefecture: prodPref.toPrefecture(),
			ImageURL:   prodImgURL,
		},
		Category:      domain.CategoryLabel{Slug: bevSlug, LabelI18n: catName},
		LabelImageURL: bevLabelURL,
	}
	row.UserAvgRating = userAvg
	row.UserCheckinCount = int(userCount)
	row.LastCheckinAt = lastAt
	row.GlobalAvgRating = globalAvg
	row.GlobalCheckinCount = int(globalCount)
	return row, nil
}

// userBeverageSortClauses returns the ORDER BY tail and the cursor-
// keyset AND clause for the requested sort axis. They are returned as
// two strings so the caller can splice them into the canonical
// SELECT without rebuilding the rest of the statement.
//
// Every sort axis has a final tiebreaker on `b.id ASC` so the page
// boundary is deterministic. ASC tiebreaker (not DESC) is intentional:
// the next page must return rows strictly *after* the previous-page
// tail in scan order, regardless of the outer sort direction.
func userBeverageSortClauses(p UserBeveragesParams) (orderBy, keyset string) {
	const tieAsc = `b.id ASC`

	switch p.Sort {
	case SortUserBeverageProducer:
		if p.SortDescDir {
			orderBy = `b.producer_id DESC, ` + tieAsc
			keyset = `AND ($7::text IS NULL OR
                       b.producer_id::text < $7::text
                    OR (b.producer_id::text = $7::text AND b.id > $8::uuid))`
		} else {
			orderBy = `b.producer_id ASC, ` + tieAsc
			keyset = `AND ($7::text IS NULL OR
                       b.producer_id::text > $7::text
                    OR (b.producer_id::text = $7::text AND b.id > $8::uuid))`
		}
		return

	case SortUserBeverageCategory:
		if p.SortDescDir {
			orderBy = `b.category_slug DESC, ` + tieAsc
			keyset = `AND ($7::text IS NULL OR
                       b.category_slug < $7::text
                    OR (b.category_slug = $7::text AND b.id > $8::uuid))`
		} else {
			orderBy = `b.category_slug ASC, ` + tieAsc
			keyset = `AND ($7::text IS NULL OR
                       b.category_slug > $7::text
                    OR (b.category_slug = $7::text AND b.id > $8::uuid))`
		}
		return

	case SortUserBeverageLastCheckin:
		if !p.SortDescDir {
			orderBy = `u.last_at ASC, ` + tieAsc
			keyset = `AND ($6::timestamptz IS NULL OR
                       (u.last_at, b.id) > ($6::timestamptz, $8::uuid))`
		} else {
			orderBy = `u.last_at DESC, ` + tieAsc
			keyset = `AND ($6::timestamptz IS NULL OR
                       (u.last_at, b.id) < ($6::timestamptz, $8::uuid))`
		}
		return

	default:
		// SortUserBeverageRating (and the empty-string default).
		if p.SortDescDir || p.Sort == SortUserBeverageRating || p.Sort == "" {
			// DESC NULLS LAST.
			orderBy = `(u.user_avg IS NULL) ASC, u.user_avg DESC, ` + tieAsc
			keyset = `AND ($5::bigint IS NULL OR (
                CASE
                  WHEN $5::bigint = -1 THEN
                    u.user_avg IS NULL AND b.id > $8::uuid
                  ELSE
                    u.user_avg IS NULL
                    OR (u.user_avg IS NOT NULL AND (u.user_avg * 1000)::bigint < $5::bigint)
                    OR (u.user_avg IS NOT NULL AND (u.user_avg * 1000)::bigint = $5::bigint AND b.id > $8::uuid)
                END
              ))`
		} else {
			// ASC NULLS FIRST.
			orderBy = `(u.user_avg IS NULL) DESC, u.user_avg ASC, ` + tieAsc
			keyset = `AND ($5::bigint IS NULL OR (
                CASE
                  WHEN $5::bigint = -1 THEN
                    u.user_avg IS NOT NULL
                    OR (u.user_avg IS NULL AND b.id > $8::uuid)
                  ELSE
                    u.user_avg IS NOT NULL AND (
                      (u.user_avg * 1000)::bigint > $5::bigint
                      OR ((u.user_avg * 1000)::bigint = $5::bigint AND b.id > $8::uuid)
                    )
                END
              ))`
		}
		return
	}
}
