// Internal-package unit tests for the Stage 8 admin catalog request
// validators. These exercise the Validate methods directly without an
// HTTP transport, so we don't have to mock the role-gate DB lookup.
package handlers

import (
	"errors"
	"strings"
	"testing"

	"github.com/kamos/api/internal/domain"
)

func TestAdminBeverageCreateValidate(t *testing.T) {
	strPtr := func(s string) *string { return &s }
	base := func() AdminBeverageCreate {
		return AdminBeverageCreate{
			BreweryID:  "b-1",
			CategoryID: strPtr("c-1"),
			NameI18n:   domain.I18nText{EN: "X", JA: "Xj"},
		}
	}
	cases := []struct {
		name  string
		mut   func(*AdminBeverageCreate)
		want  string // expected error substring
		valid bool   // true = expect Validate to return nil
	}{
		{"baseline", func(r *AdminBeverageCreate) {}, "", true},
		{"missing brewery", func(r *AdminBeverageCreate) { r.BreweryID = "" }, "brewery_id", false},
		{"missing category id and slug", func(r *AdminBeverageCreate) {
			r.CategoryID = nil
			r.CategorySlug = nil
		}, "category_id or category_slug", false},
		{"slug only ok", func(r *AdminBeverageCreate) {
			r.CategoryID = nil
			r.CategorySlug = strPtr("nihonshu")
		}, "", true},
		{"both id and slug ok", func(r *AdminBeverageCreate) {
			r.CategorySlug = strPtr("shochu")
		}, "", true},
		{"empty id falls back to slug", func(r *AdminBeverageCreate) {
			r.CategoryID = strPtr("")
			r.CategorySlug = strPtr("liqueur")
		}, "", true},
		{"both empty rejected", func(r *AdminBeverageCreate) {
			r.CategoryID = strPtr("")
			r.CategorySlug = strPtr("")
		}, "category_id or category_slug", false},
		{"missing name.en", func(r *AdminBeverageCreate) { r.NameI18n.EN = "" }, "name_i18n", false},
		{"missing name.ja", func(r *AdminBeverageCreate) { r.NameI18n.JA = "" }, "name_i18n", false},
		{"abv negative", func(r *AdminBeverageCreate) { v := -0.1; r.ABV = &v }, "abv", false},
		{"abv over 60", func(r *AdminBeverageCreate) { v := 60.5; r.ABV = &v }, "abv", false},
		{"abv 0 ok", func(r *AdminBeverageCreate) { v := 0.0; r.ABV = &v }, "", true},
		{"abv 60 ok", func(r *AdminBeverageCreate) { v := 60.0; r.ABV = &v }, "", true},
		{"polishing 0", func(r *AdminBeverageCreate) { v := 0; r.PolishingRatio = &v }, "", true},
		{"polishing 100", func(r *AdminBeverageCreate) { v := 100; r.PolishingRatio = &v }, "", true},
		{"polishing 101", func(r *AdminBeverageCreate) { v := 101; r.PolishingRatio = &v }, "polishing_ratio", false},
		{"polishing negative", func(r *AdminBeverageCreate) { v := -1; r.PolishingRatio = &v }, "polishing_ratio", false},
		{"label not https", func(r *AdminBeverageCreate) { v := "http://x.test/y.jpg"; r.LabelImageURL = &v }, "https", false},
		{"label https ok", func(r *AdminBeverageCreate) { v := "https://x.test/y.jpg"; r.LabelImageURL = &v }, "", true},
		{"label too long", func(r *AdminBeverageCreate) {
			v := "https://x.test/" + strings.Repeat("a", 520)
			r.LabelImageURL = &v
		}, "label_image_url", false},
		{"bidi-override in name", func(r *AdminBeverageCreate) {
			r.NameI18n.EN = "hi\u202eevil"
		}, "bidi-override", false},
		{"control char in prefecture", func(r *AdminBeverageCreate) {
			v := "Hyogo\x01"
			r.Prefecture = &v
		}, "control character", false},
		{"prefecture too long", func(r *AdminBeverageCreate) {
			v := strings.Repeat("a", 200)
			r.Prefecture = &v
		}, "100", false},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			r := base()
			tc.mut(&r)
			err := r.Validate()
			if tc.valid {
				if err != nil {
					t.Fatalf("want valid, got %v", err)
				}
				return
			}
			if err == nil {
				t.Fatalf("want error containing %q, got nil", tc.want)
			}
			if !errors.Is(err, domain.ErrValidation) {
				t.Fatalf("want ErrValidation sentinel, got %v", err)
			}
			if tc.want != "" && !strings.Contains(err.Error(), tc.want) {
				t.Errorf("error %q does not contain %q", err.Error(), tc.want)
			}
		})
	}
}

func TestAdminBeverageUpdateValidate(t *testing.T) {
	// Update is partial — empty body is valid (no-op).
	r := AdminBeverageUpdate{}
	if err := r.Validate(); err != nil {
		t.Fatalf("empty update should validate: %v", err)
	}

	// Setting name_i18n with only en is rejected.
	bad := AdminBeverageUpdate{NameI18n: &domain.I18nText{EN: "X"}}
	if err := bad.Validate(); err == nil || !strings.Contains(err.Error(), "name_i18n") {
		t.Errorf("want name_i18n error, got %v", err)
	}

	// abv out of range.
	v := 75.0
	bad2 := AdminBeverageUpdate{ABV: &v}
	if err := bad2.Validate(); err == nil || !strings.Contains(err.Error(), "abv") {
		t.Errorf("want abv error, got %v", err)
	}
}

func TestAdminBreweryCreateValidate(t *testing.T) {
	base := func() AdminBreweryCreate {
		return AdminBreweryCreate{
			NameI18n: domain.I18nText{EN: "Brewery", JA: "酒造"},
		}
	}
	cases := []struct {
		name string
		mut  func(*AdminBreweryCreate)
		want string
		ok   bool
	}{
		{"baseline", func(r *AdminBreweryCreate) {}, "", true},
		{"missing name.en", func(r *AdminBreweryCreate) { r.NameI18n.EN = "" }, "name_i18n", false},
		{"missing name.ja", func(r *AdminBreweryCreate) { r.NameI18n.JA = "" }, "name_i18n", false},
		{"founded year too old", func(r *AdminBreweryCreate) { y := 799; r.FoundedYear = &y }, "founded_year", false},
		{"founded year too new", func(r *AdminBreweryCreate) { y := 2101; r.FoundedYear = &y }, "founded_year", false},
		{"founded year 800 ok", func(r *AdminBreweryCreate) { y := 800; r.FoundedYear = &y }, "", true},
		{"founded year 2100 ok", func(r *AdminBreweryCreate) { y := 2100; r.FoundedYear = &y }, "", true},
		{"website wrong scheme", func(r *AdminBreweryCreate) { v := "ftp://x.test"; r.Website = &v }, "website", false},
		{"website https ok", func(r *AdminBreweryCreate) { v := "https://kura.example"; r.Website = &v }, "", true},
		{"website http ok", func(r *AdminBreweryCreate) { v := "http://kura.example"; r.Website = &v }, "", true},
		{"website too long", func(r *AdminBreweryCreate) {
			v := "https://" + strings.Repeat("a", 600)
			r.Website = &v
		}, "website", false},
		{"bidi-override in name", func(r *AdminBreweryCreate) {
			r.NameI18n.EN = "kura\u2067evil"
		}, "bidi-override", false},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			r := base()
			tc.mut(&r)
			err := r.Validate()
			if tc.ok {
				if err != nil {
					t.Fatalf("want valid, got %v", err)
				}
				return
			}
			if err == nil {
				t.Fatalf("want error containing %q, got nil", tc.want)
			}
			if !errors.Is(err, domain.ErrValidation) {
				t.Fatalf("want ErrValidation sentinel, got %v", err)
			}
			if tc.want != "" && !strings.Contains(err.Error(), tc.want) {
				t.Errorf("error %q does not contain %q", err.Error(), tc.want)
			}
		})
	}
}

func TestAdminBreweryUpdateValidate(t *testing.T) {
	// Empty body is valid.
	r := AdminBreweryUpdate{}
	if err := r.Validate(); err != nil {
		t.Fatalf("empty update should validate: %v", err)
	}

	// Founded year out of range.
	y := 100
	bad := AdminBreweryUpdate{FoundedYear: &y}
	if err := bad.Validate(); err == nil || !strings.Contains(err.Error(), "founded_year") {
		t.Errorf("want founded_year error, got %v", err)
	}
}
