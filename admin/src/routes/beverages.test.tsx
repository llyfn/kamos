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

import { Route } from './beverages';

function renderBeverages() {
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

const sampleProducer = {
  id: 'bbbbbbbb-1111-1111-1111-111111111111',
  name: { en: 'Asahi Shuzo', ja: '旭酒造' },
  created_at: '2026-05-16T12:00:00Z',
  deleted_at: null,
};

const sampleBeverage = {
  id: '11111111-1111-1111-1111-111111111111',
  name: { en: 'Dassai 23', ja: '獺祭 二割三分' },
  producer: sampleProducer,
  category: { slug: 'nihonshu', label_i18n: { en: 'Nihonshu (Sake)' } },
  flavor_profile: [],
  abv: 16,
  avg_rating: null,
  check_in_count: 0,
  created_at: '2026-05-16T12:00:00Z',
  deleted_at: null as string | null,
};

function setupListResponse(items: (typeof sampleBeverage)[]) {
  apiGet.mockImplementation((path: string) => {
    if (path === '/v1/admin/me') return Promise.resolve({ data: { role: 'admin' } });
    if (path === '/v1/admin/beverages') {
      return Promise.resolve({
        data: { items, next_cursor: null, has_more: false },
      });
    }
    if (path === '/v1/admin/producers') {
      return Promise.resolve({
        data: { items: [sampleProducer], next_cursor: null, has_more: false },
      });
    }
    if (path === '/v1/categories') {
      return Promise.resolve({
        data: [{ slug: 'nihonshu', label_i18n: { en: 'Nihonshu (Sake)' } }],
      });
    }
    if (path === '/v1/flavor-tags') return Promise.resolve({ data: [] });
    return Promise.resolve({ error: { error: 'not_mocked', code: 'NOT_MOCKED' } });
  });
}

describe('/beverages', () => {
  beforeEach(() => {
    apiGet.mockReset();
    apiPost.mockReset();
    apiPatch.mockReset();
    apiDelete.mockReset();
  });

  it('renders rows from the API response', async () => {
    setupListResponse([sampleBeverage]);
    renderBeverages();

    expect(await screen.findByText('Dassai 23')).toBeInTheDocument();
    expect(screen.getByText('Asahi Shuzo')).toBeInTheDocument();
    expect(screen.getByText('nihonshu')).toBeInTheDocument();
    expect(screen.getByText('live')).toBeInTheDocument();
  });

  it('shows an empty state with no items', async () => {
    setupListResponse([]);
    renderBeverages();
    expect(await screen.findByText('No beverages.')).toBeInTheDocument();
  });

  it('q filter triggers refetch with the right query string', async () => {
    setupListResponse([sampleBeverage]);
    renderBeverages();
    await screen.findByText('Dassai 23');

    const search = screen.getByPlaceholderText('FTS over name_i18n') as HTMLInputElement;
    fireEvent.change(search, { target: { value: 'dassai' } });

    await waitFor(() => {
      const lastCall = apiGet.mock.calls.filter((c) => c[0] === '/v1/admin/beverages').pop();
      expect(lastCall?.[1]?.params?.query?.q).toBe('dassai');
    });
  });

  it('category filter sends category_slug=nihonshu', async () => {
    setupListResponse([sampleBeverage]);
    renderBeverages();
    await screen.findByText('Dassai 23');

    const categorySelect = screen
      .getAllByRole('combobox')
      .find((el) => (el as HTMLSelectElement).options[1]?.value === 'nihonshu');
    if (!categorySelect) throw new Error('category select not found');
    fireEvent.change(categorySelect, { target: { value: 'nihonshu' } });

    await waitFor(() => {
      const lastCall = apiGet.mock.calls.filter((c) => c[0] === '/v1/admin/beverages').pop();
      expect(lastCall?.[1]?.params?.query?.category_slug).toBe('nihonshu');
    });
  });

  it('edit flow PATCHes to /v1/admin/beverages/{id}', async () => {
    setupListResponse([sampleBeverage]);
    apiPatch.mockResolvedValueOnce({
      data: sampleBeverage,
      response: { status: 200 },
    });

    renderBeverages();
    fireEvent.click(await screen.findByRole('button', { name: 'Edit' }));

    const dialog = await screen.findByRole('dialog');
    // The initial state pre-selects the slug from the loaded beverage,
    // so the form is already submittable without any extra input.

    const submit = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submit) throw new Error('submit not found');
    fireEvent.click(submit);

    await waitFor(() => expect(apiPatch).toHaveBeenCalledTimes(1));
    const firstCall = apiPatch.mock.calls[0];
    if (!firstCall) throw new Error('apiPatch not called');
    const [path, init] = firstCall;
    expect(path).toBe('/v1/admin/beverages/{id}');
    expect(init.params.path.id).toBe(sampleBeverage.id);
    expect(init.body.producer_id).toBe(sampleProducer.id);
    expect(init.body.category_slug).toBe('nihonshu');
    expect(init.body.category_id).toBeUndefined();
  });

  it('soft-delete flow DELETEs to /v1/admin/beverages/{id}', async () => {
    setupListResponse([sampleBeverage]);
    apiDelete.mockResolvedValueOnce({ response: { status: 204 } });

    renderBeverages();
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
    expect(path).toBe('/v1/admin/beverages/{id}');
    expect(init.params.path.id).toBe(sampleBeverage.id);
  });

  it('restore flow POSTs to /v1/admin/beverages/{id}/restore', async () => {
    const deleted = { ...sampleBeverage, deleted_at: '2026-05-16T13:00:00Z' };
    setupListResponse([deleted]);
    apiPost.mockResolvedValueOnce({
      data: { ...deleted, deleted_at: null },
      response: { status: 200 },
    });

    renderBeverages();
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
    expect(path).toBe('/v1/admin/beverages/{id}/restore');
    expect(init.params.path.id).toBe(sampleBeverage.id);
  });
});
