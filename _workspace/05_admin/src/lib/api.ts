// Typed Fetch wrapper around openapi-fetch. Reads the access token from
// localStorage and attaches Authorization on every request. On 401, attempts
// a refresh once via /v1/auth/refresh; on second failure, clears tokens and
// reloads to /login.

import createClient, { type Middleware } from 'openapi-fetch';
import type { paths } from '@/types/api';
import { clearTokens, getAccessToken, getRefreshToken, setTokens } from '@/lib/tokens';

const API_BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? 'http://localhost:8080';

export class ForbiddenError extends Error {
  constructor(message = 'Forbidden') {
    super(message);
    this.name = 'ForbiddenError';
  }
}

interface RefreshResponseJSON {
  access_token: string;
  refresh_token: string;
}

let refreshInFlight: Promise<string | null> | null = null;

async function tryRefresh(): Promise<string | null> {
  if (refreshInFlight) return refreshInFlight;
  const refresh = getRefreshToken();
  if (!refresh) return null;
  refreshInFlight = (async () => {
    try {
      const res = await fetch(`${API_BASE}/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh_token: refresh }),
      });
      if (!res.ok) return null;
      const body = (await res.json()) as RefreshResponseJSON;
      setTokens(body.access_token, body.refresh_token);
      return body.access_token;
    } catch {
      return null;
    } finally {
      refreshInFlight = null;
    }
  })();
  return refreshInFlight;
}

const authMiddleware: Middleware = {
  async onRequest({ request }) {
    const token = getAccessToken();
    if (token) request.headers.set('Authorization', `Bearer ${token}`);
    return request;
  },
  async onResponse({ request, response }) {
    if (response.status === 403) {
      throw new ForbiddenError();
    }
    if (response.status !== 401) return response;
    // Avoid loops on the refresh endpoint itself.
    if (new URL(request.url).pathname.endsWith('/v1/auth/refresh')) return response;

    const newAccess = await tryRefresh();
    if (!newAccess) {
      clearTokens();
      if (typeof window !== 'undefined') window.location.assign('/login');
      return response;
    }
    const retry = new Request(request, {});
    retry.headers.set('Authorization', `Bearer ${newAccess}`);
    return fetch(retry);
  },
};

export const api = createClient<paths>({ baseUrl: API_BASE });
api.use(authMiddleware);

export type { paths } from '@/types/api';
