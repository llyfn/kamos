---
name: perf-review
description: "Performance review skill for KAMOS. Identifies N+1 queries, missing indexes, over-fetching, unbounded queries, blocking I/O, Flutter rebuild storms, and algorithmic inefficiencies. Use when reviewing for scalability, latency, or efficiency. Triggers: performance review, scalability, N+1, indexing, latency, optimization."
---

# Performance Review Skill

Identifies bottlenecks that are correct now but won't scale. Look for patterns that pass code review but fail under load.

## Method

1. Find every list-returning function (Go repository, Dart repository).
2. Trace its callers. Any caller in a loop is an N+1 candidate.
3. Cross-reference every query in `query_patterns.md` against the indexes in `indexes.md`.
4. For Flutter: open every screen with `ref.watch(...)` calls — what state does it subscribe to, how broad is the rebuild?

## High-value greps

```bash
# N+1 candidates: DB calls inside loops (Go)
grep -rn "\.QueryRow\|\.Query\|\.Exec" backend/internal/ | grep -v "_test.go"
# Then visually scan for these inside `for _, x := range ...` blocks

# Unbounded list queries
grep -rn "SELECT .* FROM" backend/ | grep -iv "LIMIT\|COUNT(\|EXISTS("

# Offset pagination (anti-pattern; SPEC mandates cursor)
grep -rn "OFFSET\s\+\$" backend/

# Flutter: heavy operations in build()
grep -rn "\.map(\|\.where(\|\.sort\|\.fold(" frontend/lib/ | grep -v "provider\|repository\|notifier\|controller"

# Flutter: non-lazy ListView
grep -rn "ListView(" frontend/lib/ | grep -v "ListView\.builder\|ListView\.separated"

# Missing image cache
grep -rn "Image\.network(" frontend/lib/

# Synchronous file/HTTP in handlers (Go)
grep -rn "http\.Get\|os\.ReadFile\|ioutil\.ReadFile" backend/internal/handlers/
```

## N+1 detection — common Go pattern

```go
// BAD — N+1
checkins, _ := repo.ListCheckinsByUser(ctx, userID)
for _, ci := range checkins {
    ci.Beverage, _ = repo.GetBeverage(ctx, ci.BeverageID)  // one query per check-in
}

// GOOD — JOIN at the SQL layer
checkins, _ := repo.ListCheckinsWithBeverages(ctx, userID)

// ALSO GOOD — batch fetch
checkins, _ := repo.ListCheckinsByUser(ctx, userID)
ids := make([]string, len(checkins))
for i, ci := range checkins { ids[i] = ci.BeverageID }
beverages, _ := repo.GetBeveragesByIDs(ctx, ids)  // single IN query
```

The KAMOS feed query (`SPEC §5.2`) is the highest-risk N+1 — it joins users, beverages, producers, and toasts. Verify the SQL in `query_patterns.md` does the joins server-side, not in Go.

## Index coverage

For each query in `query_patterns.md`:

1. Extract `WHERE` columns and `ORDER BY` columns
2. Check `migrations/` for a covering index (leading column matches the leftmost `WHERE`)
3. Flag if missing — this is a HIGH at any non-trivial data volume

KAMOS-critical indexes:

- `check_ins (user_id, created_at DESC) WHERE deleted_at IS NULL` — feed
- `follows (follower_id) WHERE status = 'accepted'` — feed join
- `beverages USING GIN (name_i18n)` — search
- `users (LOWER(username))` and `users (LOWER(email))` — auth lookups

## Flutter rebuild scope audit

For each `ref.watch(provider)`:

- What does the provider expose? If it's a large object and the widget uses one field, narrow with `.select((s) => s.fieldName)`.
- Is the widget inside a `ListView.builder` (rebuilt per scroll)? The watched provider must be as narrow as possible.
- Heavy work in `build()` — sorting, filtering, formatting — should be in the provider or a memoized helper.

## Pagination checklist

- [ ] All list endpoints have a hard `LIMIT` (≤ 50, KAMOS feed is 20 per `SPEC §5.2`)
- [ ] Cursor pagination, not offset (offset degrades at large offsets and conflicts with SPEC)
- [ ] Cursor encodes `(created_at, id)` — tuple pagination handles non-unique timestamps
- [ ] Flutter scroll uses `ListView.builder` not pre-loaded `ListView(children: ...)`
- [ ] `next_cursor` is opaque (base64-JSON) — clients do not parse it

## KAMOS-specific hotspots

- **Feed query** — must be cursor-paginated and indexed; verify the SQL and the Flutter infinite-scroll wiring
- **Beverage search** — full-text on `name_i18n` JSONB needs a GIN index; without it, search is O(n) on the table
- **Check-in detail** — flavor tags + photos shouldn't be 2 separate queries; use a single `JOIN` or `SELECT IN`
- **Profile screen** — follower / following counts shouldn't be `COUNT(*)` on every load. Either denormalize (counter columns updated by trigger or app code) or cache.
- **Image upload** — must be direct-to-storage (S3 / GCS pre-signed URL) from Flutter, not proxied through Go (would block the API goroutine on upload bytes)
- **Toast count on feed cards** — every feed item shows a toast count. The feed SQL must include it via a `LATERAL` subquery or a denormalized column, not a separate request per card

## Severity guide

| Severity | Meaning |
|---|---|
| HIGH | P95 > 2s or risk of OOM at 10k users |
| MEDIUM | Noticeable at 1k users; acceptable for MVP but should be fixed before growth |
| LOW | Micro-optimization; address only after profiling confirms |

## Output format

Write to `docs/history/review/perf_findings.md` with `[PERF-NNN]` numbering. Always include "scale impact" — the data volume at which this becomes a problem.

```markdown
## [PERF-NNN] Short title
- Severity: HIGH | MEDIUM | LOW
- Pattern: N+1 | Missing Index | Over-fetch | Algorithmic | Flutter Rebuild | Unbounded Query | Blocking I/O | Other
- Location: file:line
- Finding: the bottleneck
- Scale impact: at what data volume does this become a problem?
- Fix: specific change (SQL snippet, code snippet, or widget pattern)
```

## Cross-domain SendMessage

- If the bottleneck is rooted in architecture (e.g., no caching layer because no service abstraction) → SendMessage `arch-reviewer`
- If a perf fix requires a schema change → flag to the orchestrator for `db-architect`
- If a perf gap also enables a security issue (e.g., no rate limit on `/auth/login` enables credential stuffing) → SendMessage `security-reviewer`

## Uncertainty

If a finding requires profiling data to confirm severity, mark it as "Suspected — needs profiling under load" rather than omit.
