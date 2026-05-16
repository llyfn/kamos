import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ToastProvider } from '@/components/toast';

const apiGet = vi.fn();
const apiPost = vi.fn();
vi.mock('@/lib/api', () => ({
  api: {
    GET: (...args: unknown[]) => apiGet(...args),
    POST: (...args: unknown[]) => apiPost(...args),
  },
  ForbiddenError: class extends Error {},
}));

// The route file uses createFileRoute which needs to register against the
// router; in tests we render the component directly.
import { Route } from './queue';

function renderQueue() {
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

describe('/queue', () => {
  it('renders rows from the API response', async () => {
    apiGet.mockResolvedValueOnce({
      data: {
        items: [
          {
            id: '11111111-1111-1111-1111-111111111111',
            username: 'submitter_one',
            payload: { name_en: 'Test Sake' },
            status: 'pending',
            created_at: '2026-05-16T12:00:00Z',
          },
          {
            id: '22222222-2222-2222-2222-222222222222',
            username: 'submitter_two',
            payload: { name_en: 'Another' },
            status: 'pending',
            created_at: '2026-05-16T13:00:00Z',
          },
        ],
        next_cursor: null,
        has_more: false,
      },
    });

    renderQueue();

    expect(await screen.findByText('submitter_one')).toBeInTheDocument();
    expect(screen.getByText('submitter_two')).toBeInTheDocument();
    // Two Approve buttons (one per row).
    expect(screen.getAllByRole('button', { name: 'Approve' })).toHaveLength(2);
    await waitFor(() => expect(apiGet).toHaveBeenCalledTimes(1));
    const firstCall = apiGet.mock.calls[0];
    expect(firstCall?.[0]).toBe('/v1/admin/beverage-requests');
  });

  it('shows an empty state with no items', async () => {
    apiGet.mockResolvedValueOnce({
      data: { items: [], next_cursor: null, has_more: false },
    });
    renderQueue();
    expect(await screen.findByText('No pending requests.')).toBeInTheDocument();
  });
});
