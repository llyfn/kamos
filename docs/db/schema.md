# KAMOS — Database Schema

Source of truth for the PostgreSQL 15+ data model backing KAMOS. Every entity here traces to `SPEC.md` and the screen data shapes in `design/HANDOFF.md`.

Migrations live in `migrations/`. **Append-only**: never edit a deployed migration; add a new one.

---

## ERD narrative

```
                                  ┌───────────────────────┐
                                  │ beverage_categories   │  (3 seeded rows;
                                  │  slug, name_i18n      │   SPEC §2.1 strings)
                                  └─────────┬─────────────┘
                                            │ category_id
                                            ▼
   ┌──────────────────┐ producer_id┌────────────────────┐
   │ producers        │◀───────────│ beverages          │───────┐
   │ name_i18n,       │            │ name_i18n, abv,    │       │
   │ prefecture_id ─┐ │            │ polishing_ratio,   │       │
   └──────────────┬─┘ │            │ avg_rating (denorm)│       │
                  ▼   │            │ check_in_count     │       │
       ┌──────────────┴──┐         └────────┬───────────┘       │
       │ prefectures     │                                      │
       │ region_id, slug │                                      │
       │ name_i18n       │                                      │
       └────────┬────────┘                                      │
                ▼                                               │
         ┌──────────────┐                                       │
         │ regions      │ (8 seeded rows;                       │
         │ slug,        │  Japan's traditional regions)         │
         │ name_i18n    │                                       │
         └──────────────┘                                       │
                                                                │
                                            │ beverage_id       │ flavor_tag_id
                                            ▼                   ▼
   ┌──────────────────┐                ┌─────────────────┐  ┌────────────────┐
   │ users            │── user_id ────▶│ check_ins       │  │ flavor_tags    │
   │ username (lc),   │                │ rating, review, │  │ dimension,     │
   │ display_username │                │ price..., del.. │  │ slug, name_i18n│
   │ deleted_at,      │                └────┬────────────┘  └────────────────┘
   │ username_release │                     │ check_in_id            ▲
   └────────┬─────────┘                     ├────────────▶ check_in_photos
            │                               │             (≤4 by sort_order)
            │                               └────────────▶ check_in_flavor_tags
            │   ┌──────────┐                                         ▲
            ├──▶│ follows  │ (follower_id, followed_id, status)      │
            │   └──────────┘                                         │
            │                                                        │
            │   ┌──────────┐                                         │
            ├──▶│ toasts   │ PK (user_id, check_in_id)               │
            │   └──────────┘                                         │
            │                                                        │
            │   ┌─────────────────┐  collection_id   ┌──────────────────────┐
            └──▶│ collections     │◀─────────────────│ collection_entries   │
                │ name, del...    │                  │ note (≤200)          │
                └─────────────────┘                  └────────┬─────────────┘
                                                              │ beverage_id
                                                              ▼
                                                       beverages (above)
```

---

## Key design decisions

### 1. i18n storage: JSONB, not separate columns

For `producers`, `beverages`, `beverage_categories`, `flavor_tags`, and certain user-facing free-text fields on `beverages` (`subcategory_i18n`, `description_i18n`), names are stored as a JSONB object `{"en": "...", "ja": "...", "ko": "..."}`. This matches the JSX kit's data shape (`data.jsx::CATALOG`), enables a single GIN FTS index that covers all three locales at once, and means adding a fourth locale post-MVP is a data migration rather than a schema migration.

Rejected alternative: three `name_en`/`name_ja`/`name_ko` columns. Forces three indexes for cross-locale search, and the schema balloons when more i18n fields are added.

Where presence is required (SPEC §2.2: en+ja required), a `CHECK (name_i18n ? 'en' AND name_i18n ? 'ja')` enforces it at the row level.

Trade-off: `JSONB` queries are slightly more verbose in Go (`COALESCE(name->>'ko', name->>'en')` for the SPEC §6.5 fallback). The fallback resolution is owned by the backend layer; see `query_patterns.md`.

### 2. Username / case-insensitive uniqueness

The SPEC §3.2 / §6.3 rule is: usernames are case-insensitive, stored lowercase, displayed as entered. We model this with two columns:

- `username` — the lowercase canonical form, regex-enforced (`^[a-z0-9_]{3,30}$`).
- `display_username` — the case-preserved form used in the UI (`@Yamamoto`).
- A coherence CHECK guarantees `LOWER(display_username) = username`.

Why two `TEXT` columns rather than `CITEXT`? `CITEXT` would conflate the lookup form and the display form, making it harder to render the user's original casing without a second field. Two columns are clearer and Go-friendly.

### 3. Username 30-day hold

SPEC §3.3: a soft-deleted user's username is held for 30 days before being released. We considered three approaches:

1. **Partial unique index with `NOW()` in the predicate** — rejected: Postgres requires the partial-index predicate to be `IMMUTABLE`, and `NOW()` is `STABLE`.
2. **A separate `username_releases` table** — workable, but introduces a second source of truth for the same data.
3. **A `username_release_at` column on `users` plus an application-layer registration check** — chosen.

The schema enforces:
- `username_release_at IS NOT NULL ⇔ deleted_at IS NOT NULL` (coherence CHECK).
- `idx_users_username_live` (unique, partial `WHERE deleted_at IS NULL`) protects live handles.
- `idx_users_username_held` (non-unique, partial `WHERE deleted_at IS NOT NULL`) accelerates the registration-time check.

The registration handler runs the query in `query_patterns.md` § "Username availability" before inserting a new user. There is a narrow race window between the check and the insert; the live-set unique index closes it for the live case, and the held-case race resolves to the first writer winning the live row (the second sees a unique violation on the live index).

### 4. Photo cap of 4 per check-in

SPEC §4.1 / §6.7: ≤ 4 photos per check-in. Implemented as:

- `sort_order SMALLINT NOT NULL CHECK (sort_order BETWEEN 0 AND 3)` — exactly 4 valid values.
- `UNIQUE (check_in_id, sort_order)` — at most one row per (check_in, slot).

By combinatorics, at most 4 rows can exist per `check_in_id`. No trigger needed. The application is responsible for assigning the next free `sort_order` on insert (see `query_patterns.md`). This was the skill's recommended pattern.

Rejected alternative: an `AFTER INSERT` trigger that counts rows and raises. Triggers obscure the constraint and are harder to reason about during reviews.

### 5. `avg_rating` running aggregate

SPEC §4.2: "Beverage average rating is computed as a running average and updated on every check-in."

We chose **trigger-maintained denormalized columns** on `beverages` (`avg_rating NUMERIC(3,2)`, `check_in_count INT`):

- Pros: O(1) read on the BeverageScreen and SearchScreen "top rated" sort. No `AVG()` aggregation on every read. Always fresh.
- Cons: ~one extra `UPDATE` per check-in write. Acceptable at MVP write volume.

Rejected alternatives:

- **A materialized view refreshed on a schedule** — breaks the "fresh" UX promise (the user expects their rating to be reflected on the BeverageScreen immediately).
- **Compute on read**: `SELECT AVG(rating) ... GROUP BY beverage_id` per request — fine for low volumes but doesn't scale, and the index for sorting "top rated by category" becomes impractical without a column.

The trigger function `recompute_beverage_rating(beverage_id)` runs after every check_in INSERT/UPDATE/DELETE and rewrites both columns. Soft-deleted check-ins are excluded (`deleted_at IS NULL`), and NULL ratings are excluded from the average (an unrated check-in still counts toward… nothing — we deliberately exclude it from both `avg_rating` and `check_in_count`; see "Open SPEC ambiguity" below).

### 6. Follow approval flow

SPEC §5.1: public profiles instant-follow; private profiles approve / decline.

The `follows` table uses a composite primary key `(follower_id, followed_id)` (no surrogate id), matching the skill's canonical shape. The `status` column carries `pending` or `accepted`:

- Public follow: insert `(follower, followed, 'accepted', NOW())`.
- Private follow request: insert `(follower, followed, 'pending', NULL)`.
- Approval: `UPDATE follows SET status = 'accepted', accepted_at = NOW() WHERE …`.
- Decline: `DELETE FROM follows WHERE … AND status = 'pending'`. (No "declined" status — once declined the row is gone and the requester can re-request.)
- Unfollow: `DELETE` regardless of status.

Coherence CHECK: `pending` ⇔ `accepted_at IS NULL`. Prevents the application from forgetting to set `accepted_at` on approval.

### 7. Default collections — application-layer

SPEC §6.1 mandates `Inventory` + `Wishlist` for every new user. The skill (and the brief, §6.8) recommend handling this in the application layer so the names can be localized to the user's chosen `locale` at creation time. We follow that recommendation. The registration handler creates the user and the two collections in the same `pgx.Tx`. See `query_patterns.md` § "User creation".

No `is_default` column lives on `collections` — SPEC §6.1 explicitly says the defaults "behave identically" and are renameable / deletable. The UI's `isDefault: true` flag in `COLLECTIONS` (`data.jsx`) is presentation-only and can be derived in the API response if needed (e.g. by checking whether `name` matches a known default), but we don't store it.

### 8. Soft-delete filtering policy

Five tables soft-delete: `users`, `check_ins`, `collections`, `beverages` (014), `producers` (014). Every list query against these MUST include `WHERE deleted_at IS NULL` unless it is an admin "include_deleted" path. The partial indexes on all five make this nearly free. The conventions are codified in `query_patterns.md`.

`collection_entries` does **not** soft-delete; removing a beverage from a collection is a hard delete (`DELETE FROM collection_entries`). The motivation: collection contents are transient by nature; users freely add/remove. Soft-delete adds friction without value.

`toasts` does not soft-delete; un-toasting is a hard `DELETE`.

`follows` does not soft-delete; unfollowing is a hard `DELETE`.

**Catalog soft-delete (014).** `beverages.deleted_at` and `producers.deleted_at` are nullable timestamps that the admin SPA sets on "delete" and clears on "restore". Both columns are filtered by every public read path (matches the `users.deleted_at` convention). All hot-path indexes on these tables are partial `WHERE deleted_at IS NULL`, and a small partial helper index `WHERE deleted_at IS NOT NULL` (`idx_{beverages,producers}_deleted_at`) accelerates the admin "trash" view. The producer soft-delete handler runs a preflight that returns `409 PRODUCER_HAS_LIVE_BEVERAGES` if any live beverage still references the producer — `beverages.producer_id` is `ON DELETE RESTRICT`, so this preserves referential integrity without surprising the user.

### 9. Category enum: lookup table, not Postgres `ENUM` type

SPEC §2.1 freezes three categories (Nihonshu / Shochu / Liqueur) with locale-specific display strings. Two options:

1. Postgres `ENUM` type with `slug`-shaped values + display strings in code.
2. `beverage_categories` table seeded with 3 rows and FK from `beverages.category_id`.

We chose option 2 because:
- Display strings live in the DB (single source of truth for the SPEC §2.1 contract).
- Adding a future category post-MVP is a data write, not an `ALTER TYPE`.
- FKs are easier to reason about than enum values.

Beverages also carry a denormalized `category_slug` column kept in sync by a trigger (`sync_beverage_category_slug`), so the `polishing_ratio_nihonshu_only` CHECK can be evaluated row-locally without a join.

### 9b. Regions / prefectures as i18n reference tables (016)

`producers` (`breweries` pre-017) originally carried free-text `prefecture` and `region` columns. In practice this drifted (mixed `'Niigata'` / `'新潟'` / `'新潟県'` for the same logical place) and made it impossible to drive admin filtering or grouped dropdowns without a controlled vocabulary.

Migration 016 introduces:

- `regions` — 8 seed rows for Japan's traditional regions (Hokkaido, Tōhoku, Kantō, Chūbu, Kansai, Chūgoku, Shikoku, Kyūshū & Okinawa).
- `prefectures` — 47 seed rows in JIS order, each FK'd to a region with `ON DELETE RESTRICT`.

Both tables follow the same `JSONB name_i18n` pattern as `beverage_categories` and `flavor_tags` (`{en, ja, ko}` all required by CHECK — these are seed-only, so all three locales are mandatory).

`producers` gets a nullable `prefecture_id UUID REFERENCES prefectures(id) ON DELETE RESTRICT`. The old free-text `prefecture` and `region` columns were backfilled best-effort (case-insensitive match against `name_i18n->>'en'` or exact match against `name_i18n->>'ja'`) and then dropped. Rows that didn't match resolve to NULL — admin recuration is the explicit fallback rather than silently guessing.

`beverages.prefecture` and `beverages.region` were also dropped with no replacement: locality is derived through `beverages.producer_id → producers.prefecture_id → prefectures.region_id`. Two FK hops on a small catalog is cheap and removes the duplication.

Country dimension is intentionally **not** introduced: MVP is Japan-only. A `countries` table can be added later above `regions` without disturbing existing FKs. `venues.prefecture` (Phase 4, Foursquare-backed) is independent and was not touched — that column is third-party-sourced free text.

### 9c. Notifications (019)

SPEC §5.4 defines an in-app notifications inbox with five event types: `toast`, `comment`, `follow`, `follow_request`, `follow_approved`. Push notifications are deferred to v1.1. The schema is intentionally one wide table — splitting per-type tables would bloat the read path with `UNION ALL` for the unified-inbox cursor.

**Emit strategy: app layer, in-transaction.** No triggers. Every emit path lives in the repository code wrapping the source mutation in the same `pgx.Tx`:

| Source event | Emit |
|---|---|
| `INSERT INTO toasts` | `notifications(type='toast', actor=toaster, recipient=check_in.user_id, check_in_id)` |
| `INSERT INTO comments` | `notifications(type='comment', actor=commenter, recipient=check_in.user_id, check_in_id, comment_id)` |
| `INSERT INTO follows (status='accepted')` (public target) | `notifications(type='follow', actor=follower, recipient=followed_id)` |
| `INSERT INTO follows (status='pending')` (private target) | `notifications(type='follow_request', actor=follower, recipient=followed_id)` |
| `UPDATE follows SET status='accepted' WHERE status='pending'` | `notifications(type='follow_approved', actor=approver, recipient=requester)` AND `DELETE` the original `follow_request` notification |
| `DELETE FROM follows WHERE status='pending'` (decline) | `DELETE` the `follow_request` notification |

Triggers were rejected: review surface gets harder, the `follows`-side `INSERT` is conditionally `pending` or `accepted` and that branching belongs in service code, and the comment-author emit needs both `check_in.user_id` and `comment.id` which only the service knows after the comment write. Mirrors the pattern set by `comments` in 009 (also trigger-free).

**Self-action filter.** SPEC §5.4: "Self-actions never produce a notification." Service layer filters before insert. The DB still carries `notifications_no_self` as a belt-and-suspenders CHECK so a bug that bypasses the service filter is rejected at write time.

**Soft-delete propagation.**

- `recipient_user_id` is `ON DELETE CASCADE`: when a user is hard-purged (post 30-day username hold), their inbox vanishes with them. Recipient soft-delete does NOT wipe the inbox — the rows stay until hard purge.
- `actor_user_id` is `ON DELETE SET NULL`: a deleted (soft- or hard-) actor leaves the row in place; the UI renders the localized "Deleted user" placeholder per SPEC §5.4.
- `check_in_id` and `comment_id` are `ON DELETE SET NULL`: a deleted source preserves the notification; the row no longer has a tap target but the user still sees the event happened.

**Dedupe matrix.**

| Type | DB dedupe | Rationale |
|---|---|---|
| `toast` | Partial unique on `(recipient, actor, check_in_id) WHERE type='toast'` | Toggling a toast off and back on must not spam the recipient. Re-insert is `ON CONFLICT DO NOTHING`. |
| `comment` | None | Every comment is its own event. Multiple comments from the same actor on the same check-in produce multiple notifications. |
| `follow` | Partial unique on `(recipient, actor) WHERE type='follow'` | Unfollow + re-follow does NOT re-notify in MVP. Revisit if user feedback requests it. |
| `follow_request` | None | Lifecycle requires the row to be deletable on approve/decline/cancel so a later re-request can re-notify. The "row exists only while the underlying follow is pending" invariant cannot be expressed in a partial unique predicate (would need a subquery, which is not `IMMUTABLE`). The application owns deletion — service code DELETEs the `follow_request` row on each terminal transition. |
| `follow_approved` | Partial unique on `(recipient, actor) WHERE type='follow_approved'` | One row per pair per approval-event for MVP. Re-approval after a future unfollow → re-request → approve cycle is swallowed by `ON CONFLICT DO NOTHING`; same logical "your follow was approved" event for the requester. |

**Reference-shape CHECK.** A single `notifications_refs_match_type` CHECK enforces per-type which of `check_in_id` and `comment_id` must be NULL or NOT NULL. Catches misuse at write time instead of letting a malformed row reach a Flutter `null!` crash.

**Read-state.** `read_at TIMESTAMPTZ NULL` — set on (a) row scrolls into view, (b) row tapped, (c) "Mark all read". The partial index `idx_notifications_recipient_unread WHERE read_at IS NULL` keeps the badge-dot lookup index-only and the unread-count aggregate cheap; in a healthy inbox where most rows are read it stays tiny.

### 10. UUID, not bigint, primary keys

`pgcrypto.gen_random_uuid()` everywhere. Trade-offs:

- Slightly larger keys, slightly worse index locality.
- Trivial to generate client-side or in distributed components later.
- Avoids leaking record-count via sequential IDs in the API.

This aligns with the skill and the stack section of `00_brief.md`.

---

## Tables (summary)

| Table | Purpose | Soft-delete | Notable invariants |
|---|---|---|---|
| `users` | Accounts. | `deleted_at` + `username_release_at` | Lowercase username regex, en/ja/ko locale, public/private privacy, at least one auth method present. |
| `email_verifications` | 24h token for email link. | — | `expires_at` checked in app. |
| `beverage_categories` | SPEC §2.1 lookup. | — | Slug locked to 3 values. |
| `producers` | Maker catalog (renamed from `breweries` in 017). | `deleted_at` (014) | `name_i18n` requires en+ja. Founded year sanity-checked. Soft-deletable for admin curation. `prefecture_id` FK → `prefectures` (016), nullable; old free-text `prefecture`/`region` columns dropped. |
| `beverages` | Catalog rows. | `deleted_at` (014) | `polishing_ratio` only valid for nihonshu (CHECK with denorm `category_slug`). ABV range. Soft-deletable for admin curation. Locality derived through `producer_id → producers.prefecture_id` (016 + 017); own `prefecture`/`region` columns dropped. |
| `regions` | Japan's 8 traditional regions (seed). | — | `name_i18n` requires en+ja+ko. 8 seeded rows (016). |
| `prefectures` | Japan's 47 prefectures (seed), FK to `regions`. | — | `name_i18n` requires en+ja+ko. 47 seeded rows in JIS order (016). |
| `flavor_tags` | Admin taxonomy (SPEC §4.3). | — | 5 fixed dimensions. |
| `beverage_flavor_tags` | Aggregate tags per beverage. | — | Composite PK. |
| `check_ins` | User logs. | `deleted_at` | Rating 0.5..5.0 in 0.5 steps, review ≤500, price coherence. Beverage immutable post-create (SPEC §4.4) — enforced at app layer. |
| `check_in_photos` | ≤4 photos per check-in. | — | `sort_order ∈ {0..3}` + UNIQUE. |
| `check_in_flavor_tags` | Tags per check-in. | — | Composite PK. |
| `follows` | Social graph. | — | Composite PK, status enum, `pending ⇔ accepted_at IS NULL`. |
| `toasts` | Reactions. | — | One per (user, check_in). |
| `collections` | User-owned lists. | `deleted_at` | Name 1..50 chars, unique per user (case-insensitive) among live rows. |
| `collection_entries` | Beverage × collection. | — | Note ≤200. Composite PK. |
| `beverage_addition_requests` | SPEC §2.4 user feedback. | — | Status enum. |
| `notifications` | In-app inbox (SPEC §5.4). | — (recipient hard-delete CASCADEs the row; soft-delete of actor/check-in/comment SET NULLs the FK and keeps the row visible). | `type` ∈ {`toast`,`comment`,`follow`,`follow_request`,`follow_approved`}. Per-type CHECK on which references must be populated. `actor_user_id <> recipient_user_id`. Partial unique indexes dedupe `toast` per (recipient, actor, check_in) and `follow` / `follow_approved` per (recipient, actor). `comment` and `follow_request` deliberately have no DB dedupe — see "Notifications" section. |

---

## SPEC traceability

Every CHECK constraint and column traces to a SPEC clause:

| Constraint / column | Trace |
|---|---|
| `users.username ~ '^[a-z0-9_]{3,30}$'` | §3.2, §6.3 |
| `users.bio` ≤ 200 | §3.2 |
| `users.display_name` 1..50 | §3.2 |
| `users.locale IN ('en','ja','ko')` | §8 |
| `users.privacy_mode IN ('public','private')` | §5.1 |
| `users.username_release_at` (30-day hold) | §3.3 |
| `beverage_categories` 3 seeded rows | §2.1 |
| `beverages.polishing_ratio` nihonshu-only | §2.2 |
| `beverages.abv` range | §2.2 |
| `check_ins.rating` 0.5..5.0 step 0.5 | §4.2, §6.2 |
| `check_ins.review_text` ≤ 500 | §4.1, §6.7 |
| `check_in_photos.sort_order 0..3` + UNIQUE | §4.1, §6.7 |
| `check_ins.purchase_type` enum | §4.1 |
| `check_ins.price_*` coherence | §4.1 |
| `check_ins.deleted_at` | §4.4, §6.4 |
| `follows.status IN ('pending','accepted')` | §5.1 |
| `follows.follower_id <> followed_id` | §5.1 |
| `toasts` composite PK | §5.3 |
| `collections.name` 1..50 | §6.3 |
| `collection_entries.note` ≤ 200 | §6.2 |
| Cursor pagination indexes | §5.2, §6.6 |
| Default `Inventory` + `Wishlist` (app-layer) | §6.1, §6.8 |
| `regions` / `prefectures` (i18n reference) | §2.3 (producer prefecture display); 016 |
| `producers.prefecture_id` FK (replaces free-text) | §2.3; 016 + 017 |

---

## Open SPEC ambiguities (resolved with stated assumptions)

1. **NULL ratings & beverage `check_in_count`**. SPEC §4.1 says rating is optional; SPEC §4.2 says the beverage's average is "computed as a running average and updated on every check-in." We assume:
   - `avg_rating` averages only **non-null** ratings (otherwise `AVG()` would be meaningless).
   - `check_in_count` (denormalized on `beverages`) counts **rated** check-ins only — the BeverageScreen renders `X.X / 5.0 · N check-ins`, and a count that includes unrated rows would be confusing relative to the average.
   - The raw "how many times has this beverage been logged at all" count is recoverable via `SELECT COUNT(*) FROM check_ins WHERE beverage_id = ? AND deleted_at IS NULL`, but is not denormalized.
   - **Flag for review**: confirm this is the intended UX before launch. If "checkins: 2841" in `data.jsx` is meant to count all check-ins regardless of rating, we'll add a second denormalized column.

2. **`accepted_at` on legacy/public follows**. SPEC §5.1 implies public follows are "instant"; we set `accepted_at = created_at` on insert. There's no SPEC text saying these are conceptually different from approved private follows, so they share the same column.

3. **Subcategory i18n**. SPEC §2.2 calls the subcategory "Text · Free from predefined list" but doesn't explicitly say it is i18n. The JSX kit treats it as i18n (`{en:'Junmai Daiginjo', ja:'純米大吟醸', ko:'준마이 다이긴조'}`). We follow the JSX (JSONB column).

4. **Beverage `flavor_profile` array vs `beverage_flavor_tags` junction**. The JSX has a flat array of tag labels per beverage; we maintain **both** a `flavor_profile TEXT[]` of tag slugs (cheap to render) and the `beverage_flavor_tags` junction (clean joins for filtering). Admin tooling is responsible for keeping them in sync; we did not add a trigger to enforce this because admin writes happen offline.

5. **Beverage hard-delete vs soft-delete**. SPEC does not specify whether admin-curated beverages can be removed. We chose `ON DELETE RESTRICT` for `beverages` references from `check_ins` and `collection_entries`; the admin must reassign or hide before deleting. This avoids destroying user history. If the SPEC owner wants a "hide from search" semantic without delete, add a `beverages.is_hidden BOOLEAN` later.

6. **`beverage_addition_requests` payload**. SPEC §2.4 says "users can request additions via a form" with no field list. We modeled the payload as JSONB so the form can evolve without schema migrations.

---

## Operations

### Applying the migrations

```bash
psql "$DATABASE_URL" -f migrations/001_initial.sql
psql "$DATABASE_URL" -f migrations/002_seed_taxonomy.sql
```

### Verifying

```bash
psql "$DATABASE_URL" -c "\d+ users"
psql "$DATABASE_URL" -c "\d+ check_ins"
psql "$DATABASE_URL" -c "SELECT slug, name_i18n FROM beverage_categories ORDER BY sort_order;"
psql "$DATABASE_URL" -c "SELECT dimension, COUNT(*) FROM flavor_tags GROUP BY dimension;"
```

### Future migration discipline

- One transaction per file.
- Never edit a deployed migration. Add a new one.
- Destructive operations (column drop, type change) require an explicit user-confirmation step per the project CLAUDE.md.
