package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
)

// presignPutTTL is the lifetime baked into the signature returned by
// /v1/uploads/photo-presign. Long enough that mobile clients on a slow
// connection still have time to PUT; short enough that a leaked URL is
// not a long-term security hole.
const presignPutTTL = 15 * time.Minute

// maxPhotoBytes mirrors the CHECK constraint on photo_uploads.byte_size in
// migration 004. Duplicated here so a violation is reported as a clean 422
// before the INSERT, instead of pgx surfacing the CHECK error as a 500.
const maxPhotoBytes int64 = 10 * 1024 * 1024

// presignOutstandingCap caps the number of un-attached, un-expired
// pending presigns a single user may hold. SEC-008: prevents a user from
// minting thousands of pending rows + presigned URLs to scrape R2
// capacity or stage a flood. 8 is comfortably above the SPEC 4-photos-
// per-check-in cap × concurrent drafts in the UI.
const presignOutstandingCap = 8

type photoPresignRequest struct {
	ContentType string `json:"content_type"`
	ByteSize    int64  `json:"byte_size"`
}

type photoPresignResponse struct {
	UploadID  string            `json:"upload_id"`
	UploadURL string            `json:"upload_url"`
	Headers   map[string]string `json:"headers"`
	BlobKey   string            `json:"blob_key"`
	ExpiresAt time.Time         `json:"expires_at"`
}

// PhotoPresign — POST /v1/uploads/photo-presign.
//
// Returns a presigned PUT URL for a single photo. The client PUTs the bytes
// directly to R2 with the supplied Content-Type, then calls
// POST /v1/check-ins/{id}/photos with the returned upload_id.
//
// When the server is running without R2 configured (R2_BUCKET unset), this
// endpoint returns 503 STORAGE_DISABLED — a deliberate, machine-readable
// signal that the feature is OFF at this deployment.
func (h *Handler) PhotoPresign(w http.ResponseWriter, r *http.Request) {
	uid, ok := h.authedID(w, r)
	if !ok {
		return
	}
	// SEC-008: refuse to mint a new presign when the caller already has
	// `presignOutstandingCap` un-attached pending rows in the window.
	// Forces the client to either finish attaching (which flips the row
	// to 'attached') or wait for the TTL to elapse (which makes the row
	// eligible for orphan cleanup).
	pending, err := h.Repos.PhotoUploads.CountPendingForUser(r.Context(), uid, presignPutTTL)
	if err != nil {
		h.writeErr(w, "PhotoPresign count pending", err)
		return
	}
	if pending >= presignOutstandingCap {
		httperr.WriteError(w, http.StatusTooManyRequests, "PRESIGN_OUTSTANDING_LIMIT",
			"too many pending photo uploads; finish attaching or wait")
		return
	}
	var req photoPresignRequest
	if err := decodeJSON(r, &req); err != nil {
		h.writeErr(w, "PhotoPresign decode", err)
		return
	}
	ext := extensionForContentType(req.ContentType)
	if ext == "" {
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"content_type must be image/jpeg, image/png, or image/webp")
		return
	}
	if req.ByteSize <= 0 || req.ByteSize > maxPhotoBytes {
		httperr.WriteError(w, http.StatusUnprocessableEntity, "VALIDATION",
			"byte_size must be in (0, 10485760]")
		return
	}

	uploadID := uuid.New().String()
	blobKey := fmt.Sprintf("checkins/%s/%s.%s", uid, uploadID, ext)

	if err := h.Repos.PhotoUploads.CreateWithID(
		r.Context(), uploadID, uid, blobKey, req.ContentType, req.ByteSize,
	); err != nil {
		h.writeErr(w, "PhotoPresign insert", err)
		return
	}

	pp, err := h.Storage.PresignPut(r.Context(), blobKey, req.ContentType, req.ByteSize, presignPutTTL)
	if err != nil {
		if errors.Is(err, domain.ErrStorageDisabled) {
			httperr.WriteError(w, http.StatusServiceUnavailable, "STORAGE_DISABLED",
				"photo uploads not configured on this server")
			return
		}
		h.writeErr(w, "PhotoPresign sign", err)
		return
	}

	httperr.WriteJSON(w, http.StatusOK, photoPresignResponse{
		UploadID:  uploadID,
		UploadURL: pp.URL,
		Headers:   pp.Headers,
		BlobKey:   pp.BlobKey,
		ExpiresAt: pp.ExpiresAt,
	})
}

// extensionForContentType maps the SPEC-allowed photo MIME types to a file
// extension. Empty return = rejected.
func extensionForContentType(ct string) string {
	switch ct {
	case "image/jpeg":
		return "jpg"
	case "image/png":
		return "png"
	case "image/webp":
		return "webp"
	}
	return ""
}
