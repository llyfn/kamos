// Package storage abstracts the blob backend used for check-in photos.
//
// Two implementations:
//   - R2: Cloudflare R2 (S3-compatible) via aws-sdk-go-v2 + PresignClient.
//   - Disabled: a no-op that refuses with domain.ErrStorageDisabled. Used
//     when the operator has not set the R2_* env vars yet. Selecting this
//     keeps the API process bootable without any third-party credentials.
//
// Both implementations satisfy the Storage interface so handlers stay
// branch-free.
package storage

import (
	"context"
	"time"

	"github.com/kamos/api/internal/domain"
)

// PresignedPut is the result of issuing a presigned PUT URL.
type PresignedPut struct {
	URL       string            // the URL the client PUTs to
	Headers   map[string]string // headers the client MUST set on the PUT
	BlobKey   string            // bucket-relative key (echoed back)
	ExpiresAt time.Time         // when the URL stops working
}

// Storage is the surface every handler depends on. Implementations:
//   - *R2       — real backend.
//   - Disabled  — no-op refusal.
type Storage interface {
	// PresignPut returns a one-shot PUT URL for the given blob_key.
	// ttl must be ≤ 1h (S3 limit) and > 0.
	PresignPut(ctx context.Context, blobKey, contentType string, byteSize int64, ttl time.Duration) (*PresignedPut, error)
	// PublicURL turns a blob_key into the customer-facing CDN URL. May be
	// empty if no PublicBaseURL was configured (e.g., Disabled).
	PublicURL(blobKey string) string
	// Delete removes a blob. Safe to call on the Disabled backend (no-op).
	Delete(ctx context.Context, blobKey string) error
}

// Disabled is the no-op Storage. Selected when env vars are empty.
type Disabled struct{}

// PresignPut on Disabled always refuses; handlers map this to 503.
func (Disabled) PresignPut(ctx context.Context, blobKey, contentType string, byteSize int64, ttl time.Duration) (*PresignedPut, error) {
	return nil, domain.ErrStorageDisabled
}

// PublicURL on Disabled returns empty. The check-in photos endpoint will
// then store an empty string in check_in_photos.photo_url — see the
// integration test for documented behaviour.
func (Disabled) PublicURL(string) string { return "" }

// Delete on Disabled is a successful no-op.
func (Disabled) Delete(context.Context, string) error { return nil }
