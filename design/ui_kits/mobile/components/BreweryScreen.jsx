// KAMOS — Screen: Brewery Detail (SPEC §2.3, §7 "browse by brewery").
// Fields: i18n name, prefecture/region, founded year, website, description.
// Lists all beverages from this brewery.

const BreweryScreen = ({ brewery, onBack, onOpenBeverage }) => {
  const { tt } = useLocale();
  if (!brewery) return null;

  const beverages = (window.CATALOG || []).filter(b => brewery.beverageIds.includes(b.id));

  return (
    <div style={{ flex: 1, overflowY: 'auto', background: 'var(--bg-page)' }}>
      <TopBar title="" onBack={onBack} right={
        <button style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-1)' }}>
          <Icon name="more"/>
        </button>
      }/>

      {/* Hero — full-bleed Kinari band; one of the sanctioned uses of the warm card surface */}
      <div style={{
        background: 'var(--bg-warm)', borderBottom: '1px solid var(--border-1)',
        padding: '8px 20px 24px', textAlign: 'center',
      }}>
        <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)' }}>
          {tt({ en: 'Brewery', ja: '蔵元', ko: '양조장' })}
        </div>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 30, fontWeight: 600, lineHeight: 1.15, marginTop: 6 }}>
          {tt(brewery.name)}
        </div>
        <div style={{ fontSize: 14, color: 'var(--fg-2)', marginTop: 4 }}>
          <Icon name="pin" size={13}/> {tt(brewery.region)}
        </div>
        {brewery.founded && (
          <div style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--fg-3)', marginTop: 4 }}>
            {tt({ en: 'Founded', ja: '創業', ko: '창업' })} {brewery.founded}
          </div>
        )}
      </div>

      <div style={{ padding: '20px' }}>
        {brewery.description && (
          <p style={{ fontSize: 14, lineHeight: 1.6, color: 'var(--fg-1)', margin: '0 0 14px' }}>
            {tt(brewery.description)}
          </p>
        )}
        {brewery.website && (
          <a href={brewery.website} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--fg-link)', textDecoration: 'none' }}>
            <Icon name="globe" size={14}/> {brewery.website.replace(/^https?:\/\//, '')}
          </a>
        )}

        <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, color: 'var(--fg-1)', margin: '24px 0 10px' }}>
          {tt({ en: 'Beverages', ja: '銘柄', ko: '제품' })}
        </div>

        {beverages.length === 0 ? (
          <EmptyState
            title={tt({ en: 'No beverages yet', ja: 'まだ銘柄がありません', ko: '아직 등록된 제품이 없습니다' })}
          />
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {beverages.map(b => (
              <Card key={b.id} onClick={() => onOpenBeverage?.(b)}>
                <div style={{ display: 'flex', gap: 12 }}>
                  <Label width={52} height={68} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>{tt(b.name)}</div>
                    <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>{tt(CATEGORY_LABELS[b.category])} · {tt(b.subcategory)}</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
                      <Stars value={b.rating} size={12}/>
                      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 600 }}>{b.rating.toFixed(1)} / 5.0</span>
                    </div>
                  </div>
                  <Icon name="chev" size={18} color="var(--fg-muted)"/>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

Object.assign(window, { BreweryScreen });
