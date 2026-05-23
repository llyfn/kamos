// Package domain — sentinel errors.
//
// Stage 3 split: previously every sentinel lived in `internal/apierror` and
// imported `net/http` transitively into every repository file. That
// architectural inversion (data-access layer transitively depending on
// HTTP) made it harder to share repositories with non-HTTP entry points
// (a future worker / CLI / batch job). The fix is to keep sentinels in
// the domain package (no `net/http` dependency) and route HTTP coupling
// through internal/httperr.
//
// All sentinels formerly in `apierror` now live here. The `apierror` shim
// re-exports them for backward compatibility — new code should reach for
// `domain.ErrNotFound`, `domain.ErrConflict`, etc. directly.
package domain

import "errors"

// Repository / service layers return one of these; the httperr.WriteFrom
// mapper translates them to HTTP status + machine-readable code. Wrap
// with fmt.Errorf("%w: detail", domain.Err...) when extra context is
// useful — errors.Is walks the wrap chain.
var (
	ErrNotFound          = errors.New("not_found")
	ErrConflict          = errors.New("conflict")
	ErrForbidden         = errors.New("forbidden")
	ErrUnauthorized      = errors.New("unauthorized")
	ErrValidation        = errors.New("validation")
	ErrBadRequest        = errors.New("bad_request")
	ErrUsernameHeld      = errors.New("username_held")
	ErrEmailTaken        = errors.New("email_taken")
	ErrBeverageNotFound  = errors.New("beverage_not_found")
	ErrCheckinNotFound   = errors.New("checkin_not_found")
	ErrCollectionFull    = errors.New("collection_full")
	ErrPhotoCapExceeded  = errors.New("photo_cap_exceeded")
	ErrFollowSelf        = errors.New("follow_self")
	ErrTokenExpired      = errors.New("token_expired")
	ErrInvalidCredential = errors.New("invalid_credential")
	ErrRateLimited       = errors.New("rate_limited")
	// ErrStorageDisabled is returned when an endpoint that needs the blob
	// store is called but R2 was not configured (env vars empty). The
	// presign endpoint maps this to 503.
	ErrStorageDisabled = errors.New("storage_disabled")
	// ErrUploadNotCompleted is returned when a client tries to attach a
	// photo_uploads row that hasn't reached an attachable state yet.
	ErrUploadNotCompleted = errors.New("upload_not_completed")
	// ErrNotImplemented is the disabled-storage no-op refusal.
	ErrNotImplemented = errors.New("not_implemented")
	// ErrRefreshTokenRaceLost is returned by RefreshTokenRepo.RotateAtomic
	// when the predecessor row was already revoked by a concurrent rotation
	// (UPDATE … WHERE revoked_at IS NULL RETURNING id, RowsAffected = 0).
	// The caller treats this as TOKEN_INVALID — exactly one successor
	// lands per predecessor (SEC-010).
	ErrRefreshTokenRaceLost = errors.New("refresh_token_race_lost")
	// ErrBreweryHasLiveBeverages is returned by BreweryRepo.SoftDelete when
	// at least one beverage still references the brewery (deleted_at IS NULL).
	// FK is ON DELETE RESTRICT so even though soft-delete only flips the
	// brewery's deleted_at, leaving live children would orphan them from
	// /v1/breweries lookups. The admin must soft-delete or reassign the
	// dependent beverages first. Maps to 409 BREWERY_HAS_LIVE_BEVERAGES.
	ErrBreweryHasLiveBeverages = errors.New("brewery_has_live_beverages")
)
