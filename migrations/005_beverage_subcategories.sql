-- 005_beverage_subcategories.sql
-- Promote `beverages.subcategory_i18n` (free-text JSONB) to a proper joinable
-- table `beverage_subcategories` with admin-managed CRUD. Slice C, post-MVP
-- polish batch.
--
-- Decisions (from docs/history/04_subcategory_table_admin/00_brief.md):
--   * One row per (category, slug). "Other" is a per-category row, not a
--     cross-category one — three seed rows: nihonshu_other / shochu_other /
--     liqueur_other.
--   * Each row carries `name_i18n` with required en + ja + ko keys, same shape
--     as beverage_categories.name_i18n (CHECK enforced).
--   * Soft-delete via `deleted_at TIMESTAMPTZ`; admin "delete" sets this and is
--     blocked at the application layer if any non-soft-deleted beverage still
--     references the subcategory. The FK is ON DELETE RESTRICT to backstop the
--     hard-delete path.
--   * Stable `sort_order SMALLINT` for display; seeds use multiples of 10 so
--     future inserts can slot between (the unmatched-backfill rows use 500 so
--     they sit between curated entries and the "Other" row at 990).
--   * Denormalized `category_slug TEXT` synced from `beverage_categories.slug`
--     via the same trigger pattern as beverages.category_slug — keeps query
--     paths (admin filtering, public catalog grouping) row-local without an
--     extra JOIN.
--
-- LEGACY COLUMN — `beverages.subcategory_i18n` STAYS in this migration. From
-- this point forward the FK `beverages.subcategory_id` is the source of truth
-- on writes; the old JSONB column is ignored on writes and rendered only as a
-- fallback during the one-release dual-source window. A follow-up migration
-- (006_*) will DROP the column once the Flutter/admin clients have shipped.
--
-- BACKFILL — idempotent. For every non-soft-deleted beverage with a non-null
-- subcategory_i18n:
--   1. Match by LOWER(TRIM(en value)) against a seeded subcategory under the
--      same category. If found, set beverages.subcategory_id.
--   2. Otherwise create a NEW row under that category with a derived slug
--      (sort_order = 500 so it sits between seeded values and "Other"), then
--      set beverages.subcategory_id. ON CONFLICT (category_id, slug) DO
--      NOTHING makes the insert idempotent; the subsequent UPDATE finds the
--      row whether it was just inserted or pre-existed.
--
-- One transaction. Append-only.

BEGIN;

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------
CREATE TABLE beverage_subcategories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES beverage_categories (id) ON DELETE RESTRICT,
  category_slug TEXT NOT NULL,   -- denormalized; synced via trigger below
  slug TEXT NOT NULL,   -- short stable identifier, lowercase + underscores
  name_i18n JSONB NOT NULL,  -- {en, ja, ko} all required + non-empty
  sort_order SMALLINT NOT NULL DEFAULT 0,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Slugs unique per category; the same bare slug under a different category
  -- is allowed (we don't exercise that in seed, but the column scope honors
  -- the FK boundary).
  CONSTRAINT beverage_subcategories_category_slug_unique
  UNIQUE (category_id, slug),

  -- All three locales required AND non-empty. Mirrors the
  -- beverage_categories_name_complete shape but adds the non-empty check
  -- (categories rely on application-level seeds; subcategories are
  -- admin-editable so a stricter DB-level backstop is appropriate).
  CONSTRAINT beverage_subcategories_name_complete
  CHECK (
    name_i18n ? 'en' AND name_i18n ? 'ja' AND name_i18n ? 'ko'
    AND char_length(name_i18n ->> 'en') > 0
    AND char_length(name_i18n ->> 'ja') > 0
    AND char_length(name_i18n ->> 'ko') > 0
  ),

  -- Slug format: lowercase letters / digits / underscores. Mirrors the
  -- beverage_categories.slug spirit (controlled vocabulary) without locking
  -- the value list, since admin can add new rows.
  CONSTRAINT beverage_subcategories_slug_format
  CHECK (slug ~ '^[a-z0-9_]{1,64}$'),

  -- category_slug must agree with the allowed category vocabulary. The
  -- trigger below keeps it in sync with beverage_categories.slug on INSERT
  -- and on UPDATE OF category_id; this CHECK is defense-in-depth.
  CONSTRAINT beverage_subcategories_category_slug_allowed
  CHECK (category_slug IN ('nihonshu', 'shochu', 'liqueur'))
);

CREATE TRIGGER trg_beverage_subcategories_updated_at
BEFORE UPDATE ON beverage_subcategories
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Keep beverage_subcategories.category_slug consistent with the parent
-- beverage_categories.slug. Mirrors sync_beverage_category_slug() from the
-- baseline; defined under a distinct name so the two triggers stay
-- independent on future changes.
CREATE OR REPLACE FUNCTION sync_beverage_subcategory_category_slug()
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

CREATE TRIGGER trg_beverage_subcategories_sync_category_slug
BEFORE INSERT OR UPDATE OF category_id ON beverage_subcategories
FOR EACH ROW EXECUTE FUNCTION sync_beverage_subcategory_category_slug();

-- ---------------------------------------------------------------------------
-- FK on beverages
-- ---------------------------------------------------------------------------
-- ON DELETE SET NULL: deleting a subcategory (hard, not soft) loses the link
-- but preserves the beverage row. In practice the application layer blocks
-- hard-delete when live beverages reference the subcategory; this FK action
-- is the backstop for the admin-recovery-script path.
ALTER TABLE beverages
ADD COLUMN subcategory_id UUID NULL
REFERENCES beverage_subcategories (id) ON DELETE SET NULL;

-- Partial index: catalog views filter beverages by subcategory and only ever
-- read live rows. Soft-deleted beverages don't appear in the public catalog
-- and aren't useful to scan here.
CREATE INDEX beverages_subcategory_id_idx
ON beverages (subcategory_id)
WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- Seed (sort_order in multiples of 10 leaves room for future inserts)
-- ---------------------------------------------------------------------------
INSERT INTO beverage_subcategories (category_id, slug, name_i18n, sort_order)
SELECT
  bc.id,
  v.slug,
  v.name_i18n::JSONB,
  v.sort_order
FROM (
  VALUES
  -- Nihonshu
  ('nihonshu', 'junmai', '{"en":"Junmai","ja":"純米","ko":"준마이"}', 10),
  ('nihonshu', 'honjozo', '{"en":"Honjozo","ja":"本醸造","ko":"혼조조"}', 20),
  ('nihonshu', 'ginjo', '{"en":"Ginjo","ja":"吟醸","ko":"긴조"}', 30),
  ('nihonshu', 'daiginjo', '{"en":"Daiginjo","ja":"大吟醸","ko":"다이긴조"}', 40),
  ('nihonshu', 'junmai_ginjo', '{"en":"Junmai Ginjo","ja":"純米吟醸","ko":"준마이 긴조"}', 50),
  ('nihonshu', 'junmai_daiginjo', '{"en":"Junmai Daiginjo","ja":"純米大吟醸","ko":"준마이 다이긴조"}', 60),
  ('nihonshu', 'nigori', '{"en":"Nigori","ja":"にごり","ko":"니고리"}', 70),
  ('nihonshu', 'nihonshu_other', '{"en":"Other","ja":"その他","ko":"기타"}', 990),

  -- Shochu
  ('shochu', 'imo', '{"en":"Imo (Sweet Potato)","ja":"芋焼酎","ko":"이모 (고구마)"}', 10),
  ('shochu', 'mugi', '{"en":"Mugi (Barley)","ja":"麦焼酎","ko":"무기 (보리)"}', 20),
  ('shochu', 'kome', '{"en":"Kome (Rice)","ja":"米焼酎","ko":"코메 (쌀)"}', 30),
  ('shochu', 'soba', '{"en":"Soba (Buckwheat)","ja":"そば焼酎","ko":"소바 (메밀)"}', 40),
  ('shochu', 'kokuto', '{"en":"Kokuto (Brown Sugar)","ja":"黒糖焼酎","ko":"코쿠토 (흑설탕)"}', 50),
  ('shochu', 'awamori', '{"en":"Awamori","ja":"泡盛","ko":"아와모리"}', 60),
  ('shochu', 'shochu_other', '{"en":"Other","ja":"その他","ko":"기타"}', 990),

  -- Liqueur
  ('liqueur', 'umeshu', '{"en":"Umeshu","ja":"梅酒","ko":"우메슈"}', 10),
  ('liqueur', 'yuzushu', '{"en":"Yuzushu","ja":"柚子酒","ko":"유즈슈"}', 20),
  ('liqueur', 'liqueur_other', '{"en":"Other","ja":"その他","ko":"기타"}', 990)
) AS v (category_slug, slug, name_i18n, sort_order)
INNER JOIN beverage_categories AS bc ON v.category_slug = bc.slug
ON CONFLICT (category_id, slug) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Backfill from beverages.subcategory_i18n  (idempotent)
-- ---------------------------------------------------------------------------
-- Two-phase: insert any unmatched free-text values as new rows; then UPDATE
-- beverages.subcategory_id by matching LOWER(TRIM(en)) under the same
-- category. The UPDATE catches both pre-existing seeded matches and the
-- just-inserted unmatched rows.

-- Phase A — create rows for unmatched en values (one per (category, en)).
-- Slug derivation: lowercase, non-alnum -> '_', collapse runs, trim leading
-- and trailing underscores. The DISTINCT ON keeps the first hit per
-- (category, en) so two beverages with identical en text resolve to the
-- same new row.
WITH source AS (
  SELECT DISTINCT ON (b.category_id, lower(trim(b.subcategory_i18n ->> 'en')))
    b.category_id,
    b.category_slug,
    trim(b.subcategory_i18n ->> 'en') AS en_text,
    nullif(trim(b.subcategory_i18n ->> 'ja'), '') AS ja_text,
    nullif(trim(b.subcategory_i18n ->> 'ko'), '') AS ko_text
  FROM beverages AS b
  WHERE
    b.deleted_at IS NULL
    AND b.subcategory_i18n IS NOT NULL
    AND b.subcategory_i18n ? 'en'
    AND trim(b.subcategory_i18n ->> 'en') <> ''
)

INSERT INTO beverage_subcategories (category_id, slug, name_i18n, sort_order)
SELECT
  s.category_id,
  -- Derived slug. NULLIF + COALESCE guard against an en value that has no
  -- alnum characters (e.g. punctuation only) — fallback to a stable
  -- placeholder that the admin can rename. The (category_id, slug) UNIQUE
  -- still applies, so two such rows in the same category would conflict and
  -- the second is swallowed by ON CONFLICT DO NOTHING (which is fine: the
  -- subsequent UPDATE will link both beverages to the first row by the en
  -- match, since the placeholder rows share the en value too).
  coalesce(
    nullif(
      regexp_replace(
        regexp_replace(lower(s.en_text), '[^a-z0-9]+', '_', 'g'),
        '^_+|_+$', '', 'g'
      ),
      ''
    ),
    'subcategory'
  ) AS slug,
  jsonb_build_object(
    'en', s.en_text,
    'ja', coalesce(s.ja_text, s.en_text),  -- SPEC §6.5 fallback: ja missing → en
    'ko', coalesce(s.ko_text, s.en_text)   -- SPEC §6.5 fallback: ko missing → en
  ) AS name_i18n,
  500 AS sort_order
FROM source AS s
-- Skip rows whose en text already matches a (just-seeded) subcategory under
-- the same category — that's the "already canonical" case handled purely by
-- Phase B.
WHERE
  NOT EXISTS (
    SELECT 1 FROM beverage_subcategories AS sc
    WHERE
      sc.category_id = s.category_id
      AND lower(sc.name_i18n ->> 'en') = lower(s.en_text)
  )
ON CONFLICT (category_id, slug) DO NOTHING;

-- Phase B — link every non-null subcategory_i18n beverage to its matching
-- row. `WHERE b.subcategory_id IS NULL` makes this idempotent on re-run.
UPDATE beverages b
SET subcategory_id = sc.id
FROM beverage_subcategories AS sc
WHERE
  b.subcategory_id IS NULL
  AND b.deleted_at IS NULL
  AND b.subcategory_i18n IS NOT NULL
  AND b.subcategory_i18n ? 'en'
  AND trim(b.subcategory_i18n ->> 'en') <> ''
  AND sc.category_id = b.category_id
  AND sc.deleted_at IS NULL
  AND lower(sc.name_i18n ->> 'en') = lower(trim(b.subcategory_i18n ->> 'en'));

COMMIT;
