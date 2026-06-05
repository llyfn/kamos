// KAMOS — Screen: Check-in flow (SPEC §4, post-MVP redesign per
// docs/history/03_checkin_compose_redesign/00_brief.md).
//
// New layout (top → bottom):
//   1. Beverage card header (label image + name + producer + category overline)
//   2. Rating  — continuous slider 0.5..5.0, 0.25 step, nullable; mono "x.xx / 5.0"
//   3. Review + photo — Row: multi-line note on the left (≤500), 1 fixed square photo right
//   4. Flavor tags — flat horizontally-scrolling row of selected chips + "+ Browse";
//                    Browse opens a tall bottom sheet with search + flat tag list
//   5. Location — venue picker row (Foursquare flow unchanged; just renamed from "Where?")
//   6. Price — currency segmented + amount field + serving/bottle toggle
//   7. Submit — full-width primary pill at the bottom of the form (AppBar action removed)
//
// Removed from compose UI: Purchase Type section. (DB column stays — server-side only.)

const CheckInScreen = ({ b, onClose, onSubmit }) => {
  const { tt } = useLocale();
  const [rating, setRating] = React.useState(null);    // null = unrated (SPEC §4.2)
  const [review, setReview] = React.useState('');
  const [tags, setTags] = React.useState(new Set());
  const [photo, setPhoto] = React.useState(null);      // single tile; ≤1 photo per check-in
  const [price, setPrice] = React.useState('');
  const [currency, setCurrency] = React.useState('JPY');
  const [priceMode, setPriceMode] = React.useState('serving'); // 'serving' | 'bottle'
  const [venue, setVenue] = React.useState(null);
  const [browseOpen, setBrowseOpen] = React.useState(false);
  const [tagQuery, setTagQuery] = React.useState('');

  // Flat flavor tag catalog (SPEC §4.3). No dimension grouping in the picker — the
  // brief calls for a single searchable flat list, so we flatten here.
  const ALL_TAGS = [
    'Dry', 'Off-dry', 'Sweet', 'Very sweet',
    'Light', 'Medium', 'Full',
    'Low', 'Crisp', 'Bright', 'Sharp',
    'Fruity', 'Floral', 'Earthy', 'Umami', 'Smoky', 'Nutty', 'Woody',
    'Short', 'Clean', 'Lingering', 'Warming',
  ];

  const toggleTag = (t) => setTags(prev => {
    const n = new Set(prev);
    n.has(t) ? n.delete(t) : n.add(t);
    return n;
  });

  const reviewOverflow = review.length > 500;
  const canPost = review.length <= 500; // rating optional; photo optional

  const submit = () => onSubmit?.({
    rating, review, tags: [...tags],
    photo: photo ? 1 : 0,
    price: price || null, currency, priceMode,
    venueId: venue?.id ?? null,
  });

  const filteredTags = tagQuery
    ? ALL_TAGS.filter(t => t.toLowerCase().includes(tagQuery.toLowerCase()))
    : ALL_TAGS;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-page)', position: 'relative' }}>
      <div style={{ height: 52, padding: '0 8px', display: 'flex', alignItems: 'center', borderBottom: '1px solid var(--border-1)', flex: 'none' }}>
        <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: 'var(--fg-1)' }}>
          <Icon name="x"/>
        </button>
        <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600, textAlign: 'center' }}>
          {tt(UI.checkinBtn)}
        </div>
        {/* AppBar action removed per redesign brief — submit lives at the bottom of the form. */}
        <div style={{ width: 40 }}/>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px 24px' }}>
        {/* 1. Beverage card header — unchanged */}
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

        {/* 2. Rating — continuous slider, 0.25 step, nullable */}
        <SectionLabel>{tt(UI.rating)}</SectionLabel>
        <RatingSlider value={rating} onChange={setRating}/>

        {/* 3. Review + photo Row — note expands, photo is a fixed 104-dp square on the right */}
        <SectionLabel>{tt(UI.reviewOpt)}</SectionLabel>
        <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <FormField counter={`${review.length} / 500`} error={reviewOverflow ? tt({ en: 'Review is too long', ja: 'レビューが長すぎます', ko: '리뷰가 너무 깁니다' }) : null}>
              <TextArea
                value={review}
                onChange={setReview}
                placeholder={tt({ en: 'Leave a note', ja: 'メモを残す', ko: '메모 남기기' })}
                maxLength={500}
                minHeight={104}
              />
            </FormField>
          </div>
          <div style={{ width: 104, flex: 'none' }}>
            <div style={{ width: 104, height: 104 }}>
              {photo
                ? <PhotoTile filled onRemove={() => setPhoto(null)}/>
                : <PhotoTile onAdd={() => setPhoto({ id: Date.now() })}/>}
            </div>
          </div>
        </div>

        {/* 4. Flavor tags — flat scrollable chip row + "+ Browse" → bottom sheet */}
        <button onClick={() => setBrowseOpen(true)} style={{ background: 'transparent', border: 'none', padding: 0, margin: 0, textAlign: 'left', cursor: 'pointer', width: '100%' }}>
          <SectionLabel>{tt(UI.flavorTags)}</SectionLabel>
        </button>
        <div style={{ display: 'flex', gap: 6, overflowX: 'auto', paddingBottom: 4, scrollbarWidth: 'none' }}>
          {[...tags].map(t => (
            <div key={t} style={{ flex: 'none' }}>
              <Chip on onClick={() => toggleTag(t)}>{t}</Chip>
            </div>
          ))}
          <div style={{ flex: 'none' }}>
            <Chip onClick={() => setBrowseOpen(true)}>
              {tt({ en: '+ Browse', ja: '+ 一覧', ko: '+ 둘러보기' })}
            </Chip>
          </div>
        </div>

        {/* 5. Location — renamed from "Where?"; Foursquare flow unchanged */}
        <SectionLabel>{tt({ en: 'Location', ja: '場所', ko: '위치' })}</SectionLabel>
        <button onClick={() => setVenue(venue ? null : { id: 'fsq-demo', name: 'Sake Bar Buri' })} style={{
          width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '12px 14px',
          background: 'var(--bg-surface)', border: '1px solid var(--border-2)',
          borderRadius: 'var(--radius-sm)', cursor: 'pointer', textAlign: 'left',
        }}>
          <Icon name="pin" size={18} color="var(--fg-2)"/>
          <div style={{ flex: 1, fontFamily: 'var(--font-body)', fontSize: 14, color: venue ? 'var(--fg-1)' : 'var(--fg-muted)' }}>
            {venue ? venue.name : tt({ en: 'Add a venue', ja: '会場を追加', ko: '장소 추가' })}
          </div>
          {venue
            ? <Icon name="x" size={16} color="var(--fg-muted)"/>
            : <Icon name="chev" size={16} color="var(--fg-muted)"/>}
        </button>

        {/* 6. Price — unchanged */}
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

        {/* 7. Full-width submit at the bottom of the form */}
        <div style={{ marginTop: 24 }}>
          <button onClick={canPost ? submit : undefined} disabled={!canPost} style={{
            width: '100%',
            background: !canPost ? 'var(--c-gray-200)' : 'var(--c-ai)',
            color: !canPost ? 'var(--c-gray-400)' : '#fff',
            border: 'none', borderRadius: 999, padding: '14px 20px',
            fontFamily: 'var(--font-body)', fontWeight: 600, fontSize: 15,
            cursor: !canPost ? 'not-allowed' : 'pointer',
          }}>{tt(UI.post)}</button>
        </div>
      </div>

      {/* Flavor tag browse sheet — flat searchable list, large modal */}
      <Sheet open={browseOpen} onClose={() => setBrowseOpen(false)} title={tt(UI.flavorTags)}>
        <div style={{ marginBottom: 12 }}>
          <TextField
            value={tagQuery}
            onChange={setTagQuery}
            placeholder={tt({ en: 'Search tags', ja: 'タグを検索', ko: '태그 검색' })}
          />
        </div>
        <div style={{ maxHeight: 360, overflowY: 'auto', display: 'flex', flexWrap: 'wrap', gap: 6, paddingBottom: 8 }}>
          {filteredTags.map(t => (
            <Chip key={t} on={tags.has(t)} onClick={() => toggleTag(t)}>{t}</Chip>
          ))}
          {filteredTags.length === 0 && (
            <div style={{ width: '100%', padding: '20px 0', textAlign: 'center', color: 'var(--fg-3)', fontSize: 13 }}>
              {tt({ en: 'No matching tags.', ja: '該当するタグがありません。', ko: '일치하는 태그가 없습니다.' })}
            </div>
          )}
        </div>
      </Sheet>
    </div>
  );
};

// ---------------------------------------------------------------------------
// RatingSlider — continuous 0.5..5.0 slider, 0.25 step (19 levels), nullable.
// Renders the current value as "x.xx / 5.0" in mono next to a "Clear" affordance.
// Internal range is 0..18 (19 stops); value = 0.5 + index * 0.25.
// `null` = unrated; the slider visually parks at the low rail.
// ---------------------------------------------------------------------------
const RatingSlider = ({ value, onChange }) => {
  const { tt } = useLocale();
  const STEP_COUNT = 18; // 0.5..5.0 inclusive in 0.25 increments = 19 stops, 18 steps
  const toIdx = (v) => v == null ? 0 : Math.round((v - 0.5) * 4);
  const fromIdx = (i) => +(0.5 + i * 0.25).toFixed(2);
  const idx = toIdx(value);
  const percent = (idx / STEP_COUNT) * 100;

  return (
    <div style={{ padding: '8px 0 4px' }}>
      <div style={{ position: 'relative', height: 28, display: 'flex', alignItems: 'center' }}>
        <input
          type="range"
          min={0}
          max={STEP_COUNT}
          step={1}
          value={idx}
          onChange={(e) => onChange?.(fromIdx(Number(e.target.value)))}
          style={{
            width: '100%', appearance: 'none', background: 'transparent',
            outline: 'none', margin: 0,
          }}
        />
        {/* track (visual only — sits behind the native input) */}
        <div style={{
          position: 'absolute', left: 0, right: 0, top: '50%', transform: 'translateY(-50%)',
          height: 4, borderRadius: 2, background: 'var(--c-gray-200)', pointerEvents: 'none',
        }}>
          <div style={{
            width: value == null ? 0 : `${percent}%`, height: '100%',
            background: 'var(--c-ai)', borderRadius: 2,
          }}/>
        </div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 6 }}>
        <div style={{ fontFamily: 'var(--font-mono)', fontSize: 13, color: value == null ? 'var(--fg-3)' : 'var(--fg-1)' }}>
          {value == null ? '— / 5.0' : `${value.toFixed(2)} / 5.0`}
        </div>
        <button
          onClick={() => onChange?.(null)}
          disabled={value == null}
          style={{
            background: 'transparent', border: 'none',
            padding: '4px 8px', cursor: value == null ? 'default' : 'pointer',
            fontFamily: 'var(--font-body)', fontSize: 12, fontWeight: 600,
            color: value == null ? 'var(--fg-muted)' : 'var(--fg-brand)',
          }}
        >
          {tt({ en: 'Clear', ja: 'クリア', ko: '지우기' })}
        </button>
      </div>
    </div>
  );
};

const SectionLabel = ({ children }) => (
  <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', margin: '20px 0 8px' }}>{children}</div>
);

Object.assign(window, { CheckInScreen, RatingSlider });
