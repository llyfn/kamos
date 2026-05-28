// KAMOS — Screen: Feed (the home tab — followed users' check-ins).
// Cursor-paginated (SPEC §6.6); page size = 20. Reverse chronological.
// User's own check-ins do NOT appear here (SPEC §5.2).

const FeedItem = ({ item, onToast, onOpenBeverage }) => {
  const { tt } = useLocale();
  const b = (window.CATALOG || []).find(x => x.id === item.beverageId) || {};
  const [toasted, setToasted] = React.useState(item.youToasted || false);
  const [count, setCount] = React.useState(item.toasts);

  const handleToast = () => {
    const next = !toasted;
    setToasted(next);
    setCount(c => c + (next ? 1 : -1));
    onToast?.(item.id, next);
  };

  return (
    <Card style={{ marginBottom: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <Avatar initial={item.user[0].toUpperCase()} tone={item.tone || 'kinari'} />
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--fg-1)' }}>{item.user}</div>
          <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>{item.when}</div>
        </div>
        <button style={{ border: 'none', background: 'transparent', color: 'var(--fg-3)', padding: 4, cursor: 'pointer' }}>
          <Icon name="more" size={18}/>
        </button>
      </div>

      <div style={{ display: 'flex', gap: 12, marginTop: 12, cursor: 'pointer' }} onClick={() => onOpenBeverage?.(b)}>
        <Label width={52} height={68} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600, color: 'var(--fg-1)', lineHeight: 1.2 }}>
            {tt(b.name)}
          </div>
          <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>
            {tt(b.producer)} · {tt(b.region)}
          </div>
          {item.rating != null && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
              <Stars value={item.rating} size={13}/>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: 12, fontWeight: 600 }}>
                {item.rating.toFixed(1)} / 5.0
              </span>
            </div>
          )}
        </div>
      </div>

      {item.review && (
        <div style={{ marginTop: 10, fontSize: 14, lineHeight: 1.55, color: 'var(--fg-1)' }}>
          {item.review.length > 140 ? (
            <>
              {item.review.slice(0, 140)}
              <span style={{ color: 'var(--fg-link)', cursor: 'pointer', fontWeight: 600 }}> more</span>
            </>
          ) : item.review}
        </div>
      )}

      {item.tags && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
          {item.tags.map(t => (
            <span key={t} style={{ fontSize: 11, padding: '3px 8px', borderRadius: 999, background: 'var(--bg-tint-mizu)', color: 'var(--c-kon)' }}>{t}</span>
          ))}
        </div>
      )}

      {item.photoCount > 0 && (
        <div style={{ marginTop: 10, height: 160, borderRadius: 'var(--radius-md)', background: 'linear-gradient(160deg, var(--c-kinari), var(--c-gray-100))', border: '1px solid var(--border-1)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fg-muted)' }}>
          <Icon name="camera" size={28}/>
        </div>
      )}

      <div style={{ display: 'flex', gap: 14, marginTop: 12, paddingTop: 10, borderTop: '1px solid var(--border-1)', alignItems: 'center' }}>
        <button onClick={handleToast} style={{
          display: 'flex', alignItems: 'center', gap: 6,
          background: toasted ? 'var(--c-koh)' : 'transparent',
          color: toasted ? '#fff' : 'var(--fg-2)',
          border: '1px solid', borderColor: toasted ? 'var(--c-koh)' : 'var(--border-2)',
          padding: '5px 12px', borderRadius: 999, cursor: 'pointer',
          fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 600,
          transition: 'all 200ms var(--ease-out)',
        }}>
          <img src="../../assets/logo_white.png" alt="" style={{
            width: 18, height: 'auto',
            filter: toasted ? 'none' : 'brightness(0) saturate(100%) invert(53%) sepia(33%) saturate(645%) hue-rotate(335deg) brightness(91%) contrast(85%)',
            display: 'inline-block',
            transform: toasted ? 'scale(1.1)' : 'scale(1)',
            transition: 'transform 240ms var(--ease-out)',
          }}/>
          <span>{count}</span>
        </button>
      </div>
    </Card>
  );
};

const FeedScreen = ({ data, onOpenBeverage, onCheckIn }) => {
  const { tt } = useLocale();
  // Toggle for demonstrating the empty state. Default to false.
  const [showEmpty] = React.useState(false);

  return (
    <div style={{ flex: 1, overflowY: 'auto', padding: '4px 16px 16px' }}>
      <div style={{ padding: '8px 4px 14px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600, color: 'var(--fg-1)', letterSpacing: '-0.01em' }}>
            {tt(UI.following)}
          </div>
          <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 2 }}>{tt(UI.fromFollow)}</div>
        </div>
        {/* Bell-with-badge removed per notifications_ux.md §1.4 — follow requests
            now live as rows in the Notifications tab. Check-in is still
            reachable from the beverage detail screen. */}
      </div>

      {showEmpty || !data || data.length === 0 ? (
        <EmptyState
          glyph="醸"
          title={tt({ en: 'No check-ins yet', ja: 'まだチェックインがありません', ko: '아직 체크인이 없습니다' })}
          body={tt(UI.emptyFeed)}
        />
      ) : (
        <>
          {data.map(item => (
            <FeedItem key={item.id} item={item} onOpenBeverage={onOpenBeverage}/>
          ))}
          <PagingFooter
            state="loading"
            hasMore
            label={tt(UI.loadingMore)}
          />
        </>
      )}
    </div>
  );
};

Object.assign(window, { FeedScreen });
