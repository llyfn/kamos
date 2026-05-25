// KAMOS — Screens: Lists (Collections) & Profile (Me).
// - Collections: list of user-owned collections (SPEC §6). Default `Inventory`
//   and `Wishlist` are shown first; they look identical to user-created lists.
// - Profile: display_username preserves casing (SPEC §6.3); handle is the
//   stored-lowercase form rendered as `@{handle}`.

const ListsScreen = ({ collections, onOpenCollection, onNewList }) => {
  const { tt } = useLocale();
  return (
    <div style={{ flex: 1, overflowY: 'auto', padding: '8px 16px 16px' }}>
      <div style={{ padding: '8px 4px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600 }}>{tt(UI.collections)}</div>
        <button onClick={onNewList} style={{ border: '1px solid var(--border-2)', background: '#fff', borderRadius: 999, padding: '6px 12px', fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>
          ＋ {tt(UI.newList)}
        </button>
      </div>
      {collections.length === 0 ? (
        <EmptyState
          glyph="集"
          title={tt({ en: 'No collections yet', ja: 'まだコレクションがありません', ko: '아직 컬렉션이 없습니다' })}
          body={tt({ en: 'Tap "New list" to start a collection.', ja: '「新しいリスト」からコレクションを作成。', ko: '"새 리스트"를 탭하여 컬렉션을 만들어보세요.' })}
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {collections.map(c => (
            <Card key={c.id} onClick={() => onOpenCollection?.(c)}>
              <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                <div style={{ width: 56, height: 56, borderRadius: 10, background: c.tone === 'kon' ? 'var(--c-kon)' : c.tone === 'koh' ? 'var(--c-koh)' : 'var(--c-kinari)', color: c.tone ? '#fff' : 'var(--fg-1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 22, flex: 'none' }}>
                  {c.glyph || c.name[0]}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600 }}>{c.name}</div>
                  <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>
                    {c.count} {tt({ en: c.count === 1 ? 'bottle' : 'bottles', ja: '本', ko: '병' })} · {c.note || tt({ en: 'Private', ja: '非公開', ko: '비공개' })}
                  </div>
                </div>
                <Icon name="chev" size={18} color="var(--fg-muted)"/>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
};

const ProfileScreen = ({ user, recent, onEditProfile, onOpenSettings }) => {
  const { tt, locale, setLocale } = useLocale();
  return (
    <div style={{ flex: 1, overflowY: 'auto' }}>
      <div style={{ padding: '12px 20px 8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <SegmentedControl
          value={locale}
          onChange={setLocale}
          options={[{ id: 'en', label: 'EN' }, { id: 'ja', label: '日本語' }, { id: 'ko', label: '한국어' }]}
        />
        <button onClick={onOpenSettings} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-1)' }}>
          <Icon name="more"/>
        </button>
      </div>
      <div style={{ padding: '8px 20px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
        <Avatar initial={user.initial} size={84} tone="kinari"/>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 24, fontWeight: 600 }}>{user.displayName}</div>
        <div style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--fg-3)' }}>@{user.handle}</div>
        {user.privacy === 'private' && (
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '2px 8px', background: 'var(--bg-tint-mizu)', color: 'var(--c-kon)', borderRadius: 999, fontSize: 11, fontWeight: 600, fontFamily: 'var(--font-body)' }}>
            {tt({ en: 'Private', ja: '非公開', ko: '비공개' })}
          </div>
        )}
        <div style={{ fontSize: 14, color: 'var(--fg-2)', textAlign: 'center', maxWidth: 280, marginTop: 4 }}>{user.bio}</div>
      </div>
      <div style={{ padding: '0 20px', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 18 }}>
        {[
          { l: tt({ en: 'Check-ins', ja: 'チェックイン', ko: '체크인' }), v: user.stats.checkins },
          { l: tt({ en: 'Unique',    ja: 'ユニーク',     ko: '유니크' }), v: user.stats.unique },
          { l: tt({ en: 'Followers', ja: 'フォロワー',   ko: '팔로워' }), v: user.stats.followers },
          { l: tt({ en: 'Following', ja: 'フォロー中',   ko: '팔로잉' }), v: user.stats.following },
        ].map(s => (
          <div key={s.l} style={{ background: 'var(--bg-warm)', border: '1px solid var(--border-1)', borderRadius: 10, padding: '10px 6px', textAlign: 'center' }}>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 18, fontWeight: 600, color: 'var(--fg-1)' }}>{s.v}</div>
            <div style={{ fontSize: 10, color: 'var(--fg-3)', textTransform: 'uppercase', letterSpacing: '0.1em', fontWeight: 600 }}>{s.l}</div>
          </div>
        ))}
      </div>
      <div style={{ padding: '0 20px', display: 'flex', gap: 8, marginBottom: 18 }}>
        <Btn kind="primary" full onClick={onEditProfile}>{tt(UI.editProfile)}</Btn>
        <Btn kind="secondary" onClick={onOpenSettings}>{tt(UI.settings)}</Btn>
      </div>
      <div style={{ padding: '0 16px 16px' }}>
        <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', padding: '4px 4px 10px' }}>
          {tt(UI.recentChk)}
        </div>
        {recent.length === 0 ? (
          <EmptyState
            title={tt({ en: 'No check-ins yet', ja: 'まだチェックインがありません', ko: '아직 체크인이 없습니다' })}
            body={tt({ en: 'Tap + to log your first.', ja: '＋から最初の一杯を記録。', ko: '＋ 버튼으로 첫 기록을 남겨보세요.' })}
          />
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {recent.map(r => {
              const b = (window.CATALOG || []).find(x => x.id === r.beverageId) || {};
              return (
                <Card key={r.id}>
                  <div style={{ display: 'flex', gap: 12 }}>
                    <Label width={44} height={58} tone={b.labelTone} kanji={b.kanji}/>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                        <span style={{ fontFamily: 'var(--font-display)', fontSize: 14, fontWeight: 600 }}>{tt(b.name)}</span>
                        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)' }}>{r.when}</span>
                      </div>
                      <div style={{ fontSize: 12, color: 'var(--fg-2)' }}>{tt(b.producer)}</div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
                        <Stars value={r.rating} size={11}/>
                        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600 }}>{r.rating.toFixed(1)} / 5.0</span>
                      </div>
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

Object.assign(window, { ListsScreen, ProfileScreen });
