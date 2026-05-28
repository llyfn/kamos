-- 001_initial.sql
-- KAMOS — consolidated baseline schema (post-020 final state).
--
-- This file is a SQUASH of the original 001..020 migration history into a
-- single DDL baseline that reproduces the exact production schema. It carries
-- no seed data — taxonomy/reference rows live in 002_seed_taxonomy.sql.
--
-- It is recorded in schema_migrations as `001_initial.sql` (unchanged filename)
-- so production, which already has 001..020 applied, never re-runs it. A fresh
-- environment applies 001 + 002 and is then at parity with production.
--
-- One transaction. Append-only: future changes go in a new file (021_…).
-- Traces: SPEC.md §2-§8 plus the post-MVP roadmap (refresh tokens, photo
-- uploads, venues, RBAC + moderation log, public collections, flat comments,
-- regions/prefectures, producer rename, notifications).
--
-- A NOTE ON CONSTRAINT NAMES: several objects retain identifiers from the
-- pre-rename era because PostgreSQL's ALTER … RENAME does not rewrite the
-- names of primary keys, foreign keys, or (PG18) the per-column NOT NULL
-- constraints. The `breweries → producers` rename (historical migration 017)
-- is the source of every `breweries_*` / `beverages_brewery_id_*` identifier
-- below. They are spelled out explicitly so this consolidated file produces a
-- byte-identical catalog to the sequential history. Do not "tidy" them.

BEGIN;

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid() + digest()

-- ===========================================================================
-- ENUM TYPES
-- ===========================================================================
-- These were introduced across the history (photo_upload_status in the photo-
-- upload migration, user_role with the RBAC migration, the collection and
-- moderation enums with the public-collections + moderation-log migration).
-- The moderation enums later gained catalog-CRUD values and had 'brewery'
-- renamed to 'producer'; the value lists below are the final ordered sets.

CREATE TYPE collection_visibility AS ENUM ('private', 'public');

-- moderation_action_type: 'soft_delete'/'role_change'/'suspend'/'approve'/
-- 'reject' shipped with the moderation log; 'create'/'update'/'restore' were
-- appended when admin catalog CRUD started writing audit rows.
CREATE TYPE moderation_action_type AS ENUM (
  'soft_delete', 'role_change', 'suspend', 'approve', 'reject',
  'create', 'update', 'restore'
);

-- moderation_target_type: 'check_in'/'comment'/'user'/'beverage_request'
-- shipped with the log; 'beverage'/'brewery' were appended for catalog CRUD;
-- 'brewery' was then renamed to 'producer' (so it sorts in the appended slot,
-- not alphabetically).
CREATE TYPE moderation_target_type AS ENUM (
  'check_in', 'comment', 'user', 'beverage_request', 'beverage', 'producer'
);

-- photo_upload_status: 'uploaded' is reserved for a future server-side
-- HEAD-verify step; we never set it today but keep it in the enum.
CREATE TYPE photo_upload_status AS ENUM (
  'pending', 'uploaded', 'attached', 'orphaned'
);

CREATE TYPE user_role AS ENUM ('user', 'moderator', 'admin');

-- ---------------------------------------------------------------------------
-- Shared trigger function: keep updated_at fresh on row mutation.
-- Attached per-table further down.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===========================================================================
-- USERS  (SPEC §3)
-- ===========================================================================
-- - `username`: stored lowercase, regex-enforced (SPEC §3.2 / §6.3).
-- - `display_username`: case as entered at registration (rendered in UI).
-- - `email`: stored as-entered; uniqueness via LOWER() partial index.
-- - `password_hash` nullable: Google-only users have no password.
-- - `google_sub` nullable: email-only users.
-- - `deleted_at` enables soft-delete (SPEC §3.3).
-- - `username_release_at`: when the lowercase handle becomes available for
--    re-registration. Set to `deleted_at + interval '30 days'` on delete.
-- - `role`: RBAC enum (user/moderator/admin). Single-column enum chosen over a
--    relational user_roles table — YAGNI until per-resource permissions or
--    multiple concurrent roles per user actually appear.
CREATE TABLE users (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username                      TEXT        NOT NULL,
  display_username              TEXT        NOT NULL,
  email                         TEXT        NOT NULL,
  email_verified                BOOLEAN     NOT NULL DEFAULT FALSE,
  password_hash                 TEXT,
  google_sub                    TEXT,
  display_name                  TEXT        NOT NULL,
  avatar_url                    TEXT,
  bio                           TEXT,
  locale                        TEXT        NOT NULL DEFAULT 'en',
  privacy_mode                  TEXT        NOT NULL DEFAULT 'public',
  deleted_at                    TIMESTAMPTZ,
  username_release_at           TIMESTAMPTZ,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  role                          USER_ROLE   NOT NULL DEFAULT 'user',

  -- SPEC §3.2 / §6.3: lowercase + alnum/underscore, 3-30 chars.
  CONSTRAINT users_username_format
    CHECK (username ~ '^[a-z0-9_]{3,30}$'),

  -- Display username preserves case but otherwise same charset/length.
  CONSTRAINT users_display_username_format
    CHECK (display_username ~ '^[A-Za-z0-9_]{3,30}$'),

  -- LOWER(display_username) must equal username (defensive coherence check).
  CONSTRAINT users_display_username_matches_lower
    CHECK (LOWER(display_username) = username),

  CONSTRAINT users_display_name_length
    CHECK (char_length(display_name) BETWEEN 1 AND 50),

  CONSTRAINT users_bio_length
    CHECK (bio IS NULL OR char_length(bio) <= 200),

  CONSTRAINT users_locale_allowed
    CHECK (locale IN ('en', 'ja', 'ko')),

  CONSTRAINT users_privacy_allowed
    CHECK (privacy_mode IN ('public', 'private')),

  -- At least one auth method must exist.
  CONSTRAINT users_auth_method_present
    CHECK (password_hash IS NOT NULL OR google_sub IS NOT NULL),

  -- Soft-delete coherence.
  CONSTRAINT users_release_implies_delete
    CHECK ((deleted_at IS NULL AND username_release_at IS NULL)
        OR (deleted_at IS NOT NULL AND username_release_at IS NOT NULL))
);

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Username uniqueness:
-- - Live users hold the lowercase handle exclusively via this partial index.
-- - Soft-deleted users continue to hold the handle until `username_release_at`,
--   enforced at registration time by an explicit query (see query_patterns.md).
--   We deliberately do not create a "held" partial index involving NOW(),
--   because partial-index predicates must be IMMUTABLE (NOW() is STABLE).
-- SPEC §3.3 / §6.3.
CREATE UNIQUE INDEX idx_users_username_live
  ON users (username)
  WHERE deleted_at IS NULL;

-- B-tree index on the held set so the registration-time "is this handle
-- still held?" query is fast. Not unique — two soft-deleted users could
-- historically share a handle (one re-registered after the first's release,
-- then both eventually soft-deleted). The application enforces "no live row
-- exists AND no held row exists" at registration via the query in
-- query_patterns.md.
CREATE INDEX idx_users_username_held
  ON users (username, username_release_at)
  WHERE deleted_at IS NOT NULL;

-- Email uniqueness: case-insensitive among live users.
CREATE UNIQUE INDEX idx_users_email_live
  ON users (LOWER(email))
  WHERE deleted_at IS NULL;

-- Google sub uniqueness: among live users.
CREATE UNIQUE INDEX idx_users_google_sub_live
  ON users (google_sub)
  WHERE deleted_at IS NULL AND google_sub IS NOT NULL;

-- SEC-006 support: the in-memory soft-delete cache refreshes its set every
-- interval from `SELECT id FROM users WHERE deleted_at > now() - INTERVAL …`.
-- This partial index makes that refresh query indexable instead of a seq-scan.
CREATE INDEX idx_users_deleted_at_recent
  ON users (deleted_at)
  WHERE deleted_at IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Email verification tokens.
-- 24h expiry per SPEC §3.1. One active token per address at a time enforced
-- in the application; multiple historical rows allowed for audit.
--
-- SEC-004: we store only the SHA-256 hash of the token (`token_hash`), never
-- the raw token string the user clicks through their email — same hashed-
-- secret discipline as refresh_tokens.token_hash. A DB read or backup leak
-- therefore cannot reconstruct a live verification URL.
-- ---------------------------------------------------------------------------
CREATE TABLE email_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  token_hash  BYTEA NOT NULL
);

-- Unique among UNUSED verification rows. We don't filter on expires_at in the
-- predicate because NOW() is not IMMUTABLE and Postgres refuses the index.
-- used_at IS NULL is enough — the cleanup job hard-deletes rows after the 24h
-- window, and the application still re-checks expires_at on read. Token
-- entropy is 256 bits so a clash on an expired-but-unused row is
-- astronomically unlikely.
CREATE UNIQUE INDEX idx_email_verifications_token_hash
  ON email_verifications (token_hash)
  WHERE used_at IS NULL;

CREATE INDEX idx_email_verifications_user
  ON email_verifications (user_id);

-- ===========================================================================
-- BEVERAGE CATALOG  (SPEC §2)
-- ===========================================================================

-- Categories — three rows seeded in 002_seed_taxonomy.sql. `slug` is the
-- stable API key; `name_i18n` carries the SPEC §2.1 canonical strings.
CREATE TABLE beverage_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL,
  name_i18n   JSONB NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT beverage_categories_slug_format
    CHECK (slug IN ('nihonshu', 'shochu', 'liqueur')),

  -- Canonical SPEC §2.1 strings must exist in en + ja + ko.
  CONSTRAINT beverage_categories_name_complete
    CHECK (
      name_i18n ? 'en' AND
      name_i18n ? 'ja' AND
      name_i18n ? 'ko'
    )
);
CREATE UNIQUE INDEX idx_beverage_categories_slug
  ON beverage_categories (slug);

CREATE TRIGGER trg_beverage_categories_updated_at
  BEFORE UPDATE ON beverage_categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ===========================================================================
-- REGIONS + PREFECTURES  (Japan locality reference, i18n)
-- ===========================================================================
-- Controlled vocabulary backing producer locality, replacing the old free-text
-- prefecture/region columns (which drifted: "Niigata" / "新潟" / "新潟県").
-- Same name_i18n JSONB pattern as beverage_categories and flavor_tags. Seeded
-- in 002_seed_taxonomy.sql. Country dimension is intentionally out of scope —
-- MVP is Japan-only; a countries table can be added later without disturbing
-- the FK chain. Defined here (ahead of producers) because producers.prefecture_id
-- FK-references prefectures and this is one transaction.

-- regions — Japan's 8 traditional regions. All three locales required because
-- these are seed-only and always rendered localized.
CREATE TABLE regions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL UNIQUE,
  name_i18n   JSONB NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT regions_name_has_en_ja_ko
    CHECK (name_i18n ? 'en' AND name_i18n ? 'ja' AND name_i18n ? 'ko')
);

-- prefectures — Japan's 47 prefectures, FK'd to a region. sort_order = JIS
-- prefecture code (Hokkaido=1 … Okinawa=47), the canonical Japanese order.
CREATE TABLE prefectures (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region_id   UUID NOT NULL REFERENCES regions(id) ON DELETE RESTRICT,
  slug        TEXT NOT NULL UNIQUE,
  name_i18n   JSONB NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT prefectures_name_has_en_ja_ko
    CHECK (name_i18n ? 'en' AND name_i18n ? 'ja' AND name_i18n ? 'ko')
);

CREATE INDEX idx_prefectures_region_id
  ON prefectures (region_id);

-- Producers (SPEC §2.3) — historically `breweries`, renamed because the same
-- catalog row type holds shochu distilleries and liqueur makers, none of which
-- "brew". The rename was in-place (ALTER TABLE … RENAME), so the table's PK,
-- prefecture FK, NOT NULL constraints, and updated_at trigger all keep their
-- original `breweries_*` / `trg_breweries_*` identifiers. They are spelled out
-- explicitly here to reproduce the post-rename catalog byte-for-byte.
-- - `name_i18n`: { en, ja, ko? } — en + ja required at app layer; we enforce
--    `en` and `ja` presence here as a defensive check.
-- - `description_i18n`: optional, no presence check.
-- - `prefecture_id`: FK to the prefectures reference table (replaced the old
--    free-text prefecture/region columns to kill denormalization drift).
-- - `beverage_count`: trigger-maintained count of this producer's beverages.
-- - `deleted_at`: admin soft-delete (hard-delete is blocked by ON DELETE
--    RESTRICT from beverages).
CREATE TABLE producers (
  id                  UUID
    CONSTRAINT breweries_id_not_null NOT NULL
    PRIMARY KEY DEFAULT gen_random_uuid(),
  name_i18n           JSONB
    CONSTRAINT breweries_name_i18n_not_null NOT NULL,
  founded_year        SMALLINT,
  website             TEXT,
  description_i18n    JSONB,
  created_at          TIMESTAMPTZ DEFAULT NOW()
    CONSTRAINT breweries_created_at_not_null NOT NULL,
  updated_at          TIMESTAMPTZ DEFAULT NOW()
    CONSTRAINT breweries_updated_at_not_null NOT NULL,
  beverage_count      INTEGER DEFAULT 0
    CONSTRAINT breweries_beverage_count_not_null NOT NULL,
  deleted_at          TIMESTAMPTZ,
  prefecture_id       UUID
    CONSTRAINT breweries_prefecture_id_fkey REFERENCES prefectures(id) ON DELETE RESTRICT,

  CONSTRAINT breweries_name_has_en_ja
    CHECK (name_i18n ? 'en' AND name_i18n ? 'ja'),

  CONSTRAINT breweries_founded_year_range
    CHECK (founded_year IS NULL OR (founded_year BETWEEN 800 AND 2100)),

  CONSTRAINT producers_beverage_count_nonneg
    CHECK (beverage_count >= 0)
);

-- The primary key constraint keeps its pre-rename name.
ALTER TABLE producers RENAME CONSTRAINT producers_pkey TO breweries_pkey;

CREATE TRIGGER trg_breweries_updated_at
  BEFORE UPDATE ON producers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Producer FTS index for cross-locale name search. Partial on live rows so the
-- public catalog path never scans soft-deleted producers.
CREATE INDEX idx_producers_name_tsv
  ON producers USING GIN (
    to_tsvector('simple',
      coalesce(name_i18n ->> 'en', '') || ' ' ||
      coalesce(name_i18n ->> 'ja', '') || ' ' ||
      coalesce(name_i18n ->> 'ko', '')
    )
  )
  WHERE deleted_at IS NULL;

-- Partial index for admin filtering and producer-detail prefecture joins.
CREATE INDEX idx_producers_prefecture_id
  ON producers (prefecture_id)
  WHERE deleted_at IS NULL;

-- "Trash" helper — used only by admin include_deleted queries. Partial keeps
-- it tiny; the dominant write path (deleted_at IS NULL) never touches it.
CREATE INDEX idx_producers_deleted_at
  ON producers (deleted_at)
  WHERE deleted_at IS NOT NULL;

-- Beverages (SPEC §2.2).
-- - `polishing_ratio` only valid for nihonshu (CHECK with category lookup).
--    Implemented via a row-level CHECK that delegates to category_slug,
--    a denormalized column kept in sync via FK + trigger.
-- - `avg_rating` and `check_in_count` are running denormalized aggregates
--    maintained by triggers on check_ins (see end of file).
-- - `producer_id`: historically `brewery_id`; renamed with the table rename.
--    Its NOT NULL constraint keeps the original `beverages_brewery_id_not_null`
--    name (spelled out below), but the FK was explicitly renamed to
--    `beverages_producer_id_fkey`.
-- - prefecture/region: removed — locality is derived through
--    beverages.producer_id -> producers.prefecture_id -> prefectures.region_id.
-- - `deleted_at`: admin soft-delete.
CREATE TABLE beverages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  producer_id         UUID
    CONSTRAINT beverages_brewery_id_not_null NOT NULL
    CONSTRAINT beverages_producer_id_fkey REFERENCES producers(id) ON DELETE RESTRICT,
  category_id         UUID NOT NULL REFERENCES beverage_categories(id) ON DELETE RESTRICT,
  category_slug       TEXT NOT NULL,   -- denormalized for the polishing-ratio CHECK
  name_i18n           JSONB NOT NULL,
  subcategory_i18n    JSONB,            -- e.g. {en:'Junmai Daiginjo', ja:'純米大吟醸', ko:'…'}
  abv                 NUMERIC(4,1),
  polishing_ratio     SMALLINT,         -- nihonshu only
  flavor_profile      TEXT[] NOT NULL DEFAULT '{}',  -- aggregate tag slugs
  description_i18n    JSONB,
  label_image_url     TEXT,
  avg_rating          NUMERIC(3,2),     -- denormalized; NULL when no ratings
  check_in_count      INTEGER NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ,

  CONSTRAINT beverages_name_has_en_ja
    CHECK (name_i18n ? 'en' AND name_i18n ? 'ja'),

  CONSTRAINT beverages_category_slug_allowed
    CHECK (category_slug IN ('nihonshu', 'shochu', 'liqueur')),

  -- SPEC §2.2: polishing ratio only valid for nihonshu.
  CONSTRAINT beverages_polishing_ratio_nihonshu_only
    CHECK (
      polishing_ratio IS NULL
      OR (category_slug = 'nihonshu' AND polishing_ratio BETWEEN 1 AND 100)
    ),

  -- ABV sanity.
  CONSTRAINT beverages_abv_range
    CHECK (abv IS NULL OR (abv >= 0 AND abv <= 70)),

  -- check_in_count must not go negative.
  CONSTRAINT beverages_check_in_count_nonneg
    CHECK (check_in_count >= 0)
);

CREATE TRIGGER trg_beverages_updated_at
  BEFORE UPDATE ON beverages
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Keep beverages.category_slug consistent with beverage_categories.slug.
-- This guards against the app forgetting to set category_slug at write time.
CREATE OR REPLACE FUNCTION sync_beverage_category_slug()
RETURNS TRIGGER AS $$
BEGIN
  SELECT slug INTO NEW.category_slug
  FROM beverage_categories
  WHERE id = NEW.category_id;
  IF NEW.category_slug IS NULL THEN
    RAISE EXCEPTION 'beverage_categories row not found for id %', NEW.category_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_beverages_sync_category_slug
  BEFORE INSERT OR UPDATE OF category_id ON beverages
  FOR EACH ROW EXECUTE FUNCTION sync_beverage_category_slug();

-- Beverage indexes (documented in indexes.md). All public-read indexes are
-- partial on live rows so the planner keeps using them on the hot public
-- catalog path without filtering soft-deleted rows post-fetch.
CREATE INDEX idx_beverages_producer
  ON beverages (producer_id)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_category
  ON beverages (category_id)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_name_gin
  ON beverages USING GIN (name_i18n jsonb_path_ops)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_name_tsv
  ON beverages USING GIN (
    to_tsvector('simple',
      coalesce(name_i18n ->> 'en', '') || ' ' ||
      coalesce(name_i18n ->> 'ja', '') || ' ' ||
      coalesce(name_i18n ->> 'ko', '')
    )
  )
  WHERE deleted_at IS NULL;

CREATE INDEX idx_beverages_avg_rating_desc
  ON beverages (category_id, avg_rating DESC NULLS LAST)
  WHERE deleted_at IS NULL AND check_in_count >= 3;

-- Popularity keyset for the beverage list: the cursor encodes
-- (check_in_count, created_at, id) so a forward seek can walk the index in
-- order with stable ties. Full-table (not partial) — the unfiltered list
-- excludes nothing.
CREATE INDEX idx_beverages_popularity_keyset
  ON beverages (check_in_count DESC, created_at DESC, id DESC);

-- "Trash" helper for admin include_deleted queries.
CREATE INDEX idx_beverages_deleted_at
  ON beverages (deleted_at)
  WHERE deleted_at IS NOT NULL;

-- ===========================================================================
-- FLAVOR TAGS  (SPEC §4.3)
-- ===========================================================================
CREATE TABLE flavor_tags (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        TEXT NOT NULL,
  dimension   TEXT NOT NULL,
  name_i18n   JSONB NOT NULL,
  sort_order  SMALLINT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT flavor_tags_dimension_allowed
    CHECK (dimension IN ('sweetness', 'body', 'acidity', 'character', 'finish')),

  CONSTRAINT flavor_tags_name_has_en
    CHECK (name_i18n ? 'en')
);

CREATE UNIQUE INDEX idx_flavor_tags_slug
  ON flavor_tags (slug);

CREATE INDEX idx_flavor_tags_dimension
  ON flavor_tags (dimension, sort_order);

CREATE TRIGGER trg_flavor_tags_updated_at
  BEFORE UPDATE ON flavor_tags
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Aggregate flavor tags on a beverage (admin-curated, separate from check-in
-- tags). Renders the "Aggregated flavor" section on BeverageScreen.
-- We keep it as a junction even though beverages.flavor_profile holds the
-- slugs as an array — junction supports clean joins for filtering.
CREATE TABLE beverage_flavor_tags (
  beverage_id     UUID NOT NULL REFERENCES beverages(id) ON DELETE CASCADE,
  flavor_tag_id   UUID NOT NULL REFERENCES flavor_tags(id) ON DELETE RESTRICT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (beverage_id, flavor_tag_id)
);
CREATE INDEX idx_beverage_flavor_tags_tag
  ON beverage_flavor_tags (flavor_tag_id);

-- ===========================================================================
-- VENUES  (post-MVP roadmap, Foursquare-backed)
-- ===========================================================================
-- Optional venue tag on check-ins. Venues live as long as any check-in
-- references them; on check-in delete the FK is SET NULL and orphan venue rows
-- are kept (cheap, low cardinality). No background cleanup job.
--
-- The user-controlled text fields carry backstop length caps — the
-- application-layer validator is the primary enforcement, these CHECKs catch
-- any path that bypasses it (e.g. direct admin DB writes). The lat/lng range
-- checks stay anonymous (auto-named venues_lat_check / venues_lng_check) to
-- match the catalog.
CREATE TABLE venues (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- foursquare_id is nullable so free-form (non-Foursquare) venues can also
  -- live here in a future phase. UNIQUE so we can upsert on conflict.
  foursquare_id   TEXT UNIQUE,
  name            TEXT NOT NULL,
  address         TEXT,
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  country         TEXT,
  prefecture      TEXT,
  locality        TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CHECK (lat IS NULL OR (lat BETWEEN -90 AND 90)),
  CHECK (lng IS NULL OR (lng BETWEEN -180 AND 180)),

  CONSTRAINT venues_name_length
    CHECK (char_length(name) BETWEEN 1 AND 200),
  CONSTRAINT venues_address_length
    CHECK (address IS NULL OR char_length(address) <= 500),
  CONSTRAINT venues_country_length
    CHECK (country IS NULL OR char_length(country) <= 100),
  CONSTRAINT venues_prefecture_length
    CHECK (prefecture IS NULL OR char_length(prefecture) <= 100),
  CONSTRAINT venues_locality_length
    CHECK (locality IS NULL OR char_length(locality) <= 100),
  CONSTRAINT venues_foursquare_id_length
    CHECK (foursquare_id IS NULL OR char_length(foursquare_id) BETWEEN 1 AND 100)
);

CREATE INDEX idx_venues_country ON venues (country);
CREATE INDEX idx_venues_prefecture ON venues (prefecture);
-- NOTE: a speculative idx_venues_name_tsv was created and then dropped in the
-- history (no current reader). Re-add when free-form local venue search lands.

-- ===========================================================================
-- CHECK-INS  (SPEC §4)
-- ===========================================================================
-- `serving_style` was dropped from MVP scope (removed in the producer-rename
-- migration alongside its CHECK). `venue_id` is the optional Foursquare tag.
-- `toast_count` / `comment_count` are trigger-maintained counter caches that
-- eliminate correlated subqueries in the feed projection.
CREATE TABLE check_ins (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  beverage_id         UUID NOT NULL REFERENCES beverages(id) ON DELETE RESTRICT,
  rating              NUMERIC(3,1),
  review_text         TEXT,
  price_amount        NUMERIC(10,2),
  price_currency      CHAR(3),
  price_unit          TEXT,             -- 'serving' | 'bottle'
  purchase_type       TEXT,             -- 'on_premise' | 'retail' | 'gift' | 'other'
  deleted_at          TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  venue_id            UUID REFERENCES venues(id) ON DELETE SET NULL,
  toast_count         INTEGER NOT NULL DEFAULT 0,
  comment_count       INTEGER NOT NULL DEFAULT 0,

  -- SPEC §4.2 / §6.2: 0.5..5.0 in 0.5 steps, optional (NULL allowed).
  -- (rating * 10)::int % 5 = 0 enforces the half-step grid.
  CONSTRAINT check_ins_rating_valid
    CHECK (
      rating IS NULL OR (
        rating >= 0.5 AND rating <= 5.0
        AND (rating * 10)::int % 5 = 0
      )
    ),

  -- SPEC §4.1 / §6.7: review ≤ 500 chars.
  CONSTRAINT check_ins_review_text_length
    CHECK (review_text IS NULL OR char_length(review_text) <= 500),

  -- Price coherence: amount + currency + unit are all-or-nothing.
  CONSTRAINT check_ins_price_coherent
    CHECK (
      (price_amount IS NULL AND price_currency IS NULL AND price_unit IS NULL)
      OR
      (price_amount IS NOT NULL AND price_currency IS NOT NULL AND price_unit IS NOT NULL
       AND price_amount >= 0)
    ),

  CONSTRAINT check_ins_price_unit_allowed
    CHECK (price_unit IS NULL OR price_unit IN ('serving', 'bottle')),

  CONSTRAINT check_ins_purchase_type_allowed
    CHECK (purchase_type IS NULL OR purchase_type IN ('on_premise', 'retail', 'gift', 'other')),

  CONSTRAINT check_ins_toast_count_nonneg
    CHECK (toast_count >= 0),

  CONSTRAINT check_ins_comment_count_nonneg
    CHECK (comment_count >= 0)
);

CREATE TRIGGER trg_check_ins_updated_at
  BEFORE UPDATE ON check_ins
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Feed / profile keyset cursor indexes (SPEC §5.2 / §6.6).
-- NOTE: a global (created_at, id) index existed in early history and was
-- dropped — no production query reads check-ins without a user_id or
-- beverage_id filter, so it was pure write amplification.
CREATE INDEX idx_check_ins_user_created
  ON check_ins (user_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_check_ins_beverage_created
  ON check_ins (beverage_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_check_ins_venue
  ON check_ins (venue_id)
  WHERE venue_id IS NOT NULL;

-- Check-in photos (SPEC §4.1 / §6.7).
-- The 4-photo cap is enforced via `sort_order BETWEEN 0 AND 3` + UNIQUE on
-- (check_in_id, sort_order). With sort_order constrained to 4 discrete values
-- and a uniqueness guarantee, there can be at most 4 rows per check_in.
-- The application is responsible for assigning the next free sort_order.
CREATE TABLE check_in_photos (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_in_id     UUID NOT NULL REFERENCES check_ins(id) ON DELETE CASCADE,
  photo_url       TEXT NOT NULL,
  storage_key     TEXT,
  width           INT,
  height          INT,
  sort_order      SMALLINT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT check_in_photos_sort_order_range
    CHECK (sort_order BETWEEN 0 AND 3)
);
CREATE UNIQUE INDEX idx_check_in_photos_unique
  ON check_in_photos (check_in_id, sort_order);

CREATE INDEX idx_check_in_photos_check_in
  ON check_in_photos (check_in_id, sort_order);

-- Tags chosen by the user for a specific check-in (SPEC §4.1 / §4.3).
CREATE TABLE check_in_flavor_tags (
  check_in_id     UUID NOT NULL REFERENCES check_ins(id) ON DELETE CASCADE,
  flavor_tag_id   UUID NOT NULL REFERENCES flavor_tags(id) ON DELETE RESTRICT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (check_in_id, flavor_tag_id)
);
CREATE INDEX idx_check_in_flavor_tags_tag
  ON check_in_flavor_tags (flavor_tag_id);

-- ===========================================================================
-- PHOTO UPLOADS  (post-MVP roadmap — presigned R2/S3 uploads)
-- ===========================================================================
-- Tracks presigned-PUT photo uploads to Cloudflare R2 (or any S3-compatible
-- backend). Lifecycle:
--   'pending'  → presigned URL issued, client has NOT yet PUT
--   'attached' → linked to a check_in_photo row (the handler promotes
--                'pending' → 'attached' directly, trusting the client claim
--                that the PUT succeeded; orphan-cleanup sweeps the rest)
--   'orphaned' → never attached within 24h. Object deleted from R2, row kept
--                for audit.
-- The 'uploaded' value is reserved for a future server-side HEAD-verify step.
CREATE TABLE photo_uploads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blob_key        TEXT NOT NULL UNIQUE,
  content_type    TEXT NOT NULL,
  byte_size       INTEGER NOT NULL CHECK (byte_size > 0 AND byte_size <= 10 * 1024 * 1024),
  status          PHOTO_UPLOAD_STATUS NOT NULL DEFAULT 'pending',
  check_in_id     UUID REFERENCES check_ins(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  attached_at     TIMESTAMPTZ,
  orphaned_at     TIMESTAMPTZ
);

CREATE INDEX idx_photo_uploads_user
  ON photo_uploads (user_id);

CREATE INDEX idx_photo_uploads_orphan_candidates
  ON photo_uploads (created_at)
  WHERE status IN ('pending', 'uploaded');

-- ===========================================================================
-- AVG RATING / CHECK-IN COUNT MAINTENANCE
-- ===========================================================================
-- Strategy: trigger-maintained running aggregate columns on `beverages`.
-- - On INSERT of a check_in (deleted_at IS NULL): recompute avg + count.
-- - On UPDATE of rating OR deleted_at: recompute.
-- - On DELETE: recompute.
-- This is O(1) lock cost on each check-in (one UPDATE on beverages). It avoids
-- the AVG()-over-the-world cost on every read of the beverage detail screen.
-- Alternative considered: a materialized view refreshed on a schedule — but
-- the feed/beverage detail must see fresh ratings instantly, so we recompute
-- per-event. See schema.md for the discussion.
CREATE OR REPLACE FUNCTION recompute_beverage_rating(p_beverage_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE beverages b SET
    avg_rating = sub.avg_rating,
    check_in_count = sub.cnt
  FROM (
    SELECT
      AVG(rating)::NUMERIC(3,2)  AS avg_rating,
      COUNT(*)::INT              AS cnt
    FROM check_ins
    WHERE beverage_id = p_beverage_id
      AND deleted_at IS NULL
      AND rating IS NOT NULL
  ) sub
  WHERE b.id = p_beverage_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_check_ins_aggregate_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM recompute_beverage_rating(NEW.beverage_id);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- beverage_id is immutable per SPEC §4.4 (only beverage cannot be edited).
    PERFORM recompute_beverage_rating(NEW.beverage_id);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM recompute_beverage_rating(OLD.beverage_id);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_ins_agg_iud
  AFTER INSERT OR UPDATE OR DELETE ON check_ins
  FOR EACH ROW EXECUTE FUNCTION trg_check_ins_aggregate_sync();

-- ===========================================================================
-- SOCIAL: FOLLOWS  (SPEC §5.1)
-- ===========================================================================
-- Composite PK matches skill recommendation: no surrogate id.
-- `status` carries 'pending' (private profile, awaiting approval) or 'accepted'.
-- `accepted_at` is the timestamp of approval; NULL while pending.
CREATE TABLE follows (
  follower_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followed_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'accepted',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  accepted_at     TIMESTAMPTZ,

  PRIMARY KEY (follower_id, followed_id),

  CONSTRAINT follows_status_allowed
    CHECK (status IN ('pending', 'accepted')),

  CONSTRAINT follows_no_self
    CHECK (follower_id <> followed_id),

  CONSTRAINT follows_accepted_implies_timestamp
    CHECK (
      (status = 'pending' AND accepted_at IS NULL)
      OR (status = 'accepted' AND accepted_at IS NOT NULL)
    )
);

-- Follow indexes (documented in indexes.md).
CREATE INDEX idx_follows_follower_accepted
  ON follows (follower_id, followed_id)
  WHERE status = 'accepted';

CREATE INDEX idx_follows_followed_accepted
  ON follows (followed_id, follower_id)
  WHERE status = 'accepted';

CREATE INDEX idx_follows_followed_pending
  ON follows (followed_id, created_at DESC)
  WHERE status = 'pending';

-- Accepted keyset for Inbox / Followers / Following: covers the
-- (followed_id, accepted_at DESC, follower_id DESC) tuple cursor. Partial on
-- 'accepted' (all accepted rows have accepted_at NOT NULL per the CHECK).
CREATE INDEX idx_follows_followed_accepted_keyset
  ON follows (followed_id, accepted_at DESC, follower_id DESC)
  WHERE status = 'accepted';

-- ===========================================================================
-- SOCIAL: TOASTS  (SPEC §5.3)
-- ===========================================================================
-- One toast per user × check_in (toggleable). Composite PK enforces this
-- without a surrogate id.
CREATE TABLE toasts (
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  check_in_id     UUID NOT NULL REFERENCES check_ins(id) ON DELETE CASCADE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, check_in_id)
);

CREATE INDEX idx_toasts_check_in
  ON toasts (check_in_id);

-- ===========================================================================
-- COLLECTIONS  (SPEC §6)
-- ===========================================================================
-- `Inventory` + `Wishlist` are seeded application-side (see schema.md).
-- No special `is_default` column — they behave identically to user-created
-- lists (SPEC §6.1: "renameable or deletable"). The UI's `isDefault: true`
-- flag is presentation-only and does not require DB representation.
-- - `visibility`: public/private toggle for the discovery feed.
-- - `entry_count`: trigger-maintained count of collection_entries rows.
CREATE TABLE collections (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  visibility      COLLECTION_VISIBILITY NOT NULL DEFAULT 'private',
  entry_count     INTEGER NOT NULL DEFAULT 0,

  CONSTRAINT collections_name_length
    CHECK (char_length(name) BETWEEN 1 AND 50),

  CONSTRAINT collections_entry_count_nonneg
    CHECK (entry_count >= 0)
);

CREATE TRIGGER trg_collections_updated_at
  BEFORE UPDATE ON collections
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- A user cannot have two live collections with the same name.
CREATE UNIQUE INDEX idx_collections_user_name_live
  ON collections (user_id, LOWER(name))
  WHERE deleted_at IS NULL;

-- "List my collections" — Lists screen.
CREATE INDEX idx_collections_user_live
  ON collections (user_id)
  WHERE deleted_at IS NULL;

-- Discovery feed: most-recent-first cursor on (created_at, id), partial on
-- the discoverable rows only.
CREATE INDEX idx_collections_public_recent
  ON collections (created_at DESC, id DESC)
  WHERE visibility = 'public' AND deleted_at IS NULL;

-- Collection contents (SPEC §6.2). Composite PK enforces the "binary
-- membership" rule. `note` ≤ 200 chars per SPEC §6.2.
CREATE TABLE collection_entries (
  collection_id   UUID NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  beverage_id     UUID NOT NULL REFERENCES beverages(id) ON DELETE RESTRICT,
  note            TEXT,
  added_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (collection_id, beverage_id),

  CONSTRAINT collection_entries_note_length
    CHECK (note IS NULL OR char_length(note) <= 200)
);

CREATE INDEX idx_collection_entries_beverage
  ON collection_entries (beverage_id);

-- ===========================================================================
-- COMMENTS  (post-MVP roadmap — flat comments on check-ins)
-- ===========================================================================
-- One row per comment. No threading (SPEC §9 keeps threaded comments
-- anti-scope; flat is reopened in v1.1). The body-length check mirrors the
-- SPEC §6.7 review-text cap (≤ 500 chars). The no-control-character check is
-- defense in depth against poisoned UTF-8 reaching the shared comment surface.
--
-- `user_id` is ON DELETE SET NULL (and therefore nullable): when the
-- username-hold sweep hard-purges a long-deleted user, SET NULL keeps the body
-- + timestamps in place and the Flutter card renders an "anonymous" author for
-- orphaned rows. (The original FK had no ON DELETE clause and silently broke
-- the purge — the SET NULL fix is folded in here.)
CREATE TABLE comments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  check_in_id     UUID NOT NULL REFERENCES check_ins(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  body            TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ,

  CONSTRAINT comments_body_length
    CHECK (char_length(body) BETWEEN 1 AND 500),

  -- Reject NUL byte + all C0 control chars except tab (0x09) and LF (0x0a).
  -- The application validator is the primary line of defense; this is the
  -- DB-level backstop.
  CONSTRAINT comments_body_no_control
    CHECK (body !~ E'[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]')
);

-- Most-recent-first list by (check_in, created_at, id); cursor pagination
-- pattern matches the feed/profile keyset indexes. Partial filter keeps the
-- index lean by skipping soft-deleted rows.
CREATE INDEX idx_comments_checkin_recent
  ON comments (check_in_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

-- Per-author audit (rare: admin queries / abuse triage). Not partial so it
-- covers soft-deleted rows too — they're the ones an admin most often wants
-- to inspect.
CREATE INDEX idx_comments_user_created
  ON comments (user_id, created_at DESC);

-- ===========================================================================
-- COUNTER-CACHE TRIGGERS  (feed projection performance)
-- ===========================================================================
-- Denormalized counts on parent rows, maintained by triggers that mirror the
-- trg_check_ins_aggregate_sync shape, to eliminate correlated subqueries in
-- the feed / producer-list / collection-list projections.
--   * check_ins.toast_count    ← toasts
--   * check_ins.comment_count  ← comments (tracks soft-delete via deleted_at)
--   * producers.beverage_count ← beverages
--   * collections.entry_count  ← collection_entries

-- toast_count: ±1 on INSERT/DELETE of a toasts row.
CREATE OR REPLACE FUNCTION trg_toasts_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE check_ins SET toast_count = toast_count + 1
    WHERE id = NEW.check_in_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE check_ins SET toast_count = toast_count - 1
    WHERE id = OLD.check_in_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_toasts_count
  AFTER INSERT OR DELETE ON toasts
  FOR EACH ROW EXECUTE FUNCTION trg_toasts_count_sync();

-- comment_count: ±1 on INSERT/DELETE; also tracks UPDATE of deleted_at so that
-- soft-delete decrements and un-delete (admin restore) re-increments.
CREATE OR REPLACE FUNCTION trg_comments_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Newly inserted rows are always live (deleted_at default is NULL).
    UPDATE check_ins SET comment_count = comment_count + 1
    WHERE id = NEW.check_in_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Hard delete: only decrement when the row was live at delete time.
    IF OLD.deleted_at IS NULL THEN
      UPDATE check_ins SET comment_count = comment_count - 1
      WHERE id = OLD.check_in_id;
    END IF;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Soft-delete: live → deleted. Decrement.
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
      UPDATE check_ins SET comment_count = comment_count - 1
      WHERE id = NEW.check_in_id;
    -- Un-delete (admin restore): deleted → live. Re-increment.
    ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
      UPDATE check_ins SET comment_count = comment_count + 1
      WHERE id = NEW.check_in_id;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_comments_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION trg_comments_count_sync();

CREATE TRIGGER trg_comments_count_update
  AFTER UPDATE OF deleted_at ON comments
  FOR EACH ROW EXECUTE FUNCTION trg_comments_count_sync();

-- beverage_count: ±1 on INSERT/DELETE of a beverages row. References
-- `producers` (post-rename body — the original referenced `breweries`).
CREATE OR REPLACE FUNCTION trg_beverages_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE producers SET beverage_count = beverage_count + 1
    WHERE id = NEW.producer_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE producers SET beverage_count = beverage_count - 1
    WHERE id = OLD.producer_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_beverages_count
  AFTER INSERT OR DELETE ON beverages
  FOR EACH ROW EXECUTE FUNCTION trg_beverages_count_sync();

-- entry_count: ±1 on INSERT/DELETE of a collection_entries row.
CREATE OR REPLACE FUNCTION trg_collection_entries_count_sync()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE collections SET entry_count = entry_count + 1
    WHERE id = NEW.collection_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE collections SET entry_count = entry_count - 1
    WHERE id = OLD.collection_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_collection_entries_count
  AFTER INSERT OR DELETE ON collection_entries
  FOR EACH ROW EXECUTE FUNCTION trg_collection_entries_count_sync();

-- ===========================================================================
-- AUTH: REFRESH TOKENS  (rotating refresh tokens with re-use detection)
-- ===========================================================================
-- - `token_hash` is the SHA-256 of the raw secret. The raw secret is the only
--   value clients ever see; it is hashed before persistence and never logged.
-- - Tokens form a chain: each rotation links to its predecessor via
--   `parent_id`; the originating token of a chain carries `family_id = id`
--   (set by the application on insert).
-- - `revoked_at` is set on rotation (predecessor) and on logout. Re-use of a
--   revoked token revokes the entire family.
-- - `expires_at` is enforced by the application; the partial index helps the
--   cleanup job find candidates without scanning revoked rows.
CREATE TABLE refresh_tokens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash      BYTEA NOT NULL UNIQUE,    -- SHA-256 of the raw secret. Raw never stored.
  parent_id       UUID REFERENCES refresh_tokens(id) ON DELETE SET NULL,  -- previous token in the chain
  family_id       UUID NOT NULL,            -- top-of-chain marker; all rotations share it
  issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ NOT NULL,
  revoked_at      TIMESTAMPTZ,
  device_label    TEXT,
  user_agent      TEXT,                     -- not currently exposed on wire; future
  ip              INET
);

CREATE INDEX idx_refresh_tokens_user_active
  ON refresh_tokens (user_id)
  WHERE revoked_at IS NULL;

CREATE INDEX idx_refresh_tokens_family
  ON refresh_tokens (family_id);

CREATE INDEX idx_refresh_tokens_expires
  ON refresh_tokens (expires_at)
  WHERE revoked_at IS NULL;

-- ===========================================================================
-- BEVERAGE ADDITION REQUESTS  (SPEC §2.4)
-- ===========================================================================
-- Free-form user feedback / new-beverage request form. JSONB payload keeps
-- the catalog data flexible; admin reviews & promotes manually to canonical
-- beverages.
CREATE TABLE beverage_addition_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- user_id nullable so that hard-purging a soft-deleted requester
  -- (after the 30-day hold) doesn't destroy the admin's queue.
  user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  payload         JSONB NOT NULL,
  status          TEXT NOT NULL DEFAULT 'pending',
  reviewed_by     UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at     TIMESTAMPTZ,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT beverage_addition_requests_status_allowed
    CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE TRIGGER trg_beverage_addition_requests_updated_at
  BEFORE UPDATE ON beverage_addition_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_beverage_addition_requests_status
  ON beverage_addition_requests (status, created_at DESC);

-- ===========================================================================
-- MODERATION LOG  (admin action audit trail)
-- ===========================================================================
-- Every admin moderation action writes a row. `target_type` covers the
-- surfaces a moderator can touch (check_in / comment / user / beverage_request
-- / beverage / producer); `action` distinguishes what they did (soft_delete /
-- role_change / suspend / approve / reject / create / update / restore).
--
-- moderator_id is ON DELETE SET NULL so hard-purging an ex-admin (after the
-- 30-day hold) doesn't blow away the audit trail. target_id is NOT constrained
-- to any specific table — moderation can outlive its target (e.g. a comment is
-- soft-deleted, then the parent check-in is cascade-deleted on user purge; the
-- log row still tells us who did what when).
CREATE TABLE moderation_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  moderator_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  target_type     MODERATION_TARGET_TYPE NOT NULL,
  target_id       UUID NOT NULL,
  action          MODERATION_ACTION_TYPE NOT NULL,
  notes           TEXT,
  metadata        JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT moderation_log_notes_length
    CHECK (notes IS NULL OR char_length(notes) <= 1000)
);

-- "Show me every action ever taken on this row" — admin UI surface.
CREATE INDEX idx_moderation_log_target
  ON moderation_log (target_type, target_id, created_at DESC);

-- "Show me everything this moderator did" — audit / abuse-of-power surface.
CREATE INDEX idx_moderation_log_moderator
  ON moderation_log (moderator_id, created_at DESC);

-- ===========================================================================
-- NOTIFICATIONS  (SPEC §5.4 — in-app inbox)
-- ===========================================================================
-- Five event types: toast, comment, follow, follow_request, follow_approved.
-- Push is deferred to v1.1. Rows are inserted at the app layer in the same
-- transaction as the source event (no triggers — every emit path is explicit
-- so reviewers can audit the "self-actions never notify" rule).
--
-- TEXT + CHECK chosen over a Postgres enum for `type` so adding a sixth type
-- later is a one-line CHECK rewrite instead of an ALTER TYPE coordinating with
-- every replica's cached enum oid.
--
-- Soft-delete semantics:
--   * Recipient hard-delete: ON DELETE CASCADE wipes the recipient's inbox.
--   * Actor delete: ON DELETE SET NULL preserves the row; UI renders the
--     localized "Deleted user" placeholder.
--   * Referenced check-in / comment HARD-delete: ON DELETE CASCADE wipes the
--     orphaned notification. (These FKs were SET NULL at first, which
--     contradicted notifications_refs_match_type and would abort any future
--     hard-delete with 23514; the CASCADE fix is folded in here. Soft-deletes
--     don't fire CASCADE, so SPEC §5.4's "soft-delete preserves the
--     notification" still holds.)
CREATE TABLE notifications (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type                TEXT NOT NULL,
  actor_user_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  check_in_id         UUID REFERENCES check_ins(id) ON DELETE CASCADE,
  comment_id          UUID REFERENCES comments(id) ON DELETE CASCADE,
  read_at             TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- SPEC §5.4: only the five canonical event types.
  CONSTRAINT notifications_type_allowed
    CHECK (
      type IN ('toast', 'comment', 'follow', 'follow_request', 'follow_approved')
    ),

  -- SPEC §5.4: "Self-actions never produce a notification." actor_user_id NULL
  -- is allowed (soft-deleted actor) and bypasses the check.
  CONSTRAINT notifications_no_self
    CHECK (actor_user_id IS NULL OR actor_user_id <> recipient_user_id),

  -- Per-type reference-column shape:
  --   toast    → check_in_id required, comment_id NULL
  --   comment  → check_in_id + comment_id both required
  --   follow*  → both check_in_id and comment_id NULL
  CONSTRAINT notifications_refs_match_type
    CHECK (
      (type = 'toast' AND check_in_id IS NOT NULL AND comment_id IS NULL)
      OR (type = 'comment' AND check_in_id IS NOT NULL AND comment_id IS NOT NULL)
      OR (
        type IN ('follow', 'follow_request', 'follow_approved')
        AND check_in_id IS NULL
        AND comment_id IS NULL
      )
    )
);

-- Dedupe partial unique indexes (SPEC §5.4). A second INSERT collapses to
-- ON CONFLICT DO NOTHING in the app layer.
--   * toast: at most one per (recipient, actor, check_in).
--   * follow / follow_approved: at most one per (recipient, actor).
--   * comment: NO dedupe — every comment is a distinct event (natural key is
--     comment_id, already the FK target).
--   * follow_request: NO dedupe — the app deletes the row on every terminal
--     state (approve/decline/cancel), so a re-request inserts cleanly.
CREATE UNIQUE INDEX idx_notifications_toast_unique
  ON notifications (recipient_user_id, actor_user_id, check_in_id)
  WHERE type = 'toast';

CREATE UNIQUE INDEX idx_notifications_follow_unique
  ON notifications (recipient_user_id, actor_user_id)
  WHERE type = 'follow';

CREATE UNIQUE INDEX idx_notifications_follow_approved_unique
  ON notifications (recipient_user_id, actor_user_id)
  WHERE type = 'follow_approved';

-- Primary cursor index for GET /v1/notifications: keyset pagination on
-- (created_at DESC, id DESC) per recipient.
CREATE INDEX idx_notifications_recipient_created
  ON notifications (recipient_user_id, created_at DESC, id DESC);

-- Unread-count + unread-dot path. Partial keeps the index tiny — most rows in
-- a healthy inbox are read.
CREATE INDEX idx_notifications_recipient_unread
  ON notifications (recipient_user_id)
  WHERE read_at IS NULL;

COMMIT;
