// Stage 4 — admin session helpers. Replaces tokens.ts (which used
// localStorage). The browser holds the auth state in three HttpOnly
// cookies set by the server; JS only ever reads the CSRF token cookie.
//
// Every fetch under /v1/admin must include `credentials: 'include'` so
// the browser attaches the kamos_admin_* cookies, plus an
// `X-CSRF-Token` header that mirrors the kamos_admin_csrf cookie value
// (double-submit pattern).

const API_BASE =
  (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? 'http://localhost:8080';

const CSRF_COOKIE = 'kamos_admin_csrf';

/** Read the CSRF cookie value, URL-decoded. Returns null when absent. */
export function getCsrfToken(): string | null {
  if (typeof document === 'undefined') return null;
  const target = `${CSRF_COOKIE}=`;
  for (const raw of document.cookie.split(';')) {
    const trimmed = raw.trim();
    if (trimmed.startsWith(target)) {
      try {
        return decodeURIComponent(trimmed.slice(target.length));
      } catch {
        return trimmed.slice(target.length);
      }
    }
  }
  return null;
}

/** Sign the operator in. Throws on non-2xx. */
export async function login(email: string, password: string): Promise<void> {
  const res = await fetch(`${API_BASE}/v1/auth/admin-login`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    const code = res.status === 401 ? 'invalid_credentials' : 'login_failed';
    throw new LoginError(code, res.status);
  }
}

/** Best-effort logout. Always clears the local session expectation. */
export async function logout(): Promise<void> {
  try {
    const csrf = getCsrfToken();
    const headers: Record<string, string> = {};
    if (csrf) headers['X-CSRF-Token'] = csrf;
    await fetch(`${API_BASE}/v1/auth/admin-logout`, {
      method: 'POST',
      credentials: 'include',
      headers,
    });
  } catch {
    // Best-effort — the cookie clear is what matters.
  }
}

/** Mutates the given RequestInit to attach X-CSRF-Token when needed. */
export function attachCsrf(init: RequestInit | undefined, method: string): RequestInit {
  const base: RequestInit = { ...(init ?? {}), credentials: 'include' };
  if (method.toUpperCase() === 'GET' || method.toUpperCase() === 'HEAD') return base;
  const csrf = getCsrfToken();
  if (!csrf) return base;
  const headers = new Headers(base.headers ?? undefined);
  headers.set('X-CSRF-Token', csrf);
  base.headers = headers;
  return base;
}

export class LoginError extends Error {
  readonly code: 'invalid_credentials' | 'forbidden' | 'login_failed';
  readonly status: number;
  constructor(code: LoginError['code'], status: number) {
    super(code);
    this.code = code;
    this.status = status;
    this.name = 'LoginError';
  }
}
