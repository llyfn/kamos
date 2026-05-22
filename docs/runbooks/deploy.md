# Runbook — deploy (Fly.io)

Concrete checklist for bringing the KAMOS hosted environment up on Fly.io
(Tokyo / NRT) and operating the auto-deploy pipeline. There is currently
one hosted environment; a dev/prod split is deferred until reliability
requirements warrant it.

Cross-references:
- [`DEPLOYMENT.md`](../../DEPLOYMENT.md) — env-var reference + feature-flag list.
- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — process topology, multi-replica cache invalidation.
- [`fly.toml`](../../fly.toml) — committed app definition (two processes, NRT).
- [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml) — the CD pipeline.

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
   - Optional: custom domain `photos.kamos.app` → `R2_PUBLIC_BASE_URL`

4. **Cloudflare Pages** project `kamos-admin`:
   - Connect to the GitHub repo, build dir `admin/`, build command `npm run build`,
     output dir `dist`
   - Env vars (dashboard): `VITE_API_BASE_URL=https://api.kamos.app`
   - Custom domain `admin.kamos.app`

5. **DNS**:
   - `api.kamos.app` → Fly app (TLS issued by Fly): `flyctl certs add api.kamos.app -a kamos`
   - `admin.kamos.app` → Cloudflare Pages (TLS auto)

6. **Sentry + Grafana Cloud** — already provisioned (see
   [`reference_observability_vendors.md`](../../.claude/memory/reference_observability_vendors.md)).
   Get the `kamos-api` DSN and OTLP gateway URL + Basic auth header.

7. **GitHub `production` environment**:
   Repo → Settings → Environments → `production` → add secrets:
   - `FLY_API_TOKEN` (from `flyctl auth token`)
   - `DATABASE_URL` — admin DSN with `sslmode=require`
   - `GITHUB_TOKEN` already auto-provided for GHCR

## 2. Initial schema + secrets

```sh
# Migrate the freshly-attached Postgres
PSQL_URL='postgres://...?sslmode=require' make db-migrate
psql "$PSQL_URL" -c '\d+ users' | head -40   # sanity

# Generate secrets
openssl rand -base64 48   # JWT_SECRET
openssl rand -base64 48   # CURSOR_SECRET
```

```sh
flyctl secrets set -a kamos \
  APP_ENV=production \
  APP_VERSION=initial \
  JWT_SECRET=... \
  CURSOR_SECRET=... \
  APP_BASE_URL=https://api.kamos.app \
  CORS_ALLOWED_ORIGINS=https://admin.kamos.app \
  CACHE_BACKEND=redis \
  CACHE_REDIS_URL='rediss://...' \
  R2_ENDPOINT_URL='https://<account>.r2.cloudflarestorage.com' \
  R2_ACCESS_KEY_ID=... \
  R2_SECRET_ACCESS_KEY=... \
  R2_BUCKET=kamos-checkin-photos \
  R2_PUBLIC_BASE_URL=https://photos.kamos.app \
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

This pushes a fresh image to `ghcr.io/<owner>/kamos-api:<sha>`, applies
migrations, calls `flyctl deploy --image`, then runs `scripts/smoke.sh`
against `https://api.kamos.app`. Expected smoke output:
`=== Phase 6 FINAL smoke PASSED (18/18) ===`.

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
# Roll the deployment back to a previous Fly release (binary only — does
# NOT roll back migrations; KAMOS migrations are append-only by policy).
flyctl releases rollback <version> -a kamos

# Or re-deploy a specific GHCR tag:
flyctl deploy -a kamos \
  --image ghcr.io/<owner>/kamos-api:<previous-sha> \
  --strategy rolling
```

**Migrations are not rolled back.** If a deploy introduced a schema change
that the previous binary can't read, you must either (a) ship a forward-only
fix or (b) deploy a binary that tolerates both schemas. This is why migrations
are append-only ([`DEPLOYMENT.md §5`](../../DEPLOYMENT.md#5-database)).

Run the smoke script after a rollback:
```sh
API_BASE_URL=https://api.kamos.app scripts/smoke.sh
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

Cloudflare Pages auto-deploys on every push to `main`. Verify:

```sh
curl -I https://admin.kamos.app
# Should serve from Cloudflare; HTTP/2 200.

# CSRF + cookie flow (the failure-prone surface):
# log in via the admin UI, confirm Set-Cookie has kamos_admin_csrf with
# SameSite=Strict, Secure, HttpOnly absent on the csrf cookie (so JS can read it),
# and that mutating requests echo X-CSRF-Token matching that cookie value.
```

If admin can't reach the API, verify `CORS_ALLOWED_ORIGINS` on Fly contains
`https://admin.kamos.app` exactly (no trailing slash).

## 9. Post-deploy housekeeping

- Tag the release: `git tag release-$(date +%Y%m%d-%H%M) && git push --tags`.
- Note the deploy in the team channel with commit SHA + smoke output.
- If anything failed: see [`incident-response.md`](./incident-response.md).
