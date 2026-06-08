---
id: invariant:checkin-caps
spec: SPEC.md §4.1
severity_on_violation: MAJOR
layers: [schema, api, flutter, openapi]
owners: [backend-engineer, flutter-engineer, qa-inspector]
---

# Check-in caps

## Rule

- Review text ≤ 500 chars (UTF-8 characters, not bytes; see [[invariant:sanitize-text]]).
- Up to 1 photo per check-in on submission.

Existing multi-photo check-ins (from the pre-cap era) remain readable — the API still serves their full photo arrays. The cap applies on **submit**, not on **read**.

## Check

```bash
# Schema CHECK
grep -rn "review_text\|char_length\|review.*500" migrations/

# Domain validator
grep -rn "ReviewText\|500" backend/internal/domain/checkins*.go

# OpenAPI
grep -nA 3 "review_text:" backend/openapi.yaml

# Flutter form
grep -rn "maxLength: 500\|500" frontend/lib/features/checkin/

# Photo cap on submit
grep -rn "PhotoURLs\|photo_urls\|photos" backend/internal/handlers/checkins*.go backend/internal/domain/checkins*.go
```

## Where each layer enforces it

- **DB CHECK** — `char_length(review_text) <= 500` (backstop).
- **Domain validator** — `backend/internal/domain/checkins.go` enforces character length on submit.
- **Handler** — rejects > 1 photo on submit. Reads emit the stored array as-is.
- **OpenAPI** — declares `review_text: { maxLength: 500 }` and the photo array max on the create operation.
- **Flutter form** — `maxLength: 500`, photo picker capped at 1 on submit.

## Related

- [[invariant:sanitize-text]] — text passes through `domain.SanitizeText` before the length check
- [[invariant:rating-scale]] — rating sits alongside on the same submit payload
