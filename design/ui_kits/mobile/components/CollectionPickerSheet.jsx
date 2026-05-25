// KAMOS — Sheet: Collection Picker (SPEC §6.3).
// Multi-select. A beverage can be in multiple collections at once.
// Inline "Create new collection" affordance creates a new collection and
// selects it. Save commits the diff (add to checked, remove from unchecked).

const CollectionPickerSheet = ({ open, beverage, collections, onClose, onSave }) => {
  const { tt } = useLocale();
  const [picked, setPicked] = React.useState(new Set(
    (collections || []).filter(c => beverage && c.beverageIds?.includes(beverage.id)).map(c => c.id)
  ));
  const [creating, setCreating] = React.useState(false);
  const [newName, setNewName] = React.useState('');
  const [localCollections, setLocalCollections] = React.useState(collections || []);

  const toggle = (id) => setPicked(prev => {
    const n = new Set(prev);
    n.has(id) ? n.delete(id) : n.add(id);
    return n;
  });

  const createNew = () => {
    if (!newName.trim()) return;
    const id = `new-${Date.now()}`;
    setLocalCollections(prev => [...prev, { id, name: newName.trim(), count: 0, note: 'Custom', beverageIds: [] }]);
    setPicked(prev => new Set(prev).add(id));
    setNewName('');
    setCreating(false);
  };

  return (
    <Sheet open={open} onClose={onClose} title={tt({ en: 'Add to collections', ja: 'コレクションに追加', ko: '컬렉션에 추가' })}>
      {beverage && (
        <div style={{ display: 'flex', gap: 10, alignItems: 'center', padding: '4px 0 12px', borderBottom: '1px solid var(--border-1)' }}>
          <Label width={40} height={54} tone={beverage.labelTone} kanji={beverage.kanji}/>
          <div>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 14, fontWeight: 600 }}>{tt(beverage.name)}</div>
            <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>{tt(beverage.producer)}</div>
          </div>
        </div>
      )}

      <div style={{ maxHeight: 320, overflowY: 'auto', padding: '6px 0' }}>
        {localCollections.map(c => {
          const on = picked.has(c.id);
          return (
            <button key={c.id} onClick={() => toggle(c.id)} style={{
              display: 'flex', alignItems: 'center', gap: 12, width: '100%',
              padding: '10px 4px', background: 'transparent', border: 'none',
              borderBottom: '1px solid var(--border-1)', cursor: 'pointer', textAlign: 'left',
            }}>
              <div style={{ width: 40, height: 40, borderRadius: 8, background: c.tone === 'kon' ? 'var(--c-kon)' : c.tone === 'koh' ? 'var(--c-koh)' : 'var(--c-kinari)', color: c.tone ? '#fff' : 'var(--fg-1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 16, flex: 'none' }}>
                {c.glyph || c.name[0]}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: 'var(--font-body)', fontSize: 14, fontWeight: 600, color: 'var(--fg-1)' }}>{c.name}</div>
                <div style={{ fontSize: 12, color: 'var(--fg-3)' }}>
                  {c.count} {tt({ en: c.count === 1 ? 'bottle' : 'bottles', ja: '本', ko: '병' })}
                </div>
              </div>
              <div style={{
                width: 22, height: 22, borderRadius: '50%',
                border: on ? 'none' : '1.5px solid var(--border-2)',
                background: on ? 'var(--c-ai)' : 'transparent',
                color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
                flex: 'none',
              }}>
                {on && <Icon name="check" size={14} color="#fff"/>}
              </div>
            </button>
          );
        })}

        {creating ? (
          <div style={{ display: 'flex', gap: 8, padding: '12px 4px', alignItems: 'center' }}>
            <TextField value={newName} onChange={setNewName} maxLength={50}
              placeholder={tt({ en: 'Collection name', ja: 'コレクション名', ko: '컬렉션 이름' })}/>
            <Btn kind="primary" onClick={createNew}>{tt(UI.save)}</Btn>
          </div>
        ) : (
          <button onClick={() => setCreating(true)} style={{
            width: '100%', display: 'flex', alignItems: 'center', gap: 8, padding: '14px 4px',
            background: 'transparent', border: 'none', cursor: 'pointer',
            color: 'var(--fg-link)', fontFamily: 'var(--font-body)', fontSize: 14, fontWeight: 600,
          }}>
            <Icon name="plus" size={18}/> {tt({ en: 'Create new collection', ja: '新しいコレクション', ko: '새 컬렉션 만들기' })}
          </button>
        )}
      </div>

      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        <Btn kind="secondary" full onClick={onClose}>{tt(UI.cancel)}</Btn>
        <Btn kind="primary"   full onClick={() => onSave?.([...picked])}>{tt(UI.save)}</Btn>
      </div>
    </Sheet>
  );
};

Object.assign(window, { CollectionPickerSheet });
