// KAMOS — Screen: Check-in flow

const CheckInScreen = ({ b, onClose, onSubmit }) => {
  const [rating, setRating] = React.useState(0);
  const [review, setReview] = React.useState('');
  const [tags, setTags] = React.useState(new Set());
  const allTags = ['Dry', 'Off-dry', 'Sweet', 'Crisp', 'Bright', 'Floral', 'Fruity', 'Umami', 'Earthy', 'Smoky', 'Lingering', 'Warming'];
  const toggleTag = (t) => setTags(prev => {
    const n = new Set(prev);
    n.has(t) ? n.delete(t) : n.add(t);
    return n;
  });
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-page)' }}>
      <div style={{ height: 52, padding: '0 8px', display: 'flex', alignItems: 'center', borderBottom: '1px solid var(--border-1)', flex: 'none' }}>
        <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: 'var(--fg-1)' }}><Icon name="x"/></button>
        <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600, textAlign: 'center' }}>Check in</div>
        <button onClick={() => onSubmit({ rating, review, tags: [...tags] })} disabled={rating === 0} style={{
          background: rating === 0 ? 'var(--c-gray-200)' : 'var(--c-ai)', color: rating === 0 ? 'var(--c-gray-400)' : '#fff',
          border: 'none', borderRadius: 999, padding: '8px 16px', fontWeight: 600, fontSize: 13, cursor: rating === 0 ? 'not-allowed' : 'pointer', marginRight: 6,
        }}>Post</button>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px 24px' }}>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', padding: 12, background: '#fff', border: '1px solid var(--border-1)', borderRadius: 12 }}>
          <Label width={48} height={64} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
          <div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 16, fontWeight: 600 }}>{b.name}</div>
            <div style={{ fontSize: 12, color: 'var(--fg-2)' }}>{b.brewery} · {b.region}</div>
          </div>
        </div>

        <SectionLabel>Rating</SectionLabel>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 4, padding: '12px 0' }}>
          {[1, 2, 3, 4, 5].map(n => (
            <button key={n} onClick={() => setRating(n === rating ? n - 0.5 : n)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 4 }}>
              <span style={{ fontSize: 32, color: rating >= n ? 'var(--c-yamabuki)' : rating >= n - 0.5 ? 'var(--c-yamabuki)' : 'var(--c-gray-200)', lineHeight: 1 }}>
                {rating >= n ? '★' : rating >= n - 0.5 ? '⯨' : '☆'}
              </span>
            </button>
          ))}
        </div>
        <div style={{ textAlign: 'center', fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--fg-2)' }}>
          {rating > 0 ? `${rating.toFixed(1)} / 5.0` : 'Tap a star to rate · half-steps allowed'}
        </div>

        <SectionLabel>Review · optional</SectionLabel>
        <textarea value={review} onChange={e => setReview(e.target.value)} maxLength={500} placeholder="Pear, soft rice, a clean finish…" style={{
          width: '100%', minHeight: 96, padding: 12, fontFamily: 'var(--font-body)', fontSize: 14,
          border: '1px solid var(--border-2)', borderRadius: 10, resize: 'none', outline: 'none', background: '#fff', color: 'var(--fg-1)',
        }}/>
        <div style={{ textAlign: 'right', fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)' }}>{review.length} / 500</div>

        <SectionLabel>Flavor tags</SectionLabel>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {allTags.map(t => <Chip key={t} on={tags.has(t)} onClick={() => toggleTag(t)}>{t}</Chip>)}
        </div>

        <SectionLabel>Photos · up to 4</SectionLabel>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
          {[0, 1, 2, 3].map(i => (
            <div key={i} style={{ aspectRatio: '1/1', borderRadius: 8, border: '1px dashed var(--border-2)', background: 'var(--bg-sunken)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fg-muted)' }}>
              <Icon name="camera" size={20}/>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const SectionLabel = ({ children }) => (
  <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', margin: '20px 0 8px' }}>{children}</div>
);

Object.assign(window, { CheckInScreen });
