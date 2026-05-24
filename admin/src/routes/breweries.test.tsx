import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ToastProvider } from '@/components/toast';

const apiGet = vi.fn();
const apiPost = vi.fn();
const apiPatch = vi.fn();
const apiDelete = vi.fn();
vi.mock('@/lib/api', () => ({
  api: {
    GET: (...args: unknown[]) => apiGet(...args),
    POST: (...args: unknown[]) => apiPost(...args),
    PATCH: (...args: unknown[]) => apiPatch(...args),
    DELETE: (...args: unknown[]) => apiDelete(...args),
  },
  ForbiddenError: class extends Error {},
}));

import { Route } from './breweries';

function renderBreweries() {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const Component = Route.options.component;
  if (!Component) throw new Error('no component on Route');
  return render(
    <QueryClientProvider client={qc}>
      <ToastProvider>
        <Component />
      </ToastProvider>
    </QueryClientProvider>,
  );
}

interface RegionFixture {
  id: string;
  slug: string;
  name: { en: string; ja?: string; ko?: string };
  sort_order: number;
}
interface PrefectureFixture {
  id: string;
  slug: string;
  name: { en: string; ja?: string; ko?: string };
  sort_order: number;
  region: RegionFixture;
}
interface BreweryFixture {
  id: string;
  name: { en: string; ja?: string; ko?: string };
  prefecture?: PrefectureFixture | null;
  founded_year?: number;
  website?: string;
  description?: { en: string; ja?: string; ko?: string };
  beverage_count?: number;
  created_at: string;
  deleted_at: string | null;
}

function defaultMe(role: 'admin' | 'moderator' | 'user' = 'admin') {
  return { data: { role } };
}

const sampleRegion: RegionFixture = {
  id: 'rrrrrrrr-7777-7777-7777-777777777777',
  slug: 'chugoku',
  name: { en: 'Chūgoku', ja: '中国' },
  sort_order: 7,
};

const samplePrefecture: PrefectureFixture = {
  id: 'pppppppp-3535-3535-3535-353535353535',
  slug: 'yamaguchi',
  name: { en: 'Yamaguchi', ja: '山口県' },
  sort_order: 35,
  region: sampleRegion,
};

const sampleRegionsResponse = [
  {
    id: sampleRegion.id,
    slug: sampleRegion.slug,
    name: sampleRegion.name,
    sort_order: sampleRegion.sort_order,
    prefectures: [
      {
        id: samplePrefecture.id,
        slug: samplePrefecture.slug,
        name: samplePrefecture.name,
        sort_order: samplePrefecture.sort_order,
      },
    ],
  },
];

function setupListResponse(items: BreweryFixture[], hasMore = false) {
  apiGet.mockImplementation((path: string) => {
    if (path === '/v1/admin/me') return Promise.resolve(defaultMe());
    if (path === '/v1/admin/breweries') {
      return Promise.resolve({
        data: { items, next_cursor: null, has_more: hasMore },
      });
    }
    if (path === '/v1/reference/regions') {
      return Promise.resolve({ data: sampleRegionsResponse });
    }
    return Promise.resolve({ error: { error: 'not_mocked', code: 'NOT_MOCKED' } });
  });
}

const sampleBrewery: BreweryFixture = {
  id: '11111111-1111-1111-1111-111111111111',
  name: { en: 'Asahi Shuzo', ja: '旭酒造' },
  prefecture: samplePrefecture,
  created_at: '2026-05-16T12:00:00Z',
  deleted_at: null,
};

describe('/breweries', () => {
  beforeEach(() => {
    apiGet.mockReset();
    apiPost.mockReset();
    apiPatch.mockReset();
    apiDelete.mockReset();
  });

  it('renders rows from the API response', async () => {
    setupListResponse([sampleBrewery]);
    renderBreweries();

    expect(await screen.findByText('Asahi Shuzo')).toBeInTheDocument();
    expect(screen.getByText('Yamaguchi')).toBeInTheDocument();
    expect(screen.getByText('live')).toBeInTheDocument();
  });

  it('shows an empty state with no items', async () => {
    setupListResponse([]);
    renderBreweries();
    expect(await screen.findByText('No breweries.')).toBeInTheDocument();
  });

  it('q filter triggers refetch with the right query string', async () => {
    setupListResponse([sampleBrewery]);
    renderBreweries();
    await screen.findByText('Asahi Shuzo');

    const search = screen.getByPlaceholderText('FTS over name_i18n') as HTMLInputElement;
    fireEvent.change(search, { target: { value: 'asahi' } });

    await waitFor(() => {
      const lastCall = apiGet.mock.calls.filter((c) => c[0] === '/v1/admin/breweries').pop();
      expect(lastCall?.[1]?.params?.query?.q).toBe('asahi');
    });
  });

  it('create flow POSTs to /v1/admin/breweries', async () => {
    setupListResponse([]);
    apiPost.mockResolvedValueOnce({
      data: { ...sampleBrewery, id: 'new-id' },
      response: { status: 201 },
    });

    renderBreweries();
    fireEvent.click(await screen.findByRole('button', { name: 'New brewery' }));

    const englishLabel = await screen.findByText(/English \*/);
    const englishInput = englishLabel.parentElement?.querySelector('input');
    const japaneseLabel = screen.getByText(/Japanese \*/);
    const japaneseInput = japaneseLabel.parentElement?.querySelector('input');
    if (!englishInput || !japaneseInput) throw new Error('name inputs missing');
    fireEvent.change(englishInput, { target: { value: 'Test Brewery' } });
    fireEvent.change(japaneseInput, { target: { value: 'テスト酒造' } });

    const dialog = screen.getByRole('dialog');
    const submit = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submit) throw new Error('submit not found');
    fireEvent.click(submit);

    await waitFor(() => expect(apiPost).toHaveBeenCalledTimes(1));
    const firstCall = apiPost.mock.calls[0];
    if (!firstCall) throw new Error('apiPost not called');
    const [path, init] = firstCall;
    expect(path).toBe('/v1/admin/breweries');
    expect(init.body.name_i18n.en).toBe('Test Brewery');
    expect(init.body.name_i18n.ja).toBe('テスト酒造');
  });

  it('edit flow PATCHes to /v1/admin/breweries/{id}', async () => {
    setupListResponse([sampleBrewery]);
    apiPatch.mockResolvedValueOnce({
      data: sampleBrewery,
      response: { status: 200 },
    });

    renderBreweries();
    fireEvent.click(await screen.findByRole('button', { name: 'Edit' }));

    const dialog = await screen.findByRole('dialog');
    const submit = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submit) throw new Error('submit not found');
    fireEvent.click(submit);

    await waitFor(() => expect(apiPatch).toHaveBeenCalledTimes(1));
    const firstCall = apiPatch.mock.calls[0];
    if (!firstCall) throw new Error('apiPatch not called');
    const [path, init] = firstCall;
    expect(path).toBe('/v1/admin/breweries/{id}');
    expect(init.params.path.id).toBe(sampleBrewery.id);
  });

  it('soft-delete flow DELETEs to /v1/admin/breweries/{id}', async () => {
    setupListResponse([sampleBrewery]);
    apiDelete.mockResolvedValueOnce({ response: { status: 204 } });

    renderBreweries();
    fireEvent.click(await screen.findByRole('button', { name: 'Soft-delete' }));

    const dialog = await screen.findByRole('dialog');
    const submit = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submit) throw new Error('submit not found');
    fireEvent.click(submit);

    await waitFor(() => expect(apiDelete).toHaveBeenCalledTimes(1));
    const firstCall = apiDelete.mock.calls[0];
    if (!firstCall) throw new Error('apiDelete not called');
    const [path, init] = firstCall;
    expect(path).toBe('/v1/admin/breweries/{id}');
    expect(init.params.path.id).toBe(sampleBrewery.id);
  });

  it('soft-delete 409 surfaces the BREWERY_HAS_LIVE_BEVERAGES toast', async () => {
    setupListResponse([sampleBrewery]);
    apiDelete.mockResolvedValueOnce({
      error: { error: 'has live beverages', code: 'BREWERY_HAS_LIVE_BEVERAGES' },
      response: { status: 409 },
    });

    renderBreweries();
    fireEvent.click(await screen.findByRole('button', { name: 'Soft-delete' }));

    const dialog = await screen.findByRole('dialog');
    const submit = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submit) throw new Error('submit not found');
    fireEvent.click(submit);

    expect(
      await screen.findByText(
        /Cannot delete — this brewery still has live beverages\. Soft-delete or reassign them first\./,
      ),
    ).toBeInTheDocument();
  });

  it('restore flow POSTs to /v1/admin/breweries/{id}/restore', async () => {
    const deleted = { ...sampleBrewery, deleted_at: '2026-05-16T13:00:00Z' };
    setupListResponse([deleted]);
    apiPost.mockResolvedValueOnce({
      data: { ...deleted, deleted_at: null },
      response: { status: 200 },
    });

    renderBreweries();
    fireEvent.click(await screen.findByRole('button', { name: 'Restore' }));

    const dialog = await screen.findByRole('dialog');
    const submit = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submit) throw new Error('submit not found');
    fireEvent.click(submit);

    await waitFor(() => expect(apiPost).toHaveBeenCalledTimes(1));
    const firstCall = apiPost.mock.calls[0];
    if (!firstCall) throw new Error('apiPost not called');
    const [path, init] = firstCall;
    expect(path).toBe('/v1/admin/breweries/{id}/restore');
    expect(init.params.path.id).toBe(sampleBrewery.id);
  });
});
