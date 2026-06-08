# Spawn prompt — test-runner (kamos-build phase 4 chain)

```
subagent_type: test-runner
model: <recommended_model from verify-gates SKILL.md>
args:
  context: kamos-build
  base: HEAD~<N>  # or the merge-base with main
  feature: <feature>
prompt:
Use the verify-gates skill. Detect changed paths via
`git diff --name-only {base}...HEAD` and run only the required gates
from the matrix unless the orchestrator passes --all.

Write docs/history/<NN>_<feature>/verify_report.md.

Communication:
- PASS: SendMessage orchestrator with the verdict; TaskUpdate per
  [[protocol:BUILD-013]]
- FAIL: SendMessage the owning implementer per the verify-gates routing
  table with the gate name, exit code, and last 50 stderr lines, BLOCKER
  severity, using [[protocol:BUILD-008]] payload shape

Do NOT fix code yourself.
```
