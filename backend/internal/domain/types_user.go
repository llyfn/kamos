package domain

import (
	"regexp"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

type User struct {
	ID              string     `json:"id"`
	Username        string     `json:"username"`         // lowercase handle (the unique key)
	DisplayUsername string     `json:"display_username"` // case-preserved for rendering
	Email           string     `json:"email"`
	EmailVerified   bool       `json:"email_verified"`
	DisplayName     string     `json:"display_name"`
	AvatarURL       *string    `json:"avatar_url"`
	Bio             *string    `json:"bio"`
	Locale          string     `json:"locale"`
	PrivacyMode     string     `json:"privacy_mode"`
	CreatedAt       time.Time  `json:"created_at"`
	DeletedAt       *time.Time `json:"-"`
}

// PublicUser is the User shape exposed via GET /v1/users/{username}.
// Email and EmailVerified are intentionally omitted — they are private
// to the owner and would leak through the public profile endpoint otherwise.
type PublicUser struct {
	ID              string    `json:"id"`
	Username        string    `json:"username"`
	DisplayUsername string    `json:"display_username"`
	DisplayName     string    `json:"display_name"`
	AvatarURL       *string   `json:"avatar_url"`
	Bio             *string   `json:"bio"`
	Locale          string    `json:"locale"`
	PrivacyMode     string    `json:"privacy_mode"`
	CreatedAt       time.Time `json:"created_at"`
}

// ToPublic returns the privacy-safe projection of u.
func (u User) ToPublic() PublicUser {
	return PublicUser{
		ID:              u.ID,
		Username:        u.Username,
		DisplayUsername: u.DisplayUsername,
		DisplayName:     u.DisplayName,
		AvatarURL:       u.AvatarURL,
		Bio:             u.Bio,
		Locale:          u.Locale,
		PrivacyMode:     u.PrivacyMode,
		CreatedAt:       u.CreatedAt,
	}
}

type UserStats struct {
	Checkins  int `json:"checkins"`
	Unique    int `json:"unique"`
	Followers int `json:"followers"`
	Following int `json:"following"`
}

type Me struct {
	User
	Stats UserStats `json:"stats"`
	// Phase 5a: role surfaces RBAC state so the admin Flutter client can
	// decide whether to show admin UI. Read from users.role on every /me
	// request (no JWT claim) so a demotion takes effect immediately.
	Role UserRole `json:"role"`
	// DeletedAt surfaces soft-delete status. Pre-suspension this is null;
	// after admin suspension or self-DELETE, the JWT is also revoked by
	// the SoftDeleteCache, so this field is normally only seen by admin
	// queues looking at lapsed soft-deleted accounts.
	DeletedAt *time.Time `json:"deleted_at"`
}

// RegisterRequest is the body shape for POST /v1/auth/register.
type RegisterRequest struct {
	Username    string  `json:"username"`
	Email       string  `json:"email"`
	Password    string  `json:"password"`
	DisplayName string  `json:"display_name"`
	Locale      string  `json:"locale"`
	Bio         *string `json:"bio,omitempty"`
}

var (
	usernameRE = regexp.MustCompile(`^[A-Za-z0-9_]{3,30}$`)
	// rfc-5322 is a beast; we use a pragmatic regex that catches obvious typos
	// without over-rejecting legitimate addresses.
	emailRE = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
)

func (r *RegisterRequest) Validate() error {
	r.Username = strings.TrimSpace(r.Username)
	r.Email = strings.TrimSpace(r.Email)
	r.DisplayName = strings.TrimSpace(r.DisplayName)
	r.Locale = strings.TrimSpace(strings.ToLower(r.Locale))
	if !usernameRE.MatchString(r.Username) {
		return wrapValidation("username must be 3-30 chars of letters, digits, or underscore")
	}
	if !emailRE.MatchString(r.Email) {
		return wrapValidation("email is malformed")
	}
	if len(r.Password) < 8 {
		return wrapValidation("password must be at least 8 characters")
	}
	if r.DisplayName == "" {
		r.DisplayName = r.Username
	}
	// SEC-006: reject control + bidi-override characters in display_name.
	clean, err := SanitizeText("display_name", r.DisplayName, false, 50)
	if err != nil {
		return err
	}
	r.DisplayName = clean
	if r.Bio != nil {
		bio, err := SanitizeText("bio", *r.Bio, false, 200)
		if err != nil {
			return err
		}
		*r.Bio = bio
	}
	if r.Locale != "en" && r.Locale != "ja" && r.Locale != "ko" {
		r.Locale = "en"
	}
	return nil
}

// UpdateMeRequest — PATCH /v1/users/me.
type UpdateMeRequest struct {
	DisplayName *string `json:"display_name,omitempty"`
	Bio         *string `json:"bio,omitempty"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
	Locale      *string `json:"locale,omitempty"`
	PrivacyMode *string `json:"privacy_mode,omitempty"`
}

func (r *UpdateMeRequest) Validate() error {
	if r.DisplayName != nil {
		s := strings.TrimSpace(*r.DisplayName)
		if len([]rune(s)) < 1 {
			return wrapValidation("display_name must be 1-50 characters")
		}
		clean, err := SanitizeText("display_name", s, false, 50)
		if err != nil {
			return err
		}
		*r.DisplayName = clean
	}
	if r.Bio != nil {
		clean, err := SanitizeText("bio", *r.Bio, false, 200)
		if err != nil {
			return err
		}
		*r.Bio = clean
	}
	if r.Locale != nil {
		v := strings.ToLower(strings.TrimSpace(*r.Locale))
		if v != "en" && v != "ja" && v != "ko" {
			return wrapValidation("locale must be one of: en, ja, ko")
		}
		*r.Locale = v
	}
	if r.PrivacyMode != nil {
		v := strings.ToLower(strings.TrimSpace(*r.PrivacyMode))
		if v != "public" && v != "private" {
			return wrapValidation("privacy_mode must be one of: public, private")
		}
		*r.PrivacyMode = v
	}
	return nil
}
