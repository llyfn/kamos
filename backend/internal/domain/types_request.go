package domain

// ---------------------------------------------------------------------------
// Beverage feedback (user-submitted requests)
// ---------------------------------------------------------------------------

// BeverageRequest is the public body for POST /v1/beverage-requests. The
// payload is intentionally free-form JSONB — Phase 5 admin moderation
// re-keys this into structured Beverage rows on approval.
type BeverageRequest struct {
	Payload map[string]any `json:"payload"`
}

func (r *BeverageRequest) Validate() error {
	if len(r.Payload) == 0 {
		return wrapValidation("payload is required")
	}
	return nil
}
