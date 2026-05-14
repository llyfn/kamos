package domain

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/kamos/api/internal/apierror"
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
			if !errors.Is(err, apierror.ErrValidation) {
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
	// All three locales currently return the English names — when the
	// designer pins localized strings this test will need updating per
	// the comment in types.go.
	for _, loc := range []string{"en", "ja", "ko"} {
		inv, wish := LocalizedDefaultCollections(loc)
		if inv != "Inventory" || wish != "Wishlist" {
			t.Errorf("locale %q: got (%q, %q)", loc, inv, wish)
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
	if !errors.Is(err, apierror.ErrValidation) {
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
