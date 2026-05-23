import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
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

import { Route } from './users';

function renderUsers() {
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

interface UserFixture {
  id: string;
  username: string;
  display_username: string;
  email: string;
  role: 'user' | 'moderator' | 'admin';
  created_at: string;
  deleted_at: string | null;
}

const sampleUser: UserFixture = {
  id: '11111111-1111-1111-1111-111111111111',
  username: 'alice',
  display_username: 'Alice',
  email: 'alice@example.com',
  role: 'user',
  created_at: '2026-05-16T12:00:00Z',
  deleted_at: null,
};

function setupApi(opts: { items?: UserFixture[]; meRole?: 'admin' | 'moderator' } = {}) {
  apiGet.mockImplementation((path: string) => {
    if (path === '/v1/admin/me') {
      return Promise.resolve({ data: { role: opts.meRole ?? 'admin' } });
    }
    if (path === '/v1/admin/users') {
      return Promise.resolve({
        data: {
          items: opts.items ?? [sampleUser],
          next_cursor: null,
          has_more: false,
        },
      });
    }
    return Promise.resolve({ error: { error: 'not_mocked', code: 'NOT_MOCKED' } });
  });
}

describe('/users', () => {
  beforeEach(() => {
    apiGet.mockReset();
    apiPost.mockReset();
  });

  it('renders rows from the API response', async () => {
    setupApi();
    renderUsers();
    expect(await screen.findByText('Alice')).toBeInTheDocument();
    expect(screen.getByText('alice@example.com')).toBeInTheDocument();
  });

  it('Apply triggers refetch with the three exact-match params', async () => {
    setupApi();
    renderUsers();
    await screen.findByText('Alice');

    // There are two case-insensitive inputs (username + email) — they
    // share the placeholder. Grab both and index by DOM order.
    const exactInputs = screen.getAllByPlaceholderText('case-insensitive');
    fireEvent.change(exactInputs[0] as HTMLInputElement, { target: { value: 'Alice' } });
    fireEvent.change(exactInputs[1] as HTMLInputElement, {
      target: { value: 'ALICE@example.com' },
    });
    const uuid = screen.getByPlaceholderText('user uuid');
    fireEvent.change(uuid, { target: { value: '22222222-2222-2222-2222-222222222222' } });

    fireEvent.click(screen.getByRole('button', { name: 'Apply' }));

    await waitFor(() => {
      const lastCall = apiGet.mock.calls.filter((c) => c[0] === '/v1/admin/users').pop();
      const q = lastCall?.[1]?.params?.query;
      expect(q?.username).toBe('Alice');
      expect(q?.email).toBe('ALICE@example.com');
      expect(q?.id).toBe('22222222-2222-2222-2222-222222222222');
    });
  });

  it('Reset clears all exact-match filters', async () => {
    setupApi();
    renderUsers();
    await screen.findByText('Alice');

    const exactInputs = screen.getAllByPlaceholderText('case-insensitive');
    fireEvent.change(exactInputs[0] as HTMLInputElement, { target: { value: 'Alice' } });
    fireEvent.click(screen.getByRole('button', { name: 'Apply' }));
    await waitFor(() => {
      const last = apiGet.mock.calls.filter((c) => c[0] === '/v1/admin/users').pop();
      expect(last?.[1]?.params?.query?.username).toBe('Alice');
    });

    fireEvent.click(screen.getByRole('button', { name: 'Reset' }));
    await waitFor(() => {
      const last = apiGet.mock.calls.filter((c) => c[0] === '/v1/admin/users').pop();
      expect(last?.[1]?.params?.query?.username).toBeUndefined();
      expect(last?.[1]?.params?.query?.email).toBeUndefined();
      expect(last?.[1]?.params?.query?.id).toBeUndefined();
    });
  });

  it('hides cursor pager when an exact filter is active', async () => {
    apiGet.mockImplementation((path: string) => {
      if (path === '/v1/admin/me') return Promise.resolve({ data: { role: 'admin' } });
      if (path === '/v1/admin/users') {
        return Promise.resolve({
          data: { items: [sampleUser], next_cursor: 'next', has_more: true },
        });
      }
      return Promise.resolve({ error: { error: 'not_mocked', code: 'NOT_MOCKED' } });
    });
    renderUsers();
    await screen.findByText('Alice');

    // Pager Next button is enabled when no exact filter is set.
    expect(screen.getByRole('button', { name: /Next/ })).toBeEnabled();

    const exactInputs = screen.getAllByPlaceholderText('case-insensitive');
    fireEvent.change(exactInputs[0] as HTMLInputElement, { target: { value: 'alice' } });
    fireEvent.click(screen.getByRole('button', { name: 'Apply' }));

    await waitFor(() => {
      expect(screen.getByRole('button', { name: /Next/ })).toBeDisabled();
    });
  });
});
