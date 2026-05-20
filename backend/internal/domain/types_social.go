package domain

import "time"

// ---------------------------------------------------------------------------
// Social
// ---------------------------------------------------------------------------

type FollowRequest struct {
	UserID          string    `json:"user_id"`
	Username        string    `json:"username"`
	DisplayUsername string    `json:"display_username"`
	DisplayName     string    `json:"display_name"`
	AvatarURL       *string   `json:"avatar_url"`
	Bio             *string   `json:"bio"`
	CreatedAt       time.Time `json:"created_at"`
}

type FollowResult struct {
	Status string `json:"status"` // 'accepted' | 'pending'
}
