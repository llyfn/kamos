// Flavor tag admin API helpers. Thin wrappers around the typed
// openapi-fetch client.

import { api } from '@/lib/api';
import type { components } from '@/types/api';

export type AdminFlavorTag = components['schemas']['AdminFlavorTag'];
export type AdminFlavorTagCreate = components['schemas']['AdminFlavorTagCreate'];
export type AdminFlavorTagUpdate = components['schemas']['AdminFlavorTagUpdate'];
export type FlavorDimension = AdminFlavorTagCreate['dimension'];

export async function listAdminFlavorTags(opts: {
  dimension?: FlavorDimension | undefined;
  includeDeleted?: boolean | undefined;
}): Promise<AdminFlavorTag[]> {
  const query: { dimension?: FlavorDimension; include_deleted?: '0' | '1' } = {};
  if (opts.dimension) query.dimension = opts.dimension;
  if (opts.includeDeleted) query.include_deleted = '1';
  const { data, error } = await api.GET('/v1/admin/flavor-tags', { params: { query } });
  if (error || !data) throw new Error('list_flavor_tags_failed');
  return data;
}

export async function createFlavorTag(body: AdminFlavorTagCreate): Promise<AdminFlavorTag> {
  const { data, error, response } = await api.POST('/v1/admin/flavor-tags', { body });
  if (error || !data) throw new Error(`create_flavor_tag_failed_${response.status}`);
  return data;
}

export async function updateFlavorTag(
  id: string,
  body: AdminFlavorTagUpdate,
): Promise<AdminFlavorTag> {
  const { data, error, response } = await api.PATCH('/v1/admin/flavor-tags/{id}', {
    params: { path: { id } },
    body,
  });
  if (error || !data) throw new Error(`update_flavor_tag_failed_${response.status}`);
  return data;
}

export async function deleteFlavorTag(id: string): Promise<void> {
  const { error, response } = await api.DELETE('/v1/admin/flavor-tags/{id}', {
    params: { path: { id } },
  });
  if (response.status === 409) {
    const detail = (error as { error?: string } | null)?.error ?? 'flavor tag in use';
    throw new Error(`409:${detail}`);
  }
  if (error || response.status !== 204) {
    throw new Error(`delete_flavor_tag_failed_${response.status}`);
  }
}

export async function restoreFlavorTag(id: string): Promise<AdminFlavorTag> {
  const { data, error, response } = await api.POST('/v1/admin/flavor-tags/{id}/restore', {
    params: { path: { id } },
  });
  if (error || !data) throw new Error(`restore_flavor_tag_failed_${response.status}`);
  return data;
}
