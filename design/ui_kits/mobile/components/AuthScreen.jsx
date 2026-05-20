// KAMOS — Screen: Authentication flows (SPEC §3.1).
// Modes: signIn | signUp | forgot | verifyEmail.
// - Email + password (≥8 chars, bcrypt server-side).
// - Google OAuth2 (auto-create on first login). Only the client ID ships
//   to the app; the secret stays server-side (SPEC §3.1, brief §6.10).
// - Email verification: 24h link expiry; unverified accounts can still log in.

const AuthScreen = ({ mode = 'signIn', onModeChange, onSignedIn }) => {
  const { tt } = useLocale();
  const [email, setEmail]       = React.useState('');
  const [password, setPassword] = React.useState('');
  const [username, setUsername] = React.useState('');

  const passwordTooShort = password.length > 0 && password.length < 8;
  const usernameInvalid  = username.length > 0 && !/^[A-Za-z0-9_]{3,30}$/.test(username);

  const isSignIn = mode === 'signIn';
  const isSignUp = mode === 'signUp';
  const isForgot = mode === 'forgot';
  const isVerify = mode === 'verifyEmail';

  return (
    <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '24px 24px 8px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
        <img src="../../assets/logo.png" alt="" style={{ width: 56, height: 56, marginTop: 16 }}/>
        <div style={{ fontFamily: 'var(--font-display)', fontSize: 28, fontWeight: 700, letterSpacing: '0.04em', color: 'var(--c-kon)' }}>KAMOS</div>
        <div style={{ fontSize: 13, color: 'var(--fg-3)', textAlign: 'center', maxWidth: 280 }}>
          {tt({
            en: 'Discover and log Nihonshu, Shochu, and Liqueur.',
            ja: '日本酒、焼酎、リキュールを記録するアプリ。',
            ko: '니혼슈, 쇼츄, 리큐어를 기록하는 앱.',
          })}
        </div>
      </div>

      <div style={{ flex: 1, padding: '24px 20px 20px' }}>
        {isVerify ? (
          <VerifyEmail email={email || 'you@example.com'} onResend={() => {}} onContinue={onSignedIn}/>
        ) : isForgot ? (
          <>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 22, fontWeight: 600, margin: '0 0 4px' }}>
              {tt({ en: 'Reset password', ja: 'パスワードを再設定', ko: '비밀번호 재설정' })}
            </h2>
            <p style={{ fontSize: 13, color: 'var(--fg-3)', margin: '0 0 18px' }}>
              {tt({
                en: 'Enter your email. We will send a reset link valid for 1 hour.',
                ja: 'メールアドレスを入力してください。1時間有効な再設定リンクを送信します。',
                ko: '이메일을 입력하세요. 1시간 동안 유효한 재설정 링크를 보내드립니다.',
              })}
            </p>
            <FormField label={tt({ en: 'Email', ja: 'メール', ko: '이메일' })}>
              <TextField type="email" value={email} onChange={setEmail} autoComplete="email" placeholder="you@example.com"/>
            </FormField>
            <Btn kind="primary" full onClick={() => onModeChange?.('signIn')}>
              {tt({ en: 'Send reset link', ja: 'リンクを送る', ko: '링크 보내기' })}
            </Btn>
            <button onClick={() => onModeChange?.('signIn')} style={{ background: 'transparent', border: 'none', color: 'var(--fg-link)', padding: '14px 0', fontFamily: 'var(--font-body)', fontSize: 14, cursor: 'pointer', width: '100%' }}>
              {tt({ en: 'Back to sign in', ja: 'サインインに戻る', ko: '로그인으로 돌아가기' })}
            </button>
          </>
        ) : (
          <>
            <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 22, fontWeight: 600, margin: '0 0 14px' }}>
              {isSignIn
                ? tt({ en: 'Sign in',         ja: 'サインイン',     ko: '로그인' })
                : tt({ en: 'Create account',  ja: 'アカウント作成', ko: '계정 만들기' })}
            </h2>

            {isSignUp && (
              <FormField
                label={tt({ en: 'Username', ja: 'ユーザー名', ko: '사용자 이름' })}
                helper={tt({
                  en: '3–30 chars · letters, numbers, underscores · case-insensitive',
                  ja: '3–30文字 · 英数字とアンダースコア · 大文字小文字を区別しない',
                  ko: '3–30자 · 영문/숫자/언더스코어 · 대소문자 구분 없음',
                })}
                error={usernameInvalid ? tt({ en: 'Invalid username', ja: 'ユーザー名が無効', ko: '잘못된 사용자 이름' }) : null}
              >
                <TextField value={username} onChange={setUsername} placeholder="yamamoto" maxLength={30} autoComplete="username"/>
              </FormField>
            )}

            <FormField label={tt({ en: 'Email', ja: 'メール', ko: '이메일' })}>
              <TextField type="email" value={email} onChange={setEmail} autoComplete="email" placeholder="you@example.com"/>
            </FormField>

            <FormField
              label={tt({ en: 'Password', ja: 'パスワード', ko: '비밀번호' })}
              helper={isSignUp ? tt({ en: 'At least 8 characters', ja: '8文字以上', ko: '8자 이상' }) : null}
              error={passwordTooShort ? tt({ en: 'Too short', ja: '短すぎます', ko: '너무 짧습니다' }) : null}
            >
              <TextField type="password" value={password} onChange={setPassword} autoComplete={isSignUp ? 'new-password' : 'current-password'}/>
            </FormField>

            {isSignIn && (
              <button onClick={() => onModeChange?.('forgot')} style={{ background: 'transparent', border: 'none', color: 'var(--fg-link)', padding: 0, fontFamily: 'var(--font-body)', fontSize: 13, cursor: 'pointer', marginBottom: 14 }}>
                {tt({ en: 'Forgot password?', ja: 'パスワードを忘れた', ko: '비밀번호를 잊으셨나요?' })}
              </button>
            )}

            <Btn kind="primary" full onClick={isSignUp ? () => onModeChange?.('verifyEmail') : onSignedIn}>
              {isSignIn ? tt(UI.signIn) : tt(UI.signUp)}
            </Btn>

            <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '18px 0' }}>
              <div style={{ flex: 1, height: 1, background: 'var(--border-1)' }}/>
              <div style={{ fontFamily: 'var(--font-body)', fontSize: 11, color: 'var(--fg-3)', textTransform: 'uppercase', letterSpacing: '0.12em' }}>
                {tt({ en: 'or', ja: 'または', ko: '또는' })}
              </div>
              <div style={{ flex: 1, height: 1, background: 'var(--border-1)' }}/>
            </div>

            <button onClick={onSignedIn} style={{
              width: '100%', padding: '11px 16px',
              background: '#fff', border: '1px solid var(--border-2)', borderRadius: 999,
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
              cursor: 'pointer', fontFamily: 'var(--font-body)', fontSize: 14, fontWeight: 600, color: 'var(--fg-1)',
            }}>
              <svg width="18" height="18" viewBox="0 0 18 18"><path fill="#4285F4" d="M16.51 8.18c0-.57-.05-1.12-.14-1.65H9v3.12h4.21c-.18.98-.74 1.81-1.57 2.36v1.96h2.54c1.49-1.37 2.33-3.4 2.33-5.79z"/><path fill="#34A853" d="M9 17c2.13 0 3.91-.71 5.21-1.93l-2.54-1.96c-.71.47-1.6.75-2.67.75-2.05 0-3.79-1.38-4.41-3.24H1.97v2.03A8 8 0 0 0 9 17z"/><path fill="#FBBC04" d="M4.59 10.62A4.7 4.7 0 0 1 4.34 9c0-.57.1-1.12.25-1.62V5.35H1.97A8 8 0 0 0 1 9c0 1.29.31 2.51.86 3.65l2.73-2.03z"/><path fill="#EA4335" d="M9 4.66c1.16 0 2.2.4 3.02 1.18l2.25-2.25C12.91 2.4 11.13 1.7 9 1.7A8 8 0 0 0 1.97 5.35l2.62 2.03C5.21 5.52 6.95 4.66 9 4.66z"/></svg>
              {tt({ en: 'Continue with Google', ja: 'Googleで続行', ko: 'Google로 계속하기' })}
            </button>

            <div style={{ textAlign: 'center', padding: '20px 0 8px', fontFamily: 'var(--font-body)', fontSize: 13, color: 'var(--fg-2)' }}>
              {isSignIn
                ? tt({ en: 'No account yet?', ja: 'アカウントがない？', ko: '계정이 없으신가요?' })
                : tt({ en: 'Already have an account?', ja: 'すでにアカウントをお持ち？', ko: '이미 계정이 있으신가요?' })}{' '}
              <button onClick={() => onModeChange?.(isSignIn ? 'signUp' : 'signIn')} style={{ background: 'transparent', border: 'none', color: 'var(--fg-link)', fontWeight: 600, cursor: 'pointer', fontSize: 13 }}>
                {isSignIn ? tt(UI.signUp) : tt(UI.signIn)}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

const VerifyEmail = ({ email, onResend, onContinue }) => {
  const { tt } = useLocale();
  return (
    <div style={{ textAlign: 'center', padding: '24px 8px' }}>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: 48, color: 'var(--c-gray-300)' }}>封</div>
      <h2 style={{ fontFamily: 'var(--font-display)', fontSize: 22, fontWeight: 600, margin: '8px 0 6px' }}>
        {tt({ en: 'Verify your email', ja: 'メールを確認', ko: '이메일을 확인하세요' })}
      </h2>
      <p style={{ fontSize: 14, color: 'var(--fg-2)', margin: '0 0 4px' }}>
        {tt({
          en: 'We sent a verification link to',
          ja: '確認リンクをお送りしました：',
          ko: '확인 링크를 보내드렸습니다:',
        })}
      </p>
      <p style={{ fontFamily: 'var(--font-mono)', fontSize: 14, fontWeight: 600, margin: '0 0 6px', color: 'var(--fg-1)' }}>{email}</p>
      <p style={{ fontSize: 12, color: 'var(--fg-3)', margin: '0 0 20px' }}>
        {tt({
          en: 'The link expires in 24 hours. You can still use the app while unverified.',
          ja: 'リンクは24時間有効です。未確認でもアプリは利用できます。',
          ko: '링크는 24시간 동안 유효합니다. 미확인 상태에서도 앱을 사용할 수 있습니다.',
        })}
      </p>
      <Btn kind="primary" full onClick={onContinue}>
        {tt({ en: 'Continue to KAMOS', ja: 'KAMOSを始める', ko: 'KAMOS 시작하기' })}
      </Btn>
      <button onClick={onResend} style={{ background: 'transparent', border: 'none', color: 'var(--fg-link)', padding: '14px 0', fontFamily: 'var(--font-body)', fontSize: 14, cursor: 'pointer' }}>
        {tt({ en: 'Resend email', ja: 'メールを再送', ko: '이메일 다시 보내기' })}
      </button>
    </div>
  );
};

Object.assign(window, { AuthScreen });
