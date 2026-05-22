import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
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

import { Route } from './comments';

function renderComments() {
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

interface CommentFixture {
  id: string;
  check_in_id: string;
  body: string;
  user: { display_username: string };
  created_at: string;
  deleted_at?: string | null;
}

function setupApi(opts: {
  me?: { role: 'admin' | 'moderator' | 'user' };
  comments: { items: CommentFixture[]; next_cursor: string | null; has_more: boolean };
}) {
  apiGet.mockImplementation((path: string) => {
    if (path === '/v1/users/me') {
      return Promise.resolve({ data: { role: opts.me?.role ?? 'admin' } });
    }
    if (path === '/v1/admin/comments') {
      return Promise.resolve({ data: opts.comments });
    }
    return Promise.resolve({ error: { error: 'not_mocked', code: 'NOT_MOCKED' } });
  });
}

describe('/comments', () => {
  it('renders rows from the API response', async () => {
    setupApi({
      comments: {
        items: [
          {
            id: '11111111-1111-1111-1111-111111111111',
            check_in_id: 'aaaaaaaa-1111-1111-1111-111111111111',
            user: { display_username: 'alice' },
            body: 'great drink',
            created_at: '2026-05-16T12:00:00Z',
            deleted_at: null,
          },
          {
            id: '22222222-2222-2222-2222-222222222222',
            check_in_id: 'bbbbbbbb-2222-2222-2222-222222222222',
            user: { display_username: 'bob' },
            body: 'agreed',
            created_at: '2026-05-16T13:00:00Z',
            deleted_at: null,
          },
        ],
        next_cursor: null,
        has_more: false,
      },
    });

    renderComments();

    expect(await screen.findByText('alice')).toBeInTheDocument();
    expect(screen.getByText('bob')).toBeInTheDocument();
    expect(screen.getByText('great drink')).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: 'Soft delete' })).toHaveLength(2);
    await waitFor(() =>
      expect(apiGet.mock.calls.some((c) => c[0] === '/v1/admin/comments')).toBe(true),
    );
  });

  it('renders an empty state when no comments', async () => {
    setupApi({ comments: { items: [], next_cursor: null, has_more: false } });
    renderComments();
    expect(await screen.findByText('No comments.')).toBeInTheDocument();
  });

  it('moderate modal POSTs notes to the moderate endpoint', async () => {
    setupApi({
      comments: {
        items: [
          {
            id: '11111111-1111-1111-1111-111111111111',
            check_in_id: 'aaaaaaaa-1111-1111-1111-111111111111',
            user: { display_username: 'alice' },
            body: 'spammy comment',
            created_at: '2026-05-16T12:00:00Z',
            deleted_at: null,
          },
        ],
        next_cursor: null,
        has_more: false,
      },
    });
    apiPost.mockResolvedValueOnce({ response: { status: 204 } });

    renderComments();

    const openBtn = await screen.findByRole('button', { name: 'Soft delete' });
    fireEvent.click(openBtn);

    const textarea = await screen.findByRole('textbox');
    fireEvent.change(textarea, { target: { value: 'off-topic spam' } });

    // The modal's own submit button — the table row button has the same label
    // but is disabled-style; we click the submit button inside the dialog.
    const dialog = screen.getByRole('dialog');
    const submitBtn = Array.from(dialog.querySelectorAll('button')).find(
      (b) => b.getAttribute('type') === 'submit',
    );
    if (!submitBtn) throw new Error('submit button not found');
    fireEvent.click(submitBtn);

    await waitFor(() => expect(apiPost).toHaveBeenCalledTimes(1));
    const firstCall = apiPost.mock.calls[0];
    if (!firstCall) throw new Error('apiPost was not called');
    const [path, init] = firstCall;
    expect(path).toBe('/v1/admin/comments/{id}/moderate');
    expect(init.params.path.id).toBe('11111111-1111-1111-1111-111111111111');
    expect(init.body).toEqual({ notes: 'off-topic spam' });
  });
});
