# Protocol contracts

Single source of truth for inter-agent SendMessage strings. Skills, agent files, and orchestrator prompts cite protocol IDs (e.g. `[[protocol:BUILD-004]]`) and never restate the wire string. The validation script fails if a hardcoded string drifts from the contract.

## Files

| File | Used by | Coverage |
|---|---|---|
| [build-pipeline.md](build-pipeline.md) | `kamos-build` skill | vertical-slice feature builds: designer → db-architect → backend-engineer → flutter-engineer ↔ qa-inspector |
| [review-fanout.md](review-fanout.md) | `code-review` skill | arch/security/perf/style reviewer cross-talk |
| [spec-sweep.md](spec-sweep.md) | `spec-sweep` skill | cross-layer SPEC-change propagation |

## How to cite

In any skill, agent file, or orchestrator prompt:

> SendMessage `qa-inspector` per [[protocol:BUILD-004]] when the backend slice is complete.

The validation script extracts every `[[protocol:<ID>]]` reference and asserts the ID exists in the contract; conversely, any literal SendMessage payload string that does **not** match a protocol entry is flagged.

## Adding or changing a protocol

1. Open the relevant contract file and add (or edit) the row.
2. Bump the file's `version:` in frontmatter.
3. Update any citing skill/agent to use the new ID (or the same ID's new payload).
4. Run `.claude/scripts/validate-harness.sh`.

## Payload conventions

- `<feature>` and `<module>` are interpolated by the orchestrator from the brief.
- `<finding-id>` is the QA or reviewer's own ID (e.g. `QA-014`, `SEC-007`).
- Every SendMessage payload that references files must include `file:line`.
- Wire strings use straight ASCII; the orchestrator interpolates literally.
