---
id: invariant:cursor-pagination
spec: SPEC.md §5.2
severity_on_violation: BLOCKER
layers: [api, flutter, openapi]
owners: [backend-engineer, flutter-engineer, qa-inspector]
---

# Cursor pagination

## Rule

Every list endpoint paginates by HMAC-signed opaque cursor — never `offset` / `page`. Response shape is fixed:

```json
{ "items": [...], "next_cursor": "...", "has_more": false }
```

Cursors are signed with `CURSOR_SECRET` (≥ 32 bytes, validated at startup). Tampered cursors return `400 INVALID_CURSOR`. Feed page size is 20; other lists default to 20 unless SPEC overrides. See [[invariant:pagination-size]].

## Check

```bash
# Go handlers: every list endpoint emits next_cursor + has_more
grep -rn "next_cursor\|NextCursor" backend/internal/handlers/

# OpenAPI: schema declares the wrapper
grep -n "next_cursor\|has_more" backend/openapi.yaml

# Flutter repository layer never uses offset/page
grep -rn "offset\|'page'" frontend/lib/ | grep -i repository
# Any match → BLOCKER

# Flutter consumes nextCursor + hasMore
grep -rn "nextCursor\|next_cursor" frontend/lib/ | grep repository
```

## Where each layer enforces it

- **Cursor envelope** — `backend/internal/cursor/` HMAC-signs every cursor; verifies on decode.
- **Handlers** — every list handler in `backend/internal/handlers/` emits `next_cursor` + `has_more`.
- **OpenAPI** — `backend/openapi.yaml` declares the page wrapper as a reusable schema.
- **Flutter** — `Page<T>` model in `frontend/lib/shared/models/` matches the Go `pkg/cursor.Page[T]`; repositories pass `cursor` query param, never `offset`.
- **User search ranking** — `(match_tier, name_length, created_at, id)` packed into the same envelope; see [[invariant:search-bigm]].

## Related

- [[invariant:pagination-size]] — feed = 20
- [[invariant:search-bigm]] — user search cursor packs match-tier into the envelope
