// KAMOS — Screen: Beverage Detail

const BeverageScreen = ({ b, onBack, onCheckIn, onAddToList }) => {
  return (
    <div style={{ flex: 1, overflowY: 'auto', background: 'var(--bg-page)' }}>
      <TopBar title="" onBack={onBack} right={<button style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-1)' }}><Icon name="more"/></button>}/>
      <div style={{ padding: '0 20px 20px' }}>
        <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 20px' }}>
          <Label width={140} height={184} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
        </div>
        <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', textAlign: 'center' }}>{b.subcategory}</div>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 28, fontWeight: 600, lineHeight: 1.15, textAlign: 'center', marginTop: 6, color: 'var(--fg-1)' }}>{b.name}</div>
        <div style={{ fontSize: 14, color: 'var(--fg-2)', textAlign: 'center', marginTop: 4 }}>{b.brewery} · {b.region}</div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 14 }}>
          <Stars value={b.rating} size={16}/>
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 16, fontWeight: 600 }}>{b.rating.toFixed(1)} / 5.0</span>
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--fg-3)' }}>· {b.checkins} check-ins</span>
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 18 }}>
          <Btn kind="primary" full onClick={onCheckIn}>Check in</Btn>
          <Btn kind="secondary" onClick={onAddToList}>＋ List</Btn>
        </div>

        <div style={{ marginTop: 22, padding: '14px 16px', background: 'var(--bg-warm)', borderRadius: 12, border: '1px solid var(--border-1)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Stat label="ABV" value={`${b.abv}%`}/>
            {b.seimai && <Stat label="Seimai" value={`${b.seimai}%`}/>}
            <Stat label="Region" value={b.region}/>
            <Stat label="Type" value={b.subcategory}/>
          </div>
        </div>

        <SectionHeader>Aggregated flavor</SectionHeader>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {b.flavor.map(t => <span key={t} style={{ fontSize: 12, padding: '5px 10px', borderRadius: 999, background: 'var(--bg-tint-mizu)', color: 'var(--c-kon)' }}>{t}</span>)}
        </div>

        <SectionHeader>About the brewery</SectionHeader>
        <div style={{ fontSize: 14, color: 'var(--fg-1)', lineHeight: 1.6 }}>{b.about}</div>

        <SectionHeader>Recent check-ins</SectionHeader>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {b.recent.map((r, i) => (
            <div key={i} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: 12, background: '#fff', border: '1px solid var(--border-1)', borderRadius: 10 }}>
              <Avatar initial={r.user[0].toUpperCase()} size={32}/>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontWeight: 600, fontSize: 13 }}>{r.user}</span>
                  <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)' }}>★ {r.rating.toFixed(1)}</span>
                </div>
                <div style={{ fontSize: 13, color: 'var(--fg-1)', marginTop: 4, lineHeight: 1.5 }}>{r.review}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const Stat = ({ label, value }) => (
  <div>
    <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.1em', color: 'var(--fg-3)' }}>{label}</div>
    <div style={{ fontFamily: 'var(--font-mono)', fontSize: 15, fontWeight: 600, color: 'var(--fg-1)', marginTop: 4 }}>{value}</div>
  </div>
);

const SectionHeader = ({ children }) => (
  <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, color: 'var(--fg-1)', margin: '24px 0 10px' }}>{children}</div>
);

Object.assign(window, { BeverageScreen });
