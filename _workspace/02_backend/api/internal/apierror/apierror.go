// Package apierror defines sentinel errors used across the API and maps them
// to HTTP status codes + machine-readable codes. Every handler that touches a
// repository should switch on these so the response shape is uniform.
package apierror

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
)

// Sentinel errors. Repository / service layers return one of these; handlers
// map them to HTTP status. Wrap with fmt.Errorf("%w: detail", Err...) when
// extra context is useful.
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
)

// APIError is the body shape every error response uses.
//   { "error": "<human>", "code": "<machine>" }
type APIError struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

// WriteJSON writes a JSON response with the given status.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if v != nil {
		_ = json.NewEncoder(w).Encode(v)
	}
}

// WriteError writes the canonical error body shape.
func WriteError(w http.ResponseWriter, status int, code, msg string) {
	WriteJSON(w, status, APIError{Error: msg, Code: code})
}

// WriteFrom inspects a sentinel and writes the matching HTTP status. Pass
// `log` so the handler can record internal-error details without leaking them
// to the client.
func WriteFrom(w http.ResponseWriter, log *slog.Logger, op string, err error) {
	switch {
	case errors.Is(err, ErrUnauthorized):
		WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
	case errors.Is(err, ErrForbidden):
		WriteError(w, http.StatusForbidden, "FORBIDDEN", "forbidden")
	case errors.Is(err, ErrNotFound),
		errors.Is(err, ErrBeverageNotFound),
		errors.Is(err, ErrCheckinNotFound):
		WriteError(w, http.StatusNotFound, "NOT_FOUND", "not found")
	case errors.Is(err, ErrConflict),
		errors.Is(err, ErrUsernameHeld),
		errors.Is(err, ErrEmailTaken):
		WriteError(w, http.StatusConflict, codeOf(err), err.Error())
	case errors.Is(err, ErrValidation),
		errors.Is(err, ErrPhotoCapExceeded),
		errors.Is(err, ErrCollectionFull),
		errors.Is(err, ErrFollowSelf):
		WriteError(w, http.StatusUnprocessableEntity, codeOf(err), err.Error())
	case errors.Is(err, ErrBadRequest):
		WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
	case errors.Is(err, ErrInvalidCredential):
		WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
	case errors.Is(err, ErrTokenExpired):
		WriteError(w, http.StatusGone, "TOKEN_EXPIRED", "token expired")
	case errors.Is(err, ErrRateLimited):
		WriteError(w, http.StatusTooManyRequests, "RATE_LIMITED", "rate_limited")
	case errors.Is(err, ErrStorageDisabled), errors.Is(err, ErrNotImplemented):
		WriteError(w, http.StatusServiceUnavailable, "STORAGE_DISABLED",
			"photo uploads not configured on this server")
	case errors.Is(err, ErrUploadNotCompleted):
		WriteError(w, http.StatusConflict, "UPLOAD_NOT_COMPLETED",
			"upload has not been completed")
	default:
		if log != nil {
			log.Error("internal error", "op", op, "err", err)
		}
		WriteError(w, http.StatusInternalServerError, "INTERNAL", "internal error")
	}
}

func codeOf(err error) string {
	switch {
	case errors.Is(err, ErrConflict):
		return "CONFLICT"
	case errors.Is(err, ErrUsernameHeld):
		return "USERNAME_HELD"
	case errors.Is(err, ErrEmailTaken):
		return "EMAIL_TAKEN"
	case errors.Is(err, ErrValidation):
		return "VALIDATION"
	case errors.Is(err, ErrPhotoCapExceeded):
		return "PHOTO_CAP_EXCEEDED"
	case errors.Is(err, ErrCollectionFull):
		return "COLLECTION_FULL"
	case errors.Is(err, ErrFollowSelf):
		return "FOLLOW_SELF"
	}
	return "ERROR"
}
