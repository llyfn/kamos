import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

const fetchMock = vi.fn();
vi.stubGlobal('fetch', fetchMock);

function setCsrfCookie(value: string | null) {
  Object.defineProperty(document, 'cookie', {
    configurable: true,
    get: () => (value === null ? '' : `kamos_admin_csrf=${value}`),
  });
}

beforeEach(() => {
  vi.resetModules();
  fetchMock.mockReset();
  setCsrfCookie(null);
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
  it('forwards GET requests with credentials and no X-CSRF-Token', async () => {
    setCsrfCookie('csrf-abc');
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
    expect(req.credentials).toBe('include');
    expect(req.headers.get('X-CSRF-Token')).toBeNull();
  });

  it('attaches X-CSRF-Token on POST when cookie present', async () => {
    setCsrfCookie('csrf-abc');
    fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }));
    const { api } = await import('./api');
    await api.POST('/v1/admin/users/{id}/suspend', {
      params: { path: { id: 'u-1' } },
    });
    const req = fetchMock.mock.calls[0]?.[0] as Request;
    expect(req.headers.get('X-CSRF-Token')).toBe('csrf-abc');
    expect(req.credentials).toBe('include');
  });

  it('refreshes once on 401 via admin-refresh and retries', async () => {
    setCsrfCookie('csrf-abc');
    // 1st: /v1/users/me 401
    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 401 }));
    // 2nd: admin-refresh 204
    fetchMock.mockResolvedValueOnce(new Response(null, { status: 204 }));
    // 3rd: retry /v1/users/me 200
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
    const refreshUrl = fetchMock.mock.calls[1]?.[0] as string;
    expect(refreshUrl).toContain('/v1/auth/admin-refresh');
    const refreshInit = fetchMock.mock.calls[1]?.[1] as RequestInit;
    expect(refreshInit?.method).toBe('POST');
  });

  it('redirects to /login when refresh fails', async () => {
    setCsrfCookie('csrf-abc');
    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 401 }));
    fetchMock.mockResolvedValueOnce(new Response('{}', { status: 401 }));

    const { api } = await import('./api');
    await api.GET('/v1/users/me');
    expect(window.location.assign).toHaveBeenCalledWith('/login');
  });
});
