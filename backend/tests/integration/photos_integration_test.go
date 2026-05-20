//go:build integration
// +build integration

package integration

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
)

// Phase 3 photo upload — Disabled-storage path.
//
// We're running with the default test harness (no R2_* envs set), so the
// server boots with storage.Disabled. Two contracts:
//
//  1. POST /v1/uploads/photo-presign → 503 STORAGE_DISABLED. This is the
//     machine-readable signal to the mobile client that the deployment
//     does not have R2 wired up.
//  2. POST /v1/check-ins/{id}/photos with an upload_id whose row we
//     planted directly via SQL still attaches successfully — the photo_url
//     column ends up empty because Storage.PublicURL is "" on Disabled.
//     We document this as the "no R2 configured" contract. Once R2 is
//     wired, this test will be updated to assert the real CDN URL.
func TestPhotoPresignReturns503WhenStorageDisabled(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "snapper", "snapper@example.com", "hunter2hunter2")

	body := map[string]any{
		"content_type": "image/jpeg",
		"byte_size":    1024,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/uploads/photo-presign", tok, body)
	if code != http.StatusServiceUnavailable {
		t.Fatalf("presign: status=%d body=%s", code, raw)
	}
	var e errBodyShape
	if err := json.Unmarshal(raw, &e); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if e.Code != "STORAGE_DISABLED" {
		t.Errorf("code: %q", e.Code)
	}
}

// PhotoPresign validates content_type before touching anything else.
func TestPhotoPresignContentTypeValidation(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, _ := mustRegister(t, srv, "validator", "validator@example.com", "hunter2hunter2")

	// Bad content type → 422.
	body := map[string]any{
		"content_type": "image/gif",
		"byte_size":    1024,
	}
	code, raw := doReq(t, srv, http.MethodPost, "/v1/uploads/photo-presign", tok, body)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("presign content_type: status=%d body=%s", code, raw)
	}

	// Negative byte size → 422.
	body = map[string]any{
		"content_type": "image/jpeg",
		"byte_size":    0,
	}
	code, raw = doReq(t, srv, http.MethodPost, "/v1/uploads/photo-presign", tok, body)
	if code != http.StatusUnprocessableEntity {
		t.Fatalf("presign byte_size: status=%d body=%s", code, raw)
	}
}

// Attach a synthetic 'pending' photo_uploads row to a check-in. Because
// storage is Disabled, the resulting check_in_photos.photo_url is "". The
// 4-photo cap still applies on the 5th attempt.
func TestAttachUploadedPhotoToCheckin(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	tok, uid := mustRegister(t, srv, "shutter", "shutter@example.com", "hunter2hunter2")
	bevID := seedBeverage(t, "Junmai")

	// Create the check-in.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", tok,
		map[string]any{"beverage_id": bevID, "rating": 4.0})
	if code != http.StatusCreated {
		t.Fatalf("create checkin: %d %s", code, raw)
	}
	var ci struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(raw, &ci)

	// Plant four 'pending' rows directly. Attaching all four succeeds; a
	// fifth returns the SPEC PHOTO_CAP_EXCEEDED.
	p := getPool(t)
	for i := 0; i < 5; i++ {
		uploadID := mustInsertPendingUpload(t, p, uid, fmt.Sprintf("checkins/%s/p%d.jpg", uid, i))
		code, raw := doReq(t, srv, http.MethodPost,
			"/v1/check-ins/"+ci.ID+"/photos", tok,
			map[string]any{"upload_id": uploadID})
		switch i {
		case 4:
			// 5th photo — repository enforces the cap.
			if code != http.StatusUnprocessableEntity {
				t.Fatalf("5th photo attach: status=%d body=%s", code, raw)
			}
			var e errBodyShape
			_ = json.Unmarshal(raw, &e)
			if e.Code != "PHOTO_CAP_EXCEEDED" {
				t.Errorf("5th photo code: %q", e.Code)
			}
		default:
			if code != http.StatusCreated {
				t.Fatalf("attach %d: status=%d body=%s", i, code, raw)
			}
			var ph struct {
				URL string `json:"url"`
			}
			_ = json.Unmarshal(raw, &ph)
			// With Disabled storage we expect an empty url — documented.
			if ph.URL != "" {
				t.Errorf("expected empty url under Disabled storage, got %q", ph.URL)
			}
		}
	}

	// And the photo_uploads row should be 'attached'.
	var status string
	if err := p.QueryRow(context.Background(),
		`SELECT status FROM photo_uploads WHERE check_in_id = $1 LIMIT 1;`,
		ci.ID).Scan(&status); err != nil {
		t.Fatalf("status lookup: %v", err)
	}
	if status != "attached" {
		t.Errorf("status: %q", status)
	}
}

// Trying to attach an upload that belongs to a different user → 404. Never
// leak existence to the unrelated viewer.
func TestAttachUploadOwnedByOtherUser(t *testing.T) {
	truncateAll(t)
	srv := newServer(t)
	defer srv.Close()

	_, owner := mustRegister(t, srv, "ownerx", "ownerx@example.com", "hunter2hunter2")
	thief, _ := mustRegister(t, srv, "thiefx", "thiefx@example.com", "hunter2hunter2")
	bevID := seedBeverage(t, "Daiginjo")

	// Thief creates their own check-in.
	code, raw := doReq(t, srv, http.MethodPost, "/v1/check-ins", thief,
		map[string]any{"beverage_id": bevID})
	if code != http.StatusCreated {
		t.Fatalf("create checkin: %d %s", code, raw)
	}
	var ci struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(raw, &ci)

	// Plant an upload owned by owner.
	p := getPool(t)
	uploadID := mustInsertPendingUpload(t, p, owner, "checkins/owner/x.jpg")

	code, raw = doReq(t, srv, http.MethodPost,
		"/v1/check-ins/"+ci.ID+"/photos", thief,
		map[string]any{"upload_id": uploadID})
	if code != http.StatusNotFound {
		t.Fatalf("attach foreign upload: status=%d body=%s", code, raw)
	}
}
