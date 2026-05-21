// Package repository — admin moderation_log reads (Stage 7, item M-8.1).
//
// The write path is in admin.go::insertModerationLog, called from inside the
// approve/reject/moderate/suspend/role-change transactions. This file adds
// the read counterpart so the admin UI can render the audit trail without
// dropping into psql.
//
// Index reuse (migration 008):
//   - (target_type, target_id, created_at DESC)  → idx_moderation_log_target
//   - (moderator_id, created_at DESC)            → idx_moderation_log_moderator
//
// The query plans onto whichever index matches the supplied filter; when
// neither is present (admin browses the global audit feed) the ORDER BY +
// LIMIT still walks the index on created_at DESC implied by the partial
// indexes' leading sort.
package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kamos/api/internal/domain"
)

// ModerationLogRepo wraps moderation_log read SQL. Writes still live with
// the action that produced them (admin.go::insertModerationLog) — the
// audit row + the underlying state change always commit together.
type ModerationLogRepo struct{ db *pgxpool.Pool }

// ModerationLogFilter scopes the list by target / moderator. Empty strings
// disable that filter; the cursor (CursorTs, CursorID) carries the keyset.
type ModerationLogFilter struct {
	TargetType  string
	TargetID    string
	ModeratorID string
}

// ListModerationLog pages through moderation_log entries newest-first.
// Returns rows ordered by (created_at DESC, id DESC); caller emits the
// page+1 row as the next cursor via cursor.SliceAndCursor.
func (r *ModerationLogRepo) ListModerationLog(
	ctx context.Context,
	f ModerationLogFilter,
	cursorTs *time.Time,
	cursorID *string,
	limit int,
) ([]domain.ModerationLogEntry, error) {
	if limit <= 0 {
		limit = 20
	}
	const q = `
SELECT id, moderator_id, action::text, target_type::text, target_id,
       notes, metadata, created_at
FROM moderation_log
WHERE ($1::text = '' OR target_type::text = $1)
  AND ($2::text = '' OR target_id = $2::uuid)
  AND ($3::text = '' OR moderator_id = $3::uuid)
  AND ($4::timestamptz IS NULL OR (created_at, id) < ($4::timestamptz, $5::uuid))
ORDER BY created_at DESC, id DESC
LIMIT $6;`
	rows, err := r.db.Query(ctx, q,
		f.TargetType, f.TargetID, f.ModeratorID,
		cursorTs, cursorID, limit+1)
	if err != nil {
		return nil, fmt.Errorf("ModerationLogRepo.ListModerationLog: %w", err)
	}
	defer rows.Close()
	out := make([]domain.ModerationLogEntry, 0, limit+1)
	for rows.Next() {
		var e domain.ModerationLogEntry
		var meta []byte
		if err := rows.Scan(&e.ID, &e.ModeratorID, &e.Action, &e.TargetType,
			&e.TargetID, &e.Notes, &meta, &e.CreatedAt); err != nil {
			return nil, fmt.Errorf("ModerationLogRepo.ListModerationLog scan: %w", err)
		}
		if len(meta) > 0 {
			m, err := unmarshalJSONBToMap(meta)
			if err != nil {
				return nil, fmt.Errorf("ModerationLogRepo.ListModerationLog metadata: %w", err)
			}
			e.Metadata = m
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
