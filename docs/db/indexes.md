# KAMOS — Index Strategy

This document explains every index in `migrations/001_initial.sql` and `migrations/002_seed_taxonomy.sql`, why it exists, which query pattern it serves, and which SPEC clause it supports. New indexes go in a **new** migration — never edit a deployed file. Parenthetical migration numbers below (e.g. `014`, `017`) are historical: the pre-1.0 migrations were squashed into `001_initial.sql`.

## Principles

1. **Cover every WHERE + ORDER BY leading-column combination** in `query_patterns.md`.
2. **Partial indexes for soft-deleted tables**: `WHERE deleted_at IS NULL` so the index is dense, smaller, and faster than a full-table index that the planner would have to filter post-fetch.
3. **Tuple keyset cursors** (`(created_at DESC, id DESC)`) require a composite index in matching column order. We never use OFFSET (SPEC §6.6).
4. **Case-insensitive uniqueness** on `username`/`email` uses `LOWER()` expression indexes or already-lowercased columns.
5. **i18n names** (`JSONB`) are searchable via GIN with the `jsonb_path_ops` operator class for the most common containment / key-existence queries.

## Index catalog

### users

| Index | Purpose | SPEC |
|---|---|---|
| `idx_users_username_live` (unique, partial) | Case-insensitive uniqueness for **live** users on the lowercase `username`. | §3.2, §6.3 |
| `idx_users_username_held` (non-unique, partial) | Lookup of soft-deleted handles still in their 30-day hold window. Used by the registration handler's "is this handle still held?" check. **Not unique** because Postgres cannot make a partial-index predicate involving `NOW()` (must be IMMUTABLE) — hold-window logic lives in the application query, see `query_patterns.md`. | §3.3, §6.3 |
| `idx_users_email_live` (unique, partial) | Case-insensitive email uniqueness for live users. | §3.1 |
| `idx_users_google_sub_live` (unique, partial) | Google OAuth subject is unique per live user. NULL allowed (email-only users). | §3.1 |

### email_verifications

| Index | Purpose |
|---|---|
| `idx_email_verifications_token_hash` (unique) | Token redemption is a point lookup on the hashed token. |
| `idx_email_verifications_user` | Resending verification: list a user's verification rows by `user_id`. |

### beverage_categories

| Index | Purpose |
|---|---|
| `idx_beverage_categories_slug` (unique) | Stable API key `nihonshu | shochu | liqueur` is the join target from `beverages.category_id` and a frequent slug-based lookup. |

### producers

The implicit PK plus the FTS index documented under "producers (search)" cover all current read paths. Migration 014 added `producers.deleted_at` and a tiny partial helper index for the admin "trash" view. Migration 016 added the prefecture FK and its partial index. Migration 017 renamed the table (`breweries` → `producers`) and these indexes:

| Index | Purpose |
|---|---|
| `idx_producers_deleted_at` (partial, 014; renamed 017) | Admin `include_deleted` listing. `WHERE deleted_at IS NOT NULL` keeps the index tiny — almost every row in the catalog is live. |
| `idx_producers_prefecture_id` (partial, 016; renamed 017) | Admin filtering by prefecture and producer-detail prefecture/region joins on the public read path. `WHERE deleted_at IS NULL` keeps the index dense. |

```sql
CREATE INDEX idx_producers_prefecture_id
  ON producers (prefecture_id)
  WHERE deleted_at IS NULL;
```

### beverages

| Index | Purpose | SPEC |
|---|---|---|
| `idx_beverages_producer` (partial, rebuilt 014; renamed 017) | "All beverages from a producer" — ProducerScreen. `WHERE deleted_at IS NULL`. | §7 |
| `idx_beverages_category` (partial, rebuilt 014) | "Browse by category" — SearchScreen filter chips. `WHERE deleted_at IS NULL`. | §7 |
| `idx_beverages_name_gin` (partial, rebuilt 014) | Full-text-ish search across all locales of the i18n name JSONB. Using GIN with the `jsonb_path_ops` opclass supports `name_i18n @> '{"en":"Dassai"}'` (containment) but not `LIKE`. For substring search, we **also** maintain a `tsvector` on `(name_i18n->>'en' || ' ' || name_i18n->>'ja' || ' ' || COALESCE(name_i18n->>'ko', ''))` — see the next row. `WHERE deleted_at IS NULL`. | §7 |
| `idx_beverages_name_tsv` (functional GIN, partial, rebuilt 014) | `tsvector` over the concatenation of all three locales' names. Supports the beverage search screen and the admin catalog `?q=` filter (via `websearch_to_tsquery('simple', $1)` to hit this index). Postgres FTS handles per-locale stemming poorly for Japanese/Korean — for MVP we use `'simple'` configuration (no stemming) which still gives prefix and lexeme matching. `WHERE deleted_at IS NULL`. | §7 |
| `idx_beverages_avg_rating_desc` (partial, rebuilt 014) | "Top-rated beverages in a category" sort. `WHERE deleted_at IS NULL AND check_in_count >= 3` — the existing `>= 3` filter is kept, and `deleted_at IS NULL` is added so soft-deleted catalog entries fall out of the top-rated list. | §7 |
| `idx_beverages_deleted_at` (partial, 014) | Admin `include_deleted` listing. `WHERE deleted_at IS NOT NULL` — tiny. |

Canonical definitions live in `migrations/001_initial.sql`. The index DDL is:

```sql
CREATE INDEX idx_beverages_producer
  ON beverages (producer_id)
  WHERE deleted_at IS NULL;
CREATE INDEX idx_beverages_category
  ON beverages (category_id)
  WHERE deleted_at IS NULL;
CREATE INDEX idx_beverages_name_gin
  ON beverages USING gin (name_i18n jsonb_path_ops)
  WHERE deleted_at IS NULL;
CREATE INDEX idx_beverages_name_tsv
  ON beverages USING gin (
    to_tsvector('simple',
      coalesce(name_i18n->>'en','') || ' ' ||
      coalesce(name_i18n->>'ja','') || ' ' ||
      coalesce(name_i18n->>'ko','')))
  WHERE deleted_at IS NULL;
CREATE INDEX idx_beverages_avg_rating_desc
  ON beverages (category_id, avg_rating DESC NULLS LAST)
  WHERE deleted_at IS NULL AND check_in_count >= 3;
CREATE INDEX idx_beverages_deleted_at
  ON beverages (deleted_at)
  WHERE deleted_at IS NOT NULL;
```

> Note: migration 017 renames `idx_beverages_brewery` → `idx_beverages_producer` to track the `brewery_id → producer_id` column rename. The DDL above reflects the post-017 names.

> Note: 014 DROPs the original (non-partial) indexes and recreates them with the `WHERE deleted_at IS NULL` predicate. During apply there is a brief window where these indexes are absent and public reads may seq-scan; acceptable for the current single-region hosted env per `docs/runbooks/deploy.md`.

### beverages (subcategory FK — 005, Slice C)

Migration 005 adds `beverages.subcategory_id UUID NULL` (FK → `beverage_subcategories(id) ON DELETE SET NULL`) and one partial index. The new join target is `beverage_subcategories`, documented in its own section below.

| Index | Purpose | Trace |
|---|---|---|
| `beverages_subcategory_id_idx` (partial) | "Filter beverages by subcategory in catalog views" — public catalog grouping/filter-chip path and the admin catalog filter on the beverage list. `WHERE deleted_at IS NULL` keeps the index dense since soft-deleted beverages are excluded from every catalog read. | brief 04, §2.2 |

```sql
CREATE INDEX beverages_subcategory_id_idx
  ON beverages (subcategory_id)
  WHERE deleted_at IS NULL;
```

### beverage_subcategories (005, Slice C)

A small, admin-curated taxonomy table (18 seeded rows + a handful of backfilled free-text rows). Read paths are exclusively "list rows under a category, ordered by sort_order" and "look up by `(category_id, slug)` for admin edit". The UNIQUE composite already covers both; no extra index is needed.

| Index | Purpose |
|---|---|
| `beverage_subcategories_pkey` (implicit) | Point lookup by id from the `beverages.subcategory_id` JOIN and the admin edit endpoint. |
| `beverage_subcategories_category_slug_unique` (UNIQUE, composite on `(category_id, slug)`) | Doubles as the read-path index for "list a category's subcategories ordered by sort_order" — Postgres uses the composite's leading column for the equality predicate, then sorts the small per-category set in memory. Acceptable: 8 rows under nihonshu, 7 under shochu, 3 under liqueur plus a small free-text tail. |

Intentionally NOT created:
- `(category_id, sort_order)` — would speed up the list query above by one sort step, but the per-category cardinality is in the single-digit-to-low-teens range. Add only if backfill grows the table by orders of magnitude (no evidence today).
- An index on `deleted_at` — soft-delete rows are exception cases; admin reads use `deleted_at IS NOT NULL` over a tiny set and a partial helper is overkill at this cardinality.

### producers (search)

After 014 the producer FTS index is also partial; renamed in 017:

```sql
CREATE INDEX idx_producers_name_tsv ON producers USING gin (
  to_tsvector('simple',
    coalesce(name_i18n->>'en','') || ' ' ||
    coalesce(name_i18n->>'ja','') || ' ' ||
    coalesce(name_i18n->>'ko','')))
WHERE deleted_at IS NULL;
```

### flavor_tags

| Index | Purpose |
|---|---|
| `idx_flavor_tags_slug` (unique) | Stable join key from check-in tagging. |
| `idx_flavor_tags_dimension` | Render the picker grouped by dimension (`sweetness`, `body`, ...). |

### check_ins

The feed query is the hottest path on the API. Two indexes cover it:

| Index | Purpose | SPEC |
|---|---|---|
| `idx_check_ins_user_created` (partial) | Tuple keyset cursor for feed and profile recent-check-ins. Composite `(user_id, created_at DESC, id DESC)` matches the planner's tuple comparison `(created_at, id) < ($cursor_ts, $cursor_id)` so it scans backwards along the index. `WHERE deleted_at IS NULL` keeps the index dense. | §5.2, §6.6 |
| `idx_check_ins_beverage_created` (partial) | BeverageScreen "recent check-ins" list, cursor-paginated. | §7 |
| `idx_check_ins_created_global` (partial) | "Public timeline" capability — not in MVP, but cheap and useful for QA. We may drop this if it adds write cost without a reader. **Decision: include for MVP**, since admin tooling will use it. | — |
| `idx_check_ins_user_beverage` (partial, 007) | Distinct-beverage aggregation page (`GET /v1/users/{username}/beverages`, Slice D). The query is `WHERE user_id = $1 AND deleted_at IS NULL GROUP BY beverage_id` — this composite lets the planner index-scan straight into the grouped projection instead of hash-aggregating post-scan. `WHERE deleted_at IS NULL` keeps the index dense. | — |

Definitions added in `001_initial.sql` (`idx_check_ins_user_beverage` in `007_user_beverages_indexes.sql`):

```sql
CREATE INDEX idx_check_ins_user_created
  ON check_ins (user_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_check_ins_beverage_created
  ON check_ins (beverage_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_check_ins_created_global
  ON check_ins (created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

-- Migration 004:
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_check_ins_user_beverage
  ON check_ins (user_id, beverage_id)
  WHERE deleted_at IS NULL;
```

#### User-beverages query pattern

`GET /v1/users/{username}/beverages` is the only caller. Single
SQL statement (no N+1), expressed as a CTE that aggregates the
user's check-ins per beverage and JOINs the result back against
the beverages + producers + categories rows:

```sql
WITH u AS (
  SELECT
    beverage_id,
    AVG(rating) FILTER (WHERE rating IS NOT NULL) AS user_avg,
    COUNT(*)                                       AS user_count,
    MAX(created_at)                                AS last_at
  FROM check_ins
  WHERE user_id = $1 AND deleted_at IS NULL
  GROUP BY beverage_id
)
SELECT b.id, b.name_i18n, ...
FROM u
JOIN beverages b           ON b.id = u.beverage_id AND b.deleted_at IS NULL
JOIN producers br          ON br.id = b.producer_id AND br.deleted_at IS NULL
JOIN beverage_categories cat ON cat.id = b.category_id
WHERE (filters)
ORDER BY (sort axis)
LIMIT $N + 1;
```

The CTE uses `idx_check_ins_user_beverage` for the GROUP BY; the
outer JOINs use the existing partial indexes on `beverages.deleted_at`
and the JOIN-target primary keys.

### check_in_photos / check_in_flavor_tags

| Index | Purpose |
|---|---|
| `idx_check_in_photos_unique` (unique) | Enforces 4-photo cap via `(check_in_id, sort_order)` with `sort_order BETWEEN 0 AND 3` CHECK. Also serves as the join index for fetching photos in feed order. (SPEC §4.1 / §6.7) |
| `idx_check_in_photos_check_in` | Plain join index by `check_in_id`, used when sort_order is irrelevant. |
| `idx_check_in_flavor_tags_tag` | "Which check-ins reference this tag?" — admin tooling and the aggregated-flavor view on BeverageScreen. |

### follows

| Index | Purpose | SPEC |
|---|---|---|
| Implicit PK on `(follower_id, followed_id)` | Point lookup for "is A following B?". | §5.1 |
| `idx_follows_follower_accepted` (partial) | Feed query: "users that follower_id follows, accepted". | §5.2 |
| `idx_follows_followed_pending` (partial) | Inbox: "users who have requested to follow followed_id, pending". | §5.4 |
| `idx_follows_followed_accepted` (partial) | "Followers of X". | §5.1 |

Definitions added in `001_initial.sql`:

```sql
CREATE INDEX idx_follows_follower_accepted
  ON follows (follower_id, followed_id)
  WHERE status = 'accepted';

CREATE INDEX idx_follows_followed_accepted
  ON follows (followed_id, follower_id)
  WHERE status = 'accepted';

CREATE INDEX idx_follows_followed_pending
  ON follows (followed_id, created_at DESC)
  WHERE status = 'pending';
```

### toasts

| Index | Purpose | SPEC |
|---|---|---|
| Implicit PK on `(user_id, check_in_id)` | Enforces "one toast per user per check-in" and serves "has user X toasted check-in Y?" | §5.3 |
| `idx_toasts_check_in` | Feed query: render `toasts: N` count per check-in. | §5.3 |

```sql
CREATE INDEX idx_toasts_check_in ON toasts (check_in_id);
```

### collections / collection_entries

| Index | Purpose | SPEC |
|---|---|---|
| `idx_collections_user_name_live` (unique, partial) | A user cannot have two live collections with the same case-insensitive name. | §6.3 |
| `idx_collections_user_live` (partial) | "List my collections" — Lists screen. | §6 |
| Implicit PK on `(collection_id, beverage_id)` | Enforces "binary membership" and serves the collection-detail query. | §6.2 |
| `idx_collection_entries_beverage` | "Which collections contain this beverage?" — drives the picker's pre-checked state. | §6.3 |

```sql
CREATE INDEX idx_collections_user_live
  ON collections (user_id)
  WHERE deleted_at IS NULL;
```

### regions / prefectures (016)

Both tables are seed-only — read-heavy, write-effectively-never. Default PK + UNIQUE on `slug` covers slug lookups; one extra index on `prefectures.region_id` covers the grouped-dropdown query.

| Index | Purpose |
|---|---|
| `regions_slug_key` (unique, implicit) | Slug lookup from the admin form. |
| `prefectures_slug_key` (unique, implicit) | Slug lookup from the admin form and as the join target from `producers`. |
| `idx_prefectures_region_id` | "List prefectures in region X" for the admin grouped dropdown and any future region-filtered producer query. |

```sql
CREATE INDEX idx_prefectures_region_id ON prefectures (region_id);
```

### beverage_addition_requests

| Index | Purpose |
|---|---|
| `idx_beverage_addition_requests_status` | Admin tooling: "show me pending requests". |

```sql
CREATE INDEX idx_beverage_addition_requests_status
  ON beverage_addition_requests (status, created_at DESC);
```

### notifications (019 + 020)

Indexes are introduced by migration 019. Migration 020 swaps `check_in_id` and `comment_id` from `ON DELETE SET NULL` to `ON DELETE CASCADE` (resolving the `notifications_refs_match_type` contradiction); it adds no new indexes and the dedupe partials below are unchanged.

| Index | Purpose | SPEC |
|---|---|---|
| `idx_notifications_recipient_created` | Cursor pagination for `GET /v1/notifications`. Composite `(recipient_user_id, created_at DESC, id DESC)` matches the planner's tuple comparison `(created_at, id) < ($cursor_ts, $cursor_id)` so backward index scan returns rows in cursor order without a sort. | §5.4 |
| `idx_notifications_recipient_unread` (partial) | `GET /v1/notifications/unread-count` and the per-replica "any unread?" dot. `WHERE read_at IS NULL` — tiny in a healthy inbox where most rows are read. Aggregate is index-only. | §5.4 |
| `idx_notifications_toast_unique` (unique, partial) | Dedupe: one toast notification per (recipient, actor, check_in). Toggle-toggle does not spam. `WHERE type = 'toast'`. | §5.4 |
| `idx_notifications_follow_unique` (unique, partial) | Dedupe: one follow notification per (recipient, actor). Re-follow does not re-notify in MVP. `WHERE type = 'follow'`. | §5.4 |
| `idx_notifications_follow_approved_unique` (unique, partial) | Dedupe: one follow_approved notification per (recipient, actor). `WHERE type = 'follow_approved'`. | §5.4 |

```sql
CREATE INDEX idx_notifications_recipient_created
  ON notifications (recipient_user_id, created_at DESC, id DESC);

CREATE INDEX idx_notifications_recipient_unread
  ON notifications (recipient_user_id)
  WHERE read_at IS NULL;

CREATE UNIQUE INDEX idx_notifications_toast_unique
  ON notifications (recipient_user_id, actor_user_id, check_in_id)
  WHERE type = 'toast';

CREATE UNIQUE INDEX idx_notifications_follow_unique
  ON notifications (recipient_user_id, actor_user_id)
  WHERE type = 'follow';

CREATE UNIQUE INDEX idx_notifications_follow_approved_unique
  ON notifications (recipient_user_id, actor_user_id)
  WHERE type = 'follow_approved';
```

No index for `comment` or `follow_request` dedupe — both are intentionally non-deduped at the DB. `comment` is naturally unique by `comment_id` FK; `follow_request` is deletable on every terminal transition by the application so re-requests can re-notify (see schema.md §9c).

## Index size & write-cost notes

- **Hottest write paths**: `check_ins.INSERT` updates three indexes (`user_created`, `beverage_created`, `created_global`) plus the aggregate trigger on `beverages`. The trigger does one extra `UPDATE` on `beverages`, which is acceptable at expected MVP write volume (~order of magnitude under 10/sec sustained).
- **Index bloat risk**: `idx_check_ins_user_created` will grow indefinitely as a user accumulates check-ins. The partial `WHERE deleted_at IS NULL` helps but not against retained rows. Consider a TTL / archive process post-MVP; out of scope here.
- **GIN write cost**: `idx_beverages_name_gin` and `idx_beverages_name_tsv` are write-heavy. Beverages are admin-curated and write-rare (catalog updates are bulk imports), so the cost is amortized.

## Indexes intentionally NOT created

- `users.LOWER(display_username)` — never queried. Login uses `LOWER(?)` against `username`, never `display_username`.
- `check_ins.deleted_at` — we use partial-index predicates everywhere instead of a separate index on the column.
- `beverages.subcategory_i18n` — the legacy free-text JSONB column kept through the Slice C release window. Never indexed; reads after Slice C use the `subcategory_id` FK path documented above. The column is dropped in a follow-up migration after dual-source rendering ends.
- Any index on `producers.region`/`beverages.region` — these free-text columns were removed in 016. Locality is now derived through `producers.prefecture_id → prefectures.region_id`; add a covering index on `(region_id, …)` of `prefectures` only if the producer-list-by-region query becomes a hotspot (it does not today).

## Future migrations to consider

1. **`004_*.sql` — search FTS upgrade**: replace `'simple'` config with locale-specific configs once stemming requirements are finalized.
2. **`005_*.sql` — toast count denorm**: if the feed's `LATERAL` count subquery becomes a hotspot (>5ms per row), denormalize `toast_count` onto `check_ins` and maintain via toast triggers.
3. **`006_*.sql` — username release purge job**: a periodic job to hard-purge user rows whose `username_release_at < NOW() - interval '7 days'` (i.e. comfortably past their hold window) to keep the held-handle index small.
