---
id: invariant:rating-scale
spec: SPEC.md §4.2
severity_on_violation: BLOCKER
layers: [schema, api, openapi, flutter]
owners: [db-architect, backend-engineer, flutter-engineer, qa-inspector]
---

# Rating scale

## Rule

Rating is `0.5–5.0` in `0.25` steps (19 levels). Optional per check-in.

- **Storage:** PostgreSQL `NUMERIC(3,2)` with `CHECK (rating IS NULL OR (rating BETWEEN 0.5 AND 5.0 AND (rating * 4) = floor(rating * 4)))`.
- **Wire:** JSON number (never string), preserves two decimals.
- **Server validation:** nullable; if present, range + step check before insert.
- **Client UI:** 0.25-step star widget — never 0.5 widget, never integer.

## Check

```bash
# Schema constraint
grep -rn "NUMERIC(3,2)\|rating.*BETWEEN" migrations/

# Go validator
grep -rn "Rating\|rating" backend/internal/domain/ backend/internal/handlers/checkins*.go

# OpenAPI: type number, multipleOf 0.25
grep -nA 3 "rating:" backend/openapi.yaml

# Flutter widget granularity
grep -rn "0.25\|0\\.25" frontend/lib/shared/widgets/ frontend/lib/features/checkin/
```

## Where each layer enforces it

- **Schema** — `migrations/NNN_*.sql` declares `rating NUMERIC(3,2)` + CHECK constraint.
- **Repository** — pgx scans into `float64`/`*float64`; never int.
- **Domain validator** — `backend/internal/domain/checkins.go` validates range + step before insert.
- **OpenAPI** — `format: float, multipleOf: 0.25, minimum: 0.5, maximum: 5.0, nullable: true`.
- **Flutter model** — `double?`; star widget renders 19 levels in 0.25 increments.

## Related

- [[invariant:checkin-caps]] — rating sits alongside review-text + photo caps on check-in submit
