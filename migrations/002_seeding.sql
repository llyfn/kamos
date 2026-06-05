-- 002_seeding.sql
-- Seed the admin-curated taxonomy and locality reference data that the
-- SPEC fixes as part of the contract:
--   - beverage_categories:    the three canonical SPEC §2.1 rows.
--   - beverage_subcategories: 18 seeded subtypes (Nihonshu × 8, Shochu × 7,
--                             Liqueur × 3, including a per-category "Other").
--   - flavor_tags:            the SPEC §4.3 taxonomy in en/ja/ko.
--   - regions:                Japan's 8 traditional regions (i18n).
--   - prefectures:            Japan's 47 prefectures (i18n), FK'd to a region.
--
-- These rows are referenced by FK from beverages, check_in_flavor_tags, and
-- producers.prefecture_id, so they must exist before any catalog data loads.

BEGIN;

-- ---------------------------------------------------------------------------
-- Categories — SPEC §2.1 canonical strings, never abbreviated.
-- ---------------------------------------------------------------------------
INSERT INTO beverage_categories (slug, name_i18n, sort_order) VALUES
(
  'nihonshu',
  '{"en":"Nihonshu (Sake)","ja":"日本酒","ko":"니혼슈 (사케)"}'::jsonb,
  10
),
(
  'shochu',
  '{"en":"Shochu","ja":"焼酎","ko":"쇼츄"}'::jsonb,
  20
),
(
  'liqueur',
  '{"en":"Liqueur","ja":"リキュール","ko":"리큐어"}'::jsonb,
  30
);

-- ---------------------------------------------------------------------------
-- Beverage subcategories — admin-editable but seeded with the canonical
-- Nihonshu / Shochu / Liqueur subtypes plus a per-category "Other" row.
-- sort_order in multiples of 10 leaves room for future inserts between
-- seeded values; "Other" sits at 990 so it sorts to the bottom. Category
-- FK is resolved by slug so we don't hardcode UUIDs.
-- ---------------------------------------------------------------------------
INSERT INTO beverage_subcategories (category_id, slug, name_i18n, sort_order)
SELECT
  bc.id,
  v.slug,
  v.name_i18n::jsonb,
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
INNER JOIN beverage_categories AS bc ON v.category_slug = bc.slug;

-- ---------------------------------------------------------------------------
-- Flavor tags — SPEC §4.3 taxonomy.
-- Translations are reasonable defaults; ja/ko strings are reviewable by the
-- product/i18n owner before launch and editable via admin UI later.
-- ---------------------------------------------------------------------------
INSERT INTO flavor_tags (slug, dimension, name_i18n, sort_order) VALUES
-- Sweetness
('dry', 'sweetness', '{"en":"Dry",        "ja":"辛口",   "ko":"드라이"}'::jsonb, 10),
('off_dry', 'sweetness', '{"en":"Off-dry",    "ja":"やや辛口","ko":"오프 드라이"}'::jsonb, 20),
('sweet', 'sweetness', '{"en":"Sweet",      "ja":"甘口",   "ko":"달콤"}'::jsonb, 30),
('very_sweet', 'sweetness', '{"en":"Very sweet", "ja":"極甘口", "ko":"매우 달콤"}'::jsonb, 40),

-- Body
('light', 'body', '{"en":"Light",      "ja":"軽快",   "ko":"라이트"}'::jsonb, 10),
('medium', 'body', '{"en":"Medium",     "ja":"中口",   "ko":"미디엄"}'::jsonb, 20),
('full', 'body', '{"en":"Full",       "ja":"濃醇",   "ko":"풀바디"}'::jsonb, 30),

-- Acidity
('low_acidity', 'acidity', '{"en":"Low",        "ja":"低酸",   "ko":"낮은 산미"}'::jsonb, 10),
('crisp', 'acidity', '{"en":"Crisp",      "ja":"キレ",   "ko":"크리스프"}'::jsonb, 20),
('bright', 'acidity', '{"en":"Bright",     "ja":"爽やか", "ko":"브라이트"}'::jsonb, 30),
('sharp', 'acidity', '{"en":"Sharp",      "ja":"シャープ","ko":"샤프"}'::jsonb, 40),

-- Character
('fruity', 'character', '{"en":"Fruity",     "ja":"フルーティ","ko":"과일향"}'::jsonb, 10),
('floral', 'character', '{"en":"Floral",     "ja":"華やか", "ko":"꽃향"}'::jsonb, 20),
('earthy', 'character', '{"en":"Earthy",     "ja":"土っぽい","ko":"흙내음"}'::jsonb, 30),
('umami', 'character', '{"en":"Umami",      "ja":"旨味",   "ko":"감칠맛"}'::jsonb, 40),
('smoky', 'character', '{"en":"Smoky",      "ja":"スモーキー","ko":"스모키"}'::jsonb, 50),
('nutty', 'character', '{"en":"Nutty",      "ja":"ナッツ", "ko":"고소"}'::jsonb, 60),
('woody', 'character', '{"en":"Woody",      "ja":"木の香り","ko":"우디"}'::jsonb, 70),

-- Finish
('short', 'finish', '{"en":"Short",      "ja":"短い",   "ko":"짧은 피니시"}'::jsonb, 10),
('clean', 'finish', '{"en":"Clean",      "ja":"クリーン","ko":"클린"}'::jsonb, 20),
('lingering', 'finish', '{"en":"Lingering",  "ja":"余韻長い","ko":"긴 여운"}'::jsonb, 30),
('warming', 'finish', '{"en":"Warming",    "ja":"温かみ", "ko":"따뜻한 피니시"}'::jsonb, 40);

-- ---------------------------------------------------------------------------
-- Regions — Japan's 8 traditional regions. sort_order is the conventional
-- north-to-south ordering used across the product surface.
-- ---------------------------------------------------------------------------
INSERT INTO regions (slug, name_i18n, sort_order) VALUES
('hokkaido', '{"en":"Hokkaido","ja":"北海道","ko":"홋카이도"}'::jsonb, 1),
('tohoku', '{"en":"Tōhoku","ja":"東北","ko":"도호쿠"}'::jsonb, 2),
('kanto', '{"en":"Kantō","ja":"関東","ko":"간토"}'::jsonb, 3),
('chubu', '{"en":"Chūbu","ja":"中部","ko":"주부"}'::jsonb, 4),
('kansai', '{"en":"Kansai","ja":"関西","ko":"간사이"}'::jsonb, 5),
('chugoku', '{"en":"Chūgoku","ja":"中国","ko":"주고쿠"}'::jsonb, 6),
('shikoku', '{"en":"Shikoku","ja":"四国","ko":"시코쿠"}'::jsonb, 7),
('kyushu_okinawa', '{"en":"Kyūshū & Okinawa","ja":"九州・沖縄","ko":"규슈・오키나와"}'::jsonb, 8);

-- ---------------------------------------------------------------------------
-- Prefectures (JIS order, Hokkaido=1 … Okinawa=47). Region FKs are resolved
-- by slug so we don't hardcode UUIDs.
-- ---------------------------------------------------------------------------
INSERT INTO prefectures (region_id, slug, name_i18n, sort_order)
SELECT
  r.id,
  v.slug,
  v.name_i18n::jsonb,
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

COMMIT;
