import { createFileRoute, useNavigate } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { api } from '@/lib/api';
import { setTokens } from '@/lib/tokens';

export const Route = createFileRoute('/login')({
  component: LoginPage,
});

function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const { data: auth, error: loginError, response } = await api.POST('/v1/auth/login', {
        body: { email, password },
      });
      if (loginError || !auth) {
        setError(response.status === 401 ? 'Invalid credentials' : 'Login failed');
        return;
      }
      setTokens(auth.access_token, auth.refresh_token);

      const { data: me, error: meError } = await api.GET('/v1/users/me');
      if (meError || !me) {
        setError('Could not fetch profile');
        return;
      }
      if (me.role !== 'admin' && me.role !== 'moderator') {
        setError('Insufficient privileges — admin or moderator role required.');
        return;
      }
      navigate({ to: '/queue' });
    } catch {
      setError('Network error');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="max-w-sm mx-auto mt-12">
      <h1 className="text-xl font-semibold mb-6">Sign in</h1>
      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-[color:var(--color-muted)]">Email</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoComplete="email"
            className="border border-[color:var(--color-border)] rounded px-3 py-2 bg-[color:var(--color-surface)]"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-[color:var(--color-muted)]">Password</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete="current-password"
            className="border border-[color:var(--color-border)] rounded px-3 py-2 bg-[color:var(--color-surface)]"
          />
        </label>
        {error && <p className="text-sm text-red-700">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="mt-2 bg-[color:var(--color-accent)] text-white rounded py-2 disabled:opacity-50"
        >
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  );
}
