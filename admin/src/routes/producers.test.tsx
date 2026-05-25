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

import { Route } from './producers';

function renderProducers() {
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
interface ProducerFixture {
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

function setupListResponse(items: ProducerFixture[], hasMore = false) {
  apiGet.mockImplementation((path: string) => {
    if (path === '/v1/admin/me') return Promise.resolve(defaultMe());
    if (path === '/v1/admin/producers') {
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

const sampleProducer: ProducerFixture = {
  id: '11111111-1111-1111-1111-111111111111',
  name: { en: 'Asahi Shuzo', ja: '旭酒造' },
  prefecture: samplePrefecture,
  created_at: '2026-05-16T12:00:00Z',
  deleted_at: null,
};

describe('/producers', () => {
  beforeEach(() => {
    apiGet.mockReset();
    apiPost.mockReset();
    apiPatch.mockReset();
    apiDelete.mockReset();
  });

  it('renders rows from the API response', async () => {
    setupListResponse([sampleProducer]);
    renderProducers();

    expect(await screen.findByText('Asahi Shuzo')).toBeInTheDocument();
    expect(screen.getByText('Yamaguchi')).toBeInTheDocument();
    expect(screen.getByText('live')).toBeInTheDocument();
  });

  it('shows an empty state with no items', async () => {
    setupListResponse([]);
    renderProducers();
    expect(await screen.findByText('No producers.')).toBeInTheDocument();
  });

  it('q filter triggers refetch with the right query string', async () => {
    setupListResponse([sampleProducer]);
    renderProducers();
    await screen.findByText('Asahi Shuzo');

    const search = screen.getByPlaceholderText('FTS over name_i18n') as HTMLInputElement;
    fireEvent.change(search, { target: { value: 'asahi' } });

    await waitFor(() => {
      const lastCall = apiGet.mock.calls.filter((c) => c[0] === '/v1/admin/producers').pop();
      expect(lastCall?.[1]?.params?.query?.q).toBe('asahi');
    });
  });

  it('create flow POSTs to /v1/admin/producers', async () => {
    setupListResponse([]);
    apiPost.mockResolvedValueOnce({
      data: { ...sampleProducer, id: 'new-id' },
      response: { status: 201 },
    });

    renderProducers();
    fireEvent.click(await screen.findByRole('button', { name: 'New producer' }));

    const englishLabel = await screen.findByText(/English \*/);
    const englishInput = englishLabel.parentElement?.querySelector('input');
    const japaneseLabel = screen.getByText(/Japanese \*/);
    const japaneseInput = japaneseLabel.parentElement?.querySelector('input');
    if (!englishInput || !japaneseInput) throw new Error('name inputs missing');
    fireEvent.change(englishInput, { target: { value: 'Test Producer' } });
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
    expect(path).toBe('/v1/admin/producers');
    expect(init.body.name_i18n.en).toBe('Test Producer');
    expect(init.body.name_i18n.ja).toBe('テスト酒造');
  });

  it('edit flow PATCHes to /v1/admin/producers/{id}', async () => {
    setupListResponse([sampleProducer]);
    apiPatch.mockResolvedValueOnce({
      data: sampleProducer,
      response: { status: 200 },
    });

    renderProducers();
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
    expect(path).toBe('/v1/admin/producers/{id}');
    expect(init.params.path.id).toBe(sampleProducer.id);
  });

  it('soft-delete flow DELETEs to /v1/admin/producers/{id}', async () => {
    setupListResponse([sampleProducer]);
    apiDelete.mockResolvedValueOnce({ response: { status: 204 } });

    renderProducers();
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
    expect(path).toBe('/v1/admin/producers/{id}');
    expect(init.params.path.id).toBe(sampleProducer.id);
  });

  it('soft-delete 409 surfaces the PRODUCER_HAS_LIVE_BEVERAGES toast', async () => {
    setupListResponse([sampleProducer]);
    apiDelete.mockResolvedValueOnce({
      error: { error: 'has live beverages', code: 'PRODUCER_HAS_LIVE_BEVERAGES' },
      response: { status: 409 },
    });

    renderProducers();
    fireEvent.click(await screen.findByRole('button', { name: 'Soft-delete' }));

    const dialog = await screen.findByRole('dialog');
    const submit = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submit) throw new Error('submit not found');
    fireEvent.click(submit);

    expect(
      await screen.findByText(
        /Cannot delete — this producer still has live beverages\. Soft-delete or reassign them first\./,
      ),
    ).toBeInTheDocument();
  });

  it('restore flow POSTs to /v1/admin/producers/{id}/restore', async () => {
    const deleted = { ...sampleProducer, deleted_at: '2026-05-16T13:00:00Z' };
    setupListResponse([deleted]);
    apiPost.mockResolvedValueOnce({
      data: { ...deleted, deleted_at: null },
      response: { status: 200 },
    });

    renderProducers();
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
    expect(path).toBe('/v1/admin/producers/{id}/restore');
    expect(init.params.path.id).toBe(sampleProducer.id);
  });
});
