import { useQuery } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { RoleGuard } from '@/components/guard';
import { Modal } from '@/components/modal';
import { QueueTable, type QueueTableColumn } from '@/components/QueueTable';
import { useToast } from '@/components/toast';
import { useModerateComment } from '@/hooks/admin/mutations';
import { api } from '@/lib/api';
import type { components } from '@/types/api';

type AdminComment = components['schemas']['AdminComment'];

// Backend `/v1/admin/comments?status=visible` returns BOTH live + soft-deleted
// rows (per the openapi description; the row carries `deleted_at` for
// distinguishing). `status=deleted` returns only soft-deleted rows. To get
// "live only", we fetch `visible` and client-filter on `deleted_at == null`.
type Filter = 'visible' | 'deleted' | 'all';

const COLUMNS: QueueTableColumn[] = [
  { key: 'created', label: 'Created' },
  { key: 'checkin', label: 'Check-in' },
  { key: 'author', label: 'Author' },
  { key: 'body', label: 'Body' },
  { key: 'status', label: 'Status' },
  { key: 'actions', label: 'Actions', className: 'text-right' },
];

export const Route = createFileRoute('/comments')({
  component: GuardedCommentsPage,
});

function GuardedCommentsPage() {
  return (
    <RoleGuard requires={['admin', 'moderator']}>
      <CommentsPage />
    </RoleGuard>
  );
}

function CommentsPage() {
  const [filter, setFilter] = useState<Filter>('visible');
  const [cursor, setCursor] = useState<string | null>(null);

  // 'visible' and 'all' both hit the API with status=visible (the API's
  // "visible" bucket includes soft-deleted rows). 'deleted' hits status=deleted.
  const apiStatus: 'visible' | 'deleted' = filter === 'deleted' ? 'deleted' : 'visible';

  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin', 'comments', apiStatus, cursor],
    queryFn: async () => {
      const query: { status: 'visible' | 'deleted'; cursor?: string } = {
        status: apiStatus,
      };
      if (cursor) query.cursor = cursor;
      const { data: page, error } = await api.GET('/v1/admin/comments', {
        params: { query },
      });
      if (error || !page) throw new Error('failed_to_load_comments');
      return page;
    },
  });

  const visibleItems =
    data?.items.filter((c) => (filter === 'visible' ? c.deleted_at == null : true)) ?? [];

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">Comments moderation</h1>

      <div className="flex gap-3 items-center text-sm mb-3">
        <label className="flex items-center gap-1">
          <span className="text-[color:var(--color-muted)]">Status</span>
          <select
            value={filter}
            onChange={(e) => {
              setFilter(e.target.value as Filter);
              setCursor(null);
            }}
            className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)]"
          >
            <option value="visible">Visible</option>
            <option value="deleted">Deleted</option>
            <option value="all">All</option>
          </select>
        </label>
      </div>

      {isLoading && <p className="text-sm text-[color:var(--color-muted)]">Loading…</p>}
      {isError && <p className="text-sm text-red-700">Failed to load comments.</p>}
      {data && (
        <QueueTable<AdminComment>
          columns={COLUMNS}
          items={visibleItems}
          page={{ hasMore: data.has_more, nextCursor: data.next_cursor ?? null }}
          cursor={cursor}
          onCursorChange={setCursor}
          rowKey={(c) => c.id}
          emptyLabel="No comments."
          renderRow={(c) => <CommentRow comment={c} />}
        />
      )}
    </div>
  );
}

const BODY_PREVIEW_LIMIT = 200;

function CommentRow({ comment }: { comment: AdminComment }) {
  const [modal, setModal] = useState<'moderate' | null>(null);
  const [expanded, setExpanded] = useState(false);
  const isDeleted = comment.deleted_at != null;
  const truncated = comment.body.length > BODY_PREVIEW_LIMIT;
  const display =
    truncated && !expanded ? `${comment.body.slice(0, BODY_PREVIEW_LIMIT)}…` : comment.body;

  return (
    <>
      <tr className="border-t border-[color:var(--color-border)]">
        <td className="p-2 align-top whitespace-nowrap text-[color:var(--color-muted)]">
          {new Date(comment.created_at).toLocaleString()}
        </td>
        <td className="p-2 align-top font-mono text-xs text-[color:var(--color-muted)]">
          {comment.check_in_id.slice(0, 8)}…
        </td>
        <td className="p-2 align-top">{comment.user.display_username}</td>
        <td className="p-2 align-top max-w-xl">
          {truncated ? (
            <button
              type="button"
              onClick={() => setExpanded((v) => !v)}
              className="text-left whitespace-pre-wrap"
              title={expanded ? 'Collapse' : 'Expand'}
            >
              {display}
            </button>
          ) : (
            <span className="whitespace-pre-wrap">{display}</span>
          )}
        </td>
        <td className="p-2 align-top">
          {isDeleted ? <span className="text-red-700">deleted</span> : <span>visible</span>}
        </td>
        <td className="p-2 align-top text-right whitespace-nowrap">
          <button
            type="button"
            onClick={() => setModal('moderate')}
            disabled={isDeleted}
            className="px-2 py-1 bg-red-700 text-white rounded text-xs disabled:opacity-40"
            title={isDeleted ? 'Already deleted' : 'Soft delete'}
          >
            Soft delete
          </button>
        </td>
      </tr>
      {modal === 'moderate' && <ModerateModal comment={comment} onClose={() => setModal(null)} />}
    </>
  );
}

function ModerateModal({ comment, onClose }: { comment: AdminComment; onClose: () => void }) {
  const toast = useToast();
  const mut = useModerateComment(comment.id);
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    mut.mutate(notes, {
      onSuccess: () => {
        toast.push('Comment moderated (soft-deleted)');
        onClose();
      },
      onError: (e: Error) => setError(e.message),
    });
  }

  return (
    <Modal open onClose={onClose} title={`Soft-delete comment — ${comment.user.display_username}`}>
      <form onSubmit={onSubmit} className="flex flex-col gap-3 text-sm">
        <p className="text-[color:var(--color-muted)] whitespace-pre-wrap border-l-2 border-[color:var(--color-border)] pl-2">
          {comment.body}
        </p>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">
            Moderation notes (optional, ≤1000)
          </span>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={1000}
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
            disabled={mut.isPending}
            className="px-3 py-1 bg-red-700 text-white rounded disabled:opacity-50"
          >
            {mut.isPending ? 'Moderating…' : 'Soft delete'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
