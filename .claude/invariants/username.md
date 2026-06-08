---
id: invariant:username
spec: SPEC.md §3.2
severity_on_violation: BLOCKER
layers: [schema, api, flutter]
owners: [backend-engineer, db-architect, flutter-engineer, qa-inspector]
---

# Username rules

## Rule

- 3–30 characters.
- Alphanumeric + `_`. No spaces, no punctuation, no Unicode letters.
- Case-insensitive uniqueness. Stored lowercase. **Displayed as entered** at registration.
- Held for 30 days after account soft-delete before another user may claim it (see [[invariant:soft-delete]]).

Comparison, lookup, and uniqueness use the lowercase form. Display uses the stored `username_display`.

## Check

```bash
# Schema constraints
grep -rn "username\|username_display\|username_release" migrations/

# Constrained validator (not SanitizeText)
grep -rn "ValidateUsername\|username.*regex\|username.*length" backend/internal/domain/

# Lowercase on lookup
grep -rn "ToLower.*username\|lower(username)" backend/internal/repository/

# Flutter validator mirrors server
grep -rn "username" frontend/lib/features/auth/ frontend/l10n/intl_en.arb
```

## Where each layer enforces it

- **Schema** — `username TEXT NOT NULL` with CHECK on length + regex; `username_display TEXT NOT NULL` for case-preserved render; unique index on `lower(username)` (or stored-lowercase column).
- **Domain validator** — `backend/internal/domain/users.go` validates length + character set before registration.
- **Repository** — every lookup uses the lowercase column.
- **Flutter form** — client-side validator mirrors server rules; server is the backstop.
- **Username release** — see [[invariant:soft-delete]].

## Related

- [[invariant:soft-delete]] — 30-day hold is part of the username release contract
- [[invariant:sanitize-text]] — username uses its own validator, not SanitizeText
