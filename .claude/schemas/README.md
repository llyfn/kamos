# Agent output schemas

JSON Schemas for structured outputs that agents return inside Workflow scripts. The Workflow tool validates outputs against the schema at tool-call time and retries the agent on mismatch — so downstream code can rely on the shape.

## Files

| Schema | Producer | Consumer |
|---|---|---|
| [qa-finding.json](qa-finding.json) | qa-inspector | kamos-build workflow phase gating + MINOR sweep |
| [review-finding.json](review-finding.json) | arch / security / perf / style reviewers | code-review synthesis stage |
| [handoff-addendum.json](handoff-addendum.json) | designer (phase 1 of kamos-build) | db-architect + backend-engineer (phase 2 inputs) |
| [verify-report.json](verify-report.json) | test-runner | kamos-build phase 4 gating |

## How to use in a Workflow script

```js
import qaSchema from '../schemas/qa-finding.json' assert { type: 'json' }

const verdict = await agent(
  promptFor('qa-inspector.md'),
  { schema: qaSchema, agentType: 'qa-inspector' }
)
// verdict is validated; its .status, .findings, .invariants are typed.
```

The current `kamos-build/workflow.mjs` inlines these schemas. As the rollout proceeds, those inline copies will be replaced with `import ... assert { type: 'json' }` references to keep the schema authoritative here.

## Conventions

- Every schema has an `$id: "kamos://schemas/<name>.json"` so agents can reference it by URI in prompts.
- Finding IDs follow `<DOMAIN>-NNN` (e.g. `QA-014`, `SEC-007`) — required by the corresponding schema pattern.
- Invariant IDs follow `invariant:<kebab-name>` per `.claude/invariants/`.
- `additionalProperties: false` everywhere; new fields require a schema bump.
