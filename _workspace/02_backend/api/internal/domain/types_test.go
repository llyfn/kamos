package domain

import (
	"errors"
	"strings"
	"testing"

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
