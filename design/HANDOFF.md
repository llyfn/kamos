# Design → Downstream Handoff

Single bridging document for `db-architect`, `backend-engineer`, and `flutter-engineer`. Not a screen-spec rewrite — this is an index pointing each agent at the canonical sources.

## Canonical sources
- **SPEC of record** — `SPEC.md` (product spec)
- **Brief** — `docs/history/00_brief.md` (sections 4, 6, 8 are load-bearing)
- **Design tokens** — `design/colors_and_type.css` (single source of truth for hex / sp / dp / ms / radii / shadows / motion)
- **Brand + voice + visual rules** — `design/README.md`
- **Screens (runnable)** — `design/ui_kits/mobile/index.html` + `components/*.jsx`
- **Primitive previews** — `design/preview/*.html`

The API contract (`backend/openapi.yaml`) is owned by `backend-engineer`. This document does not define it — it lists the data shapes each screen needs so the contract can be written from SPEC.md plus this index.

## Feature add-on specs

- **Notifications + nav rewrite (SPEC §5.4)** — `design/notifications_ux.md`. Defines the unified Notifications screen (5 row types, unread tint, Mark all read, inline Approve/Decline on `follow_request` rows), the bottom-nav rewrite (Feed · Lists · Discover · Notifications · Me, no center FAB), the Koh-dot unread indicator on the Notifications tab, mark-on-scroll behavior, soft-deleted actor rendering, and the EN ARB key list. Flutter engineer must read this end-to-end before touching `frontend/lib/features/notifications/` or `frontend/lib/app/router.dart`. Supersedes the `InboxScreen.jsx` flow.
- **Profile / social UX expansion** — `design/profile_social_ux_expansion.md`.

## Screen → file map

| User-facing surface | JSX file |
|---|---|
| Auth: sign in, create account, forgot password, verify email, Google OAuth | `components/AuthScreen.jsx` |
| Feed (followed users' check-ins, cursor-paginated, page size 20) | `components/FeedScreen.jsx` |
| Notifications (all 5 types, replaces old Inbox) | `components/NotificationsScreen.jsx` |
| [legacy] Follow-request inbox | `components/InboxScreen.jsx` — superseded by NotificationsScreen; kept for `/inbox` → `/notifications` redirect milestone |
| Discover (formerly Search; full-text + category filter chips) | `components/SearchScreen.jsx` |
| Beverage detail (catalog, avg rating, flavor aggregate, recent check-ins) | `components/BeverageScreen.jsx` |
| Producer detail (i18n name, region, founded, website, beverage list) | `components/ProducerScreen.jsx` |
| Check-in (rating, review, tags, photos, price, purchase type) | `components/CheckInScreen.jsx` |
| Profile (Me): stats, locale toggle, recent check-ins | `components/ProfileLists.jsx::ProfileScreen` |
| Edit profile: display name, bio, avatar | `components/EditProfileScreen.jsx` |
| Settings: email, password, privacy, locale, soft-delete | `components/SettingsScreen.jsx` |
| Collections list (default `Inventory` + `Wishlist` + custom) | `components/ProfileLists.jsx::ListsScreen` |
| Collection detail (contents, rename, delete) | `components/CollectionDetailScreen.jsx` |
| Collection picker sheet (multi-select with inline create) | `components/CollectionPickerSheet.jsx` |
| Empty / loading / error patterns | `components/Primitives.jsx` (EmptyState, LoadingState, ErrorState, PagingFooter, Badge) |

## Data shapes each screen needs

`backend-engineer` should resolve these against SPEC.md to write `openapi.yaml`. Names use `snake_case` because that is the API convention in `openapi.yaml`.

- **Auth** — `POST /auth/register`, `POST /auth/login`, `POST /auth/forgot`, `GET /auth/verify?token=...`, `POST /auth/oauth/google`. Issue JWT (HS256). Response includes `{ user, access_token }`. `flutter_secure_storage` on device (SPEC §6.9).
- **User (me)** — `GET /me`, `PATCH /me` (display_name, bio, avatar_url, locale, privacy). Body shape matches `data.jsx::ME`: `{ id, handle, display_username, display_name, email, email_verified, bio, avatar_url, locale, privacy, stats: { checkins, unique, followers, following } }`. Note both `handle` (lowercase) and `display_username` (case preserved) per SPEC §6.3.
- **User actions** — `POST /me/email`, `POST /me/password`, `DELETE /me` (soft-delete, 30-day username hold).
- **Beverage catalog** — `GET /beverages?q=&category=&cursor=`, `GET /beverages/:id`. Shape includes `{ id, name: {en, ja, ko?}, producer: {id, name: {...}}, region: {...}, category, subcategory: {...}, abv, seimai?, flavor: [...], rating: number, checkins: number, description: {...}, recent: [...] }`. Category is one of `'nihonshu' | 'shochu' | 'liqueur'` (stable keys); display strings come from the locale-aware UI table (SPEC §2.1).
- **Producer** — `GET /producers/:id`. Shape `{ id, name: {...}, region: {...}, founded?, website?, description?: {...}, beverages: [{id, name, ...}] }`.
- **Check-in** — `POST /checkins`, `PATCH /checkins/:id`, `DELETE /checkins/:id` (soft-delete). Body: `{ beverage_id, rating?: 0.5..5.0 step 0.5 | null, review?: string (≤500), tags?: [string], photos?: [url] (≤4), price?: { amount: number, currency: 'JPY'|'KRW'|'USD', mode: 'serving'|'bottle' }, purchase_type?: 'on-premise'|'retail'|'gift'|'other' }`. Rating is **optional**; a check-in with `rating === null` is valid (SPEC §4.2).
- **Feed** — `GET /feed?cursor=&limit=20`. Reverse-chronological. Response `{ items: [feedItem], next_cursor: string|null, has_more: bool }`. Each `feedItem` includes `{ id, user: {handle, display_name, avatar}, beverage: {id, name, kanji, producer, region}, rating?, review?, tags, toasts: count, you_toasted: bool, photo_count, created_at }`. Exclude the requester's own check-ins (SPEC §5.2).
- **Toast** — `POST /checkins/:id/toast`, `DELETE /checkins/:id/toast`. Idempotent. One per user per check-in (SPEC §5.3). Returns the new `{ toasts, you_toasted }`.
- **Follow** — `POST /follow/:user_id`, `DELETE /follow/:user_id`. For private targets, `POST` creates a request; for public targets it's instant.
- **Follow requests (inbox)** — `GET /follow/requests?cursor=`, `POST /follow/requests/:id/approve`, `POST /follow/requests/:id/decline`. Required only when the requester's privacy is `'private'`. Each request: `{ id, user: {handle, display_name, avatar, bio}, created_at }`. The bell-badge count in `FeedScreen` derives from `GET /follow/requests?status=pending` count.
- **Collections** — `GET /collections`, `POST /collections`, `PATCH /collections/:id`, `DELETE /collections/:id`. `GET /collections/:id` returns the collection plus its beverages. `POST /collections/:id/items {beverage_id, note?}` adds; `DELETE /collections/:id/items/:beverage_id` removes. Default `Inventory` and `Wishlist` are seeded application-side on user creation (SPEC §6.8).
- **Search** — `GET /search?q=&category=&cursor=`. Matches beverage and producer names across all locales (SPEC §7).

## UI behaviors implying specific API ergonomics

- **Cursor pagination everywhere** (SPEC §6.6). Response shape is uniform: `{ items, next_cursor, has_more }`. Never offset. Feed page size = 20; other lists choose their own (document in `openapi.yaml`). The kit visualises this via `Primitives.jsx::PagingFooter` — Flutter should drive it from `has_more` + `next_cursor`.
- **Follow-request inbox needs Approve / Decline endpoints**, not a generic mutation; the screen renders side-by-side buttons per row. The list endpoint should be paginated even though typical inboxes will be small.
- **Toast is a toggle**, one row per user × check-in. The Feed renders optimistically (count is updated client-side before the server confirms). Endpoint should be idempotent: hitting `POST` twice should not double the count.
- **Collection picker multi-selects** the beverage's membership across all collections at once. A single `PUT /beverages/:id/collections {ids: [...]}` (set semantics) is more ergonomic than N add/remove calls. The picker also creates a new collection inline; the new ID needs to be returned synchronously so the picker can include it in the saved set.
- **Rating is optional.** A `null` rating must round-trip without coercing to `0` or `0.0`. DB column allows `NULL`; API emits `null`; Flutter model uses `double?`.
- **Review character cap (500)** is UI-enforced and must be DB-enforced (`CHECK length(review) <= 500`) plus Go-validated. Same for the 4-photo cap.
- **Username case** — `handle` is the lowercase unique form; `display_username` is the case-preserved form for rendering (SPEC §6.3). Login accepts either; lookup is `LOWER(?)`. Soft-deleted accounts hold the lowercase handle for 30 days.
- **Default collection seeding** — at user-creation time, application-side seeds two rows (`Inventory`, `Wishlist`). They have no special flag in the API; the kit's `data.jsx::COLLECTIONS` carries an `isDefault: true` marker for the UI alone (used in `CollectionDetailScreen` to show "Default collection" overline copy). The DB does not need that column.
- **i18n strings on user-generated content** are NOT translated (SPEC §8). Reviews and notes are stored as-entered. Catalog/producer names are i18n objects; SPEC §6.5 fallback `ko→en`, `ja→en` is applied on the API response (server-side) **or** Flutter-side (client-side) — `backend-engineer` to decide. Server-side resolution is preferred because it keeps the contract simple (return resolved strings + locale tag).

## Tokens that downstream agents must consume verbatim

- Colors → `colors_and_type.css::--c-mizu/sora/hanada/ai/kon/rurikon/koh/matcha/akane/yamabuki/shironeri/kinari`
- Type → `--font-display`, `--font-body`, `--font-mono` + the `.kamos-*` classes
- Spacing → `--space-1..12` (4px base)
- Radii → `--radius-xs/sm/md/lg/xl/pill`
- Shadows → `--shadow-1/2/3/inset/focus`
- Motion → `--ease-out`, `--ease-in-out`, `--dur-fast/base/slow`
- Layout → `--mobile-max: 420px`

In Flutter, mirror these in `theme/tokens.dart` so widgets read them by name. Do not hardcode hex / px anywhere in widget code.

## Substitution flags (still open)

1. **Display font** — Shippori Mincho (substitution; user to confirm).
2. **Icon set** — Phosphor recommended (substitution; kit ships inline SVG fallbacks).
3. **Koh accent retention** — currently used only for toast / kanpai; cuttable for single-hue brand.
4. **Half-star glyph** — `⯨` (U+2BE8) renders inconsistently; Flutter must substitute.
