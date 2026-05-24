import { useQuery } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
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
  const [form, setForm] = useState<{
    brewery_id: string;
    category_id: string;
    name_en: string;
    name_ja: string;
    name_ko: string;
    abv: string;
    label_image_url: string;
  }>({
    brewery_id: '',
    category_id: '',
    name_en: '',
    name_ja: '',
    name_ko: '',
    abv: '',
    label_image_url: '',
  });
  const [error, setError] = useState<string | null>(null);

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const body: components['schemas']['AdminBeverageRequestApproval'] = {
      brewery_id: form.brewery_id.trim(),
      category_id: form.category_id.trim(),
      name_i18n: {
        en: form.name_en.trim(),
        ja: form.name_ja.trim(),
        ko: form.name_ko.trim(),
      },
    };
    if (form.abv.trim()) body.abv = Number(form.abv);
    if (form.label_image_url.trim()) body.label_image_url = form.label_image_url.trim();
    approve.mutate(body, {
      onSuccess: () => {
        toast.push('Approved');
        onClose();
      },
      onError: (e: Error) => setError(e.message),
    });
  }

  return (
    <Modal open onClose={onClose} title="Approve beverage request">
      <form onSubmit={onSubmit} className="flex flex-col gap-3 text-sm">
        <Field
          label="Brewery ID (uuid)"
          value={form.brewery_id}
          onChange={(v) => setForm({ ...form, brewery_id: v })}
          required
        />
        <Field
          label="Category ID (uuid)"
          value={form.category_id}
          onChange={(v) => setForm({ ...form, category_id: v })}
          required
        />
        <Field
          label="Name (en)"
          value={form.name_en}
          onChange={(v) => setForm({ ...form, name_en: v })}
          required
        />
        <Field
          label="Name (ja)"
          value={form.name_ja}
          onChange={(v) => setForm({ ...form, name_ja: v })}
          required
        />
        <Field
          label="Name (ko)"
          value={form.name_ko}
          onChange={(v) => setForm({ ...form, name_ko: v })}
          required
        />
        <Field
          label="ABV (optional)"
          value={form.abv}
          onChange={(v) => setForm({ ...form, abv: v })}
          type="number"
        />
        <Field
          label="Label image URL (optional)"
          value={form.label_image_url}
          onChange={(v) => setForm({ ...form, label_image_url: v })}
        />
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
            disabled={approve.isPending}
            className="px-3 py-1 bg-emerald-700 text-white rounded disabled:opacity-50"
          >
            {approve.isPending ? 'Approving…' : 'Approve'}
          </button>
        </div>
      </form>
    </Modal>
  );
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

interface FieldProps {
  label: string;
  value: string;
  onChange: (v: string) => void;
  required?: boolean;
  type?: string;
}

function Field({ label, value, onChange, required, type = 'text' }: FieldProps) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[color:var(--color-muted)]">{label}</span>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required={required ?? false}
        className="border border-[color:var(--color-border)] rounded px-2 py-1"
      />
    </label>
  );
}
