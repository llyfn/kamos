# Invariant catalog

Single source of truth for SPEC-derived rules that every layer must enforce. Skills, agents, and orchestrator prompts cite invariants **by ID** (e.g. `[[invariant:jwt-storage]]`) and never restate them.

`SPEC.md` is canonical for *what* the rule is. This catalog is canonical for *how to check it* and *where each layer enforces it*.

## Index

| ID | One-line rule | SPEC | Severity on violation |
|---|---|---|---|
| [invariant:admin-auth](admin-auth.md) | Admin: HttpOnly cookie + X-CSRF-Token double-submit; SameSite=Strict | §6.9, `ARCHITECTURE.md §5` | BLOCKER |
| [invariant:category-strings](category-strings.md) | Exact strings per locale, no abbreviation, no `Sake` alone in en | §2.1, §8 | BLOCKER |
| [invariant:checkin-caps](checkin-caps.md) | Review text ≤ 500 chars; ≤ 1 photo on submit | §4.1 | MAJOR |
| [invariant:cursor-pagination](cursor-pagination.md) | `next_cursor` + `has_more`, HMAC-signed, never offset | §5.2 | BLOCKER |
| [invariant:default-collections](default-collections.md) | Register creates Inventory + Wishlist in same TX, localized | §6.1 | BLOCKER |
| [invariant:i18n-fallback](i18n-fallback.md) | Missing `ko`/`ja` falls back to `en`, exactly one layer | §8 | MAJOR |
| [invariant:jwt-storage](jwt-storage.md) | `flutter_secure_storage` only; iOS Keychain `first_unlock_this_device` | §3.1, §6.9 | BLOCKER |
| [invariant:pagination-size](pagination-size.md) | Feed page size 20; lists use cursor not offset | §5.2 | MAJOR |
| [invariant:rating-scale](rating-scale.md) | 0.5–5.0 in 0.25 steps, `NUMERIC(3,2)`, optional | §4.2 | BLOCKER |
| [invariant:sanitize-text](sanitize-text.md) | All user text through `domain.SanitizeText`; rejects controls + bidi | §3.x, security policy | BLOCKER |
| [invariant:search-bigm](search-bigm.md) | `pg_bigm` substring engine; `bigmLikeArg` escape; one query per endpoint | §5.x | BLOCKER |
| [invariant:soft-delete](soft-delete.md) | `deleted_at TIMESTAMPTZ`; username held 30 days; auth cache rejects | §3.3, §4.4 | BLOCKER |
| [invariant:username](username.md) | 3–30 chars, alphanumeric + `_`, case-insensitive, stored lowercase | §3.2 | BLOCKER |

## File format

```yaml
---
id: invariant:<kebab-name>
spec: SPEC.md §X (+ §Y)
severity_on_violation: BLOCKER | MAJOR | MINOR
layers: [schema, api, admin, flutter, ...]
owners: [agent-name, ...]   # agents responsible for upholding it
---

# <Title>

## Rule
<one paragraph stating the rule exactly>

## Check
<grep / regex / file pointer that flags violations — copy-pasteable>

## Where each layer enforces it
<bullet per layer, with file pointer>

## Related
- [[invariant:<other>]] <one-line tie>
```

## How to cite

Skills, agent files, orchestrator prompts: write `[[invariant:jwt-storage]]` inline, do not restate the rule. The validation script (`scripts/validate-harness.sh`) fails the build if a cited ID does not exist here.

## Adding a new invariant

1. Create `.claude/invariants/<id>.md` in the format above.
2. Add a row to the table in this README.
3. Update any skill/agent that already encodes the rule to cite the new ID instead.
4. Run `.claude/scripts/validate-harness.sh`.
