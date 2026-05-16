import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

const apiGet = vi.fn();
vi.mock('@/lib/api', () => ({
  api: {
    GET: (...args: unknown[]) => apiGet(...args),
  },
}));

import { RoleGuard } from './guard';

function renderGuard(requires: Array<'admin' | 'moderator' | 'user'>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}>
      <RoleGuard requires={requires}>
        <div>protected child</div>
      </RoleGuard>
    </QueryClientProvider>,
  );
}

describe('<RoleGuard />', () => {
  it('renders children when the role matches', async () => {
    apiGet.mockResolvedValueOnce({ data: { role: 'admin' } });
    renderGuard(['admin', 'moderator']);
    expect(await screen.findByText('protected child')).toBeInTheDocument();
  });

  it('renders the insufficient-privileges panel when the role does not match', async () => {
    apiGet.mockResolvedValueOnce({ data: { role: 'user' } });
    renderGuard(['admin', 'moderator']);
    expect(await screen.findByText('Insufficient privileges')).toBeInTheDocument();
    expect(
      screen.getByText(/admin or moderator role required/i),
    ).toBeInTheDocument();
    expect(screen.queryByText('protected child')).not.toBeInTheDocument();
  });

  it('renders a loading state while the auth query is pending', () => {
    // Never-resolving promise keeps useQuery in the loading state.
    apiGet.mockReturnValueOnce(new Promise(() => {}));
    renderGuard(['admin', 'moderator']);
    expect(screen.getByText('Loading…')).toBeInTheDocument();
    expect(screen.queryByText('protected child')).not.toBeInTheDocument();
  });
});
