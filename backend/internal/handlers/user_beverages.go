package handlers

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/kamos/api/internal/cursor"
	"github.com/kamos/api/internal/domain"
	"github.com/kamos/api/internal/httperr"
	"github.com/kamos/api/internal/middleware"
	"github.com/kamos/api/internal/repository"
	"github.com/kamos/api/internal/spec"
)

// GetUserBeverages — GET /v1/users/{username}/beverages.
//
// Returns one row per distinct beverage the named user has checked in
// to (soft-deleted check-ins excluded), aggregating the user's own
// rating + count alongside the global aggregates already maintained
// on the beverage row.
//
// Filters (`category`, `producer_id`, `min_rating`) and sort
// (`rating | producer | category | last_checkin`, with optional
// `sort_dir`) are all validated server-side. Cursor pagination per
// SPEC §6.6 — page size 20 default, 50 max.
//
// Privacy: same gate as GET /v1/users/{username}. For private users,
// only the user themselves and accepted followers may list; everyone
// else gets 403 PRIVATE_PROFILE.
func (h *Handler) GetUserBeverages(w http.ResponseWriter, r *http.Request) {
	username := chi.URLParam(r, "username")
	target, err := h.Repos.Users.FindByUsername(r.Context(), username)
	if err != nil {
		h.writeErr(w, "GetUserBeverages find", err)
		return
	}
	if ok, err := h.privateProfileGate(r, target); err != nil {
		h.writeErr(w, "GetUserBeverages gate", err)
		return
	} else if !ok {
		httperr.WriteError(w, http.StatusForbidden, "PRIVATE_PROFILE",
			"this user's beverages are private")
		return
	}
	params, err := buildUserBeveragesParams(r, target.ID)
	if err != nil {
		h.writeErr(w, "GetUserBeverages params", err)
		return
	}
	rows, err := h.Repos.UserBeverages.ListUserBeverages(r.Context(), params)
	if err != nil {
		h.writeErr(w, "GetUserBeverages list", err)
		return
	}
	items, next, hasMore := cursor.SliceAndCursor(rows, params.Limit, func(row domain.UserBeverageRow) cursor.Cursor {
		return encodeUserBeverageCursor(params.Sort, row)
	})
	httperr.WriteJSON(w, http.StatusOK, cursor.Page[domain.UserBeverageRow]{
		Items: items, NextCursor: next, HasMore: hasMore,
	})
}

// privateProfileGate returns ok=true when the viewer may list the
// target user's beverages. For a public profile any viewer is fine;
// for a private profile only the user themselves or an accepted
// follower may list. Mirrors GetUser's gate so the two surfaces stay
// in lock-step.
func (h *Handler) privateProfileGate(r *http.Request, target *domain.User) (bool, error) {
	if target.PrivacyMode != "private" {
		return true, nil
	}
	viewer := middleware.UserFromContext(r.Context())
	if viewer == nil {
		return false, nil
	}
	if viewer.ID == target.ID {
		return true, nil
	}
	state, err := h.Repos.Social.FollowState(r.Context(), viewer.ID, target.ID)
	if err != nil {
		return false, err
	}
	return state == "accepted", nil
}

// buildUserBeveragesParams parses every query-string knob into the
// repository params struct, returning the typed validation error
// straight from the first parser to fail. Kept as a single helper so
// the handler body stays a thin orchestration layer.
func buildUserBeveragesParams(r *http.Request, userID string) (repository.UserBeveragesParams, error) {
	sort, sortDescDir, err := parseUserBeverageSort(r)
	if err != nil {
		return repository.UserBeveragesParams{}, err
	}
	categorySlug, err := parseCategorySlug(r)
	if err != nil {
		return repository.UserBeveragesParams{}, err
	}
	producerID, err := parseProducerID(r)
	if err != nil {
		return repository.UserBeveragesParams{}, err
	}
	minRating, err := parseMinRating(r)
	if err != nil {
		return repository.UserBeveragesParams{}, err
	}
	c, err := parseCursor(r)
	if err != nil {
		return repository.UserBeveragesParams{}, err
	}
	params := repository.UserBeveragesParams{
		UserID:       userID,
		CategorySlug: categorySlug,
		ProducerID:   producerID,
		MinRating:    minRating,
		Sort:         sort,
		SortDescDir:  sortDescDir,
		Limit:        parseLimit(r, spec.PageSizeDefault, spec.PageSizeMax),
	}
	applyUserBeverageCursor(&params, c)
	return params, nil
}

// applyUserBeverageCursor copies the cursor envelope's slots into the
// repository params per the active sort. The encoder only fills the
// slot relevant to the active sort; everything else stays nil so the
// SQL keyset short-circuits to "first page".
func applyUserBeverageCursor(params *repository.UserBeveragesParams, c cursor.Cursor) {
	if c.ID != "" {
		id := c.ID
		params.CursorID = &id
	}
	switch params.Sort {
	case repository.SortUserBeverageRating:
		if c.Score != nil {
			v := *c.Score
			params.CursorRatingScaled = &v
		}
	case repository.SortUserBeverageLastCheckin:
		if !c.CreatedAt.IsZero() {
			t := c.CreatedAt
			params.CursorTimestamp = &t
		}
	case repository.SortUserBeverageProducer, repository.SortUserBeverageCategory:
		if c.Type != "" {
			s := c.Type
			params.CursorStringSort = &s
		}
	}
}

// parseUserBeverageSort reads ?sort=&sort_dir= and validates both. The
// default sort is "rating" DESC. Each sort axis has its own default
// direction; an explicit `sort_dir` overrides.
func parseUserBeverageSort(r *http.Request) (repository.UserBeverageSort, bool, error) {
	raw := r.URL.Query().Get("sort")
	if raw == "" {
		raw = string(repository.SortUserBeverageRating)
	}
	var sort repository.UserBeverageSort
	var defaultDesc bool
	switch repository.UserBeverageSort(raw) {
	case repository.SortUserBeverageRating:
		sort = repository.SortUserBeverageRating
		defaultDesc = true
	case repository.SortUserBeverageProducer:
		sort = repository.SortUserBeverageProducer
		defaultDesc = false
	case repository.SortUserBeverageCategory:
		sort = repository.SortUserBeverageCategory
		defaultDesc = false
	case repository.SortUserBeverageLastCheckin:
		sort = repository.SortUserBeverageLastCheckin
		defaultDesc = true
	default:
		return "", false, validationErr("sort must be one of rating | producer | category | last_checkin")
	}
	desc := defaultDesc
	if d := r.URL.Query().Get("sort_dir"); d != "" {
		switch d {
		case "asc":
			desc = false
		case "desc":
			desc = true
		default:
			return "", false, validationErr("sort_dir must be 'asc' or 'desc'")
		}
	}
	return sort, desc, nil
}

func parseCategorySlug(r *http.Request) (*string, error) {
	v := r.URL.Query().Get("category")
	if v == "" {
		return nil, nil
	}
	switch v {
	case "nihonshu", "shochu", "liqueur":
		s := v
		return &s, nil
	}
	return nil, validationErr("category must be one of nihonshu | shochu | liqueur")
}

func parseProducerID(r *http.Request) (*string, error) {
	v := r.URL.Query().Get("producer_id")
	if v == "" {
		return nil, nil
	}
	// Cheap UUID shape check — full validation happens DB-side when
	// the cast to ::uuid fires. We only need to reject obvious garbage
	// so an invalid value doesn't surface as a 500.
	if len(v) != 36 {
		return nil, validationErr("producer_id must be a UUID")
	}
	return &v, nil
}

func parseMinRating(r *http.Request) (*float64, error) {
	v := r.URL.Query().Get("min_rating")
	if v == "" {
		return nil, nil
	}
	n, err := strconv.ParseFloat(v, 64)
	if err != nil {
		return nil, validationErr("min_rating must be a number")
	}
	if n < spec.RatingMin || n > spec.RatingMax {
		return nil, validationErr("min_rating must be between 0.5 and 5.0")
	}
	return &n, nil
}

// encodeUserBeverageCursor emits the next-page cursor for the
// requested sort. Only the slots relevant to the sort axis are
// populated; the others stay zero-valued and round-trip cleanly
// through the cursor envelope's omitempty JSON tags.
func encodeUserBeverageCursor(sort repository.UserBeverageSort, row domain.UserBeverageRow) cursor.Cursor {
	c := cursor.Cursor{ID: row.Beverage.ID}
	switch sort {
	case repository.SortUserBeverageRating:
		var s int64
		if row.UserAvgRating == nil {
			s = repository.UserBeverageRatingNullSentinel
		} else {
			s = int64(*row.UserAvgRating * float64(repository.UserBeverageRatingCursorScale))
		}
		c.Score = &s
	case repository.SortUserBeverageLastCheckin:
		c.CreatedAt = row.LastCheckinAt
	case repository.SortUserBeverageProducer:
		c.Type = row.Beverage.Producer.ID
	case repository.SortUserBeverageCategory:
		c.Type = row.Beverage.Category.Slug
	}
	return c
}

// validationErr wraps the validation sentinel so writeErr maps it to
// a 422 VALIDATION response with the supplied human message.
func validationErr(msg string) error {
	return fmt.Errorf("%w: %s", domain.ErrValidation, msg)
}
