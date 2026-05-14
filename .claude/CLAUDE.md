# KAMOS — CLAUDE.md

A Japanese alcoholic beverage discovery and tracking platform — Untappd for Nihonshu, Shochu, and craft sake-adjacent drinks. Flutter (iOS + Android) on Go + PostgreSQL, with full EN / JA / KO localization.

This file orients every Claude Code session in this repo. Project-specific invariants and the multi-agent harness layout are documented here; how-to knowledge lives in `.claude/skills/`; per-agent communication protocols live in `.claude/agents/`.

## Read first

- `README.md` — high-level pitch
- `SPEC.md` — MVP product specification, the source of truth for behavior
- `.claude/skills/` — task playbooks (loaded on demand)
- `.claude/agents/` — specialist agent definitions

When `SPEC.md` and any other document conflict, `SPEC.md` wins.

## Stack

- **Backend:** Go 1.26+ (latest LTS), `chi` router, `pgx/v5` directly (no ORM), JWT (HS256 or RS256), Google OAuth2
- **DB:** PostgreSQL 18+ with `pgcrypto` for `gen_random_uuid()`
- **Mobile:** Flutter (stable channel), Riverpod, `go_router`, `dio`, `flutter_secure_storage`
- **Locales:** `en`, `ja`, `ko` (full coverage in MVP)
- **Min platforms:** iOS 13+, Android API 26+

## Repository layout

The project follows a workspace-based pipeline used by the agent harness, then graduates to a real source tree:

```
_workspace/                  # agent intermediate artifacts (per-phase outputs)
  00_brief.md
  01_design/                 # designer outputs
  02_backend/db/             # db-architect outputs (migrations, query patterns)
  02_backend/api/            # backend-engineer outputs (Go source, openapi.yaml)
  03_frontend/               # flutter-engineer outputs (Flutter project)
  04_qa/                     # qa-inspector incremental + final reports
  review/                    # code-review skill outputs
backend/                     # the real Go project (promoted from _workspace once stable)
frontend/                    # the real Flutter project
migrations/                  # the real migration files (mirrors _workspace/02_backend/db/migrations/)
```

**Path rule:** if `backend/` or `frontend/` already exists at the repo root, write production code there. Otherwise write to `_workspace/02_backend/api/` or `_workspace/03_frontend/`. Never write the same file in both places.

## How this project uses agents and skills

KAMOS is built with a multi-agent harness. Sessions fall into one of three modes:

1. **Orchestrated full-stack work** — invoke the `kamos-build` skill. It runs the full pipeline: designer → db-architect + backend-engineer (parallel) → flutter-engineer → qa-inspector. Use this for "build the app," "scaffold X feature end-to-end," or any request that touches multiple layers.
2. **Code review** — invoke the `code-review` skill. It fans out four reviewer agents (arch / security / perf / style) and merges their findings.
3. **Single-task work** — for a single bug fix, a single screen, a single endpoint, a single migration: just do the work directly using the relevant skill (`go-api`, `flutter-feature`, `db-schema`, `design-wireframe`) without spawning agents. Spawning a team for a one-line fix is the wrong tool.

The agents in `.claude/agents/` are designed to be spawned by the orchestrator skills, not invoked manually for every task.

## Project invariants (from SPEC)

These are non-negotiable across every layer. Violating any of these is a QA blocker.

**Category terminology** — UI must use these exact strings:

| Locale | Sake | Shochu | Liqueur |
|---|---|---|---|
| `en` | `Nihonshu (Sake)` | `Shochu` | `Liqueur` |
| `ja` | `日本酒` | `焼酎` | `リキュール` |
| `ko` | `니혼슈 (사케)` | `쇼츄` | `리큐어` |

Never abbreviate, never substitute "Sake" alone in `en`.

**Rating scale** — `0.5–5.0` in `0.5` steps (10 levels). Optional per check-in. Stored in PostgreSQL as `NUMERIC(3,1)`. In Go and Dart, use a type that preserves one decimal (`float64` / `double` is acceptable; integer is not). API responses emit it as a number, never a string.

**Username** — case-insensitive, stored lowercase, displayed as entered at registration. `3–30` chars, alphanumeric + underscore.

**Soft-delete rules** — accounts are soft-deleted; the username is held for 30 days before being released. Check-ins and collections are soft-deleted via `deleted_at TIMESTAMPTZ`.

**i18n fallback** — if a beverage has no `ko` name, the `ko` locale falls back to `en`. Same rule for `ja → en`. Never display empty strings or the wrong-locale text.

**Pagination** — feed and all list endpoints use cursor pagination, never offset. Response shape: `{ "items": [...], "next_cursor": "...", "has_more": bool }`. Page size is 20 for the feed.

**Check-in caps** — review text ≤ 500 chars; up to 4 photos per check-in.

**Default collections** — every new user is created with two collections: `Inventory` and `Wishlist`. They are renameable and deletable, not special.

**Auth storage on Flutter** — JWT lives in `flutter_secure_storage`, never in `SharedPreferences`. This is a security blocker, not a preference.

**Out of scope for MVP** — venue/location, threaded comments, push notifications, public collections, user-submitted beverages, web client, Apple Sign-In, beverage scanning, blocking. If a request implies any of these, confirm scope before implementing.

## Communication

- Reply in the language the user wrote in. When replying in Korean or Japanese, keep code, identifiers, library names, error messages, and SPEC terms (`Nihonshu`, `Shochu`, `check-in`, `toast`) in their canonical form. Do not transliterate.
- Be direct. Skip preambles and recaps unless asked.
- Reference code as `path/to/file.go:42`.
- Do not guess SPEC details. If something is not stated in `SPEC.md`, say so and ask.

## Before editing

- Read the relevant files first. Do not infer file contents from names.
- For any change touching more than ~3 files, summarize the plan and wait for confirmation.
- Do not modify files outside the requested scope. No bundled refactors.
- If the work is multi-layer (e.g., new endpoint requiring a migration + handler + Flutter screen), prefer invoking `kamos-build` or coordinating through the agent files rather than freelancing all three layers in one pass.

## Verification — before declaring "done"

A task is not complete until the relevant verification passes:

| Layer changed | Run |
|---|---|
| Migrations | `psql` apply on a fresh test DB; check schema with `\d+` |
| Go | `go build ./...` and `go test ./...` |
| Flutter | `flutter analyze` and `flutter test` |
| OpenAPI | spec validates and matches handler response shapes (cross-check with `qa-inspect` skill) |
| i18n | all three ARB files have matching keys |

Multi-layer changes additionally need an integration check — that's the `qa-inspector` agent's job.

If anything fails, report what failed. Do not call it complete.

## Destructive operations — confirm first

- `rm -rf`, recursive deletes
- `git push --force`, `git reset --hard` on shared branches, branch deletion
- Editing or deleting any migration file already applied to a shared environment (always add a new migration instead)
- Database drops, truncates, destructive seed scripts
- Any change that modifies files outside the repo

## Secrets

- Never commit secrets. Use environment variables and `.env.example` for documentation.
- The Flutter app must never hold the Google OAuth client secret — only the client ID is shipped to the app; the secret stays server-side.

## Tooling preferences

- Backend tests use the standard library `testing` package; integration tests use a real PostgreSQL test DB, not mocks
- Flutter uses `freezed` + `json_serializable` for models; do not write `fromJson` by hand if codegen is available
- No new dependencies without asking; the dependency lists in `flutter-feature` and `go-api` skills are the baseline

---

**For specific work:**
- Multi-layer feature → `kamos-build` skill
- Code review → `code-review` skill
- Schema work → `db-schema` skill
- Go endpoint → `go-api` skill
- Flutter screen → `flutter-feature` skill
- Wireframe / spec → `design-wireframe` skill
- QA cross-check → `qa-inspect` skill
