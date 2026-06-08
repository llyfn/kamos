---
id: invariant:sanitize-text
spec: KAMOS security policy (per CLAUDE.md "Project invariants")
severity_on_violation: BLOCKER
layers: [api]
owners: [backend-engineer, security-reviewer, qa-inspector]
---

# Text input sanitization

## Rule

Every user-provided string field flows through `domain.SanitizeText(field, value, allowEmpty, maxLen)`. The helper:

1. Rejects control characters.
2. Rejects bidi-override codepoints (U+202A–U+202E, U+2066–U+2069).
3. Enforces UTF-8 length (not byte length).
4. Returns a typed validation error consumed by `httperr`.

No handler may bypass this helper for free-text fields (review_text, display_name, comment_body, collection name, etc.). Enum/ID fields that are not free-text validate via their own constrained validators.

## Check

```bash
# Every free-text request field decode is followed by SanitizeText
grep -rn "SanitizeText" backend/internal/domain/ backend/internal/handlers/

# No raw string passthrough in handlers that take user text
grep -rnE 'req\.(ReviewText|DisplayName|Body|Name)' backend/internal/handlers/ \
  | grep -v "SanitizeText"
```

## Where each layer enforces it

- **Helper** — `backend/internal/domain/validate.go` (or `validate/`). Authoritative one-implementation place.
- **Handlers / validators** — request-shape `Validate()` methods call `SanitizeText` for every free-text field before the service layer sees it.
- **DB** — CHECK constraints exist for length caps as a backstop only; they are not the primary defense.

## Related

- [[invariant:checkin-caps]] — review_text length cap layered on top of sanitization
- [[invariant:username]] — username has its own constrained validator (not SanitizeText)
