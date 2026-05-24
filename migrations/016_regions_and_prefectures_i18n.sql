-- 016_regions_and_prefectures_i18n.sql
-- Replace free-text `breweries.prefecture` / `breweries.region` and
-- `beverages.prefecture` / `beverages.region` with proper i18n reference
-- tables: `regions` (Japan's 8 traditional regions) and `prefectures`
-- (the 47 prefectures, FK'd to a region).
--
-- Beverages stop carrying their own prefecture/region columns entirely —
-- locality is derived through `beverages.brewery_id -> breweries.prefecture_id
-- -> prefectures.region_id`. This removes the denormalization drift that
-- free-text fields have shown in practice (e.g. mixed "Niigata" / "新潟" /
-- "新潟県") and gives the admin SPA a controlled vocabulary backed by the
-- same `name_i18n` JSONB pattern already used for `beverage_categories` and
-- `flavor_tags` (see 002_seed_taxonomy.sql).
--
-- Country dimension is intentionally out of scope: MVP is Japan-only. A
-- `countries` table can be added later without disturbing the FK chain.
-- `venues.prefecture` (Phase 4, Foursquare-backed) is untouched — that
-- column is third-party-sourced free text and is QA'd in a different path.
--
-- Backfill for `breweries.prefecture_id` is best-effort: a case-insensitive
-- match against `name_i18n->>'en'` OR exact `name_i18n->>'ja'`. Anything
-- that doesn't match resolves to NULL, which is the correct representation
-- for "unknown / not yet curated". The catalog is small at this stage;
-- admin can re-curate stragglers after this migration applies.
--
-- Append-only. One transaction.

BEGIN;

-- ---------------------------------------------------------------------------
-- regions — Japan's 8 traditional regions.
-- name_i18n requires all three locales because these are seed-only and the
-- product surface always renders the region label localized.
-- ---------------------------------------------------------------------------
CREATE TABLE regions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name_i18n JSONB NOT NULL,
  sort_order SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT regions_name_has_en_ja_ko
  CHECK (name_i18n ? 'en' AND name_i18n ? 'ja' AND name_i18n ? 'ko')
);

-- ---------------------------------------------------------------------------
-- prefectures — Japan's 47 prefectures, FK'd to a region.
-- sort_order = JIS prefecture code (Hokkaido=1 … Okinawa=47), the canonical
-- order used by every Japanese reference table.
-- ---------------------------------------------------------------------------
CREATE TABLE prefectures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  region_id UUID NOT NULL REFERENCES regions (id) ON DELETE RESTRICT,
  slug TEXT NOT NULL UNIQUE,
  name_i18n JSONB NOT NULL,
  sort_order SMALLINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT prefectures_name_has_en_ja_ko
  CHECK (name_i18n ? 'en' AND name_i18n ? 'ja' AND name_i18n ? 'ko')
);

CREATE INDEX idx_prefectures_region_id ON prefectures (region_id);

-- ---------------------------------------------------------------------------
-- Seed regions.
-- ---------------------------------------------------------------------------
INSERT INTO regions (slug, name_i18n, sort_order) VALUES
('hokkaido', '{"en":"Hokkaido","ja":"北海道","ko":"홋카이도"}'::JSONB, 1),
('tohoku', '{"en":"Tōhoku","ja":"東北","ko":"도호쿠"}'::JSONB, 2),
('kanto', '{"en":"Kantō","ja":"関東","ko":"간토"}'::JSONB, 3),
('chubu', '{"en":"Chūbu","ja":"中部","ko":"주부"}'::JSONB, 4),
('kansai', '{"en":"Kansai","ja":"関西","ko":"간사이"}'::JSONB, 5),
('chugoku', '{"en":"Chūgoku","ja":"中国","ko":"주고쿠"}'::JSONB, 6),
('shikoku', '{"en":"Shikoku","ja":"四国","ko":"시코쿠"}'::JSONB, 7),
('kyushu_okinawa', '{"en":"Kyūshū & Okinawa","ja":"九州・沖縄","ko":"규슈・오키나와"}'::JSONB, 8);

-- ---------------------------------------------------------------------------
-- Seed prefectures (JIS order). Region FKs are resolved by slug so we don't
-- hardcode UUIDs.
-- ---------------------------------------------------------------------------
INSERT INTO prefectures (region_id, slug, name_i18n, sort_order)
SELECT
  r.id,
  v.slug,
  v.name_i18n::JSONB,
  v.sort_order
FROM (
  VALUES
  ('hokkaido', 'hokkaido', '{"en":"Hokkaido","ja":"北海道","ko":"홋카이도"}', 1),
  ('tohoku', 'aomori', '{"en":"Aomori","ja":"青森県","ko":"아오모리현"}', 2),
  ('tohoku', 'iwate', '{"en":"Iwate","ja":"岩手県","ko":"이와테현"}', 3),
  ('tohoku', 'miyagi', '{"en":"Miyagi","ja":"宮城県","ko":"미야기현"}', 4),
  ('tohoku', 'akita', '{"en":"Akita","ja":"秋田県","ko":"아키타현"}', 5),
  ('tohoku', 'yamagata', '{"en":"Yamagata","ja":"山形県","ko":"야마가타현"}', 6),
  ('tohoku', 'fukushima', '{"en":"Fukushima","ja":"福島県","ko":"후쿠시마현"}', 7),
  ('kanto', 'ibaraki', '{"en":"Ibaraki","ja":"茨城県","ko":"이바라키현"}', 8),
  ('kanto', 'tochigi', '{"en":"Tochigi","ja":"栃木県","ko":"도치기현"}', 9),
  ('kanto', 'gunma', '{"en":"Gunma","ja":"群馬県","ko":"군마현"}', 10),
  ('kanto', 'saitama', '{"en":"Saitama","ja":"埼玉県","ko":"사이타마현"}', 11),
  ('kanto', 'chiba', '{"en":"Chiba","ja":"千葉県","ko":"지바현"}', 12),
  ('kanto', 'tokyo', '{"en":"Tokyo","ja":"東京都","ko":"도쿄도"}', 13),
  ('kanto', 'kanagawa', '{"en":"Kanagawa","ja":"神奈川県","ko":"가나가와현"}', 14),
  ('chubu', 'niigata', '{"en":"Niigata","ja":"新潟県","ko":"니가타현"}', 15),
  ('chubu', 'toyama', '{"en":"Toyama","ja":"富山県","ko":"도야마현"}', 16),
  ('chubu', 'ishikawa', '{"en":"Ishikawa","ja":"石川県","ko":"이시카와현"}', 17),
  ('chubu', 'fukui', '{"en":"Fukui","ja":"福井県","ko":"후쿠이현"}', 18),
  ('chubu', 'yamanashi', '{"en":"Yamanashi","ja":"山梨県","ko":"야마나시현"}', 19),
  ('chubu', 'nagano', '{"en":"Nagano","ja":"長野県","ko":"나가노현"}', 20),
  ('chubu', 'gifu', '{"en":"Gifu","ja":"岐阜県","ko":"기후현"}', 21),
  ('chubu', 'shizuoka', '{"en":"Shizuoka","ja":"静岡県","ko":"시즈오카현"}', 22),
  ('chubu', 'aichi', '{"en":"Aichi","ja":"愛知県","ko":"아이치현"}', 23),
  ('kansai', 'mie', '{"en":"Mie","ja":"三重県","ko":"미에현"}', 24),
  ('kansai', 'shiga', '{"en":"Shiga","ja":"滋賀県","ko":"시가현"}', 25),
  ('kansai', 'kyoto', '{"en":"Kyoto","ja":"京都府","ko":"교토부"}', 26),
  ('kansai', 'osaka', '{"en":"Osaka","ja":"大阪府","ko":"오사카부"}', 27),
  ('kansai', 'hyogo', '{"en":"Hyōgo","ja":"兵庫県","ko":"효고현"}', 28),
  ('kansai', 'nara', '{"en":"Nara","ja":"奈良県","ko":"나라현"}', 29),
  ('kansai', 'wakayama', '{"en":"Wakayama","ja":"和歌山県","ko":"와카야마현"}', 30),
  ('chugoku', 'tottori', '{"en":"Tottori","ja":"鳥取県","ko":"돗토리현"}', 31),
  ('chugoku', 'shimane', '{"en":"Shimane","ja":"島根県","ko":"시마네현"}', 32),
  ('chugoku', 'okayama', '{"en":"Okayama","ja":"岡山県","ko":"오카야마현"}', 33),
  ('chugoku', 'hiroshima', '{"en":"Hiroshima","ja":"広島県","ko":"히로시마현"}', 34),
  ('chugoku', 'yamaguchi', '{"en":"Yamaguchi","ja":"山口県","ko":"야마구치현"}', 35),
  ('shikoku', 'tokushima', '{"en":"Tokushima","ja":"徳島県","ko":"도쿠시마현"}', 36),
  ('shikoku', 'kagawa', '{"en":"Kagawa","ja":"香川県","ko":"가가와현"}', 37),
  ('shikoku', 'ehime', '{"en":"Ehime","ja":"愛媛県","ko":"에히메현"}', 38),
  ('shikoku', 'kochi', '{"en":"Kōchi","ja":"高知県","ko":"고치현"}', 39),
  ('kyushu_okinawa', 'fukuoka', '{"en":"Fukuoka","ja":"福岡県","ko":"후쿠오카현"}', 40),
  ('kyushu_okinawa', 'saga', '{"en":"Saga","ja":"佐賀県","ko":"사가현"}', 41),
  ('kyushu_okinawa', 'nagasaki', '{"en":"Nagasaki","ja":"長崎県","ko":"나가사키현"}', 42),
  ('kyushu_okinawa', 'kumamoto', '{"en":"Kumamoto","ja":"熊本県","ko":"구마모토현"}', 43),
  ('kyushu_okinawa', 'oita', '{"en":"Ōita","ja":"大分県","ko":"오이타현"}', 44),
  ('kyushu_okinawa', 'miyazaki', '{"en":"Miyazaki","ja":"宮崎県","ko":"미야자키현"}', 45),
  ('kyushu_okinawa', 'kagoshima', '{"en":"Kagoshima","ja":"鹿児島県","ko":"가고시마현"}', 46),
  ('kyushu_okinawa', 'okinawa', '{"en":"Okinawa","ja":"沖縄県","ko":"오키나와현"}', 47)
) AS v (region_slug, slug, name_i18n, sort_order)
INNER JOIN regions AS r ON v.region_slug = r.slug;

-- ---------------------------------------------------------------------------
-- breweries: add nullable prefecture_id FK, backfill from free text, drop
-- the old free-text columns.
--
-- Backfill matches `name_i18n->>'en'` (case-insensitive) OR exact
-- `name_i18n->>'ja'`. Anything that doesn't match stays NULL — these rows
-- need admin recuration; we deliberately do not guess.
-- ---------------------------------------------------------------------------
ALTER TABLE breweries
ADD COLUMN prefecture_id UUID REFERENCES prefectures (id) ON DELETE RESTRICT;

UPDATE breweries
SET prefecture_id = p.id
FROM prefectures AS p
WHERE
  breweries.prefecture IS NOT NULL
  AND (
    lower(p.name_i18n ->> 'en') = lower(breweries.prefecture)
    OR p.name_i18n ->> 'ja' = breweries.prefecture
  );

ALTER TABLE breweries DROP COLUMN prefecture;
ALTER TABLE breweries DROP COLUMN region;

-- Partial index for admin filtering and brewery-detail prefecture joins.
CREATE INDEX idx_breweries_prefecture_id
ON breweries (prefecture_id)
WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- beverages: drop free-text prefecture/region (derived via brewery FK).
-- ---------------------------------------------------------------------------
ALTER TABLE beverages DROP COLUMN prefecture;
ALTER TABLE beverages DROP COLUMN region;

COMMIT;
