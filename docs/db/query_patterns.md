# KAMOS — Query Patterns

Annotated SQL the backend engineer implements as `pgx/v5` repository functions. Each section names the screen / endpoint, the SPEC clause, the SQL, the index it relies on, and notes on Go-side handling.

Conventions:
- `$1`, `$2`, ... are positional parameters in pgx style.
- `created_at` keyset cursors are encoded server-side as `base64(JSON({ts, id}))`.
- All list queries against `users`, `check_ins`, `collections` MUST include `WHERE deleted_at IS NULL`. Where a JOIN crosses into one of these tables, the join predicate carries it.

---

## 1. User registration with default collections

**Endpoint**: `POST /auth/register` (also Google OAuth first-login).
**SPEC**: §3.1, §6.1, §6.8.

Wrap in a `pgx.Tx`. Insert the user, then the two default collections. Names are localized to the user's chosen `locale`.

```sql
-- 1a. Insert user.
INSERT INTO users (
  username, display_username, email, email_verified,
  password_hash, google_sub,
  display_name, avatar_url, bio,
  locale, privacy_mode
) VALUES (
  LOWER($1), $1, $2, $3,
  $4, $5,
  $6, $7, $8,
  $9, 'public'
)
RETURNING id, username, display_username, email, email_verified,
          display_name, avatar_url, bio, locale, privacy_mode, created_at;
```

```sql
-- 1b. Seed default collections. Names depend on locale:
--   en: 'Inventory'   / 'Wishlist'
--   ja: '在庫'        / 'ウィッシュリスト'
--   ko: '인벤토리'     / '위시리스트'
INSERT INTO collections (user_id, name) VALUES
  ($1, $2),  -- Inventory (localized)
  ($1, $3);  -- Wishlist  (localized)
```

Go is responsible for picking the localized strings; the DB does not enforce default-collection names. The user may rename or delete them freely afterwards (SPEC §6.1).

### Username availability (pre-registration check)

Before attempting the insert, the registration handler runs:

```sql
-- Returns nothing if the handle is available.
-- Returns one row if the handle is currently in use (live) or still held
-- (soft-deleted but within 30-day window).
SELECT
  CASE
    WHEN deleted_at IS NULL THEN 'live'
    WHEN username_release_at IS NULL OR username_release_at > NOW() THEN 'held'
    ELSE 'released'
  END AS state,
  COALESCE(username_release_at, NOW()) AS available_at
FROM users
WHERE username = LOWER($1)
  AND (deleted_at IS NULL OR username_release_at > NOW())
LIMIT 1;
```

If the query returns a row, the handler rejects with 409 Conflict and includes `available_at` for the UI to show "available in N days" when held. If the query is empty, proceed to insert; the live partial unique index handles the inevitable race.

---

## 2. Login (email + password OR Google OAuth)

```sql
-- 2a. Email login lookup (case-insensitive on email).
SELECT id, username, display_username, email, email_verified,
       password_hash, display_name, avatar_url, bio, locale, privacy_mode
FROM users
WHERE LOWER(email) = LOWER($1)
  AND deleted_at IS NULL
LIMIT 1;
```

```sql
-- 2b. Google OAuth: look up by google_sub, fall back to email match for
-- account linking (covered by the same query — if google_sub matches we
-- return it; else fall through to a separate email-based query in Go).
SELECT id, username, display_username, email, email_verified,
       display_name, avatar_url, bio, locale, privacy_mode
FROM users
WHERE google_sub = $1
  AND deleted_at IS NULL
LIMIT 1;
```

Indexes used: `idx_users_email_live`, `idx_users_google_sub_live`.

---

## 3. Feed (cursor-paginated)

**Endpoint**: `GET /feed?cursor=&limit=20`.
**SPEC**: §5.2, §6.6.

Reverse-chronological. Includes the requester's own check-ins plus accepted-followed users' check-ins (`LEFT JOIN follows` with an `OR ci.user_id = $1` predicate). Keyset cursor on `(created_at, id)`.

```sql
SELECT
  ci.id,
  ci.rating,
  ci.review_text,
  ci.created_at,
  ci.user_id,
  u.username,
  u.display_username,
  u.display_name,
  u.avatar_url,
  ci.beverage_id,
  b.name_i18n         AS beverage_name_i18n,
  b.category_slug     AS beverage_category,
  br.id               AS producer_id,
  br.name_i18n        AS producer_name_i18n,
  COALESCE(tc.cnt, 0) AS toast_count,
  EXISTS (
    SELECT 1 FROM toasts tt
    WHERE tt.check_in_id = ci.id AND tt.user_id = $1
  )                   AS you_toasted,
  ph.photo_count
FROM check_ins ci
LEFT JOIN follows f
  ON f.followed_id = ci.user_id
  AND f.follower_id = $1
  AND f.status = 'accepted'
JOIN users u
  ON u.id = ci.user_id
  AND u.deleted_at IS NULL
JOIN beverages b
  ON b.id = ci.beverage_id
JOIN producers br
  ON br.id = b.producer_id
LEFT JOIN LATERAL (
  SELECT COUNT(*) AS cnt FROM toasts t WHERE t.check_in_id = ci.id
) tc ON TRUE
LEFT JOIN LATERAL (
  SELECT COUNT(*)::int AS photo_count FROM check_in_photos p WHERE p.check_in_id = ci.id
) ph ON TRUE
WHERE ci.deleted_at IS NULL
  AND (ci.user_id = $1 OR f.followed_id IS NOT NULL) -- self or followed
  AND ($2::timestamptz IS NULL OR
       (ci.created_at, ci.id) < ($2, $3))           -- keyset cursor (NULL on first page)
ORDER BY ci.created_at DESC, ci.id DESC
LIMIT 21;                                            -- 20 + 1 to compute has_more
```

Indexes used:
- `idx_follows_follower_accepted` for the JOIN.
- `idx_check_ins_user_created` for the ORDER BY per-user.
- `idx_beverages_producer` for the `b.producer_id → producers.id` join.
- Tuple comparison `(created_at, id) <` allows Postgres to perform a backward index scan with an "index condition" that prunes already-seen rows.

Go-side:
- Fetch up to 21. If 21 returned, `has_more = true` and emit only first 20; encode the 20th row's `(created_at, id)` as `next_cursor`. Else `has_more = false`, `next_cursor = null`.
- Apply SPEC §6.5 i18n fallback when emitting the response:
  ```go
  name := nameI18n["ko"]
  if name == nil { name = nameI18n["en"] }
  ```
- Render `review_text` truncated to 140 chars on the client; the API returns the full string (SPEC §5.2 truncation is UI-side).

Tags per check-in are fetched separately to avoid row explosion on the JOIN:

```sql
SELECT cift.check_in_id, ft.slug, ft.dimension, ft.name_i18n
FROM check_in_flavor_tags cift
JOIN flavor_tags ft ON ft.id = cift.flavor_tag_id
WHERE cift.check_in_id = ANY($1);   -- $1 is a UUID[] of the page's ids
```

---

## 4. Toggle a toast

**Endpoint**: `POST /checkins/:id/toast` / `DELETE /checkins/:id/toast`.
**SPEC**: §5.3.

Idempotent insert / delete on a composite-PK table.

```sql
-- Insert (idempotent).
INSERT INTO toasts (user_id, check_in_id)
VALUES ($1, $2)
ON CONFLICT (user_id, check_in_id) DO NOTHING;
```

```sql
-- Remove.
DELETE FROM toasts
WHERE user_id = $1 AND check_in_id = $2;
```

After either, return the fresh counts:

```sql
SELECT
  (SELECT COUNT(*) FROM toasts WHERE check_in_id = $2) AS toasts,
  EXISTS (SELECT 1 FROM toasts WHERE check_in_id = $2 AND user_id = $1) AS you_toasted;
```

Gate: if the check_in's owner has `privacy_mode = 'private'`, the toaster must be an accepted follower. The check is in the handler, but the DB query for the gate is:

```sql
SELECT 1
FROM check_ins ci
JOIN users u ON u.id = ci.user_id
WHERE ci.id = $1
  AND ci.deleted_at IS NULL
  AND (
    u.privacy_mode = 'public'
    OR u.id = $2
    OR EXISTS (
      SELECT 1 FROM follows f
      WHERE f.follower_id = $2 AND f.followed_id = u.id AND f.status = 'accepted'
    )
  )
LIMIT 1;
```

If no row returned, the handler responds 403/404 per the API style (404 to avoid leaking existence).

---

## 5. Follow / follow-request approval

**Endpoint**: `POST /follow/:user_id`, `POST /follow/requests/:id/approve`, `POST /follow/requests/:id/decline`.
**SPEC**: §5.1, §5.4.

```sql
-- 5a. Initiate follow.
--   For a public target: insert as 'accepted'.
--   For a private target: insert as 'pending'.
-- The handler determines $3/$4 based on a prior lookup of the target's privacy.
INSERT INTO follows (follower_id, followed_id, status, accepted_at)
VALUES ($1, $2, $3, $4)
ON CONFLICT (follower_id, followed_id) DO NOTHING
RETURNING follower_id, followed_id, status, created_at, accepted_at;
```

```sql
-- 5b. List inbox (pending requests targeted at the current user).
SELECT
  f.follower_id   AS user_id,
  u.username,
  u.display_username,
  u.display_name,
  u.avatar_url,
  u.bio,
  f.created_at
FROM follows f
JOIN users u ON u.id = f.follower_id AND u.deleted_at IS NULL
WHERE f.followed_id = $1
  AND f.status = 'pending'
  AND ($2::timestamptz IS NULL OR f.created_at < $2)
ORDER BY f.created_at DESC
LIMIT 21;
```

Uses `idx_follows_followed_pending`.

```sql
-- 5c. Approve.
UPDATE follows
SET status = 'accepted', accepted_at = NOW()
WHERE follower_id = $1
  AND followed_id = $2
  AND status = 'pending';
```

```sql
-- 5d. Decline (hard delete).
DELETE FROM follows
WHERE follower_id = $1
  AND followed_id = $2
  AND status = 'pending';
```

```sql
-- 5e. Unfollow (regardless of state).
DELETE FROM follows
WHERE follower_id = $1 AND followed_id = $2;
```

```sql
-- 5f. Inbox badge count.
SELECT COUNT(*) FROM follows
WHERE followed_id = $1 AND status = 'pending';
```

---

## 6. Create a check-in (with photos and tags)

**Endpoint**: `POST /checkins`.
**SPEC**: §4.1, §6.7.

Three statements in one `pgx.Tx`:

```sql
-- 6a. Insert check-in.
INSERT INTO check_ins (
  user_id, beverage_id,
  rating, review_text,
  price_amount, price_currency, price_unit,
  purchase_type
) VALUES (
  $1, $2,
  $3, $4,
  $5, $6, $7,
  $8
)
RETURNING id, created_at;
```

```sql
-- 6b. Insert photos (Go loops; sort_order is 0..3).
INSERT INTO check_in_photos (check_in_id, photo_url, storage_key, sort_order)
VALUES ($1, $2, $3, $4);
```

The application enforces `len(photos) <= 4` before the loop; the UNIQUE(check_in_id, sort_order) + CHECK(sort_order BETWEEN 0 AND 3) prevents over-insertion at the DB.

```sql
-- 6c. Insert flavor tags (multi-row VALUES).
INSERT INTO check_in_flavor_tags (check_in_id, flavor_tag_id)
SELECT $1, ft.id FROM flavor_tags ft WHERE ft.slug = ANY($2);
```

After commit, the `trg_check_ins_agg_iud` trigger has already updated `beverages.avg_rating` and `beverages.check_in_count`.

---

## 7. Edit a check-in

**Endpoint**: `PATCH /checkins/:id`.
**SPEC**: §4.4 — all fields editable EXCEPT `beverage_id`.

Go validates that the patch does not include `beverage_id`. The DB does not enforce it (no DB-level guarantee that `beverage_id` is immutable; we rely on application discipline).

```sql
UPDATE check_ins SET
  rating          = COALESCE($2, rating),
  review_text     = $3,           -- nullable, allow explicit clear
  price_amount    = $4,
  price_currency  = $5,
  price_unit      = $6,
  purchase_type   = $7
WHERE id = $1
  AND user_id = $8
  AND deleted_at IS NULL
RETURNING id, updated_at;
```

Photo & tag edits are separate batched statements (delete + re-insert pattern; trivial at the ≤4 / ≤many sizes involved).

---

## 8. Soft-delete a check-in

**Endpoint**: `DELETE /checkins/:id`.
**SPEC**: §4.4 / §6.4.

```sql
UPDATE check_ins
SET deleted_at = NOW()
WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
RETURNING id;
```

The `trg_check_ins_agg_iud` trigger fires on UPDATE and recomputes the beverage's `avg_rating` and `check_in_count`.

---

## 9. Soft-delete a user

**Endpoint**: `DELETE /me`.
**SPEC**: §3.3.

```sql
UPDATE users SET
  deleted_at          = NOW(),
  username_release_at = NOW() + INTERVAL '30 days'
WHERE id = $1 AND deleted_at IS NULL
RETURNING username, username_release_at;
```

The 30-day hold is enforced at registration time (see §1 "Username availability"). Soft-deleting a user does **not** cascade-delete their check-ins or collections; those rows persist for other users to view via direct links (the feed and profile screens, however, hide soft-deleted users by joining `WHERE u.deleted_at IS NULL`).

A scheduled job (out of scope for this migration) eventually hard-purges users whose `username_release_at < NOW() - INTERVAL '7 days'`.

---

## 10. Beverage detail

**Endpoint**: `GET /beverages/:id`.
**SPEC**: §7.

```sql
SELECT
  b.id, b.name_i18n, b.category_slug, b.subcategory_i18n,
  b.abv, b.polishing_ratio,
  b.description_i18n, b.label_image_url,
  b.avg_rating, b.check_in_count,
  br.id AS producer_id,
  br.name_i18n AS producer_name_i18n,
  pf.name_i18n AS prefecture_name_i18n,
  rg.name_i18n AS region_name_i18n
FROM beverages b
JOIN producers br ON br.id = b.producer_id
LEFT JOIN prefectures pf ON pf.id = br.prefecture_id
LEFT JOIN regions rg ON rg.id = pf.region_id
WHERE b.id = $1;
```

Aggregated flavor profile (the "風味プロフィール" block):

```sql
SELECT ft.slug, ft.dimension, ft.name_i18n, COUNT(*) AS uses
FROM check_in_flavor_tags cift
JOIN check_ins ci ON ci.id = cift.check_in_id AND ci.deleted_at IS NULL
JOIN flavor_tags ft ON ft.id = cift.flavor_tag_id
WHERE ci.beverage_id = $1
GROUP BY ft.slug, ft.dimension, ft.name_i18n
ORDER BY uses DESC, ft.dimension, ft.sort_order
LIMIT 12;
```

Recent check-ins for this beverage (cursor-paginated):

```sql
SELECT ci.id, ci.rating, ci.review_text, ci.created_at,
       u.username, u.display_username, u.display_name, u.avatar_url
FROM check_ins ci
JOIN users u ON u.id = ci.user_id AND u.deleted_at IS NULL
WHERE ci.beverage_id = $1
  AND ci.deleted_at IS NULL
  AND ($2::timestamptz IS NULL OR (ci.created_at, ci.id) < ($2, $3))
ORDER BY ci.created_at DESC, ci.id DESC
LIMIT 21;
```

Uses `idx_check_ins_beverage_created`.

---

## 11. Search beverages

**Endpoint**: `GET /search?q=&category=&cursor=`.
**SPEC**: §7.

Cross-locale lexeme matching via the GIN tsvector index. Cursor is `(checkins, id)` for relevance proxy, or `(avg_rating, id)` for top-rated. For MVP we use a single ordering: `ts_rank` desc, then `check_in_count` desc as a popularity tiebreak.

```sql
SELECT b.id, b.name_i18n, b.category_slug, b.avg_rating, b.check_in_count,
       br.name_i18n AS producer_name_i18n
FROM beverages b
JOIN producers br ON br.id = b.producer_id
WHERE
  ($1::text IS NULL OR
   to_tsvector('simple',
     coalesce(b.name_i18n->>'en','') || ' ' ||
     coalesce(b.name_i18n->>'ja','') || ' ' ||
     coalesce(b.name_i18n->>'ko','')
   ) @@ plainto_tsquery('simple', $1))
  AND ($2::text IS NULL OR b.category_slug = $2)
  AND ($3::int IS NULL OR (b.check_in_count, b.id::text) < ($3, $4))
ORDER BY b.check_in_count DESC, b.id DESC
LIMIT 21;
```

Note: the cursor here uses `(check_in_count, id)` because we sort by popularity. For ordering by rating, swap to `(avg_rating, id)` and re-pick the cursor encoding accordingly. The cursor format must include which sort order it belongs to so Go can dispatch.

---

## 12. Collections — list and detail

```sql
-- 12a. List my collections.
SELECT c.id, c.name, c.created_at, c.updated_at,
       COUNT(ce.beverage_id)::int AS entry_count
FROM collections c
LEFT JOIN collection_entries ce ON ce.collection_id = c.id
WHERE c.user_id = $1 AND c.deleted_at IS NULL
GROUP BY c.id
ORDER BY c.created_at ASC;
```

```sql
-- 12b. Collection detail (entries).
SELECT ce.beverage_id, ce.note, ce.added_at,
       b.name_i18n, b.category_slug, b.label_image_url,
       br.name_i18n AS producer_name_i18n
FROM collection_entries ce
JOIN beverages b ON b.id = ce.beverage_id
JOIN producers br ON br.id = b.producer_id
WHERE ce.collection_id = $1
  AND ($2::timestamptz IS NULL OR ce.added_at < $2)
ORDER BY ce.added_at DESC
LIMIT 51;
```

```sql
-- 12c. Add a beverage to a collection (idempotent).
INSERT INTO collection_entries (collection_id, beverage_id, note)
VALUES ($1, $2, $3)
ON CONFLICT (collection_id, beverage_id) DO UPDATE
  SET note = EXCLUDED.note;
```

```sql
-- 12d. Remove a beverage.
DELETE FROM collection_entries
WHERE collection_id = $1 AND beverage_id = $2;
```

```sql
-- 12e. Collection picker pre-checked state: which of my collections already
-- contain this beverage?
SELECT c.id FROM collections c
JOIN collection_entries ce ON ce.collection_id = c.id
WHERE c.user_id = $1
  AND c.deleted_at IS NULL
  AND ce.beverage_id = $2;
```

For the `PUT /beverages/:id/collections {ids: [...]}` set-semantics endpoint suggested in HANDOFF, Go runs in a transaction:
1. `12e` to read current set.
2. Compute add/remove deltas.
3. Apply `12c` for additions and `12d` for removals.

---

## 13. i18n fallback resolution in queries

For server-side resolution of `ko → en` / `ja → en` (HANDOFF preference), use:

```sql
SELECT COALESCE(name_i18n->>$1, name_i18n->>'en') AS resolved_name
FROM beverages WHERE id = $2;
```

`$1` is the user's locale (`'en'` | `'ja'` | `'ko'`). When the user's locale is `en`, the fallback collapses to a no-op.

The backend can choose to resolve at the API boundary and emit `name` as a flat string + `name_i18n` as the full object, depending on bandwidth/contract preferences. The DB exposes both.

---

## 14. Read patterns NOT explicitly listed

For everything else — edit profile, change email, change password, account deletion, beverage addition request submission — the queries are straightforward single-table writes guarded by the same conventions (soft-delete filter, ownership check, RETURNING for the response shape). The backend can derive them from the column lists in `schema.md` and the CHECK constraints in `migrations/001_initial.sql`.

---

## 15. Cache coherence (Stage 4)

KAMOS runs N stateless API replicas behind a load balancer. Hot reads pass through three coherence tiers:

1. **L1 — per-replica typed `cache.Caches`** (`backend/internal/cache/caches.go`). In-process LRU + TTL for taxonomy, beverage detail, and producer detail. Each replica holds its own copy; writes invalidate the local copy synchronously.
2. **L2 — `cache.Backend`** (`backend/internal/cache/backend.go`). Optional shared adapter. Default `in_process` (per-replica only); production multi-replica deploys set `CACHE_BACKEND=redis` + `CACHE_REDIS_URL` for cross-replica visibility. The Redis adapter uses SCAN + UNLINK for prefix busts.
3. **Cross-replica bus — Postgres `LISTEN/NOTIFY`** on the `kamos_cache_invalidate` channel. Every write path that busts L1 also calls `cache.NotifyInvalidation(ctx, db, log, payload)`. Each replica runs one `cache.Invalidator` goroutine that holds a hijacked pgx connection, listens, and routes arriving payloads to `Caches.InvalidatePrefix`.

**Payload grammar:**

| Payload                 | Effect                                          |
| ----------------------- | ----------------------------------------------- |
| `taxonomy`              | Bust `Categories` + `FlavorTags`                |
| `beverage:<uuid>`       | Bust `BeverageDetail` rows prefixed `<uuid>:`   |
| `producer:<uuid>`       | Bust `ProducerDetail` rows prefixed `<uuid>:`   |

**Eventual-consistency window:** the write-path local L1 bust is immediate; peer replicas observe the bust on the order of single-digit milliseconds under nominal load (NOTIFY → backend forwarding → `WaitForNotification` deliver). Combined with HTTP `Cache-Control` ceilings (`max-age=300` on beverages, `max-age=3600` on taxonomy), the cross-replica stale-read ceiling is **sub-second in normal operation, bounded at the HTTP TTL in the pathological case** (e.g. a downed invalidator that hasn't reconnected yet — the loop self-heals with 500ms → 30s exponential backoff).

**Failure modes & guarantees:**

- A failed `NotifyInvalidation` logs `cache_notify_failed` and returns; the local write is already committed and the local replica is already coherent.
- A disconnected invalidator logs `cache_invalidator_disconnected` and reconnects with backoff. While disconnected, peer replicas drift up to the L1 TTL ceiling on the relevant key (`5m` beverage, `10m` producer, `1h` taxonomy).
- Schema additions that introduce new prefixes do NOT crash the invalidator — `Caches.InvalidatePrefix` no-ops on unknown payloads.
- The pgx connection is hijacked out of the pool (`Conn.Hijack()`) so the listener cannot be silently recycled mid-flight. Closed explicitly during shutdown.
