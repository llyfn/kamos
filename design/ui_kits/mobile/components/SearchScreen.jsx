// KAMOS — Screen: Search / Discover (SPEC §7).
// - Full-text search across beverage + producer names, all locales.
// - Category chips render exact SPEC §2.1 strings, per locale.
// - Empty state shows recent searches; no-results state shows a calm message.

const SearchScreen = ({ catalog, onPickBeverage, onPickProducer, recentSearches = [], placeholderMode = false }) => {
  const { tt, locale } = useLocale();
  const [q, setQ] = React.useState('');
  const [cat, setCat] = React.useState('all');

  // Category chips: exact SPEC §2.1 strings — never abbreviate, never substitute.
  const cats = [
    { id: 'all',       label: tt({ en: 'All', ja: 'すべて', ko: '전체' }) },
    { id: 'nihonshu',  label: tt(CATEGORY_LABELS.nihonshu) },
    { id: 'shochu',    label: tt(CATEGORY_LABELS.shochu) },
    { id: 'liqueur',   label: tt(CATEGORY_LABELS.liqueur) },
  ];

  // Search matches name + producer across all locales (SPEC §7).
  const matches = (b) => {
    if (!q) return true;
    const needle = q.toLowerCase();
    const fields = [b.name, b.producer, b.region].flatMap(n => Object.values(n || {}));
    return fields.some(s => typeof s === 'string' && s.toLowerCase().includes(needle));
  };
  const filtered = (catalog || []).filter(b => (cat === 'all' || b.category === cat) && matches(b));

  const showRecent = !q && cat === 'all' && filtered.length > 0;
  const noResults  = !!q && filtered.length === 0;

  return (
    <div style={{ flex: 1, overflowY: 'auto' }}>
      <div style={{ padding: '8px 16px 12px', position: 'sticky', top: 0, background: 'var(--bg-page)', zIndex: 5 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600, padding: '4px 4px 12px' }}>
          {tt(UI.discover)}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 14px', borderRadius: 999, background: 'var(--c-gray-100)' }}>
          <Icon name="search" size={18} color="var(--fg-3)"/>
          <input
            value={q}
            onChange={e => setQ(e.target.value)}
            placeholder={tt(UI.emptySearch)}
            style={{ flex: 1, border: 'none', background: 'transparent', outline: 'none', fontSize: 14, fontFamily: 'var(--font-body)' }}
          />
          {q && (
            <button onClick={() => setQ('')} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-3)' }}>
              <Icon name="x" size={16}/>
            </button>
          )}
        </div>
        <div style={{ display: 'flex', gap: 8, padding: '12px 0 4px', overflowX: 'auto' }}>
          {cats.map(c => <Chip key={c.id} on={cat === c.id} onClick={() => setCat(c.id)}>{c.label}</Chip>)}
        </div>
      </div>

      {placeholderMode && !q && cat === 'all' && recentSearches.length > 0 && (
        <div style={{ padding: '4px 16px 4px' }}>
          <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', padding: '8px 4px' }}>
            {tt({ en: 'Recent searches', ja: '最近の検索', ko: '최근 검색' })}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {recentSearches.map(r => <Chip key={r} kind="tag" onClick={() => setQ(r)}>{r}</Chip>)}
          </div>
        </div>
      )}

      {noResults ? (
        <EmptyState
          glyph="—"
          title={tt({ en: 'No results', ja: '該当なし', ko: '결과 없음' })}
          body={tt(UI.noResults)}
        />
      ) : (
        <div style={{ padding: '4px 16px 16px' }}>
          {!placeholderMode && (
            <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', padding: '8px 4px' }}>
              {filtered.length} {tt({ en: filtered.length === 1 ? 'result' : 'results', ja: '件', ko: '건' })}
            </div>
          )}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {filtered.map(b => (
              <Card key={b.id} onClick={() => onPickBeverage?.(b)}>
                <div style={{ display: 'flex', gap: 12 }}>
                  <Label width={52} height={68} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>{tt(b.name)}</div>
                    <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>{tt(b.producer)} · {tt(b.region)}</div>
                    <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 2 }}>{tt(b.subcategory)} · {b.abv.toFixed(1)}%</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
                      <Stars value={b.rating} size={12}/>
                      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 600 }}>{b.rating.toFixed(1)} / 5.0</span>
                      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)', marginLeft: 4 }}>· {b.checkins}</span>
                    </div>
                  </div>
                  <Icon name="chev" size={18} color="var(--fg-muted)"/>
                </div>
              </Card>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

Object.assign(window, { SearchScreen });
