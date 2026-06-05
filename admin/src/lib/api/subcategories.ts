// Subcategory admin API helpers. Slice C. Thin wrappers over the
// typed openapi-fetch client so the route components stay readable and
// share the CSRF + cookie pattern with the rest of the admin client.

import { api } from '@/lib/api';
import type { components } from '@/types/api';

export type AdminSubcategory = components['schemas']['AdminSubcategory'];
export type AdminSubcategoryCreate = components['schemas']['AdminSubcategoryCreate'];
export type AdminSubcategoryUpdate = components['schemas']['AdminSubcategoryUpdate'];
export type Subcategory = components['schemas']['Subcategory'];
export type CategorySlug = components['schemas']['CategoryLabel']['slug'];

export async function listAdminSubcategories(opts: {
  category?: CategorySlug | undefined;
  includeDeleted?: boolean | undefined;
}): Promise<AdminSubcategory[]> {
  const query: { category?: CategorySlug; include_deleted?: '0' | '1' } = {};
  if (opts.category) query.category = opts.category;
  if (opts.includeDeleted) query.include_deleted = '1';
  const { data, error } = await api.GET('/v1/admin/subcategories', { params: { query } });
  if (error || !data) throw new Error('list_subcategories_failed');
  return data;
}

export async function createSubcategory(body: AdminSubcategoryCreate): Promise<AdminSubcategory> {
  const { data, error, response } = await api.POST('/v1/admin/subcategories', { body });
  if (error || !data) throw new Error(`create_subcategory_failed_${response.status}`);
  return data;
}

export async function updateSubcategory(
  id: string,
  body: AdminSubcategoryUpdate,
): Promise<AdminSubcategory> {
  const { data, error, response } = await api.PATCH('/v1/admin/subcategories/{id}', {
    params: { path: { id } },
    body,
  });
  if (error || !data) throw new Error(`update_subcategory_failed_${response.status}`);
  return data;
}

export async function deleteSubcategory(id: string): Promise<void> {
  const { error, response } = await api.DELETE('/v1/admin/subcategories/{id}', {
    params: { path: { id } },
  });
  // 409 IN_USE bubbles up as a structured error; throw with the body so
  // the UI can render the explanation.
  if (response.status === 409) {
    const detail = (error as { error?: string } | null)?.error ?? 'subcategory in use';
    throw new Error(`409:${detail}`);
  }
  if (error || response.status !== 204) {
    throw new Error(`delete_subcategory_failed_${response.status}`);
  }
}

export async function restoreSubcategory(id: string): Promise<AdminSubcategory> {
  const { data, error, response } = await api.POST('/v1/admin/subcategories/{id}/restore', {
    params: { path: { id } },
  });
  if (error || !data) throw new Error(`restore_subcategory_failed_${response.status}`);
  return data;
}

// Public read — used by the subcategory picker on the beverage form so
// the dropdown stays in sync with admin edits without leaking
// soft-deleted rows.
export async function listPublicSubcategories(category?: CategorySlug): Promise<Subcategory[]> {
  const query: { category?: CategorySlug } = {};
  if (category) query.category = category;
  const { data, error } = await api.GET('/v1/subcategories', { params: { query } });
  if (error || !data) throw new Error('list_public_subcategories_failed');
  return data;
}
