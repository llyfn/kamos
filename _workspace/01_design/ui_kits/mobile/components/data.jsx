// KAMOS — Sample data for the UI kit. Realistic-feeling but invented.

const CATALOG = [
  {
    id: 'dassai-23', name: 'Dassai 23', kanji: '獺祭', labelRomaji: '23',
    brewery: 'Asahi Shuzo', region: 'Yamaguchi',
    category: 'nihonshu', subcategory: 'Junmai Daiginjo',
    abv: 16.0, seimai: 23, rating: 4.5, checkins: 2841, labelTone: 'navy',
    flavor: ['Fruity', 'Floral', 'Light', 'Crisp', 'Lingering', 'Pear'],
    about: 'Founded in 1948 in the mountains of Iwakuni. Asahi Shuzo polishes its rice further than almost any brewery, hence the name 23 — the percentage of grain remaining.',
    recent: [
      { user: 'aiko', rating: 4.5, review: 'Bright pear, soft rice. Finish lingers, faintly mineral.' },
      { user: 'minjun', rating: 4.0, review: '깔끔하고 우아한 단맛. 처음 마시는 사람에게도 추천.' },
      { user: 'tetsu', rating: 5.0, review: '間違いない一本。冷やしてグラスで。' },
    ],
  },
  {
    id: 'kuromatsu', name: 'Kuromatsu Kenbishi', kanji: '黒松', labelRomaji: '剣菱',
    brewery: 'Kenbishi Shuzo', region: 'Hyōgo',
    category: 'nihonshu', subcategory: 'Junmai',
    abv: 17.0, seimai: 70, rating: 4.2, checkins: 612, labelTone: 'navy',
    flavor: ['Umami', 'Full', 'Earthy', 'Warming', 'Nutty'],
    about: 'Brewed continuously since 1505 — one of the oldest sake brands in Japan. A robust kimoto style; serve warm.',
    recent: [
      { user: 'tetsu', rating: 4.5, review: 'Old-school. Best at 45°C with a small carafe.' },
    ],
  },
  {
    id: 'kuro-kirishima', name: 'Kuro Kirishima', kanji: '黒霧島', labelRomaji: '',
    brewery: 'Kirishima Shuzo', region: 'Miyazaki',
    category: 'shochu', subcategory: 'Imo Shochu',
    abv: 25.0, rating: 4.0, checkins: 904, labelTone: 'koh',
    flavor: ['Sweet', 'Earthy', 'Full', 'Warming'],
    about: 'Sweet potato shochu with black koji. Try it oyuwari (cut with hot water).',
    recent: [
      { user: 'aiko', rating: 4.0, review: 'Roasted sweet potato. Hot water, 6:4.' },
    ],
  },
  {
    id: 'iichiko', name: 'Iichiko Silhouette', kanji: 'いいちこ', labelRomaji: '',
    brewery: 'Sanwa Shurui', region: 'Ōita',
    category: 'shochu', subcategory: 'Mugi Shochu',
    abv: 25.0, rating: 3.8, checkins: 1450, labelTone: 'sky',
    flavor: ['Light', 'Crisp', 'Nutty', 'Clean'],
    about: 'Barley shochu, smooth enough to drink straight or on the rocks.',
    recent: [],
  },
  {
    id: 'choya-umeshu', name: 'Choya Umeshu', kanji: '梅酒', labelRomaji: '',
    brewery: 'Choya', region: 'Osaka',
    category: 'liqueur', subcategory: 'Umeshu',
    abv: 14.0, rating: 4.1, checkins: 3120, labelTone: 'matcha',
    flavor: ['Sweet', 'Fruity', 'Bright'],
    about: 'Plum liqueur, infused with whole ume.',
    recent: [],
  },
  {
    id: 'kubota-senju', name: 'Kubota Senjyu', kanji: '久保田', labelRomaji: '千寿',
    brewery: 'Asahi Shuzo (Niigata)', region: 'Niigata',
    category: 'nihonshu', subcategory: 'Tokubetsu Honjozo',
    abv: 15.0, seimai: 55, rating: 4.3, checkins: 1880, labelTone: 'navy',
    flavor: ['Dry', 'Light', 'Crisp', 'Clean'],
    about: 'A Niigata classic — quiet, dry, food-friendly.',
    recent: [],
  },
];

const FEED = [
  {
    id: 'f1', user: 'aiko', tone: 'kinari', when: '2 hours ago',
    beverage: 'Dassai 23', kanji: '獺祭', labelRomaji: '23', labelTone: 'navy',
    brewery: 'Asahi Shuzo · Yamaguchi',
    rating: 4.5, review: 'Bright pear, soft rice. Finish lingers, faintly mineral.',
    tags: ['Dry', 'Floral', 'Umami'], toasts: 12,
  },
  {
    id: 'f2', user: 'minjun', tone: 'mizu', when: '6 hours ago',
    beverage: 'Choya Umeshu', kanji: '梅酒', labelTone: 'matcha',
    brewery: 'Choya · Osaka',
    rating: 4.0, review: '여름 저녁에 얼음 잔뜩 넣어서. 단맛이 너무 무겁지 않아 좋았어요.',
    tags: ['Sweet', 'Fruity'], toasts: 4,
  },
  {
    id: 'f3', user: 'tetsu', tone: 'kon', when: 'Yesterday',
    beverage: 'Kuromatsu Kenbishi', kanji: '黒松', labelRomaji: '剣菱', labelTone: 'navy',
    brewery: 'Kenbishi Shuzo · Hyōgo',
    rating: 4.5, review: '燗で。45度くらいがちょうどいい。米の旨味がじわっと。',
    tags: ['Umami', 'Warming', 'Earthy'], toasts: 22,
  },
];

const COLLECTIONS = [
  { id: 'inv', name: 'Inventory', glyph: '酒', tone: 'kon', count: 12, note: 'At home right now' },
  { id: 'wish', name: 'Wishlist', glyph: '望', tone: 'koh', count: 28, note: 'Want to try' },
  { id: 'travel', name: 'Niigata trip', count: 6, note: 'Custom · April' },
  { id: 'gifts', name: 'Gifts to send', count: 3, note: 'Custom' },
];

const ME = {
  initial: 'Y', name: 'Yamamoto', handle: 'yamamoto',
  bio: 'Logging Junmai and Imo Shochu. Tokyo & Kagoshima.',
  stats: { checkins: 184, unique: 92, followers: 320, following: 144 },
};

const MY_RECENT = [
  { id: 'r1', beverage: 'Dassai 23', kanji: '獺祭', labelTone: 'navy', brewery: 'Asahi Shuzo', rating: 4.5, when: 'Apr 28' },
  { id: 'r2', beverage: 'Iichiko Silhouette', kanji: 'いいちこ', labelTone: 'sky', brewery: 'Sanwa Shurui', rating: 3.5, when: 'Apr 22' },
  { id: 'r3', beverage: 'Kuro Kirishima', kanji: '黒霧島', labelTone: 'koh', brewery: 'Kirishima Shuzo', rating: 4.0, when: 'Apr 14' },
];

Object.assign(window, { CATALOG, FEED, COLLECTIONS, ME, MY_RECENT });
