package domain

import (
	"encoding/json"
	"fmt"

	"github.com/kamos/api/internal/spec"
)

// ---------------------------------------------------------------------------
// Beverage feedback (user-submitted requests)
// ---------------------------------------------------------------------------

// BeverageRequest is the public body for POST /v1/beverage-requests. The
// payload is intentionally free-form JSONB — admin moderation re-keys
// this into structured Beverage rows on approval.
//
// The payload is bounded so a hostile user cannot stuff arbitrary
// documents into the public submission queue or burn moderator attention
// on garbage. Required keys mirror the fields the admin queue UI actually
// uses; unknown extra keys are still allowed (they round-trip into
// PayloadRaw for the moderator to see), but each known string is
// sanitized against control / bidi / NUL bytes.
//
// Per-beverage `prefecture` / `region` are not known fields — clients that
// send them will see the values round-trip into PayloadRaw (no validation,
// no sanitization) for the moderator to see as free-form hints. Producer
// locality is curated via PATCH /v1/admin/producers/{id}.
type BeverageRequest struct {
	Payload map[string]any `json:"payload"`
}

// payloadMaxBytes is the serialized-JSON cap. The value lives in
// specs/invariants.yaml (beverage_request.payload_max_bytes) so changes
// flow from the SoT.
const payloadMaxBytes = spec.BeverageRequestPayloadMax

// payloadCategorySlugEnum mirrors beverage_categories.slug from the catalog
// seed. Sourced from the SoT (specs/invariants.yaml categories.slugs) so
// domain stays pure — no DB dependency in the validator.
var payloadCategorySlugEnum = func() map[string]struct{} {
	m := make(map[string]struct{}, len(spec.CategorySlugs))
	for _, s := range spec.CategorySlugs {
		m[s] = struct{}{}
	}
	return m
}()

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
	{key: "name", required: true, allowNewline: false, maxLen: spec.BeverageRequestStringMax},
	{key: "producer_name", required: true, allowNewline: false, maxLen: spec.BeverageRequestStringMax},
	{key: "category_slug", required: true, allowNewline: false, maxLen: spec.BeverageRequestStringMax},
	// Optional sanitized strings — only validated when present.
	{key: "subcategory", required: false, allowNewline: false, maxLen: spec.BeverageRequestStringMax},
	{key: "label_image_url", required: false, allowNewline: false, maxLen: spec.BeverageRequestStringMax},
	{key: "notes", required: false, allowNewline: true, maxLen: spec.BeverageRequestNotesMax},
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
