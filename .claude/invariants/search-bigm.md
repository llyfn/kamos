---
id: invariant:search-bigm
spec: KAMOS search policy (per CLAUDE.md "Search invariants")
severity_on_violation: BLOCKER
layers: [schema, api]
owners: [db-architect, backend-engineer, qa-inspector, perf-reviewer]
---

# Search uses pg_bigm with one query plan per endpoint

## Rule

1. **Every searchable column has a covering bigm GIN index.** No `LIKE '%foo%'` or `ILIKE` against a column without `gin_bigm_ops`. The four baseline indexes shipped in migration 003 are: `idx_beverages_search_bigm`, `idx_producers_search_bigm`, `idx_users_username_bigm`, `idx_users_display_name_bigm` (functional, on `lower(display_name)`).
2. **Cross-field / i18n search uses a materialized `search_text TEXT` column** maintained by triggers. Compose on write, never on read. Triggers cover every parent edit that affects composition.
3. **pg_bigm is the substring engine.** Do not introduce `pg_trgm`, `to_tsvector`, or `websearch_to_tsquery` for new search paths. Bigm subsumes them for CJK-first content.
4. **LIKE metacharacter escape is mandatory.** All user-supplied query strings flowing into a `LIKE` clause pass through `repository.bigmLikeArg(q)` (lowercase + escape `\`, `%`, `_`). Skipping is a SECURITY-adjacent correctness bug.
5. **One query plan per search endpoint.** No FTS-then-trigram fallback, no `UNION ALL` of competing shapes.
6. **User-search ranking is 3-tier SQL**, not Go: exact → prefix → substring, then `char_length(username) ASC, created_at DESC, id DESC`. Cursor packs `(match_tier, name_length, created_at, id)`. Min-2-char rule + case-insensitivity + `deleted_at IS NULL` filter preserved.

## Check

```bash
# Forbidden: pg_trgm / FTS in new search paths
grep -rn "pg_trgm\|to_tsvector\|websearch_to_tsquery" migrations/ backend/internal/repository/

# bigmLikeArg used for every user query reaching LIKE
grep -rn "bigmLikeArg\|LIKE '%" backend/internal/repository/

# Bigm indexes exist
grep -rn "gin_bigm_ops" migrations/

# search_text trigger composition
grep -rn "kamos_compute_.*_search_text\|kamos_trg_.*_search_text" migrations/
```

## Where each layer enforces it

- **Image** — kamos-db forks `flyio/postgres-flex:18` and bakes `pg_bigm` (`db/Dockerfile`). Rebuild via `cd db/ && flyctl deploy -a kamos-db --remote-only`.
- **Schema** — bigm indexes alongside the search column; `search_text` triggers cascade from every parent edit.
- **Repository** — uses `bigmLikeArg(q)`; no inline lowercasing or escaping.
- **Cursor envelope** — search endpoints HMAC-sign the 4-tuple cursor; see [[invariant:cursor-pagination]].

## Related

- [[invariant:cursor-pagination]] — search cursors share the envelope contract
- [[invariant:soft-delete]] — search filters `deleted_at IS NULL`
