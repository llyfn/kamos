# Spawn prompt — style-reviewer (code-review)

```
subagent_type: style-reviewer
model: <recommended_model from style-review SKILL.md>
prompt:
Read docs/history/review/00_scope.md. Use the style-review skill.

Write findings to docs/history/review/style_findings.md per the skill's
output format. STYLE-NNN numbering, severity in {MEDIUM, LOW} only —
never HIGH or CRITICAL (per the review-fanout protocol's severity
normalization).

Report patterns once with a representative example + a list of affected
locations. Do not file one entry per occurrence when N > 3.

Honor the KAMOS comments policy (CLAUDE.md "Code comments — strict
policy") when judging comment-related findings:
- Flag history/changelog comments, task-tracking comments, restated
  identifiers
- Do NOT flag absence of comments — that is the default

Cross-domain SendMessages per [[protocol:review-fanout]]:
- [[protocol:REVIEW-007]] if a style pattern masks a structural problem
- [[protocol:REVIEW-008]] if an error-handling gap could mask a security
  issue
- Receive (no inbound; style does not receive routed findings)

TaskUpdate per [[protocol:REVIEW-010]] on completion.
```
