// Internal-package tests for unexported helpers. Anything that needs the
// router or repository wiring lives in handlers_test.go (external package);
// this file targets the small, pure helpers in handlers.go.
package handlers

import (
	"net/http/httptest"
	"testing"
)

// localeKey must whitelist en/ja/ko and map everything else to the EN
// fallback bucket so the cache-key axis stays bounded.
func TestLocaleKey(t *testing.T) {
	cases := []struct {
		name   string
		header string
		want   string
	}{
		{"empty header", "", "any"},
		{"plain en", "en", "en"},
		{"plain ja", "ja", "ja"},
		{"plain ko", "ko", "ko"},
		{"en-US collapses to en", "en-US", "en"},
		{"ja-JP collapses to ja", "ja-JP", "ja"},
		{"ko-KR collapses to ko", "ko-KR", "ko"},
		{"uppercase EN", "EN", "en"},
		{"unsupported zh -> en bucket", "zh", "en"},
		{"unsupported zh-CN -> en bucket", "zh-CN", "en"},
		{"unsupported fr-FR -> en bucket", "fr-FR", "en"},
		{"comma list takes primary", "ja-JP,en;q=0.8", "ja"},
		{"weight after primary", "ko;q=0.9", "ko"},
		{"whitespace tolerated", " en-GB ", "en"},
		{"single-char primary -> en bucket", "x", "en"},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/", nil)
			if tc.header != "" {
				req.Header.Set("Accept-Language", tc.header)
			}
			got := localeKey(req)
			if got != tc.want {
				t.Errorf("localeKey(%q) = %q, want %q", tc.header, got, tc.want)
			}
		})
	}
}
