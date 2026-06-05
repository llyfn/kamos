// /subcategories — admin CRUD page for beverage_subcategories.
//
// Slice C. Mirrors the existing /beverages and /producers pages: list
// table with inline edit + soft-delete / restore actions, a header
// "New subcategory" button that opens the create dialog, and an
// include-deleted toggle. Soft-delete surfaces the 409 IN_USE response
// when the row is still attached to live beverages.

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { RoleGuard } from '@/components/guard';
import { Modal } from '@/components/modal';
import { useToast } from '@/components/toast';
import {
  type AdminSubcategory,
  type AdminSubcategoryCreate,
  type AdminSubcategoryUpdate,
  type CategorySlug,
  createSubcategory,
  deleteSubcategory,
  listAdminSubcategories,
  restoreSubcategory,
  updateSubcategory,
} from '@/lib/api/subcategories';

export const Route = createFileRoute('/subcategories')({
  component: GuardedPage,
});

function GuardedPage() {
  return (
    <RoleGuard requires={['admin']}>
      <SubcategoriesPage />
    </RoleGuard>
  );
}

function SubcategoriesPage() {
  const toast = useToast();
  const [categoryFilter, setCategoryFilter] = useState<CategorySlug | ''>('');
  const [includeDeleted, setIncludeDeleted] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);

  const query = useQuery({
    queryKey: ['admin', 'subcategories', categoryFilter, includeDeleted],
    queryFn: () =>
      listAdminSubcategories({
        category: categoryFilter || undefined,
        includeDeleted,
      }),
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold">Subcategories</h1>
        <button
          type="button"
          onClick={() => setCreateOpen(true)}
          className="px-3 py-1 bg-[color:var(--color-accent)] text-white rounded text-sm"
        >
          New subcategory
        </button>
      </div>

      <div className="flex flex-wrap gap-3 items-end text-sm mb-3 border border-[color:var(--color-border)] rounded bg-[color:var(--color-surface)] p-3">
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Category</span>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value as CategorySlug | '')}
            className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)]"
          >
            <option value="">(any)</option>
            <option value="nihonshu">Nihonshu (Sake)</option>
            <option value="shochu">Shochu</option>
            <option value="liqueur">Liqueur</option>
          </select>
        </label>
        <label className="flex items-center gap-1">
          <input
            type="checkbox"
            checked={includeDeleted}
            onChange={(e) => setIncludeDeleted(e.target.checked)}
          />
          <span>include deleted</span>
        </label>
      </div>

      {query.isLoading && <p className="text-sm text-[color:var(--color-muted)]">Loading…</p>}
      {query.isError && <p className="text-sm text-red-700">Failed to load subcategories.</p>}
      {query.data && (
        <table className="w-full text-sm border border-[color:var(--color-border)]">
          <thead>
            <tr className="bg-[color:var(--color-surface)] text-left">
              <th className="p-2">Category</th>
              <th className="p-2">Slug</th>
              <th className="p-2">Name (EN)</th>
              <th className="p-2">Sort</th>
              <th className="p-2">In use</th>
              <th className="p-2">Status</th>
              <th className="p-2 text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {query.data.length === 0 && (
              <tr>
                <td colSpan={7} className="p-3 text-center text-[color:var(--color-muted)]">
                  No subcategories.
                </td>
              </tr>
            )}
            {query.data.map((row) => (
              <Row key={row.id} row={row} onDeleted={(name) => toast.push(`Deleted ${name}`)} />
            ))}
          </tbody>
        </table>
      )}

      {createOpen && (
        <CreateDialog
          onClose={() => setCreateOpen(false)}
          onCreated={() => {
            toast.push('Subcategory created');
            setCreateOpen(false);
          }}
        />
      )}
    </div>
  );
}

function Row({ row, onDeleted }: { row: AdminSubcategory; onDeleted: (name: string) => void }) {
  const [modal, setModal] = useState<'edit' | 'delete' | 'restore' | null>(null);
  const isDeleted = row.deleted_at != null;
  return (
    <>
      <tr className="border-t border-[color:var(--color-border)]">
        <td className="p-2">{row.category_slug}</td>
        <td className="p-2 font-mono text-xs">{row.slug}</td>
        <td className="p-2">{row.name.en}</td>
        <td className="p-2">{row.sort_order}</td>
        <td className="p-2">{row.beverage_count}</td>
        <td className="p-2">
          {isDeleted ? (
            <span className="px-2 py-0.5 rounded text-xs bg-red-100 text-red-800">deleted</span>
          ) : (
            <span className="px-2 py-0.5 rounded text-xs bg-emerald-100 text-emerald-800">
              live
            </span>
          )}
        </td>
        <td className="p-2 text-right whitespace-nowrap">
          <button
            type="button"
            onClick={() => setModal('edit')}
            className="px-2 py-1 border border-[color:var(--color-border)] rounded text-xs mr-1"
          >
            Edit
          </button>
          {isDeleted ? (
            <button
              type="button"
              onClick={() => setModal('restore')}
              className="px-2 py-1 bg-emerald-700 text-white rounded text-xs"
            >
              Restore
            </button>
          ) : (
            <button
              type="button"
              onClick={() => setModal('delete')}
              className="px-2 py-1 bg-red-700 text-white rounded text-xs"
            >
              Delete
            </button>
          )}
        </td>
      </tr>
      {modal === 'edit' && <EditDialog row={row} onClose={() => setModal(null)} />}
      {modal === 'delete' && (
        <DeleteDialog
          row={row}
          onClose={() => setModal(null)}
          onDeleted={() => onDeleted(row.name.en)}
        />
      )}
      {modal === 'restore' && <RestoreDialog row={row} onClose={() => setModal(null)} />}
    </>
  );
}

function CreateDialog({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const qc = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: (body: AdminSubcategoryCreate) => createSubcategory(body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'subcategories'] });
      qc.invalidateQueries({ queryKey: ['public', 'subcategories'] });
      onCreated();
    },
    onError: (e: Error) => setError(e.message),
  });
  return (
    <Modal open onClose={onClose} title="New subcategory">
      <SubcategoryForm
        submitting={mut.isPending}
        submitLabel="Create"
        errorMessage={error}
        onSubmit={(body) => mut.mutate(body as AdminSubcategoryCreate)}
        onCancel={onClose}
      />
    </Modal>
  );
}

function EditDialog({ row, onClose }: { row: AdminSubcategory; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: (body: AdminSubcategoryUpdate) => updateSubcategory(row.id, body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'subcategories'] });
      qc.invalidateQueries({ queryKey: ['public', 'subcategories'] });
      toast.push('Subcategory updated');
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });
  return (
    <Modal open onClose={onClose} title={`Edit subcategory — ${row.name.en}`}>
      <SubcategoryForm
        initial={row}
        submitting={mut.isPending}
        submitLabel="Save"
        errorMessage={error}
        onSubmit={(body) =>
          mut.mutate({
            slug: body.slug,
            name_i18n: body.name_i18n,
            sort_order: body.sort_order,
          })
        }
        onCancel={onClose}
      />
    </Modal>
  );
}

function DeleteDialog({
  row,
  onClose,
  onDeleted,
}: {
  row: AdminSubcategory;
  onClose: () => void;
  onDeleted: () => void;
}) {
  const qc = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: () => deleteSubcategory(row.id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'subcategories'] });
      qc.invalidateQueries({ queryKey: ['public', 'subcategories'] });
      onDeleted();
      onClose();
    },
    onError: (e: Error) => {
      // 409:<message> surfaces the IN_USE explanation; keep it visible
      // alongside the count.
      setError(e.message);
    },
  });
  function onConfirm(e: FormEvent) {
    e.preventDefault();
    setError(null);
    mut.mutate();
  }
  return (
    <Modal open onClose={onClose} title={`Delete subcategory — ${row.name.en}?`}>
      <form onSubmit={onConfirm}>
        <p className="text-sm mb-3">
          Soft-deletes the subcategory. Live beverages must be detached first; the request will fail
          with <code className="font-mono">IN_USE</code> otherwise.
        </p>
        {row.beverage_count > 0 && (
          <p className="text-xs text-red-700 mb-2">
            Currently used by <strong>{row.beverage_count}</strong> live beverage(s).
          </p>
        )}
        {error && <p className="text-red-700 text-xs mb-2">{error}</p>}
        <div className="flex justify-end gap-2">
          <button
            type="button"
            onClick={onClose}
            className="px-3 py-1 border border-[color:var(--color-border)] rounded text-sm"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={mut.isPending}
            className="px-3 py-1 bg-red-700 text-white rounded text-sm disabled:opacity-50"
          >
            {mut.isPending ? 'Deleting…' : 'Delete'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function RestoreDialog({ row, onClose }: { row: AdminSubcategory; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: () => restoreSubcategory(row.id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'subcategories'] });
      qc.invalidateQueries({ queryKey: ['public', 'subcategories'] });
      toast.push(`Restored ${row.name.en}`);
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });
  function onConfirm(e: FormEvent) {
    e.preventDefault();
    setError(null);
    mut.mutate();
  }
  return (
    <Modal open onClose={onClose} title={`Restore ${row.name.en}?`}>
      <form onSubmit={onConfirm}>
        <p className="text-sm mb-3">
          Clears <code className="font-mono">deleted_at</code>; the subcategory reappears in the
          public list.
        </p>
        {error && <p className="text-red-700 text-xs mb-2">{error}</p>}
        <div className="flex justify-end gap-2">
          <button
            type="button"
            onClick={onClose}
            className="px-3 py-1 border border-[color:var(--color-border)] rounded text-sm"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={mut.isPending}
            className="px-3 py-1 bg-emerald-700 text-white rounded text-sm disabled:opacity-50"
          >
            {mut.isPending ? 'Restoring…' : 'Restore'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

// ---- inline form ----

interface SubcategoryFormProps {
  initial?: AdminSubcategory | null;
  submitting?: boolean;
  submitLabel?: string;
  errorMessage?: string | null;
  onSubmit: (body: AdminSubcategoryCreate) => void;
  onCancel: () => void;
}

function SubcategoryForm({
  initial,
  submitting,
  submitLabel = 'Save',
  errorMessage,
  onSubmit,
  onCancel,
}: SubcategoryFormProps) {
  const [categorySlug, setCategorySlug] = useState<CategorySlug | ''>(initial?.category_slug ?? '');
  const [slug, setSlug] = useState(initial?.slug ?? '');
  const [nameEn, setNameEn] = useState(initial?.name.en ?? '');
  const [nameJa, setNameJa] = useState(initial?.name.ja ?? '');
  const [nameKo, setNameKo] = useState(initial?.name.ko ?? '');
  const [sortOrder, setSortOrder] = useState(String(initial?.sort_order ?? 0));
  const [localError, setLocalError] = useState<string | null>(null);

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLocalError(null);
    if (!categorySlug) {
      setLocalError('Category is required.');
      return;
    }
    if (!/^[a-z0-9_]{1,64}$/.test(slug)) {
      setLocalError('Slug must match [a-z0-9_]{1,64}.');
      return;
    }
    if (!nameEn || !nameJa || !nameKo) {
      setLocalError('All three locale names are required.');
      return;
    }
    const sort = Number.parseInt(sortOrder, 10);
    if (!Number.isInteger(sort)) {
      setLocalError('Sort order must be an integer.');
      return;
    }
    onSubmit({
      category_slug: categorySlug,
      slug,
      name_i18n: { en: nameEn, ja: nameJa, ko: nameKo },
      sort_order: sort,
    });
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3 text-sm">
      <label className="flex flex-col gap-1">
        <span className="text-[color:var(--color-muted)]">Category *</span>
        <select
          value={categorySlug}
          onChange={(e) => setCategorySlug(e.target.value as CategorySlug | '')}
          disabled={!!initial}
          required
          className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)] disabled:opacity-50"
        >
          <option value="">(select)</option>
          <option value="nihonshu">Nihonshu (Sake)</option>
          <option value="shochu">Shochu</option>
          <option value="liqueur">Liqueur</option>
        </select>
        {initial && (
          <span className="text-xs text-[color:var(--color-muted)]">
            Category can't be changed after creation. Delete + recreate to move.
          </span>
        )}
      </label>

      <label className="flex flex-col gap-1">
        <span className="text-[color:var(--color-muted)]">Slug * (lowercase, alnum, _)</span>
        <input
          type="text"
          value={slug}
          onChange={(e) => setSlug(e.target.value.toLowerCase())}
          maxLength={64}
          required
          pattern="^[a-z0-9_]{1,64}$"
          className="border border-[color:var(--color-border)] rounded px-2 py-1 font-mono"
        />
      </label>

      <fieldset className="flex flex-col gap-2 border border-[color:var(--color-border)] rounded p-3">
        <legend className="px-1 text-[color:var(--color-muted)]">Name (all three required)</legend>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">English *</span>
          <input
            type="text"
            value={nameEn}
            onChange={(e) => setNameEn(e.target.value)}
            maxLength={200}
            required
            className="border border-[color:var(--color-border)] rounded px-2 py-1"
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Japanese *</span>
          <input
            type="text"
            value={nameJa}
            onChange={(e) => setNameJa(e.target.value)}
            maxLength={200}
            required
            className="border border-[color:var(--color-border)] rounded px-2 py-1"
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Korean *</span>
          <input
            type="text"
            value={nameKo}
            onChange={(e) => setNameKo(e.target.value)}
            maxLength={200}
            required
            className="border border-[color:var(--color-border)] rounded px-2 py-1"
          />
        </label>
      </fieldset>

      <label className="flex flex-col gap-1">
        <span className="text-[color:var(--color-muted)]">Sort order (lower = first)</span>
        <input
          type="number"
          value={sortOrder}
          onChange={(e) => setSortOrder(e.target.value)}
          className="border border-[color:var(--color-border)] rounded px-2 py-1 w-24"
        />
      </label>

      {(localError || errorMessage) && (
        <p className="text-red-700 text-xs">{localError ?? errorMessage}</p>
      )}
      <div className="flex justify-end gap-2 mt-2">
        <button
          type="button"
          onClick={onCancel}
          className="px-3 py-1 border border-[color:var(--color-border)] rounded"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={submitting}
          className="px-3 py-1 bg-[color:var(--color-accent)] text-white rounded disabled:opacity-50"
        >
          {submitting ? 'Saving…' : submitLabel}
        </button>
      </div>
    </form>
  );
}
