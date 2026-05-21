package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/kamos/api/internal/auth"
	"github.com/kamos/api/internal/config"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/email"
	"github.com/kamos/api/internal/repository"
)

// AuthService owns the credential / google / refresh-rotation flows. It is
// the single place where the (username-check + email-check + user-insert +
// default-collections + refresh-issue + verification-mail) dance lives;
// handlers shrink to decode → validate → call.
type AuthService struct {
	cfg     *config.Config
	log     *slog.Logger
	users   AuthUserRepo
	tokens  AuthRefreshRepo
	signer  *auth.Signer
	mailer  email.Mailer
	baseURL string
}

// AuthUserRepo is the slice of repository.UserRepo the auth service needs.
// Defined here (consumer side) so a test can substitute a fake without
// touching pgx.
type AuthUserRepo interface {
	CheckUsernameAvailability(ctx context.Context, username string) (state string, availableAt time.Time, err error)
	EmailExists(ctx context.Context, email string) (bool, error)
	CreateUserWithDefaults(ctx context.Context, p repository.CreateUserParams) (*domain.User, error)
	FindByEmail(ctx context.Context, email string) (*repository.AuthRow, error)
	FindByGoogleSub(ctx context.Context, sub string) (*domain.User, error)
	FindByID(ctx context.Context, id string) (*domain.User, error)
	LoadPasswordHash(ctx context.Context, id string) (string, error)
	UpdatePasswordHash(ctx context.Context, id, hash string) error
	UpdateEmail(ctx context.Context, id, email string) error
	CreateVerificationToken(ctx context.Context, userID, token string) error
	FindUserByVerificationToken(ctx context.Context, token string) (string, error)
	MarkEmailVerified(ctx context.Context, userID, token string) error
}

// AuthRefreshRepo is the slice of repository.RefreshTokenRepo the auth
// service needs.
type AuthRefreshRepo interface {
	Insert(ctx context.Context, userID string, hash []byte, parentID *string, familyID string, ttl time.Duration) (string, error)
	LookupByHash(ctx context.Context, hash []byte) (*repository.RefreshTokenRow, error)
	MarkRevoked(ctx context.Context, id string) error
	RevokeFamily(ctx context.Context, familyID string) (int, error)
	RotateAtomic(ctx context.Context, predecessorID, userID string, hash []byte, familyID string, ttl time.Duration) (string, error)
	RevokeAllForUser(ctx context.Context, userID string) (int, error)
}

func newAuthService(d Deps) *AuthService {
	s := &AuthService{
		cfg:    d.Cfg,
		log:    d.Log,
		signer: d.Signer,
		mailer: d.Mailer,
	}
	if d.Repos != nil {
		s.users = d.Repos.Users
		s.tokens = d.Repos.RefreshTokens
	}
	if d.Cfg != nil {
		s.baseURL = d.Cfg.AppBaseURL
	}
	return s
}

func (s *AuthService) refreshTTL() time.Duration {
	if s.cfg != nil && s.cfg.RefreshTTL > 0 {
		return s.cfg.RefreshTTL
	}
	return auth.DefaultRefreshTTL
}

// IssueAuthPair generates a new access JWT and originating refresh token
// for the given user.
func (s *AuthService) IssueAuthPair(ctx context.Context, user *domain.User) (access, refresh string, err error) {
	access, err = s.signer.Sign(user.ID, user.Username)
	if err != nil {
		return "", "", fmt.Errorf("IssueAuthPair sign: %w", err)
	}
	raw, hash, err := auth.NewRefreshSecret()
	if err != nil {
		return "", "", fmt.Errorf("IssueAuthPair secret: %w", err)
	}
	if _, err := s.tokens.Insert(ctx, user.ID, hash, nil, "", s.refreshTTL()); err != nil {
		return "", "", fmt.Errorf("IssueAuthPair insert: %w", err)
	}
	return access, raw, nil
}

// SendVerificationEmail renders and dispatches a verification mail. Errors
// are logged at WARN; we never fail the caller's request — verification
// mail is best-effort. SEC-011: only log the raw link in non-production.
func (s *AuthService) SendVerificationEmail(ctx context.Context, user *domain.User, token string) {
	link := s.baseURL + "/verify?token=" + token
	data := email.TemplateData{
		DisplayName:  user.DisplayName,
		VerifyLink:   link,
		AppName:      "KAMOS",
		SupportEmail: "support@kamos.app",
	}
	subject, htmlBody, textBody, err := email.Render("verify_email", user.Locale, data)
	if err != nil {
		if s.log != nil {
			s.log.Warn("verification_email_render", "err", err, "user_id", user.ID)
		}
		return
	}
	if s.cfg != nil && s.cfg.Env != "production" && s.log != nil {
		s.log.Info("verification link", "user_id", user.ID, "link", link)
	}
	if s.mailer == nil {
		return
	}
	if err := s.mailer.Send(ctx, user.Email, subject, htmlBody, textBody); err != nil {
		if s.log != nil {
			s.log.Warn("verification_email_send", "err", err, "user_id", user.ID)
		}
	}
}

// AuthResult is the wire shape returned by Register / Login / GoogleLogin /
// RotateRefresh. Mirrors domain.AuthResponse but without leaking the response
// shape into the service contract.
type AuthResult struct {
	User             domain.User
	AccessToken      string
	RefreshToken     string
	RefreshExpiresIn int64
}

// Register orchestrates the registration flow: availability check → email
// check → password hash → user + default collections insert → verification
// token issue → verification mail dispatch → auth pair issue. Any sentinel
// errors flow through unchanged so the handler maps them to HTTP status.
func (s *AuthService) Register(ctx context.Context, req domain.RegisterRequest, randomToken func(int) (string, error)) (*AuthResult, error) {
	state, _, err := s.users.CheckUsernameAvailability(ctx, req.Username)
	if err != nil {
		return nil, fmt.Errorf("Register username: %w", err)
	}
	if state == "live" || state == "held" {
		return nil, domain.ErrUsernameHeld
	}
	taken, err := s.users.EmailExists(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("Register email: %w", err)
	}
	if taken {
		return nil, domain.ErrEmailTaken
	}
	hashed, err := auth.HashPassword(req.Password)
	if err != nil {
		return nil, fmt.Errorf("Register hash: %w", err)
	}
	user, err := s.users.CreateUserWithDefaults(ctx, repository.CreateUserParams{
		DisplayUsername: req.Username,
		Email:           req.Email,
		EmailVerified:   false,
		PasswordHash:    &hashed,
		DisplayName:     req.DisplayName,
		Bio:             req.Bio,
		Locale:          req.Locale,
	})
	if err != nil {
		return nil, fmt.Errorf("Register insert: %w", err)
	}
	token, _ := randomToken(32)
	if err := s.users.CreateVerificationToken(ctx, user.ID, token); err != nil && s.log != nil {
		s.log.Error("CreateVerificationToken", "err", err)
	}
	s.SendVerificationEmail(ctx, user, token)
	access, refresh, err := s.IssueAuthPair(ctx, user)
	if err != nil {
		return nil, err
	}
	return &AuthResult{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     refresh,
		RefreshExpiresIn: int64(s.refreshTTL().Seconds()),
	}, nil
}

// Login orchestrates email+password login. Returns ErrInvalidCredential on
// any failure so callers don't distinguish "no user", "no password", or
// "wrong password" at the wire (SEC-018: dummy compare on the no-user
// path equalizes wall-clock time).
func (s *AuthService) Login(ctx context.Context, req domain.LoginRequest) (*AuthResult, error) {
	row, err := s.users.FindByEmail(ctx, req.Email)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			auth.VerifyDummyPassword(req.Password)
			return nil, domain.ErrInvalidCredential
		}
		return nil, fmt.Errorf("Login find: %w", err)
	}
	if row.PasswordHash == nil {
		auth.VerifyDummyPassword(req.Password)
		return nil, domain.ErrInvalidCredential
	}
	if err := auth.VerifyPassword(*row.PasswordHash, req.Password); err != nil {
		return nil, domain.ErrInvalidCredential
	}
	access, refresh, err := s.IssueAuthPair(ctx, &row.User)
	if err != nil {
		return nil, err
	}
	return &AuthResult{
		User:             row.User,
		AccessToken:      access,
		RefreshToken:     refresh,
		RefreshExpiresIn: int64(s.refreshTTL().Seconds()),
	}, nil
}

// RotateRefresh orchestrates the rotating refresh-token flow with re-use
// detection (see auth.go.original::RefreshToken for the full 6-case rule
// list).
func (s *AuthService) RotateRefresh(ctx context.Context, raw string) (*AuthResult, error) {
	hash := auth.HashRefreshToken(raw)
	row, err := s.tokens.LookupByHash(ctx, hash)
	if err != nil {
		return nil, fmt.Errorf("RotateRefresh lookup: %w", err)
	}
	// Re-use detection: presented token is revoked → burn the family.
	if row.RevokedAt != nil {
		n, ferr := s.tokens.RevokeFamily(ctx, row.FamilyID)
		if ferr != nil && s.log != nil {
			s.log.Error("RefreshToken family revoke", "err", ferr,
				"user_id", row.UserID, "family_id", row.FamilyID)
		}
		if s.log != nil {
			s.log.Warn("refresh_token_reuse_detected",
				"user_id", row.UserID,
				"family_id", row.FamilyID,
				"revoked_count", n,
			)
		}
		return nil, domain.ErrInvalidCredential // handler maps → 401 TOKEN_INVALID
	}
	if time.Now().After(row.ExpiresAt) {
		return nil, domain.ErrTokenExpired
	}
	user, err := s.users.FindByID(ctx, row.UserID)
	if err != nil {
		if errors.Is(err, domain.ErrNotFound) {
			return nil, domain.ErrInvalidCredential
		}
		return nil, fmt.Errorf("RotateRefresh find user: %w", err)
	}
	access, err := s.signer.Sign(user.ID, user.Username)
	if err != nil {
		return nil, fmt.Errorf("RotateRefresh sign: %w", err)
	}
	rawNew, newHash, err := auth.NewRefreshSecret()
	if err != nil {
		return nil, fmt.Errorf("RotateRefresh secret: %w", err)
	}
	if _, err := s.tokens.RotateAtomic(ctx, row.ID, user.ID, newHash, row.FamilyID, s.refreshTTL()); err != nil {
		if errors.Is(err, domain.ErrRefreshTokenRaceLost) {
			return nil, domain.ErrInvalidCredential
		}
		return nil, fmt.Errorf("RotateRefresh rotate: %w", err)
	}
	return &AuthResult{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     rawNew,
		RefreshExpiresIn: int64(s.refreshTTL().Seconds()),
	}, nil
}

// GoogleLogin orchestrates Google ID-token sign-in: either link to an
// existing google_sub OR register a fresh account using the provided /
// derived username. Returns the same AuthResult shape as Login.
//
// `googlePayload` is the result of auth.GoogleVerifier.Verify — passed in
// rather than re-verified here so the handler keeps ownership of the verifier.
func (s *AuthService) GoogleLogin(ctx context.Context, req domain.GoogleLoginRequest, payload *auth.GooglePayload) (*AuthResult, error) {
	existing, err := s.users.FindByGoogleSub(ctx, payload.Sub)
	if err != nil && !errors.Is(err, domain.ErrNotFound) {
		return nil, fmt.Errorf("GoogleLogin lookup: %w", err)
	}
	if existing != nil {
		return s.googleLoginExistingPath(ctx, existing)
	}
	return s.googleLoginCreatePath(ctx, req, payload)
}

// googleLoginExistingPath handles the "found a row by google_sub" branch.
func (s *AuthService) googleLoginExistingPath(ctx context.Context, user *domain.User) (*AuthResult, error) {
	access, refresh, err := s.IssueAuthPair(ctx, user)
	if err != nil {
		return nil, err
	}
	return &AuthResult{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     refresh,
		RefreshExpiresIn: int64(s.refreshTTL().Seconds()),
	}, nil
}

// googleLoginCreatePath handles the first-login branch. Returns one of
// ErrUsernameHeld, ErrEmailTaken, ErrValidation (USERNAME_REQUIRED) when
// the candidate username can't be derived.
func (s *AuthService) googleLoginCreatePath(ctx context.Context, req domain.GoogleLoginRequest, payload *auth.GooglePayload) (*AuthResult, error) {
	uname := ""
	if req.Username != nil && *req.Username != "" {
		uname = *req.Username
	} else if payload.Email != "" {
		if at := strings.IndexByte(payload.Email, '@'); at > 0 {
			uname = payload.Email[:at]
		}
	}
	cand := SanitizeUsernameCandidate(uname)
	if cand == "" {
		return nil, errUsernameRequired
	}
	state, _, err := s.users.CheckUsernameAvailability(ctx, cand)
	if err != nil {
		return nil, fmt.Errorf("googleLoginCreate avail: %w", err)
	}
	if state == "live" || state == "held" {
		return nil, domain.ErrUsernameHeld
	}
	if payload.Email != "" {
		taken, err := s.users.EmailExists(ctx, payload.Email)
		if err != nil {
			return nil, fmt.Errorf("googleLoginCreate email: %w", err)
		}
		if taken {
			return nil, domain.ErrEmailTaken
		}
	}
	locale := "en"
	if req.Locale != nil {
		l := *req.Locale
		if l == "en" || l == "ja" || l == "ko" {
			locale = l
		}
	}
	dispName := payload.Name
	if dispName != "" {
		if clean, err := domain.SanitizeText("display_name", dispName, false, 50); err == nil {
			dispName = clean
		} else {
			dispName = ""
		}
	}
	if dispName == "" {
		dispName = cand
	}
	var avatar *string
	if payload.Picture != "" {
		a := payload.Picture
		avatar = &a
	}
	user, err := s.users.CreateUserWithDefaults(ctx, repository.CreateUserParams{
		DisplayUsername: cand,
		Email:           payload.Email,
		EmailVerified:   payload.EmailVerified,
		GoogleSub:       &payload.Sub,
		DisplayName:     dispName,
		AvatarURL:       avatar,
		Locale:          locale,
	})
	if err != nil {
		return nil, fmt.Errorf("googleLoginCreate insert: %w", err)
	}
	access, refresh, err := s.IssueAuthPair(ctx, user)
	if err != nil {
		return nil, err
	}
	return &AuthResult{
		User:             *user,
		AccessToken:      access,
		RefreshToken:     refresh,
		RefreshExpiresIn: int64(s.refreshTTL().Seconds()),
	}, nil
}

// ErrUsernameRequired is a service-layer marker the handler maps to
// 422 USERNAME_REQUIRED. Carried as a wrapped ErrValidation so the
// existing writeErr path produces the right status.
var errUsernameRequired = errors.New("USERNAME_REQUIRED: please choose a username")

// ErrUsernameRequired is the public alias used by handlers when matching
// the GoogleLogin "no derivable username" branch.
func ErrUsernameRequired() error { return errUsernameRequired }

// SanitizeUsernameCandidate strips disallowed characters from a Google-
// derived username candidate and trims to the SPEC 3-30 range. Returns ""
// if the result is too short. Exported so handlers can use the same logic
// for any client-supplied first-login username before the service is hit.
func SanitizeUsernameCandidate(s string) string {
	var b []rune
	for _, ch := range s {
		switch {
		case ch >= 'a' && ch <= 'z',
			ch >= 'A' && ch <= 'Z',
			ch >= '0' && ch <= '9',
			ch == '_':
			b = append(b, ch)
		}
		if len(b) >= 30 {
			break
		}
	}
	if len(b) < 3 {
		return ""
	}
	return string(b)
}

// VerifyEmail orchestrates the verify-email flow.
func (s *AuthService) VerifyEmail(ctx context.Context, token string) error {
	userID, err := s.users.FindUserByVerificationToken(ctx, token)
	if err != nil {
		return err
	}
	return s.users.MarkEmailVerified(ctx, userID, token)
}

// ResendVerification issues a fresh 24h token for the given user and
// fires the verification mail (best-effort).
func (s *AuthService) ResendVerification(ctx context.Context, userID string, randomToken func(int) (string, error)) error {
	token, _ := randomToken(32)
	if err := s.users.CreateVerificationToken(ctx, userID, token); err != nil {
		return err
	}
	user, err := s.users.FindByID(ctx, userID)
	if err != nil {
		if s.log != nil {
			s.log.Warn("ResendVerification: lookup user", "err", err, "user_id", userID)
		}
		return nil
	}
	s.SendVerificationEmail(ctx, user, token)
	return nil
}

// ChangePassword orchestrates the authed password-change flow.
func (s *AuthService) ChangePassword(ctx context.Context, userID, current, next string) error {
	currentHash, err := s.users.LoadPasswordHash(ctx, userID)
	if err != nil {
		return err
	}
	if err := auth.VerifyPassword(currentHash, current); err != nil {
		return domain.ErrInvalidCredential
	}
	newHash, err := auth.HashPassword(next)
	if err != nil {
		return fmt.Errorf("ChangePassword hash: %w", err)
	}
	return s.users.UpdatePasswordHash(ctx, userID, newHash)
}

// ChangeEmail orchestrates the authed email-change flow: uniqueness check,
// update, fresh verification token + mail dispatch.
func (s *AuthService) ChangeEmail(ctx context.Context, userID, newEmail string, randomToken func(int) (string, error)) error {
	taken, err := s.users.EmailExists(ctx, newEmail)
	if err != nil {
		return err
	}
	if taken {
		return domain.ErrEmailTaken
	}
	if err := s.users.UpdateEmail(ctx, userID, newEmail); err != nil {
		return err
	}
	token, _ := randomToken(32)
	if err := s.users.CreateVerificationToken(ctx, userID, token); err != nil && s.log != nil {
		s.log.Error("EmailChange token", "err", err)
	}
	user, err := s.users.FindByID(ctx, userID)
	if err != nil {
		if s.log != nil {
			s.log.Warn("EmailChange: lookup user", "err", err, "user_id", userID)
		}
		return nil
	}
	s.SendVerificationEmail(ctx, user, token)
	return nil
}

// Logout revokes either a single refresh token (when raw != "") or every
// active refresh token for the user. Mismatched ownership returns nil so
// the handler can render 204 silently per the existing contract.
func (s *AuthService) Logout(ctx context.Context, userID, raw string) error {
	if raw != "" {
		hash := auth.HashRefreshToken(raw)
		row, err := s.tokens.LookupByHash(ctx, hash)
		if err != nil {
			if errors.Is(err, domain.ErrNotFound) {
				return nil // best-effort
			}
			return err
		}
		if row.UserID != userID {
			if s.log != nil {
				s.log.Warn("logout_token_owner_mismatch",
					"authed_user_id", userID, "token_user_id", row.UserID)
			}
			return nil
		}
		return s.tokens.MarkRevoked(ctx, row.ID)
	}
	_, err := s.tokens.RevokeAllForUser(ctx, userID)
	return err
}
