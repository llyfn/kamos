// Package domain holds the request/response and DB-facing structs used by
// handlers and repositories. Validation methods enforce SPEC caps at the API
// boundary (DB CHECKs are a backstop, not the primary line of defense).
//
// Stage 3 split: types previously lived in a single types.go file. The
// individual structs and per-aggregate validators now live in:
//
//   - types_user.go        — User, PublicUser, Me, RegisterRequest, UpdateMeRequest, UserStats
//   - types_auth.go        — LoginRequest, GoogleLoginRequest, VerifyEmail, PasswordChange,
//     EmailChange, AuthResponse, RefreshToken, LogoutRequest
//   - types_beverage.go    — Brewery, BreweryRef, Beverage, BeverageDetail, BeverageRef,
//     CategoryLabel, FlavorAggregate, FlavorTag
//   - types_checkin.go     — Price, Create/Update CheckinRequest, Checkin, CheckinUser,
//     PhotoRef, CheckinSummary, FeedItem, ToastState, ValidRating
//   - types_venue.go       — CheckinVenue + venue validation helpers, Venue, VenueRef
//   - types_comment.go     — Comment, CreateCommentRequest
//   - types_collection.go  — Collection, CollectionEntry,
//     CollectionDetail, requests
//   - types_social.go      — FollowRequest, FollowResult
//   - types_admin.go       — UserRole
//   - types_request.go     — BeverageRequest (user-submitted feedback)
//   - types_localized.go   — I18nText, I18nFromJSON, LocalizedDefaultCollections
//
// This file (types.go) keeps only the cross-cutting helpers that don't
// belong to any one aggregate: SanitizeText, wrapValidation, ErrMsg.
package domain

import (
	"fmt"
	"strings"
)

// SanitizeText enforces a shared charset rule on free-form user-supplied
// text fields. It rejects:
//   - ASCII control chars < 0x20 except tab (0x09) and, when allowNewline,
//     LF (0x0a).
//   - ASCII DEL (0x7F) — stripped silently (rare in real input but a
//     poisoning vector).
//   - Unicode bidi-override codepoints U+202A..U+202E and U+2066..U+2069
//     (SEC-006 / "Trojan Source").
//
// Returns the trimmed string (silent DEL strip applied) and an error if
// any disallowed rune appears or if the rune-length is outside [1, maxLen].
// allowNewline = true permits LF as part of the body (used by review +
// comment bodies). The caller has already trimmed surrounding whitespace
// when that's desired — SanitizeText leaves internal whitespace alone.
//
// SEC-006: the bidi-override block lets a comment look benign in source
// (e.g. on a moderation review screen) while rendering as something else.
// We reject rather than strip so the user sees the error and rewrites.
func SanitizeText(field, s string, allowNewline bool, maxLen int) (string, error) {
	var b []rune
	runes := 0
	for _, r := range s {
		switch {
		case r == 0:
			return "", wrapValidation(field + " contains NUL byte")
		case r == 0x7F:
			// DEL — strip silently.
			continue
		case r == 0x09:
			// Tab — always allowed.
		case r == 0x0a:
			if !allowNewline {
				return "", wrapValidation(field + " contains a control character")
			}
		case r < 0x20:
			return "", wrapValidation(field + " contains a control character")
		case r >= 0x202A && r <= 0x202E,
			r >= 0x2066 && r <= 0x2069:
			return "", wrapValidation(field + " contains a bidi-override character")
		}
		b = append(b, r)
		runes++
	}
	if runes > maxLen {
		return "", wrapValidation(fmt.Sprintf("%s must be ≤ %d characters", field, maxLen))
	}
	return string(b), nil
}

// wrapValidation joins the sentinel with a human message so handlers can
// errors.Is(err, domain.ErrValidation) and read the original message.
func wrapValidation(msg string) error {
	return fmt.Errorf("%w: %s", ErrValidation, msg)
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
