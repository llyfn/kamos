package domain

import (
	"encoding/json"
	"fmt"
)

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
