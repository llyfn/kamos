import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const fetchMock = vi.fn();
vi.stubGlobal('fetch', fetchMock);

function installLocalStorage(): Storage {
  const store = new Map<string, string>();
  const stub: Storage = {
    get length() {
      return store.size;
    },
    clear: () => store.clear(),
    getItem: (k) => (store.has(k) ? (store.get(k) as string) : null),
    key: (i) => Array.from(store.keys())[i] ?? null,
    removeItem: (k) => {
      store.delete(k);
    },
    setItem: (k, v) => {
      store.set(k, String(v));
    },
  };
  Object.defineProperty(window, 'localStorage', { value: stub, configurable: true });
  return stub;
}

beforeEach(() => {
  vi.resetModules();
  fetchMock.mockReset();
  installLocalStorage();
  Object.defineProperty(window, 'location', {
    value: { ...window.location, assign: vi.fn() },
    writable: true,
    configurable: true,
  });
});

afterEach(() => {
  vi.unstubAllGlobals();
  vi.stubGlobal('fetch', fetchMock);
});

describe('api client', () => {
  it('attaches the Authorization header from localStorage', async () => {
    window.localStorage.setItem('kamos_access_token', 'access-123');
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ id: 'u1', username: 'op', role: 'admin' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    const { api } = await import('./api');
    await api.GET('/v1/users/me');
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const req = fetchMock.mock.calls[0]?.[0] as Request;
    expect(req.headers.get('Authorization')).toBe('Bearer access-123');
  });

  it('refreshes once on 401 and retries the original request', async () => {
    window.localStorage.setItem('kamos_access_token', 'expired');
    window.localStorage.setItem('kamos_refresh_token', 'refresh-1');

    // 1st call: /v1/users/me returns 401
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ error: 'expired', code: 'TOKEN_EXPIRED' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      }),
    );
    // 2nd call: /v1/auth/refresh returns new pair
    fetchMock.mockResolvedValueOnce(
      new Response(
        JSON.stringify({ access_token: 'new-access', refresh_token: 'new-refresh' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    );
    // 3rd call: retry of /v1/users/me succeeds
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify({ id: 'u1', username: 'op', role: 'admin' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    const { api } = await import('./api');
    const { data } = await api.GET('/v1/users/me');
    expect(data).toMatchObject({ id: 'u1' });
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(window.localStorage.getItem('kamos_access_token')).toBe('new-access');
    expect(window.localStorage.getItem('kamos_refresh_token')).toBe('new-refresh');
  });

  it('clears tokens and redirects when refresh fails', async () => {
    window.localStorage.setItem('kamos_access_token', 'expired');
    window.localStorage.setItem('kamos_refresh_token', 'bad');

    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 401 }));
    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 401 }));

    const { api } = await import('./api');
    await api.GET('/v1/users/me');
    expect(window.localStorage.getItem('kamos_access_token')).toBeNull();
    expect(window.location.assign).toHaveBeenCalledWith('/login');
  });
});
