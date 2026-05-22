import { api } from '@/lib/api';
import { logout as sessionLogout } from '@/lib/session';
import type { components } from '@/types/api';
import { useQuery } from '@tanstack/react-query';

export type Role = components['schemas']['UserRole'];
export type Me = components['schemas']['Me'];

export function useAuth() {
  const query = useQuery({
    queryKey: ['me'],
    queryFn: async (): Promise<Me> => {
      const { data, error } = await api.GET('/v1/users/me');
      if (error || !data) throw new Error('unauthorized');
      return data;
    },
    retry: false,
    staleTime: 30_000,
  });

  const me = query.data ?? null;
  const role: Role | null = me?.role ?? null;
  return {
    me,
    role,
    isAdmin: role === 'admin',
    isModerator: role === 'moderator' || role === 'admin',
    isLoading: query.isLoading,
    isError: query.isError,
    logout: async () => {
      await sessionLogout();
      if (typeof window !== 'undefined') window.location.assign('/login');
    },
  };
}
