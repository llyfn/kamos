# Runbook — deploy (Fly.io)

Concrete checklist for bringing the KAMOS hosted environment up on Fly.io
(Tokyo / NRT) and operating the auto-deploy pipeline. There is currently
one hosted environment; a dev/prod split is deferred until reliability
requirements warrant it.

Cross-references:
- [`DEPLOYMENT.md`](../../DEPLOYMENT.md) — env-var reference + feature-flag list.
- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — process topology, multi-replica cache invalidation.
- [`backend/fly.toml`](../../backend/fly.toml) — committed app definition (two processes, NRT). Lives inside `backend/` because that's the Dockerfile's build context.
- [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml) — the backend CD pipeline.
- [`.github/workflows/deploy-admin.yml`](../../.github/workflows/deploy-admin.yml) — the admin SPA CD pipeline (Cloudflare Pages via Wrangler).

## 1. Provision (one-time, manual)

1. **Fly app + Postgres** (Tokyo / NRT):
   ```sh
   flyctl auth login
   flyctl postgres create \
     --name kamos-db --region nrt \
     --image-ref postgres:18-alpine \
     --vm-size shared-cpu-1x --volume-size 10
   flyctl apps create kamos --org <your-org>
   flyctl postgres attach kamos-db --app kamos   # sets DATABASE_URL secret
   ```
   Capture the printed `DATABASE_URL` (and a copy with `sslmode=require` for CI).

2. **Upstash Redis** (NRT, TLS, `allkeys-lru`): create from dashboard, capture
   the `rediss://` URL — needed for `CACHE_BACKEND=redis` + `CACHE_REDIS_URL`.
   Optional: skip if you only run one server machine.

3. **Cloudflare R2** bucket + scoped API token:
   - Bucket: `kamos-checkin-photos`
   - Token scope: Object Read + Write on that bucket only
   - Enable the bucket's free public `r2.dev` URL → `R2_PUBLIC_BASE_URL`

4. **Cloudflare Pages** project `kamos-admin` (deployed by GitHub Actions via
   Wrangler, not the dashboard Git integration — see §8):
   - Create an API token scoped **Account → Cloudflare Pages: Edit**; note the
     account ID.
   - Pre-create the project so the first non-interactive deploy doesn't prompt:
     ```sh
     npx wrangler pages project create kamos-admin --production-branch=main
     ```
   - No dashboard env var is needed: `admin/.env.production`
     (`VITE_API_BASE_URL=https://kamos.fly.dev`) is baked in at build time by CI.
   - Served at the free `kamos-admin.pages.dev` URL.

> **Custom domains are deferred.** The API is served at `https://kamos.fly.dev`
> (Fly-provided, TLS included), the admin at `kamos-admin.pages.dev`, and photos
> via the bucket's `r2.dev` URL — all free, no external DNS. To add custom
> domains later: register `kamos.app`, put its DNS on a provider, then
> `flyctl certs add api.kamos.app -a kamos` (+ the AAAA/A records it prints),
> point `admin.kamos.app` at Pages, and flip the URLs in §2 + `deploy.yml`.

6. **Sentry + Grafana Cloud** — already provisioned (see
   [`reference_observability_vendors.md`](../../.claude/memory/reference_observability_vendors.md)).
   Get the `kamos-api` DSN and OTLP gateway URL + Basic auth header.

7. **GitHub `production` environment**:
   Repo → Settings → Environments → `production` → add secrets:
   - `FLY_API_TOKEN` — a deploy token for the `kamos` app
     (`flyctl tokens create deploy -a kamos`). Used by `deploy.yml`.
   - `CLOUDFLARE_API_TOKEN` — token scoped **Cloudflare Pages: Edit**. Used by
     `deploy-admin.yml`.
   - `CLOUDFLARE_ACCOUNT_ID` — the Cloudflare account ID. Used by
     `deploy-admin.yml`.

   The backend CD builds on Fly's remote builder (no external registry) and
   doesn't touch the DB (migrations are manual, §2). The admin CD builds
   `admin/` and uploads `dist/` to Pages with Wrangler.

## 2. Initial schema + secrets

The DB (`kamos-db`) sits on Fly's private network, so reach it through a
`flyctl proxy` tunnel from a workstation that has org access. `migrate.sh`
is idempotent (tracks applied files in `schema_migrations`), so it's safe
to re-run.

```sh
# Tunnel to the private DB, then apply migrations idempotently
flyctl proxy 15432:5432 -a kamos-db &
PSQL_URL='postgres://kamos:<pass>@127.0.0.1:15432/kamos?sslmode=disable' \
  scripts/migrate.sh migrations
psql "$PSQL_URL" -c '\d+ users' | head -40   # sanity

# Generate secrets
openssl rand -base64 48   # JWT_SECRET
openssl rand -base64 48   # CURSOR_SECRET
```

**Migrations are NOT applied by CD.** `FLY_API_TOKEN` is a deploy token
scoped to the `kamos` app and can't reach `kamos-db`, and the CI runner is
off the private network. Apply any new migration with the tunnel command
above **before merging** the schema change. Append-only + idempotent means
a deploy that lands before/after the migration is safe either way.

```sh
flyctl secrets set -a kamos \
  APP_ENV=production \
  APP_VERSION=initial \
  JWT_SECRET=... \
  CURSOR_SECRET=... \
  APP_BASE_URL=https://kamos.fly.dev \
  CORS_ALLOWED_ORIGINS=https://<project>.pages.dev,http://localhost:5174 \
  CACHE_BACKEND=redis \
  CACHE_REDIS_URL='rediss://...' \
  R2_ENDPOINT_URL='https://<account>.r2.cloudflarestorage.com' \
  R2_ACCESS_KEY_ID=... \
  R2_SECRET_ACCESS_KEY=... \
  R2_BUCKET=kamos-checkin-photos \
  R2_PUBLIC_BASE_URL=https://<bucket>.r2.dev \
  SENTRY_DSN='https://...@sentry.io/...' \
  OTEL_EXPORTER_OTLP_ENDPOINT='https://otlp-gateway-prod-ap-northeast-0.grafana.net' \
  OTEL_EXPORTER_OTLP_HEADERS='Authorization=Basic <base64-of-instanceID:apikey>'
```

`JWT_SECRET` and `CURSOR_SECRET` are both validated `≥ 32 bytes` at startup
(`backend/internal/config/config.go:208,231`). Skipping either or supplying a
short value fails the boot.

Leave `GOOGLE_CLIENT_ID`, `RESEND_API_KEY`, `EMAIL_FROM`, `FOURSQUARE_API_KEY`
empty for now — features degrade per [`DEPLOYMENT.md §9`](../../DEPLOYMENT.md#9-vendor-gated-features).

## 3. First deploy

```sh
gh workflow run deploy.yml --ref main
gh run watch
```

This builds the image on Fly's remote builder (pushed to `registry.fly.io`,
authed natively by `FLY_API_TOKEN` — no external registry), runs
`flyctl deploy --remote-only`, stages `APP_VERSION`, then runs a lightweight
liveness check (`/healthz` + `/v1/categories`) against `https://kamos.fly.dev`.
It does **not** run migrations (see §2) — apply those manually beforehand.

Subsequent deploys happen automatically on every merge to `main` once CI passes.

## 4. Verify observability ingest

- **Sentry** → `kamos-api` project → trigger any 4xx with `Authorization: Bearer bad`;
  event should appear within ~60s. (Routine 4xx are filtered; trigger a panic via
  an internal-only debug endpoint if one is wired, otherwise wait for natural traffic.)
- **Grafana** → stack `kamos` → Explore → Prometheus:
  `rate(http_requests_total{app="kamos"}[5m]) > 0`. Loki should show
  `service.name="kamos-api"`.
- **OnCall** schedule for the `kamos` team is populated (Grafana → Alerting → OnCall).
- The `APP_VERSION` tag on traces should equal the deployed git SHA.

## 5. Multi-replica cache path

`fly.toml` sets `min_machines_running = 2`. Verify cross-replica invalidation:

```sh
flyctl status -a kamos   # confirm 2 server machines + 1 worker

# Mutate via one machine, read via the other; cache should drop within ~500ms.
# (Exact mutation path is in the smoke script.)
```

If only 1 machine is running, increase: `flyctl scale count server=2 -a kamos`.

## 6. Rollback

```sh
flyctl releases list -a kamos
# Roll back to a previous Fly release (binary only — does NOT roll back
# migrations; KAMOS migrations are append-only by policy). Fly keeps the
# prior images in registry.fly.io, so this restores the exact artifact.
flyctl releases rollback <version> -a kamos
```

**Migrations are not rolled back.** If a deploy introduced a schema change
that the previous binary can't read, you must either (a) ship a forward-only
fix or (b) deploy a binary that tolerates both schemas. This is why migrations
are append-only ([`DEPLOYMENT.md §5`](../../DEPLOYMENT.md#5-database)).

Run the smoke script after a rollback:
```sh
API_BASE_URL=https://kamos.fly.dev scripts/smoke.sh
```

## 7. Worker liveness

```sh
flyctl logs -a kamos --instance <worker-machine-id>
```

Expected log lines (intervals per [`ARCHITECTURE.md §4`](../../ARCHITECTURE.md#4-multi-replica-topology)):
`username_hold`, `avg_rating_sweep`, `email_verification_cleanup`, `photo_orphan_cleanup`.

Every tick is wrapped in `pg_try_advisory_lock`, so a stray second worker
would log "lock not acquired, skipping" instead of double-running jobs.

## 8. Admin SPA

The admin SPA deploys via [`deploy-admin.yml`](../../.github/workflows/deploy-admin.yml):
on CI green (or `workflow_dispatch`) it builds `admin/` and uploads `dist/` to
the `kamos-admin` Pages project with Wrangler — gated on CI, same trigger model
as the backend `deploy.yml`. The build bakes in `admin/.env.production`
(`VITE_API_BASE_URL=https://kamos.fly.dev`).

The SPA ships `admin/public/_redirects` (`/* /index.html 200`) so client-side
TanStack Router deep-links resolve instead of 404ing on a hard refresh.

Before the first deploy, set the API's CORS allowlist to the (fixed) Pages origin:

```sh
flyctl secrets set -a kamos \
  CORS_ALLOWED_ORIGINS=https://kamos-admin.pages.dev,http://localhost:5174
```

First deploy / re-deploy:

```sh
gh workflow run deploy-admin.yml --ref main
gh run watch
```

Verify:

```sh
curl -I https://kamos-admin.pages.dev             # HTTP/2 200
curl -I https://kamos-admin.pages.dev/users/123   # 200 (index.html), not 404 — SPA fallback

# CSRF + cookie flow (the failure-prone surface):
# log in via the admin UI, confirm Set-Cookie has kamos_admin_csrf with
# SameSite=Strict, Secure, HttpOnly absent on the csrf cookie (so JS can read it),
# and that mutating requests echo X-CSRF-Token matching that cookie value.
```

If admin can't reach the API, verify `CORS_ALLOWED_ORIGINS` on Fly contains
the exact `https://kamos-admin.pages.dev` origin (no trailing slash).

## 9. Post-deploy housekeeping

- Tag the release: `git tag release-$(date +%Y%m%d-%H%M) && git push --tags`.
- Note the deploy in the team channel with commit SHA + smoke output.
- If anything failed: see [`incident-response.md`](./incident-response.md).
