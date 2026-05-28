# Runbook — incident response

What to do when an alert fires or an end-user reports something visibly broken. Optimized for the on-call's first 15 minutes; not a substitute for the postmortem.

## On-call

The active rotation is in Grafana OnCall, stack `kamos`. Schedule + escalation chain are owned there.

```sh
# get the current on-call user via the Grafana MCP, or directly:
#   Grafana → OnCall → Schedules → kamos-primary
```

## Triage flow

1. **Confirm the signal.** Is this in Sentry (`kamos-api` or `kamos-app` project)? In Grafana alerting? In a user report? All three? Match the timestamp.
2. **Classify severity.**
   - **SEV-1** — auth broken for all users / DB unreachable / data corruption suspected. Page everyone.
   - **SEV-2** — feature-level outage (uploads down, search down, etc.) or sustained 5xx surge. Page primary on-call.
   - **SEV-3** — degraded latency or a single user complaint. File a ticket; investigate next business day.
3. **Form a one-sentence hypothesis.** "Schema migration N didn't apply on replica 2." "R2 token rotated and the new value isn't on the worker." "Cache invalidation NOTIFY is missing." Write it in the incident channel before you start poking.
4. **Mitigate, then root-cause.** Stopping the bleeding first is the right move; restoring before understanding is fine.

## Quick mitigations

These are the ones that have a low blast radius and a high probability of helping:

| Symptom | Mitigation |
|---|---|
| Sustained 429s from one user | Verify `RATE_LIMIT_DISABLED=0` (the production default). If a user is abusive, ban via `POST /v1/admin/users/{id}/suspend`. |
| Stale taxonomy / category names after a migration | Force cache flush: `psql "$DATABASE_URL" -c "SELECT pg_notify('kamos_cache_invalidate', 'taxonomy');"` — every API replica drops its `taxonomy` cache key on the next tick. |
| Stale beverage detail after an admin moderation action | Same channel, key `beverage:<id>` — `SELECT pg_notify('kamos_cache_invalidate', 'beverage:00000000-0000-...');`. |
| API replicas pegged | Scale out: bump replica count. Cache is per-replica L1 + optional shared L2, so adding replicas just adds capacity; no warm-up cost beyond the LRU fill. |
| Worker silently not running | Check `pg_try_advisory_lock` rows: `SELECT pid, query FROM pg_stat_activity WHERE query LIKE '%pg_try_advisory_lock%';`. If empty, the worker isn't connecting; check `DATABASE_URL` on the worker pod. |
| Auth surge of 401s | Did `JWT_SECRET` just rotate? See `secret-rotation.md`. If not, check the soft-deleted-user cache for a poisoned entry. |
| Photo upload returning 503 | `R2_*` env unset or token expired — see `DEPLOYMENT.md` §3. |
| Email verification not arriving | Check `RESEND_API_KEY` is set; check Resend dashboard for bounces / rate limits. Empty key falls back to LogMailer (link printed to stdout). |

## When in doubt

- **Roll back.** The previous container image is one `kubectl rollout undo` away. No bonus points for diagnosing on a live fire.
- **Read-only DB session.** `psql "$DATABASE_URL" -c "SELECT pg_backend_pid();"` then `BEGIN; SET TRANSACTION READ ONLY;` — investigate without risk of writes.
- **Page a second person.** Two heads on a SEV-1 is always right.

## Postmortem template

File at `docs/history/incidents/YYYYMMDD-<slug>.md` within 48 hours.

```md
# Incident YYYY-MM-DD — <one-line summary>

**Severity:** SEV-1 / SEV-2 / SEV-3
**Detected at:** <UTC timestamp> via <signal source>
**Resolved at:** <UTC timestamp>
**Duration:** <minutes>

## Timeline
- HH:MM — first signal.
- HH:MM — on-call paged.
- HH:MM — hypothesis: <…>.
- HH:MM — mitigation: <…>.
- HH:MM — confirmed resolved.

## Impact
- <which users / how many / what they saw>

## Root cause
<the actual bug or operational mistake, not "human error">

## Contributing factors
- <what made it possible / what made detection slow>

## Action items
- [ ] <follow-up, owner, due date>
- [ ] <follow-up, owner, due date>

## What went well
- <signal landed in Sentry within 60s of the regression>
- <runbook covered the mitigation>

## What went poorly
- <we missed it for 20 minutes because the alert was muted>
```

Blameless. Action items get filed as issues with owners + dates within a week.
