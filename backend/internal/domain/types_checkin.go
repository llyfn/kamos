package domain

import (
	"math"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// Check-ins
// ---------------------------------------------------------------------------

// Price is the structured shape for check-in pricing per HANDOFF.
type Price struct {
	Amount   float64 `json:"amount"`
	Currency string  `json:"currency"` // 'JPY' | 'KRW' | 'USD'
	Mode     string  `json:"mode"`     // 'serving' | 'bottle'  (DB column: price_unit)
}

// CreateCheckinRequest — POST /v1/check-ins.
type CreateCheckinRequest struct {
	BeverageID   string   `json:"beverage_id"`
	Rating       *float64 `json:"rating,omitempty"`
	Review       *string  `json:"review,omitempty"`
	Tags         []string `json:"tags,omitempty"` // flavor_tag slugs
	Photos       []string `json:"photos,omitempty"`
	Price        *Price   `json:"price,omitempty"`
	PurchaseType *string  `json:"purchase_type,omitempty"`
	// Venue is the optional Phase-4 venue tag. Three shapes are accepted:
	//   - { id } existing venue UUID → attach as-is.
	//   - { foursquare_id, name, ... } Foursquare hit → upsert by fsq id.
	//   - {} / null → ignored (silent drop). This keeps the contract
	//     permissive so Flutter clients on older builds can submit empty
	//     objects without erroring.
	Venue *CheckinVenue `json:"venue,omitempty"`
}

// allowedPurchase / allowedCurrency / allowedPriceMode are the controlled
// vocabularies enforced by check-in validation. Kept package-private so
// domain types alone define the SPEC sets.
var (
	allowedPurchase  = map[string]bool{"on_premise": true, "retail": true, "gift": true, "other": true}
	allowedCurrency  = map[string]bool{"JPY": true, "KRW": true, "USD": true}
	allowedPriceMode = map[string]bool{"serving": true, "bottle": true}
)

// ValidRating enforces SPEC §4.2: 0.5–5.0 in 0.5 steps. Nil is valid.
func ValidRating(r *float64) error {
	if r == nil {
		return nil
	}
	if *r < 0.5 || *r > 5.0 {
		return wrapValidation("rating must be between 0.5 and 5.0")
	}
	// 0.5 step grid check using *10 % 5.
	scaled := math.Round(*r * 10)
	if math.Mod(scaled, 5) != 0 {
		return wrapValidation("rating must be in 0.5 steps")
	}
	return nil
}

func (r *CreateCheckinRequest) Validate() error {
	if r.BeverageID == "" {
		return wrapValidation("beverage_id is required")
	}
	if err := ValidRating(r.Rating); err != nil {
		return err
	}
	if r.Review != nil {
		clean, err := SanitizeText("review", *r.Review, true, 500)
		if err != nil {
			return err
		}
		*r.Review = clean
	}
	if len(r.Photos) > 4 {
		return wrapValidation("a check-in may have at most 4 photos")
	}
	if r.PurchaseType != nil {
		v := strings.ToLower(strings.ReplaceAll(*r.PurchaseType, "-", "_"))
		if !allowedPurchase[v] {
			return wrapValidation("purchase_type must be one of: on_premise, retail, gift, other")
		}
		*r.PurchaseType = v
	}
	if r.Price != nil {
		if !allowedCurrency[strings.ToUpper(r.Price.Currency)] {
			return wrapValidation("price.currency must be one of: JPY, KRW, USD")
		}
		r.Price.Currency = strings.ToUpper(r.Price.Currency)
		if !allowedPriceMode[strings.ToLower(r.Price.Mode)] {
			return wrapValidation("price.mode must be one of: serving, bottle")
		}
		r.Price.Mode = strings.ToLower(r.Price.Mode)
		if r.Price.Amount < 0 {
			return wrapValidation("price.amount must be ≥ 0")
		}
	}
	return nil
}

// UpdateCheckinRequest — PATCH /v1/check-ins/:id.
// `beverage_id` cannot change per SPEC §4.4; if a client sends it, we reject.
//
// Post-creation editability (01): the request additionally accepts
// `add_photos` (newly-uploaded photo_uploads ids to attach) and
// `remove_photos` (photo ids on the existing check-in to detach). The
// SPEC §4.2 four-photo cap is enforced against the resulting set
// (current - removed + added) inside the service layer.
type UpdateCheckinRequest struct {
	BeverageID   *string   `json:"beverage_id,omitempty"` // poison field — must be nil
	Rating       *float64  `json:"rating,omitempty"`
	ClearRating  bool      `json:"clear_rating,omitempty"`
	Review       *string   `json:"review,omitempty"`
	ClearReview  bool      `json:"clear_review,omitempty"`
	Tags         *[]string `json:"tags,omitempty"`
	Price        *Price    `json:"price,omitempty"`
	ClearPrice   bool      `json:"clear_price,omitempty"`
	PurchaseType *string   `json:"purchase_type,omitempty"`
	// AddPhotos lists photo_uploads ids (returned from the
	// /v1/uploads/photo-presign flow) to attach to the check-in.
	AddPhotos []string `json:"add_photos,omitempty"`
	// RemovePhotos lists existing photo URLs (PhotoRef.URL) to detach
	// from the check-in. The URL is the natural id surfaced to the client
	// on the existing Checkin.photos projection.
	RemovePhotos []string `json:"remove_photos,omitempty"`
}

func (r *UpdateCheckinRequest) Validate() error {
	if r.BeverageID != nil {
		return wrapValidation("beverage_id cannot be changed after a check-in is created")
	}
	if err := ValidRating(r.Rating); err != nil {
		return err
	}
	if r.Review != nil {
		clean, err := SanitizeText("review", *r.Review, true, 500)
		if err != nil {
			return err
		}
		*r.Review = clean
	}
	if r.PurchaseType != nil {
		v := strings.ToLower(strings.ReplaceAll(*r.PurchaseType, "-", "_"))
		if !allowedPurchase[v] {
			return wrapValidation("purchase_type must be one of: on_premise, retail, gift, other")
		}
		*r.PurchaseType = v
	}
	if r.Price != nil {
		if !allowedCurrency[strings.ToUpper(r.Price.Currency)] {
			return wrapValidation("price.currency must be one of: JPY, KRW, USD")
		}
		r.Price.Currency = strings.ToUpper(r.Price.Currency)
		if !allowedPriceMode[strings.ToLower(r.Price.Mode)] {
			return wrapValidation("price.mode must be one of: serving, bottle")
		}
		r.Price.Mode = strings.ToLower(r.Price.Mode)
	}
	return nil
}

// Checkin is the canonical check-in DTO returned by the API. // added CommentCount; FeedItem mirrors the field.
type Checkin struct {
	ID           string      `json:"id"`
	User         CheckinUser `json:"user"`
	Beverage     BeverageRef `json:"beverage"`
	Rating       *float64    `json:"rating"`
	Review       *string     `json:"review"`
	Tags         []FlavorTag `json:"tags"`
	Photos       []PhotoRef  `json:"photos"`
	Price        *Price      `json:"price,omitempty"`
	PurchaseType *string     `json:"purchase_type,omitempty"`
	Venue        *VenueRef   `json:"venue,omitempty"`
	Toasts       int         `json:"toasts"`
	YouToasted   bool        `json:"you_toasted"`
	CommentCount int         `json:"comment_count"`
	CreatedAt    time.Time   `json:"created_at"`
	UpdatedAt    time.Time   `json:"updated_at"`
	// EditedAt is non-nil when the author has touched any tracked field
	// after creation (SPEC §4.4 / migration 003). Rendering-only.
	EditedAt *time.Time `json:"edited_at,omitempty"`
}

type CheckinUser struct {
	ID              string  `json:"id"`
	Username        string  `json:"username"`
	DisplayUsername string  `json:"display_username"`
	DisplayName     string  `json:"display_name"`
	AvatarURL       *string `json:"avatar_url"`
}

type PhotoRef struct {
	URL       string `json:"url"`
	SortOrder int    `json:"sort_order"`
}

// CheckinSummary is a lighter shape for "recent check-ins" sections.
// Stage 5 (PERF-010): the summary carries Photos hydrated via the
// PhotosFor batch helper so the beverage detail screen can render
// thumbnails without a follow-up round trip. Profile-UX expansion: it
// also carries Tags (flavor tag chips) so the beverage detail
// "recent check-ins" rows can render richer cards.
type CheckinSummary struct {
	ID        string      `json:"id"`
	User      CheckinUser `json:"user"`
	Rating    *float64    `json:"rating"`
	Review    *string     `json:"review"`
	Photos    []PhotoRef  `json:"photos"`
	Tags      []FlavorTag `json:"tags"`
	CreatedAt time.Time   `json:"created_at"`
}

// FeedItem matches HANDOFF's feedItem shape. Stage 5 (PERF-002):
// the previous `photo_count` integer is replaced by a hydrated
// `photos: []PhotoRef` slice so the Flutter feed card can render
// the actual photo grid without a follow-up request per check-in.
// `comment_count` and `toasts` are now denormalized counter reads
// from check_ins (migration 011) rather than correlated subqueries.
type FeedItem struct {
	ID           string      `json:"id"`
	User         CheckinUser `json:"user"`
	Beverage     BeverageRef `json:"beverage"`
	Rating       *float64    `json:"rating"`
	Review       *string     `json:"review"`
	Tags         []FlavorTag `json:"tags"`
	Photos       []PhotoRef  `json:"photos"`
	Toasts       int         `json:"toasts"`
	YouToasted   bool        `json:"you_toasted"`
	CommentCount int         `json:"comment_count"`
	Venue        *VenueRef   `json:"venue,omitempty"`
	CreatedAt    time.Time   `json:"created_at"`
	// EditedAt is non-nil when the author has touched any tracked field
	// after creation (SPEC §4.4 / migration 003). Rendering-only.
	EditedAt *time.Time `json:"edited_at,omitempty"`
}

// ToastState is the response body for the toast toggle endpoint.
type ToastState struct {
	Toasts     int  `json:"toasts"`
	YouToasted bool `json:"you_toasted"`
}
