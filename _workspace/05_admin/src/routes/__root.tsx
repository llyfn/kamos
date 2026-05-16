import { ToastProvider } from '@/components/toast';
import { clearTokens, getAccessToken } from '@/lib/tokens';
import type { QueryClient } from '@tanstack/react-query';
import { Link, Outlet, createRootRouteWithContext } from '@tanstack/react-router';

interface RouterContext {
  queryClient: QueryClient;
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootLayout,
});

function RootLayout() {
  const loggedIn = getAccessToken() !== null;
  return (
    <ToastProvider>
      <div className="min-h-full flex flex-col">
        <header className="border-b border-[color:var(--color-border)] bg-[color:var(--color-surface)]">
          <div className="mx-auto max-w-6xl px-6 py-3 flex items-center justify-between">
            <Link to="/" className="font-semibold tracking-tight text-[color:var(--color-accent)]">
              KAMOS Admin
            </Link>
            <nav className="flex items-center gap-4 text-sm">
              {loggedIn && (
                <>
                  <Link
                    to="/queue"
                    className="hover:underline"
                    activeProps={{ className: 'underline' }}
                  >
                    Queue
                  </Link>
                  <Link
                    to="/users"
                    className="hover:underline"
                    activeProps={{ className: 'underline' }}
                  >
                    Users
                  </Link>
                  <Link
                    to="/checkins"
                    className="hover:underline"
                    activeProps={{ className: 'underline' }}
                  >
                    Check-ins
                  </Link>
                  <Link
                    to="/comments"
                    className="hover:underline"
                    activeProps={{ className: 'underline' }}
                  >
                    Comments
                  </Link>
                  <button
                    type="button"
                    onClick={() => {
                      clearTokens();
                      window.location.assign('/login');
                    }}
                    className="text-[color:var(--color-muted)] hover:text-[color:var(--color-fg)]"
                  >
                    Log out
                  </button>
                </>
              )}
              {!loggedIn && (
                <Link to="/login" className="hover:underline">
                  Log in
                </Link>
              )}
            </nav>
          </div>
        </header>
        <main className="flex-1">
          <div className="mx-auto max-w-6xl px-6 py-6">
            <Outlet />
          </div>
        </main>
      </div>
    </ToastProvider>
  );
}
