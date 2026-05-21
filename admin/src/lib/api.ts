// Typed Fetch wrapper around openapi-fetch. Stage 4 — drops localStorage
// + Bearer in favor of HttpOnly cookies. The browser auto-attaches the
// kamos_admin_* cookies when `credentials: 'include'` is set, and the
// CSRF middleware demands an X-CSRF-Token header that mirrors the
// kamos_admin_csrf cookie value (double-submit pattern).
//
// On 401 we attempt one /v1/auth/admin-refresh round-trip (cookies-only,
// no body) and retry. On second failure we redirect to /login —
// session is gone.

import createClient, { type Middleware } from 'openapi-fetch';
import type { paths } from '@/types/api';
import { attachCsrf, getCsrfToken } from '@/lib/session';

const API_BASE =
  (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? 'http://localhost:8080';

export class ForbiddenError extends Error {
  constructor(message = 'Forbidden') {
    super(message);
    this.name = 'ForbiddenError';
  }
}

let refreshInFlight: Promise<boolean> | null = null;

async function tryRefresh(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = (async () => {
    try {
      const res = await fetch(`${API_BASE}/v1/auth/admin-refresh`, {
        method: 'POST',
        credentials: 'include',
      });
      return res.ok;
    } catch {
      return false;
    } finally {
      refreshInFlight = null;
    }
  })();
  return refreshInFlight;
}

const sessionMiddleware: Middleware = {
  async onRequest({ request }) {
    // Make every request a cookie request and stamp the CSRF header
    // when applicable. The Request object exposed by openapi-fetch is
    // immutable in shape, but headers + credentials propagate through
    // the returned Request below.
    const method = request.method.toUpperCase();
    if (method !== 'GET' && method !== 'HEAD') {
      const csrf = getCsrfToken();
      if (csrf) request.headers.set('X-CSRF-Token', csrf);
    }
    return new Request(request, { credentials: 'include' });
  },
  async onResponse({ request, response }) {
    if (response.status === 403) {
      throw new ForbiddenError();
    }
    if (response.status !== 401) return response;
    if (new URL(request.url).pathname.endsWith('/v1/auth/admin-refresh')) return response;

    const ok = await tryRefresh();
    if (!ok) {
      if (typeof window !== 'undefined') window.location.assign('/login');
      return response;
    }
    const retry = new Request(request, { credentials: 'include' });
    const method = retry.method.toUpperCase();
    if (method !== 'GET' && method !== 'HEAD') {
      const csrf = getCsrfToken();
      if (csrf) retry.headers.set('X-CSRF-Token', csrf);
    }
    return fetch(retry);
  },
};

export const api = createClient<paths>({ baseUrl: API_BASE, credentials: 'include' });
api.use(sessionMiddleware);

// Re-export attachCsrf for ad-hoc fetch() callers (non-openapi-fetch paths).
export { attachCsrf };

export type { paths } from '@/types/api';
