package domain

import (
	"encoding/json"
	"fmt"
)

// ---------------------------------------------------------------------------
// Beverage feedback (user-submitted requests)
// ---------------------------------------------------------------------------

// BeverageRequest is the public body for POST /v1/beverage-requests. The
// payload is intentionally free-form JSONB — admin moderation
// re-keys this into structured Beverage rows on approval.
//
// Stage 7 (M-11.5 / SEC-024): the payload is now constrained so a hostile
// user cannot stuff arbitrary documents into the public submission queue
// or burn moderator attention on garbage. Required keys mirror the fields
// the admin queue UI actually uses; unknown extra keys are still allowed
// (they round-trip into PayloadRaw for the moderator to see), but each
// known string is sanitized against control / bidi / NUL bytes.
//
// Migration 016: per-beverage `prefecture` / `region` were dropped — the
// approval moderator UI (AdminApproveBeverageRequest) no longer accepts
// them either, and brewery locality is now curated via
// PATCH /v1/admin/breweries/{id}. We accordingly stopped declaring
// `prefecture` / `region` as known fields on the user submission: a
// client that still sends them will see the values round-trip into
// PayloadRaw (no validation, no sanitization) for the moderator to see
// as free-form hints, but they will not be promoted into any
// structured Beverage column.
type BeverageRequest struct {
	Payload map[string]any `json:"payload"`
}

// payloadMaxBytes is the serialized-JSON cap. 4 KiB comfortably holds the
// known string fields plus a few extra metadata hints from the client
// without giving an attacker a place to store secrets-by-proxy.
const payloadMaxBytes = 4 * 1024

// payloadCategorySlugEnum mirrors beverage_categories.slug in migration 002.
// Re-declared here (rather than reusing the cached taxonomy) so domain stays
// pure — no DB dependency in the validator.
var payloadCategorySlugEnum = map[string]struct{}{
	"nihonshu": {},
	"shochu":   {},
	"liqueur":  {},
}

// payloadField captures the per-field sanitization rules.
//
// `notes` is the only place a user wants newlines; everything else is a
// single-line label and rejects newlines. Lengths track the user-visible
// max characters per field — `notes` matches the check-in review cap
// (500), the rest are single-line labels (200).
type payloadField struct {
	key          string
	required     bool
	allowNewline bool
	maxLen       int
}

var beverageRequestFields = []payloadField{
	{key: "name", required: true, allowNewline: false, maxLen: 200},
	{key: "brewery_name", required: true, allowNewline: false, maxLen: 200},
	{key: "category_slug", required: true, allowNewline: false, maxLen: 200},
	// Optional sanitized strings — only validated when present.
	{key: "subcategory", required: false, allowNewline: false, maxLen: 200},
	{key: "label_image_url", required: false, allowNewline: false, maxLen: 200},
	{key: "notes", required: false, allowNewline: true, maxLen: 500},
}

func (r *BeverageRequest) Validate() error {
	if len(r.Payload) == 0 {
		return wrapValidation("payload is required")
	}

	// Size cap — compute on the serialized representation. Even if the
	// map only carries one key, an attacker could nest deeply-recursive
	// values; json.Marshal expands everything before we measure.
	raw, err := json.Marshal(r.Payload)
	if err != nil {
		return wrapValidation("payload is not serializable")
	}
	if len(raw) > payloadMaxBytes {
		return wrapValidation(fmt.Sprintf("payload must be ≤ %d bytes", payloadMaxBytes))
	}

	// Per-field sanitization. Anything not declared in beverageRequestFields
	// is left untouched (the moderator UI renders it for human review). The
	// 4 KiB cap above is the backstop for unknown keys.
	for _, f := range beverageRequestFields {
		v, present := r.Payload[f.key]
		if !present {
			if f.required {
				return wrapValidation(f.key + " is required")
			}
			continue
		}
		s, ok := v.(string)
		if !ok {
			return wrapValidation(f.key + " must be a string")
		}
		if f.required && s == "" {
			return wrapValidation(f.key + " is required")
		}
		// Optional fields are allowed to be empty (caller meant "absent").
		if s == "" {
			continue
		}
		cleaned, err := SanitizeText(f.key, s, f.allowNewline, f.maxLen)
		if err != nil {
			return err
		}
		r.Payload[f.key] = cleaned
	}

	// Enum check on category_slug. Must run AFTER sanitization (the
	// sanitizer leaves the case intact and the enum is lowercase).
	slug := r.Payload["category_slug"].(string)
	if _, ok := payloadCategorySlugEnum[slug]; !ok {
		return wrapValidation("category_slug must be one of: nihonshu, shochu, liqueur")
	}
	return nil
}
