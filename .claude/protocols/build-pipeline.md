---
id: protocol:build-pipeline
version: 1
used_by: [kamos-build]
participants: [designer, db-architect, backend-engineer, flutter-engineer, qa-inspector]
---

# Build pipeline protocol

Every SendMessage inside `kamos-build`. The orchestrator interpolates `<feature>`, `<module>`, `<finding-id>` from the brief and the running state. Wire strings are literal.

## Contract

| ID | Sender → Receiver | Wire string (literal) | Payload | Trigger | Receiver action |
|---|---|---|---|---|---|
| BUILD-001 | designer → db-architect | `Design ready for <feature>` | none | Phase 1 designer complete | Begin schema work using `design/HANDOFF.md` addendum |
| BUILD-002 | designer → backend-engineer | `Design ready for <feature>` | none | Phase 1 designer complete | Begin handler scaffolding in parallel with db-architect; stub repo calls |
| BUILD-003 | db-architect → backend-engineer | `DB ready for <feature> — migration NNN, query patterns at docs/db/query_patterns.md` | `NNN` migration id | First migration set + `query_patterns.md` complete | Implement repository layer using `query_patterns.md` SQL directly |
| BUILD-004 | backend-engineer → qa-inspector | `Backend module <feature> complete` | list of changed paths | Go API slice feature-complete | Run `mode=incremental-be` cross-check; write `qa_report_backend.md` |
| BUILD-005 | backend-engineer → qa-inspector | `Admin module <feature> complete` | list of changed paths | Admin slice feature-complete (when in scope) | Run `mode=incremental-admin` cross-check; write `qa_report_admin.md` |
| BUILD-006 | backend-engineer → flutter-engineer | `OpenAPI ready for <feature> at backend/openapi.yaml` | none | `openapi.yaml` updates land | Replace Flutter stubs with real Dio calls + generated models |
| BUILD-007 | flutter-engineer → qa-inspector | `Flutter feature <feature> complete` | list of changed paths | Flutter slice feature-complete | Run `mode=incremental-fe` cross-check; write `qa_report_frontend.md` |
| BUILD-008 | qa-inspector → implementer | `BLOCKER/MAJOR <finding-id>: <file:line> — <fix>` | severity, finding id, file:line, exact fix | A BLOCKER or MAJOR is filed | Implementer owns the fix (per `feedback_implementer_owns_qa_fixes`); does not bounce to orchestrator |
| BUILD-009 | implementer → qa-inspector | `Fixed <finding-id>` | the changed file:line(s) | After applying the BUILD-008 fix | Re-read the cited file:line, re-run the relevant check, mark resolved only after re-verification |
| BUILD-010 | qa-inspector → orchestrator | `<slice> PASS / PASS WITH MINOR / FAIL` | report path | After each incremental report | Orchestrator gates the phase per the result |
| BUILD-011 | implementer → designer | `Open question on <feature>: <one-line>` | the ambiguous shape or screen | Implementer hits an unresolved design ambiguity | Designer resolves in `design/HANDOFF.md`; SendMessages BUILD-001/002 again |
| BUILD-012 | qa-inspector ↔ both implementers | `BLOCKER/MAJOR <finding-id>: contract mismatch <file:line> ↔ <file:line>` | both file:lines, the spec gap | Two layers disagree and SPEC is silent | Both implementers receive; orchestrator chooses the side if not resolved in 2 rounds |
| BUILD-013 | any agent → orchestrator | `TaskUpdate <task-id> <status>` | task id, status | After each meaningful state change | Orchestrator gates phase progression on TaskGet of every task in the phase |

## Severity → routing

| Severity | Routing | Wire IDs | Phase impact |
|---|---|---|---|
| BLOCKER | implementer owns fix; QA re-verifies before resolved | BUILD-008 → BUILD-009 | Halts dependent task; 2 unresolved rounds → halt phase, escalate to user |
| MAJOR | implementer owns fix; QA re-verifies | BUILD-008 → BUILD-009 | Does not halt; resolves before phase end |
| MINOR | filed in report; not routed live | (none) | Swept at end of phase per backlog policy |

## Ordering

```
designer ──BUILD-001──► db-architect
       └──BUILD-002──► backend-engineer
                              │
db-architect ──BUILD-003──► backend-engineer
                              │
                              ├──BUILD-004──► qa-inspector  (Go API slice)
                              ├──BUILD-005──► qa-inspector  (admin slice, if scoped)
                              └──BUILD-006──► flutter-engineer
                                                    │
                                                    └──BUILD-007──► qa-inspector  (Flutter slice)

qa-inspector ──BUILD-008──► <impl>  ◄──BUILD-009── <impl>   (fix round-trip)
qa-inspector ──BUILD-010──► orchestrator                     (slice verdict)

(any) ──BUILD-013──► TaskUpdate                              (continuous)
```

## What this protocol is not

- **Not a state machine for phase gating.** Phase gating is decided by `TaskGet` over all tasks (per `kamos-build` SKILL.md).
- **Not the only wire shape.** Ad-hoc messages outside the contract are permitted; if a pattern recurs, codify it here.
