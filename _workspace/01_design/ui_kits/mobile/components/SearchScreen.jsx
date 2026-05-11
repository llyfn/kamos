// KAMOS — Screen: Search / Discover

const SearchScreen = ({ catalog, onPickBeverage }) => {
  const [q, setQ] = React.useState('');
  const [cat, setCat] = React.useState('all');
  const cats = [
    { id: 'all', label: 'All' },
    { id: 'nihonshu', label: 'Nihonshu · 日本酒' },
    { id: 'shochu', label: 'Shochu · 焼酎' },
    { id: 'liqueur', label: 'Liqueur · リキュール' },
  ];
  const filtered = catalog.filter(b =>
    (cat === 'all' || b.category === cat) &&
    (!q || b.name.toLowerCase().includes(q.toLowerCase()) || b.brewery.toLowerCase().includes(q.toLowerCase()))
  );
  return (
    <div style={{ flex: 1, overflowY: 'auto' }}>
      <div style={{ padding: '8px 16px 12px', position: 'sticky', top: 0, background: 'var(--bg-page)', zIndex: 5 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600, padding: '4px 4px 12px' }}>Discover</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 14px', borderRadius: 999, background: 'var(--c-gray-100)' }}>
          <Icon name="search" size={18} color="var(--fg-3)"/>
          <input value={q} onChange={e => setQ(e.target.value)} placeholder="Search breweries, beverages, prefectures…" style={{ flex: 1, border: 'none', background: 'transparent', outline: 'none', fontSize: 14, fontFamily: 'var(--font-body)' }}/>
          {q && <button onClick={() => setQ('')} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-3)' }}><Icon name="x" size={16}/></button>}
        </div>
        <div style={{ display: 'flex', gap: 8, padding: '12px 0 4px', overflowX: 'auto' }}>
          {cats.map(c => <Chip key={c.id} on={cat === c.id} onClick={() => setCat(c.id)}>{c.label}</Chip>)}
        </div>
      </div>
      <div style={{ padding: '4px 16px 16px' }}>
        <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', padding: '8px 4px' }}>
          {filtered.length} result{filtered.length === 1 ? '' : 's'}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {filtered.map(b => (
            <Card key={b.id} onClick={() => onPickBeverage?.(b)}>
              <div style={{ display: 'flex', gap: 12 }}>
                <Label width={52} height={68} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>{b.name}</div>
                  <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>{b.brewery} · {b.region}</div>
                  <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 2 }}>{b.subcategory} · {b.abv}%</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
                    <Stars value={b.rating} size={12}/>
                    <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 600 }}>{b.rating.toFixed(1)}</span>
                    <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)', marginLeft: 4 }}>· {b.checkins} check-ins</span>
                  </div>
                </div>
                <Icon name="chev" size={18} color="var(--fg-muted)"/>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { SearchScreen });
