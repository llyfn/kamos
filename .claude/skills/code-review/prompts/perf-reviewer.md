# Spawn prompt — perf-reviewer (code-review)

```
subagent_type: perf-reviewer
model: <recommended_model from perf-review SKILL.md>
prompt:
Read docs/history/review/00_scope.md. Use the perf-review skill.

Write findings to docs/history/review/perf_findings.md per the skill's
output format. PERF-NNN numbering. Each finding includes a "scale impact"
note (data volume at which it becomes a problem). Severity in {HIGH,
MEDIUM, LOW} — never CRITICAL.

Catalog invariants to verify (cite IDs in findings; do not restate):
- [[invariant:cursor-pagination]] — list endpoints HMAC-cursor, not offset
- [[invariant:search-bigm]] — covering bigm GIN index per searchable column;
  one query plan per search endpoint; bigmLikeArg escape

Begin with the index coverage cross-check (docs/db/query_patterns.md +
docs/db/indexes.md; fall back to migrations/ if stale). Then run the
high-value greps from the skill.

Cross-domain SendMessages per [[protocol:review-fanout]]:
- [[protocol:REVIEW-005]] if a bottleneck is rooted in architecture
- [[protocol:REVIEW-006]] if missing rate-limiting / DoS-adjacent
- [[protocol:REVIEW-009]] if fix needs a schema change (flag db-architect,
  do NOT modify migrations directly)
- Receive [[protocol:REVIEW-002]] / [[protocol:REVIEW-004]] from other
  reviewers; cross-reference

TaskUpdate per [[protocol:REVIEW-010]] on completion.
```
