# Spawn prompt — qa-inspector (kamos-build, every phase)

The qa-inspector slot in every `kamos-build` team is spawned with the same
template; only the `mode` arg differs.

```
subagent_type: qa-inspector
model: <recommended_model for the mode, from qa-inspect SKILL.md frontmatter>
args:
  mode: incremental-be | incremental-admin | incremental-fe | final
  feature: <feature>
  brief_path: docs/history/<NN>_<feature>/00_brief.md
prompt:
Use the qa-inspect skill in mode={mode} for {feature}.

Wait for the corresponding "slice complete" SendMessage:
- incremental-be    → [[protocol:BUILD-004]] from backend-engineer
- incremental-admin → [[protocol:BUILD-005]] from backend-engineer
- incremental-fe    → [[protocol:BUILD-007]] from flutter-engineer
- final             → spawned directly by orchestrator after Phase 3 ends

Cross-check the named slice against:
- backend/openapi.yaml ↔ Flutter repositories (incremental-fe / final)
- migrations/ schema ↔ Go struct json tags (incremental-be / final)
- design/HANDOFF.md ↔ Go handler response shapes (incremental-be / final)
- admin/ React calls ↔ admin Go handlers per [[invariant:admin-auth]]
  (incremental-admin)
- ARB key parity across en/ja/ko (incremental-fe / final)
- go_router paths ↔ real screen files (incremental-fe / final)

Then run the catalog invariant grep checks relevant to {mode}:
- [[invariant:jwt-storage]]       (all modes)
- [[invariant:cursor-pagination]] (be / fe / final)
- [[invariant:category-strings]]  (fe / final)
- [[invariant:rating-scale]]      (be / fe / final)
- [[invariant:soft-delete]]       (be / final)
- [[invariant:default-collections]] (be / final)
- [[invariant:i18n-fallback]]     (be / fe / final)
- [[invariant:checkin-caps]]      (be / fe / final)
- [[invariant:sanitize-text]]     (be / admin / final)
- [[invariant:search-bigm]]       (be / final)
- [[invariant:admin-auth]]        (admin / final)
- [[invariant:username]]          (be / fe / final)
- [[invariant:pagination-size]]   (be / fe / final)

Write docs/history/<NN>_<feature>/qa/qa_report_{mode-short}.md per the
qa-inspect skill output format. PASS / PASS WITH MINOR / FAIL summary at
top.

Communication:
- [[protocol:BUILD-008]] for BLOCKER/MAJOR — route to the responsible
  implementer with file:line + exact fix (implementer owns the fix)
- [[protocol:BUILD-010]] back to the orchestrator with the verdict
- MINOR → file in the report, append to docs/history/backlog.md for the
  end-of-phase sweep, do NOT route live
- TaskUpdate per [[protocol:BUILD-013]] per slice

Re-verification: when an implementer sends BUILD-009, re-read the cited
file:line, re-run the relevant invariant check, mark resolved only after
re-verify passes.
```
