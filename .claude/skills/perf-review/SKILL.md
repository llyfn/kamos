---
name: perf-review
description: "Performance bottleneck review skill. Identifies N+1 queries, missing indexes, over-fetching, unbounded queries, Flutter rebuild storms, and algorithmic inefficiencies. Use when reviewing code for scalability, latency issues, or efficiency problems."
---

# Performance Review Skill

Identifies bottlenecks that are correct now but will fail under load.

## High-Value Grep Patterns

```bash
# N+1 candidates: DB calls inside loops (Go)
grep -rn "\.Query\|\.QueryRow\|\.Exec" . | grep -v "_test.go" > /tmp/db_calls.txt
# then look for these call sites appearing inside for-range blocks

# Unbounded queries (no LIMIT)
grep -rn "SELECT.*FROM" . | grep -iv "LIMIT\|COUNT(\|EXISTS("

# Flutter: heavy work in build()
grep -rn "\.map(\|\.where(\|\.sort" lib/ | grep -v "provider\|repository\|notifier"

# Flutter: missing lazy list
grep -rn "ListView(" lib/ | grep -v "ListView\.builder\|ListView\.separated"

# Missing CachedNetworkImage
grep -rn "Image\.network(" lib/
```

## N+1 Detection Method

1. Find all list-returning repository functions
2. Trace the callers of each function
3. For each caller: is there a loop that calls another repository function per item?

**Common Go N+1 pattern:**
```go
// BAD: N+1
checkins, _ := repo.ListCheckins(ctx, userID)
for _, ci := range checkins {
    ci.Beverage, _ = repo.GetBeverage(ctx, ci.BeverageID) // query per checkin!
}

// GOOD: JOIN or batch fetch
checkins, _ := repo.ListCheckinsWithBeverages(ctx, userID)
// or:
bevIDs := extractBeverageIDs(checkins)
beverages, _ := repo.GetBeveragesByIDs(ctx, bevIDs) // single IN query
```

## Index Coverage Check

For each query pattern in `query_patterns.md`:
1. Extract the `WHERE` and `ORDER BY` columns
2. Check if a covering index exists in `migrations/`
3. Flag if the leading column of the WHERE is not indexed

## Flutter Rebuild Scope Audit

For each `ref.watch(someProvider)` call in a widget:
- What state does it subscribe to?
- If the provider holds a large object (e.g., full user profile), is only one field actually used? If so, add `.select((state) => state.fieldName)`
- Does the widget sit inside a `ListView.builder` (rebuilt per scroll)? If so, the watched provider should be as narrow as possible

## Pagination Checklist

- [ ] All list endpoints have a hard `LIMIT` (max 50–100)
- [ ] Pagination uses cursor (created_at + id), not offset (degrades at large offsets)
- [ ] Flutter: infinite scroll uses a `FlatList`/`ListView.builder` not a pre-loaded list
- [ ] `next_cursor` is opaque (base64 encoded) — clients should not parse it

## Severity Guide

| Severity | Meaning |
|----------|---------|
| HIGH | Will cause P95 latency > 2s or OOM at 10k users |
| MEDIUM | Noticeable at 1k users; acceptable for MVP but should be fixed before growth |
| LOW | Micro-optimization; address only after profiling confirms it |

## Output

Write to `_workspace/review/perf_findings.md` with `[PERF-NNN]` numbering. Include "scale impact" (at what data volume does this become a problem?) to help triage.
