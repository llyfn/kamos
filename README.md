# KAMOS

A discovery and tracking platform for Japanese alcoholic beverages — Nihonshu, Shochu, and beyond.

Named after *醸す (kamosu)*, the Japanese verb for brewing and fermenting, KAMOS is to Japanese craft spirits what Untappd is to beer: a place to log what you've tried, discover what's next, and share the experience with people who care as much as you do.

## What you can do

**Discover** a curated database of beverages with brewery profiles, flavor profiles, regional origins, and brewing details — searchable and browseable across three languages.

**Check in** with a rating, tasting notes, flavor tags, price, and photos. Every check-in builds an aggregated flavor portrait for each beverage over time.

**Follow** other users and see their check-ins in a live feed. Profiles can be public or private.

**Collect** bottles into personal lists — the default Inventory and Wishlist, or any custom list you create.

## Tech stack

| Layer | Tech |
|---|---|
| Mobile | Flutter (iOS 13+, Android API 26+), Riverpod, `go_router`, `dio`, `flutter_secure_storage` |
| API | Go 1.26+, `chi` router, `pgx/v5` (no ORM), JWT (HS256), Google OAuth2 |
| Database | PostgreSQL 18+ with `pgcrypto` |
| Cache | Per-replica LRU (always); optional Redis 7+ (multi-replica L2) |
| Media | Cloudflare R2 (S3-compatible) for check-in photos |
| Venue tag | Foursquare Places API (optional) |
| Admin | React 19 + Vite 6 SPA (TypeScript) |
| Email | Resend (transactional) |
| Observability | Sentry + OTel + Prometheus + Grafana Cloud |
| Locales | `en`, `ja`, `ko` (full coverage) |

## Quick start

```sh
# Local dev — Postgres in docker, API + worker on host
make up                          # postgres + api in docker-compose
make db-migrate                  # apply migrations
make smoke                       # 18-step integration smoke (requires API up)

cd frontend && flutter run       # mobile app against http://localhost:8080
cd admin && npm install && npm run dev  # admin SPA against http://localhost:8080
```

Full env-var reference and staging/production deploy notes live in [DEPLOYMENT.md](DEPLOYMENT.md).

## Documentation

| Where | What |
|---|---|
| [SPEC.md](SPEC.md) | Product specification (MVP) — the source of truth for behaviour. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System overview, layer breakdowns, multi-replica topology, library choices. |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Environment variables, vendor flags, quick-start scripts, smoke verification. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Conventional Commits, verification matrix, coding conventions. |
| [docs/db/](docs/db/) | Schema, indexes, query patterns. |
| [docs/runbooks/](docs/runbooks/) | Staging deploy, secret rotation, incident response. |
| [docs/history/](docs/history/) | Per-phase QA reports + code review artifacts (post-MVP). |
| [`.claude/`](.claude/) | Claude Code agent harness — orchestrator skills + specialist agents. |

## Localization

Full support for English, 日本語, and 한국어. Category strings are character-exact per SPEC §2.1:

| Locale | Sake | Shochu | Liqueur |
|---|---|---|---|
| `en` | `Nihonshu (Sake)` | `Shochu` | `Liqueur` |
| `ja` | `日本酒` | `焼酎` | `リキュール` |
| `ko` | `니혼슈 (사케)` | `쇼츄` | `리큐어` |

## Repository layout

```
backend/        Go REST API + worker (chi + pgx/v5)
frontend/       Flutter mobile app
admin/          React admin web client
migrations/     PostgreSQL migrations (append-only)
design/         Design system: tokens, brand doc, UI kit, previews
docs/           Long-form docs (db/, history/, runbooks/)
scripts/        Operational scripts (smoke, e2e, token codegen)
```

## License

TBD. Internal until further notice.

---

→ [Specification](SPEC.md) · [Architecture](ARCHITECTURE.md) · [Deployment](DEPLOYMENT.md) · [Contributing](CONTRIBUTING.md)
