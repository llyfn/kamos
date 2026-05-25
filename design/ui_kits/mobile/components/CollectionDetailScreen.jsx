// KAMOS — Screen: Collection Detail (SPEC §6).
// Shows the beverages in one collection. Rename, delete (with confirmation),
// remove-beverage. Optional per-entry note (≤200 chars).

const CollectionDetailScreen = ({ collection, onBack, onOpenBeverage, onRename, onDelete }) => {
  const { tt } = useLocale();
  if (!collection) return null;

  const beverages = (window.CATALOG || []).filter(b => collection.beverageIds.includes(b.id));
  const [menu, setMenu] = React.useState(false);
  const [confirmDelete, setConfirmDelete] = React.useState(false);

  return (
    <div style={{ flex: 1, overflowY: 'auto', background: 'var(--bg-page)' }}>
      <TopBar
        title={collection.name}
        onBack={onBack}
        right={
          <button onClick={() => setMenu(true)} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-1)' }}>
            <Icon name="more"/>
          </button>
        }
      />

      <div style={{ padding: '8px 20px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{
          width: 64, height: 64, borderRadius: 12,
          background: collection.tone === 'kon' ? 'var(--c-kon)' : collection.tone === 'koh' ? 'var(--c-koh)' : 'var(--c-kinari)',
          color: collection.tone ? '#fff' : 'var(--fg-1)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 28, flex: 'none',
        }}>
          {collection.glyph || collection.name[0]}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 12, color: 'var(--fg-3)', textTransform: 'uppercase', letterSpacing: '0.12em', fontWeight: 600 }}>
            {collection.isDefault
              ? tt({ en: 'Default collection', ja: 'デフォルト', ko: '기본 컬렉션' })
              : tt({ en: 'Custom collection', ja: 'カスタム', ko: '사용자 컬렉션' })}
          </div>
          <div style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--fg-3)', marginTop: 2 }}>
            {beverages.length} {tt({ en: beverages.length === 1 ? 'bottle' : 'bottles', ja: '本', ko: '병' })} · {tt({ en: 'Private', ja: '非公開', ko: '비공개' })}
          </div>
        </div>
      </div>

      <div style={{ padding: '0 20px 20px' }}>
        {beverages.length === 0 ? (
          <EmptyState
            glyph="∅"
            title={tt({ en: 'Empty collection', ja: '空のコレクション', ko: '빈 컬렉션' })}
            body={tt({
              en: 'Add beverages from a beverage page or check-in screen.',
              ja: '銘柄詳細やチェックイン画面から追加できます。',
              ko: '제품 페이지나 체크인 화면에서 추가하세요.',
            })}
          />
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {beverages.map(b => (
              <Card key={b.id} onClick={() => onOpenBeverage?.(b)}>
                <div style={{ display: 'flex', gap: 12 }}>
                  <Label width={48} height={64} tone={b.labelTone} kanji={b.kanji} romaji={b.labelRomaji}/>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: 'var(--font-display)', fontSize: 15, fontWeight: 600 }}>{tt(b.name)}</div>
                    <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>{tt(b.producer)}</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
                      <Stars value={b.rating} size={11}/>
                      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600 }}>{b.rating.toFixed(1)} / 5.0</span>
                    </div>
                  </div>
                  <Icon name="chev" size={18} color="var(--fg-muted)"/>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>

      {menu && (
        <Sheet open onClose={() => setMenu(false)} title={collection.name}>
          <Row label={tt({ en: 'Rename', ja: '名前を変更', ko: '이름 변경' })} onClick={() => { setMenu(false); onRename?.(collection); }}/>
          <Row label={tt({ en: 'Delete collection', ja: 'コレクションを削除', ko: '컬렉션 삭제' })} danger onClick={() => { setMenu(false); setConfirmDelete(true); }}/>
        </Sheet>
      )}

      {confirmDelete && (
        <Sheet open onClose={() => setConfirmDelete(false)} title={tt({ en: 'Delete this collection?', ja: 'このコレクションを削除？', ko: '이 컬렉션을 삭제할까요?' })}>
          <p style={{ fontSize: 14, color: 'var(--fg-2)', lineHeight: 1.55, margin: '4px 0 18px' }}>
            {tt({
              en: 'This removes the collection and all of its entries. The beverages themselves are unaffected.',
              ja: 'コレクションとそのすべてのエントリが削除されます。銘柄自体には影響しません。',
              ko: '컬렉션과 모든 항목이 삭제됩니다. 제품 자체는 영향받지 않습니다.',
            })}
          </p>
          <div style={{ display: 'flex', gap: 8 }}>
            <Btn kind="secondary" full onClick={() => setConfirmDelete(false)}>{tt(UI.cancel)}</Btn>
            <Btn kind="danger"    full onClick={() => { setConfirmDelete(false); onDelete?.(collection); }}>
              {tt({ en: 'Delete', ja: '削除', ko: '삭제' })}
            </Btn>
          </div>
        </Sheet>
      )}
    </div>
  );
};

Object.assign(window, { CollectionDetailScreen });
