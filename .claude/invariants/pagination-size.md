---
id: invariant:pagination-size
spec: SPEC.md §5.2
severity_on_violation: MAJOR
layers: [api, flutter, openapi]
owners: [backend-engineer, flutter-engineer, qa-inspector]
---

# Pagination size

## Rule

- Feed page size = **20**.
- Other list endpoints default to **20** unless SPEC overrides.
- All list endpoints use cursor pagination; see [[invariant:cursor-pagination]] for the envelope contract.

Page size is server-decided; clients do not request a larger size. A client-supplied `limit` higher than the server cap is silently clamped (`min(reqLimit, cap)`), never rejected with 4xx.

## Check

```bash
# Server cap declared once
grep -rn "PageSize\|page_size\|FeedPageSize\|defaultPageSize" backend/internal/

# OpenAPI declares the cap
grep -nA 2 "limit:" backend/openapi.yaml | head -40
```

## Where each layer enforces it

- **Handler / service** — caps `limit` at 20 before passing to the repository.
- **OpenAPI** — `limit: { maximum: 20, default: 20 }` on every list operation.
- **Flutter** — repository does not pass a `limit`; the server's cap is the contract.

## Related

- [[invariant:cursor-pagination]] — wrapper shape that paginated responses use
