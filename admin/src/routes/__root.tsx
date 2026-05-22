import type { QueryClient } from '@tanstack/react-query';
import { createRootRouteWithContext, Link, Outlet } from '@tanstack/react-router';
import { ToastProvider } from '@/components/toast';
import { useAuth } from '@/lib/auth';

interface RouterContext {
  queryClient: QueryClient;
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootLayout,
});

function RootLayout() {
  // Stage 4 — auth state lives in HttpOnly cookies, so we derive the
  // "logged in" flag from the /v1/users/me query rather than reading
  // localStorage. The query loading state collapses to "not logged in"
  // for the header rendering — the only consequence is a brief blank-
  // nav flash on first paint, which is fine for an admin tool.
  const { me, logout } = useAuth();
  const loggedIn = me !== null;
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
                  <Link
                    to="/moderation-log"
                    className="hover:underline"
                    activeProps={{ className: 'underline' }}
                  >
                    Audit
                  </Link>
                  <button
                    type="button"
                    onClick={() => {
                      void logout();
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
