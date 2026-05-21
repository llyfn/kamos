package domain

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"
)

func TestRegisterRequestValidate(t *testing.T) {
	tests := []struct {
		name    string
		in      RegisterRequest
		wantErr string // substring of expected error msg, "" = no error
	}{
		{
			"valid",
			RegisterRequest{Username: "yamamoto", Email: "y@example.com", Password: "password1", DisplayName: "Yama"},
			"",
		},
		{
			"username too short",
			RegisterRequest{Username: "yo", Email: "y@example.com", Password: "password1"},
			"username",
		},
		{
			"username has dash",
			RegisterRequest{Username: "yama-moto", Email: "y@example.com", Password: "password1"},
			"username",
		},
		{
			"password too short",
			RegisterRequest{Username: "yamamoto", Email: "y@example.com", Password: "short"},
			"password",
		},
		{
			"bad email",
			RegisterRequest{Username: "yamamoto", Email: "no-at-symbol", Password: "password1"},
			"email",
		},
		{
			"bio too long",
			func() RegisterRequest {
				bio := strings.Repeat("x", 201)
				return RegisterRequest{Username: "yamamoto", Email: "y@example.com", Password: "password1", Bio: &bio}
			}(),
			"bio",
		},
		{
			"display name too long",
			RegisterRequest{
				Username:    "yamamoto",
				Email:       "y@example.com",
				Password:    "password1",
				DisplayName: strings.Repeat("y", 51),
			},
			"display_name",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.in.Validate()
			if tt.wantErr == "" {
				if err != nil {
					t.Fatalf("want nil, got %v", err)
				}
				return
			}
			if err == nil {
				t.Fatalf("want error containing %q, got nil", tt.wantErr)
			}
			if !errors.Is(err, ErrValidation) {
				t.Errorf("error should wrap ErrValidation, got %v", err)
			}
			if !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error %q does not contain %q", err.Error(), tt.wantErr)
			}
		})
	}
}

func TestValidRating(t *testing.T) {
	good := []float64{0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0}
	for _, v := range good {
		v := v
		if err := ValidRating(&v); err != nil {
			t.Errorf("rating %v: want valid, got %v", v, err)
		}
	}
	bad := []float64{0, 0.3, 0.75, 1.1, 5.5, -1}
	for _, v := range bad {
		v := v
		if err := ValidRating(&v); err == nil {
			t.Errorf("rating %v: want error, got nil", v)
		}
	}
	// nil is valid (rating is optional)
	if err := ValidRating(nil); err != nil {
		t.Errorf("nil rating: want valid, got %v", err)
	}
}

// TestRating_SPECScale centralizes the SPEC §4.2 rating invariant
// (0.5–5.0 in 0.5 steps; nil is allowed since rating is optional). The
// existing TestValidRating sprays the cases across two slices; this
// table-driven shape is what reviewers should grep for when checking
// "is the rating scale still enforced?" — one row per documented edge.
func TestRating_SPECScale(t *testing.T) {
	v0 := 0.0
	v05 := 0.5
	v04 := 0.4
	v5 := 5.0
	v55 := 5.5
	v47 := 4.7

	cases := []struct {
		name string
		in   *float64
		ok   bool
	}{
		{"zero is rejected (below floor)", &v0, false},
		{"half-step floor is accepted", &v05, true},
		{"below floor (0.4) is rejected", &v04, false},
		{"ceiling 5.0 is accepted", &v5, true},
		{"above ceiling 5.5 is rejected", &v55, false},
		{"step-misaligned 4.7 is rejected", &v47, false},
		{"nil is accepted (optional rating)", nil, true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := ValidRating(tc.in)
			if tc.ok && err != nil {
				t.Errorf("want valid, got %v", err)
			}
			if !tc.ok && err == nil {
				t.Errorf("want error, got nil")
			}
		})
	}
}

func TestCreateCheckinValidate(t *testing.T) {
	tooLong := strings.Repeat("r", 501)
	cases := []struct {
		name string
		in   CreateCheckinRequest
		want string
	}{
		{"missing beverage", CreateCheckinRequest{}, "beverage_id"},
		{"review too long", CreateCheckinRequest{BeverageID: "x", Review: &tooLong}, "review"},
		{
			"5 photos", CreateCheckinRequest{
				BeverageID: "x", Photos: []string{"a", "b", "c", "d", "e"},
			}, "4 photos",
		},
		{
			"bad rating step",
			func() CreateCheckinRequest {
				r := 3.25
				return CreateCheckinRequest{BeverageID: "x", Rating: &r}
			}(),
			"0.5",
		},
		{
			"good",
			func() CreateCheckinRequest {
				r := 4.5
				return CreateCheckinRequest{BeverageID: "x", Rating: &r}
			}(),
			"",
		},
	}
	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.in.Validate()
			if tt.want == "" {
				if err != nil {
					t.Fatalf("want valid, got %v", err)
				}
				return
			}
			if err == nil {
				t.Fatalf("want error containing %q, got nil", tt.want)
			}
			if !strings.Contains(err.Error(), tt.want) {
				t.Errorf("error %q does not contain %q", err.Error(), tt.want)
			}
		})
	}
}

func TestI18nResolveFallback(t *testing.T) {
	t1 := I18nText{EN: "Dassai", JA: "獺祭"}
	if got := t1.Resolve("ko"); got != "Dassai" {
		t.Errorf("ko fallback: got %q want Dassai", got)
	}
	if got := t1.Resolve("ja"); got != "獺祭" {
		t.Errorf("ja: got %q want 獺祭", got)
	}
	t2 := I18nText{EN: "X", KO: "K"}
	if got := t2.Resolve("ja"); got != "X" {
		t.Errorf("ja missing → en fallback: got %q", got)
	}
}

// M3 invariant: the public-profile projection must not contain `email` or
// `email_verified`. This is both a SPEC privacy requirement and a security
// invariant — the QA M3 finding tracked exactly this leak.
func TestUserToPublicJSONDoesNotLeakEmail(t *testing.T) {
	u := User{
		ID:              "u-1",
		Username:        "yamamoto",
		DisplayUsername: "Yamamoto",
		Email:           "secret@example.com",
		EmailVerified:   true,
		DisplayName:     "Yamamoto-san",
		Locale:          "ja",
		PrivacyMode:     "public",
		CreatedAt:       time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	}
	pub := u.ToPublic()
	b, err := json.Marshal(pub)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	s := string(b)
	// Public username MUST appear.
	if !strings.Contains(s, `"username"`) {
		t.Errorf("public JSON missing username: %s", s)
	}
	if !strings.Contains(s, `"yamamoto"`) {
		t.Errorf("public JSON missing username value: %s", s)
	}
	// Email MUST NOT appear under any of its possible JSON forms.
	for _, leak := range []string{`"email"`, `"email_verified"`, "secret@example.com"} {
		if strings.Contains(s, leak) {
			t.Errorf("public JSON leaks %q: %s", leak, s)
		}
	}
}

// Sanity: the full User shape (used only for /v1/users/me) DOES include
// the email — this is the contrast case that proves the public projection
// is actively scrubbing.
func TestUserFullJSONIncludesEmail(t *testing.T) {
	u := User{
		ID:       "u-1",
		Username: "yamamoto",
		Email:    "secret@example.com",
	}
	b, err := json.Marshal(u)
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if !strings.Contains(string(b), `"email":"secret@example.com"`) {
		t.Errorf("full User JSON should include email; got %s", b)
	}
}

func TestLocalizedDefaultCollectionsConstant(t *testing.T) {
	cases := []struct {
		locale, wantInv, wantWish string
	}{
		{"en", "Inventory", "Wishlist"},
		{"ja", "インベントリー", "ウィッシュリスト"},
		{"ko", "인벤토리", "위시리스트"},
		// Unknown locales fall back to English.
		{"", "Inventory", "Wishlist"},
		{"fr", "Inventory", "Wishlist"},
	}
	for _, tc := range cases {
		inv, wish := LocalizedDefaultCollections(tc.locale)
		if inv != tc.wantInv || wish != tc.wantWish {
			t.Errorf("locale %q: got (%q, %q) want (%q, %q)",
				tc.locale, inv, wish, tc.wantInv, tc.wantWish)
		}
	}
}

func TestUpdateMeRequestValidate(t *testing.T) {
	pn := func(s string) *string { return &s }
	cases := []struct {
		name string
		in   UpdateMeRequest
		want string
	}{
		{"no fields", UpdateMeRequest{}, ""},
		{"empty display_name", UpdateMeRequest{DisplayName: pn(" ")}, "display_name"},
		{"long display_name", UpdateMeRequest{DisplayName: pn(strings.Repeat("a", 51))}, "display_name"},
		{"long bio", UpdateMeRequest{Bio: pn(strings.Repeat("b", 201))}, "bio"},
		{"bad locale", UpdateMeRequest{Locale: pn("fr")}, "locale"},
		{"good locale", UpdateMeRequest{Locale: pn("ja")}, ""},
		{"bad privacy", UpdateMeRequest{PrivacyMode: pn("public-ish")}, "privacy_mode"},
		{"good privacy", UpdateMeRequest{PrivacyMode: pn("private")}, ""},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			err := tc.in.Validate()
			if tc.want == "" {
				if err != nil {
					t.Fatalf("want nil, got %v", err)
				}
				return
			}
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("want error containing %q, got %v", tc.want, err)
			}
		})
	}
}

func TestUpdateCheckinRejectsBeverageChange(t *testing.T) {
	bid := "bev-1"
	req := UpdateCheckinRequest{BeverageID: &bid}
	err := req.Validate()
	if err == nil {
		t.Fatalf("want error on beverage_id change")
	}
	if !errors.Is(err, ErrValidation) {
		t.Errorf("want ErrValidation, got %v", err)
	}
}

func TestCreateCollectionValidate(t *testing.T) {
	r := CreateCollectionRequest{Name: ""}
	if err := r.Validate(); err == nil {
		t.Fatalf("empty name: want error")
	}
	r2 := CreateCollectionRequest{Name: strings.Repeat("x", 51)}
	if err := r2.Validate(); err == nil {
		t.Fatalf("too long name: want error")
	}
	r3 := CreateCollectionRequest{Name: "Reserve"}
	if err := r3.Validate(); err != nil {
		t.Errorf("ok name: %v", err)
	}
}

// SEC-006 — SanitizeText rejects ASCII NUL, bidi-override, control chars
// when newline is not allowed, and over-length input. Multibyte / regular
// Unicode is passed through.
func TestSanitizeTextRejectsControl(t *testing.T) {
	type tc struct {
		name         string
		in           string
		allowNewline bool
		maxLen       int
		wantErr      bool
	}
	cases := []tc{
		{"empty ok", "", false, 10, false},
		{"plain ok", "hello", false, 10, false},
		{"multibyte ok", "酒造-こんにちは", false, 50, false},
		{"NUL rejected", "abc\x00def", true, 50, true},
		{"control rejected", "abc\x05def", true, 50, true},
		{"newline rejected when not allowed", "line1\nline2", false, 50, true},
		{"newline ok when allowed", "line1\nline2", true, 50, false},
		{"tab always ok", "a\tb", false, 50, false},
		{"DEL stripped", "ab\x7fc", false, 50, false},
		{"bidi LRE rejected", "ab‪cd", true, 50, true},
		{"bidi RLO rejected", "ab‮cd", true, 50, true},
		{"bidi LRI rejected", "ab⁦cd", true, 50, true},
		{"bidi PDI rejected", "ab⁩cd", true, 50, true},
		{"length cap", strings.Repeat("x", 11), false, 10, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := SanitizeText("field", c.in, c.allowNewline, c.maxLen)
			if c.wantErr && err == nil {
				t.Fatalf("expected error for %q", c.in)
			}
			if !c.wantErr && err != nil {
				t.Fatalf("unexpected error for %q: %v", c.in, err)
			}
		})
	}
}

// Stage 7 (M-11.5 / SEC-024) — the public submission body must reject
// payloads that omit required keys, use a non-enum category_slug, exceed
// the 4 KiB JSON cap, smuggle bidi/control bytes, or stuff a non-string
// into one of the typed string fields.
func TestBeverageRequestValidate(t *testing.T) {
	valid := func() map[string]any {
		return map[string]any{
			"name":          "Dassai 23",
			"brewery_name":  "Asahi Shuzo",
			"category_slug": "nihonshu",
		}
	}

	cases := []struct {
		name    string
		payload map[string]any
		wantErr string // substring; "" = no error
	}{
		{"valid minimal", valid(), ""},
		{
			"valid with optionals",
			func() map[string]any {
				m := valid()
				m["subcategory"] = "Junmai Daiginjo"
				notes := "tasted at\nizakaya"
				m["notes"] = notes
				return m
			}(),
			"",
		},
		{"empty payload", map[string]any{}, "payload is required"},
		{
			"missing name",
			func() map[string]any {
				m := valid()
				delete(m, "name")
				return m
			}(),
			"name is required",
		},
		{
			"missing brewery_name",
			func() map[string]any {
				m := valid()
				delete(m, "brewery_name")
				return m
			}(),
			"brewery_name is required",
		},
		{
			"missing category_slug",
			func() map[string]any {
				m := valid()
				delete(m, "category_slug")
				return m
			}(),
			"category_slug is required",
		},
		{
			"empty required string",
			func() map[string]any {
				m := valid()
				m["name"] = ""
				return m
			}(),
			"name is required",
		},
		{
			"category_slug not enum",
			func() map[string]any {
				m := valid()
				m["category_slug"] = "whiskey"
				return m
			}(),
			"category_slug must be one of",
		},
		{
			"name not a string",
			func() map[string]any {
				m := valid()
				m["name"] = 42
				return m
			}(),
			"name must be a string",
		},
		{
			"name too long",
			func() map[string]any {
				m := valid()
				m["name"] = strings.Repeat("x", 201)
				return m
			}(),
			"name must be ≤ 200",
		},
		{
			"notes too long",
			func() map[string]any {
				m := valid()
				m["notes"] = strings.Repeat("n", 501)
				return m
			}(),
			"notes must be ≤ 500",
		},
		{
			"name has newline",
			func() map[string]any {
				m := valid()
				m["name"] = "line1\nline2"
				return m
			}(),
			"control character",
		},
		{
			"name has bidi override",
			func() map[string]any {
				m := valid()
				m["name"] = "Dassai‮23"
				return m
			}(),
			"bidi-override",
		},
		{
			"payload too large",
			func() map[string]any {
				m := valid()
				// Push the JSON over 4 KiB by stashing a large unknown
				// blob. Unknown keys are allowed to round-trip but the
				// total payload still has to fit the cap.
				m["bulk"] = strings.Repeat("a", 5*1024)
				return m
			}(),
			"≤ 4096 bytes",
		},
	}
	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			r := BeverageRequest{Payload: tt.payload}
			err := r.Validate()
			if tt.wantErr == "" {
				if err != nil {
					t.Fatalf("want nil, got %v", err)
				}
				return
			}
			if err == nil {
				t.Fatalf("want error containing %q, got nil", tt.wantErr)
			}
			if !errors.Is(err, ErrValidation) {
				t.Errorf("error should wrap ErrValidation, got %v", err)
			}
			if !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("error %q does not contain %q", err.Error(), tt.wantErr)
			}
		})
	}
}
