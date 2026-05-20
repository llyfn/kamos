// KAMOS — Screen: Edit Profile (SPEC §3.2, §3.3).
// Editable: display_name (≤50), bio (≤200), avatar.
// Username is NOT editable from this screen — it's set at registration
// and held for 30 days after deletion. Email/password live in Settings.

const EditProfileScreen = ({ user, onClose, onSave }) => {
  const { tt } = useLocale();
  const [displayName, setDisplayName] = React.useState(user.displayName);
  const [bio, setBio] = React.useState(user.bio || '');

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-page)' }}>
      <div style={{ height: 52, padding: '0 8px', display: 'flex', alignItems: 'center', borderBottom: '1px solid var(--border-1)', flex: 'none' }}>
        <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: 'var(--fg-1)', fontFamily: 'var(--font-body)', fontSize: 14 }}>
          {tt(UI.cancel)}
        </button>
        <div style={{ flex: 1, fontFamily: 'var(--font-display)', fontSize: 17, fontWeight: 600, textAlign: 'center' }}>
          {tt(UI.editProfile)}
        </div>
        <button onClick={() => onSave?.({ displayName, bio })} style={{
          background: 'var(--c-ai)', color: '#fff',
          border: 'none', borderRadius: 999, padding: '8px 16px',
          fontWeight: 600, fontSize: 13, cursor: 'pointer', marginRight: 6,
        }}>{tt(UI.save)}</button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '20px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, marginBottom: 18 }}>
          <Avatar initial={user.initial} size={84} tone="kinari"/>
          <button style={{ background: 'transparent', border: 'none', color: 'var(--fg-link)', fontFamily: 'var(--font-body)', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
            {tt({ en: 'Change avatar', ja: 'アバターを変更', ko: '아바타 변경' })}
          </button>
        </div>

        <FormField label={tt({ en: 'Display name', ja: '表示名', ko: '표시 이름' })} counter={`${displayName.length} / 50`}>
          <TextField value={displayName} onChange={setDisplayName} maxLength={50}/>
        </FormField>

        <FormField
          label={tt({ en: 'Username', ja: 'ユーザー名', ko: '사용자 이름' })}
          helper={tt({
            en: 'Cannot be changed.',
            ja: '変更できません。',
            ko: '변경할 수 없습니다.',
          })}
        >
          <TextField value={user.displayUsername} disabled/>
        </FormField>

        <FormField label={tt({ en: 'Bio', ja: '自己紹介', ko: '소개' })} counter={`${bio.length} / 200`}>
          <TextArea value={bio} onChange={setBio} maxLength={200} minHeight={80}/>
        </FormField>
      </div>
    </div>
  );
};

Object.assign(window, { EditProfileScreen });
