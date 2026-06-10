package domain

import (
	"encoding/json"
	"fmt"

	"github.com/kamos/api/internal/spec"
)

// I18nText is the JSONB shape used for beverage / producer / category / tag
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

// I18nFromJSON unmarshals a JSONB column into I18nText. Tolerates missing keys.
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

// LocalizedDefaultCollections returns the seeded collection names in the
// user's locale. Values come from specs/invariants.yaml via
// spec.DefaultCollectionInventory / spec.DefaultCollectionWishlist; unknown
// locales fall back to spec.LocaleFallback.
func LocalizedDefaultCollections(locale string) (inventory, wishlist string) {
	inv, ok := spec.DefaultCollectionInventory[locale]
	if !ok {
		inv = spec.DefaultCollectionInventory[spec.LocaleFallback]
	}
	wish, ok := spec.DefaultCollectionWishlist[locale]
	if !ok {
		wish = spec.DefaultCollectionWishlist[spec.LocaleFallback]
	}
	return inv, wish
}
