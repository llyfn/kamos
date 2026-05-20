-- 002_seed_taxonomy.sql
-- Seed the admin-curated taxonomy that the SPEC fixes as part of the contract:
--   - beverage_categories: the three canonical SPEC §2.1 rows.
--   - flavor_tags: the SPEC §4.3 taxonomy in en/ja/ko.
-- These rows are referenced by FK from beverages and check_in_flavor_tags,
-- so they must exist before any catalog data is loaded.

BEGIN;

-- ---------------------------------------------------------------------------
-- Categories — SPEC §2.1 canonical strings, never abbreviated.
-- ---------------------------------------------------------------------------
INSERT INTO beverage_categories (slug, name_i18n, sort_order) VALUES
  ('nihonshu',
   '{"en":"Nihonshu (Sake)","ja":"日本酒","ko":"니혼슈 (사케)"}'::jsonb,
   10),
  ('shochu',
   '{"en":"Shochu","ja":"焼酎","ko":"쇼츄"}'::jsonb,
   20),
  ('liqueur',
   '{"en":"Liqueur","ja":"リキュール","ko":"리큐어"}'::jsonb,
   30);

-- ---------------------------------------------------------------------------
-- Flavor tags — SPEC §4.3 taxonomy.
-- Translations are reasonable defaults; ja/ko strings are reviewable by the
-- product/i18n owner before launch and editable via admin UI later.
-- ---------------------------------------------------------------------------
INSERT INTO flavor_tags (slug, dimension, name_i18n, sort_order) VALUES
  -- Sweetness
  ('dry',         'sweetness', '{"en":"Dry",        "ja":"辛口",   "ko":"드라이"}'::jsonb, 10),
  ('off_dry',     'sweetness', '{"en":"Off-dry",    "ja":"やや辛口","ko":"오프 드라이"}'::jsonb, 20),
  ('sweet',       'sweetness', '{"en":"Sweet",      "ja":"甘口",   "ko":"달콤"}'::jsonb, 30),
  ('very_sweet',  'sweetness', '{"en":"Very sweet", "ja":"極甘口", "ko":"매우 달콤"}'::jsonb, 40),

  -- Body
  ('light',       'body',      '{"en":"Light",      "ja":"軽快",   "ko":"라이트"}'::jsonb, 10),
  ('medium',      'body',      '{"en":"Medium",     "ja":"中口",   "ko":"미디엄"}'::jsonb, 20),
  ('full',        'body',      '{"en":"Full",       "ja":"濃醇",   "ko":"풀바디"}'::jsonb, 30),

  -- Acidity
  ('low_acidity', 'acidity',   '{"en":"Low",        "ja":"低酸",   "ko":"낮은 산미"}'::jsonb, 10),
  ('crisp',       'acidity',   '{"en":"Crisp",      "ja":"キレ",   "ko":"크리스프"}'::jsonb, 20),
  ('bright',      'acidity',   '{"en":"Bright",     "ja":"爽やか", "ko":"브라이트"}'::jsonb, 30),
  ('sharp',       'acidity',   '{"en":"Sharp",      "ja":"シャープ","ko":"샤프"}'::jsonb, 40),

  -- Character
  ('fruity',      'character', '{"en":"Fruity",     "ja":"フルーティ","ko":"과일향"}'::jsonb, 10),
  ('floral',      'character', '{"en":"Floral",     "ja":"華やか", "ko":"꽃향"}'::jsonb, 20),
  ('earthy',      'character', '{"en":"Earthy",     "ja":"土っぽい","ko":"흙내음"}'::jsonb, 30),
  ('umami',       'character', '{"en":"Umami",      "ja":"旨味",   "ko":"감칠맛"}'::jsonb, 40),
  ('smoky',       'character', '{"en":"Smoky",      "ja":"スモーキー","ko":"스모키"}'::jsonb, 50),
  ('nutty',       'character', '{"en":"Nutty",      "ja":"ナッツ", "ko":"고소"}'::jsonb, 60),
  ('woody',       'character', '{"en":"Woody",      "ja":"木の香り","ko":"우디"}'::jsonb, 70),

  -- Finish
  ('short',       'finish',    '{"en":"Short",      "ja":"短い",   "ko":"짧은 피니시"}'::jsonb, 10),
  ('clean',       'finish',    '{"en":"Clean",      "ja":"クリーン","ko":"클린"}'::jsonb, 20),
  ('lingering',   'finish',    '{"en":"Lingering",  "ja":"余韻長い","ko":"긴 여운"}'::jsonb, 30),
  ('warming',     'finish',    '{"en":"Warming",    "ja":"温かみ", "ko":"따뜻한 피니시"}'::jsonb, 40);

COMMIT;
