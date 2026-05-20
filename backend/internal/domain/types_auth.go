package domain

import "strings"

// ---------------------------------------------------------------------------
// Auth request / response shapes
// ---------------------------------------------------------------------------

// LoginRequest is the email+password login body.
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (r *LoginRequest) Validate() error {
	r.Email = strings.TrimSpace(r.Email)
	if r.Email == "" || r.Password == "" {
		return wrapValidation("email and password are required")
	}
	return nil
}

// GoogleLoginRequest carries a Google ID token from the client.
type GoogleLoginRequest struct {
	IDToken  string  `json:"id_token"`
	Username *string `json:"username,omitempty"` // first-login only
	Locale   *string `json:"locale,omitempty"`
}

func (r *GoogleLoginRequest) Validate() error {
	if r.IDToken == "" {
		return wrapValidation("id_token is required")
	}
	if r.Username != nil && !usernameRE.MatchString(*r.Username) {
		return wrapValidation("username must be 3-30 chars of letters, digits, or underscore")
	}
	return nil
}

// VerifyEmailRequest carries the 24h verification token.
type VerifyEmailRequest struct {
	Token string `json:"token"`
}

func (r *VerifyEmailRequest) Validate() error {
	if r.Token == "" {
		return wrapValidation("token is required")
	}
	return nil
}

// PasswordChangeRequest — authed endpoint.
type PasswordChangeRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

func (r *PasswordChangeRequest) Validate() error {
	if r.CurrentPassword == "" {
		return wrapValidation("current_password is required")
	}
	if len(r.NewPassword) < 8 {
		return wrapValidation("new_password must be at least 8 characters")
	}
	return nil
}

// EmailChangeRequest — authed endpoint; triggers re-verification.
type EmailChangeRequest struct {
	NewEmail string `json:"new_email"`
}

func (r *EmailChangeRequest) Validate() error {
	r.NewEmail = strings.TrimSpace(r.NewEmail)
	if !emailRE.MatchString(r.NewEmail) {
		return wrapValidation("new_email is malformed")
	}
	return nil
}

// AuthResponse is the body returned by register / login / google / refresh.
// The refresh_token is the raw (base64-rawurl 43-char) secret — the server
// stores only its SHA-256 hash. expires_in / refresh_expires_in are seconds.
type AuthResponse struct {
	User             User   `json:"user"`
	AccessToken      string `json:"access_token"`
	RefreshToken     string `json:"refresh_token"`
	TokenType        string `json:"token_type"`         // "Bearer"
	ExpiresIn        int64  `json:"expires_in"`         // access-token TTL, seconds
	RefreshExpiresIn int64  `json:"refresh_expires_in"` // refresh-token TTL, seconds
}

// RefreshTokenRequest is the body for POST /v1/auth/refresh.
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (r *RefreshTokenRequest) Validate() error {
	if r.RefreshToken == "" {
		return wrapValidation("refresh_token is required")
	}
	return nil
}

// LogoutRequest is the optional body for POST /v1/auth/logout. When the
// refresh_token is present, only that token is revoked; when absent, every
// active refresh token for the authed user is revoked (logout-everywhere).
type LogoutRequest struct {
	RefreshToken string `json:"refresh_token,omitempty"`
}
