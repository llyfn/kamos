// KAMOS — Phone shell, top bar, tab bar, bottom sheet host.

const Phone = ({ children, onBack, title, action }) => (
  <div className="kamos-phone" style={{
    width: 390, height: 844, position: 'relative',
    background: 'var(--bg-page)',
    borderRadius: 44, border: '8px solid #1B1F26',
    boxShadow: '0 24px 60px rgba(15,35,80,0.18), 0 4px 12px rgba(15,35,80,0.08)',
    overflow: 'hidden', display: 'flex', flexDirection: 'column', flex: 'none',
  }}>
    {/* status bar */}
    <div style={{
      height: 44, padding: '0 24px',
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      fontFamily: '-apple-system, system-ui', fontWeight: 600, fontSize: 14,
      color: 'var(--fg-1)', flex: 'none',
    }}>
      <span>9:41</span>
      <span style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <svg width="16" height="10" viewBox="0 0 16 10"><rect x="0" y="6" width="3" height="4" rx="0.5" fill="currentColor"/><rect x="4" y="4" width="3" height="6" rx="0.5" fill="currentColor"/><rect x="8" y="2" width="3" height="8" rx="0.5" fill="currentColor"/><rect x="12" y="0" width="3" height="10" rx="0.5" fill="currentColor"/></svg>
        <svg width="22" height="10" viewBox="0 0 22 10"><rect x="0.5" y="0.5" width="19" height="9" rx="2.5" stroke="currentColor" fill="none"/><rect x="2" y="2" width="14" height="6" rx="1.5" fill="currentColor"/></svg>
      </span>
    </div>
    {children}
    {/* home indicator */}
    <div style={{ height: 30, display: 'flex', alignItems: 'flex-end', justifyContent: 'center', paddingBottom: 8, flex: 'none' }}>
      <div style={{ width: 134, height: 5, borderRadius: 3, background: 'var(--c-sumi)' }}></div>
    </div>
  </div>
);

const TopBar = ({ title, onBack, right, transparent }) => (
  <div style={{
    height: 52, padding: '0 8px',
    display: 'flex', alignItems: 'center', gap: 4,
    background: transparent ? 'transparent' : 'var(--bg-page)',
    borderBottom: transparent ? 'none' : '1px solid var(--border-1)',
    flex: 'none',
  }}>
    {onBack ? (
      <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: 20, border: 'none', background: 'transparent', color: 'var(--fg-1)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon name="back" size={22} />
      </button>
    ) : <div style={{ width: 8 }} />}
    <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontSize: 18, fontWeight: 600, color: 'var(--fg-1)', textAlign: onBack ? 'center' : 'left', paddingLeft: onBack ? 0 : 8 }}>
      {title}
    </div>
    <div style={{ width: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{right}</div>
  </div>
);

const TabBar = ({ tab, setTab }) => {
  const tabs = [
    { id: 'feed',    label: 'Feed',    icon: 'home' },
    { id: 'search',  label: 'Search',  icon: 'search' },
    { id: 'checkin', label: 'Check in', icon: 'plus' },
    { id: 'lists',   label: 'Lists',   icon: 'bookmark' },
    { id: 'me',      label: 'Me',      icon: 'user' },
  ];
  return (
    <div style={{
      flex: 'none',
      borderTop: '1px solid var(--border-1)',
      background: 'rgba(252, 250, 246, 0.92)',
      backdropFilter: 'blur(16px)',
      WebkitBackdropFilter: 'blur(16px)',
      display: 'flex', height: 64, padding: '6px 4px 0',
    }}>
      {tabs.map(t => {
        const active = tab === t.id;
        const isCheckin = t.id === 'checkin';
        return (
          <button key={t.id} onClick={() => setTab(t.id)} style={{
            flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
            background: 'transparent', border: 'none', cursor: 'pointer', padding: 4,
            color: active ? 'var(--c-ai)' : 'var(--fg-3)',
          }}>
            {isCheckin ? (
              <div style={{ width: 38, height: 38, borderRadius: 19, background: 'var(--c-ai)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: 'var(--shadow-2)' }}>
                <Icon name="plus" size={22} color="#fff" />
              </div>
            ) : (
              <Icon name={t.icon} size={22} />
            )}
            {!isCheckin && <span style={{ fontSize: 10, fontWeight: 600, fontFamily: 'var(--font-body)' }}>{t.label}</span>}
            {isCheckin && <span style={{ fontSize: 10, fontWeight: 600, color: 'var(--fg-3)' }}>Check in</span>}
          </button>
        );
      })}
    </div>
  );
};

const Sheet = ({ open, onClose, children, title }) => {
  if (!open) return null;
  return (
    <div onClick={onClose} style={{
      position: 'absolute', inset: 0, zIndex: 50,
      background: 'rgba(15,35,80,0.5)',
      display: 'flex', alignItems: 'flex-end',
      animation: 'kfade 200ms var(--ease-out)',
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        width: '100%', background: 'var(--bg-surface)',
        borderRadius: '24px 24px 0 0',
        padding: '8px 0 24px',
        animation: 'kslide 240ms var(--ease-out)',
      }}>
        <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0' }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: 'var(--c-gray-300)' }}></div>
        </div>
        {title && (
          <div style={{ padding: '4px 20px 12px', fontFamily: 'var(--font-display)', fontSize: 18, fontWeight: 600 }}>{title}</div>
        )}
        <div style={{ padding: '0 20px' }}>{children}</div>
      </div>
      <style>{`
        @keyframes kfade { from { opacity: 0 } to { opacity: 1 } }
        @keyframes kslide { from { transform: translateY(40px); opacity: 0 } to { transform: translateY(0); opacity: 1 } }
      `}</style>
    </div>
  );
};

Object.assign(window, { Phone, TopBar, TabBar, Sheet });
