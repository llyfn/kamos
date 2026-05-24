import { useQuery } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import {
  CatalogBeverageForm,
  type CatalogBeverageFormPartial,
} from '@/components/CatalogBeverageForm';
import { RoleGuard } from '@/components/guard';
import { JsonTree } from '@/components/json-tree';
import { Modal } from '@/components/modal';
import { QueueTable, type QueueTableColumn } from '@/components/QueueTable';
import { useToast } from '@/components/toast';
import { useApproveBeverageRequest, useRejectBeverageRequest } from '@/hooks/admin/mutations';
import { api } from '@/lib/api';
import type { components } from '@/types/api';

type Request = components['schemas']['AdminBeverageRequest'];

export const Route = createFileRoute('/queue')({
  component: GuardedQueuePage,
});

const COLUMNS: QueueTableColumn[] = [
  { key: 'created', label: 'Created' },
  { key: 'submitter', label: 'Submitter' },
  { key: 'payload', label: 'Payload' },
  { key: 'status', label: 'Status' },
  { key: 'actions', label: 'Actions', className: 'text-right' },
];

function GuardedQueuePage() {
  return (
    <RoleGuard requires={['admin', 'moderator']}>
      <QueuePage />
    </RoleGuard>
  );
}

function QueuePage() {
  const [cursor, setCursor] = useState<string | null>(null);
  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin', 'beverage-requests', cursor],
    queryFn: async () => {
      const params: { status: 'pending'; cursor?: string } = { status: 'pending' };
      if (cursor) params.cursor = cursor;
      const { data: page, error } = await api.GET('/v1/admin/beverage-requests', {
        params: { query: params },
      });
      if (error || !page) throw new Error('failed_to_load_queue');
      return page;
    },
  });

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">Pending beverage requests</h1>
      {isLoading && <p className="text-sm text-[color:var(--color-muted)]">Loading…</p>}
      {isError && <p className="text-sm text-red-700">Failed to load queue.</p>}
      {data && (
        <QueueTable<Request>
          columns={COLUMNS}
          items={data.items}
          page={{ hasMore: data.has_more, nextCursor: data.next_cursor ?? null }}
          cursor={cursor}
          onCursorChange={setCursor}
          rowKey={(r) => r.id}
          emptyLabel="No pending requests."
          renderRow={(r) => <Row request={r} />}
        />
      )}
    </div>
  );
}

function Row({ request }: { request: Request }) {
  const [modal, setModal] = useState<'approve' | 'reject' | null>(null);
  return (
    <>
      <tr className="border-t border-[color:var(--color-border)]">
        <td className="p-2 align-top whitespace-nowrap text-[color:var(--color-muted)]">
          {new Date(request.created_at).toLocaleString()}
        </td>
        <td className="p-2 align-top">{request.username ?? '(deleted)'}</td>
        <td className="p-2 align-top max-w-xl">
          <JsonTree value={request.payload} />
        </td>
        <td className="p-2 align-top">{request.status}</td>
        <td className="p-2 align-top text-right whitespace-nowrap">
          <button
            type="button"
            onClick={() => setModal('approve')}
            className="px-2 py-1 bg-emerald-700 text-white rounded text-xs mr-1"
          >
            Approve
          </button>
          <button
            type="button"
            onClick={() => setModal('reject')}
            className="px-2 py-1 bg-red-700 text-white rounded text-xs"
          >
            Reject
          </button>
        </td>
      </tr>
      {modal === 'approve' && <ApproveModal request={request} onClose={() => setModal(null)} />}
      {modal === 'reject' && <RejectModal request={request} onClose={() => setModal(null)} />}
    </>
  );
}

function ApproveModal({ request, onClose }: { request: Request; onClose: () => void }) {
  const toast = useToast();
  const approve = useApproveBeverageRequest(request.id);
  const [error, setError] = useState<string | null>(null);
  const initialPartial = requestPayloadToInitial(request.payload);

  function handleSubmit(body: components['schemas']['AdminBeverageCreate']) {
    setError(null);
    // AdminBeverageCreate and AdminBeverageRequestApproval share the same
    // wire shape post-approval-parity; Approval just adds optional
    // `notes` + `subcategory_i18n`. Forward the form's emitted Create
    // body as the approval payload.
    const approval = body as unknown as components['schemas']['AdminBeverageRequestApproval'];
    approve.mutate(approval, {
      onSuccess: () => {
        toast.push('Approved');
        onClose();
      },
      onError: (e: Error) => setError(e.message),
    });
  }

  return (
    <Modal open onClose={onClose} title="Approve beverage request">
      <CatalogBeverageForm
        initialPartial={initialPartial}
        submitting={approve.isPending}
        submitLabel="Approve"
        errorMessage={error}
        onSubmit={handleSubmit}
        onCancel={onClose}
      />
    </Modal>
  );
}

// Best-effort mapping from the free-form JSONB request payload (see
// backend/internal/domain/types_request.go for known keys) into the
// admin form's loose initial-partial shape. Unknown keys are dropped:
// the full payload is still rendered by JsonTree on the row so the
// reviewer can crib values manually. Brewery is intentionally not
// prefilled — `brewery_name` is the user's free-text guess, not a
// UUID, so the reviewer picks the canonical brewery via BreweryPicker.
function requestPayloadToInitial(payload: Record<string, unknown>): CatalogBeverageFormPartial {
  const str = (k: string) => (typeof payload[k] === 'string' ? (payload[k] as string) : '');
  const num = (k: string): string => {
    const v = payload[k];
    if (typeof v === 'number') return String(v);
    if (typeof v === 'string') return v;
    return '';
  };
  const rawSlug = str('category_slug');
  const slug =
    rawSlug === 'nihonshu' || rawSlug === 'shochu' || rawSlug === 'liqueur' ? rawSlug : '';
  return {
    category_slug: slug,
    name_en: str('name'),
    name_ja: str('name_ja'),
    abv: num('abv'),
    polishing_ratio: num('polishing_ratio'),
    label_image_url: str('label_image_url'),
  };
}

function RejectModal({ request, onClose }: { request: Request; onClose: () => void }) {
  const toast = useToast();
  const reject = useRejectBeverageRequest(request.id);
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    reject.mutate(notes, {
      onSuccess: () => {
        toast.push('Rejected', 'success');
        onClose();
      },
      onError: (e: Error) => setError(e.message),
    });
  }

  return (
    <Modal open onClose={onClose} title="Reject beverage request">
      <form onSubmit={onSubmit} className="flex flex-col gap-3 text-sm">
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Notes * (1–500 chars)</span>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            required
            minLength={1}
            maxLength={500}
            rows={4}
            className="border border-[color:var(--color-border)] rounded px-2 py-1"
          />
        </label>
        {error && <p className="text-red-700 text-xs">{error}</p>}
        <div className="flex justify-end gap-2 mt-2">
          <button
            type="button"
            onClick={onClose}
            className="px-3 py-1 border border-[color:var(--color-border)] rounded"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={reject.isPending}
            className="px-3 py-1 bg-red-700 text-white rounded disabled:opacity-50"
          >
            {reject.isPending ? 'Rejecting…' : 'Reject'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
