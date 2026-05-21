# Contributing to KAMOS

Welcome. KAMOS is a Flutter (iOS + Android) + Go + PostgreSQL stack with a React admin client and full `en`/`ja`/`ko` localization. This document describes how to land changes.

If anything here conflicts with `SPEC.md` or `.claude/CLAUDE.md`, those documents win.

## Source of truth

- `SPEC.md` — product behaviour. Source of truth for invariants (categories, rating scale, pagination, etc.).
- `.claude/CLAUDE.md` — project-wide engineering rules and verification matrix.
- `DEPLOYMENT.md` — environment variables, deploy targets, secret rotation.
- `docs/db/` — schema, indexes, query patterns.

## Branching & commits

We use **Conventional Commits** (`<type>(<scope>): <subject>`) with a fixed scope enum. The full list of allowed types and scopes lives in `.github/commitlint.config.cjs`.

**Common types:** `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `ci`, `build`, `perf`, `style`.

**Allowed scopes (current):**

| Scope | Use for |
|---|---|
| `frontend` | Flutter app code (`frontend/`) |
| `frontend/ios` | iOS-specific platform code |
| `api` | Backend HTTP layer (handlers, router, middleware-wiring) |
| `backend` | Go backend, broader than `api` (services, repo, config, etc.) |
| `middleware` | Go middleware specifically |
| `cache` | Cache + invalidation layer |
| `admin` | React admin client (`admin/`) |
| `qa` | QA reports, smoke scripts, integration tests |
| `observability` | Sentry, Grafana, OTel, logs, metrics |
| `design` | Design tokens, brand, wireframes (`design/`) |
| `review` | Code-review artifacts |
| `security` | Security fixes that span layers |
| `repo` | Repo-wide changes (layout, Makefile, top-level docs) |
| `harness` | `.claude/` agent + skill harness |
| `docs` | Documentation that isn't tied to a single subsystem |
| `ci` | GitHub Actions, lint configs |
| `deps` | Dependency bumps |

Header is capped at 100 characters. Examples:

```
feat(api): add /v1/admin/moderation-log endpoint
fix(frontend): clear toast count on logout
chore(ci): add tooling baseline + CI workflow
```

Body is plain Markdown. End AI-pair-programmed commits with:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

### Local commit hooks

The repo ships a `lefthook.yml` that runs commitlint on every commit message. To enable:

```bash
npm install        # installs commitlint + lefthook at the repo root
npx lefthook install
```

Hooks are best-effort: a missing local install will not block CI, but CI will reject malformed commit messages.

## Verification matrix

Every change must pass the matrix for the layers it touches.

| Layer changed | Run |
|---|---|
| Migrations | `psql` apply against a fresh test DB; verify with `\d+`. Append-only. |
| Go (`backend/`) | `go build ./...` and `go test ./... -short`. Integration suite (`go test -tags=integration`) if behaviour-affecting. |
| Flutter (`frontend/`) | `flutter analyze --no-fatal-infos --no-fatal-warnings` and `flutter test`. |
| OpenAPI (`backend/openapi.yaml`) | Spec must validate; response shapes match handlers. Re-run admin `npm run codegen` if shapes changed. |
| i18n (`frontend/l10n/*.arb`) | All three locales (`en`, `ja`, `ko`) must have matching keys. |
| Admin (`admin/`) | `npm run build` (TypeScript + Vite). `npx biome check src/` is advisory until Stage 8. |
| Multi-layer | Add an integration check; consider invoking the `qa-inspect` skill. |

If any verification fails, the change is not done. Report what failed.

## CI

`.github/workflows/ci.yml` runs on every PR to `main` and every push to `main`. Jobs:

1. **`backend-go`** — `go build` + `go vet` + `golangci-lint` (advisory) + `go test -short`.
2. **`frontend-flutter`** — `flutter pub get` + `flutter analyze` (no-fatal) + `flutter test`.
3. **`sql-lint`** — `sqlfluff lint migrations/` (advisory).
4. **`admin-build`** — `npm ci` + `biome check` (advisory) + `npm run build`.
5. **`integration-smoke`** — Docker Postgres + `make db-migrate` + `scripts/smoke.sh` (advisory, `main` only).

A `paths-filter` step skips jobs that aren't relevant to the diff. On `main` everything runs.

### Advisory vs required (Stage 2)

The following are intentionally **advisory** in CI for now:

- `go vet` findings — three pre-existing test-helper warnings; Stage 8 cleans up.
- `golangci-lint` findings — Stage 8 of the refactor plan owns the cleanup sweep.
- `flutter analyze` strict-lint findings — same, demoted to `info` severity in `frontend/analysis_options.yaml`.
- `biome check` warnings/errors on the admin client — Stage 8 cleanup.
- `sqlfluff` findings on migrations — purely stylistic.
- `integration-smoke` — runs on `main` only; environment-dependent.

A future PR (Stage 8) will flip these from advisory to required once the existing findings are resolved. The list of currently-demoted strict Flutter lints is documented inline in `frontend/analysis_options.yaml`.

## Design tokens

The canonical source for color / spacing / radius / typography / motion tokens is `design/tokens.json`. A bash + node codegen script (`scripts/gen-tokens.sh`) reads it and emits per-platform sinks. The CI `tokens-codegen` job runs the script and fails if the generated sinks drift, which makes this a **required** check on every PR.

Workflow:

1. Edit `design/tokens.json`.
2. Run `scripts/gen-tokens.sh`.
3. Commit the JSON change **and** the regenerated sinks together.

Current sink coverage (Stage 7 partial — see ARCH-011):

| Sink | Path | Status |
|---|---|---|
| Admin (TypeScript) | `admin/src/lib/tokens.ts` | Generated. |
| CSS variables | `design/colors_and_type.css` | Hand-maintained. Codegen target is queued; values must be kept in sync with `tokens.json` by hand for now. |
| Flutter theme | `frontend/lib/app/theme.dart` | Hand-maintained. Same caveat — codegen target is queued. |

When you change a color in `tokens.json`, mirror the same value into `design/colors_and_type.css` and the relevant constants in `frontend/lib/app/theme.dart` in the same PR until the codegen lands for those sinks.

## Migration discipline

- **Append-only.** Never edit a migration that has been applied to a shared environment.
- File naming: `NNN_short_snake_case.sql`, zero-padded to three digits, monotonically increasing.
- Each migration should be transactional where possible (`BEGIN; … COMMIT;`), but Postgres DDL inside transactions is fine.
- Rollbacks are forward-only: write a new migration that undoes the change, not a `-1` or `down` script.
- Update `docs/db/schema.md` and `docs/db/query_patterns.md` in the same PR if the change is observable from the application layer.

## Secrets

- Never commit secrets. Use environment variables; document them in `local.env.example` and `DEPLOYMENT.md`.
- Stage 0 of the refactor added a `CURSOR_SECRET` env var (≥32 bytes, validated at startup). Production must set this. Sample lives in `local.env.example`; deploy docs are in `DEPLOYMENT.md`.
- The Flutter app must never hold the Google OAuth client secret — only the client ID ships to the app.
- JWT secret (`JWT_SECRET`) is also validated for length (≥32 bytes) at startup.

## PR checklist

Before requesting review:

- [ ] Link to the relevant SPEC section (or note that the change is internal).
- [ ] Run the verification matrix for every layer touched.
- [ ] CI is green (or every red job is documented as advisory and pre-existing).
- [ ] No secrets in the diff (`.env`, credentials, API keys).
- [ ] Commit messages match the Conventional Commits format.
- [ ] If the change is multi-layer, add or update the relevant integration tests.
- [ ] If the change touches `openapi.yaml`, regenerate the admin and Flutter typed clients in the same PR.

## What this project does not accept

- Edits to files outside the requested scope. "I noticed this nearby" refactors belong in their own PR.
- Skipping commit hooks (`--no-verify`) or signing (`--no-gpg-sign`) without a written reason.
- New dependencies without prior agreement; the dependency lists in the relevant skill (`go-api`, `flutter-feature`) are the baseline.
- Force-pushes to `main`.
- Deleting or editing migrations that have been applied to staging or production.

## Working with the agent harness

If you're using Claude Code with this repo, the multi-agent skills do most of the heavy lifting:

- `kamos-build` — full-stack feature.
- `code-review` — four reviewers + merge.
- `qa-inspect` — boundary / SPEC compliance check.
- Per-layer skills (`go-api`, `flutter-feature`, `db-schema`, `design-wireframe`) for single-task work.

The agents in `.claude/agents/` are spawned by the orchestrator skills; don't invoke them directly for trivial fixes.
