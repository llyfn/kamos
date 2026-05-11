// KAMOS — UI primitives. Buttons, chips, avatar, rating stars, label image, etc.

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

Object.assign(window, { Avatar, Label, Stars, Btn, Chip, Card, Icon });
