---
id: protocol:review-fanout
version: 1
used_by: [code-review]
participants: [arch-reviewer, security-reviewer, perf-reviewer, style-reviewer]
---

# Review fan-out protocol

Cross-domain SendMessages exchanged inside `code-review`. The orchestrator does **not** intermediate live — reviewers cross-reference reviewer-to-reviewer; the orchestrator only consolidates at synthesis time.

## Contract

| ID | Sender → Receiver | Wire string (literal) | Payload | Trigger | Receiver action |
|---|---|---|---|---|---|
| REVIEW-001 | arch-reviewer → security-reviewer | `ARCH<finding-id> may have security impact at <file:line>` | finding id + location | Arch reviewer spots an issue with security implications (e.g. auth scattered, validation duplicated and inconsistent) | Security reviewer cross-references; if confirmed, adds reciprocal entry to its findings file |
| REVIEW-002 | arch-reviewer → perf-reviewer | `ARCH<finding-id> may have perf impact at <file:line>` | finding id + location | Arch reviewer spots an issue with perf implications (no service abstraction → no caching; eagerly loaded graphs) | Perf reviewer cross-references |
| REVIEW-003 | security-reviewer → arch-reviewer | `SEC<finding-id> has structural root cause at <file:line>` | finding id + location | Vulnerability is rooted in architecture (e.g. duplicated auth check, one variant missing) | Arch reviewer cross-references; root cause finding may merge |
| REVIEW-004 | security-reviewer → perf-reviewer | `SEC<finding-id> fix has perf cost — coordinate at <file:line>` | finding id + location | Security fix would add latency (per-request DB ownership check, etc.) | Perf reviewer suggests an efficient fix shape |
| REVIEW-005 | perf-reviewer → arch-reviewer | `PERF<finding-id> rooted in architecture at <file:line>` | finding id + location | Bottleneck rooted in missing abstraction (no batch repository method, N+1 at the service seam) | Arch reviewer cross-references |
| REVIEW-006 | perf-reviewer → security-reviewer | `PERF<finding-id> enables DoS / abuse at <file:line>` | finding id + location | Missing rate-limiting on a sensitive path (e.g. `/auth/login`) enabling credential stuffing or scraping | Security reviewer cross-references; treats as security-adjacent |
| REVIEW-007 | style-reviewer → arch-reviewer | `STYLE<finding-id> masks structural problem at <file:line>` | finding id + location | Style symptom (duplicated error handling because no central helper) | Arch reviewer evaluates structural root cause |
| REVIEW-008 | style-reviewer → security-reviewer | `STYLE<finding-id> could mask security gap at <file:line>` | finding id + location | Swallowed auth error / ignored validation on a sensitive endpoint | Security reviewer evaluates |
| REVIEW-009 | perf-reviewer → orchestrator | `PERF<finding-id> requires schema change — flag db-architect` | finding id, suggested change | Fix needs a new index / denormalization the perf reviewer should not implement | Orchestrator records for db-architect (no live spawn during code-review) |
| REVIEW-010 | any reviewer → orchestrator | `TaskUpdate <task-id> completed` | task id | Reviewer finishes its findings file | Orchestrator detects via TaskList; synthesis begins when all four are completed |

## Cross-domain matrix

A finding is **cross-domain** when two reviewers cite the same `file:line` (or same function/struct), or when a SendMessage above is acknowledged. The orchestrator's synthesis step dedups: it counts once under the higher-severity domain in the executive summary table and merges into one entry in the "Cross-Domain Findings" section.

| Originating domain | Cross-domain implications worth flagging |
|---|---|
| Architecture | Security (auth scattered), Perf (no caching seam) |
| Security | Architecture (root cause), Perf (fix cost) |
| Performance | Architecture (missing abstraction), Security (DoS / abuse) |
| Style | Architecture (no helper), Security (swallowed errors) |

## Severity normalization

| Domain | May issue | May NOT issue |
|---|---|---|
| Architecture | HIGH, MEDIUM, LOW | CRITICAL (reserved for security + rare system-unsafe arch) |
| Security | CRITICAL, HIGH, MEDIUM, LOW | — |
| Performance | HIGH, MEDIUM, LOW | CRITICAL |
| Style | MEDIUM, LOW | HIGH, CRITICAL |

If two reviewers disagree on severity for the same finding, the orchestrator uses the higher value and notes the discrepancy in the cross-domain section.

## What this protocol is not

- **Not a phase gating system.** Reviewers run concurrently; synthesis waits on all four `TaskUpdate completed`.
- **Not for runtime triage.** Severity caps above are reporting conventions; production triage uses on-call docs.
