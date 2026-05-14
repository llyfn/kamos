// KAMOS — Screen: Settings (SPEC §3.3, §5.1, §8).
// Account: change email (re-verify), change password (current required),
// delete account (soft-delete, 30-day username hold).
// Privacy: public (instant follows) vs private (approval required).
// Preferences: locale (en | ja | ko).

const SettingsScreen = ({ user, onClose, onChangeEmail, onChangePassword, onDeleteAccount }) => {
  const { tt, locale, setLocale } = useLocale();
  const [privacy, setPrivacy] = React.useState(user.privacy);
  const [confirmDelete, setConfirmDelete] = React.useState(false);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--bg-page)' }}>
      <TopBar title={tt(UI.settings)} onBack={onClose}/>

      <div style={{ flex: 1, overflowY: 'auto' }}>
        <Section title={tt({ en: 'Account', ja: 'アカウント', ko: '계정' })}>
          <Row label={tt({ en: 'Email', ja: 'メール', ko: '이메일' })} value={user.email} onClick={onChangeEmail}/>
          <Row
            label={tt({ en: 'Email verification', ja: 'メール確認', ko: '이메일 인증' })}
            value={user.emailVerified
              ? tt({ en: 'Verified', ja: '確認済み', ko: '확인됨' })
              : tt({ en: 'Pending', ja: '未確認',   ko: '미확인' })}
          />
          <Row label={tt({ en: 'Password', ja: 'パスワード', ko: '비밀번호' })} value="••••••••" onClick={onChangePassword}/>
        </Section>

        <Section title={tt({ en: 'Privacy', ja: 'プライバシー', ko: '개인 정보' })}>
          <div style={{ background: 'var(--bg-surface)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', borderBottom: '1px solid var(--border-1)' }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: 'var(--font-body)', fontSize: 15, color: 'var(--fg-1)' }}>
                  {tt({ en: 'Private account', ja: '非公開アカウント', ko: '비공개 계정' })}
                </div>
                <div style={{ fontSize: 12, color: 'var(--fg-3)', marginTop: 2 }}>
                  {tt({
                    en: 'Approve followers individually. Check-ins are visible only to approved followers.',
                    ja: 'フォロワーを個別に承認。チェックインは承認済みフォロワーのみに表示。',
                    ko: '팔로워를 개별 승인. 체크인은 승인된 팔로워에게만 표시.',
                  })}
                </div>
              </div>
              <Toggle on={privacy === 'private'} onChange={(v) => setPrivacy(v ? 'private' : 'public')}/>
            </div>
          </div>
        </Section>

        <Section title={tt({ en: 'Preferences', ja: '環境設定', ko: '환경 설정' })}>
          <div style={{ background: 'var(--bg-surface)', padding: '14px 16px', borderBottom: '1px solid var(--border-1)' }}>
            <div style={{ fontFamily: 'var(--font-body)', fontSize: 15, color: 'var(--fg-1)', marginBottom: 8 }}>
              {tt({ en: 'Language', ja: '言語', ko: '언어' })}
            </div>
            <SegmentedControl
              value={locale}
              onChange={setLocale}
              options={[
                { id: 'en', label: 'English' },
                { id: 'ja', label: '日本語' },
                { id: 'ko', label: '한국어' },
              ]}
            />
          </div>
        </Section>

        <Section title={tt({ en: 'Danger zone', ja: '危険な操作', ko: '계정 삭제' })}>
          <Row
            label={tt({ en: 'Delete account', ja: 'アカウントを削除', ko: '계정 삭제' })}
            helper={tt({
              en: 'Soft-delete · username held for 30 days before release.',
              ja: '論理削除 · ユーザー名は30日間保留されます。',
              ko: '소프트 삭제 · 사용자 이름은 30일간 보류 후 해제됩니다.',
            })}
            danger
            onClick={() => setConfirmDelete(true)}
          />
        </Section>

        <div style={{ padding: '24px 20px', fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--fg-3)', textAlign: 'center' }}>
          KAMOS · v0.1.0
        </div>
      </div>

      {confirmDelete && (
        <Sheet open onClose={() => setConfirmDelete(false)} title={tt({ en: 'Delete account?', ja: 'アカウントを削除しますか？', ko: '계정을 삭제하시겠습니까?' })}>
          <p style={{ fontSize: 14, color: 'var(--fg-2)', lineHeight: 1.55, margin: '4px 0 18px' }}>
            {tt({
              en: 'Your account will be soft-deleted. Your username will be held for 30 days before it can be claimed by someone else. Check-ins and collections will be removed from public view.',
              ja: 'アカウントは論理削除されます。ユーザー名は30日間保留され、その後再利用可能になります。チェックインとコレクションは非表示となります。',
              ko: '계정은 소프트 삭제됩니다. 사용자 이름은 30일간 보류 후 다른 사용자가 사용할 수 있습니다. 체크인과 컬렉션은 비공개 처리됩니다.',
            })}
          </p>
          <div style={{ display: 'flex', gap: 8 }}>
            <Btn kind="secondary" full onClick={() => setConfirmDelete(false)}>{tt(UI.cancel)}</Btn>
            <Btn kind="danger" full onClick={() => { setConfirmDelete(false); onDeleteAccount?.(); }}>
              {tt({ en: 'Delete', ja: '削除', ko: '삭제' })}
            </Btn>
          </div>
        </Sheet>
      )}
    </div>
  );
};

const Section = ({ title, children }) => (
  <div style={{ marginTop: 18 }}>
    <div style={{ padding: '8px 20px 6px', fontFamily: 'var(--font-body)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.12em', color: 'var(--fg-3)' }}>{title}</div>
    {children}
  </div>
);

Object.assign(window, { SettingsScreen });
