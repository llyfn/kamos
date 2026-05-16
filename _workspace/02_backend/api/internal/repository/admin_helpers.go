package repository

import (
	"encoding/json"
	"fmt"

	"github.com/kamos/api/internal/domain"
)

// unmarshalJSONBToMap decodes a JSONB byte slice into a map. Used by admin
// listings that surface the original user-submitted payload.
func unmarshalJSONBToMap(raw []byte) (map[string]any, error) {
	if len(raw) == 0 {
		return map[string]any{}, nil
	}
	out := map[string]any{}
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, fmt.Errorf("unmarshalJSONBToMap: %w", err)
	}
	return out, nil
}

// jsonMarshalI18n encodes the canonical {en, ja, ko?} shape. ko is omitted
// when empty (matches the JSON-tagged omitempty on domain.I18nText).
func jsonMarshalI18n(t domain.I18nText) ([]byte, error) {
	b, err := json.Marshal(t)
	if err != nil {
		return nil, fmt.Errorf("jsonMarshalI18n: %w", err)
	}
	return b, nil
}
