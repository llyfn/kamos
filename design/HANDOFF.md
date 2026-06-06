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
| Check-in (rating slider, review beside a 1-photo square, flavor profiles, Location, price + currency, per-serving / per-bottle) | `components/CheckInScreen.jsx` |
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
- **Check-in** — `POST /checkins`, `PATCH /checkins/:id`, `DELETE /checkins/:id` (soft-delete). Body: `{ beverage_id, rating?: 0.5..5.0 step 0.25 | null, review?: string (≤500), tags?: [string], photos?: [url] (≤1 on submission; existing rows with up to 4 stay readable), price?: { amount: number, currency: 'JPY'|'KRW'|'USD', mode: 'serving'|'bottle' } }`. Rating is **optional**; a check-in with `rating === null` is valid (SPEC §4.2). `purchase_type` is no longer collected by the mobile UI; the API still accepts the field and the DB column stays for legacy rows.
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

## Post-creation editability

Shipped: PATCH /v1/check-ins/{id} (caller-owned tri-state body), new PATCH /v1/comments/{id} (author-only), `edited_at` columns on both rows. SPEC anchors: §4.2, §4.4, §5.4, §6.6. No new JSX screens; no token / `colors_and_type.css` edits.

### Screen ↔ data-shape mapping

- **Edit check-in** — the compose screen runs in a `mode: edit` variant of the same widget tree (no separate `EditCheckInScreen`): same 0.25-step rating slider, ≤500-char review beside a single photo square, flavor profiles row, Location row, price + currency + serving/bottle. Pre-fills from `GET /v1/check-ins/{id}` (`checkInDetailProvider`); the beverage row renders read-only (`beverage_id` immutable per SPEC §4.4). On save, calls `PATCH /v1/check-ins/{id}` with `{rating?, review?, tags?, price?, add_photos?, remove_photos?}` and expects the existing `CheckinResponse` shape plus `edited_at: string | null` (ISO timestamp, nullable). Submit-button label switches to `Save` / `Saving…`.
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

### Deferred

Edit history audit log, time-limited edit windows, admin-side comment redaction, beverage re-pointing on a check-in, push notifications for edits.

## Producer images

Admin-uploaded optional image on the `producers` row. Mobile renders it where it adds value; never displays a placeholder when the field is null.

### Data shapes

- `Producer` and `ProducerRef` both expose `image_url: string | null`. The compact embed (`ProducerRef`) is included so the feed renders the optional thumbnail without an extra fetch.
- Wire path: admin uploads via the existing R2 presign flow with a new `purpose: "producer"` parameter; the returned `upload_id` is sent on `POST /v1/admin/producers` or `PATCH /v1/admin/producers/{id}` and the backend resolves it to a public R2 URL stored as `producers.image_url`.

### Placement

- **`ProducerDetailScreen` (Flutter):** 140-dp circular avatar centered above the name block, with a 1-dp `--c-border-1` outline (`cached_network_image` clipped through `ClipOval`). When `image_url == null`, the same-dimension circle is filled with `--c-kinari` — keeps the header rhythm without drawing attention to absence.
- **`CheckInCard` (Flutter):** small 16-dp circular avatar (`cached_network_image` with `CircleAvatar` fallback) immediately to the left of the producer name in the beverage info row, **only when `producer.image_url != null`**. When null, do not insert anything (no empty gap, no placeholder). The producer name + region row already reads cleanly without it.
- **`CatalogProducerForm.tsx` (admin):** image input slot beneath the prefecture row. Order: name (en/ja/ko) → prefecture → image → founded → website → description. Editing shows the current image as a preview tile with a "Clear" button below; creating shows an empty dotted-border drop target.

### Iconography + color

- Image-missing alt text uses `producerImageMissing` (en: "No producer image", ja: 「醸造所の画像なし」, ko: "양조장 이미지 없음"). Semantic only — never visible UI copy.
- Image hero on detail screen does NOT carry a Koh-accent overlay (per `design/README.md` Koh is reserved for toast/kanpai). A subtle `--c-border-1` 1-dp outline on the hero is enough to seat it in the surface.

### Deferred

User-submitted producer images, multi-image galleries, in-app cropping/resizing, admin moderation queue beyond the existing producer publish flow.

## Check-in compose redesign (Slice B)

Refresh of `CheckInScreen.jsx`. Brief: `docs/history/03_checkin_compose_redesign/00_brief.md`. SPEC §4.1 (photo cap) and §4.2 (rating step) move from `≤4 photos / 0.5 step` to `≤1 photo / 0.25 step` in lockstep; `CLAUDE.md` "Project invariants" mirrors. No new design tokens.

### New field order (top → bottom)

1. Beverage card header (unchanged: label image, name, producer · region, category overline).
2. **Rating** — `RatingSlider` (see below).
3. **Review** + photo Row (see below).
4. **Flavor Tags** — flat horizontally-scrolling chip row of currently selected tags + trailing `+ Browse` chip; tapping the section header *or* the `+ Browse` chip opens the flavor tag browse bottom sheet (see below).
5. **Location** — venue picker row (renamed from "Where?"). Foursquare flow unchanged.
6. **Price** — currency segmented (`¥` / `₩` / `$`) + amount field + serving/bottle toggle. Unchanged.
7. Full-width primary submit pill (`Post`). Inside the scrollable body, immediately after price.

The AppBar no longer carries a Post button; the right-hand AppBar slot is a 40-dp spacer to keep the title centered against the leading `X`.

### Rating slider primitive

`RatingSlider` (defined inline in `CheckInScreen.jsx`; Flutter to mirror as `frontend/lib/features/check_in/widgets/rating_slider.dart`).

- Continuous horizontal slider, single line. No star glyphs on compose. (Read-only `StarsDisplay` continues to round 0.25 values to half/full stars on feed cards and detail screens — no change.)
- Range: `0.5..5.0` inclusive, `0.25` step → 19 stops (18 segments). Internal index `0..18`, value = `0.5 + i * 0.25`.
- Value is **nullable**. `null` = unrated (SPEC §4.2 says rating is optional). The slider visually parks at the low rail when unrated; the readout shows `— / 5.0`.
- Readout: small `var(--font-mono)` 13-sp text `x.xx / 5.0` (two-decimal formatting, e.g. `4.25 / 5.0`) sitting under the slider on the left.
- Trailing `Clear` text affordance (`var(--font-body)` 12-sp, `var(--fg-brand)`, disabled-state `var(--fg-muted)`) sets the value back to `null`. Disabled when value is already `null`.
- **No** "Tap a star to rate" helper text. The `ratingTapToRate` ARB key is removed.
- Track styling: `var(--c-gray-200)` rail, `var(--c-ai)` fill, 4-dp thickness, 2-dp radius. Thumb is the platform native (Material in Flutter; default `<input type=range>` in the HTML kit) — no custom thumb token introduced.

### Review + photo Row layout

A horizontal `Row` containing:

- **Left:** multi-line note `TextArea` inside a `FormField` with the existing 500-char counter and overflow error. Placeholder: `Leave a note` / `メモを残す` / `메모 남기기`. `minHeight` = 104-dp so it visually matches the photo tile height. `flex: 1`.
- **Right:** a single fixed-size **104 × 104 dp** square photo tile (`PhotoTile` primitive). Empty state opens the picker; filled state renders the picked thumbnail with the existing 22-dp remove `x` chip in the top-right corner.

Cap: **1 photo per check-in on submission**, enforced UI-side and server-side. Existing multi-photo check-ins (pre-redesign) remain readable in the feed and on the detail screen — only the compose surface is capped. The old 4-tile grid is gone.

### Flavor tag pattern

- **Inline row:** a horizontally scrolling flat `Row` (`overflow-x: auto`, no wrap) of currently selected tag chips, terminated by a `+ Browse` chip. The section header (`Flavor Tags`) is itself tappable and opens the same sheet — gives the user two ways in.
- **Browse sheet:** the existing `Sheet` primitive (large modal bottom sheet, `var(--radius-xl)` top corners, backdrop blur), titled `Flavor Tags`. Top of the sheet: a single-line `TextField` search input (placeholder `Search tags` / `タグを検索` / `태그 검색`). Below: a single **flat** wrapped list of all tag chips — no dimension grouping anymore. Tapping a chip toggles selection in place; the underlying screen state updates immediately. The sheet has no Save/Done button — closing dismisses.
- Empty search → `No matching tags.` message in `var(--fg-3)`.
- Selected tags persist across sheet open/close.
- The old dimension-grouped layout (`Sweetness`, `Body`, `Acidity`, `Character`, `Finish`) is gone from the UI. The taxonomy data still informs Flutter's tag catalog; the picker just renders it flat and searchable.

### Location label (renaming)

The section formerly labeled `Where?` is now **`Location`** (EN `Location` / JA `場所` / KO `위치`). The Foursquare venue picker flow is unchanged — the row still opens the venue search, returns a `venue_id`, and renders the selected venue name with an inline clear affordance. ARB key text updates; code identifiers should rename where it adds clarity.

### Purchase Type removal (UI only)

The `Purchase type` section (on-premise / retail / gift / other chips) is **gone from the compose UI**. The `checkInPurchase*` ARB keys are removed.

- DB column `check_ins.purchase_type` stays.
- The API stops requiring/accepting `purchase_type` in `POST /v1/check-ins` and `PATCH /v1/check-ins/{id}` from the Flutter compose flow. (If the column is kept in the request body schema for forward-compat, document it as nullable, never set by the mobile client.)
- No UI surface displays the value either; existing rows that have a value keep it in the DB but it's not rendered anywhere user-facing.

### Submit button placement

A single full-width primary pill (`Post`, `var(--c-ai)` background, white text, 14-sp body, 999-px radius) sits at the bottom of the scrollable form, **inside** the scroll region — not pinned. The AppBar action button is removed; the trailing AppBar slot is empty (a 40-dp spacer maintains centering of the title).

### Open i18n strings introduced by this redesign

Inline in the HTML kit; Flutter ARB keys to be confirmed by `flutter-engineer` (suggested names):

| Key (suggested) | EN | JA | KO |
|---|---|---|---|
| `checkInLocation` | Location | 場所 | 위치 |
| `checkInLocationEmpty` | Add a venue | 会場を追加 | 장소 추가 |
| `checkInReviewPlaceholder` | Leave a note | メモを残す | 메모 남기기 |
| `checkInFlavorBrowse` | + Browse | + 一覧 | + 둘러보기 |
| `checkInFlavorSheetSearch` | Search tags | タグを検索 | 태그 검색 |
| `checkInFlavorSheetEmpty` | No matching tags. | 該当するタグがありません。 | 일치하는 태그가 없습니다. |
| `ratingClear` | Clear | クリア | 지우기 |

### Removed strings

- `ratingTapToRate` (`Tap a star to rate · half-steps allowed` / etc.) — gone with the slider.
- `checkInPurchase*` (section label + on-premise / retail / gift / other) — section removed.
- `checkInPhotosCap` (`Photos · up to 4` / etc.) — there is no separate photo section anymore; the lone tile lives in the review Row.
