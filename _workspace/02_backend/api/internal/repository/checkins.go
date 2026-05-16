package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/kamos/api/internal/apierror"
	"github.com/kamos/api/internal/domain"
)

type CheckinRepo struct{ db *pgxpool.Pool }

// CreateCheckinParams is the repository-layer shape — fields are already
// validated by the handler.
type CreateCheckinParams struct {
	UserID       string
	BeverageID   string
	Rating       *float64
	ReviewText   *string
	PriceAmount  *float64
	PriceCcy     *string
	PriceUnit    *string
	PurchaseType *string
	ServingStyle *string
	PhotoURLs    []string
	TagSlugs     []string
	// VenueID is the optional Phase-4 venue FK. nil = no venue.
	VenueID *string
}

// Create inserts the check-in row, photos, and flavor tags atomically. The
// avg_rating / check_in_count trigger fires on COMMIT.
func (r *CheckinRepo) Create(ctx context.Context, p CreateCheckinParams) (string, time.Time, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("CheckinRepo.Create: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const ins = `
INSERT INTO check_ins (
  user_id, beverage_id,
  rating, review_text,
  price_amount, price_currency, price_unit,
  purchase_type, serving_style,
  venue_id
) VALUES (
  $1, $2,
  $3, $4,
  $5, $6, $7,
  $8, $9,
  $10
)
RETURNING id, created_at;`
	var id string
	var createdAt time.Time
	if err := tx.QueryRow(ctx, ins,
		p.UserID, p.BeverageID,
		p.Rating, p.ReviewText,
		p.PriceAmount, p.PriceCcy, p.PriceUnit,
		p.PurchaseType, p.ServingStyle,
		p.VenueID,
	).Scan(&id, &createdAt); err != nil {
		return "", time.Time{}, fmt.Errorf("CheckinRepo.Create insert: %w", err)
	}

	for i, url := range p.PhotoURLs {
		if i >= 4 {
			return "", time.Time{}, apierror.ErrPhotoCapExceeded
		}
		const insPh = `INSERT INTO check_in_photos (check_in_id, photo_url, sort_order) VALUES ($1, $2, $3);`
		if _, err := tx.Exec(ctx, insPh, id, url, i); err != nil {
			return "", time.Time{}, fmt.Errorf("CheckinRepo.Create photo: %w", err)
		}
	}

	if len(p.TagSlugs) > 0 {
		const insTags = `
INSERT INTO check_in_flavor_tags (check_in_id, flavor_tag_id)
SELECT $1, ft.id FROM flavor_tags ft WHERE ft.slug = ANY($2)
ON CONFLICT DO NOTHING;`
		if _, err := tx.Exec(ctx, insTags, id, p.TagSlugs); err != nil {
			return "", time.Time{}, fmt.Errorf("CheckinRepo.Create tags: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return "", time.Time{}, fmt.Errorf("CheckinRepo.Create commit: %w", err)
	}
	return id, createdAt, nil
}

// Get returns a single check-in, fully hydrated for the API response. The
// `viewerID` is used to evaluate `you_toasted` and may be empty for unauthed
// reads. Returns NotFound when the check-in is soft-deleted or non-existent.
func (r *CheckinRepo) Get(ctx context.Context, id, viewerID string) (*domain.Checkin, error) {
	const q = `
SELECT
  ci.id, ci.user_id, ci.beverage_id,
  ci.rating, ci.review_text,
  ci.price_amount, ci.price_currency, ci.price_unit,
  ci.purchase_type, ci.serving_style,
  ci.created_at, ci.updated_at,
  u.username, u.display_username, u.display_name, u.avatar_url, u.privacy_mode,
  b.name_i18n, b.category_slug, b.label_image_url,
  cat.name_i18n AS category_name_i18n,
  br.id AS brewery_id, br.name_i18n AS brewery_name_i18n, br.region AS brewery_region,
  v.id AS venue_id, v.name AS venue_name, v.locality AS venue_locality, v.country AS venue_country,
  (SELECT COUNT(*) FROM toasts WHERE check_in_id = ci.id) AS toasts,
  EXISTS(SELECT 1 FROM toasts WHERE check_in_id = ci.id AND user_id = NULLIF($2, '')::uuid) AS you_toasted,
  -- Phase 6a comment_count projection.
  (SELECT COUNT(*) FROM comments cm WHERE cm.check_in_id = ci.id AND cm.deleted_at IS NULL) AS comment_count
FROM check_ins ci
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
JOIN beverages b ON b.id = ci.beverage_id
JOIN breweries br ON br.id = b.brewery_id
JOIN beverage_categories cat ON cat.id = b.category_id
LEFT JOIN venues v ON v.id = ci.venue_id
WHERE ci.id = $1 AND ci.deleted_at IS NULL;`

	row := r.db.QueryRow(ctx, q, id, viewerID)
	var (
		c             domain.Checkin
		priceAmount   *float64
		priceCcy      *string
		priceUnit     *string
		bevName       []byte
		bevCatSlug    string
		bevLabel      *string
		catNameJSON   []byte
		brwName       []byte
		brwRegion     *string
		brwID         string
		userPrivacy   string
		userIDVal     string
		bevIDVal      string
		venueID       *string
		venueName     *string
		venueLocality *string
		venueCountry  *string
		toasts        int64
		youToasted    bool
		commentCnt    int64
	)
	err := row.Scan(
		&c.ID, &userIDVal, &bevIDVal,
		&c.Rating, &c.Review,
		&priceAmount, &priceCcy, &priceUnit,
		&c.PurchaseType, &c.ServingStyle,
		&c.CreatedAt, &c.UpdatedAt,
		&c.User.Username, &c.User.DisplayUsername, &c.User.DisplayName, &c.User.AvatarURL, &userPrivacy,
		&bevName, &bevCatSlug, &bevLabel,
		&catNameJSON,
		&brwID, &brwName, &brwRegion,
		&venueID, &venueName, &venueLocality, &venueCountry,
		&toasts, &youToasted, &commentCnt,
	)
	if err != nil {
		return nil, wrapNoRows("CheckinRepo.Get", err)
	}
	c.CommentCount = int(commentCnt)
	if venueID != nil && venueName != nil {
		c.Venue = &domain.VenueRef{
			ID:       *venueID,
			Name:     *venueName,
			Locality: venueLocality,
			Country:  venueCountry,
		}
	}
	c.User.ID = userIDVal
	c.Toasts = int(toasts)
	c.YouToasted = youToasted

	bn, _ := domain.I18nFromJSON(bevName)
	cn, _ := domain.I18nFromJSON(catNameJSON)
	rn, _ := domain.I18nFromJSON(brwName)
	c.Beverage = domain.BeverageRef{
		ID:            bevIDVal,
		Name:          bn,
		Brewery:       domain.BreweryRef{ID: brwID, Name: rn, Region: brwRegion},
		Category:      domain.CategoryLabel{Slug: bevCatSlug, LabelI18n: cn},
		LabelImageURL: bevLabel,
	}
	if priceAmount != nil && priceCcy != nil && priceUnit != nil {
		c.Price = &domain.Price{Amount: *priceAmount, Currency: *priceCcy, Mode: *priceUnit}
	}

	// Hydrate photos + tags via batched fetches.
	photos, err := r.PhotosFor(ctx, []string{id})
	if err != nil {
		return nil, err
	}
	c.Photos = photos[id]

	tags, err := r.TagsFor(ctx, []string{id})
	if err != nil {
		return nil, err
	}
	c.Tags = tags[id]
	if c.Tags == nil {
		c.Tags = []domain.FlavorTag{}
	}
	if c.Photos == nil {
		c.Photos = []domain.PhotoRef{}
	}

	// Privacy: if the owner is private and the viewer is not the owner and
	// not an accepted follower, return NotFound (we do not leak existence).
	if userPrivacy == "private" && viewerID != userIDVal {
		ok, err := isAcceptedFollower(ctx, r.db, viewerID, userIDVal)
		if err != nil {
			return nil, err
		}
		if !ok {
			return nil, apierror.ErrNotFound
		}
	}
	return &c, nil
}

// PhotosFor returns photos keyed by check_in_id, sort_order asc.
func (r *CheckinRepo) PhotosFor(ctx context.Context, ids []string) (map[string][]domain.PhotoRef, error) {
	if len(ids) == 0 {
		return map[string][]domain.PhotoRef{}, nil
	}
	const q = `
SELECT check_in_id, photo_url, sort_order
FROM check_in_photos
WHERE check_in_id = ANY($1)
ORDER BY sort_order;`
	rows, err := r.db.Query(ctx, q, ids)
	if err != nil {
		return nil, fmt.Errorf("PhotosFor: %w", err)
	}
	defer rows.Close()
	out := make(map[string][]domain.PhotoRef, len(ids))
	for rows.Next() {
		var ciID, url string
		var so int
		if err := rows.Scan(&ciID, &url, &so); err != nil {
			return nil, fmt.Errorf("PhotosFor scan: %w", err)
		}
		out[ciID] = append(out[ciID], domain.PhotoRef{URL: url, SortOrder: so})
	}
	return out, rows.Err()
}

// TagsFor returns flavor tags keyed by check_in_id.
func (r *CheckinRepo) TagsFor(ctx context.Context, ids []string) (map[string][]domain.FlavorTag, error) {
	if len(ids) == 0 {
		return map[string][]domain.FlavorTag{}, nil
	}
	const q = `
SELECT cift.check_in_id, ft.id, ft.slug, ft.dimension, ft.name_i18n
FROM check_in_flavor_tags cift
JOIN flavor_tags ft ON ft.id = cift.flavor_tag_id
WHERE cift.check_in_id = ANY($1)
ORDER BY ft.dimension, ft.sort_order;`
	rows, err := r.db.Query(ctx, q, ids)
	if err != nil {
		return nil, fmt.Errorf("TagsFor: %w", err)
	}
	defer rows.Close()
	out := make(map[string][]domain.FlavorTag, len(ids))
	for rows.Next() {
		var ciID string
		var t domain.FlavorTag
		var nameJSON []byte
		if err := rows.Scan(&ciID, &t.ID, &t.Slug, &t.Dimension, &nameJSON); err != nil {
			return nil, fmt.Errorf("TagsFor scan: %w", err)
		}
		t.Name, _ = domain.I18nFromJSON(nameJSON)
		out[ciID] = append(out[ciID], t)
	}
	return out, rows.Err()
}

// Update applies a partial edit. The handler has already rejected attempts
// to change beverage_id (SPEC §4.4). The function returns ErrForbidden when
// the row is not owned by the user.
type UpdateCheckinParams struct {
	ID           string
	UserID       string
	Rating       *float64
	ClearRating  bool
	Review       *string
	ClearReview  bool
	PriceAmount  *float64
	PriceCcy     *string
	PriceUnit    *string
	ClearPrice   bool
	PurchaseType *string
	ServingStyle *string
	Tags         *[]string // nil = no change; non-nil (even empty) = replace
}

func (r *CheckinRepo) Update(ctx context.Context, p UpdateCheckinParams) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("CheckinRepo.Update: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Verify ownership and liveness first; lock the row.
	var owner string
	err = tx.QueryRow(ctx,
		`SELECT user_id FROM check_ins WHERE id = $1 AND deleted_at IS NULL FOR UPDATE;`,
		p.ID).Scan(&owner)
	if errors.Is(err, pgx.ErrNoRows) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("CheckinRepo.Update lock: %w", err)
	}
	if owner != p.UserID {
		return apierror.ErrForbidden
	}

	const q = `
UPDATE check_ins SET
  rating         = CASE WHEN $2::boolean THEN NULL
                        WHEN $3::numeric IS NULL THEN rating
                        ELSE $3::numeric END,
  review_text    = CASE WHEN $4::boolean THEN NULL
                        WHEN $5::text IS NULL THEN review_text
                        ELSE $5::text END,
  price_amount   = CASE WHEN $6::boolean THEN NULL
                        WHEN $7::numeric IS NULL THEN price_amount
                        ELSE $7::numeric END,
  price_currency = CASE WHEN $6::boolean THEN NULL
                        WHEN $8::text IS NULL THEN price_currency
                        ELSE $8::text END,
  price_unit     = CASE WHEN $6::boolean THEN NULL
                        WHEN $9::text IS NULL THEN price_unit
                        ELSE $9::text END,
  purchase_type  = COALESCE($10, purchase_type),
  serving_style  = COALESCE($11, serving_style)
WHERE id = $1 AND deleted_at IS NULL;`
	if _, err := tx.Exec(ctx, q,
		p.ID,
		p.ClearRating, p.Rating,
		p.ClearReview, p.Review,
		p.ClearPrice, p.PriceAmount, p.PriceCcy, p.PriceUnit,
		p.PurchaseType, p.ServingStyle,
	); err != nil {
		return fmt.Errorf("CheckinRepo.Update: %w", err)
	}

	if p.Tags != nil {
		if _, err := tx.Exec(ctx, `DELETE FROM check_in_flavor_tags WHERE check_in_id = $1;`, p.ID); err != nil {
			return fmt.Errorf("CheckinRepo.Update tags clear: %w", err)
		}
		if len(*p.Tags) > 0 {
			const insTags = `
INSERT INTO check_in_flavor_tags (check_in_id, flavor_tag_id)
SELECT $1, ft.id FROM flavor_tags ft WHERE ft.slug = ANY($2)
ON CONFLICT DO NOTHING;`
			if _, err := tx.Exec(ctx, insTags, p.ID, *p.Tags); err != nil {
				return fmt.Errorf("CheckinRepo.Update tags insert: %w", err)
			}
		}
	}

	return tx.Commit(ctx)
}

// SoftDelete marks the row deleted; the trigger recomputes the beverage's
// avg_rating and check_in_count.
func (r *CheckinRepo) SoftDelete(ctx context.Context, id, userID string) error {
	const q = `
UPDATE check_ins SET deleted_at = NOW()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id;`
	var got string
	if err := r.db.QueryRow(ctx, q, id, userID).Scan(&got); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Either gone or not owned.
			var ownedByOther bool
			_ = r.db.QueryRow(ctx,
				`SELECT EXISTS(SELECT 1 FROM check_ins WHERE id = $1 AND deleted_at IS NULL);`, id,
			).Scan(&ownedByOther)
			if ownedByOther {
				return apierror.ErrForbidden
			}
			return apierror.ErrNotFound
		}
		return fmt.Errorf("CheckinRepo.SoftDelete: %w", err)
	}
	return nil
}

// AddPhoto inserts a single photo into the next free slot. Returns
// ErrPhotoCapExceeded if all four slots are taken.
func (r *CheckinRepo) AddPhoto(ctx context.Context, checkinID, userID, photoURL string) (domain.PhotoRef, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.PhotoRef{}, fmt.Errorf("AddPhoto: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var owner string
	err = tx.QueryRow(ctx,
		`SELECT user_id FROM check_ins WHERE id = $1 AND deleted_at IS NULL FOR UPDATE;`,
		checkinID).Scan(&owner)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.PhotoRef{}, apierror.ErrNotFound
	}
	if err != nil {
		return domain.PhotoRef{}, fmt.Errorf("AddPhoto lock: %w", err)
	}
	if owner != userID {
		return domain.PhotoRef{}, apierror.ErrForbidden
	}

	var existing int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*) FROM check_in_photos WHERE check_in_id = $1;`, checkinID).Scan(&existing); err != nil {
		return domain.PhotoRef{}, fmt.Errorf("AddPhoto count: %w", err)
	}
	if existing >= 4 {
		return domain.PhotoRef{}, apierror.ErrPhotoCapExceeded
	}

	var sortOrder int
	if err := tx.QueryRow(ctx,
		`SELECT COALESCE(MAX(sort_order), -1) + 1 FROM check_in_photos WHERE check_in_id = $1;`,
		checkinID).Scan(&sortOrder); err != nil {
		return domain.PhotoRef{}, fmt.Errorf("AddPhoto next: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO check_in_photos (check_in_id, photo_url, sort_order) VALUES ($1, $2, $3);`,
		checkinID, photoURL, sortOrder); err != nil {
		return domain.PhotoRef{}, fmt.Errorf("AddPhoto insert: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.PhotoRef{}, fmt.Errorf("AddPhoto commit: %w", err)
	}
	return domain.PhotoRef{URL: photoURL, SortOrder: sortOrder}, nil
}

// ToggleToast inserts-or-deletes the row, returning the fresh state.
func (r *CheckinRepo) ToggleToast(ctx context.Context, userID, checkinID string) (domain.ToastState, error) {
	// First, ensure visibility per private-account rules.
	if err := r.checkVisibility(ctx, userID, checkinID); err != nil {
		return domain.ToastState{}, err
	}

	// Toggle: delete if exists, otherwise insert. We do this in a single tx.
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.ToastState{}, fmt.Errorf("ToggleToast: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var existed bool
	if err := tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM toasts WHERE user_id = $1 AND check_in_id = $2);`,
		userID, checkinID).Scan(&existed); err != nil {
		return domain.ToastState{}, fmt.Errorf("ToggleToast exists: %w", err)
	}
	if existed {
		if _, err := tx.Exec(ctx,
			`DELETE FROM toasts WHERE user_id = $1 AND check_in_id = $2;`, userID, checkinID); err != nil {
			return domain.ToastState{}, fmt.Errorf("ToggleToast delete: %w", err)
		}
	} else {
		if _, err := tx.Exec(ctx,
			`INSERT INTO toasts (user_id, check_in_id) VALUES ($1, $2) ON CONFLICT DO NOTHING;`,
			userID, checkinID); err != nil {
			return domain.ToastState{}, fmt.Errorf("ToggleToast insert: %w", err)
		}
	}

	var s domain.ToastState
	var cnt int64
	if err := tx.QueryRow(ctx, `
SELECT
  (SELECT COUNT(*) FROM toasts WHERE check_in_id = $2),
  EXISTS (SELECT 1 FROM toasts WHERE check_in_id = $2 AND user_id = $1);`,
		userID, checkinID).Scan(&cnt, &s.YouToasted); err != nil {
		return domain.ToastState{}, fmt.Errorf("ToggleToast count: %w", err)
	}
	s.Toasts = int(cnt)
	if err := tx.Commit(ctx); err != nil {
		return domain.ToastState{}, fmt.Errorf("ToggleToast commit: %w", err)
	}
	return s, nil
}

// checkVisibility implements the privacy gate from query_patterns.md §4.
// Returns nil if the check-in is visible to the viewer; ErrNotFound otherwise.
func (r *CheckinRepo) checkVisibility(ctx context.Context, viewerID, checkinID string) error {
	const q = `
SELECT 1
FROM check_ins ci
JOIN users u ON u.id = ci.user_id
WHERE ci.id = $1
  AND ci.deleted_at IS NULL
  AND (
    u.privacy_mode = 'public'
    OR u.id = $2
    OR EXISTS (
      SELECT 1 FROM follows f
      WHERE f.follower_id = $2 AND f.followed_id = u.id AND f.status = 'accepted'
    )
  )
LIMIT 1;`
	var one int
	if err := r.db.QueryRow(ctx, q, checkinID, viewerID).Scan(&one); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return apierror.ErrNotFound
		}
		return fmt.Errorf("checkVisibility: %w", err)
	}
	return nil
}

// UserCheckins returns a paginated list of check-ins for a user, applying
// the same privacy gate as the feed. `viewerID` may be empty for unauthed
// reads (only public profiles will return rows).
func (r *CheckinRepo) UserCheckins(ctx context.Context, viewerID, targetID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Checkin, error) {
	const q = `
SELECT
  ci.id, ci.user_id, ci.beverage_id,
  ci.rating, ci.review_text,
  ci.price_amount, ci.price_currency, ci.price_unit,
  ci.purchase_type, ci.serving_style,
  ci.created_at, ci.updated_at,
  u.username, u.display_username, u.display_name, u.avatar_url, u.privacy_mode,
  b.name_i18n, b.category_slug, b.label_image_url,
  cat.name_i18n AS category_name_i18n,
  br.id, br.name_i18n, br.region,
  v.id, v.name, v.locality, v.country,
  (SELECT COUNT(*) FROM toasts WHERE check_in_id = ci.id),
  EXISTS(SELECT 1 FROM toasts WHERE check_in_id = ci.id AND user_id = NULLIF($2, '')::uuid),
  -- Phase 6a comment_count.
  (SELECT COUNT(*) FROM comments cm WHERE cm.check_in_id = ci.id AND cm.deleted_at IS NULL)
FROM check_ins ci
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
JOIN beverages b ON b.id = ci.beverage_id
JOIN breweries br ON br.id = b.brewery_id
JOIN beverage_categories cat ON cat.id = b.category_id
LEFT JOIN venues v ON v.id = ci.venue_id
WHERE ci.user_id = $1
  AND ci.deleted_at IS NULL
  AND (
    u.privacy_mode = 'public'
    OR u.id = NULLIF($2,'')::uuid
    OR EXISTS (
      SELECT 1 FROM follows f
      WHERE f.follower_id = NULLIF($2,'')::uuid AND f.followed_id = u.id AND f.status = 'accepted'
    )
  )
  AND ($3::timestamptz IS NULL OR (ci.created_at, ci.id::text) < ($3::timestamptz, $4::text))
ORDER BY ci.created_at DESC, ci.id DESC
LIMIT $5;`
	rows, err := r.db.Query(ctx, q, targetID, viewerID, cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("UserCheckins: %w", err)
	}
	defer rows.Close()
	out := make([]domain.Checkin, 0, limit+1)
	ids := make([]string, 0, limit+1)
	for rows.Next() {
		var c domain.Checkin
		var (
			priceAmount               *float64
			priceCcy, priceUnit       *string
			bevName, catName          []byte
			brwName                   []byte
			bevSlug                   string
			bevLabel, brwRegion       *string
			brwID, userIDVal, bevID   string
			venueID, venueName        *string
			venueLocality, venueCtry  *string
			toastCnt                  int64
			youToast                  bool
			userPrivacy               string
			commentCnt                int64
		)
		if err := rows.Scan(
			&c.ID, &userIDVal, &bevID,
			&c.Rating, &c.Review,
			&priceAmount, &priceCcy, &priceUnit,
			&c.PurchaseType, &c.ServingStyle,
			&c.CreatedAt, &c.UpdatedAt,
			&c.User.Username, &c.User.DisplayUsername, &c.User.DisplayName, &c.User.AvatarURL, &userPrivacy,
			&bevName, &bevSlug, &bevLabel,
			&catName,
			&brwID, &brwName, &brwRegion,
			&venueID, &venueName, &venueLocality, &venueCtry,
			&toastCnt, &youToast, &commentCnt,
		); err != nil {
			return nil, fmt.Errorf("UserCheckins scan: %w", err)
		}
		c.User.ID = userIDVal
		c.Toasts = int(toastCnt)
		c.YouToasted = youToast
		c.CommentCount = int(commentCnt)
		n, _ := domain.I18nFromJSON(bevName)
		cn, _ := domain.I18nFromJSON(catName)
		brn, _ := domain.I18nFromJSON(brwName)
		c.Beverage = domain.BeverageRef{
			ID:            bevID,
			Name:          n,
			Brewery:       domain.BreweryRef{ID: brwID, Name: brn, Region: brwRegion},
			Category:      domain.CategoryLabel{Slug: bevSlug, LabelI18n: cn},
			LabelImageURL: bevLabel,
		}
		if priceAmount != nil && priceCcy != nil && priceUnit != nil {
			c.Price = &domain.Price{Amount: *priceAmount, Currency: *priceCcy, Mode: *priceUnit}
		}
		if venueID != nil && venueName != nil {
			c.Venue = &domain.VenueRef{
				ID:       *venueID,
				Name:     *venueName,
				Locality: venueLocality,
				Country:  venueCtry,
			}
		}
		out = append(out, c)
		ids = append(ids, c.ID)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	// Hydrate photos + tags in batches.
	photos, err := r.PhotosFor(ctx, ids)
	if err != nil {
		return nil, err
	}
	tags, err := r.TagsFor(ctx, ids)
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

// isAcceptedFollower is a shared helper used by the privacy gate.
func isAcceptedFollower(ctx context.Context, db *pgxpool.Pool, viewerID, ownerID string) (bool, error) {
	if viewerID == "" {
		return false, nil
	}
	const q = `SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id = $1 AND followed_id = $2 AND status = 'accepted');`
	var ok bool
	if err := db.QueryRow(ctx, q, viewerID, ownerID).Scan(&ok); err != nil {
		return false, fmt.Errorf("isAcceptedFollower: %w", err)
	}
	return ok, nil
}

// AssertViewerCanSeeCheckin is the shared visibility gate for surfaces
// that hang off a check-in (e.g. `GET /v1/check-ins/{id}/comments`).
// Returns nil when the caller is allowed to see the check-in (matching
// the rule applied inside Get); ErrNotFound otherwise.
//
// The rule (mirrors Get exactly):
//   - Row missing, parent soft-deleted, or owner soft-deleted → ErrNotFound.
//   - Owner of the check-in is private AND viewer is not the owner AND
//     not an accepted follower → ErrNotFound (do not leak existence).
//   - All other cases → nil.
//
// The `ci.deleted_at IS NULL` filter is what gives a moderator's
// soft-delete the same effect on the comment surface as it has on the
// check-in detail surface — without this filter, the comments around
// a hidden check-in would remain world-readable, defeating the
// moderation action.
func (r *CheckinRepo) AssertViewerCanSeeCheckin(ctx context.Context, checkInID, viewerID string) error {
	const q = `SELECT user_id, privacy_mode FROM check_ins ci
JOIN users u ON u.id = ci.user_id
WHERE ci.id = $1 AND ci.deleted_at IS NULL AND u.deleted_at IS NULL;`
	var ownerID, privacy string
	if err := r.db.QueryRow(ctx, q, checkInID).Scan(&ownerID, &privacy); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return apierror.ErrNotFound
		}
		return fmt.Errorf("AssertViewerCanSeeCheckin: %w", err)
	}
	if privacy == "private" && viewerID != ownerID {
		ok, err := isAcceptedFollower(ctx, r.db, viewerID, ownerID)
		if err != nil {
			return err
		}
		if !ok {
			return apierror.ErrNotFound
		}
	}
	return nil
}
