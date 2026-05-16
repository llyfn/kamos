import { createFileRoute, useNavigate } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { setTokens } from '@/lib/tokens';

export const Route = createFileRoute('/login')({
  component: LoginPage,
});

const API_BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? 'http://localhost:8080';

interface AuthResponse {
  access_token: string;
  refresh_token: string;
  user: { id: string; username: string };
}

interface MeResponse {
  id: string;
  username: string;
  role: 'user' | 'moderator' | 'admin';
}

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
      const loginRes = await fetch(`${API_BASE}/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      if (!loginRes.ok) {
        setError(loginRes.status === 401 ? 'Invalid credentials' : 'Login failed');
        return;
      }
      const auth = (await loginRes.json()) as AuthResponse;
      setTokens(auth.access_token, auth.refresh_token);

      const meRes = await fetch(`${API_BASE}/v1/users/me`, {
        headers: { Authorization: `Bearer ${auth.access_token}` },
      });
      if (!meRes.ok) {
        setError('Could not fetch profile');
        return;
      }
      const me = (await meRes.json()) as MeResponse;
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
