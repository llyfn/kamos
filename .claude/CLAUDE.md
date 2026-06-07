# KAMOS — CLAUDE.md

A Japanese alcoholic beverage discovery and tracking platform — Untappd for Nihonshu, Shochu, and craft sake-adjacent drinks. Flutter (iOS + Android) on Go + PostgreSQL, with full EN / JA / KO localization.

This file orients every Claude Code session in this repo. Project-specific invariants and the multi-agent harness layout are documented here; how-to knowledge lives in `.claude/skills/`; per-agent communication protocols live in `.claude/agents/`.

## Read first

- `README.md` — high-level pitch + doc index
- `SPEC.md` — MVP product specification, the source of truth for behavior
- `ARCHITECTURE.md` — system overview, layer breakdowns, multi-replica topology
- `DEPLOYMENT.md` — env vars, vendor flags, deploy quickstart
- `CONTRIBUTING.md` — commits, verification matrix, coding conventions
- `docs/runbooks/` — staging deploy, secret rotation, incident response
- `docs/db/` — schema, indexes, query patterns
- `.claude/skills/` — task playbooks (loaded on demand)
- `.claude/agents/` — specialist agent definitions

When `SPEC.md` and any other document conflict, `SPEC.md` wins.

## Stack

- **Backend:** Go 1.26+ (latest LTS), `chi` router, `pgx/v5` directly (no ORM), JWT (HS256 or RS256), Google OAuth2
- **DB:** PostgreSQL 18+ with `pgcrypto` for `gen_random_uuid()`
- **Cache:** per-replica LRU always-on; optional Redis 7+ as a shared L2, enabled by `CACHE_BACKEND=redis` + `CACHE_REDIS_URL`
- **Cursor signing:** `CURSOR_SECRET` (≥ 32 bytes, validated at startup) HMACs every paginated cursor
- **Mobile:** Flutter (stable channel), Riverpod, `go_router`, `dio`, `flutter_secure_storage`
- **Admin:** React 19 + Vite 6 + TypeScript (`admin/`)
- **Locales:** `en`, `ja`, `ko` (full coverage in MVP)
- **Min platforms:** iOS 15+, Android API 26+

## Hosted environment

A single hosted environment auto-deploys on every merge to `main`. There is no dev/prod split right now; one will be introduced once reliability requirements demand it.

Custom domains (`api.kamos.app` etc.) are deferred — we use the free Fly/Pages/r2.dev URLs for now.

| What | Where |
|---|---|
| API | `https://kamos.fly.dev` (Fly.io app `kamos`, NRT/Tokyo, two processes) |
| Admin SPA | Cloudflare Pages default `*.pages.dev` URL |
| DB | Fly Postgres `kamos-db` (Pg18, NRT) |
| Cache L2 | Upstash Redis (NRT, `rediss://`) — optional |
| Photos | Cloudflare R2 bucket `kamos-checkin-photos` (r2.dev public URL) |
| Image registry | `registry.fly.io/kamos` (Fly remote builder) |

CI: `.github/workflows/ci.yml` — all gates required (Go build/vet/golangci-lint/test, integration suite, Flutter analyze/test, admin biome/build, sqlfluff, token-drift). CD: `.github/workflows/deploy.yml` (workflow_run on CI green → `flyctl deploy --remote-only` → stage `APP_VERSION` → liveness check on `kamos.fly.dev`). Migrations are NOT in CD — apply manually via `flyctl proxy` + `scripts/migrate.sh` (runbook §2). App config: `backend/fly.toml`. Runbook: `docs/runbooks/deploy.md`.

Mobile devs: `flutter run --dart-define=KAMOS_API_BASE_URL=https://kamos.fly.dev`. TestFlight / Play Internal pipelines are not in place yet.

## Repository layout

The project uses a standard top-level layout. Production code lives here only.

```
backend/                     # Go REST API + worker (chi + pgx/v5)
  cmd/server/                #   HTTP listener — stateless, scales horizontally
  cmd/worker/                #   background-job scheduler — single replica
  internal/handlers/         #   per-aggregate HTTP layer
  internal/service/          #   orchestration, transactions, cache invalidation
  internal/repository/       #   pure SQL + scan (pgx)
  internal/domain/           #   request/response types + validate.SanitizeText
  internal/httperr/          #   domain error → HTTP mapping
  internal/cursor/           #   HMAC-signed cursor envelopes
  internal/cache/            #   Backend interface (InProcess + Redis + notify)
  internal/jobs/             #   scheduler + jobs (wrapped in pg_try_advisory_lock)
  internal/auth/             #   JWT + Google + soft-deleted-user cache
  internal/middleware/       #   ratelimit, etag, otel, admin cookie + CSRF
  internal/observability/    #   Sentry + OTel + Prometheus wiring
frontend/                    # Flutter mobile app
  lib/core/api/              #   KamosApi typed facade + consolidated exceptions
  lib/features/<aggregate>/  #   per-feature screens + providers + repositories
  lib/shared/widgets/        #   AsyncWidget, KamosCard, KamosChip, etc.
  lib/app/                   #   theme.dart (KamosTokens + KamosSpacing), router, app
admin/                       # React admin web client (HttpOnly cookie auth + CSRF)
migrations/                  # PostgreSQL migration SQL (append-only)
db/                          # Custom Postgres image (flyio/postgres-flex:18 + pg_bigm)
design/                      # Design system: tokens.json (source of truth), brand doc, UI kit
docs/                        # Long-form documentation
  db/                        #   schema.md, indexes.md, query_patterns.md
  history/                   #   00_brief.md + archived per-phase QA + review reports
  runbooks/                  #   deploy.md, secret-rotation.md, incident-response.md
scripts/                     # Operational scripts (smoke.sh, migrate.sh, gen-tokens.sh)
docker-compose.yml           # Postgres + API for local dev
Makefile                     # One-line dev tasks
ARCHITECTURE.md              # System overview + layer breakdowns
CONTRIBUTING.md              # Commits, verification matrix, conventions
DEPLOYMENT.md                # Env vars + deploy quickstart
SPEC.md                      # Product spec (source of truth)
```

## How this project uses agents and skills

KAMOS is built with a multi-agent harness. Sessions fall into one of three modes:

1. **Multi-layer feature work** — invoke the `kamos-build` skill. It runs a vertical-slice pipeline for one feature: preflight → design → schema + API (+ admin, when in scope) → Flutter → final QA. Per-layer QA fires the moment each implementer reports done. Use this whenever the request touches ≥2 of: design, schema, API, admin, Flutter, i18n.
2. **Code review** — invoke the `code-review` skill. It fans out four reviewer agents (arch / security / perf / style) and merges their findings.
3. **Single-task work** — for a single bug fix, a single screen, a single endpoint, a single migration: just do the work directly using the relevant skill (`go-api`, `flutter-feature`, `db-schema`, `design-wireframe`) without spawning agents. Spawning a team for a one-line fix is the wrong tool.

The agents in `.claude/agents/` are designed to be spawned by the orchestrator skills, not invoked manually for every task.

## Multi-replica topology

The API is stateless and scales horizontally. The worker is single-replica. Cache invalidation crosses replicas via Postgres `LISTEN/NOTIFY`. Read `ARCHITECTURE.md` §4 before making any cache or job changes.

- **`cmd/server`** — N replicas behind a load balancer. No in-process scheduler, no per-replica counters.
- **`cmd/worker`** — single replica. Owns `internal/jobs/` (`username_hold`, `avg_rating_sweep`, `email_verification_cleanup`, `photo_orphan_cleanup`). Belt-and-suspenders: every tick is wrapped in `pg_try_advisory_lock`, so even a misconfigured deploy that still ran jobs in API replicas would fail safe — only the first to grab the lock fires the body.
- **Cache invalidation** — mutator paths emit `pg_notify('kamos_cache_invalidate', '<key>')`. Every replica's `internal/cache/invalidator.go` listens and drops the matching key from its L1 LRU (and from the Redis L2 if configured). Eventual-consistency window is in the low 100s of milliseconds.

## Auth topology

Two clients, two auth surfaces:

- **Mobile (Flutter)** — Bearer JWT in `Authorization: Bearer …`. JWT + refresh token in `flutter_secure_storage` per SPEC §6.9; iOS Keychain accessibility is `first_unlock_this_device` (Stage 0 hotfix). Refresh tokens rotate atomically in a single transaction; family revocation on detected reuse.
- **Admin (React)** — `HttpOnly` + `Secure` + `SameSite=Strict` cookies for access + refresh. CSRF protection is double-submit token: `X-CSRF-Token` header compared (constant-time) against the `kamos_admin_csrf` cookie. Required on every mutating admin request. Identity endpoint is `GET /v1/admin/me` (cookie-authable; `/v1/users/me` is Bearer-only). Pages↔Fly is cross-site; same-site is restored by the Pages Function proxy at `admin/functions/v1/[[path]].ts` (and `vite.config.ts` locally). See `ARCHITECTURE.md §5`.
- **SEC-006 soft-delete cache** — `internal/auth/` keeps an in-process LRU of soft-deleted user IDs so token verification rejects them immediately for the 30-day username-hold window, without a per-request DB roundtrip.

## Project invariants (from SPEC)

These are non-negotiable across every layer. Violating any of these is a QA blocker.

**Category terminology** — UI must use these exact strings:

| Locale | Sake | Shochu | Liqueur |
|---|---|---|---|
| `en` | `Nihonshu (Sake)` | `Shochu` | `Liqueur` |
| `ja` | `日本酒` | `焼酎` | `リキュール` |
| `ko` | `니혼슈 (사케)` | `쇼츄` | `리큐어` |

Never abbreviate, never substitute "Sake" alone in `en`.

**Rating scale** — `0.5–5.0` in `0.25` steps (19 levels). Optional per check-in. Stored in PostgreSQL as `NUMERIC(3,2)`. In Go and Dart, use a type that preserves two decimals (`float64` / `double` is acceptable; integer is not). API responses emit it as a number, never a string.

**Username** — case-insensitive, stored lowercase, displayed as entered at registration. `3–30` chars, alphanumeric + underscore.

**Soft-delete rules** — accounts are soft-deleted; the username is held for 30 days before being released. Check-ins and collections are soft-deleted via `deleted_at TIMESTAMPTZ`. As of Stage 7, `comments.user_id` is `ON DELETE SET NULL` so author-soft-delete doesn't orphan the comment row.

**i18n fallback** — if a beverage has no `ko` name, the `ko` locale falls back to `en`. Same rule for `ja → en`. Never display empty strings or the wrong-locale text.

**Pagination** — feed and all list endpoints use cursor pagination, never offset. Response shape: `{ "items": [...], "next_cursor": "...", "has_more": bool }`. Page size is 20 for the feed. Cursors are HMAC-signed with `CURSOR_SECRET` (Stage 0); tampered cursors return `400 INVALID_CURSOR`.

**Check-in caps** — review text ≤ 500 chars; up to 1 photo per check-in on submission. Existing multi-photo check-ins remain readable (the API still serves their full photo arrays).

**Default collections** — every new user is created with two collections: `Inventory` and `Wishlist`. They are renameable and deletable, not special. Stage 5 localized the seed names per the registering user's `locale`.

**Auth storage on Flutter** — JWT lives in `flutter_secure_storage`, never in `SharedPreferences`. iOS Keychain accessibility = `first_unlock_this_device` (Stage 0). This is a security blocker, not a preference.

**Admin auth** — admin mutating requests require both the HttpOnly cookie (`kamos_admin_*`) AND a matching `X-CSRF-Token` header. Missing or mismatched header → `403 CSRF_MISMATCH`. Cookies are `HttpOnly` + `Secure` + `SameSite=Strict` — do not flip to `SameSite=None`; the Pages Function proxy is what keeps Strict viable across Pages↔Fly.

**Text input sanitization** — every user-provided string field flows through `domain.SanitizeText(field, value, allowEmpty, maxLen)`. The helper rejects control characters and bidi-override codepoints, enforces UTF-8 length, and returns a typed validation error.

**Search invariants** — substring search across the product follows one shape so the operator footprint stays small:

- **Every searchable column has a covering index.** No `LIKE '%foo%'` or `ILIKE` against a column without a `gin_bigm_ops` GIN index. The four bigm indexes shipped in migration 003 are the baseline: `idx_beverages_search_bigm`, `idx_producers_search_bigm`, `idx_users_username_bigm`, `idx_users_display_name_bigm` (functional, on `lower(display_name)`). Add a new bigm index in the same migration that introduces a new searchable column.
- **Cross-field / i18n search uses a materialized `search_text TEXT` column maintained by triggers.** Compose the searchable text (lowercased) on write, never on read. Triggers must cover every parent edit that affects the composition (see `kamos_compute_*_search_text` + `kamos_trg_*_search_text` for the producer/prefecture cascade pattern).
- **pg_bigm is the substring engine.** Use `search_text LIKE '%' || lower($1) || '%'` (or the `=%` operator). Do NOT introduce `pg_trgm`, `to_tsvector`, or `websearch_to_tsquery` for new search paths — bigm subsumes them for our CJK-first content. The custom kamos-db image ships `pg_bigm` ([[project-custom-pg-image]]).
- **LIKE metacharacter escape is mandatory.** All user-supplied query strings flowing into a `LIKE` clause must pass through `repository.bigmLikeArg(q)` (or equivalent) which lowercases and escapes `\`, `%`, `_`. Skipping this is a SECURITY-adjacent correctness bug: typing `%` would otherwise match everything.
- **One query plan per search endpoint.** No FTS-then-trigram fallback orchestration, no UNION ALL of competing search shapes. Bigm handles long and short, Latin and CJK, in one query.
- **User-search ranking is 3-tier in the SQL, not in Go.** Exact → prefix → substring, then `char_length(username) ASC, created_at DESC, id DESC`. Cursor packs `(match_tier, name_length, created_at, id)` through the HMAC-signed cursor envelope. Min-2-char rule + case-insensitivity + `deleted_at IS NULL` filter all preserved.

**Out of scope for MVP** — push notifications, threaded comments, end-user web client, Apple Sign-In, beverage scanning, blocking, recommendations, export. If a request implies any of these, confirm scope before implementing.

**Shipped post-MVP (v1.1)** — venue/location (Foursquare, Phase 4), flat comments on check-ins (Phase 6), public collections (Phase 6), user-submitted beverage additions with admin moderation (Phase 5). All four shipped end-to-end by Phase 7. Phase 8 brought post-create editability on check-ins + comments and admin-managed producer images.

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

## Code comments — strict policy

Default to writing **no comments**. Only two kinds of comment are acceptable:

1. The **non-obvious why or how** of a tricky piece of code — a hidden constraint, a subtle invariant, a workaround for a known bug, an unusual decision. If a future reader who already understands the surrounding code would be confused without it, write it. Otherwise don't.
2. A **really brief outline** (one short line, not a multi-line docstring) at the top of a file, class, or function describing its purpose.

**Never write:**

- History/changelog comments — `// added for Slice B`, `// post-MVP polish`, `// Phase 2`, PR/issue numbers, dates, `// removed in 2026-…`, `// see PR #42`.
- Task-tracking comments — `// used by Z`, `// handles the case from issue #…`, `// for the Y flow`.
- Restatements of well-named identifiers.
- Apologies/hedges/TODOs you don't intend to action this turn.

**When editing existing code:** if you touch a function, sweep out the surrounding comments that violate the rules above — they're orphans from prior work, not load-bearing.

This rule is non-negotiable and applies to Go, Dart, TypeScript, SQL, and ARB description fields alike. `qa-inspector` and code reviewers should flag violations as MAJOR.

## UI consistency baseline

All non-auth screens (Feed / Lists / Discover / Notifications / Me + every detail/edit/sub screen) share one chrome baseline:

- A page title in the same size/weight token as Collections (`KamosTypography.titleLg` or equivalent).
- Stat tiles and info rows are **chromeless** — no `bgWarm` panel, no border, no rounded background — unless the spec calls out a card.
- Form labels (`RATING`, `REVIEW`, etc.) use the high-contrast label token, never a low-opacity grey.
- Form placeholders never include example values (no `e.g. 1500`, no sample text). Placeholders state the field's purpose only.
- Primary CTAs at the bottom of forms are full-width pills. While submitting, the button stays styled the same — no inline spinner — and the label switches to a short progress word (e.g. `Posting…`).
- Avatars, names, and inline meta-rows align on a single vertical center axis. Profile-image taps go to the user's profile; user-name taps inside a check-in card go to the check-in detail, not the profile.
- Beverage subtitle lines show **Category · Subcategory** (never Category · Prefecture, never Producer · Prefecture in feed/discover/check-in card contexts).

If a screen looks "off" against any of these, fix it in the slice that touches it — don't accept inconsistency.

## Verification — before declaring "done"

A task is not complete until the relevant verification passes:

| Layer changed | Run |
|---|---|
| Migrations | `psql` apply on a fresh test DB; check schema with `\d+`. Append-only. |
| Go | `go build ./...`, `go vet ./...`, `go test ./... -short` |
| Go (integration) | `make api-test-int` (requires `INTEGRATION_DATABASE_URL`) |
| Flutter | `flutter analyze` and `flutter test` |
| Admin | `npm run build` (from `admin/`); `npm test --run` |
| OpenAPI | spec validates and matches handler response shapes (cross-check with `qa-inspect` skill) |
| i18n | all three ARB files have matching keys (`frontend/l10n/intl_{en,ja,ko}.arb`) |
| Design tokens | edit `design/tokens.json` then run `scripts/gen-tokens.sh`; CI fails if `admin/src/lib/tokens.ts` drifts |
| Full smoke | `make smoke` (requires a running API + Postgres) |

Multi-layer changes additionally need an integration check — that's the `qa-inspector` agent's job.

If anything fails, report what failed. Do not call it complete.

## Destructive operations — confirm first

- `rm -rf`, recursive deletes
- `git push --force`, `git reset --hard` on shared branches, branch deletion
- Editing or deleting any migration file already applied to a shared environment (always add a new migration instead)
- Database drops, truncates, destructive seed scripts
- Any change that modifies files outside the repo

## Secrets

- Never commit secrets. Use environment variables and `local.env.example` for documentation.
- `JWT_SECRET` and `CURSOR_SECRET` are both validated for length (≥ 32 bytes) at startup. Production must set both. Rotation runbook: `docs/runbooks/secret-rotation.md`.
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
