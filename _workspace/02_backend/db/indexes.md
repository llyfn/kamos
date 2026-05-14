# KAMOS — Index Strategy

This document explains every index in `migrations/001_initial.sql` and `migrations/002_seed_taxonomy.sql`, why it exists, which query pattern it serves, and which SPEC clause it supports. New indexes go in a **new** migration — never edit a deployed file.

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
| `idx_email_verifications_token` (unique) | Token redemption is a point lookup on the random token. |
| `idx_email_verifications_user` | Resending verification: list a user's verification rows by `user_id`. |

### beverage_categories

| Index | Purpose |
|---|---|
| `idx_beverage_categories_slug` (unique) | Stable API key `nihonshu | shochu | liqueur` is the join target from `beverages.category_id` and a frequent slug-based lookup. |

### breweries

No specific index is created in `001_initial.sql` other than the implicit PK. The GIN index on `name_i18n` is documented below under "Beverage search & discovery" — it lives on the `beverages` and `breweries` tables.

Add when needed (deferred):
- `idx_breweries_prefecture` — only if browse-by-prefecture becomes a feature.

### beverages

| Index | Purpose | SPEC |
|---|---|---|
| `idx_beverages_brewery` | "All beverages from a brewery" — BreweryScreen. | §7 |
| `idx_beverages_category` | "Browse by category" — SearchScreen filter chips. | §7 |
| `idx_beverages_name_gin` | Full-text-ish search across all locales of the i18n name JSONB. Using GIN with the default `jsonb_ops` opclass supports `name_i18n @> '{"en":"Dassai"}'` (containment) but not `LIKE`. For substring search, we **also** maintain a `tsvector` on `(name_i18n->>'en' || ' ' || name_i18n->>'ja' || ' ' || COALESCE(name_i18n->>'ko', ''))` — see the next row. | §7 |
| `idx_beverages_name_tsv` (functional GIN) | `tsvector` over the concatenation of all three locales' names. Supports the discover-screen search query. Postgres FTS handles per-locale stemming poorly for Japanese/Korean — for MVP we use `'simple'` configuration (no stemming) which still gives prefix and lexeme matching. | §7 |
| `idx_beverages_avg_rating_desc` (partial) | "Top-rated beverages in a category" sort. `WHERE check_in_count >= 3` filters out cold-start rows. | §7 |

Definitions added in `001_initial.sql`:

```sql
CREATE INDEX idx_beverages_brewery       ON beverages (brewery_id);
CREATE INDEX idx_beverages_category      ON beverages (category_id);
CREATE INDEX idx_beverages_name_gin      ON beverages USING GIN (name_i18n jsonb_path_ops);
CREATE INDEX idx_beverages_name_tsv      ON beverages USING GIN (
  to_tsvector('simple',
    coalesce(name_i18n->>'en','') || ' ' ||
    coalesce(name_i18n->>'ja','') || ' ' ||
    coalesce(name_i18n->>'ko','')
  )
);
CREATE INDEX idx_beverages_avg_rating_desc
  ON beverages (category_id, avg_rating DESC NULLS LAST)
  WHERE check_in_count >= 3;
```

> Note: the SQL bodies above are the canonical definitions — they were added inline to `001_initial.sql` after the table is created. (Search this file for `CREATE INDEX idx_beverages_` to confirm.)

### breweries (search)

```sql
CREATE INDEX idx_breweries_name_tsv ON breweries USING GIN (
  to_tsvector('simple',
    coalesce(name_i18n->>'en','') || ' ' ||
    coalesce(name_i18n->>'ja','') || ' ' ||
    coalesce(name_i18n->>'ko','')
  )
);
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

Definitions added in `001_initial.sql`:

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
```

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

### beverage_addition_requests

| Index | Purpose |
|---|---|
| `idx_beverage_addition_requests_status` | Admin tooling: "show me pending requests". |

```sql
CREATE INDEX idx_beverage_addition_requests_status
  ON beverage_addition_requests (status, created_at DESC);
```

## Index size & write-cost notes

- **Hottest write paths**: `check_ins.INSERT` updates three indexes (`user_created`, `beverage_created`, `created_global`) plus the aggregate trigger on `beverages`. The trigger does one extra `UPDATE` on `beverages`, which is acceptable at expected MVP write volume (~order of magnitude under 10/sec sustained).
- **Index bloat risk**: `idx_check_ins_user_created` will grow indefinitely as a user accumulates check-ins. The partial `WHERE deleted_at IS NULL` helps but not against retained rows. Consider a TTL / archive process post-MVP; out of scope here.
- **GIN write cost**: `idx_beverages_name_gin` and `idx_beverages_name_tsv` are write-heavy. Beverages are admin-curated and write-rare (catalog updates are bulk imports), so the cost is amortized.

## Indexes intentionally NOT created

- `users.LOWER(display_username)` — never queried. Login uses `LOWER(?)` against `username`, never `display_username`.
- `check_ins.deleted_at` — we use partial-index predicates everywhere instead of a separate index on the column.
- `beverages.subcategory` — subcategory is admin free-text from a predefined list. Filtering by subcategory is a post-MVP feature.
- Any index on `breweries.region`/`beverages.region` — browse-by-region is post-MVP. Add when SearchScreen exposes a region filter.

## Future migrations to consider

1. **`003_*.sql` — search FTS upgrade**: replace `'simple'` config with locale-specific configs once stemming requirements are finalized.
2. **`004_*.sql` — toast count denorm**: if the feed's `LATERAL` count subquery becomes a hotspot (>5ms per row), denormalize `toast_count` onto `check_ins` and maintain via toast triggers.
3. **`005_*.sql` — username release purge job**: a periodic job to hard-purge user rows whose `username_release_at < NOW() - interval '7 days'` (i.e. comfortably past their hold window) to keep the held-handle index small.
