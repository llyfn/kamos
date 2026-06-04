# Design → Downstream Handoff

Single bridging document for `db-architect`, `backend-engineer`, and `flutter-engineer`. Not a screen-spec rewrite — this is an index pointing each agent at the canonical sources.

## Canonical sources
- **SPEC of record** — `SPEC.md` (product spec)
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
- **Notifications inbox (subsumes follow requests)** — `GET /notifications?cursor=`, `POST /notifications/read` (body: `{ids: [uuid,...]}` XOR `{all: true}`), `GET /notifications/unread-count`. Each row: `{ id, type, actor: {handle, display_name, avatar} | null, check_in_id?, comment_id?, read_at: ISO|null, created_at }` where `type ∈ {toast, comment, follow, follow_request, follow_approved}`. The Notifications-tab unread dot derives from `GET /notifications/unread-count`. `follow_request` rows still trigger `POST /follow-requests/:id/approve` and `POST /follow-requests/:id/decline` via inline buttons (the standalone `GET /follow-requests` listing was retired — the notifications inbox replaced it).
- **Collections** — `GET /collections`, `POST /collections`, `PATCH /collections/:id`, `DELETE /collections/:id`. `GET /collections/:id` returns the collection plus its beverages. `POST /collections/:id/items {beverage_id, note?}` adds; `DELETE /collections/:id/items/:beverage_id` removes. Default `Inventory` and `Wishlist` are seeded application-side on user creation (SPEC §6.8).
- **Search** — `GET /search?q=&category=&cursor=`. Matches beverage and producer names across all locales (SPEC §7).

## UI behaviors implying specific API ergonomics

- **Cursor pagination everywhere** (SPEC §6.6). Response shape is uniform: `{ items, next_cursor, has_more }`. Never offset. Feed page size = 20; other lists choose their own (document in `openapi.yaml`). The kit visualises this via `Primitives.jsx::PagingFooter` — Flutter should drive it from `has_more` + `next_cursor`.
- **Follow-request rows on the notifications inbox need Approve / Decline endpoints**, not a generic mutation; each row renders side-by-side buttons. The notifications list endpoint is paginated even though typical inboxes will be small.
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

## Post-creation editability (01)

Brief: `docs/history/01_post_create_editability/00_brief.md`. SPEC anchors: §4.2, §4.4, §5.4, §6.6. No new JSX screens; no token / `colors_and_type.css` edits.

### Screen ↔ data-shape mapping

- **EditCheckInScreen** — reuses the `CheckInScreen.jsx` form layout verbatim (0.5-step rating, ≤500-char review counter, 4-photo grid, price + currency + serving/bottle, purchase type). Pre-fills from `GET /v1/check-ins/{id}` (`checkInDetailProvider`). On save, calls `PATCH /v1/check-ins/{id}` with `{rating?, review?, tags?, price?, purchase_type?, add_photos?, remove_photos?}` and expects the existing `CheckinResponse` shape plus one new field: `edited_at: string | null` (ISO timestamp, nullable). `beverage_id` is immutable per SPEC §4.4 — the beverage row in the form renders read-only.
- **Inline comment edit** — reuses `CommentTile`. Calls `PATCH /v1/comments/{id}` with `{body}`. Response mirrors the create response plus `edited_at: string | null`.
- **FeedItem / CheckinResponse / Comment** all gain `edited_at: string | null`. No other shape changes; existing fields untouched.

### Affordance placement

- **Check-in card (bottom action row).** Append `Icons.more_horiz` (size 18, color `--c-fg-3`, 32-dp tap target) to the right of the comment badge — the rightmost item in the row. Renders only when viewer == author. Tap opens a bottom sheet (`--radius-xl` top corners, the existing sheet pattern) with two rows: `checkInEdit` and `checkInDelete`. Delete opens a confirm dialog using `checkInDeleteConfirm` + reused `actionCancel`.
- **Check-in detail screen header.** Mirror the same overflow icon in the existing top-right header slot, same sheet.
- **Comment tile right column.** Top-to-bottom: timestamp · `Icons.edit_outlined` (size 14, color `--c-fg-3`, 14-dp InkWell with 2-dp padding — matches existing trash) · trash. Pencil renders only when viewer == author. Tap swaps body Text → TextField with reused `actionSave` / `actionCancel` (no new keys for the inline-edit row).
- **"Edited" marker.** Render `editedMarker` directly after the relative timestamp on (1) the check-in card header, (2) the check-in detail screen header, (3) the comment tile timestamp row, whenever `edited_at != null`. Style: 11sp, italic, `--c-fg-3`. Localized strings already enumerated in the brief's ARB table.

### Validation against `design/README.md`

- **Color (§Color).** Koh is reserved for toast / kanpai. Overflow + pencil + "edited" marker all use `--c-fg-3` — compliant.
- **Iconography (§Iconography).** README sets 20px as the UI default and 24px for the tab bar. The 14-dp pencil follows the existing trash precedent (no new exception). The 18-dp overflow is slightly below the 20-px default to sit inside the existing action-row rhythm next to the kanpai mark and comment badge — within tolerance; no token change.
- **Voice (§Content fundamentals).** `edited` / `編集済み` / `수정됨` are calm, sentence-case, neutral third-person — compliant.
- **Casing.** Bottom-sheet labels `Edit check-in` / `Delete check-in` are sentence case — compliant.
- **No emoji.** Confirmed — `more_horiz` and `edit_outlined` are line-icon glyphs, not emoji.
- **Type floor exception — flag.** README §Type states "Never go below 14px". The 11sp italic "edited" marker violates this floor. Brief is explicit that no new tokens are introduced. Two options for `flutter-engineer` to pick: **(a)** accept as a one-line documented exception scoped to this marker only (preferred — matches the visual weight of inline metadata on Untappd/Letterboxd and avoids token churn); **(b)** bump the marker to 12sp or the existing smallest body size. Flag this back to designer if (b) is preferred and a token is needed.

### Out of scope (this slice)

Edit history audit log, time-limited edit windows, admin-side comment redaction, beverage re-pointing on a check-in, push notifications for edits.

## Producer images (02)

Admin-uploaded optional image on the `producers` row. Mobile renders it where it adds value; never displays a placeholder when the field is null.

### Data shapes

- `Producer` and `ProducerRef` both expose `image_url: string | null`. The compact embed (`ProducerRef`) is included so the feed renders the optional thumbnail without an extra fetch.
- Wire path: admin uploads via the existing R2 presign flow with a new `purpose: "producer"` parameter; the returned `upload_id` is sent on `POST /v1/admin/producers` or `PATCH /v1/admin/producers/{id}` and the backend resolves it to a public R2 URL stored as `producers.image_url`.

### Placement

- **`ProducerDetailScreen` (Flutter):** new hero block at the top, 16:9 aspect ratio, full-width minus the safe-area inset, rounded corners (`--radius-md`), `cached_network_image`. When `image_url == null`, render a calm kinari-tile (`--c-kinari`) at the same dimensions — keeps the header rhythm without drawing attention to absence.
- **`CheckInCard` (Flutter):** small 16-dp circular avatar (`cached_network_image` with `CircleAvatar` fallback) immediately to the left of the producer name in the beverage info row, **only when `producer.image_url != null`**. When null, do not insert anything (no empty gap, no placeholder). The producer name + region row already reads cleanly without it.
- **`CatalogProducerForm.tsx` (admin):** image input slot beneath the prefecture row. Order: name (en/ja/ko) → prefecture → image → founded → website → description. Editing shows the current image as a preview tile with a "Clear" button below; creating shows an empty dotted-border drop target.

### Iconography + color

- Image-missing alt text uses `producerImageMissing` (en: "No producer image", ja: 「醸造所の画像なし」, ko: "양조장 이미지 없음"). Semantic only — never visible UI copy.
- Image hero on detail screen does NOT carry a Koh-accent overlay (per `design/README.md` Koh is reserved for toast/kanpai). A subtle `--c-border-1` 1-dp outline on the hero is enough to seat it in the surface.

### Out of scope (this slice)

User-submitted producer images, multi-image galleries, in-app cropping/resizing, admin moderation queue beyond the existing producer publish flow.
