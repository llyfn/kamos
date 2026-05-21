# Runbook — staging deploy (first cut)

A checklist for bringing the KAMOS stack up on a fresh staging environment. Assumes you can provision Postgres + Redis + a container runtime and have admin access to the Sentry org + Grafana stack listed in `~/.claude/memory/reference_observability_vendors.md`.

Cross-references:
- `DEPLOYMENT.md` — full env-var reference + flag-gated feature list.
- `ARCHITECTURE.md` — process topology (API + worker, cache, NOTIFY).

## 1. Provision

- [ ] Managed Postgres 18+ (RDS / Cloud SQL / Neon). PITR enabled. Single instance is fine for staging.
- [ ] Managed Redis 7+ (Elasticache / Upstash / similar). Single node is fine. Required only if you'll run more than one API replica.
- [ ] Cloudflare R2 bucket + scoped API token (or leave R2 vars empty to disable photo upload).
- [ ] DNS records for API + admin SPA + (optional) photo CDN.

## 2. Apply schema

```sh
# from repo root, with PSQL_URL pointed at staging
make db-migrate
```

Migrations are applied in lexical order; you'll see `→ 001_initial.sql ... → 013_comments_user_fk_cascade.sql`. Migrations are append-only — do not edit a file that was applied to staging.

Sanity:

```sh
psql "$PSQL_URL" -c '\d+ users' | head -40
```

## 3. Secrets + env

Set these on the API + worker processes. Anything marked optional can be left blank — the SDK never initializes and the feature degrades gracefully.

| Var | Required? | Notes |
|---|---|---|
| `APP_ENV` | required | `staging` |
| `DATABASE_URL` | required | `sslmode=require` |
| `JWT_SECRET` | required | ≥ 32 random bytes; `openssl rand -base64 48` |
| `CURSOR_SECRET` | required in prod | ≥ 32 random bytes; same shape as JWT_SECRET. In dev a default is used. |
| `JWT_TTL` / `REFRESH_TTL` | optional | defaults `15m` / `720h` |
| `APP_BASE_URL` | required | public origin used in email links |
| `GOOGLE_CLIENT_ID` | required for Google sign-in | server-side audience |
| `RESEND_API_KEY` + `EMAIL_FROM` | optional | empty → LogMailer (link printed at INFO) |
| `R2_ENDPOINT_URL` + `R2_ACCESS_KEY_ID` + `R2_SECRET_ACCESS_KEY` + `R2_BUCKET` + `R2_PUBLIC_BASE_URL` | optional | empty → uploads return `503 STORAGE_DISABLED` |
| `FOURSQUARE_API_KEY` | optional | empty → `/v1/venues/search` returns `503` |
| `CACHE_BACKEND` | optional | `inprocess` (default) or `redis` |
| `CACHE_REDIS_URL` | required if `CACHE_BACKEND=redis` | DSN |
| `CORS_ALLOWED_ORIGINS` | required for admin | comma-separated; admin SPA origin |
| `SENTRY_DSN` | optional | `kamos-api` project DSN |
| `OTEL_EXPORTER_OTLP_ENDPOINT` + `OTEL_EXPORTER_OTLP_HEADERS` | optional | Grafana Cloud OTLP gateway + auth header |
| `APP_VERSION` | optional | git SHA or release tag — surfaces on traces + Sentry |
| `RATE_LIMIT_DISABLED` | leave unset | only `1` for local stress |

Verify before deploy: `JWT_SECRET` and `CURSOR_SECRET` are both ≥ 32 bytes — startup fails otherwise.

## 4. Build + push images

`backend/Dockerfile` produces two binaries from the same image: `server` (HTTP listener) and `worker` (scheduler). Tag both with the same release SHA.

```sh
# from backend/
docker build -t kamos/api:$(git rev-parse --short HEAD) .
docker push kamos/api:$(git rev-parse --short HEAD)
```

Flutter ships via the App Store / Play Console; out of scope here. The admin SPA (`admin/`) ships to Cloudflare Pages (or any static host) — `npm run build` produces `admin/dist/`.

## 5. Deploy

- [ ] API replicas: deploy as `kamos/api:<sha> /server`. Start with N=2 to exercise the multi-replica cache path.
- [ ] Worker: deploy as `kamos/api:<sha> /worker`. Keep at single replica — the advisory-lock guard is a safety net, not a license to scale.
- [ ] Both processes need the same env block, minus the HTTP-listener vars on the worker.
- [ ] Health probes: API `/healthz` → 200; worker prints `worker started` on stdout.

## 6. Smoke

```sh
STAGING_URL=https://staging-api.example.com make smoke
```

`scripts/smoke.sh` runs 18 checks against the integrated public-collection + flat-comment + moderation slice. Expected: `=== Phase 6 FINAL smoke PASSED (18/18) ===`.

## 7. Verify observability ingest

- [ ] Sentry → kamos-api → fire a synthetic error: `curl -X POST https://staging-api.example.com/__test/panic` (only if the panic endpoint is wired; otherwise trigger via a bad request that the handler `recover` lifts to Sentry). Look for the event under "Issues" within ~60s.
- [ ] Grafana → stack `kamos` → Explore → Prometheus → `rate(http_requests_total[5m]) > 0` should return data. Loki should show `service.name="kamos-api"`.
- [ ] OnCall schedule for `kamos` team is populated (Grafana → Alerting → OnCall).

## 8. Post-deploy

- [ ] Tag the release in git: `git tag staging-$(date +%Y%m%d-%H%M)` + push.
- [ ] Note the deploy in `#kamos-deploys` (or equivalent) with commit SHA + smoke output.
- [ ] If anything failed: see `docs/runbooks/incident-response.md`.
