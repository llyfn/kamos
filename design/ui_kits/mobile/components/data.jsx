// KAMOS — Sample data for the UI kit. Realistic-feeling but invented.
//
// Notes for downstream agents:
//   - `category` is a stable key (`nihonshu` | `shochu` | `liqueur`).
//     Display strings live in CATEGORY_LABELS below, per locale.
//     This is the SPEC §2.1 contract — never abbreviate / never substitute.
//   - i18n names use { en, ja, ko? } shape. Resolver `t(node, locale)` applies
//     fallback `ko → en`, `ja → en` per SPEC §6.5.

// ---------------------------------------------------------------------------
// I18n: category labels — exact per SPEC §2.1 / brief §6.1.
// ---------------------------------------------------------------------------
const CATEGORY_LABELS = {
  nihonshu: { en: 'Nihonshu (Sake)', ja: '日本酒',     ko: '니혼슈 (사케)' },
  shochu:   { en: 'Shochu',           ja: '焼酎',       ko: '쇼츄' },
  liqueur:  { en: 'Liqueur',          ja: 'リキュール', ko: '리큐어' },
};

// Resolve an i18n node ({ en, ja, ko? }) for a locale, with SPEC §6.5 fallback.
const t = (node, locale) => {
  if (!node) return '';
  if (typeof node === 'string') return node;
  return node[locale] || node.en || node.ja || '';
};

// ---------------------------------------------------------------------------
// UI strings — small set used across screens. Not exhaustive (Flutter ARB
// is canonical); this is enough to render en/ja/ko samples in the demo.
// ---------------------------------------------------------------------------
const UI = {
  // tabs
  feed:     { en: 'Feed',     ja: 'フィード', ko: '피드' },
  search:   { en: 'Search',   ja: '探す',     ko: '검색' },
  checkin:  { en: 'Check in', ja: 'チェックイン', ko: '체크인' },
  lists:    { en: 'Lists',    ja: 'リスト',   ko: '리스트' },
  me:       { en: 'Me',       ja: 'マイページ', ko: '마이' },

  // headers
  following:    { en: 'Following', ja: 'フォロー中', ko: '팔로잉' },
  fromFollow:   { en: 'From people you follow', ja: 'フォロー中の人から', ko: '팔로우 중인 사람들의 활동' },
  discover:     { en: 'Discover', ja: '探す', ko: '둘러보기' },
  collections:  { en: 'Collections', ja: 'コレクション', ko: '컬렉션' },
  recentChk:    { en: 'Recent check-ins', ja: '最近のチェックイン', ko: '최근 체크인' },
  flavorAgg:    { en: 'Aggregated flavor', ja: 'フレーバー傾向', ko: '풍미 프로필' },
  aboutProducer: { en: 'About the producer', ja: '蔵元について', ko: '생산자 소개' },

  // buttons / actions
  checkinBtn:  { en: 'Check in',     ja: 'チェックイン', ko: '체크인' },
  addToList:   { en: 'Add to list',  ja: 'リストに追加', ko: '리스트에 추가' },
  editProfile: { en: 'Edit profile', ja: 'プロフィール編集', ko: '프로필 편집' },
  settings:    { en: 'Settings',     ja: '設定',          ko: '설정' },
  post:        { en: 'Post',         ja: '投稿',          ko: '게시' },
  save:        { en: 'Save',         ja: '保存',          ko: '저장' },
  cancel:      { en: 'Cancel',       ja: 'キャンセル',     ko: '취소' },
  newList:     { en: 'New list',     ja: '新しいリスト',   ko: '새 리스트' },
  approve:     { en: 'Approve',      ja: '承認',          ko: '수락' },
  decline:     { en: 'Decline',      ja: '辞退',          ko: '거절' },
  signIn:      { en: 'Sign in',      ja: 'サインイン',     ko: '로그인' },
  signUp:      { en: 'Create account', ja: 'アカウント作成', ko: '계정 만들기' },

  // check-in
  rating:        { en: 'Rating',        ja: '評価',           ko: '평점' },
  reviewOpt:     { en: 'Review · optional', ja: 'レビュー · 任意', ko: '리뷰 · 선택' },
  flavorTags:    { en: 'Flavor tags',   ja: 'フレーバータグ', ko: '풍미 태그' },
  photosCap:     { en: 'Photos · up to 4', ja: '写真 · 4枚まで', ko: '사진 · 최대 4장' },
  price:         { en: 'Price · optional', ja: '価格 · 任意', ko: '가격 · 선택' },
  purchaseType:  { en: 'Purchase type', ja: '購入種別',       ko: '구매 유형' },
  tapToRate:     { en: 'Tap a star to rate · half-steps allowed',
                   ja: 'スターをタップ · 0.5刻みで評価',
                   ko: '별을 탭하여 평가 · 0.5 단위' },

  // empty / loading / error
  emptyFeed:     { en: "No check-ins yet. Follow some people, or tap + to log your first.",
                   ja: 'まだチェックインがありません。誰かをフォローするか、＋から最初の一杯を記録しましょう。',
                   ko: '아직 체크인이 없습니다. 누군가를 팔로우하거나 ＋ 버튼으로 첫 기록을 남겨보세요.' },
  emptySearch:   { en: 'Search producers, beverages, prefectures.',
                   ja: '蔵元・銘柄・都道府県で検索',
                   ko: '생산자 · 술 · 지역으로 검색' },
  noResults:     { en: 'No matches. Try a different search.',
                   ja: '該当なし。別の言葉で試してください。',
                   ko: '결과가 없습니다. 다른 검색어를 시도해보세요.' },
  loadingMore:   { en: 'Loading more', ja: '読み込み中', ko: '불러오는 중' },
  errorRetry:    { en: 'Could not load. Tap to retry.',
                   ja: '読み込めませんでした。タップしてやり直し。',
                   ko: '불러올 수 없습니다. 탭하여 다시 시도하세요.' },
};

// ---------------------------------------------------------------------------
// Catalog — i18n names; `category` is a stable key.
// ---------------------------------------------------------------------------
const CATALOG = [
  {
    id: 'dassai-23',
    name: { en: 'Dassai 23', ja: '獺祭 純米大吟醸 二割三分', ko: '닷사이 23' },
    kanji: '獺祭', labelRomaji: '23',
    producer: { en: 'Asahi Shuzo', ja: '旭酒造', ko: '아사히 주조' },
    producerId: 'asahi-shuzo',
    region: { en: 'Yamaguchi', ja: '山口', ko: '야마구치' },
    category: 'nihonshu',
    subcategory: { en: 'Junmai Daiginjo', ja: '純米大吟醸', ko: '준마이 다이긴조' },
    abv: 16.0, seimai: 23, rating: 4.5, checkins: 2841, labelTone: 'navy',
    flavor: ['Fruity', 'Floral', 'Light', 'Crisp', 'Lingering', 'Pear'],
    about: {
      en: 'Founded in 1948 in the mountains of Iwakuni. Asahi Shuzo polishes its rice further than almost any producer — the name 23 refers to the percentage of grain remaining.',
      ja: '1948年、岩国の山中にて創業。旭酒造の精米歩合は業界でも最も低い水準。「二割三分」は残された米の割合を指す。',
      ko: '1948년 이와쿠니의 산속에서 창업. 아사히 주조는 업계에서 가장 낮은 정미율로 유명하며, "23"은 깎인 후 남은 쌀의 비율을 의미한다.',
    },
    recent: [
      { user: 'aiko',   rating: 4.5, review: 'Bright pear, soft rice. Finish lingers, faintly mineral.' },
      { user: 'minjun', rating: 4.0, review: '깔끔하고 우아한 단맛. 처음 마시는 사람에게도 추천.' },
      { user: 'tetsu',  rating: 5.0, review: '間違いない一本。冷やしてグラスで。' },
    ],
  },
  {
    id: 'kuromatsu',
    name: { en: 'Kuromatsu Kenbishi', ja: '黒松剣菱', ko: '쿠로마츠 켄비시' },
    kanji: '黒松', labelRomaji: '剣菱',
    producer: { en: 'Kenbishi Shuzo', ja: '剣菱酒造', ko: '켄비시 주조' },
    producerId: 'kenbishi-shuzo',
    region: { en: 'Hyōgo', ja: '兵庫', ko: '효고' },
    category: 'nihonshu',
    subcategory: { en: 'Junmai', ja: '純米', ko: '준마이' },
    abv: 17.0, seimai: 70, rating: 4.2, checkins: 612, labelTone: 'navy',
    flavor: ['Umami', 'Full', 'Earthy', 'Warming', 'Nutty'],
    about: {
      en: 'Brewed continuously since 1505 — one of the oldest sake brands in Japan. A robust kimoto style; serve warm.',
      ja: '1505年から続く銘柄。日本最古級の酒蔵のひとつ。生酛仕込みの骨太な味わい。燗で。',
      ko: '1505년부터 빚어온, 일본에서 가장 오래된 사케 브랜드 중 하나. 키모토 방식의 묵직한 맛. 따뜻하게 권장.',
    },
    recent: [
      { user: 'tetsu', rating: 4.5, review: 'Old-school. Best at 45°C with a small carafe.' },
    ],
  },
  {
    id: 'kuro-kirishima',
    name: { en: 'Kuro Kirishima', ja: '黒霧島', ko: '쿠로 키리시마' },
    kanji: '黒霧島', labelRomaji: '',
    producer: { en: 'Kirishima Shuzo', ja: '霧島酒造', ko: '키리시마 주조' },
    producerId: 'kirishima-shuzo',
    region: { en: 'Miyazaki', ja: '宮崎', ko: '미야자키' },
    category: 'shochu',
    subcategory: { en: 'Imo Shochu', ja: '芋焼酎', ko: '이모쇼츄' },
    abv: 25.0, rating: 4.0, checkins: 904, labelTone: 'koh',
    flavor: ['Sweet', 'Earthy', 'Full', 'Warming'],
    about: {
      en: 'Sweet potato shochu with black koji. Try it oyuwari (cut with hot water).',
      ja: '黒麹仕込みの芋焼酎。お湯割りで。',
      ko: '흑국으로 빚은 고구마 쇼츄. 오유와리(뜨거운 물에 희석)로 권장.',
    },
    recent: [
      { user: 'aiko', rating: 4.0, review: 'Roasted sweet potato. Hot water, 6:4.' },
    ],
  },
  {
    id: 'iichiko',
    name: { en: 'Iichiko Silhouette', ja: 'いいちこ シルエット', ko: '이이치코 실루엣' },
    kanji: 'いいちこ', labelRomaji: '',
    producer: { en: 'Sanwa Shurui', ja: '三和酒類', ko: '산와 슈루이' },
    producerId: 'sanwa-shurui',
    region: { en: 'Ōita', ja: '大分', ko: '오이타' },
    category: 'shochu',
    subcategory: { en: 'Mugi Shochu', ja: '麦焼酎', ko: '무기쇼츄' },
    abv: 25.0, rating: 3.8, checkins: 1450, labelTone: 'sky',
    flavor: ['Light', 'Crisp', 'Nutty', 'Clean'],
    about: {
      en: 'Barley shochu, smooth enough to drink straight or on the rocks.',
      ja: '麦焼酎。ロックでもストレートでもいけるクリーンな味わい。',
      ko: '보리 쇼츄. 스트레이트나 온더록스 모두 잘 어울리는 부드러운 맛.',
    },
    recent: [],
  },
  {
    id: 'choya-umeshu',
    name: { en: 'Choya Umeshu', ja: 'チョーヤ 梅酒', ko: '초야 매실주' },
    kanji: '梅酒', labelRomaji: '',
    producer: { en: 'Choya', ja: 'チョーヤ梅酒', ko: '초야' },
    producerId: 'choya',
    region: { en: 'Osaka', ja: '大阪', ko: '오사카' },
    category: 'liqueur',
    subcategory: { en: 'Umeshu', ja: '梅酒', ko: '우메슈' },
    abv: 14.0, rating: 4.1, checkins: 3120, labelTone: 'matcha',
    flavor: ['Sweet', 'Fruity', 'Bright'],
    about: {
      en: 'Plum liqueur infused with whole ume.',
      ja: '青梅を漬け込んだ梅酒。',
      ko: '청매실을 통째로 담근 매실주.',
    },
    recent: [],
  },
  {
    id: 'kubota-senju',
    name: { en: 'Kubota Senjyu', ja: '久保田 千寿', ko: '쿠보타 센쥬' },
    kanji: '久保田', labelRomaji: '千寿',
    producer: { en: 'Asahi Shuzo (Niigata)', ja: '朝日酒造（新潟）', ko: '아사히 주조 (니가타)' },
    producerId: 'asahi-niigata',
    region: { en: 'Niigata', ja: '新潟', ko: '니가타' },
    category: 'nihonshu',
    subcategory: { en: 'Tokubetsu Honjozo', ja: '特別本醸造', ko: '토쿠베츠 혼조조' },
    abv: 15.0, seimai: 55, rating: 4.3, checkins: 1880, labelTone: 'navy',
    flavor: ['Dry', 'Light', 'Crisp', 'Clean'],
    about: {
      en: 'A Niigata classic — quiet, dry, food-friendly.',
      ja: '新潟の定番。静かでドライ、料理に寄り添う一本。',
      ko: '니가타의 클래식. 조용하고 드라이하며 음식과 잘 어울린다.',
    },
    recent: [],
  },
];

// ---------------------------------------------------------------------------
// Producers — used by ProducerScreen (SPEC §2.3, §7 "browse by producer").
// ---------------------------------------------------------------------------
const PRODUCERS = {
  'asahi-shuzo': {
    id: 'asahi-shuzo',
    name: { en: 'Asahi Shuzo', ja: '旭酒造', ko: '아사히 주조' },
    region: { en: 'Yamaguchi', ja: '山口', ko: '야마구치' },
    founded: 1948,
    website: 'https://asahishuzo.ne.jp',
    description: {
      en: 'Iwakuni-based producer responsible for Dassai. Polishes rice further than nearly any rival.',
      ja: '岩国に拠点を構える「獺祭」の蔵元。業界でもとりわけ低い精米歩合で知られる。',
      ko: '이와쿠니에 자리한 "닷사이"의 생산자. 업계에서 가장 낮은 수준의 정미율로 유명하다.',
    },
    beverageIds: ['dassai-23'],
  },
  'kenbishi-shuzo': {
    id: 'kenbishi-shuzo',
    name: { en: 'Kenbishi Shuzo', ja: '剣菱酒造', ko: '켄비시 주조' },
    region: { en: 'Hyōgo', ja: '兵庫', ko: '효고' },
    founded: 1505,
    website: 'https://www.kenbishi.co.jp',
    description: {
      en: 'One of the oldest continuously operating sake producers in Japan. Kimoto-method, full-bodied, served warm.',
      ja: '日本最古級の酒蔵のひとつ。生酛仕込みの骨太な造り。',
      ko: '일본에서 가장 오래된 사케 생산자 중 하나. 키모토 방식의 묵직한 맛.',
    },
    beverageIds: ['kuromatsu'],
  },
  'kirishima-shuzo': {
    id: 'kirishima-shuzo',
    name: { en: 'Kirishima Shuzo', ja: '霧島酒造', ko: '키리시마 주조' },
    region: { en: 'Miyazaki', ja: '宮崎', ko: '미야자키' },
    founded: 1916,
    website: 'https://www.kirishima.co.jp',
    description: {
      en: 'Miyazaki-based maker of Kuro Kirishima, the canonical black-koji imo shochu.',
      ja: '宮崎の蔵。黒麹仕込みの「黒霧島」で知られる。',
      ko: '미야자키에 자리한 양조장. 흑국으로 빚은 "쿠로 키리시마"로 알려져 있다.',
    },
    beverageIds: ['kuro-kirishima'],
  },
};

// ---------------------------------------------------------------------------
// Feed — i18n is applied at render time via t().
// ---------------------------------------------------------------------------
const FEED = [
  {
    id: 'f1', user: 'aiko', tone: 'kinari', when: '2 hours ago',
    beverageId: 'dassai-23',
    rating: 4.5,
    review: 'Bright pear, soft rice. Finish lingers, faintly mineral.',
    tags: ['Dry', 'Floral', 'Umami'], toasts: 12, photoCount: 1,
  },
  {
    id: 'f2', user: 'minjun', tone: 'mizu', when: '6 hours ago',
    beverageId: 'choya-umeshu',
    rating: 4.0,
    review: '여름 저녁에 얼음 잔뜩 넣어서. 단맛이 너무 무겁지 않아 좋았어요.',
    tags: ['Sweet', 'Fruity'], toasts: 4, photoCount: 0,
  },
  {
    id: 'f3', user: 'tetsu', tone: 'kon', when: 'Yesterday',
    beverageId: 'kuromatsu',
    rating: 4.5,
    review: '燗で。45度くらいがちょうどいい。米の旨味がじわっと。',
    tags: ['Umami', 'Warming', 'Earthy'], toasts: 22, photoCount: 2,
  },
];

// ---------------------------------------------------------------------------
// Collections — SPEC §6. `Inventory` + `Wishlist` are default; the rest are
// user-created. All collections are owner-private in MVP.
// ---------------------------------------------------------------------------
const COLLECTIONS = [
  { id: 'inv',    name: 'Inventory',    glyph: '酒', tone: 'kon',  count: 12, note: 'At home right now', isDefault: true,  beverageIds: ['dassai-23', 'kubota-senju'] },
  { id: 'wish',   name: 'Wishlist',     glyph: '望', tone: 'koh',  count: 28, note: 'Want to try',       isDefault: true,  beverageIds: ['kuromatsu', 'choya-umeshu'] },
  { id: 'travel', name: 'Niigata trip',              count: 6,  note: 'Custom · April',     isDefault: false, beverageIds: ['kubota-senju'] },
  { id: 'gifts',  name: 'Gifts to send',             count: 3,  note: 'Custom',             isDefault: false, beverageIds: [] },
];

// ---------------------------------------------------------------------------
// Profile (Me) — display_username preserves case (SPEC §6.3); handle is
// the stored-lowercase form.
// ---------------------------------------------------------------------------
const ME = {
  initial: 'Y',
  displayName: 'Yamamoto',                 // free-text display name (≤50)
  displayUsername: 'Yamamoto',             // as entered at registration
  handle: 'yamamoto',                       // stored-lowercase, case-insensitive uniqueness
  email: 'yamamoto@example.com',
  emailVerified: true,
  bio: 'Logging Junmai and Imo Shochu. Tokyo & Kagoshima.',
  locale: 'en',                             // preference; defaults to device
  privacy: 'public',                        // 'public' | 'private' (SPEC §5.1)
  stats: { checkins: 184, unique: 92, followers: 320, following: 144 },
};

const MY_RECENT = [
  { id: 'r1', beverageId: 'dassai-23',  rating: 4.5, when: 'Apr 28' },
  { id: 'r2', beverageId: 'iichiko',    rating: 3.5, when: 'Apr 22' },
  { id: 'r3', beverageId: 'kuro-kirishima', rating: 4.0, when: 'Apr 14' },
];

// ---------------------------------------------------------------------------
// Follow request inbox (SPEC §5.4) — pending requests, badge count =
// requests.length while user.privacy === 'private'.
// ---------------------------------------------------------------------------
const FOLLOW_REQUESTS = [
  { id: 'req-1', user: 'sora_t',  displayName: 'Sora T.',      avatar: 'S', bio: 'Junmai, Niigata.',          when: '2 hours ago' },
  { id: 'req-2', user: 'minjun',  displayName: 'Minjun',       avatar: 'M', bio: '쇼츄, 매실주, 청주.',           when: 'Yesterday' },
  { id: 'req-3', user: 'kentaro', displayName: 'Kentaro N.',   avatar: 'K', bio: 'Shochu over rocks.',         when: '3 days ago' },
];

// ---------------------------------------------------------------------------
// Search history — for SearchScreen's empty/recent state.
// ---------------------------------------------------------------------------
const RECENT_SEARCHES = ['Dassai', 'Niigata', 'Junmai Ginjo', 'Kuro Kirishima'];

Object.assign(window, {
  CATEGORY_LABELS, t, UI,
  CATALOG, PRODUCERS, FEED, COLLECTIONS, ME, MY_RECENT,
  FOLLOW_REQUESTS, RECENT_SEARCHES,
});
