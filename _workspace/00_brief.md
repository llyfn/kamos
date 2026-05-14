# KAMOS — Build Brief

> Orchestrator: `kamos-build`. Sources: `README.md`, `SPEC.md`, existing draft in `_workspace/01_design/`.
> This brief is the orienting document for every agent spawned in this build.

---

## 1. Product (1-paragraph anchor)

KAMOS — *Untappd for Japanese craft spirits.* Mobile-first (Flutter, iOS + Android) discovery and tracking platform for **Nihonshu (日本酒)**, **Shochu (焼酎)**, and **Liqueur (リキュール)**. Users discover from an admin-curated catalog, **check in** with rating / review / tags / photos / price, **follow** other users, view a reverse-chronological feed, and curate **collections** (default `Inventory` + `Wishlist`). Full first-class i18n in **en / ja / ko**.

## 2. Tech stack (decided)

| Layer | Choice |
|---|---|
| Mobile | Flutter (stable), Riverpod, `go_router`, `dio`, `flutter_secure_storage`, ARB i18n |
| Backend | Go 1.24+, `chi` router, `pgx/v5` directly (no ORM), JWT (HS256), Google OAuth2 |
| Database | PostgreSQL 15+, `pgcrypto` for `gen_random_uuid()` |
| Min platforms | iOS 13+, Android API 26+ |

## 3. Workspace layout

```
_workspace/
  00_brief.md                          ← this file
  01_design/                           ← designer (extends existing draft)
    README.md                          brand + content + visual rules
    colors_and_type.css                tokens — single source of truth
    assets/                            logos
    preview/*.html                     one HTML per primitive
    ui_kits/mobile/                    runnable JSX kit (5-tab demo + deep screens)
  02_backend/
    db/                                db-architect
      schema.md
      migrations/00X_*.sql
      indexes.md
      query_patterns.md
    api/                               backend-engineer
      cmd/, internal/                  Go source
      openapi.yaml                     OpenAPI 3.1 — owned by backend-engineer
      .env.example
      README_backend.md
  03_frontend/                         flutter-engineer
    pubspec.yaml, lib/, l10n/, ios/, android/
    README_flutter.md
  04_qa/                               qa-inspector
    qa_report_{module|feature}.md      incremental
    qa_report_final.md
```

`backend/` and `frontend/` exist at the repo root but are **empty placeholders**. Production paths during the build are under `_workspace/`. Promotion to root happens only after final QA passes.

## 4. Handoff routing (reconciliation)

The agent definitions and the orchestrator skill differ on intermediate handoff files. The **agent definitions are authoritative**:

- The designer does **not** produce `api_contracts.md` / `screen_specs.md` / `design_tokens.md` as separate Markdown files. Instead:
  - **Tokens** → `_workspace/01_design/colors_and_type.css` (the only place hex / sp / dp / ms literals live)
  - **Screen specs** → `_workspace/01_design/ui_kits/mobile/components/*.jsx` + `index.html`
  - **Brand / voice / visual rules** → `_workspace/01_design/README.md`
- The **API contract is owned by `backend-engineer`** (`_workspace/02_backend/api/openapi.yaml`). It is the single canonical contract for Flutter consumption.
- `db-architect` derives entity needs from **`SPEC.md`** (which is exhaustive on fields, ranges, and invariants) plus the JSX screens for any UI-driven shapes.
- `flutter-engineer` reads tokens from `colors_and_type.css`, screens from the JSX kit, and data shapes from `openapi.yaml`.

If an agent cannot find a downstream file they expect, they should consult the source list above before stalling.

## 5. Feature scope (MVP) — what to build

| Domain | Behavior (from SPEC) |
|---|---|
| **Auth** | Email+password (bcrypt, ≥8 chars), email verification (24h link expiry), Google OAuth2 (auto-create on first login). JWT issued by API, stored in `flutter_secure_storage` on device. |
| **User profile** | Username (3–30 alnum + `_`, **case-insensitive, stored lowercase**, displayed as entered). Display name (≤50). Avatar (uploaded or Google photo). Bio (≤200). Locale (`en`/`ja`/`ko`, defaults to device). Stats: check-ins, unique beverages, followers, following. Account actions: change display name/bio/avatar/email/password; soft-delete with 30-day username hold. |
| **Beverage catalog** | Admin-curated. Beverage: i18n name (en+ja required; ko optional with `ko→en` fallback). Brewery relation. Category ∈ {Nihonshu, Shochu, Liqueur} (exact strings per locale). Subcategory (free text from predefined list). ABV (decimal). Polishing ratio (Nihonshu only). Flavor profile (multi-tag). Prefecture/region. Description (i18n). Label image URL. Average rating (running). |
| **Brewery** | i18n name (en+ja required). Prefecture/region. Founded year (optional). Website (optional). Description (i18n, optional). |
| **Check-in** | Beverage (req). Rating (optional, **0.5–5.0 in 0.5 steps**). Review text (≤500). Flavor tags (multi). Photos (≤4). Price (numeric + currency, per-serving/per-bottle toggle). Purchase type ∈ {on-premise, retail, gift, other}. Serving style ∈ {glass, carafe, bottle, can, other}. Editable except beverage. Soft-delete (`deleted_at`). Multiple check-ins per beverage allowed. |
| **Social** | Follow system with **public** (default, instant follow) / **private** (approval required) modes. Pending follow requests in an in-app inbox. Toasts: single-tap reaction on a check-in (one per user per check-in, toggleable). Toast count on each check-in. Private-user toasts gated to approved followers. |
| **Feed** | Reverse-chronological (no algorithmic ranking), 20/page **cursor pagination**. Item content: avatar+username, beverage+brewery, rating, review (truncated @140 chars), first photo, flavor tags, elapsed time. User's own check-ins excluded from own feed. Private users only shown to approved followers. |
| **Collection** | Default `Inventory` + `Wishlist` on signup (renameable, deletable). User-created lists (name ≤50). Beverage can be in multiple collections. Each entry has optional note (≤200). No quantity tracking. Visibility: **owner-only** in MVP. |
| **Discovery** | Full-text search by beverage / brewery name across all locales. Browse by category. Browse by brewery (brewery detail page). Beverage detail with avg rating, aggregated flavor profile, recent check-ins. |
| **i18n** | en / ja / ko. User locale preference (defaults to device). Beverage name fallback `ko→en` / `ja→en`. User-generated content stored as-entered, no translation. Category strings non-negotiable per §6. |

## 6. SPEC invariants — non-negotiable, cross-checked by qa-inspector

These are **blockers** if violated.

### 6.1 Category terminology (exact strings, no abbreviation/substitution)

| Locale | Sake | Shochu | Liqueur |
|---|---|---|---|
| `en` | `Nihonshu (Sake)` | `Shochu` | `Liqueur` |
| `ja` | `日本酒` | `焼酎` | `リキュール` |
| `ko` | `니혼슈 (사케)` | `쇼츄` | `리큐어` |

### 6.2 Rating
- Range: **0.5 to 5.0** in 0.5 steps (10 discrete levels). Optional per check-in.
- DB: `NUMERIC(3,1)` with `CHECK (rating IS NULL OR (rating >= 0.5 AND rating <= 5.0 AND (rating * 10)::int % 5 = 0))`.
- Go: `float64`/`*float64`. Dart: `double`/`double?`. Never integer.
- API: numeric, never a string.

### 6.3 Username
- 3–30 chars, `^[A-Za-z0-9_]+$`.
- **Case-insensitive**: stored lowercase. Original casing preserved in a separate `display_username` field for display.
- Soft-delete: 30-day hold on the lowercase value before release.

### 6.4 Soft-delete
- `users.deleted_at TIMESTAMPTZ NULL` with 30-day username hold (enforced at username uniqueness check or via partial index).
- `check_ins.deleted_at TIMESTAMPTZ NULL` — excluded from feed and counts.
- `collections.deleted_at TIMESTAMPTZ NULL` — soft-delete with cascade to entries.

### 6.5 i18n fallback (beverage / brewery names)
- `ko` missing → display `en`.
- `ja` missing → display `en`. (SPEC says ja is required, but the rule is documented to never display empty.)
- Never display empty strings or wrong-locale glyphs.

### 6.6 Pagination
- **Cursor only, never offset.** Response shape: `{ "items": [...], "next_cursor": "<opaque|null>", "has_more": <bool> }`.
- Feed page size = 20. Other lists may differ; document each.

### 6.7 Check-in caps
- Review text ≤ 500 chars (DB CHECK + Go validation + Flutter input limit).
- Photos ≤ 4 per check-in (DB CHECK on a count or row limit + server enforcement + Flutter UI limit).

### 6.8 Default collections
- On user creation, insert two collections named `Inventory` and `Wishlist` for that user. Per `db-architect.md`, this is application-layer (so localization can override the display name later if desired). These are renameable and deletable, not special.

### 6.9 JWT storage on device
- **`flutter_secure_storage` only.** Never `SharedPreferences`. This is a security blocker.

### 6.10 OAuth client secret
- Google OAuth client **secret** lives server-side. Only the client **ID** ships to the Flutter app.

## 7. Out of scope (MVP) — explicit list

Per `SPEC §9`. If any of these is implied by a feature request, halt and confirm scope:

- Venue / location on check-ins (Google Places integration deferred)
- Threaded comments on check-ins (toasts are in; comments are not)
- Push notifications (in-app follow-request inbox only)
- Public collections (owner-only in MVP)
- User-submitted beverage additions (admin-curated only)
- Personalized recommendations / editorial picks
- Web client
- Apple Sign-In
- Beverage scanning (barcode / label recognition)
- Export / data portability
- Blocking users

## 8. Existing artifacts inventory (Phase 0 finding)

The design draft at `_workspace/01_design/` is substantial and not greenfield. The designer must **review and extend**, not replace.

| Artifact | Path | State |
|---|---|---|
| Brand README | `_workspace/01_design/README.md` | Complete — voice & tone, visual foundations, iconography, file index, open questions |
| Design tokens | `_workspace/01_design/colors_and_type.css` | Complete — Japanese-blue palette, type scale, spacing, radii, shadows, motion, semantic tokens |
| Logo assets | `_workspace/01_design/assets/` | `logo.png`, `logo_mono.png`, `logo_white.png`, `logo_mark.png`, `logo_original.png` |
| Mobile UI kit | `_workspace/01_design/ui_kits/mobile/` | `index.html` + `ios-frame.jsx` + 8 component files (Primitives, Shell, Feed/Search/Beverage/CheckIn/ProfileLists screens + data) |
| Primitive previews | `_workspace/01_design/preview/*.html` | 16 standalone HTML previews (colors, type, spacing, radii, elevation, buttons, chips, cards, icons, inputs, logo) |
| Screenshot | `_workspace/01_design/screenshots/uikit.png` | One reference image of the UI kit |

**Designer's task:** review these, identify gaps against the SPEC (notably auth screens, follow request inbox, collection picker, brewery detail, edit-profile, settings, soft-delete confirmation flows, all three locales rendered in the JSX kit), and extend the same files. Open questions in the existing README (Shippori Mincho display font · Phosphor icon set · Koh accent retention) carry forward.

## 9. Phase plan

1. **Phase 0** — Brief (this file). ✓
2. **Phase 1** — Designer extends the existing system. Single agent: `designer`.
3. **Phase 2** — `db-architect` + `backend-engineer` in parallel; `qa-inspector` runs incrementally per module. Team: `kamos-backend-team`.
4. **Phase 3** — `flutter-engineer` builds the app; `qa-inspector` runs incrementally per feature. Team: `kamos-frontend-team`.
5. **Phase 4** — Final cross-layer QA. Single agent: `qa-inspector`.
6. **Phase 5** — Deployment prep (DEPLOYMENT.md, docker-compose.yml, Makefile) after final QA PASS.

## 10. Communication rules (recap)

- `db-architect` → `backend-engineer`: "DB ready"
- `backend-engineer` → `flutter-engineer`: "OpenAPI ready at `_workspace/02_backend/api/openapi.yaml`"
- `backend-engineer` → `qa-inspector`: "Backend module {name} complete"
- `flutter-engineer` → `qa-inspector`: "Flutter feature {name} complete"
- `qa-inspector` → responsible agent: BLOCKER / MAJOR fix request with file:line
- All agents: `TaskUpdate` after each meaningful state change
- No structured-JSON status pings; use `TaskUpdate` for status.
