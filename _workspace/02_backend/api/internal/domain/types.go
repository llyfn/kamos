// Package domain holds the request/response and DB-facing structs used by
// handlers and repositories. Validation methods enforce SPEC caps at the API
// boundary (DB CHECKs are a backstop, not the primary line of defense).
package domain

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"regexp"
	"strings"
	"time"

	"github.com/kamos/api/internal/apierror"
)

// ---------------------------------------------------------------------------
// Shared shapes
// ---------------------------------------------------------------------------

// I18nText is the JSONB shape used for beverage / brewery / category / tag
// names and descriptions. We DO NOT pre-resolve based on Accept-Language —
// the client owns locale selection (HANDOFF "client owns locale" is overridden
// by SPEC §8 fallback discussion — we return the full object so the client can
// also gracefully fall back).
type I18nText struct {
	EN string `json:"en"`
	JA string `json:"ja"`
	KO string `json:"ko,omitempty"`
}

// Resolve picks a string per SPEC §6.5 fallback (ko → en, ja → en).
func (t I18nText) Resolve(locale string) string {
	switch locale {
	case "ja":
		if t.JA != "" {
			return t.JA
		}
	case "ko":
		if t.KO != "" {
			return t.KO
		}
	}
	return t.EN
}

// FromJSONBytes unmarshals a JSONB column into I18nText. Tolerates missing keys.
func I18nFromJSON(raw []byte) (I18nText, error) {
	var t I18nText
	if len(raw) == 0 {
		return t, nil
	}
	if err := json.Unmarshal(raw, &t); err != nil {
		return t, fmt.Errorf("I18nFromJSON: %w", err)
	}
	return t, nil
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

type User struct {
	ID              string     `json:"id"`
	Username        string     `json:"username"`         // lowercase handle (the unique key)
	DisplayUsername string     `json:"display_username"` // case-preserved for rendering
	Email           string     `json:"email"`
	EmailVerified   bool       `json:"email_verified"`
	DisplayName     string     `json:"display_name"`
	AvatarURL       *string    `json:"avatar_url"`
	Bio             *string    `json:"bio"`
	Locale          string     `json:"locale"`
	PrivacyMode     string     `json:"privacy_mode"`
	CreatedAt       time.Time  `json:"created_at"`
	DeletedAt       *time.Time `json:"-"`
}

// PublicUser is the User shape exposed via GET /v1/users/{username}.
// Email and EmailVerified are intentionally omitted — they are private
// to the owner and would leak through the public profile endpoint otherwise.
type PublicUser struct {
	ID              string    `json:"id"`
	Username        string    `json:"username"`
	DisplayUsername string    `json:"display_username"`
	DisplayName     string    `json:"display_name"`
	AvatarURL       *string   `json:"avatar_url"`
	Bio             *string   `json:"bio"`
	Locale          string    `json:"locale"`
	PrivacyMode     string    `json:"privacy_mode"`
	CreatedAt       time.Time `json:"created_at"`
}

// ToPublic returns the privacy-safe projection of u.
func (u User) ToPublic() PublicUser {
	return PublicUser{
		ID:              u.ID,
		Username:        u.Username,
		DisplayUsername: u.DisplayUsername,
		DisplayName:     u.DisplayName,
		AvatarURL:       u.AvatarURL,
		Bio:             u.Bio,
		Locale:          u.Locale,
		PrivacyMode:     u.PrivacyMode,
		CreatedAt:       u.CreatedAt,
	}
}

type UserStats struct {
	Checkins  int `json:"checkins"`
	Unique    int `json:"unique"`
	Followers int `json:"followers"`
	Following int `json:"following"`
}

type Me struct {
	User
	Stats UserStats `json:"stats"`
}

// RegisterRequest is the body shape for POST /v1/auth/register.
type RegisterRequest struct {
	Username    string  `json:"username"`
	Email       string  `json:"email"`
	Password    string  `json:"password"`
	DisplayName string  `json:"display_name"`
	Locale      string  `json:"locale"`
	Bio         *string `json:"bio,omitempty"`
}

var (
	usernameRE = regexp.MustCompile(`^[A-Za-z0-9_]{3,30}$`)
	// rfc-5322 is a beast; we use a pragmatic regex that catches obvious typos
	// without over-rejecting legitimate addresses.
	emailRE = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
)

func (r *RegisterRequest) Validate() error {
	r.Username = strings.TrimSpace(r.Username)
	r.Email = strings.TrimSpace(r.Email)
	r.DisplayName = strings.TrimSpace(r.DisplayName)
	r.Locale = strings.TrimSpace(strings.ToLower(r.Locale))
	if !usernameRE.MatchString(r.Username) {
		return wrapValidation("username must be 3-30 chars of letters, digits, or underscore")
	}
	if !emailRE.MatchString(r.Email) {
		return wrapValidation("email is malformed")
	}
	if len(r.Password) < 8 {
		return wrapValidation("password must be at least 8 characters")
	}
	if r.DisplayName == "" {
		r.DisplayName = r.Username
	}
	if len([]rune(r.DisplayName)) > 50 {
		return wrapValidation("display_name must be ≤ 50 characters")
	}
	if r.Bio != nil && len([]rune(*r.Bio)) > 200 {
		return wrapValidation("bio must be ≤ 200 characters")
	}
	if r.Locale != "en" && r.Locale != "ja" && r.Locale != "ko" {
		r.Locale = "en"
	}
	return nil
}

// LoginRequest is the email+password login body.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (r *LoginRequest) Validate() error {
	r.Email = strings.TrimSpace(r.Email)
	if r.Email == "" || r.Password == "" {
		return wrapValidation("email and password are required")
	}
	return nil
}

// GoogleLoginRequest carries a Google ID token from the client.
type GoogleLoginRequest struct {
	IDToken  string  `json:"id_token"`
	Username *string `json:"username,omitempty"` // first-login only
	Locale   *string `json:"locale,omitempty"`
}

func (r *GoogleLoginRequest) Validate() error {
	if r.IDToken == "" {
		return wrapValidation("id_token is required")
	}
	if r.Username != nil && !usernameRE.MatchString(*r.Username) {
		return wrapValidation("username must be 3-30 chars of letters, digits, or underscore")
	}
	return nil
}

// VerifyEmailRequest carries the 24h verification token.
type VerifyEmailRequest struct {
	Token string `json:"token"`
}

func (r *VerifyEmailRequest) Validate() error {
	if r.Token == "" {
		return wrapValidation("token is required")
	}
	return nil
}

// PasswordChangeRequest — authed endpoint.
type PasswordChangeRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

func (r *PasswordChangeRequest) Validate() error {
	if r.CurrentPassword == "" {
		return wrapValidation("current_password is required")
	}
	if len(r.NewPassword) < 8 {
		return wrapValidation("new_password must be at least 8 characters")
	}
	return nil
}

// EmailChangeRequest — authed endpoint; triggers re-verification.
type EmailChangeRequest struct {
	NewEmail string `json:"new_email"`
}

func (r *EmailChangeRequest) Validate() error {
	r.NewEmail = strings.TrimSpace(r.NewEmail)
	if !emailRE.MatchString(r.NewEmail) {
		return wrapValidation("new_email is malformed")
	}
	return nil
}

// UpdateMeRequest — PATCH /v1/users/me.
type UpdateMeRequest struct {
	DisplayName *string `json:"display_name,omitempty"`
	Bio         *string `json:"bio,omitempty"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
	Locale      *string `json:"locale,omitempty"`
	PrivacyMode *string `json:"privacy_mode,omitempty"`
}

func (r *UpdateMeRequest) Validate() error {
	if r.DisplayName != nil {
		s := strings.TrimSpace(*r.DisplayName)
		if len([]rune(s)) < 1 || len([]rune(s)) > 50 {
			return wrapValidation("display_name must be 1-50 characters")
		}
		*r.DisplayName = s
	}
	if r.Bio != nil && len([]rune(*r.Bio)) > 200 {
		return wrapValidation("bio must be ≤ 200 characters")
	}
	if r.Locale != nil {
		v := strings.ToLower(strings.TrimSpace(*r.Locale))
		if v != "en" && v != "ja" && v != "ko" {
			return wrapValidation("locale must be one of: en, ja, ko")
		}
		*r.Locale = v
	}
	if r.PrivacyMode != nil {
		v := strings.ToLower(strings.TrimSpace(*r.PrivacyMode))
		if v != "public" && v != "private" {
			return wrapValidation("privacy_mode must be one of: public, private")
		}
		*r.PrivacyMode = v
	}
	return nil
}

// ---------------------------------------------------------------------------
// Auth response
// ---------------------------------------------------------------------------

// AuthResponse is the body returned by register / login / google / refresh.
// The refresh_token is the raw (base64-rawurl 43-char) secret — the server
// stores only its SHA-256 hash. expires_in / refresh_expires_in are seconds.
type AuthResponse struct {
	User             User   `json:"user"`
	AccessToken      string `json:"access_token"`
	RefreshToken     string `json:"refresh_token"`
	TokenType        string `json:"token_type"` // "Bearer"
	ExpiresIn        int64  `json:"expires_in"`         // access-token TTL, seconds
	RefreshExpiresIn int64  `json:"refresh_expires_in"` // refresh-token TTL, seconds
}

// RefreshTokenRequest is the body for POST /v1/auth/refresh.
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (r *RefreshTokenRequest) Validate() error {
	if r.RefreshToken == "" {
		return wrapValidation("refresh_token is required")
	}
	return nil
}

// LogoutRequest is the optional body for POST /v1/auth/logout. When the
// refresh_token is present, only that token is revoked; when absent, every
// active refresh token for the authed user is revoked (logout-everywhere).
type LogoutRequest struct {
	RefreshToken string `json:"refresh_token,omitempty"`
}

// ---------------------------------------------------------------------------
// Beverage / Brewery
// ---------------------------------------------------------------------------

type Brewery struct {
	ID              string    `json:"id"`
	Name            I18nText  `json:"name"`
	Prefecture      *string   `json:"prefecture,omitempty"`
	Region          *string   `json:"region,omitempty"`
	FoundedYear     *int      `json:"founded_year,omitempty"`
	Website         *string   `json:"website,omitempty"`
	Description     *I18nText `json:"description,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
	BeverageCount   *int      `json:"beverage_count,omitempty"`
}

type CategoryLabel struct {
	Slug       string   `json:"slug"`        // 'nihonshu' | 'shochu' | 'liqueur'
	LabelI18n  I18nText `json:"label_i18n"`  // SPEC §2.1 canonical strings
}

type Beverage struct {
	ID             string         `json:"id"`
	Name           I18nText       `json:"name"`
	Brewery        Brewery        `json:"brewery"`
	Category       CategoryLabel  `json:"category"`
	Subcategory    *I18nText      `json:"subcategory,omitempty"`
	ABV            *float64       `json:"abv,omitempty"`
	PolishingRatio *int           `json:"polishing_ratio,omitempty"`
	Prefecture     *string        `json:"prefecture,omitempty"`
	Region         *string        `json:"region,omitempty"`
	FlavorProfile  []string       `json:"flavor_profile"` // tag slugs
	Description    *I18nText      `json:"description,omitempty"`
	LabelImageURL  *string        `json:"label_image_url,omitempty"`
	AvgRating      *float64       `json:"avg_rating"`
	CheckInCount   int            `json:"check_in_count"`
	CreatedAt      time.Time      `json:"created_at"`
}

// BeverageDetail is a Beverage plus aggregated flavor and recent check-ins.
type BeverageDetail struct {
	Beverage
	AggregatedFlavor []FlavorAggregate `json:"aggregated_flavor"`
	RecentCheckins   []CheckinSummary  `json:"recent_check_ins"`
}

type FlavorAggregate struct {
	Slug      string   `json:"slug"`
	Dimension string   `json:"dimension"`
	Name      I18nText `json:"name"`
	Uses      int      `json:"uses"`
}

type FlavorTag struct {
	ID        string   `json:"id"`
	Slug      string   `json:"slug"`
	Dimension string   `json:"dimension"`
	Name      I18nText `json:"name"`
}

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
	BeverageID    string        `json:"beverage_id"`
	Rating        *float64      `json:"rating,omitempty"`
	Review        *string       `json:"review,omitempty"`
	Tags          []string      `json:"tags,omitempty"` // flavor_tag slugs
	Photos        []string      `json:"photos,omitempty"`
	Price         *Price        `json:"price,omitempty"`
	PurchaseType  *string       `json:"purchase_type,omitempty"`
	ServingStyle  *string       `json:"serving_style,omitempty"`
	// Venue is the optional Phase-4 venue tag. Three shapes are accepted:
	//   - { id } existing venue UUID → attach as-is.
	//   - { foursquare_id, name, ... } Foursquare hit → upsert by fsq id.
	//   - {} / null → ignored (silent drop). This keeps the contract
	//     permissive so Flutter clients on older builds can submit empty
	//     objects without erroring.
	Venue *CheckinVenue `json:"venue,omitempty"`
}

// CheckinVenue is the optional venue payload on POST /v1/check-ins. See
// CreateCheckinRequest.Venue for the three accepted shapes.
type CheckinVenue struct {
	ID           *string  `json:"id,omitempty"`
	FoursquareID *string  `json:"foursquare_id,omitempty"`
	Name         *string  `json:"name,omitempty"`
	Address      *string  `json:"address,omitempty"`
	Lat          *float64 `json:"lat,omitempty"`
	Lng          *float64 `json:"lng,omitempty"`
	Country      *string  `json:"country,omitempty"`
	Prefecture   *string  `json:"prefecture,omitempty"`
	Locality     *string  `json:"locality,omitempty"`
}

// venueFsqIDRE matches the Foursquare fsq_id format (alphanumeric, underscore,
// hyphen). Used by CheckinVenue.Validate to reject obviously poisoned values.
var venueFsqIDRE = regexp.MustCompile(`^[A-Za-z0-9_-]+$`)

// venueValidateString applies the shared charset rule used by every
// user-controlled string on CheckinVenue: rune-length bounded; reject NUL
// (0x00) and other ASCII control chars (<0x20) except space (0x20) and tab
// (0x09). Unicode code points >= 0x20 pass — international venue names are
// the common case.
func venueValidateString(field, s string, minRunes, maxRunes int) error {
	n := 0
	for _, r := range s {
		n++
		if r == 0 {
			return wrapValidation("venue." + field + " contains NUL byte")
		}
		if r < 0x20 && r != 0x09 {
			return wrapValidation("venue." + field + " contains a control character")
		}
	}
	if n < minRunes || n > maxRunes {
		return wrapValidation(fmt.Sprintf("venue.%s must be %d-%d characters", field, minRunes, maxRunes))
	}
	return nil
}

// Validate enforces field-by-field caps and charset rules on the optional
// venue payload submitted with POST /v1/check-ins. The DB CHECK constraints
// added in migration 006 are a backstop; this validator is the primary line
// of defense against poisoning of the shared venues table (SEC-001).
//
// All fields are optional in isolation — Validate only inspects what is set.
// The handler-side resolveCheckinVenue decides which combinations are
// actionable (e.g. {foursquare_id, name} → upsert).
func (v *CheckinVenue) Validate() error {
	if v == nil {
		return nil
	}
	if v.Name != nil {
		if err := venueValidateString("name", *v.Name, 1, 200); err != nil {
			return err
		}
	}
	if v.Address != nil {
		if err := venueValidateString("address", *v.Address, 0, 500); err != nil {
			return err
		}
	}
	if v.Country != nil {
		if err := venueValidateString("country", *v.Country, 0, 100); err != nil {
			return err
		}
	}
	if v.Prefecture != nil {
		if err := venueValidateString("prefecture", *v.Prefecture, 0, 100); err != nil {
			return err
		}
	}
	if v.Locality != nil {
		if err := venueValidateString("locality", *v.Locality, 0, 100); err != nil {
			return err
		}
	}
	if v.FoursquareID != nil {
		s := *v.FoursquareID
		n := len([]rune(s))
		if n < 1 || n > 100 {
			return wrapValidation("venue.foursquare_id must be 1-100 characters")
		}
		if !venueFsqIDRE.MatchString(s) {
			return wrapValidation("venue.foursquare_id must be alphanumeric with underscore or hyphen")
		}
	}
	return nil
}

// Venue is the full DB-backed venue record. Currently only exposed via the
// CheckinVenue upsert + the embedded VenueRef projection on check-ins; a
// future phase may add a public GET /v1/venues/{id} once the value is clear.
type Venue struct {
	ID           string    `json:"id"`
	FoursquareID *string   `json:"foursquare_id,omitempty"`
	Name         string    `json:"name"`
	Address      *string   `json:"address,omitempty"`
	Lat          *float64  `json:"lat,omitempty"`
	Lng          *float64  `json:"lng,omitempty"`
	Country      *string   `json:"country,omitempty"`
	Prefecture   *string   `json:"prefecture,omitempty"`
	Locality     *string   `json:"locality,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// VenueRef is the lightweight projection embedded on Checkin / FeedItem.
// Feed cards render "at Daikoku, Tokyo" — id + name + locality + country is
// enough; the full Venue is not.
type VenueRef struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Locality *string `json:"locality,omitempty"`
	Country  *string `json:"country,omitempty"`
}

var (
	allowedPurchase = map[string]bool{"on_premise": true, "retail": true, "gift": true, "other": true}
	allowedServing  = map[string]bool{"glass": true, "carafe": true, "bottle": true, "can": true, "other": true}
	allowedCurrency = map[string]bool{"JPY": true, "KRW": true, "USD": true}
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
	if r.Review != nil && len([]rune(*r.Review)) > 500 {
		return wrapValidation("review must be ≤ 500 characters")
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
	if r.ServingStyle != nil {
		v := strings.ToLower(*r.ServingStyle)
		if !allowedServing[v] {
			return wrapValidation("serving_style must be one of: glass, carafe, bottle, can, other")
		}
		*r.ServingStyle = v
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
type UpdateCheckinRequest struct {
	BeverageID   *string  `json:"beverage_id,omitempty"` // poison field — must be nil
	Rating       *float64 `json:"rating,omitempty"`
	ClearRating  bool     `json:"clear_rating,omitempty"`
	Review       *string  `json:"review,omitempty"`
	ClearReview  bool     `json:"clear_review,omitempty"`
	Tags         *[]string `json:"tags,omitempty"`
	Price        *Price   `json:"price,omitempty"`
	ClearPrice   bool     `json:"clear_price,omitempty"`
	PurchaseType *string  `json:"purchase_type,omitempty"`
	ServingStyle *string  `json:"serving_style,omitempty"`
}

func (r *UpdateCheckinRequest) Validate() error {
	if r.BeverageID != nil {
		return wrapValidation("beverage_id cannot be changed after a check-in is created")
	}
	if err := ValidRating(r.Rating); err != nil {
		return err
	}
	if r.Review != nil && len([]rune(*r.Review)) > 500 {
		return wrapValidation("review must be ≤ 500 characters")
	}
	if r.PurchaseType != nil {
		v := strings.ToLower(strings.ReplaceAll(*r.PurchaseType, "-", "_"))
		if !allowedPurchase[v] {
			return wrapValidation("purchase_type must be one of: on_premise, retail, gift, other")
		}
		*r.PurchaseType = v
	}
	if r.ServingStyle != nil {
		v := strings.ToLower(*r.ServingStyle)
		if !allowedServing[v] {
			return wrapValidation("serving_style must be one of: glass, carafe, bottle, can, other")
		}
		*r.ServingStyle = v
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

// Checkin is the canonical check-in DTO returned by the API.
type Checkin struct {
	ID           string         `json:"id"`
	User         CheckinUser    `json:"user"`
	Beverage     BeverageRef    `json:"beverage"`
	Rating       *float64       `json:"rating"`
	Review       *string        `json:"review"`
	Tags         []FlavorTag    `json:"tags"`
	Photos       []PhotoRef     `json:"photos"`
	Price        *Price         `json:"price,omitempty"`
	PurchaseType *string        `json:"purchase_type,omitempty"`
	ServingStyle *string        `json:"serving_style,omitempty"`
	Venue        *VenueRef      `json:"venue,omitempty"`
	Toasts       int            `json:"toasts"`
	YouToasted   bool           `json:"you_toasted"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
}

type CheckinUser struct {
	ID              string  `json:"id"`
	Username        string  `json:"username"`
	DisplayUsername string  `json:"display_username"`
	DisplayName     string  `json:"display_name"`
	AvatarURL       *string `json:"avatar_url"`
}

type BeverageRef struct {
	ID            string         `json:"id"`
	Name          I18nText       `json:"name"`
	Brewery       BreweryRef     `json:"brewery"`
	Category      CategoryLabel  `json:"category"`
	LabelImageURL *string        `json:"label_image_url,omitempty"`
}

type BreweryRef struct {
	ID     string    `json:"id"`
	Name   I18nText  `json:"name"`
	Region *string   `json:"region,omitempty"`
}

type PhotoRef struct {
	URL       string `json:"url"`
	SortOrder int    `json:"sort_order"`
}

// CheckinSummary is a lighter shape for "recent check-ins" sections that
// don't need photos / tags arrays.
type CheckinSummary struct {
	ID        string      `json:"id"`
	User      CheckinUser `json:"user"`
	Rating    *float64    `json:"rating"`
	Review    *string     `json:"review"`
	CreatedAt time.Time   `json:"created_at"`
}

// FeedItem matches HANDOFF's feedItem shape exactly.
type FeedItem struct {
	ID         string      `json:"id"`
	User       CheckinUser `json:"user"`
	Beverage   BeverageRef `json:"beverage"`
	Rating     *float64    `json:"rating"`
	Review     *string     `json:"review"`
	Tags       []FlavorTag `json:"tags"`
	Toasts     int         `json:"toasts"`
	YouToasted bool        `json:"you_toasted"`
	PhotoCount int         `json:"photo_count"`
	Venue      *VenueRef   `json:"venue,omitempty"`
	CreatedAt  time.Time   `json:"created_at"`
}

// ToastState is the response body for the toast toggle endpoint.
type ToastState struct {
	Toasts     int  `json:"toasts"`
	YouToasted bool `json:"you_toasted"`
}

// ---------------------------------------------------------------------------
// Social
// ---------------------------------------------------------------------------

type FollowRequest struct {
	UserID          string    `json:"user_id"`
	Username        string    `json:"username"`
	DisplayUsername string    `json:"display_username"`
	DisplayName     string    `json:"display_name"`
	AvatarURL       *string   `json:"avatar_url"`
	Bio             *string   `json:"bio"`
	CreatedAt       time.Time `json:"created_at"`
}

type FollowResult struct {
	Status string `json:"status"` // 'accepted' | 'pending'
}

// ---------------------------------------------------------------------------
// Collections
// ---------------------------------------------------------------------------

type Collection struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	EntryCount int       `json:"entry_count"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

type CollectionEntry struct {
	Beverage BeverageRef `json:"beverage"`
	Note     *string     `json:"note,omitempty"`
	AddedAt  time.Time   `json:"added_at"`
}

type CollectionDetail struct {
	Collection
	Entries []CollectionEntry `json:"entries"`
}

type CreateCollectionRequest struct {
	Name string `json:"name"`
}

func (r *CreateCollectionRequest) Validate() error {
	r.Name = strings.TrimSpace(r.Name)
	if len([]rune(r.Name)) < 1 || len([]rune(r.Name)) > 50 {
		return wrapValidation("name must be 1-50 characters")
	}
	return nil
}

type UpdateCollectionRequest struct {
	Name string `json:"name"`
}

func (r *UpdateCollectionRequest) Validate() error {
	r.Name = strings.TrimSpace(r.Name)
	if len([]rune(r.Name)) < 1 || len([]rune(r.Name)) > 50 {
		return wrapValidation("name must be 1-50 characters")
	}
	return nil
}

type AddCollectionEntryRequest struct {
	BeverageID string  `json:"beverage_id"`
	Note       *string `json:"note,omitempty"`
}

func (r *AddCollectionEntryRequest) Validate() error {
	if r.BeverageID == "" {
		return wrapValidation("beverage_id is required")
	}
	if r.Note != nil && len([]rune(*r.Note)) > 200 {
		return wrapValidation("note must be ≤ 200 characters")
	}
	return nil
}

type UpdateCollectionEntryRequest struct {
	Note *string `json:"note,omitempty"`
}

func (r *UpdateCollectionEntryRequest) Validate() error {
	if r.Note != nil && len([]rune(*r.Note)) > 200 {
		return wrapValidation("note must be ≤ 200 characters")
	}
	return nil
}

// ---------------------------------------------------------------------------
// RBAC roles (Phase 5a)
// ---------------------------------------------------------------------------

// UserRole mirrors the postgres user_role enum (migration 007). Three values
// only: user (default), moderator (can triage), admin (full access). The
// column lives on `users.role` and is read on every admin-scoped request
// (no JWT claim) so a demotion takes effect within one indexed PK lookup
// rather than waiting for the access-token TTL.
type UserRole string

const (
	RoleUser      UserRole = "user"
	RoleModerator UserRole = "moderator"
	RoleAdmin     UserRole = "admin"
)

// Valid reports whether s is one of the three accepted role strings.
func (r UserRole) Valid() bool {
	switch r {
	case RoleUser, RoleModerator, RoleAdmin:
		return true
	}
	return false
}

// ---------------------------------------------------------------------------
// Beverage feedback
// ---------------------------------------------------------------------------

type BeverageRequest struct {
	Payload map[string]any `json:"payload"`
}

func (r *BeverageRequest) Validate() error {
	if len(r.Payload) == 0 {
		return wrapValidation("payload is required")
	}
	return nil
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// wrapValidation joins the sentinel with a human message so handlers can
// errors.Is(err, apierror.ErrValidation) and read the original message.
func wrapValidation(msg string) error {
	return fmt.Errorf("%w: %s", apierror.ErrValidation, msg)
}

// LocalizedDefaultCollections returns the names of the two seeded collections
// in the user's chosen locale. Per SPEC §6.1 the names are user-renameable,
// so these are seed defaults only — users can override them at any time.
//
// Strings chosen as the standard transliterations of the English names,
// consistent with how comparable beverage-tracking apps localize the
// "inventory / wishlist" concept. Designer has not pinned alternative
// strings; if they do, update both this map and the unit test in
// `types_test.go::TestLocalizedDefaultCollectionsConstant`.
func LocalizedDefaultCollections(locale string) (inventory, wishlist string) {
	switch locale {
	case "ja":
		return "インベントリー", "ウィッシュリスト"
	case "ko":
		return "인벤토리", "위시리스트"
	default:
		// en + any unknown locale falls back to English.
		return "Inventory", "Wishlist"
	}
}

// ErrMsg extracts the human message from a validation error wrapped with
// wrapValidation.
func ErrMsg(err error) string {
	if err == nil {
		return ""
	}
	s := err.Error()
	// best-effort: drop the sentinel prefix if present
	for _, prefix := range []string{"validation: ", "bad_request: "} {
		if strings.HasPrefix(s, prefix) {
			return strings.TrimPrefix(s, prefix)
		}
	}
	return s
}

// Sentinel guard so importers can use `errors.Is(err, domain.ErrValidation)`.
var (
	_ = errors.New // silence unused import on some builds
)
