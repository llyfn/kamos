// KAMOS — UI primitives. Buttons, chips, avatar, rating stars, label image, etc.

// ----------------------------------------------------------------------------
// Locale context. Screens read `useLocale()` → { locale, setLocale, tt }.
// `tt(node)` is the locale-aware resolver (delegates to data.jsx::t).
// ----------------------------------------------------------------------------
const LocaleContext = React.createContext({ locale: 'en', setLocale: () => {} });
const useLocale = () => {
  const ctx = React.useContext(LocaleContext);
  return {
    ...ctx,
    tt: (node) => (typeof window.t === 'function' ? window.t(node, ctx.locale) : (node?.en || node || '')),
  };
};

const Avatar = ({ initial = 'A', size = 36, tone = 'kinari' }) => {
  const bg = tone === 'kon' ? 'var(--c-kon)' : tone === 'mizu' ? 'var(--c-mizu)' : 'var(--c-kinari)';
  const fg = tone === 'kon' ? '#fff' : 'var(--fg-1)';
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: bg, color: fg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: 'var(--font-display)', fontWeight: 600,
      fontSize: size * 0.42, flex: 'none',
      border: '1px solid var(--border-1)',
    }}>{initial}</div>
  );
};

// Beverage label thumbnail — stylised rectangle, no real image required.
const Label = ({ width = 56, height = 72, tone = 'navy', kanji, romaji }) => {
  const grad = tone === 'navy' ? 'linear-gradient(160deg, #2A4A6B, #0F2350)'
    : tone === 'koh' ? 'linear-gradient(160deg, #C97B5A, #8B4A2D)'
    : tone === 'matcha' ? 'linear-gradient(160deg, #8FAA7C, #4F6B40)'
    : 'linear-gradient(160deg, #4A86A8, #165E83)';
  return (
    <div style={{
      width, height, flex: 'none', borderRadius: 6,
      background: grad, color: '#fff',
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end',
      padding: 4, fontFamily: 'var(--font-display)', fontWeight: 600,
      fontSize: width * 0.16, lineHeight: 1.05, textAlign: 'center',
      boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.1)',
    }}>
      {kanji && <div style={{ fontSize: width * 0.22 }}>{kanji}</div>}
      {romaji && <div style={{ fontSize: width * 0.13, opacity: 0.85, marginTop: 2 }}>{romaji}</div>}
    </div>
  );
};

const Stars = ({ value = 4.5, size = 12 }) => {
  const full = Math.floor(value);
  const half = value - full >= 0.5;
  const total = 5;
  return (
    <span style={{ color: 'var(--c-yamabuki)', fontSize: size, letterSpacing: 1, lineHeight: 1 }}>
      {'★'.repeat(full)}{half ? '⯨' : ''}{'☆'.repeat(total - full - (half ? 1 : 0))}
    </span>
  );
};

const Btn = ({ kind = 'primary', children, onClick, full, icon }) => {
  const base = {
    fontFamily: 'var(--font-body)', fontSize: 14, fontWeight: 600,
    padding: '11px 18px', borderRadius: 999, cursor: 'pointer',
    border: '1px solid transparent', display: 'inline-flex', alignItems: 'center', gap: 6,
    width: full ? '100%' : 'auto', justifyContent: 'center',
    transition: 'all 120ms var(--ease-out)',
  };
  const styles = {
    primary: { background: 'var(--c-ai)', color: '#fff' },
    secondary: { background: '#fff', color: 'var(--fg-1)', borderColor: 'var(--border-2)' },
    ghost: { background: 'transparent', color: 'var(--fg-brand)' },
    toast: { background: 'var(--c-koh)', color: '#fff' },
    danger: { background: 'var(--c-akane)', color: '#fff' },
  };
  return <button onClick={onClick} style={{ ...base, ...styles[kind] }}>{icon}{children}</button>;
};

const Chip = ({ on, children, onClick, kind = 'default' }) => {
  const styles = {
    default: on
      ? { background: 'var(--c-ai)', color: '#fff', borderColor: 'var(--c-ai)' }
      : { background: '#fff', color: 'var(--fg-1)', borderColor: 'var(--border-2)' },
    tag: { background: 'var(--bg-tint-mizu)', color: 'var(--c-kon)', borderColor: 'transparent' },
    cat: { background: 'var(--c-kinari)', color: 'var(--fg-1)', borderColor: 'transparent' },
  };
  return (
    <button onClick={onClick} style={{
      fontFamily: 'var(--font-body)', fontSize: 13, padding: '6px 12px',
      borderRadius: 999, border: '1px solid', cursor: 'pointer',
      ...styles[kind],
    }}>{children}</button>
  );
};

const Card = ({ children, warm, onClick, style = {} }) => (
  <div onClick={onClick} style={{
    background: warm ? 'var(--bg-warm)' : 'var(--bg-card)',
    border: '1px solid var(--border-1)',
    borderRadius: 12, padding: 14,
    boxShadow: 'var(--shadow-1)',
    cursor: onClick ? 'pointer' : 'default',
    ...style,
  }}>{children}</div>
);

// Tiny inline icon set — minimal, hairline strokes; we only need a handful for the kit.
const Icon = ({ name, size = 22, color = 'currentColor' }) => {
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: 1.6, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'home':   return <svg {...props}><path d="M3 11.5 12 4l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/></svg>;
    case 'search': return <svg {...props}><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>;
    case 'plus':   return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/></svg>;
    case 'list':   return <svg {...props}><path d="M4 6h16M4 12h16M4 18h10"/></svg>;
    case 'user':   return <svg {...props}><circle cx="12" cy="9" r="3.5"/><path d="M5 20c1-3.5 4-5 7-5s6 1.5 7 5"/></svg>;
    case 'bell':   return <svg {...props}><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2H4.5z"/><path d="M10 21h4"/></svg>;
    case 'camera': return <svg {...props}><path d="M3 8h4l2-2h6l2 2h4v11H3z"/><circle cx="12" cy="13.5" r="3.5"/></svg>;
    case 'star':   return <svg {...props} fill="currentColor" stroke="none"><path d="M12 3.5l2.6 5.5 6 .9-4.4 4.2 1 6-5.2-2.8-5.2 2.8 1-6L3.4 9.9l6-.9z"/></svg>;
    case 'x':      return <svg {...props}><path d="m6 6 12 12M18 6 6 18"/></svg>;
    case 'chev':   return <svg {...props}><path d="m9 6 6 6-6 6"/></svg>;
    case 'back':   return <svg {...props}><path d="m15 6-6 6 6 6"/></svg>;
    case 'globe':  return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>;
    case 'filter': return <svg {...props}><path d="M4 6h16M7 12h10M10 18h4"/></svg>;
    case 'pin':    return <svg {...props}><path d="M12 22s7-7 7-12a7 7 0 1 0-14 0c0 5 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/></svg>;
    case 'bookmark': return <svg {...props}><path d="M6 4h12v17l-6-4-6 4z"/></svg>;
    case 'check':  return <svg {...props}><path d="m5 12 5 5L20 7"/></svg>;
    case 'more':   return <svg {...props}><circle cx="6" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="18" cy="12" r="1" fill="currentColor"/></svg>;
    default: return null;
  }
};

// ----------------------------------------------------------------------------
// StarsInput — 0.5-step rating input (SPEC §4.2). 0.5 to 5.0 across 10 levels.
// Tap left half of a star = .5; tap right half = full. Tap an already-selected
// rating to clear it (rating is optional).
// ----------------------------------------------------------------------------
const StarsInput = ({ value = 0, onChange, size = 32 }) => {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', gap: 4 }}>
      {[1, 2, 3, 4, 5].map(n => {
        const full = value >= n;
        const half = !full && value >= n - 0.5;
        return (
          <div key={n} style={{ position: 'relative', width: size, height: size, lineHeight: 1 }}>
            <span style={{
              position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: size, color: full ? 'var(--c-yamabuki)' : half ? 'var(--c-yamabuki)' : 'var(--c-gray-200)',
              transition: 'color 120ms var(--ease-out)',
              pointerEvents: 'none',
            }}>
              {full ? '★' : half ? '⯨' : '☆'}
            </span>
            <button
              aria-label={`${n - 0.5}`}
              onClick={() => onChange?.(value === n - 0.5 ? 0 : n - 0.5)}
              style={{ position: 'absolute', top: 0, left: 0, width: size / 2, height: size, background: 'transparent', border: 'none', cursor: 'pointer' }}
            />
            <button
              aria-label={`${n}`}
              onClick={() => onChange?.(value === n ? 0 : n)}
              style={{ position: 'absolute', top: 0, right: 0, width: size / 2, height: size, background: 'transparent', border: 'none', cursor: 'pointer' }}
            />
          </div>
        );
      })}
    </div>
  );
};

// ----------------------------------------------------------------------------
// EmptyState — calm, type-driven empty surface. No illustrations, no emoji.
// Optional inline kanji glyph is allowed (display type), but never required.
// ----------------------------------------------------------------------------
const EmptyState = ({ title, body, action, glyph }) => (
  <div style={{
    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
    padding: '48px 32px', textAlign: 'center', color: 'var(--fg-2)', gap: 8,
  }}>
    {glyph && (
      <div style={{ fontFamily: 'var(--font-display)', fontSize: 48, lineHeight: 1, color: 'var(--c-gray-300)', marginBottom: 8 }}>{glyph}</div>
    )}
    {title && <div style={{ fontFamily: 'var(--font-display)', fontSize: 18, fontWeight: 600, color: 'var(--fg-1)' }}>{title}</div>}
    {body && <div style={{ fontSize: 14, color: 'var(--fg-2)', lineHeight: 1.55, maxWidth: 280 }}>{body}</div>}
    {action && <div style={{ marginTop: 12 }}>{action}</div>}
  </div>
);

// ----------------------------------------------------------------------------
// LoadingState — hairline shimmer band; no spinners-of-doom.
// ----------------------------------------------------------------------------
const LoadingState = ({ label = 'Loading' }) => (
  <div style={{
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    padding: '32px 16px', gap: 10, color: 'var(--fg-3)',
  }}>
    <div style={{
      width: 18, height: 18, borderRadius: '50%',
      border: '2px solid var(--c-gray-200)', borderTopColor: 'var(--c-ai)',
      animation: 'kspin 700ms linear infinite',
    }}/>
    <span style={{ fontFamily: 'var(--font-body)', fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em' }}>{label}</span>
    <style>{`@keyframes kspin { from { transform: rotate(0deg) } to { transform: rotate(360deg) } }`}</style>
  </div>
);

// ----------------------------------------------------------------------------
// ErrorState — calm, retryable. No alarm colors. Akane is reserved for
// destructive confirmations only.
// ----------------------------------------------------------------------------
const ErrorState = ({ message = 'Could not load. Tap to retry.', onRetry }) => (
  <button onClick={onRetry} style={{
    background: 'transparent', border: '1px dashed var(--border-2)',
    borderRadius: 'var(--radius-md)', padding: '20px 16px', width: '100%',
    cursor: 'pointer', fontFamily: 'var(--font-body)', fontSize: 14, color: 'var(--fg-2)', textAlign: 'center',
  }}>
    {message}
  </button>
);

// ----------------------------------------------------------------------------
// PagingFooter — visualises the cursor-pagination "loading more…" affordance
// at the bottom of a list (SPEC §6.6, feed page size = 20).
// ----------------------------------------------------------------------------
const PagingFooter = ({ state = 'idle', hasMore = true, label = 'Loading more', endLabel = 'End of feed' }) => {
  if (state === 'loading') return <LoadingState label={label}/>;
  if (!hasMore) {
    return (
      <div style={{ padding: '20px 16px', textAlign: 'center', fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)' }}>
        — {endLabel} —
      </div>
    );
  }
  return null;
};

// ----------------------------------------------------------------------------
// Toggle — for settings (privacy mode, etc.). iOS-style hairline switch.
// ----------------------------------------------------------------------------
const Toggle = ({ on, onChange, ariaLabel }) => (
  <button
    role="switch"
    aria-checked={on}
    aria-label={ariaLabel}
    onClick={() => onChange?.(!on)}
    style={{
      width: 44, height: 26, borderRadius: 999, border: '1px solid',
      borderColor: on ? 'var(--c-ai)' : 'var(--border-2)',
      background: on ? 'var(--c-ai)' : 'var(--c-gray-100)',
      position: 'relative', cursor: 'pointer', padding: 0, flex: 'none',
      transition: 'background 200ms var(--ease-out), border-color 200ms var(--ease-out)',
    }}
  >
    <div style={{
      position: 'absolute', top: 2, left: on ? 20 : 2,
      width: 20, height: 20, borderRadius: '50%',
      background: '#fff', boxShadow: 'var(--shadow-1)',
      transition: 'left 200ms var(--ease-out)',
    }}/>
  </button>
);

// ----------------------------------------------------------------------------
// FormField — labeled wrapper. Body label, optional helper, optional counter.
// ----------------------------------------------------------------------------
const FormField = ({ label, helper, counter, error, children }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 14 }}>
    {label && (
      <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)' }}>{label}</div>
    )}
    {children}
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', minHeight: 14 }}>
      <div style={{ fontSize: 12, color: error ? 'var(--fg-danger)' : 'var(--fg-3)' }}>{error || helper || ''}</div>
      {counter != null && (
        <div style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)' }}>{counter}</div>
      )}
    </div>
  </div>
);

// ----------------------------------------------------------------------------
// TextField — single-line input with KAMOS styling.
// ----------------------------------------------------------------------------
const TextField = React.forwardRef(({ value, onChange, placeholder, type = 'text', autoComplete, disabled, maxLength }, ref) => (
  <input
    ref={ref}
    type={type}
    autoComplete={autoComplete}
    value={value ?? ''}
    onChange={(e) => onChange?.(e.target.value)}
    placeholder={placeholder}
    disabled={disabled}
    maxLength={maxLength}
    style={{
      width: '100%', padding: '11px 14px',
      fontFamily: 'var(--font-body)', fontSize: 15, color: 'var(--fg-1)',
      background: disabled ? 'var(--c-gray-100)' : 'var(--bg-surface)',
      border: '1px solid var(--border-2)', borderRadius: 'var(--radius-sm)',
      outline: 'none',
    }}
  />
));

// ----------------------------------------------------------------------------
// TextArea — multi-line input. Use with FormField for the counter.
// ----------------------------------------------------------------------------
const TextArea = ({ value, onChange, placeholder, maxLength, minHeight = 96 }) => (
  <textarea
    value={value ?? ''}
    onChange={(e) => onChange?.(e.target.value)}
    placeholder={placeholder}
    maxLength={maxLength}
    style={{
      width: '100%', minHeight, padding: 12,
      fontFamily: 'var(--font-body)', fontSize: 14, color: 'var(--fg-1)',
      background: 'var(--bg-surface)', border: '1px solid var(--border-2)',
      borderRadius: 'var(--radius-sm)', outline: 'none', resize: 'none',
    }}
  />
);

// ----------------------------------------------------------------------------
// SegmentedControl — small two/three-way selector for purchase type, currency,
// and per-serving vs per-bottle.
// ----------------------------------------------------------------------------
const SegmentedControl = ({ value, onChange, options }) => (
  <div style={{
    display: 'inline-flex', background: 'var(--c-gray-100)', borderRadius: 'var(--radius-pill)',
    padding: 2, gap: 0,
  }}>
    {options.map(opt => {
      const active = value === opt.id;
      return (
        <button key={opt.id} onClick={() => onChange?.(opt.id)} style={{
          padding: '6px 14px', borderRadius: 'var(--radius-pill)', border: 'none',
          background: active ? 'var(--bg-surface)' : 'transparent',
          color: active ? 'var(--fg-1)' : 'var(--fg-2)',
          fontFamily: 'var(--font-body)', fontSize: 13, fontWeight: 600, cursor: 'pointer',
          boxShadow: active ? 'var(--shadow-1)' : 'none',
          transition: 'all 120ms var(--ease-out)',
        }}>{opt.label}</button>
      );
    })}
  </div>
);

// ----------------------------------------------------------------------------
// Row — list-row used by Settings and account-actions menus.
// ----------------------------------------------------------------------------
const Row = ({ label, value, danger, onClick, trailing, helper }) => (
  <button onClick={onClick} disabled={!onClick} style={{
    display: 'flex', alignItems: 'center', gap: 12, width: '100%',
    padding: '14px 16px', background: 'var(--bg-surface)',
    border: 'none', borderBottom: '1px solid var(--border-1)',
    cursor: onClick ? 'pointer' : 'default', textAlign: 'left',
  }}>
    <div style={{ flex: 1 }}>
      <div style={{
        fontFamily: 'var(--font-body)', fontSize: 15,
        color: danger ? 'var(--fg-danger)' : 'var(--fg-1)',
        fontWeight: danger ? 600 : 400,
      }}>{label}</div>
      {helper && (
        <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 2 }}>{helper}</div>
      )}
    </div>
    {value && (
      <div style={{ fontFamily: 'var(--font-body)', fontSize: 14, color: 'var(--fg-2)' }}>{value}</div>
    )}
    {trailing || (onClick && <Icon name="chev" size={16} color="var(--fg-muted)"/>)}
  </button>
);

// ----------------------------------------------------------------------------
// PhotoTile — used in CheckInScreen photo grid. Add / loaded / remove states.
// ----------------------------------------------------------------------------
const PhotoTile = ({ filled, onAdd, onRemove }) => (
  <div style={{
    aspectRatio: '1/1', borderRadius: 'var(--radius-sm)',
    border: filled ? '1px solid var(--border-1)' : '1px dashed var(--border-2)',
    background: filled ? 'var(--c-kinari)' : 'var(--bg-sunken)',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    color: 'var(--fg-muted)', position: 'relative', cursor: filled ? 'default' : 'pointer',
  }} onClick={!filled ? onAdd : undefined}>
    {filled ? (
      <>
        <Icon name="camera" size={24} color="var(--fg-2)"/>
        <button onClick={(e) => { e.stopPropagation(); onRemove?.(); }} style={{
          position: 'absolute', top: 4, right: 4, width: 22, height: 22, borderRadius: '50%',
          background: 'rgba(15,35,80,0.8)', color: '#fff', border: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}>
          <Icon name="x" size={12} color="#fff"/>
        </button>
      </>
    ) : (
      <Icon name="camera" size={20}/>
    )}
  </div>
);

// ----------------------------------------------------------------------------
// Badge — small dot/count used on the inbox icon (SPEC §5.4).
// ----------------------------------------------------------------------------
const Badge = ({ count }) => {
  if (!count) return null;
  return (
    <span style={{
      position: 'absolute', top: -4, right: -4,
      minWidth: 18, height: 18, borderRadius: 9, padding: '0 5px',
      background: 'var(--c-koh)', color: '#fff',
      fontFamily: 'var(--font-mono)', fontSize: 10, fontWeight: 700,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      border: '2px solid var(--bg-page)',
    }}>{count > 99 ? '99+' : count}</span>
  );
};

Object.assign(window, {
  LocaleContext, useLocale,
  Avatar, Label, Stars, Btn, Chip, Card, Icon,
  StarsInput, EmptyState, LoadingState, ErrorState, PagingFooter,
  Toggle, FormField, TextField, TextArea, SegmentedControl, Row, PhotoTile, Badge,
});
