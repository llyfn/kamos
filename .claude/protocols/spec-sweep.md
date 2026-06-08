---
id: protocol:spec-sweep
version: 1
used_by: [spec-sweep]
participants: [designer, db-architect, backend-engineer, flutter-engineer, qa-inspector, doc-keeper]
---

# SPEC sweep protocol

For a SPEC invariant change that ripples across every layer (e.g. "rating step changed from 0.5 → 0.25"). The shape is **fan-out by layer**, not pipeline by phase. The orchestrator spawns every implementer at once; QA verifies each layer as it returns.

## Contract

| ID | Sender → Receiver | Wire string (literal) | Payload | Trigger |
|---|---|---|---|---|
| SWEEP-001 | orchestrator → all implementers | `SPEC sweep <invariant-id> — apply <delta>` | invariant id, one-line delta, link to updated `SPEC.md §` | A SPEC.md edit has landed that changes a catalog invariant |
| SWEEP-002 | implementer → qa-inspector | `Layer <layer> updated for <invariant-id>` | list of changed paths | The implementer has finished applying the delta to their layer |
| SWEEP-003 | qa-inspector → implementer | `BLOCKER/MAJOR <finding-id>: <file:line> — <fix>` | as in [[protocol:BUILD-008]] | QA found a gap in the layer's application of the delta |
| SWEEP-004 | implementer → qa-inspector | `Fixed <finding-id>` | as in [[protocol:BUILD-009]] | Implementer applied the fix |
| SWEEP-005 | qa-inspector → orchestrator | `Layer <layer> for <invariant-id>: PASS / PASS WITH MINOR / FAIL` | report path | After re-verification |
| SWEEP-006 | doc-keeper → orchestrator | `Docs updated for <invariant-id>` | list of changed paths (CLAUDE.md, SPEC.md, README, runbooks) | doc-keeper has synced the prose docs |
| SWEEP-007 | orchestrator → user | `SPEC sweep <invariant-id> complete: <N layers PASS> <M MINOR> <K FAIL>` | report path tree | All `SWEEP-005` returns received |

## Ordering

```
orchestrator ──SWEEP-001──► designer, db-architect, backend-engineer, flutter-engineer (all in parallel)
                                                │
            ┌───────────────────────────────────┘ (each implementer in parallel)
            │
        impl ──SWEEP-002──► qa-inspector
            ◄──SWEEP-003── qa-inspector  (if BLOCKER/MAJOR)
        impl ──SWEEP-004──► qa-inspector
            ◄ ... ► (round-trip until resolved)
        qa-inspector ──SWEEP-005──► orchestrator (per-layer verdict)

doc-keeper ──SWEEP-006──► orchestrator   (parallel to layer work)
orchestrator ──SWEEP-007──► user          (final)
```

## Compared to build-pipeline

| | build-pipeline | spec-sweep |
|---|---|---|
| Shape | linear pipeline through layers | parallel fan-out across layers |
| Driven by | new feature scope | SPEC catalog invariant change |
| Phase gating | yes (designer first, then schema+API, then Flutter) | no (every layer runs at once) |
| QA modes | incremental-be/admin/fe/final | one mode per layer, scoped to the invariant |
| Doc sync | end-of-phase MINOR sweep | doc-keeper runs concurrent with implementers |
