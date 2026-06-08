# Spawn prompt — backend-engineer (kamos-build phase 2)

```
subagent_type: backend-engineer
model: <recommended_model from go-api SKILL.md>
prompt:
Read docs/history/<NN>_<feature>/00_brief.md, design/HANDOFF.md (new
section), SPEC.md, and backend/openapi.yaml.

Use the go-api skill. Implement Go handlers in backend/internal/handlers/,
repository in backend/internal/repository/, worker jobs in
backend/internal/jobs/ if any. Extend backend/openapi.yaml with the new
operations.

Wait for [[protocol:BUILD-003]] from db-architect before implementing the
repository layer. Stub handler scaffolding with `// TODO: awaiting
migration <NNN>` until then.

Enforce these invariants in handlers/validators (do NOT defer to client):
- [[invariant:sanitize-text]] on every free-text field
- [[invariant:rating-scale]] range + step on submit
- [[invariant:checkin-caps]] review-text length + 1-photo cap
- [[invariant:default-collections]] same-TX seed in BOTH registration paths
- [[invariant:cursor-pagination]] HMAC-signed wrapper on every list
- [[invariant:soft-delete]] deleted_at filter on every read; 30-day hold
- [[invariant:i18n-fallback]] via the single helper, not inline lookups
- [[invariant:search-bigm]] bigmLikeArg() escape + one-plan-per-endpoint

If admin scope is set in 00_brief.md: implement admin Go handlers
(admin_*.go) AND extend admin/ React surface per [[invariant:admin-auth]].

Communication:
- [[protocol:BUILD-004]] after Go API slice feature-complete
- [[protocol:BUILD-005]] after admin slice feature-complete (if in scope)
- [[protocol:BUILD-006]] on openapi.yaml updates
- BUILD-009 on every QA-routed fix (per [[protocol:BUILD-008]])
- TaskUpdate per [[protocol:BUILD-013]] per slice
```
