// KAMOS — Screen: Check-in flow (SPEC §4).
// Fields: rating (optional, 0.5–5.0 in 0.5 steps), review (≤500), flavor tags,
// photos (≤4), price (numeric + currency, per-serving | per-bottle),
// purchase type (on-premise | retail | gift | other).

const CheckInScreen = ({ b, onClose, onSubmit }) => {
  const { tt } = useLocale();
  const [rating, setRating] = React.useState(0);    // 0 means "no rating" — VALID per SPEC §4.2
  const [review, setReview] = React.useState('');
  const [tags, setTags] = React.useState(new Set());
  const [photos, setPhotos] = React.useState([]);    // up to 4
  const [price, setPrice] = React.useState('');
  const [currency, setCurrency] = React.useState('JPY');
  const [priceMode, setPriceMode] = React.useState('serving'); // 'serving' | 'bottle'
  const [purchase, setPurchase] = React.useState(null);

  // Predefined flavor tag taxonomy (SPEC §4.3). Organised by dimension.
  const tagDimensions = [
    { dim: tt({ en: 'Sweetness', ja: '甘味', ko: '단맛' }),  tags: ['Dry', 'Off-dry', 'Sweet', 'Very sweet'] },
    { dim: tt({ en: 'Body',      ja: 'ボディ', ko: '바디' }), tags: ['Light', 'Medium', 'Full'] },
    { dim: tt({ en: 'Acidity',   ja: '酸味',   ko: '산미' }), tags: ['Low', 'Crisp', 'Bright', 'Sharp'] },
    { dim: tt({ en: 'Character', ja: '個性',   ko: '캐릭터' }), tags: ['Fruity', 'Floral', 'Earthy', 'Umami', 'Smoky', 'Nutty', 'Woody'] },
    { dim: tt({ en: 'Finish',    ja: '余韻',   ko: '피니시' }), tags: ['Short', 'Clean', 'Lingering', 'Warming'] },
  ];

  const toggleTag = (t) => setTags(prev => {
    const n = new Set(prev);
    n.has(t) ? n.delete(t) : n.add(t);
    return n;
  });

  const addPhoto = () => { if (photos.length < 4) setPhotos(p => [...p, { id: Date.now() }]); };
  const removePhoto = (id) => setPhotos(p => p.filter(x => x.id !== id));

  const reviewOverflow = review.length > 500;
  const canPost = review.length <= 500; // rating is optional, so we don't gate on it

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-page)' }}>
      <div style={{ height: 52, padding: '0 8px', display: 'flex', alignItems: 'center', borderBottom: '1px solid var(--border-1)', flex: 'none' }}>
        <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: 'var(--fg-1)' }}>
          <Icon name="x"/>
        </button>
        <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600, textAlign: 'center' }}>
          {tt(UI.checkinBtn)}
        </div>
        <button onClick={() => onSubmit?.({ rating: rating || null, review, tags: [...tags], photos: photos.length, price: price || null, currency, priceMode, purchase })}
                disabled={!canPost} style={{
          background: !canPost ? 'var(--c-gray-200)' : 'var(--c-ai)',
          color: !canPost ? 'var(--c-gray-400)' : '#fff',
          border: 'none', borderRadius: 999, padding: '8px 16px',
          fontWeight: 600, fontSize: 13, cursor: !canPost ? 'not-allowed' : 'pointer', marginRight: 6,
        }}>{tt(UI.post)}</button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px 24px' }}>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', padding: 12, background: '#fff', border: '1px solid var(--border-1)', borderRadius: 12 }}>
          <Label width={48} height={64} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>{tt(b.name)}</div>
            <div style={{ fontSize: 12, color: 'var(--fg-2)' }}>{tt(b.producer)} · {tt(b.region)}</div>
            <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.1em', color: 'var(--fg-3)', marginTop: 4 }}>
              {tt(CATEGORY_LABELS[b.category])}
            </div>
          </div>
        </div>

        <SectionLabel>{tt(UI.rating)}</SectionLabel>
        <div style={{ padding: '12px 0' }}>
          <StarsInput value={rating} onChange={setRating} size={32}/>
        </div>
        <div style={{ textAlign: 'center', fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--fg-2)' }}>
          {rating > 0 ? `${rating.toFixed(1)} / 5.0` : tt(UI.tapToRate)}
        </div>

        <SectionLabel>{tt(UI.reviewOpt)}</SectionLabel>
        <FormField counter={`${review.length} / 500`} error={reviewOverflow ? tt({ en: 'Review is too long', ja: 'レビューが長すぎます', ko: '리뷰가 너무 깁니다' }) : null}>
          <TextArea
            value={review}
            onChange={setReview}
            placeholder={tt({ en: 'Pear, soft rice, a clean finish…', ja: '梨、柔らかな米、クリアな余韻…', ko: '배, 부드러운 쌀, 깔끔한 피니시…' })}
            maxLength={500}
          />
        </FormField>

        <SectionLabel>{tt(UI.flavorTags)}</SectionLabel>
        {tagDimensions.map(({ dim, tags: list }) => (
          <div key={dim} style={{ marginBottom: 10 }}>
            <div style={{ fontFamily: 'var(--font-body)', fontSize: 10, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', marginBottom: 4 }}>{dim}</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {list.map(t => <Chip key={t} on={tags.has(t)} onClick={() => toggleTag(t)}>{t}</Chip>)}
            </div>
          </div>
        ))}

        <SectionLabel>{tt(UI.photosCap)}</SectionLabel>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
          {[0, 1, 2, 3].map(i => {
            const p = photos[i];
            return p
              ? <PhotoTile key={p.id} filled onRemove={() => removePhoto(p.id)}/>
              : <PhotoTile key={`empty-${i}`} onAdd={addPhoto}/>;
          })}
        </div>
        <div style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)', textAlign: 'right', marginTop: 4 }}>
          {photos.length} / 4
        </div>

        <SectionLabel>{tt(UI.price)}</SectionLabel>
        <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
          <SegmentedControl
            value={currency}
            onChange={setCurrency}
            options={[{ id: 'JPY', label: '¥' }, { id: 'KRW', label: '₩' }, { id: 'USD', label: '$' }]}
          />
          <TextField type="number" value={price} onChange={setPrice} placeholder="1200"/>
        </div>
        <SegmentedControl
          value={priceMode}
          onChange={setPriceMode}
          options={[
            { id: 'serving', label: tt({ en: 'Per serving', ja: '一杯',  ko: '잔당' }) },
            { id: 'bottle',  label: tt({ en: 'Per bottle',  ja: '一本',  ko: '병당' }) },
          ]}
        />

        <SectionLabel>{tt(UI.purchaseType)}</SectionLabel>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {[
            { id: 'on-premise', label: tt({ en: 'On-premise', ja: '店舗', ko: '매장' }) },
            { id: 'retail',     label: tt({ en: 'Retail',     ja: '小売', ko: '소매' }) },
            { id: 'gift',       label: tt({ en: 'Gift',       ja: '贈物', ko: '선물' }) },
            { id: 'other',      label: tt({ en: 'Other',      ja: 'その他', ko: '기타' }) },
          ].map(o => <Chip key={o.id} on={purchase === o.id} onClick={() => setPurchase(o.id === purchase ? null : o.id)}>{o.label}</Chip>)}
        </div>
      </div>
    </div>
  );
};

const SectionLabel = ({ children }) => (
  <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', margin: '20px 0 8px' }}>{children}</div>
);

Object.assign(window, { CheckInScreen });
