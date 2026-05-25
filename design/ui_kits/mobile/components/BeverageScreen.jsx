// KAMOS — Screen: Beverage Detail (SPEC §7).
// Renders catalog info, avg rating, aggregated flavor, recent check-ins.

const BeverageScreen = ({ b, onBack, onCheckIn, onAddToList, onOpenProducer }) => {
  const { tt } = useLocale();
  return (
    <div style={{ flex: 1, overflowY: 'auto', background: 'var(--bg-page)' }}>
      <TopBar title="" onBack={onBack} right={
        <button style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-1)' }}>
          <Icon name="more"/>
        </button>
      }/>
      <div style={{ padding: '0 20px 20px' }}>
        <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 20px' }}>
          <Label width={140} height={184} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
        </div>

        {/* Category overline — exact per SPEC §2.1 */}
        <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', textAlign: 'center' }}>
          {tt(CATEGORY_LABELS[b.category])} · {tt(b.subcategory)}
        </div>

        <div style={{ fontFamily: 'var(--font-display)', fontSize: 28, fontWeight: 600, lineHeight: 1.15, textAlign: 'center', marginTop: 6, color: 'var(--fg-1)' }}>
          {tt(b.name)}
        </div>

        <button onClick={() => onOpenProducer?.(b.producerId)} style={{
          display: 'block', margin: '4px auto 0', background: 'transparent', border: 'none',
          color: 'var(--fg-link)', cursor: 'pointer',
          fontFamily: 'var(--font-body)', fontSize: 14,
        }}>
          {tt(b.producer)} · {tt(b.region)}
        </button>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 14 }}>
          <Stars value={b.rating} size={16}/>
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 16, fontWeight: 600 }}>{b.rating.toFixed(1)} / 5.0</span>
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--fg-3)' }}>· {b.checkins}</span>
        </div>

        <div style={{ display: 'flex', gap: 8, marginTop: 18 }}>
          <Btn kind="primary" full onClick={onCheckIn}>{tt(UI.checkinBtn)}</Btn>
          <Btn kind="secondary" onClick={onAddToList} icon={<Icon name="bookmark" size={16}/>}>
            {tt({ en: 'List', ja: 'リスト', ko: '리스트' })}
          </Btn>
        </div>

        <div style={{ marginTop: 22, padding: '14px 16px', background: 'var(--bg-warm)', borderRadius: 12, border: '1px solid var(--border-1)' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Stat label={tt({ en: 'ABV', ja: '度数', ko: '도수' })} value={`${b.abv.toFixed(1)}%`}/>
            {b.seimai && <Stat label={tt({ en: 'Seimai', ja: '精米歩合', ko: '정미율' })} value={`${b.seimai}%`}/>}
            <Stat label={tt({ en: 'Region', ja: '地域', ko: '지역' })} value={tt(b.region)}/>
            <Stat label={tt({ en: 'Type', ja: '種類', ko: '종류' })} value={tt(b.subcategory)}/>
          </div>
        </div>

        <SectionHeader>{tt(UI.flavorAgg)}</SectionHeader>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {b.flavor.map(t => (
            <span key={t} style={{ fontSize: 12, padding: '5px 10px', borderRadius: 999, background: 'var(--bg-tint-mizu)', color: 'var(--c-kon)' }}>{t}</span>
          ))}
        </div>

        <SectionHeader>{tt(UI.aboutProducer)}</SectionHeader>
        <div style={{ fontSize: 14, color: 'var(--fg-1)', lineHeight: 1.6 }}>{tt(b.about)}</div>

        <SectionHeader>{tt(UI.recentChk)}</SectionHeader>
        {b.recent.length === 0 ? (
          <EmptyState
            title={tt({ en: 'No check-ins yet', ja: 'まだチェックインがありません', ko: '아직 체크인이 없습니다' })}
            body={tt({ en: 'Be the first to log this bottle.', ja: '最初の一本を記録しましょう。', ko: '첫 기록을 남겨보세요.' })}
          />
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {b.recent.map((r, i) => (
              <div key={i} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: 12, background: '#fff', border: '1px solid var(--border-1)', borderRadius: 10 }}>
                <Avatar initial={r.user[0].toUpperCase()} size={32}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontWeight: 600, fontSize: 13 }}>{r.user}</span>
                    <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)' }}>{r.rating.toFixed(1)} / 5.0</span>
                  </div>
                  <div style={{ fontSize: 13, color: 'var(--fg-1)', marginTop: 4, lineHeight: 1.5 }}>{r.review}</div>
                </div>
              </div>
            ))}
          </div>
        )}
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
