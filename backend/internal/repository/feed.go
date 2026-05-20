package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

type FeedRepo struct{ db *pgxpool.Pool }

// Page returns the feed page per query_patterns.md §3. Tags + photo counts
// are folded into the response. `limit` is the requested page size; the
// repository fetches limit+1 and the handler computes has_more.
func (r *FeedRepo) Page(ctx context.Context, viewerID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.FeedItem, error) {
	// Stage 5 (PERF-001/002/024): toast_count + comment_count come from
	// denormalized counter columns on check_ins (migration 011). Photos
	// are batch-hydrated after the rows.Next() loop via PhotosFor so the
	// feed ships actual photo URLs (not just a count). The only
	// remaining per-viewer correlated lookup is `you_toasted` — it
	// can't be denormalized because the answer is per-requesting-user.
	const q = `
SELECT
  ci.id,
  ci.rating,
  ci.review_text,
  ci.created_at,
  ci.user_id,
  u.username, u.display_username, u.display_name, u.avatar_url,
  ci.beverage_id,
  b.name_i18n,
  b.category_slug,
  b.label_image_url,
  cat.name_i18n,
  br.id, br.name_i18n, br.region,
  ci.toast_count,
  EXISTS(SELECT 1 FROM toasts tt WHERE tt.check_in_id = ci.id AND tt.user_id = $1),
  ci.comment_count,
  v.id, v.name, v.locality, v.country
FROM check_ins ci
JOIN follows f
  ON f.followed_id = ci.user_id
  AND f.follower_id = $1
  AND f.status = 'accepted'
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
JOIN beverages b ON b.id = ci.beverage_id
JOIN breweries br ON br.id = b.brewery_id
JOIN beverage_categories cat ON cat.id = b.category_id
LEFT JOIN venues v ON v.id = ci.venue_id
WHERE ci.deleted_at IS NULL
  AND ci.user_id <> $1
  AND ($2::timestamptz IS NULL OR (ci.created_at, ci.id) < ($2::timestamptz, $3::uuid))
ORDER BY ci.created_at DESC, ci.id DESC
LIMIT $4;`
	rows, err := r.db.Query(ctx, q, viewerID, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("FeedRepo.Page: %w", err)
	}
	defer rows.Close()

	items := make([]domain.FeedItem, 0, limit+1)
	ids := make([]string, 0, limit+1)
	for rows.Next() {
		var (
			it            domain.FeedItem
			bevName       []byte
			bevSlug       string
			bevLabel      *string
			catName       []byte
			brwName       []byte
			brwID         string
			brwRegion     *string
			toastCnt      int64
			commentCnt    int64
			youToast      bool
			userIDVal     string
			beverageID    string
			venueID       *string
			venueName     *string
			venueLocality *string
			venueCountry  *string
		)
		if err := rows.Scan(
			&it.ID,
			&it.Rating,
			&it.Review,
			&it.CreatedAt,
			&userIDVal,
			&it.User.Username, &it.User.DisplayUsername, &it.User.DisplayName, &it.User.AvatarURL,
			&beverageID,
			&bevName,
			&bevSlug,
			&bevLabel,
			&catName,
			&brwID, &brwName, &brwRegion,
			&toastCnt,
			&youToast,
			&commentCnt,
			&venueID, &venueName, &venueLocality, &venueCountry,
		); err != nil {
			return nil, fmt.Errorf("FeedRepo.Page scan: %w", err)
		}
		it.User.ID = userIDVal
		it.CommentCount = int(commentCnt)
		bn, _ := domain.I18nFromJSON(bevName)
		cn, _ := domain.I18nFromJSON(catName)
		rn, _ := domain.I18nFromJSON(brwName)
		it.Beverage = domain.BeverageRef{
			ID:            beverageID,
			Name:          bn,
			Brewery:       domain.BreweryRef{ID: brwID, Name: rn, Region: brwRegion},
			Category:      domain.CategoryLabel{Slug: bevSlug, LabelI18n: cn},
			LabelImageURL: bevLabel,
		}
		it.Toasts = int(toastCnt)
		it.YouToasted = youToast
		if venueID != nil && venueName != nil {
			it.Venue = &domain.VenueRef{ID: *venueID, Name: *venueName, Locality: venueLocality, Country: venueCountry}
		}
		items = append(items, it)
		ids = append(ids, it.ID)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Hydrate tags + photos in two batch queries (one round trip each).
	// Photos pre-Stage 5 only shipped a count on the feed — the new
	// PhotoRef slice lets the Flutter card render the actual grid.
	ck := CheckinRepo{db: r.db}
	tags, err := ck.TagsFor(ctx, ids)
	if err != nil {
		return nil, err
	}
	photos, err := ck.PhotosFor(ctx, ids)
	if err != nil {
		return nil, err
	}
	for i := range items {
		items[i].Tags = tags[items[i].ID]
		if items[i].Tags == nil {
			items[i].Tags = []domain.FlavorTag{}
		}
		items[i].Photos = photos[items[i].ID]
		if items[i].Photos == nil {
			items[i].Photos = []domain.PhotoRef{}
		}
	}
	return items, nil
}
