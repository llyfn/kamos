import { useQuery } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { RoleGuard } from '@/components/guard';
import { JsonTree } from '@/components/json-tree';
import { QueueTable, type QueueTableColumn } from '@/components/QueueTable';
import { api } from '@/lib/api';
import type { components } from '@/types/api';

type Entry = components['schemas']['ModerationLogEntry'];

type TargetType =
  | ''
  | 'check_in'
  | 'comment'
  | 'user'
  | 'beverage_request'
  | 'beverage'
  | 'brewery';

interface Filters {
  target_type: TargetType;
  target_id: string;
  moderator_id: string;
}

const EMPTY_FILTERS: Filters = { target_type: '', target_id: '', moderator_id: '' };

// Action + target-type display labels. Kept inline rather than i18n because
// the admin UI is English-only (see CLAUDE.md "Admin i18n" risk note).
const ACTION_LABELS: Record<Entry['action'], string> = {
  soft_delete: 'soft delete',
  role_change: 'role change',
  suspend: 'suspend',
  approve: 'approve',
  reject: 'reject',
  create: 'create',
  update: 'update',
  restore: 'restore',
};
const TARGET_LABELS: Record<Entry['target_type'], string> = {
  check_in: 'check-in',
  comment: 'comment',
  user: 'user',
  beverage_request: 'beverage request',
  beverage: 'beverage',
  brewery: 'brewery',
};
const ACTION_BADGE_TONE: Record<Entry['action'], string> = {
  soft_delete: 'bg-red-100 text-red-800',
  role_change: 'bg-amber-100 text-amber-800',
  suspend: 'bg-red-100 text-red-800',
  approve: 'bg-emerald-100 text-emerald-800',
  reject: 'bg-red-100 text-red-800',
  create: 'bg-sky-100 text-sky-800',
  update: 'bg-amber-100 text-amber-800',
  restore: 'bg-emerald-100 text-emerald-800',
};

const COLUMNS: QueueTableColumn[] = [
  { key: 'when', label: 'When' },
  { key: 'moderator', label: 'Moderator' },
  { key: 'action', label: 'Action' },
  { key: 'target', label: 'Target' },
  { key: 'notes', label: 'Notes' },
  { key: 'metadata', label: 'Metadata' },
];

export const Route = createFileRoute('/moderation-log')({
  component: GuardedModerationLogPage,
});

function GuardedModerationLogPage() {
  return (
    <RoleGuard requires={['admin', 'moderator']}>
      <ModerationLogPage />
    </RoleGuard>
  );
}

function ModerationLogPage() {
  // `applied` is the filter set actually in the query key (drives the
  // request); `draft` is what the user is editing. Submit copies draft →
  // applied + resets cursor so the new filter starts at page 1.
  const [draft, setDraft] = useState<Filters>(EMPTY_FILTERS);
  const [applied, setApplied] = useState<Filters>(EMPTY_FILTERS);
  const [cursor, setCursor] = useState<string | null>(null);

  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin', 'moderation-log', applied, cursor],
    queryFn: async () => {
      const query: {
        target_type?: 'check_in' | 'comment' | 'user' | 'beverage_request' | 'beverage' | 'brewery';
        target_id?: string;
        moderator_id?: string;
        cursor?: string;
      } = {};
      if (applied.target_type) query.target_type = applied.target_type;
      if (applied.target_id.trim()) query.target_id = applied.target_id.trim();
      if (applied.moderator_id.trim()) query.moderator_id = applied.moderator_id.trim();
      if (cursor) query.cursor = cursor;
      const { data: page, error } = await api.GET('/v1/admin/moderation-log', {
        params: { query },
      });
      if (error || !page) throw new Error('failed_to_load_moderation_log');
      return page;
    },
  });

  function onApply(e: FormEvent) {
    e.preventDefault();
    setApplied(draft);
    setCursor(null);
  }

  function onReset() {
    setDraft(EMPTY_FILTERS);
    setApplied(EMPTY_FILTERS);
    setCursor(null);
  }

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">Moderation log</h1>

      <form
        onSubmit={onApply}
        className="flex flex-wrap gap-3 items-end text-sm mb-3 border border-[color:var(--color-border)] rounded bg-[color:var(--color-surface)] p-3"
      >
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Target type</span>
          <select
            value={draft.target_type}
            onChange={(e) => setDraft({ ...draft, target_type: e.target.value as TargetType })}
            className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)]"
          >
            <option value="">(any)</option>
            <option value="check_in">check_in</option>
            <option value="comment">comment</option>
            <option value="user">user</option>
            <option value="beverage_request">beverage_request</option>
            <option value="beverage">beverage</option>
            <option value="brewery">brewery</option>
          </select>
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Target ID</span>
          <input
            type="text"
            value={draft.target_id}
            onChange={(e) => setDraft({ ...draft, target_id: e.target.value })}
            placeholder="uuid"
            className="border border-[color:var(--color-border)] rounded px-2 py-1 font-mono text-xs w-full sm:w-72"
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Moderator ID</span>
          <input
            type="text"
            value={draft.moderator_id}
            onChange={(e) => setDraft({ ...draft, moderator_id: e.target.value })}
            placeholder="uuid"
            className="border border-[color:var(--color-border)] rounded px-2 py-1 font-mono text-xs w-full sm:w-72"
          />
        </label>
        <div className="flex gap-2">
          <button
            type="submit"
            className="px-3 py-1 bg-[color:var(--color-accent)] text-white rounded"
          >
            Apply
          </button>
          <button
            type="button"
            onClick={onReset}
            className="px-3 py-1 border border-[color:var(--color-border)] rounded"
          >
            Reset
          </button>
        </div>
      </form>

      {isLoading && <p className="text-sm text-[color:var(--color-muted)]">Loading…</p>}
      {isError && <p className="text-sm text-red-700">Failed to load moderation log.</p>}
      {data && (
        <QueueTable<Entry>
          columns={COLUMNS}
          items={data.items}
          page={{ hasMore: data.has_more, nextCursor: data.next_cursor ?? null }}
          cursor={cursor}
          onCursorChange={setCursor}
          rowKey={(e) => e.id}
          emptyLabel="No entries."
          renderRow={(e) => <EntryRow entry={e} />}
        />
      )}
    </div>
  );
}

function EntryRow({ entry }: { entry: Entry }) {
  return (
    <tr className="border-t border-[color:var(--color-border)]">
      <td className="p-2 align-top whitespace-nowrap text-[color:var(--color-muted)]">
        {new Date(entry.created_at).toLocaleString()}
      </td>
      <td className="p-2 align-top font-mono text-xs">
        {entry.moderator_id ? `${entry.moderator_id.slice(0, 8)}…` : '(deleted)'}
      </td>
      <td className="p-2 align-top">
        <span
          className={`px-2 py-0.5 rounded text-xs ${ACTION_BADGE_TONE[entry.action] ?? 'bg-gray-100 text-gray-800'}`}
        >
          {ACTION_LABELS[entry.action] ?? entry.action}
        </span>
      </td>
      <td className="p-2 align-top">
        <div>{TARGET_LABELS[entry.target_type] ?? entry.target_type}</div>
        <div className="font-mono text-xs text-[color:var(--color-muted)]">
          {entry.target_id.slice(0, 8)}…
        </div>
      </td>
      <td className="p-2 align-top max-w-md whitespace-pre-wrap">{entry.notes ?? '—'}</td>
      <td className="p-2 align-top max-w-md">
        {entry.metadata ? <JsonTree value={entry.metadata} /> : '—'}
      </td>
    </tr>
  );
}
