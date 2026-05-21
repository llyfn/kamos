package domain

import (
	"fmt"
	"regexp"
	"time"
)

// ---------------------------------------------------------------------------
// Venues
// ---------------------------------------------------------------------------

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
