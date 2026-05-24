// /breweries — admin catalog CRUD page for breweries.
//
// Filters: debounced FTS `q`, UUID exact `id`, `include_deleted` checkbox.
// Header: "New brewery" opens the CatalogBreweryForm in create mode.
// Per-row: Edit (modal with form in edit mode), Soft-delete / Restore
// (confirm modal). The 409 BREWERY_HAS_LIVE_BEVERAGES soft-delete error
// is surfaced verbatim as a toast.

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { preferredName } from '@/components/BreweryPicker';
import { CatalogBreweryForm } from '@/components/CatalogBreweryForm';
import { RoleGuard } from '@/components/guard';
import { Modal } from '@/components/modal';
import { QueueTable, type QueueTableColumn } from '@/components/QueueTable';
import { useToast } from '@/components/toast';
import { api } from '@/lib/api';
import { useDebounced } from '@/lib/use-debounced';
import type { components } from '@/types/api';

type AdminBrewery = components['schemas']['AdminBrewery'];
type CreateBody = components['schemas']['AdminBreweryCreate'];
type UpdateBody = components['schemas']['AdminBreweryUpdate'];

export const Route = createFileRoute('/breweries')({
  component: GuardedBreweriesPage,
});

const COLUMNS: QueueTableColumn[] = [
  { key: 'id', label: 'ID' },
  { key: 'name', label: 'Name' },
  { key: 'prefecture', label: 'Prefecture' },
  { key: 'deleted', label: 'Status' },
  { key: 'actions', label: 'Actions', className: 'text-right' },
];

function GuardedBreweriesPage() {
  return (
    <RoleGuard requires={['admin']}>
      <BreweriesPage />
    </RoleGuard>
  );
}

function BreweriesPage() {
  const toast = useToast();
  const [cursor, setCursor] = useState<string | null>(null);
  const [qInput, setQInput] = useState('');
  const [idExact, setIdExact] = useState('');
  const [includeDeleted, setIncludeDeleted] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);

  const debouncedQ = useDebounced(qInput.trim(), 300);
  const idTrim = idExact.trim();

  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin', 'breweries', debouncedQ, idTrim, includeDeleted, cursor],
    queryFn: async () => {
      const query: {
        q?: string;
        id?: string;
        include_deleted?: '0' | '1';
        cursor?: string;
      } = {};
      if (debouncedQ) query.q = debouncedQ;
      if (idTrim) query.id = idTrim;
      if (includeDeleted) query.include_deleted = '1';
      if (cursor) query.cursor = cursor;
      const { data: page, error } = await api.GET('/v1/admin/breweries', {
        params: { query },
      });
      if (error || !page) throw new Error('failed_to_load_breweries');
      return page;
    },
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-semibold">Breweries</h1>
        <button
          type="button"
          onClick={() => setCreateOpen(true)}
          className="px-3 py-1 bg-[color:var(--color-accent)] text-white rounded text-sm"
        >
          New brewery
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
            className="border border-[color:var(--color-border)] rounded px-2 py-1 w-72"
          />
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
            placeholder="brewery uuid"
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
      {isError && <p className="text-sm text-red-700">Failed to load breweries.</p>}
      {data && (
        <QueueTable<AdminBrewery>
          columns={COLUMNS}
          items={data.items}
          page={{ hasMore: data.has_more, nextCursor: data.next_cursor ?? null }}
          cursor={cursor}
          onCursorChange={setCursor}
          rowKey={(b) => b.id}
          emptyLabel="No breweries."
          renderRow={(b) => <BreweryRow brewery={b} />}
        />
      )}

      {createOpen && (
        <CreateBreweryModal
          onClose={() => setCreateOpen(false)}
          onCreated={() => {
            toast.push('Brewery created');
            setCreateOpen(false);
          }}
        />
      )}
    </div>
  );
}

function BreweryRow({ brewery }: { brewery: AdminBrewery }) {
  const [modal, setModal] = useState<'edit' | 'delete' | 'restore' | null>(null);
  const isDeleted = brewery.deleted_at != null;
  const display = preferredName(brewery.name) || '(unnamed)';
  return (
    <>
      <tr className="border-t border-[color:var(--color-border)]">
        <td className="p-2 align-top">
          <CopyableId id={brewery.id} />
        </td>
        <td className="p-2 align-top">{display}</td>
        <td className="p-2 align-top text-[color:var(--color-muted)]">
          {brewery.prefecture ? preferredName(brewery.prefecture.name) : '—'}
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
      {modal === 'edit' && <EditBreweryModal brewery={brewery} onClose={() => setModal(null)} />}
      {modal === 'delete' && (
        <DeleteBreweryModal brewery={brewery} onClose={() => setModal(null)} />
      )}
      {modal === 'restore' && (
        <RestoreBreweryModal brewery={brewery} onClose={() => setModal(null)} />
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

function CreateBreweryModal({
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
      const { data, error: err, response } = await api.POST('/v1/admin/breweries', { body });
      if (err || !data) {
        const code = (err as { code?: string } | undefined)?.code;
        if (response.status === 422 && code === 'INVALID_PREFECTURE_SLUG') {
          throw new Error('INVALID_PREFECTURE_SLUG');
        }
        throw new Error(`create_failed_${response.status}`);
      }
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'breweries'] });
      qc.invalidateQueries({ queryKey: ['admin', 'brewery-typeahead'] });
      onCreated();
    },
  });
  return (
    <Modal open onClose={onClose} title="New brewery">
      <CatalogBreweryForm
        submitting={mut.isPending}
        submitLabel="Create"
        errorMessage={error}
        onSubmit={(body) =>
          mut.mutate(body as CreateBody, {
            onError: (e: Error) => setError(e.message),
          })
        }
        onCancel={onClose}
      />
    </Modal>
  );
}

function EditBreweryModal({ brewery, onClose }: { brewery: AdminBrewery; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: async (body: UpdateBody) => {
      const {
        data,
        error: err,
        response,
      } = await api.PATCH('/v1/admin/breweries/{id}', {
        params: { path: { id: brewery.id } },
        body,
      });
      if (err || !data) {
        const code = (err as { code?: string } | undefined)?.code;
        if (response.status === 422 && code === 'INVALID_PREFECTURE_SLUG') {
          throw new Error('INVALID_PREFECTURE_SLUG');
        }
        throw new Error(`update_failed_${response.status}`);
      }
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'breweries'] });
      qc.invalidateQueries({ queryKey: ['admin', 'brewery-typeahead'] });
      toast.push('Brewery updated');
      onClose();
    },
  });
  return (
    <Modal open onClose={onClose} title={`Edit brewery — ${preferredName(brewery.name)}`}>
      <CatalogBreweryForm
        initial={brewery}
        submitting={mut.isPending}
        submitLabel="Save"
        errorMessage={error}
        onSubmit={(body) =>
          mut.mutate(body as UpdateBody, {
            onError: (e: Error) => setError(e.message),
          })
        }
        onCancel={onClose}
      />
    </Modal>
  );
}

function DeleteBreweryModal({ brewery, onClose }: { brewery: AdminBrewery; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: async () => {
      const { error: err, response } = await api.DELETE('/v1/admin/breweries/{id}', {
        params: { path: { id: brewery.id } },
      });
      if (response.status === 409) {
        throw new Error('BREWERY_HAS_LIVE_BEVERAGES');
      }
      if (err || response.status !== 204) {
        throw new Error(`delete_failed_${response.status}`);
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'breweries'] });
      qc.invalidateQueries({ queryKey: ['admin', 'brewery-typeahead'] });
      toast.push(`Soft-deleted ${preferredName(brewery.name)}`);
      onClose();
    },
    onError: (e: Error) => {
      if (e.message === 'BREWERY_HAS_LIVE_BEVERAGES') {
        toast.push(
          'Cannot delete — this brewery still has live beverages. Soft-delete or reassign them first.',
          'error',
        );
      }
      setError(e.message);
    },
  });
  function onConfirm(e: FormEvent) {
    e.preventDefault();
    setError(null);
    mut.mutate();
  }
  return (
    <Modal open onClose={onClose} title={`Soft-delete ${preferredName(brewery.name)}?`}>
      <form onSubmit={onConfirm}>
        <p className="text-sm mb-3">
          This sets <code className="font-mono">deleted_at</code> on the brewery. Public catalog
          reads will hide it; you can restore it later. Fails with{' '}
          <code className="font-mono">409</code> if any live beverages still reference it.
        </p>
        {error && error !== 'BREWERY_HAS_LIVE_BEVERAGES' && (
          <p className="text-red-700 text-xs mb-2">{error}</p>
        )}
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

function RestoreBreweryModal({ brewery, onClose }: { brewery: AdminBrewery; onClose: () => void }) {
  const qc = useQueryClient();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const mut = useMutation({
    mutationFn: async () => {
      const {
        data,
        error: err,
        response,
      } = await api.POST('/v1/admin/breweries/{id}/restore', {
        params: { path: { id: brewery.id } },
      });
      if (err || !data) throw new Error(`restore_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin', 'breweries'] });
      qc.invalidateQueries({ queryKey: ['admin', 'brewery-typeahead'] });
      toast.push(`Restored ${preferredName(brewery.name)}`);
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
    <Modal open onClose={onClose} title={`Restore ${preferredName(brewery.name)}?`}>
      <form onSubmit={onConfirm}>
        <p className="text-sm mb-3">
          Clears <code className="font-mono">deleted_at</code>; the brewery reappears in the public
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
