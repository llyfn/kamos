# Spawn prompt — arch-reviewer (code-review)

```
subagent_type: arch-reviewer
model: <recommended_model from arch-review SKILL.md>
prompt:
Read docs/history/review/00_scope.md. Use the arch-review skill.

Write findings to docs/history/review/arch_findings.md per the skill's
output format. ARCH-NNN numbering, severity in {HIGH, MEDIUM, LOW} —
never CRITICAL (per the review-fanout protocol's severity normalization).

Cross-domain SendMessages per [[protocol:review-fanout]]:
- [[protocol:REVIEW-001]] if a structural issue has security implications
- [[protocol:REVIEW-002]] if it has perf implications
- Receive [[protocol:REVIEW-003]] and [[protocol:REVIEW-005]] and
  [[protocol:REVIEW-007]] from other reviewers; cross-reference

TaskUpdate per [[protocol:REVIEW-010]] on completion.

Do not flag invariants enforced by the catalog as architectural drift;
they have their own QA path. Focus on structural questions (layer
separation, dependency direction, coupling, missing abstractions).
```
