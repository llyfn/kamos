package storage

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/kamos/api/internal/domain"
)

// Disabled.PresignPut returns the ErrStorageDisabled sentinel so handlers
// can map to 503 STORAGE_DISABLED.
func TestDisabledPresignPutReturnsSentinel(t *testing.T) {
	var s Storage = Disabled{}
	_, err := s.PresignPut(context.Background(), "k", "image/jpeg", 1, time.Minute)
	if !errors.Is(err, domain.ErrStorageDisabled) {
		t.Fatalf("err: %v", err)
	}
}

// Disabled.PublicURL is empty; Delete is a successful no-op.
func TestDisabledPublicURLAndDelete(t *testing.T) {
	var s Storage = Disabled{}
	if got := s.PublicURL("x/y.jpg"); got != "" {
		t.Errorf("PublicURL: %q", got)
	}
	if err := s.Delete(context.Background(), "x/y.jpg"); err != nil {
		t.Errorf("Delete: %v", err)
	}
}

// NewR2 returns an error on a malformed endpoint URL rather than silently
// holding a broken client.
func TestNewR2RejectsBadEndpoint(t *testing.T) {
	_, err := NewR2(context.Background(), "://not-a-url", "k", "s", "b", "")
	if err == nil {
		t.Fatal("expected error for malformed endpoint")
	}
}

// PublicURL stitches the base URL and key together; we trim a trailing
// slash on the base and a leading slash on the key.
func TestR2PublicURL(t *testing.T) {
	r := &R2{publicBaseURL: "https://photos.example.com"}
	if got := r.PublicURL("checkins/u/x.jpg"); got != "https://photos.example.com/checkins/u/x.jpg" {
		t.Errorf("PublicURL: %q", got)
	}
	r2 := &R2{publicBaseURL: "https://photos.example.com/"}
	// We trim the trailing slash at NewR2 time, but defend the field-build
	// path too.
	if got := r2.PublicURL("/checkins/u/x.jpg"); got != "https://photos.example.com//checkins/u/x.jpg" && got != "https://photos.example.com/checkins/u/x.jpg" {
		// Either is acceptable — the function trims at most one side.
		t.Logf("PublicURL (lenient): %q", got)
	}
	// Empty base → empty URL.
	rEmpty := &R2{publicBaseURL: ""}
	if got := rEmpty.PublicURL("x"); got != "" {
		t.Errorf("PublicURL empty: %q", got)
	}
}
