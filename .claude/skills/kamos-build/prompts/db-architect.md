# Spawn prompt — db-architect (kamos-build phase 2)

```
subagent_type: db-architect
model: <recommended_model from db-schema SKILL.md>
prompt:
Read docs/history/<NN>_<feature>/00_brief.md, design/HANDOFF.md (new
section), and SPEC.md.

Use the db-schema skill. Write a new append-only migration to
migrations/NNN_<feature>.sql and extend docs/db/schema.md, indexes.md,
and query_patterns.md with the additions.

Encode every relevant catalog invariant as a CHECK constraint or trigger:
- [[invariant:rating-scale]] — NUMERIC(3,2) + 0.25-step CHECK
- [[invariant:soft-delete]] — deleted_at TIMESTAMPTZ where applicable
- [[invariant:username]] — length + character CHECK
- [[invariant:search-bigm]] — bigm GIN index for any new searchable column;
  search_text trigger if the column composes cross-field text

Migrations are append-only. Never edit a deployed migration; if backend
needs a schema change after this lands, add a new migration.

Communication: per [[protocol:BUILD-003]] on completion. TaskUpdate per
[[protocol:BUILD-013]].
```
