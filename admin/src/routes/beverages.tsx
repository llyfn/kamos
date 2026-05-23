// /beverages — admin catalog CRUD page for beverages.
//
// Filters: debounced FTS `q`, brewery typeahead (BreweryPicker),
// category dropdown (slug), UUID exact `id`, `include_deleted` checkbox.
// Header: "New beverage" opens the CatalogBeverageForm in create mode.
// Per-row: Edit, Soft-delete / Restore (confirm modal).

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { BreweryPicker, type BreweryPickerValue, preferredName } from '@/components/BreweryPicker';
import { CatalogBeverageForm } from '@/components/CatalogBeverageForm';
import { RoleGuard } from '@/components/guard';
import { Modal } from '@/components/modal';
import { QueueTable, type QueueTableColumn } from '@/components/QueueTable';
import { useToast } from '@/components/toast';
import { api } from '@/lib/api';
import { useDebounced } from '@/lib/use-debounced';
import type { components } from '@/types/api';

type AdminBeverage = components['schemas']['AdminBeverage'];
type CreateBody = components['schemas']['AdminBeverageCreate'];
type UpdateBody = components['schemas']['AdminBeverageUpdate'];
type CategorySlug = components['schemas']['CategoryLabel']['slug'];

export const Route = createFileRoute('/beverages')({
  component: GuardedBeveragesPage,
});

const COLUMNS: QueueTableColumn[] = [
  { key: 'id', label: 'ID' },
  { key: 'name', label: 'Name' },
  { key: 'brewery', label: 'Brewery' },
  { key: 'category', label: 'Category' },
  { key: 'abv', label: 'ABV' },
  { key: 'deleted', label: 'Status' },
  { key: 'actions', label: 'Actions', className: 'text-right' },
];

function GuardedBeveragesPage() {
  return (
    <RoleGuard requires={['admin']}>
      <BeveragesPage />
    </RoleGuard>
  );
}

function BeveragesPage() {
  const toast = useToast();
  const [cursor, setCursor] = useState<string | null>(null);
  const [qInput, setQInput] = useState('');
  const [breweryFilter, setBreweryFilter] = useState<BreweryPickerValue | null>(null);
  const [categoryFilter, setCategoryFilter] = useState<CategorySlug | ''>('');
  const [idExact, setIdExact] = useState('');
  const [includeDeleted, setIncludeDeleted] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);

  const debouncedQ = useDebounced(qInput.trim(), 300);
  const idTrim = idExact.trim();

  const { data, isLoading, isError } = useQuery({
    queryKey: [
      'admin',
      'beverages',
      debouncedQ,
      breweryFilter?.id ?? null,
      categoryFilter,
      idTrim,
      includeDeleted,
      cursor,
    ],
    queryFn: async () => {
      const query: {
        q?: string;
        brewery_id?: string;
        category_slug?: CategorySlug;
        id?: string;
        include_deleted?: '0' | '1';
        cursor?: string;
      } = {};
      if (debouncedQ) query.q = debouncedQ;
      if (breweryFilter) query.brewery_id = breweryFilter.id;
      if (categoryFilter) query.category_slug = categoryFilter;
      if (idTrim) query.id = idTrim;
      if (includeDeleted) query.include_deleted = '1';
      if (cursor) query.cursor = cursor;
      const { data: page, error } = await api.GET('/v1/admin/beverages', {
        params: { query },
      });
      if (error || !page) throw new Error('failed_to_load_beverages');
      return page;
    },
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold">Beverages</h1>
        <button
          type="button"
          onClick={() => setCreateOpen(true)}
          className="px-3 py-1 bg-[color:var(--color-accent)] text-white rounded text-sm"
        >
          New beverage
        </button>
      </div>

      <div className="flex flex-wrap gap-3 items-end text-sm mb-3 border border-[color:var(--color-border)] rounded bg-[color:var(--color-surface)] p-3">
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Search (q)</span>
          <input
            type="search"
            value={qInput}
            onChange={(e) => {
              setQInput(e.target.value);
              setCursor(null);
            }}
            placeholder="FTS over name_i18n"
            className="border border-[color:var(--color-border)] rounded px-2 py-1 w-64"
          />
        </label>
        <div className="w-64">
          <BreweryPicker
            value={breweryFilter}
            onChange={(v) => {
              setBreweryFilter(v);
              setCursor(null);
            }}
            label="Brewery (optional)"
          />
        </div>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Category</span>
          <select
            value={categoryFilter}
            onChange={(e) => {
              setCategoryFilter(e.target.value as CategorySlug | '');
              setCursor(null);
            }}
            className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)]"
          >
            <option value="">(any)</option>
            <option value="nihonshu">Nihonshu (Sake)</option>
            <option value="shochu">Shochu</option>
            <option value="liqueur">Liqueur</option>
          </select>
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">UUID (exact)</span>
          <input
            type="text"
            value={idExact}
            onChange={(e) => {
              setIdExact(e.target.value);
              setCursor(null);
            }}
            placeholder="beverage uuid"
            className="border border-[color:var(--color-border)] rounded px-2 py-1 font-mono text-xs w-72"
          />
        </label>
        <label className="flex items-center gap-1">
          <input
            type="checkbox"
            checked={includeDeleted}
            onChange={(e) => {
              setIncludeDeleted(e.target.checked);
              setCursor(null);
            }}
          />
          <span>include deleted</span>
        </label>
      </div>

      {isLoading && <p className="text-sm text-[color:var(--color-muted)]">Loading…</p>}
      {isError && <p className="text-sm text-red-700">Failed to load beverages.</p>}
      {data && (
        <QueueTable<AdminBeverage>
          columns={COLUMNS}
          items={data.items}
          page={{ hasMore: data.has_more, nextCursor: data.next_cursor ?? null }}
          cursor={cursor}
          onCursorChange={setCursor}
          rowKey={(b) => b.id}
          emptyLabel="No beverages."
          renderRow={(b) => <BeverageRow beverage={b} />}
        />
      )}

      {createOpen && (
        <CreateBeverageModal
          onClose={() => setCreateOpen(false)}
          onCreated={() => {
            toast.push('Beverage created');
            setCreateOpen(false);
          }}
        />
      )}
    </div>
  );
}

function BeverageRow({ beverage }: { beverage: AdminBeverage }) {
  const [modal, setModal] = useState<'edit' | 'delete' | 'restore' | null>(null);
  const isDeleted = beverage.deleted_at != null;
  const name = preferredName(beverage.name) || '(unnamed)';
  const brewery = preferredName(beverage.brewery.name) || '(unnamed)';
  return (
    <>
      <tr className="border-t border-[color:var(--color-border)]">
        <td className="p-2 align-top">
          <CopyableId id={beverage.id} />
        </td>
        <td className="p-2 align-top">{name}</td>
        <td className="p-2 align-top text-[color:var(--color-muted)]">{brewery}</td>
        <td className="p-2 align-top">{beverage.category.slug}</td>
        <td className="p-2 align-top">
          {beverage.abv != null ? `${beverage.abv.toFixed(1)}%` : '—'}
        </td>
        <td className="p-2 align-top whitespace-nowrap">
          {isDeleted ? (
            <span className="px-2 py-0.5 rounded text-xs bg-red-100 text-red-800">deleted</span>
          ) : (
            <span className="px-2 py-0.5 rounded text-xs bg-emerald-100 text-emerald-800">
              live
            </span>
          )}
        </td>
        <td className="p-2 align-top text-right whitespace-nowrap">
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
              Soft-delete
            </button>
          )}
        </td>
      </tr>
      {modal === 'edit' && <EditBeverageModal beverage={beverage} onClose={() => setModal(null)} />}
      {modal === 'delete' && (
        <DeleteBeverageModal beverage={beverage} onClose={() => setModal(null)} />
      )}
      {modal === 'restore' && (
        <RestoreBeverageModal beverage={beverage} onClose={() => setModal(null)} />
      )}
    </>
  );
}

function CopyableId({ id }: { id: string }) {
  const toast = useToast();
  return (
    <button
      type="button"
      onClick={() => {
        void navigator.clipboard?.writeText(id).then(() => toast.push('ID copied'));
      }}
      title={id}
      className="font-mono text-xs text-[color:var(--color-muted)] hover:text-[color:var(--color-fg)]"
    >
      {id.slice(0, 8)}…
    </button>
  );
}

function CreateBeverageModal({
  onClose,
  onCreated,
}: {
  onClose: () => void;
  onCreated: () => void;
}) {
  const qc = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: async (body: CreateBody) => {
      const { data, error: err, response } = await api.POST('/v1/admin/beverages', { body });
      if (err || !data) throw new Error(`create_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'beverages'] });
      onCreated();
    },
  });
  return (
    <Modal open onClose={onClose} title="New beverage">
      <CatalogBeverageForm
        submitting={mut.isPending}
        submitLabel="Create"
        errorMessage={error}
        onSubmit={(body) =>
          mut.mutate(body, {
            onError: (e: Error) => setError(e.message),
          })
        }
        onCancel={onClose}
      />
    </Modal>
  );
}

function EditBeverageModal({
  beverage,
  onClose,
}: {
  beverage: AdminBeverage;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: async (body: UpdateBody) => {
      const {
        data,
        error: err,
        response,
      } = await api.PATCH('/v1/admin/beverages/{id}', {
        params: { path: { id: beverage.id } },
        body,
      });
      if (err || !data) throw new Error(`update_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'beverages'] });
      toast.push('Beverage updated');
      onClose();
    },
  });
  return (
    <Modal open onClose={onClose} title={`Edit beverage — ${preferredName(beverage.name)}`}>
      <CatalogBeverageForm
        initial={beverage}
        submitting={mut.isPending}
        submitLabel="Save"
        errorMessage={error}
        onSubmit={(body) =>
          mut.mutate(body, {
            onError: (e: Error) => setError(e.message),
          })
        }
        onCancel={onClose}
      />
    </Modal>
  );
}

function DeleteBeverageModal({
  beverage,
  onClose,
}: {
  beverage: AdminBeverage;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: async () => {
      const { error: err, response } = await api.DELETE('/v1/admin/beverages/{id}', {
        params: { path: { id: beverage.id } },
      });
      if (err || response.status !== 204) {
        throw new Error(`delete_failed_${response.status}`);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'beverages'] });
      toast.push(`Soft-deleted ${preferredName(beverage.name)}`);
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
    <Modal open onClose={onClose} title={`Soft-delete ${preferredName(beverage.name)}?`}>
      <form onSubmit={onConfirm}>
        <p className="text-sm mb-3">
          This sets <code className="font-mono">deleted_at</code> on the beverage. Public catalog
          reads will hide it; existing check-ins keep their reference. You can restore it later.
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
            className="px-3 py-1 bg-red-700 text-white rounded text-sm disabled:opacity-50"
          >
            {mut.isPending ? 'Deleting…' : 'Soft-delete'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function RestoreBeverageModal({
  beverage,
  onClose,
}: {
  beverage: AdminBeverage;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: async () => {
      const {
        data,
        error: err,
        response,
      } = await api.POST('/v1/admin/beverages/{id}/restore', {
        params: { path: { id: beverage.id } },
      });
      if (err || !data) throw new Error(`restore_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'beverages'] });
      toast.push(`Restored ${preferredName(beverage.name)}`);
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
    <Modal open onClose={onClose} title={`Restore ${preferredName(beverage.name)}?`}>
      <form onSubmit={onConfirm}>
        <p className="text-sm mb-3">
          Clears <code className="font-mono">deleted_at</code>; the beverage reappears in the public
          catalog.
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
