---
id: invariant:soft-delete
spec: SPEC.md §3.3, §4.4
severity_on_violation: BLOCKER
layers: [schema, api]
owners: [db-architect, backend-engineer, qa-inspector]
---

# Soft-delete + 30-day username hold

## Rule

Soft-deletable rows carry `deleted_at TIMESTAMPTZ`. Every read query filters `WHERE deleted_at IS NULL` unless explicitly restoring or auditing.

- `users` — soft-delete sets `deleted_at` + `username_release_at = now() + interval '30 days'`. The username is held for the 30-day window before another user can claim it.
- `check_ins` — soft-deletable.
- `collections` — soft-deletable.
- `comments` — `user_id` is `ON DELETE SET NULL` (Stage 7) so author-soft-delete does not orphan the row.

SEC-006: soft-deleted user IDs are cached in-process in `backend/internal/auth/` so JWT verification rejects them immediately for the 30-day window, without a per-request DB roundtrip.

## Check

```bash
# Tables with deleted_at
grep -rn "deleted_at TIMESTAMPTZ" migrations/

# Read queries must filter
grep -rn "FROM users\|FROM check_ins\|FROM collections" backend/internal/repository/ \
  | grep -v "deleted_at IS NULL\|deleted_at IS NOT NULL\|INSERT\|UPDATE"

# Username release
grep -rn "username_release_at\|username_hold" backend/ migrations/

# Auth cache
grep -rn "SoftDeleted\|soft_delete" backend/internal/auth/
```

## Where each layer enforces it

- **Schema** — `deleted_at TIMESTAMPTZ` on `users`, `check_ins`, `collections`; `username_release_at` on `users`.
- **Repository** — every list/read query filters `deleted_at IS NULL`.
- **Auth (SEC-006)** — `backend/internal/auth/` LRU of soft-deleted user IDs; JWT verify rejects without DB roundtrip during the hold window.
- **Worker** — `username_hold` job releases the username after 30 days. See `backend/internal/jobs/`.

## Related

- [[invariant:jwt-storage]] — soft-delete cache participates in JWT verify path
- [[invariant:username]] — release is the back-half of the username uniqueness rule
