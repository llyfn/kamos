// Package validate exposes the canonical user-supplied-string and rating
// validators shared between handler-side request validation and the
// repository's pre-write defense-in-depth checks.
//
// Stage 3 split: previously the helpers lived inline in domain/types.go
// (SanitizeText, ValidRating, venueValidateString). They've been moved here
// so the validation primitives don't bake the domain package's import set
// (in particular, the apierror sentinel coupling) into every consumer.
//
// The domain-package wrappers in types.go and types_venue.go remain so
// existing callers (`domain.SanitizeText`, `domain.ValidRating`) keep
// working. They delegate to this package and add the sentinel-error
// wrapping that the handler layer's writeErr inspects.
package validate

import (
	"errors"
	"fmt"
	"math"
)

// ErrInvalid is the sentinel every helper here returns on validation
// failure. Wrap with errors.Is to recognize it; callers in the domain
// package compose it with the apierror.ErrValidation sentinel so the
// HTTP layer can map it to 422.
var ErrInvalid = errors.New("invalid")

// fieldErr produces a human-readable error with the disallowed-rune kind
// stamped into the message.
func fieldErr(format string, args ...any) error {
	return fmt.Errorf("%w: "+format, append([]any{ErrInvalid}, args...)...)
}

// Text enforces the shared charset rule on free-form user-supplied
// strings:
//   - ASCII control chars < 0x20 are rejected except tab (0x09) and,
//     when allowNewline=true, LF (0x0a).
//   - ASCII DEL (0x7F) is stripped silently.
//   - Unicode bidi-override codepoints U+202A..U+202E and U+2066..U+2069
//     are rejected (SEC-006).
//
// Returns the cleaned string and an error if any disallowed rune appears
// or if the rune length exceeds maxLen. `field` is woven into the error
// message so callers don't have to wrap.
//
// allowNewline applies to LF only. The venue-rule variant (see Venue
// below) rejects newline unconditionally but tolerates tab the same way.
func Text(field, s string, allowNewline bool, maxLen int) (string, error) {
	var b []rune
	runes := 0
	for _, r := range s {
		switch {
		case r == 0:
			return "", fieldErr("%s contains NUL byte", field)
		case r == 0x7F:
			continue
		case r == 0x09:
			// tab — always allowed.
		case r == 0x0a:
			if !allowNewline {
				return "", fieldErr("%s contains a control character", field)
			}
		case r < 0x20:
			return "", fieldErr("%s contains a control character", field)
		case r >= 0x202A && r <= 0x202E,
			r >= 0x2066 && r <= 0x2069:
			return "", fieldErr("%s contains a bidi-override character", field)
		}
		b = append(b, r)
		runes++
	}
	if runes > maxLen {
		return "", fieldErr("%s must be ≤ %d characters", field, maxLen)
	}
	return string(b), nil
}

// Venue is the variant of Text used for shared-table venue strings (name,
// address, country, prefecture, locality). It rejects newline and any
// ASCII control char < 0x20 except tab, but otherwise lets Unicode through
// (international venue names are the common case). minRunes / maxRunes
// are the rune-length window; venue.name uses (1, 200), address (0, 500),
// country/prefecture/locality (0, 100).
//
// Unlike Text this returns just the error (the caller writes the value
// verbatim into the upsert input; no DEL-stripping behaviour is desired
// on shared-table strings).
func Venue(field, s string, minRunes, maxRunes int) error {
	n := 0
	for _, r := range s {
		n++
		if r == 0 {
			return fieldErr("venue.%s contains NUL byte", field)
		}
		if r < 0x20 && r != 0x09 {
			return fieldErr("venue.%s contains a control character", field)
		}
	}
	if n < minRunes || n > maxRunes {
		return fieldErr("venue.%s must be %d-%d characters", field, minRunes, maxRunes)
	}
	return nil
}

// Rating enforces SPEC §4.2: 0.5–5.0 in 0.25 steps (19 levels). Nil is
// valid (rating is optional per-check-in). The "in 0.25 steps" check
// snaps the input to the nearest quarter and rejects any meaningful
// residual so float precision drift doesn't slip through.
func Rating(r *float64) error {
	if r == nil {
		return nil
	}
	if *r < 0.5 || *r > 5.0 {
		return fieldErr("rating must be between 0.5 and 5.0")
	}
	q := math.Round(*r / 0.25)
	if math.Abs(*r-q*0.25) > 1e-9 {
		return fieldErr("rating must be in 0.25 steps")
	}
	return nil
}
