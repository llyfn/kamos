---
name: verify-gates
description: "KAMOS verification gate skill. Runs the verification matrix from CLAUDE.md against the working tree: Go build/vet/test, integration tests, Flutter analyze/test, admin build/test, sqlfluff, token-drift check, and the local smoke test. Invoke whenever pre-merge gate, CI parity, smoke test, or full-tree verification is requested. Triggers: verify, gate, smoke, test matrix, build check, CI parity."
recommended_model: sonnet
---

# Verify Gates Skill

Runs every gate from the CLAUDE.md verification matrix and reports a single PASS / FAIL per gate plus the consolidated verdict. Used as a hard gate at end of `kamos-build` Phase 4, after `code-review` synthesis, and on direct invocation before pushing.

## When to use this skill

- End of `kamos-build` Phase 4 (chained after `qa-inspect` final mode)
- End of `code-review` synthesis (last sanity check before report finalize)
- Direct: "verify the working tree", "run the gates", "smoke check"
- Before pushing a branch when the human wants CI parity locally

## When NOT to use this skill

- Boundary or invariant verification — use `qa-inspect`
- Code-quality review — use `code-review`
- Single-suite re-run (just `go test ./...`) — invoke the command directly
- Deploying to Fly — use `deploy-runbook`

## Gate matrix

Each gate exits non-zero on failure. Run from the repo root.

| Gate | Command | Required when |
|---|---|---|
| go-build | `cd backend && go build ./...` | any backend change |
| go-vet | `cd backend && go vet ./...` | any backend change |
| go-test | `cd backend && go test ./... -short` | any backend change |
| go-int | `make api-test-int` | repository / handler / migration change (requires `INTEGRATION_DATABASE_URL`) |
| flutter-analyze | `cd frontend && flutter analyze` | any Flutter change |
| flutter-test | `cd frontend && flutter test` | any Flutter change |
| admin-build | `cd admin && npm run build` | any admin change |
| admin-test | `cd admin && npm test --run` | any admin change |
| sqlfluff | `make sqlfluff` (or equivalent CI invocation) | any migration change |
| token-drift | `scripts/gen-tokens.sh` then `git diff --exit-code admin/src/lib/tokens.ts` | any `design/tokens.json` change |
| openapi-validate | `make openapi-validate` (or equivalent) | any `backend/openapi.yaml` change |
| smoke | `make smoke` (requires running API + Postgres) | end-of-phase, end-of-review |

## Conventions

- Detect which gates are required from `git diff --name-only <base>...HEAD` (or the working tree if there is no commit context yet). Run only the required gates by default; pass `--all` to run every gate regardless.
- Run independent gates in parallel via `&` + `wait`; do not chain via `&&` unless one depends on another.
- For integration tests, fail loudly if `INTEGRATION_DATABASE_URL` is unset rather than skipping silently.
- Capture each gate's stdout/stderr to a per-gate log file for the report.

## Workflow

1. Detect changed paths via `git diff --name-only` (default base: `main`).
2. Build the required-gates set from the matrix above.
3. Run each required gate; capture exit code + last 50 stderr lines.
4. Write `docs/history/<context>/verify_report.md` (or `docs/history/verify/<YYYY-MM-DD>.md` for direct invocation).
5. Print the consolidated verdict to stdout.

## Output format

```markdown
# Verify Gates Report
Date: {YYYY-MM-DD}
Context: kamos-build phase 4 / code-review final / direct
Base: {git-ref}
Changed paths: {summary}

## Result: PASS | FAIL

## Gates

| Gate | Required | Status | Duration | Log |
|---|---|---|---|---|
| go-build | yes | PASS | 4.2s | ./logs/go-build.log |
| go-vet | yes | PASS | 1.1s | ./logs/go-vet.log |
| go-test | yes | FAIL | 12.4s | ./logs/go-test.log |
| ... | ... | ... | ... | ... |

## Failures (with last 50 stderr lines)

### go-test
<excerpt>

```

## Communication

When invoked by `kamos-build` Phase 4: SendMessage `[[protocol:BUILD-013]]` TaskUpdate; on FAIL, also SendMessage the responsible implementer with the gate name + failure excerpt + the agent who should fix it. Routing:

| Gate | Owner |
|---|---|
| go-build / go-vet / go-test / go-int / openapi-validate | backend-engineer |
| flutter-analyze / flutter-test | flutter-engineer |
| admin-build / admin-test | backend-engineer (admin slice) |
| sqlfluff | db-architect |
| token-drift | designer |
| smoke | flag to orchestrator; both layers may be implicated |

## What this skill is not

- **Not boundary verification.** That's `qa-inspect`.
- **Not deployment.** That's `deploy-runbook`.
- **Not coverage analysis.** Just gate pass/fail.
