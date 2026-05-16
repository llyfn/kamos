import type { ReactNode } from 'react';
import { useAuth, type Role } from '@/lib/auth';

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
    throw new Error('insufficient_role');
  }
  return <>{children}</>;
}
