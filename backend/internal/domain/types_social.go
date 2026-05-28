package domain

// ---------------------------------------------------------------------------
// Social
// ---------------------------------------------------------------------------

type FollowResult struct {
	Status string `json:"status"` // 'accepted' | 'pending'
}
