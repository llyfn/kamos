---
name: db-schema
description: "KAMOS PostgreSQL schema design skill. Use this to design database tables, write migration SQL files, define indexes, and document query patterns for the KAMOS beverage tracking platform. Invoke whenever schema design, migration writing, table creation, indexing, or database modeling work is requested. Triggers: schema, migration, table, ERD, index, RLS, PostgreSQL, query pattern."
---

# DB Schema Skill

Designs the PostgreSQL data model for KAMOS: normalized tables, migrations, indexes, and annotated query patterns the backend engineer will implement.

## Output structure

```
migrations/
├── 001_initial.sql
├── 002_*.sql
└── ...
docs/db/
├── schema.md          — ERD narrative + design decisions
├── indexes.md
└── query_patterns.md
```

Write migrations to `migrations/` at the repo root and design docs to `docs/db/`. There is no workspace fallback.

## Workflow

1. Read `design/HANDOFF.md` and `SPEC.md`. Every screen data shape listed in the handoff must trace to a column.
2. Apply the entity rules below.
3. Write migrations in numerical order, each in a single transaction.
4. Document indexes per query pattern.
5. Annotate query patterns the backend will translate to Go.

## Entity rules

Every table:

```sql
id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

`updated_at` is maintained by trigger:

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- repeat per table that mutates
```

Never use `SERIAL` — UUIDs everywhere.

i18n text: `JSONB` keyed by locale (`{"en": "...", "ja": "...", "ko": "..."}`). Do not use a translations table for canonical content. User-generated content (review text, notes) is stored as-is in plain text — no translation, per `SPEC §8`.

Soft-delete: `deleted_at TIMESTAMPTZ` on `users`, `check_ins`, `collections`. Every list query against these must filter `WHERE deleted_at IS NULL`.

## SPEC invariants — encode in the schema

Canonical values live in **`specs/invariants.yaml`**. Restate the value once in a CHECK constraint at the column's owning migration; don't paste the number elsewhere. The pattern:

```sql
-- Rating grid (specs/invariants.yaml rating.*)
rating NUMERIC(3,2) CHECK (
  rating >= 0.5 AND rating <= 5.0 AND (rating * 100)::int % 25 = 0
)

-- Username (specs/invariants.yaml username.storage_regex)
username TEXT NOT NULL CHECK (username ~ '^[a-z0-9_]{3,30}$')

-- Text caps (specs/invariants.yaml bio.max_chars, review_text.max_chars, …)
bio TEXT CHECK (char_length(bio) <= 200)
review_text TEXT CHECK (char_length(review_text) <= 500)
notes TEXT CHECK (char_length(notes) <= 200)
name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50)

-- Photos: submission cap is 1 (enforced in Go using spec.PhotosMaxPerSubmission).
-- Existing rows with up to 4 must remain readable, so the legacy sort_order
-- range (0..3) stays in place at the DB layer.
sort_order SMALLINT NOT NULL CHECK (sort_order BETWEEN 0 AND 3)
UNIQUE (check_in_id, sort_order)
```

When the YAML value changes, update the next migration, NOT the original — migrations are append-only.

## KAMOS entity checklist

**Users & auth**

```sql
users (
  id, username, email, email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  password_hash TEXT,                 -- NULL if Google-only
  google_sub TEXT UNIQUE,             -- NULL if email-only
  display_name TEXT NOT NULL CHECK (char_length(display_name) <= 50),
  avatar_url TEXT,
  bio TEXT CHECK (char_length(bio) <= 200),
  locale TEXT NOT NULL DEFAULT 'en' CHECK (locale IN ('en','ja','ko')),
  is_private BOOLEAN NOT NULL DEFAULT FALSE,  -- SPEC §5.1
  deleted_at TIMESTAMPTZ,
  username_release_at TIMESTAMPTZ              -- SPEC §3.3: 30-day hold
)

email_verifications (id, user_id FK, token, expires_at, used_at)
```

**Beverage catalog**

```sql
beverage_categories (
  id, slug TEXT UNIQUE NOT NULL,        -- 'nihonshu', 'shochu', 'liqueur'
  name_i18n JSONB NOT NULL              -- exact strings per SPEC §2.1
)

producers (
  id, name_i18n JSONB NOT NULL,         -- en + ja required at app layer
  region TEXT, prefecture TEXT,
  founded_year INT, website TEXT,
  description_i18n JSONB
)

beverages (
  id, producer_id FK,
  name_i18n JSONB NOT NULL,             -- en + ja required at app layer
  category_id FK,
  subcategory TEXT,                     -- free text from predefined list
  alcohol_pct NUMERIC(4,1),
  rice_polishing_ratio NUMERIC(4,1),    -- nullable, nihonshu only
  flavor_profile TEXT[],                -- canonical aggregate, not user-derived
  region TEXT,
  description_i18n JSONB,
  label_image_url TEXT,
  avg_rating NUMERIC(3,2),              -- denormalized for display
  checkin_count INT NOT NULL DEFAULT 0
)
```

**Check-ins**

```sql
flavor_tags (
  id, slug TEXT UNIQUE NOT NULL,
  dimension TEXT NOT NULL CHECK (dimension IN ('sweetness','body','acidity','character','finish')),
  name_i18n JSONB NOT NULL
)

check_ins (
  id, user_id FK, beverage_id FK,
  rating NUMERIC(3,1) CHECK (rating >= 0.5 AND rating <= 5.0 AND (rating * 2) = FLOOR(rating * 2)),
  review_text TEXT CHECK (char_length(review_text) <= 500),
  price_amount NUMERIC(10,2),
  price_currency CHAR(3),
  price_unit TEXT CHECK (price_unit IN ('serving','bottle')),
  purchase_type TEXT CHECK (purchase_type IN ('on_premise','retail','gift','other')),
  -- venue_id FK NULLABLE  -- v1.1 only, do not include in MVP migrations
  deleted_at TIMESTAMPTZ
)

check_in_photos (
  id, check_in_id FK,
  storage_key TEXT NOT NULL, url TEXT NOT NULL,
  width INT, height INT,
  sort_order SMALLINT NOT NULL CHECK (sort_order BETWEEN 0 AND 3),
  UNIQUE (check_in_id, sort_order)
)

check_in_flavor_tags (
  check_in_id FK, flavor_tag_id FK,
  PRIMARY KEY (check_in_id, flavor_tag_id)
)
```

**Social**

```sql
follows (
  follower_id FK REFERENCES users(id),
  followed_id FK REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'accepted' CHECK (status IN ('pending','accepted')),  -- SPEC §5.1: pending for private profiles
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (follower_id, followed_id),
  CHECK (follower_id <> followed_id)
)

toasts (    -- SPEC §5.3
  user_id FK, check_in_id FK,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, check_in_id)
)
```

**Collections** — `SPEC §6` says collections are user-created lists; `Inventory` and `Wishlist` are pre-created on signup but otherwise behave identically.

```sql
collections (
  id, user_id FK,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50),
  is_default BOOLEAN NOT NULL DEFAULT FALSE,    -- true for the auto-created Inventory + Wishlist
  deleted_at TIMESTAMPTZ
)

collection_entries (
  collection_id FK, beverage_id FK,
  notes TEXT CHECK (char_length(notes) <= 200),
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (collection_id, beverage_id)
)
```

**Default collection creation** — SPEC §6.1 mandates that every new user starts with `Inventory` and `Wishlist`. Decide once whether to handle this in:

1. The application layer (registration handler creates the user + 2 collections in one transaction), or
2. A trigger on `users` insert.

Option 1 is more visible in code review and easier to localize the names per the user's chosen `locale`. Document the choice in `schema.md`; do not implement both.

## Indexes

Document in `indexes.md` and add `CREATE INDEX` to the relevant migration.

**Search columns: bigm + materialized.** Project invariant per `.claude/CLAUDE.md` "Search invariants": every searchable text column gets a `gin_bigm_ops` GIN index in the same migration that introduces it. For cross-field / i18n search, build a `search_text TEXT` materialized column populated by `BEFORE INSERT/UPDATE` triggers (the lowercased concat shape) and bigm-index it. Reference template: `migrations/003_search_text_bigm.sql` (helpers `kamos_compute_*_search_text`, wrappers `kamos_trg_*_search_text`, prefecture-rename cascade). Do NOT introduce `pg_trgm`, `to_tsvector`, or `websearch_to_tsquery` for new search paths; bigm subsumes them for KAMOS's CJK-first content. `pg_bigm` is supplied by the custom kamos-db image (`docs/runbooks/deploy.md §1a`).

```sql
-- Feed query: check-ins from followed users, recent first
CREATE INDEX idx_check_ins_user_created ON check_ins (user_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_follows_follower      ON follows (follower_id) WHERE status = 'accepted';
CREATE INDEX idx_follows_followed      ON follows (followed_id) WHERE status = 'accepted';

-- Beverage search and browse
CREATE INDEX idx_beverages_category    ON beverages (category_id);
CREATE INDEX idx_beverages_producer    ON beverages (producer_id);
CREATE INDEX idx_beverages_name_gin    ON beverages USING GIN (name_i18n);
CREATE INDEX idx_producers_name_gin    ON producers USING GIN (name_i18n);

-- User lookup (case-insensitive per SPEC §3.2)
CREATE UNIQUE INDEX idx_users_username ON users (LOWER(username)) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_users_email    ON users (LOWER(email))    WHERE deleted_at IS NULL;

-- Check-in detail joins
CREATE INDEX idx_check_in_photos_ci    ON check_in_photos (check_in_id, sort_order);
CREATE INDEX idx_check_in_flavor_tags_ci ON check_in_flavor_tags (check_in_id);

-- Toasts on check-ins
CREATE INDEX idx_toasts_check_in       ON toasts (check_in_id);
```

## Query patterns

Document in `query_patterns.md` with annotated SQL — backend implements as `pgx` repository functions:

```sql
-- Feed: cursor-paginated check-ins from accepted-followed users (SPEC §5.2)
SELECT
  ci.id, ci.rating, ci.review_text, ci.created_at,
  u.id AS user_id, u.username, u.avatar_url,
  b.id AS beverage_id, b.name_i18n AS beverage_name,
  pr.name_i18n AS producer_name,
  COALESCE(t_count.cnt, 0) AS toast_count
FROM check_ins ci
JOIN follows f ON f.followed_id = ci.user_id AND f.status = 'accepted'
JOIN users u    ON u.id = ci.user_id AND u.deleted_at IS NULL
JOIN beverages b ON b.id = ci.beverage_id
JOIN producers pr ON pr.id = b.producer_id
LEFT JOIN LATERAL (SELECT COUNT(*) AS cnt FROM toasts t WHERE t.check_in_id = ci.id) t_count ON TRUE
WHERE f.follower_id = $1
  AND ci.deleted_at IS NULL
  AND (ci.created_at, ci.id) < ($2, $3)   -- cursor: (created_at, id) tuple
ORDER BY ci.created_at DESC, ci.id DESC
LIMIT 21;                                  -- 20 + 1 to detect has_more
```

Cursor format: encode `(created_at, id)` as base64 JSON. Always tuple-paginate when `created_at` is not unique.

## Migration file format

```sql
-- 001_initial.sql
BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users ( ... );
-- ...

COMMIT;
```

Each migration is one transaction. Number sequentially. Never edit a deployed migration — add a new one. Migrations are append-only.

## Output checklist

- [ ] Every API response field traces to a column or computed expression
- [ ] Text/rating/regex caps match `specs/invariants.yaml` and are enforced as CHECK constraints
- [ ] Username CHECK enforces lowercase + character class
- [ ] Soft-delete columns on users, check_ins, collections
- [ ] `username_release_at` on users for the username hold (`soft_delete.username_hold_days` in YAML)
- [ ] Default collection creation strategy documented in schema.md
- [ ] All foreign keys explicit, no orphans possible
- [ ] Indexes cover every query pattern's WHERE + ORDER BY leading columns
