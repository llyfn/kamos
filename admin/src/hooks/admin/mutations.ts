// KAMOS admin — Typed TanStack Query mutations for moderation actions.
//
// Each hook wraps one admin endpoint, invalidates the relevant query
// caches on success, and exposes a small `useXxx()` surface so the route
// files stay focused on layout. The hooks deliberately stay close to the
// raw openapi-fetch shape — no business logic, just an error->Error
// adapter, success-side invalidation, and a uniform error message format.

import { api } from '@/lib/api';
import type { components } from '@/types/api';
import { useMutation, useQueryClient } from '@tanstack/react-query';

type Approval = components['schemas']['AdminBeverageRequestApproval'];
type Role = components['schemas']['UserRole'];

/// POST /v1/admin/beverage-requests/{id}/approve
export function useApproveBeverageRequest(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: Approval) => {
      const { data, error, response } = await api.POST('/v1/admin/beverage-requests/{id}/approve', {
        params: { path: { id } },
        body,
      });
      if (error || !data) throw new Error(`approve_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'beverage-requests'] });
    },
  });
}

/// POST /v1/admin/beverage-requests/{id}/reject
export function useRejectBeverageRequest(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (notes: string) => {
      const { data, error, response } = await api.POST('/v1/admin/beverage-requests/{id}/reject', {
        params: { path: { id } },
        body: { notes },
      });
      if (error || !data) throw new Error(`reject_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'beverage-requests'] });
    },
  });
}

/// POST /v1/admin/check-ins/{id}/moderate
export function useModerateCheckin(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (notes: string | null) => {
      const body = notes?.trim() ? { notes: notes.trim() } : undefined;
      const init = body ? { body } : {};
      const { error, response } = await api.POST('/v1/admin/check-ins/{id}/moderate', {
        params: { path: { id } },
        ...init,
      });
      if (error || response.status !== 204) {
        throw new Error(`moderate_failed_${response.status}`);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'check-ins'] });
    },
  });
}

/// POST /v1/admin/comments/{id}/moderate
export function useModerateComment(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (notes: string | null) => {
      const body = notes?.trim() ? { notes: notes.trim() } : undefined;
      const init = body ? { body } : {};
      const { error, response } = await api.POST('/v1/admin/comments/{id}/moderate', {
        params: { path: { id } },
        ...init,
      });
      if (error || response.status !== 204) {
        throw new Error(`moderate_failed_${response.status}`);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'comments'] });
    },
  });
}

/// POST /v1/admin/users/{id}/suspend
export function useSuspendUser(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async () => {
      const { error, response } = await api.POST('/v1/admin/users/{id}/suspend', {
        params: { path: { id } },
      });
      if (error || response.status !== 204) {
        throw new Error(`suspend_failed_${response.status}`);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'users'] });
    },
  });
}

/// POST /v1/admin/users/{id}/role
export function useUpdateUserRole(id: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (role: Role) => {
      const { data, error, response } = await api.POST('/v1/admin/users/{id}/role', {
        params: { path: { id } },
        body: { role },
      });
      if (error || !data) throw new Error(`role_update_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'users'] });
    },
  });
}
