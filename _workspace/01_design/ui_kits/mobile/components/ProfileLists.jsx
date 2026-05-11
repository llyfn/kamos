// KAMOS — Screens: Lists & Profile (Me)

const ListsScreen = ({ collections }) => (
  <div style={{ flex: 1, overflowY: 'auto', padding: '8px 16px 16px' }}>
    <div style={{ padding: '8px 4px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: 26, fontWeight: 600 }}>Collections</div>
      <button style={{ border: '1px solid var(--border-2)', background: '#fff', borderRadius: 999, padding: '6px 12px', fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>＋ New list</button>
    </div>
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {collections.map(c => (
        <Card key={c.id}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            <div style={{ width: 56, height: 56, borderRadius: 10, background: c.tone === 'kon' ? 'var(--c-kon)' : c.tone === 'koh' ? 'var(--c-koh)' : 'var(--c-kinari)', color: c.tone ? '#fff' : 'var(--fg-1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 22, flex: 'none' }}>
              {c.glyph || c.name[0]}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600 }}>{c.name}</div>
              <div style={{ fontSize: 12, color: 'var(--fg-2)', marginTop: 2 }}>{c.count} bottle{c.count === 1 ? '' : 's'} · {c.note || 'Private'}</div>
            </div>
            <Icon name="chev" size={18} color="var(--fg-muted)"/>
          </div>
        </Card>
      ))}
    </div>
  </div>
);

const ProfileScreen = ({ user, recent }) => (
  <div style={{ flex: 1, overflowY: 'auto' }}>
    <div style={{ padding: '12px 20px 8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <button style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-1)', display: 'flex', alignItems: 'center', gap: 4, fontSize: 13 }}>
        <Icon name="globe" size={16}/> EN
      </button>
      <button style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--fg-1)' }}><Icon name="more"/></button>
    </div>
    <div style={{ padding: '8px 20px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
      <Avatar initial={user.initial} size={84} tone="kinari"/>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: 24, fontWeight: 600 }}>{user.name}</div>
      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--fg-3)' }}>@{user.handle}</div>
      <div style={{ fontSize: 14, color: 'var(--fg-2)', textAlign: 'center', maxWidth: 280, marginTop: 4 }}>{user.bio}</div>
    </div>
    <div style={{ padding: '0 20px', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 18 }}>
      {[
        { l: 'Check-ins', v: user.stats.checkins },
        { l: 'Unique', v: user.stats.unique },
        { l: 'Followers', v: user.stats.followers },
        { l: 'Following', v: user.stats.following },
      ].map(s => (
        <div key={s.l} style={{ background: 'var(--bg-warm)', border: '1px solid var(--border-1)', borderRadius: 10, padding: '10px 6px', textAlign: 'center' }}>
          <div style={{ fontFamily: 'var(--font-display)', fontSize: 18, fontWeight: 600, color: 'var(--fg-1)' }}>{s.v}</div>
          <div style={{ fontSize: 10, color: 'var(--fg-3)', textTransform: 'uppercase', letterSpacing: '0.1em', fontWeight: 600 }}>{s.l}</div>
        </div>
      ))}
    </div>
    <div style={{ padding: '0 20px', display: 'flex', gap: 8, marginBottom: 18 }}>
      <Btn kind="primary" full>Edit profile</Btn>
      <Btn kind="secondary">Settings</Btn>
    </div>
    <div style={{ padding: '0 16px 16px' }}>
      <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)', padding: '4px 4px 10px' }}>Recent check-ins</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {recent.map(r => (
          <Card key={r.id}>
            <div style={{ display: 'flex', gap: 12 }}>
              <Label width={44} height={58} tone={r.labelTone} kanji={r.kanji}/>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <span style={{ fontFamily: 'var(--font-display)', fontSize: 14, fontWeight: 600 }}>{r.beverage}</span>
                  <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)' }}>{r.when}</span>
                </div>
                <div style={{ fontSize: 12, color: 'var(--fg-2)' }}>{r.brewery}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
                  <Stars value={r.rating} size={11}/>
                  <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11, fontWeight: 600 }}>{r.rating.toFixed(1)}</span>
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  </div>
);

Object.assign(window, { ListsScreen, ProfileScreen });
