---
name: deploy-runbook
description: "KAMOS deploy + ops runbook skill. Use this to apply schema migrations to prod Postgres, rotate JWT/CURSOR secrets, redeploy the Fly app, redeploy the admin SPA on Cloudflare Pages, run staging smoke, and follow the incident-response playbook. Invoke whenever deploy, migrate apply, secret rotation, smoke, or runbook is requested. Triggers: deploy, release, migration apply, secret rotation, smoke, runbook, flyctl, Pages."
recommended_model: opus
---

# Deploy Runbook Skill

Encodes the operational runbooks at `docs/runbooks/` (deploy.md, secret-rotation.md, incident-response.md) so the orchestrator can execute them with the right preconditions, the right tools, and the right confirmations.

## When to use this skill

- Apply a migration to prod Postgres (migrations are not in CD; manual is the SPEC, per `project_prod_migration_lag` memory)
- Rotate `JWT_SECRET` or `CURSOR_SECRET`
- Deploy a hotfix to the Fly app outside of merge-to-main
- Deploy the admin SPA to Cloudflare Pages
- Run staging smoke (`make smoke` against `kamos.fly.dev`)
- Walk an incident-response checklist

## When NOT to use this skill

- Routine merge-to-main deploys — those auto-deploy via `.github/workflows/deploy.yml`
- Schema changes that have not been reviewed by `db-architect` — invoke `db-schema` first
- Migrations that touch existing data without an additive shape — escalate per `db-schema` skill's data-migration policy

## Source of truth

Always read the runbook before acting:

- `docs/runbooks/deploy.md` — provisioning + ongoing deploy + migration apply
- `docs/runbooks/secret-rotation.md` — `JWT_SECRET` + `CURSOR_SECRET` cycling
- `docs/runbooks/incident-response.md` — paging, rollback, root-cause flow
- `DEPLOYMENT.md` — env vars + flag matrix
- `backend/fly.toml` — Fly app definition (two processes, NRT)
- `.github/workflows/deploy.yml` and `.github/workflows/deploy-admin.yml`

If the runbook says "Section §N", read section §N before each step.

## Conventions

- **Confirm destructive ops with the user.** `flyctl deploy`, `flyctl secrets set/unset`, `migrate.sh apply`, `flyctl ssh console -C "psql ..."` are all confirm-first by default. The `feedback_prod_db_access_authorized` memory allows standing access for inspection/migrations, but every destructive command still asks.
- **Migrations are append-only.** Never edit a deployed migration. If something is wrong, ship a new migration that fixes it.
- **Verify prod schema_migrations after every migration.** Per the `project_prod_migration_lag` memory — production has drifted from main twice when the manual step was missed.
- **Smoke after every deploy.** Use `make smoke` (or hit `https://kamos.fly.dev/healthz` + a non-trivial endpoint) before declaring success.

## Workflow

For a migration apply to prod:

1. Confirm with the user which migration ID(s) are being applied.
2. Read `docs/runbooks/deploy.md` §2 (or the named section).
3. Open a `flyctl proxy` tunnel to `kamos-db`.
4. Run `scripts/migrate.sh apply` against the proxied URL.
5. Verify `select max(version) from schema_migrations;` matches the head.
6. Run `make smoke` against `kamos.fly.dev`.
7. Write a one-paragraph result note (date, migration ID, smoke status).

For a Fly deploy:

1. Confirm the source commit (`git log -1`).
2. `flyctl deploy --remote-only` (or `--config backend/fly.toml`).
3. Wait for the printed version + health check.
4. `make smoke`.

For a secret rotation:

1. Read `docs/runbooks/secret-rotation.md`.
2. Generate the new secret per the runbook's instructions (length, charset).
3. `flyctl secrets set NEW_SECRET=... --stage` for staged rollover.
4. Walk the dual-validity window per the runbook (overlap before cutover).
5. `flyctl secrets unset OLD_SECRET` once the window closes.

## Communication

When invoked standalone, write a result note to `docs/history/ops/<YYYY-MM-DD>_<action>.md`. When invoked inside an orchestrator (rare — most deploy work is standalone), emit `[[protocol:BUILD-013]]` TaskUpdate after each step.

## Decision discipline

- A runbook step that does not match current state (e.g., the runbook says `kamos.fly.dev/healthz` but the app is in NRT and unreachable): pause, diagnose, do not improvise. Update the runbook in a follow-up if the gap is permanent.
- A `flyctl` command that errors mid-step: do not retry blindly. Read the error, find the root cause. If unrecoverable, escalate.
- A smoke failure after deploy: rollback per `docs/runbooks/incident-response.md`; do not push another deploy hoping to fix forward without diagnosis.

## What this skill is not

- **Not the CD pipeline.** Auto-deploys on green CI happen via `.github/workflows/deploy.yml`. Use this skill for the manual paths (migrations, hotfixes, rotations).
- **Not infrastructure provisioning.** One-time setup is in `docs/runbooks/deploy.md §1` and is documented for humans; this skill does not run greenfield provisioning.
- **Not a schema author.** This skill applies migrations the `db-schema` skill produced; it does not author them.
