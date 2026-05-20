package domain

import (
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// Collections
// ---------------------------------------------------------------------------

type Collection struct {
	ID string `json:"id"`
	// OwnerID is the row's `user_id`. Exposed on the wire so clients can gate
	// owner-only UI (e.g. the visibility toggle on the detail screen) without
	// a second `GET /v1/users/me` round trip. Added in Phase 6a alongside
	// public-collection discovery.
	OwnerID    string `json:"owner_id"`
	Name       string `json:"name"`
	EntryCount int    `json:"entry_count"`
	// Visibility ('private' | 'public') — Phase 6a. Empty string on legacy
	// rows is treated by clients as 'private' (the Dart fromJson does the
	// fallback); the server fills the column with 'private' by default.
	Visibility string    `json:"visibility"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// PublicCollectionOwner is the slim user attribution embedded on rows of
// GET /v1/collections/public. Mirrors PublicUser but drops everything the
// discovery feed doesn't need (locale, privacy_mode, bio, ...).
type PublicCollectionOwner struct {
	ID              string  `json:"id"`
	Username        string  `json:"username"`
	DisplayUsername string  `json:"display_username"`
	DisplayName     string  `json:"display_name"`
	AvatarURL       *string `json:"avatar_url"`
}

// CollectionWithOwner is the row shape of GET /v1/collections/public. The
// Flutter model unpacks `owner` separately and reconstructs the inner
// Collection from the same JSON object — keep the field names aligned with
// `core/models/collection.dart::CollectionWithOwner.fromJson`.
type CollectionWithOwner struct {
	Collection
	Owner PublicCollectionOwner `json:"owner"`
}

type CollectionEntry struct {
	Beverage BeverageRef `json:"beverage"`
	Note     *string     `json:"note,omitempty"`
	AddedAt  time.Time   `json:"added_at"`
}

type CollectionDetail struct {
	Collection
	Entries []CollectionEntry `json:"entries"`
}

type CreateCollectionRequest struct {
	Name string `json:"name"`
}

func (r *CreateCollectionRequest) Validate() error {
	r.Name = strings.TrimSpace(r.Name)
	if len([]rune(r.Name)) < 1 || len([]rune(r.Name)) > 50 {
		return wrapValidation("name must be 1-50 characters")
	}
	return nil
}

// UpdateCollectionRequest — PATCH /v1/collections/{id}.
//
// Both fields are optional in isolation; at least one must be present, and
// `name`, when present, must satisfy the 1-50-char rule. Phase 6a added
// `visibility` (public|private). Sending neither field is a 422 — it's
// almost always a client bug, not a no-op intent.
type UpdateCollectionRequest struct {
	Name       *string `json:"name,omitempty"`
	Visibility *string `json:"visibility,omitempty"`
}

func (r *UpdateCollectionRequest) Validate() error {
	if r.Name == nil && r.Visibility == nil {
		return wrapValidation("at least one of name or visibility must be provided")
	}
	if r.Name != nil {
		s := strings.TrimSpace(*r.Name)
		if len([]rune(s)) < 1 || len([]rune(s)) > 50 {
			return wrapValidation("name must be 1-50 characters")
		}
		*r.Name = s
	}
	if r.Visibility != nil {
		v := strings.ToLower(strings.TrimSpace(*r.Visibility))
		if v != "private" && v != "public" {
			return wrapValidation("visibility must be one of: private, public")
		}
		*r.Visibility = v
	}
	return nil
}

type AddCollectionEntryRequest struct {
	BeverageID string  `json:"beverage_id"`
	Note       *string `json:"note,omitempty"`
}

func (r *AddCollectionEntryRequest) Validate() error {
	if r.BeverageID == "" {
		return wrapValidation("beverage_id is required")
	}
	if r.Note != nil && len([]rune(*r.Note)) > 200 {
		return wrapValidation("note must be ≤ 200 characters")
	}
	return nil
}

type UpdateCollectionEntryRequest struct {
	Note *string `json:"note,omitempty"`
}

func (r *UpdateCollectionEntryRequest) Validate() error {
	if r.Note != nil && len([]rune(*r.Note)) > 200 {
		return wrapValidation("note must be ≤ 200 characters")
	}
	return nil
}
