# Contributing to KAMOS

Welcome. KAMOS is a Flutter (iOS + Android) + Go + PostgreSQL stack with a React admin client and full `en`/`ja`/`ko` localization. This document describes how to land changes.

If anything here conflicts with `SPEC.md` or `.claude/CLAUDE.md`, those documents win.

## Source of truth

- `SPEC.md` — product behaviour. Source of truth for invariants (categories, rating scale, pagination, etc.).
- `.claude/CLAUDE.md` — project-wide engineering rules and verification matrix.
- `DEPLOYMENT.md` — environment variables, deploy targets, secret rotation.
- `docs/db/` — schema, indexes, query patterns.

## Branching & commits

`main` is protected. Land every change on a feature branch and merge it via a pull request — no direct pushes to `main`.

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

Body is plain Markdown. Do not add `Co-Authored-By` trailers.

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
| Flutter (`frontend/`) | `flutter analyze` (clean — zero findings) and `flutter test`. |
| OpenAPI (`backend/openapi.yaml`) | Spec must validate; response shapes match handlers. Re-run admin `npm run codegen` if shapes changed. |
| i18n (`frontend/l10n/*.arb`) | All three locales (`en`, `ja`, `ko`) must have matching keys. |
| Admin (`admin/`) | `npm run build` (TypeScript + Vite) and `npx biome check src/` (clean). |
| Multi-layer | Add an integration check; consider invoking the `qa-inspect` skill. |

If any verification fails, the change is not done. Report what failed.

## CI

`.github/workflows/ci.yml` runs on every PR to `main` and every push to `main`. A `paths-filter` (`changes`) job skips work irrelevant to the diff; on `main` everything runs. **All gates below are required** — a red job blocks merge (and blocks the deploy, which is gated on CI success).

1. **`backend-go`** — `go build` + `go vet` + `golangci-lint` + `go test -short`.
2. **`frontend-flutter`** — `flutter pub get` + `flutter analyze` + `flutter test`.
3. **`sql-lint`** — `sqlfluff lint migrations/`.
4. **`tokens-codegen`** — regenerate `admin/src/lib/tokens.ts` from `design/tokens.json` and fail on drift.
5. **`admin-build`** — `npm ci` + `biome check src/` + `npm run build`.
6. **`integration-test`** — Postgres 18 service + `make db-migrate` + `go test -tags=integration ./tests/integration/...` (the API runs in-process via `httptest`; seeds/truncates its own data). Runs on `migrations/` changes and on `main`.

`paths-filter` calls the GitHub PR API on `pull_request` events, so the workflow grants `permissions: pull-requests: read` — without it, every PR fails the `changes` job.

The previous "advisory until Stage 8" backlog is **cleared**: every linter (golangci-lint, flutter analyze, biome, sqlfluff) is clean and required. The old `integration-smoke` job (a curl `scripts/smoke.sh` run that needed a pre-seeded DB) was replaced by the self-contained Go `integration-test` job above; `scripts/smoke.sh` remains a manual `make smoke` tool.

## Design tokens

The canonical source for color / spacing / radius / typography / motion tokens is `design/tokens.json`. A bash + node codegen script (`scripts/gen-tokens.sh`) reads it and emits per-platform sinks. The CI `tokens-codegen` job runs the script and fails if the generated sinks drift, which makes this a **required** check on every PR.

Workflow:

1. Edit `design/tokens.json`.
2. Run `scripts/gen-tokens.sh`.
3. Commit the JSON change **and** the regenerated sinks together.

Current sink coverage (partial — see ARCH-011 for the queued codegen targets):

| Sink | Path | Status |
|---|---|---|
| Admin (TypeScript) | `admin/src/lib/tokens.ts` | Generated. |
| CSS variables | `design/colors_and_type.css` | Hand-maintained. Codegen target is queued; values must be kept in sync with `tokens.json` by hand for now. |
| Flutter theme | `frontend/lib/app/theme.dart` | Hand-maintained. Same caveat — codegen target is queued. |

When you change a color in `tokens.json`, mirror the same value into `design/colors_and_type.css` and the relevant constants in `frontend/lib/app/theme.dart` in the same PR until the codegen lands for those sinks.

## Coding conventions

These are house-style rules QA enforces during cross-layer review (the `style-review` skill). Diverging is fine when a localized reason warrants it; leave a `// non-standard …` comment so a reviewer knows it was a choice rather than an oversight.

### Dart — file-private constants

File-private constants use a leading underscore. **No `_k` prefix.** The `_k` convention is a Google C++ holdover that adds noise without value in Dart, where the leading `_` already conveys privacy and constants are syntactically distinguished by `const`.

```dart
// Good
const _sentryDsn = String.fromEnvironment('KAMOS_SENTRY_DSN');
const _nameMax = 200;

// Bad
const _kSentryDsn = String.fromEnvironment('KAMOS_SENTRY_DSN');
const _kNameMax = 200;
```

### Dart — Riverpod notifier naming

Notifier classes end in `Notifier` (`FeedNotifier`, `CommentsNotifier`, `CheckInControllerNotifier`). Providers end in `Provider` and are named after their public surface (`feedProvider`, `commentsProvider`, `checkInControllerProvider`).

Provider files in `features/<x>/providers/` are named in the plural (`feed_providers.dart`, `checkin_providers.dart`) — even when the file currently exports one provider, the convention scales to N without a rename.

### Dart — spacing literals

`SizedBox(width: …)` / `SizedBox(height: …)` / `EdgeInsets.*` should reach for `KamosSpacing.xs/sm/md/lg/xl/xxl` (4/8/12/16/24/32 px) from `frontend/lib/app/theme.dart`. The named scale mirrors `design/tokens.json → spacing.named`.

Outliers (e.g. `10`, `6`, `14`) are acceptable when no named alias fits; leave a `// non-standard spacing — design decision` comment.

### Dart — async UI

Conventional `ref.watch(provider).when(loading:, error:, data:)` patterns should use `AsyncWidget<T>` from `frontend/lib/shared/widgets/async_widget.dart`. The wrapper centralizes the default loading spinner and localized error string. Skip it when the screen needs a bespoke loading or error UI.

### Go — error construction

Use `errors.New("msg")` for static error messages. Use `fmt.Errorf("…: %w", err)` only when wrapping an inner error or formatting a value (`%q`, `%s`, `%d`). A static string passed to `fmt.Errorf` is a lint smell.

### Flutter — golden baselines

Golden tests live under `frontend/test/golden/` and write PNGs under `frontend/test/golden/goldens/`. The captured pixels are platform-specific (font hinting and emoji rasterization diverge across macOS / Linux / Windows), so a baseline produced on a developer laptop will not match Linux CI.

Workflow:

1. **Capture on Linux CI**, not locally. Push a branch and run the `flutter test --update-goldens test/golden/` step on the Ubuntu runner.
2. Pull the artifact PNGs into `frontend/test/golden/goldens/`, commit them, and remove the `@Skip('golden baselines pending CI Linux capture')` annotation from the test file.
3. Subsequent runs should pass on the same runner. A diff after a layout change means either (a) the change was intentional and you re-capture, or (b) the change was unintentional and you fix it.

Until baselines land, the golden tests stay `@Skip`-ed so the suite is green for everyone.

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
- [ ] CI is green — every gate is required.
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
