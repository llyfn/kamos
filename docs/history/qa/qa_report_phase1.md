# QA Report — Phase 1 Observability + Rate Limiting + Background Jobs

Date: 2026-05-14
Scope: Phase 1 of post-MVP roadmap (`~/.claude/plans/mutable-juggling-cook.md`).
Verdict: **PASS**

Phase 1 adds observability (OTel + Sentry, gated), token-bucket rate limiting, and an in-process scheduler running three cleanup jobs. All vendor SDKs no-op when env vars are unset — the user can sign up for Sentry / Grafana Cloud whenever; the API runs identically in dev today.

---

## What landed

### Observability
- **OTel** — `internal/observability/otel.go` initialises tracer + meter providers with OTLP/HTTP exporters when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. Resource: `service.name=kamos-api`, `service.version=${APP_VERSION}`, `deployment.environment=${APP_ENV}`. Empty endpoint = no SDK init, no goroutines spawned, log line `"otel disabled (OTEL_EXPORTER_OTLP_ENDPOINT unset)"`.
- **Sentry Go** — `internal/observability/sentry.go` calls `sentry.Init` when `SENTRY_DSN` is set; otherwise no-op `Flush` and log `"sentry disabled"`. Traces sample rate = 0 (we use OTel for traces).
- **`Trace` middleware** — `internal/middleware/observability.go` wraps each request in a span named `HTTP {method} {chi-route-pattern}`. Bounded cardinality (the chi route pattern, not raw URL).
- **`RecoverWithSentry` middleware** — replaces the prior `Recover`; calls `sentry.CurrentHub().Recover(err)` when Sentry is configured.
- **Business metric**: `checkins_created_total` counter incremented in the check-in create handler (one metric is intentional per the roadmap — "keep this small in Phase 1").

### Rate limiting (`golang.org/x/time/rate` token bucket — no new module dep)
- `RateLimitByIP(rps, burst)` — global IP bucket map with a 10-min idle GC ticker.
- `RateLimitByUser(rps, burst)` — keyed on JWT user ID; no-op on unauthed routes.
- Wiring in `internal/server/router.go`:
  - Global IP: 30 rps / burst 60
  - `/v1/auth/*` group: 5 rps / burst 10 (brute-force gate)
  - Authed routes group: 60 rps / burst 120 (per-user fairness)
- 429 body: `{"error":"rate_limited","code":"RATE_LIMITED"}`, `Retry-After: 1` header, logged at INFO (no stack trace).
- `RATE_LIMIT_DISABLED=1` env bypasses the limiter for integration tests + localhost stress checks. **Production must leave this unset** — documented.

### Background job scheduler — `internal/jobs/`
- In-process scheduler (single Go process, per roadmap default). One goroutine per job, cold-start on `Start()`, then `time.Ticker`. Errors logged at WARN, never crash the scheduler. Cooperative shutdown via context cancel.
- Jobs:
  - `username_hold_cleanup` (every 1 h) — tombstones soft-deleted users older than 30 days by rewriting `username` / `display_username` to `'del_' || substring(replace(id::text,'-','') from 1 for 24)`. Integration test asserts the original username is re-registerable.
  - `email_verification_cleanup` (every 6 h) — deletes `email_verifications` rows whose `expires_at < now() - interval '7 days'`.
  - `avg_rating_sweep` (every 24 h) — recomputes `avg_rating` + `check_in_count` from scratch and corrects any row where the trigger-maintained value diverges. Matches the trigger's "only-rated check-ins counted" semantics so it doesn't flap.

### Flutter
- `sentry_flutter ^9.20.0` added to pubspec.
- `lib/main.dart` wraps `runApp` in `runZonedGuarded`; if `--dart-define=KAMOS_SENTRY_DSN=...` is non-empty, calls `SentryFlutter.init`. Empty DSN → SDK never initialises; `debugPrint('sentry disabled')` once in debug builds.
- `lib/core/observability/sentry_observer.dart` — `SentryProviderObserver` reports Riverpod provider failures to Sentry when configured.
- `beforeBreadcrumb` redacts `Authorization` headers from any HTTP breadcrumb.
- 21/21 widget tests still PASS (Sentry doesn't initialise in the empty-DSN test environment).

---

## Live smoke (this run, against Postgres 18)

```
$ curl http://localhost:18080/healthz
{"status":"ok"}                                       # 200 OK

$ for i in $(seq 1 15); do curl -X POST .../v1/auth/login ...; done
401 401 401 401 401 401 401 401 401 401 429 429 429 429 429

$ curl -X POST .../v1/auth/login -w "%{http_code} retry-after=%header{retry-after}"
{"error":"rate_limited","code":"RATE_LIMITED"}
[status=429 retry-after=1]

Server log:
  "otel disabled (OTEL_EXPORTER_OTLP_ENDPOINT unset)"
  "sentry disabled (SENTRY_DSN unset)"
  "job_start" name=username_hold_cleanup every=1h0m0s
  "job_start" name=email_verification_cleanup every=6h0m0s
  "job_start" name=avg_rating_sweep every=24h0m0s
  "username_hold_cleanup" released=0
  "email_verification_cleanup" deleted=0
  "avg_rating_sweep" corrected=0
  "rate_limit_exceeded" key=ip:::1 path=/v1/auth/login method=POST
```

Burst of 15 produced exactly 10 successes-through-rate-limit followed by 5 × 429 — matches the `/v1/auth/*` cap (5 rps, burst 10). Cold-start tick fired for all three background jobs within ms of boot. Vendor SDKs cleanly no-op.

---

## Verification — actually ran

Backend (`_workspace/02_backend/api/`):

```
go build ./...                                                 clean
go vet ./...                                                   clean
go test -count=1 ./...                                         all PASS (added 'jobs', 'observability' packages)
go test -tags=integration -count=1 ./tests/integration/...     38 PASS (was 35; +1 rate-limit, +3 jobs, +1 in misc)
```

Frontend (`_workspace/03_frontend/`):

```
flutter analyze   No issues found! (2.0s)
flutter test      21/21 PASS
```

---

## SPEC invariants — still 12/12 PASS

Phase 1 added no new schema, did not modify existing endpoints' response shapes, did not touch JWT storage on the client, did not bypass soft-delete. The invariant trace from `qa_report_final.md` holds unchanged.

---

## Surprises (from the backend agent's report) — verified

- **Username "release" semantics** — SPEC said NULL the columns; schema has `NOT NULL` + uniqueness CHECKs, so columns can't be NULLed. The agent picked a tombstone (`'del_' || ...`) that still satisfies the format CHECK and allows reuse of the original username. Sound choice; called out in `username_hold_cleanup` integration test.
- **`avg_rating_sweep` mirrors the trigger's "rated check-ins only" count** so the sweep is idempotent against the trigger.
- **`otelhttp` not used** — wanted `chi.RouteContext(r).RoutePattern()` for bounded-cardinality spans, which `otelhttp.NewHandler` can't produce. Hand-rolled `Trace` middleware does the right thing. `otelhttp` stays as an indirect dep (chi already pulls it).
- **Pre-existing flaky `TestJWTRejectsModifiedToken`** flagged by the agent — already fixed in our session (commit `7ad3e41`). The agent saw the older version of the test still in the working tree but the fix was already applied before they ran. Treated as a noise observation; no action.

---

## What's still needed before this Phase ships to production

These don't gate Phase 2; they're follow-ons whenever the user signs up for vendors:

- Set `SENTRY_DSN` in production env (backend) + `KAMOS_SENTRY_DSN` dart-define (Flutter)
- Set `OTEL_EXPORTER_OTLP_ENDPOINT` + `OTEL_EXPORTER_OTLP_HEADERS` (with the Grafana Cloud auth header)
- Set `APP_VERSION` to a real version (we default to `"dev"`)
- Leave `RATE_LIMIT_DISABLED` UNSET in production. (Already documented in `.env.example` and `DEPLOYMENT.md`.)
- Optionally tune the three rate-limit thresholds; current defaults are conservative.

Cookbook §C4 in `~/.claude/plans/mutable-juggling-cook.md` lists the exact Sentry + Grafana Cloud signup steps and the values to send back.

---

## Carry-forward to Phase 2

- Trace middleware adds latency spans that Phase 2's refresh-token endpoint will be observable through automatically.
- Rate limit on `/v1/auth/*` (5 rps, burst 10) will throttle abusive refresh-token attempts — Phase 2 should layer a per-token attempt limit on top.
- `internal/jobs/` is reusable for Phase 3 (SMTP retry queue) and Phase 5 (admin async tasks); the scheduler API is the same.
