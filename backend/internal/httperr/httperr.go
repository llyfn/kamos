// Package httperr is the HTTP-coupling half of the former internal/apierror
// package. Sentinels now live in internal/domain (no net/http dependency);
// this package owns the WriteError / WriteFrom / WriteJSON / APIError
// machinery + the codeOf mapper.
//
// New code should:
//
//   - Return `domain.ErrX` (or `fmt.Errorf("%w: …", domain.ErrX)`) from
//     repository / service layers.
//   - Use `httperr.WriteFrom(w, log, op, err)` at the handler edge to
//     map a sentinel to its HTTP status + canonical body.
//   - Use the convenience helpers (`WriteUnauthorized`, `WriteValidation`,
//     `WriteForbidden`, `WriteNotFound`) when the handler already knows
//     the failure mode and doesn't need sentinel-routing.
package httperr

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/kamos/api/internal/domain"
)

// APIError is the body shape every error response uses.
//
//	{ "error": "<human>", "code": "<machine>" }
type APIError struct {
	Error string `json:"error"`
	Code  string `json:"code"`
}

// WriteJSON writes a JSON response with the given status. Nil body emits
// no payload (used for 204 / 304 cases that still want the explicit
// content-type header).
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if v != nil {
		_ = json.NewEncoder(w).Encode(v)
	}
}

// WriteError writes the canonical { error, code } body shape at the given
// HTTP status.
func WriteError(w http.ResponseWriter, status int, code, msg string) {
	WriteJSON(w, status, APIError{Error: msg, Code: code})
}

// Convenience helpers replacing the 20+ inline `WriteError(w, http.StatusXxx,
// "CODE", "msg")` call sites in the handler layer (STYLE-018, STYLE-042).

// WriteUnauthorized writes the canonical 401 UNAUTHORIZED response.
func WriteUnauthorized(w http.ResponseWriter) {
	WriteError(w, http.StatusUnauthorized, "UNAUTHORIZED", "unauthorized")
}

// WriteForbidden writes the canonical 403 FORBIDDEN response.
func WriteForbidden(w http.ResponseWriter) {
	WriteError(w, http.StatusForbidden, "FORBIDDEN", "forbidden")
}

// WriteNotFound writes the canonical 404 NOT_FOUND response.
func WriteNotFound(w http.ResponseWriter) {
	WriteError(w, http.StatusNotFound, "NOT_FOUND", "not found")
}

// WriteValidation writes a 422 VALIDATION response with the given message.
func WriteValidation(w http.ResponseWriter, msg string) {
	WriteError(w, http.StatusUnprocessableEntity, "VALIDATION", msg)
}

// WriteFrom inspects a sentinel and writes the matching HTTP status. Pass
// `log` so the handler can record internal-error details without leaking
// them to the client.
func WriteFrom(w http.ResponseWriter, log *slog.Logger, op string, err error) {
	switch {
	case errors.Is(err, domain.ErrUnauthorized):
		WriteUnauthorized(w)
	case errors.Is(err, domain.ErrForbidden):
		WriteForbidden(w)
	case errors.Is(err, domain.ErrNotFound),
		errors.Is(err, domain.ErrBeverageNotFound),
		errors.Is(err, domain.ErrCheckinNotFound):
		WriteNotFound(w)
	case errors.Is(err, domain.ErrConflict),
		errors.Is(err, domain.ErrUsernameHeld),
		errors.Is(err, domain.ErrEmailTaken):
		WriteError(w, http.StatusConflict, codeOf(err), err.Error())
	case errors.Is(err, domain.ErrValidation),
		errors.Is(err, domain.ErrPhotoCapExceeded),
		errors.Is(err, domain.ErrCollectionFull),
		errors.Is(err, domain.ErrFollowSelf):
		WriteError(w, http.StatusUnprocessableEntity, codeOf(err), err.Error())
	case errors.Is(err, domain.ErrBadRequest):
		WriteError(w, http.StatusBadRequest, "BAD_REQUEST", err.Error())
	case errors.Is(err, domain.ErrInvalidCredential):
		WriteError(w, http.StatusUnauthorized, "INVALID_CREDENTIAL", "invalid email or password")
	case errors.Is(err, domain.ErrTokenExpired):
		WriteError(w, http.StatusGone, "TOKEN_EXPIRED", "token expired")
	case errors.Is(err, domain.ErrRateLimited):
		WriteError(w, http.StatusTooManyRequests, "RATE_LIMITED", "rate_limited")
	case errors.Is(err, domain.ErrStorageDisabled), errors.Is(err, domain.ErrNotImplemented):
		WriteError(w, http.StatusServiceUnavailable, "STORAGE_DISABLED",
			"photo uploads not configured on this server")
	case errors.Is(err, domain.ErrUploadNotCompleted):
		WriteError(w, http.StatusConflict, "UPLOAD_NOT_COMPLETED",
			"upload has not been completed")
	default:
		if log != nil {
			log.Error("internal error", "op", op, "err", err)
		}
		WriteError(w, http.StatusInternalServerError, "INTERNAL", "internal error")
	}
}

// codeOf maps a sentinel to its canonical machine-readable code string.
// The default is "ERROR" — generic conflict / validation that didn't
// surface through a named sentinel.
func codeOf(err error) string {
	switch {
	case errors.Is(err, domain.ErrConflict):
		return "CONFLICT"
	case errors.Is(err, domain.ErrUsernameHeld):
		return "USERNAME_HELD"
	case errors.Is(err, domain.ErrEmailTaken):
		return "EMAIL_TAKEN"
	case errors.Is(err, domain.ErrValidation):
		return "VALIDATION"
	case errors.Is(err, domain.ErrPhotoCapExceeded):
		return "PHOTO_CAP_EXCEEDED"
	case errors.Is(err, domain.ErrCollectionFull):
		return "COLLECTION_FULL"
	case errors.Is(err, domain.ErrFollowSelf):
		return "FOLLOW_SELF"
	}
	return "ERROR"
}
