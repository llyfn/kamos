package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

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
  purchase_type,
  venue_id
) VALUES (
  $1, $2,
  $3, $4,
  $5, $6, $7,
  $8,
  $9
)
RETURNING id, created_at;`
	var id string
	var createdAt time.Time
	if err := tx.QueryRow(ctx, ins,
		p.UserID, p.BeverageID,
		p.Rating, p.ReviewText,
		p.PriceAmount, p.PriceCcy, p.PriceUnit,
		p.PurchaseType,
		p.VenueID,
	).Scan(&id, &createdAt); err != nil {
		return "", time.Time{}, fmt.Errorf("CheckinRepo.Create insert: %w", err)
	}

	// Stage 5 (PERF-009): one multi-row INSERT for all photos instead
	// of N round-trips. unnest($2, $3) zips the URL array with a
	// generated sort_order series. Slice B / SPEC §4.1: submission is
	// capped at 1 photo (enforced both by
	// domain.CreateCheckinRequest.Validate at the handler edge and
	// here as defense-in-depth). The DB's check_in_photos_sort_order
	// CHECK still tolerates the historical 0..3 range so existing
	// multi-photo check-ins remain readable.
	if len(p.PhotoURLs) > 1 {
		return "", time.Time{}, domain.ErrPhotoCapExceeded
	}
	if len(p.PhotoURLs) > 0 {
		sortOrders := make([]int32, len(p.PhotoURLs))
		for i := range p.PhotoURLs {
			sortOrders[i] = int32(i)
		}
		const insPh = `
INSERT INTO check_in_photos (check_in_id, photo_url, sort_order)
SELECT $1, url, ord
FROM unnest($2::text[], $3::int[]) AS u(url, ord);`
		if _, err := tx.Exec(ctx, insPh, id, p.PhotoURLs, sortOrders); err != nil {
			return "", time.Time{}, fmt.Errorf("CheckinRepo.Create photos: %w", err)
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
  ci.purchase_type,
  ci.created_at, ci.updated_at, ci.edited_at,
  u.username, u.display_username, u.display_name, u.avatar_url, u.privacy_mode,
  b.name_i18n, b.category_slug, b.label_image_url,
  cat.name_i18n AS category_name_i18n,
  br.id AS producer_id, br.name_i18n AS producer_name_i18n, br.image_url AS producer_image_url,` + producerPrefectureSelectCols + `,
  v.id AS venue_id, v.name AS venue_name, v.locality AS venue_locality, v.country AS venue_country,
  ci.toast_count AS toasts,
  EXISTS(SELECT 1 FROM toasts WHERE check_in_id = ci.id AND user_id = NULLIF($2, '')::uuid) AS you_toasted,
  ci.comment_count
FROM check_ins ci
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
JOIN beverages b ON b.id = ci.beverage_id
JOIN producers br ON br.id = b.producer_id
JOIN beverage_categories cat ON cat.id = b.category_id` + producerPrefectureJoinClause + `
LEFT JOIN venues v ON v.id = ci.venue_id
WHERE ci.id = $1 AND ci.deleted_at IS NULL;`

	c, userPrivacy, err := scanCheckinRow(r.db.QueryRow(ctx, q, id, viewerID))
	if err != nil {
		return nil, wrapNoRows("CheckinRepo.Get", err)
	}
	out := []domain.Checkin{c}
	if err := r.hydrateCheckinTagsAndPhotos(ctx, out, []string{c.ID}); err != nil {
		return nil, err
	}
	c = out[0]
	// Privacy: if the owner is private and the viewer is not the owner and
	// not an accepted follower, return NotFound (we do not leak existence).
	if userPrivacy == "private" && viewerID != c.User.ID {
		ok, err := isAcceptedFollower(ctx, r.db, viewerID, c.User.ID)
		if err != nil {
			return nil, err
		}
		if !ok {
			return nil, domain.ErrNotFound
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
	Tags         *[]string // nil = no change; non-nil (even empty) = replace
	// AddPhotoURLs are public URLs already resolved by the service layer
	// (via PhotoUploadRepo.FindByID + Storage.PublicURL) that should be
	// appended to the check-in. They land at the next free sort_order.
	AddPhotoURLs []string
	// AddPhotoUploadIDs are the matching photo_uploads.id values; the
	// repository flips them to 'attached' inside the same TX.
	AddPhotoUploadIDs []string
	// RemovePhotoURLs are existing PhotoRef.URL values to detach. The
	// repository scopes the DELETE to (check_in_id, photo_url IN (...)).
	RemovePhotoURLs []string
	// TouchEdited toggles the `edited_at = NOW()` write. The service
	// layer owns the "did anything actually change?" decision — see
	// docs/db/query_patterns.md §7. A no-op PATCH must leave edited_at
	// untouched so the "edited" marker doesn't flicker on save.
	TouchEdited bool
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
		return domain.ErrNotFound
	}
	if err != nil {
		return fmt.Errorf("CheckinRepo.Update lock: %w", err)
	}
	if owner != p.UserID {
		return domain.ErrForbidden
	}

	// Scalar update + edited_at touch in one statement. The inline-CASE
	// pattern matches query_patterns.md §7: edited_at flips only when
	// the service signaled at least one tracked-field change.
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
  edited_at      = CASE WHEN $11::boolean THEN NOW() ELSE edited_at END
WHERE id = $1 AND deleted_at IS NULL;`
	if _, err := tx.Exec(ctx, q,
		p.ID,
		p.ClearRating, p.Rating,
		p.ClearReview, p.Review,
		p.ClearPrice, p.PriceAmount, p.PriceCcy, p.PriceUnit,
		p.PurchaseType,
		p.TouchEdited,
	); err != nil {
		return fmt.Errorf("CheckinRepo.Update: %w", err)
	}

	if err := r.applyTagReplacement(ctx, tx, p.ID, p.Tags); err != nil {
		return err
	}
	if err := r.applyPhotoEdits(ctx, tx, p); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// applyTagReplacement implements the present-replaces / absent-leaves
// semantics from query_patterns.md §7. Nil means "no change"; non-nil
// (even empty) replaces the junction rows.
func (r *CheckinRepo) applyTagReplacement(ctx context.Context, tx pgx.Tx, checkinID string, tags *[]string) error {
	if tags == nil {
		return nil
	}
	if _, err := tx.Exec(ctx, `DELETE FROM check_in_flavor_tags WHERE check_in_id = $1;`, checkinID); err != nil {
		return fmt.Errorf("CheckinRepo.Update tags clear: %w", err)
	}
	if len(*tags) == 0 {
		return nil
	}
	const insTags = `
INSERT INTO check_in_flavor_tags (check_in_id, flavor_tag_id)
SELECT $1, ft.id FROM flavor_tags ft WHERE ft.slug = ANY($2)
ON CONFLICT DO NOTHING;`
	if _, err := tx.Exec(ctx, insTags, checkinID, *tags); err != nil {
		return fmt.Errorf("CheckinRepo.Update tags insert: %w", err)
	}
	return nil
}

// applyPhotoEdits removes detached URLs and appends the new ones. Remove
// runs first so the next-sort_order math reflects the post-removal floor.
// The photo_uploads rows are flipped to 'attached' in the same TX so the
// orphan-cleanup job leaves them alone. The DB CHECK on sort_order is
// the backstop — the service layer enforces the SPEC §4.1 1-photo
// submission cap pre-write so callers see the canonical
// PHOTO_CAP_EXCEEDED 422.
func (r *CheckinRepo) applyPhotoEdits(ctx context.Context, tx pgx.Tx, p UpdateCheckinParams) error {
	if len(p.RemovePhotoURLs) > 0 {
		if _, err := tx.Exec(ctx,
			`DELETE FROM check_in_photos WHERE check_in_id = $1 AND photo_url = ANY($2);`,
			p.ID, p.RemovePhotoURLs); err != nil {
			return fmt.Errorf("CheckinRepo.Update photos remove: %w", err)
		}
	}
	if len(p.AddPhotoURLs) == 0 {
		return nil
	}
	var next int
	if err := tx.QueryRow(ctx,
		`SELECT COALESCE(MAX(sort_order), -1) + 1 FROM check_in_photos WHERE check_in_id = $1;`,
		p.ID).Scan(&next); err != nil {
		return fmt.Errorf("CheckinRepo.Update photos sort_order: %w", err)
	}
	sortOrders := make([]int32, len(p.AddPhotoURLs))
	for i := range p.AddPhotoURLs {
		// Submission cap (Slice B / SPEC §4.1) is enforced upstream at
		// 1 photo; the storage-side sort_order range remains 0..3 so
		// existing multi-photo rows stay readable. int32 conversion of
		// these small bounded values is safe. Explicit conversion
		// silences the gosec G115 warning for this loop.
		sortOrders[i] = int32(next + i) //nolint:gosec
	}
	const insPh = `
INSERT INTO check_in_photos (check_in_id, photo_url, sort_order)
SELECT $1, url, ord
FROM unnest($2::text[], $3::int[]) AS u(url, ord);`
	if _, err := tx.Exec(ctx, insPh, p.ID, p.AddPhotoURLs, sortOrders); err != nil {
		return fmt.Errorf("CheckinRepo.Update photos add: %w", err)
	}
	const markAttached = `
UPDATE photo_uploads
SET status = 'attached', attached_at = NOW(), check_in_id = $1
WHERE id = ANY($2) AND status IN ('pending', 'uploaded');`
	if _, err := tx.Exec(ctx, markAttached, p.ID, p.AddPhotoUploadIDs); err != nil {
		return fmt.Errorf("CheckinRepo.Update mark attached: %w", err)
	}
	return nil
}

// CountPhotos returns the current count of photos attached to a check-in.
// Used by the service layer's PATCH pre-check to enforce the SPEC §4.1
// 1-photo submission cap on the resulting set (current - removed + added).
func (r *CheckinRepo) CountPhotos(ctx context.Context, checkinID string) (int, error) {
	const q = `SELECT COUNT(*) FROM check_in_photos WHERE check_in_id = $1;`
	var n int
	if err := r.db.QueryRow(ctx, q, checkinID).Scan(&n); err != nil {
		return 0, fmt.Errorf("CheckinRepo.CountPhotos: %w", err)
	}
	return n, nil
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
				return domain.ErrForbidden
			}
			return domain.ErrNotFound
		}
		return fmt.Errorf("CheckinRepo.SoftDelete: %w", err)
	}
	return nil
}

// AddPhoto inserts a single photo into the next free slot. Returns
// ErrPhotoCapExceeded if the check-in already has a photo attached,
// ErrForbidden if the check-in isn't owned by userID, and ErrNotFound
// if it doesn't exist or is soft-deleted.
//
// Stage 5 (PERF-008): collapsed from a four-statement tx (lock +
// count + max + insert) into a single INSERT … SELECT … HAVING
// statement. The HAVING < 1 clause is what enforces the SPEC §4.1
// 1-photo submission cap (Slice B) without needing a separate count
// round-trip; ownership + liveness are baked into the inner JOIN's
// WHERE. Existing multi-photo check-ins remain readable; only new
// attaches are blocked once any photo exists. On NoRows we issue a
// cheap discriminator query (one extra round-trip on the error
// path only) to map to NotFound / Forbidden / PhotoCapExceeded.
func (r *CheckinRepo) AddPhoto(ctx context.Context, checkinID, userID, photoURL string) (domain.PhotoRef, error) {
	const q = `
INSERT INTO check_in_photos (check_in_id, photo_url, sort_order)
SELECT $1, $2, COALESCE(MAX(p.sort_order), -1) + 1
FROM check_ins ci
LEFT JOIN check_in_photos p ON p.check_in_id = ci.id
WHERE ci.id = $1 AND ci.user_id = $3 AND ci.deleted_at IS NULL
GROUP BY ci.id
HAVING COUNT(p.id) < 1
RETURNING sort_order;`
	var sortOrder int
	if err := r.db.QueryRow(ctx, q, checkinID, photoURL, userID).Scan(&sortOrder); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.PhotoRef{}, r.classifyAddPhotoFailure(ctx, checkinID, userID)
		}
		return domain.PhotoRef{}, fmt.Errorf("AddPhoto: %w", err)
	}
	return domain.PhotoRef{URL: photoURL, SortOrder: sortOrder}, nil
}

// classifyAddPhotoFailure runs after AddPhoto's INSERT … HAVING
// returned zero rows, to distinguish between the three failure modes
// (NotFound, Forbidden, PhotoCapExceeded). Single query — order of
// branches matches the typical user experience: missing > forbidden
// > full.
func (r *CheckinRepo) classifyAddPhotoFailure(ctx context.Context, checkinID, userID string) error {
	const q = `
SELECT ci.user_id,
       (SELECT COUNT(*) FROM check_in_photos WHERE check_in_id = ci.id) AS photo_count
FROM check_ins ci
WHERE ci.id = $1 AND ci.deleted_at IS NULL;`
	var owner string
	var photoCount int
	if err := r.db.QueryRow(ctx, q, checkinID).Scan(&owner, &photoCount); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("AddPhoto classify: %w", err)
	}
	if owner != userID {
		return domain.ErrForbidden
	}
	if photoCount >= 1 {
		return domain.ErrPhotoCapExceeded
	}
	// All known reasons ruled out — surface an internal error so the
	// regression is visible in logs rather than silently swallowed.
	return errors.New("AddPhoto: insert returned no rows but row passes all gates")
}

// ToggleToastTx runs the toggle inside the caller's transaction so the
// notification emit on the "added" branch can land atomically with the
// toasts row INSERT. The visibility gate runs on the pool (cheap, indexed,
// no need to hold the tx) before the tx begins side effects.
//
// Returns:
//   - state: the fresh toast count + you_toasted (post-toggle).
//   - added: true when the call INSERTed a row (false on un-toast).
//   - ownerID: the check-in author's user id (for the notification emit).
//     Always set when the toggle succeeded; "" only on internal-error paths.
func (r *CheckinRepo) ToggleToastTx(ctx context.Context, tx pgx.Tx, userID, checkinID string) (state domain.ToastState, added bool, ownerID string, err error) {
	if err = r.checkVisibility(ctx, userID, checkinID); err != nil {
		return domain.ToastState{}, false, "", err
	}

	if err = tx.QueryRow(ctx,
		`SELECT user_id FROM check_ins WHERE id = $1 AND deleted_at IS NULL;`,
		checkinID,
	).Scan(&ownerID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ToastState{}, false, "", domain.ErrNotFound
		}
		return domain.ToastState{}, false, "", fmt.Errorf("ToggleToastTx owner: %w", err)
	}

	var existed bool
	if err = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM toasts WHERE user_id = $1 AND check_in_id = $2);`,
		userID, checkinID).Scan(&existed); err != nil {
		return domain.ToastState{}, false, "", fmt.Errorf("ToggleToastTx exists: %w", err)
	}
	if existed {
		if _, err = tx.Exec(ctx,
			`DELETE FROM toasts WHERE user_id = $1 AND check_in_id = $2;`, userID, checkinID); err != nil {
			return domain.ToastState{}, false, "", fmt.Errorf("ToggleToastTx delete: %w", err)
		}
	} else {
		if _, err = tx.Exec(ctx,
			`INSERT INTO toasts (user_id, check_in_id) VALUES ($1, $2) ON CONFLICT DO NOTHING;`,
			userID, checkinID); err != nil {
			return domain.ToastState{}, false, "", fmt.Errorf("ToggleToastTx insert: %w", err)
		}
		added = true
	}

	var cnt int64
	if err = tx.QueryRow(ctx, `
SELECT
  (SELECT COUNT(*) FROM toasts WHERE check_in_id = $2),
  EXISTS (SELECT 1 FROM toasts WHERE check_in_id = $2 AND user_id = $1);`,
		userID, checkinID).Scan(&cnt, &state.YouToasted); err != nil {
		return domain.ToastState{}, false, "", fmt.Errorf("ToggleToastTx count: %w", err)
	}
	state.Toasts = int(cnt)
	return state, added, ownerID, nil
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
			return domain.ErrNotFound
		}
		return fmt.Errorf("checkVisibility: %w", err)
	}
	return nil
}

// UserCheckins returns a paginated list of check-ins for a user, applying
// the same privacy gate as the feed. `viewerID` may be empty for unauthed
// reads (only public profiles will return rows).
//
// Stage 3 (STYLE-035 / STYLE-040) refactor: the body uses the shared
// scanCheckinRow + hydrateCheckinTagsAndPhotos helpers below so the same
// column order is honored across UserCheckins / Get / any future check-in
// listing path.
func (r *CheckinRepo) UserCheckins(ctx context.Context, viewerID, targetID string, cursorTs *time.Time, cursorID *string, limit int) ([]domain.Checkin, error) {
	const q = `
SELECT
  ci.id, ci.user_id, ci.beverage_id,
  ci.rating, ci.review_text,
  ci.price_amount, ci.price_currency, ci.price_unit,
  ci.purchase_type,
  ci.created_at, ci.updated_at, ci.edited_at,
  u.username, u.display_username, u.display_name, u.avatar_url, u.privacy_mode,
  b.name_i18n, b.category_slug, b.label_image_url,
  cat.name_i18n AS category_name_i18n,
  br.id, br.name_i18n, br.image_url,` + producerPrefectureSelectCols + `,
  v.id, v.name, v.locality, v.country,
  ci.toast_count,
  EXISTS(SELECT 1 FROM toasts WHERE check_in_id = ci.id AND user_id = NULLIF($2, '')::uuid),
  ci.comment_count
FROM check_ins ci
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
JOIN beverages b ON b.id = ci.beverage_id
JOIN producers br ON br.id = b.producer_id
JOIN beverage_categories cat ON cat.id = b.category_id` + producerPrefectureJoinClause + `
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
  AND ($3::timestamptz IS NULL OR (ci.created_at, ci.id) < ($3::timestamptz, $4::uuid))
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
		c, _, err := scanCheckinRow(rows)
		if err != nil {
			return nil, fmt.Errorf("UserCheckins scan: %w", err)
		}
		out = append(out, c)
		ids = append(ids, c.ID)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := r.hydrateCheckinTagsAndPhotos(ctx, out, ids); err != nil {
		return nil, err
	}
	return out, nil
}

// rowScanner is the slice of pgx.Row / pgx.Rows the canonical scan helper
// needs. Both satisfy this with the same Scan(args ...any) signature, so
// the helper works for both QueryRow-style and Query-style call sites.
type rowScanner interface {
	Scan(dest ...any) error
}

// scanCheckinRow reads one row of the canonical check-in projection (the
// 30-column shape shared by Get / UserCheckins / future listings) into a
// hydrated domain.Checkin. The second return is the row's owner-privacy
// mode, used by callers that gate on private-account visibility.
//
// Photos + tags are NOT loaded here — that's a batch fetch the caller
// handles via hydrateCheckinTagsAndPhotos after the rows.Next() loop ends.
func scanCheckinRow(rows rowScanner) (domain.Checkin, string, error) {
	var c domain.Checkin
	var (
		priceAmount              *float64
		priceCcy, priceUnit      *string
		bevName, catName         []byte
		brwName                  []byte
		bevSlug                  string
		bevLabel                 *string
		brwImageURL              *string
		brwPref                  prefectureScan
		brwID, userIDVal, bevID  string
		venueID, venueName       *string
		venueLocality, venueCtry *string
		toastCnt                 int64
		youToast                 bool
		userPrivacy              string
		commentCnt               int64
	)
	prefArgs := brwPref.scanArgs()
	scanArgs := make([]any, 0, 24+len(prefArgs)+7)
	scanArgs = append(scanArgs,
		&c.ID, &userIDVal, &bevID,
		&c.Rating, &c.Review,
		&priceAmount, &priceCcy, &priceUnit,
		&c.PurchaseType,
		&c.CreatedAt, &c.UpdatedAt, &c.EditedAt,
		&c.User.Username, &c.User.DisplayUsername, &c.User.DisplayName, &c.User.AvatarURL, &userPrivacy,
		&bevName, &bevSlug, &bevLabel,
		&catName,
		&brwID, &brwName, &brwImageURL,
	)
	scanArgs = append(scanArgs, prefArgs...)
	scanArgs = append(scanArgs,
		&venueID, &venueName, &venueLocality, &venueCtry,
		&toastCnt, &youToast, &commentCnt,
	)
	if err := rows.Scan(scanArgs...); err != nil {
		return domain.Checkin{}, "", err
	}
	c.User.ID = userIDVal
	c.Toasts = int(toastCnt)
	c.YouToasted = youToast
	c.CommentCount = int(commentCnt)
	bn, _ := domain.I18nFromJSON(bevName)
	cn, _ := domain.I18nFromJSON(catName)
	rn, _ := domain.I18nFromJSON(brwName)
	c.Beverage = domain.BeverageRef{
		ID:            bevID,
		Name:          bn,
		Producer:      domain.ProducerRef{ID: brwID, Name: rn, Prefecture: brwPref.toPrefecture(), ImageURL: brwImageURL},
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
	return c, userPrivacy, nil
}

// hydrateCheckinTagsAndPhotos populates the Tags + Photos slices on each
// item of `out` using one batch fetch of TagsFor + one of PhotosFor. Empty
// slices (not nil) are written so JSON responses are stable.
func (r *CheckinRepo) hydrateCheckinTagsAndPhotos(ctx context.Context, out []domain.Checkin, ids []string) error {
	photos, err := r.PhotosFor(ctx, ids)
	if err != nil {
		return err
	}
	tags, err := r.TagsFor(ctx, ids)
	if err != nil {
		return err
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
	return nil
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
	// Stage 5 (PERF-007): single-query shape per docs/db/query_patterns.md §4.
	// The OR-tree inside the WHERE encodes the visibility rule in one
	// round trip instead of the two-step "lookup-then-maybe-followers"
	// dance. NULLIF($2,'') maps the empty viewerID (unauthenticated)
	// to NULL so the comparisons against u.id / f.follower_id resolve
	// to false instead of throwing on cast.
	const q = `
SELECT 1
FROM check_ins ci
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
WHERE ci.id = $1
  AND ci.deleted_at IS NULL
  AND (
    u.privacy_mode = 'public'
    OR u.id = NULLIF($2,'')::uuid
    OR EXISTS (
      SELECT 1 FROM follows f
      WHERE f.follower_id = NULLIF($2,'')::uuid
        AND f.followed_id = u.id
        AND f.status = 'accepted'
    )
  )
LIMIT 1;`
	var one int
	if err := r.db.QueryRow(ctx, q, checkInID, viewerID).Scan(&one); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return fmt.Errorf("AssertViewerCanSeeCheckin: %w", err)
	}
	return nil
}
