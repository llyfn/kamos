import type { ReactNode } from 'react';
import { useAuth, type Role } from '@/lib/auth';
import { logout as sessionLogout } from '@/lib/session';

interface RoleGuardProps {
  requires: Role[];
  children: ReactNode;
  fallback?: ReactNode;
}

export function RoleGuard({ requires, children, fallback }: RoleGuardProps) {
  const { role, isLoading } = useAuth();
  if (isLoading) {
    return <div className="text-sm text-[color:var(--color-muted)]">Loading…</div>;
  }
  if (!role || !requires.includes(role)) {
    if (fallback !== undefined) return <>{fallback}</>;
    return <InsufficientPrivileges />;
  }
  return <>{children}</>;
}

// Shared "insufficient privileges" panel. Kept here so the copy lives in one
// place; once the admin client grows an i18n layer this is the only line to
// thread through it.
export function InsufficientPrivileges() {
  return (
    <div className="max-w-md mx-auto mt-12 border border-[color:var(--color-border)] bg-[color:var(--color-surface)] rounded p-6 text-sm">
      <h2 className="text-base font-semibold mb-2">Insufficient privileges</h2>
      <p className="text-[color:var(--color-muted)] mb-4">
        Insufficient privileges — admin or moderator role required.
      </p>
      <button
        type="button"
        onClick={() => {
          void sessionLogout().then(() => {
            if (typeof window !== 'undefined') window.location.assign('/login');
          });
        }}
        className="px-3 py-1 border border-[color:var(--color-border)] rounded"
      >
        Log out
      </button>
    </div>
  );
}
