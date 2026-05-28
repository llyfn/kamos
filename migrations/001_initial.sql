-- 001_initial.sql
-- KAMOS — initial schema.
-- One transaction. Append-only: future changes go in a new file.
-- Traces: SPEC.md §2-§8.

BEGIN;

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()

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
    CHECK (locale IN ('en','ja','ko')),

  CONSTRAINT users_privacy_allowed
    CHECK (privacy_mode IN ('public','private')),

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

-- ---------------------------------------------------------------------------
-- Email verification tokens.
-- 24h expiry per SPEC §3.1. One active token per address at a time enforced
-- in the application; multiple historical rows allowed for audit.
-- ---------------------------------------------------------------------------
CREATE TABLE email_verifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token       TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_email_verifications_token
  ON email_verifications (token);
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
    CHECK (slug IN ('nihonshu','shochu','liqueur')),

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

-- Breweries (SPEC §2.3).
-- - `name_i18n`: { en, ja, ko? } — en + ja required at app layer; we enforce
--    `en` and `ja` presence here as a defensive check.
-- - `description_i18n`: optional, no presence check.
CREATE TABLE breweries (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_i18n           JSONB NOT NULL,
  prefecture          TEXT,
  region              TEXT,
  founded_year        SMALLINT,
  website             TEXT,
  description_i18n    JSONB,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT breweries_name_has_en_ja
    CHECK (name_i18n ? 'en' AND name_i18n ? 'ja'),

  CONSTRAINT breweries_founded_year_range
    CHECK (founded_year IS NULL OR (founded_year BETWEEN 800 AND 2100))
);

CREATE TRIGGER trg_breweries_updated_at
  BEFORE UPDATE ON breweries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Brewery FTS index for cross-locale name search.
CREATE INDEX idx_breweries_name_tsv
  ON breweries USING GIN (
    to_tsvector('simple',
      coalesce(name_i18n->>'en','') || ' ' ||
      coalesce(name_i18n->>'ja','') || ' ' ||
      coalesce(name_i18n->>'ko','')
    )
  );

-- Beverages (SPEC §2.2).
-- - `polishing_ratio` only valid for nihonshu (CHECK with category lookup).
--    Implemented via a row-level CHECK that delegates to category_slug,
--    a denormalized column kept in sync via FK + trigger.
-- - `avg_rating` and `check_in_count` are running denormalized aggregates
--    maintained by triggers on check_ins (see end of file).
CREATE TABLE beverages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brewery_id          UUID NOT NULL REFERENCES breweries(id) ON DELETE RESTRICT,
  category_id         UUID NOT NULL REFERENCES beverage_categories(id) ON DELETE RESTRICT,
  category_slug       TEXT NOT NULL,   -- denormalized for the polishing-ratio CHECK
  name_i18n           JSONB NOT NULL,
  subcategory_i18n    JSONB,            -- e.g. {en:'Junmai Daiginjo', ja:'純米大吟醸', ko:'…'}
  abv                 NUMERIC(4,1),
  polishing_ratio     SMALLINT,         -- nihonshu only
  flavor_profile      TEXT[] NOT NULL DEFAULT '{}',  -- aggregate tag slugs
  prefecture          TEXT,
  region              TEXT,
  description_i18n    JSONB,
  label_image_url     TEXT,
  avg_rating          NUMERIC(3,2),     -- denormalized; NULL when no ratings
  check_in_count      INTEGER NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT beverages_name_has_en_ja
    CHECK (name_i18n ? 'en' AND name_i18n ? 'ja'),

  CONSTRAINT beverages_category_slug_allowed
    CHECK (category_slug IN ('nihonshu','shochu','liqueur')),

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

-- Beverage indexes (documented in indexes.md).
CREATE INDEX idx_beverages_brewery
  ON beverages (brewery_id);

CREATE INDEX idx_beverages_category
  ON beverages (category_id);

CREATE INDEX idx_beverages_name_gin
  ON beverages USING GIN (name_i18n jsonb_path_ops);

CREATE INDEX idx_beverages_name_tsv
  ON beverages USING GIN (
    to_tsvector('simple',
      coalesce(name_i18n->>'en','') || ' ' ||
      coalesce(name_i18n->>'ja','') || ' ' ||
      coalesce(name_i18n->>'ko','')
    )
  );

CREATE INDEX idx_beverages_avg_rating_desc
  ON beverages (category_id, avg_rating DESC NULLS LAST)
  WHERE check_in_count >= 3;

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
    CHECK (dimension IN ('sweetness','body','acidity','character','finish')),

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
-- CHECK-INS  (SPEC §4)
-- ===========================================================================
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
  serving_style       TEXT,             -- 'glass' | 'carafe' | 'bottle' | 'can' | 'other'
  deleted_at          TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

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
    CHECK (price_unit IS NULL OR price_unit IN ('serving','bottle')),

  CONSTRAINT check_ins_purchase_type_allowed
    CHECK (purchase_type IS NULL OR purchase_type IN ('on_premise','retail','gift','other')),

  CONSTRAINT check_ins_serving_style_allowed
    CHECK (serving_style IS NULL OR serving_style IN ('glass','carafe','bottle','can','other'))
);

CREATE TRIGGER trg_check_ins_updated_at
  BEFORE UPDATE ON check_ins
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Feed / profile keyset cursor indexes (SPEC §5.2 / §6.6).
CREATE INDEX idx_check_ins_user_created
  ON check_ins (user_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_check_ins_beverage_created
  ON check_ins (beverage_id, created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX idx_check_ins_created_global
  ON check_ins (created_at DESC, id DESC)
  WHERE deleted_at IS NULL;

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
    CHECK (status IN ('pending','accepted')),

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
CREATE TABLE collections (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT collections_name_length
    CHECK (char_length(name) BETWEEN 1 AND 50)
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
    CHECK (status IN ('pending','approved','rejected'))
);

CREATE TRIGGER trg_beverage_addition_requests_updated_at
  BEFORE UPDATE ON beverage_addition_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX idx_beverage_addition_requests_status
  ON beverage_addition_requests (status, created_at DESC);

COMMIT;
