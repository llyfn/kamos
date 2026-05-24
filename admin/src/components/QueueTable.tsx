// KAMOS admin — Generic paginated table.
//
// The four admin list routes (queue / users / comments / check-ins) all
// share the same shape: a TanStack Query cursor-paginated result, an
// empty state, a header row, per-item rows rendered by a caller-supplied
// component, and First / Next buttons. QueueTable lifts that shell out
// so the route files focus on column definitions + row markup.

import type { ReactNode } from 'react';

export interface QueueTableColumn {
  /// Stable column key (used as the React key on the `<th>`).
  key: string;
  /// Visible header label.
  label: string;
  /// Optional Tailwind classes appended to the `<th>` className.
  className?: string;
}

export interface QueueTablePageInfo {
  /// Whether a next page exists (drives the Next button's disabled state).
  hasMore: boolean;
  /// The cursor for the next page (forwarded to onCursorChange on click).
  nextCursor: string | null;
}

export interface QueueTableProps<T> {
  /// Column header definitions.
  columns: QueueTableColumn[];
  /// Page items. May be empty.
  items: T[];
  /// Pagination metadata.
  page: QueueTablePageInfo;
  /// Current cursor. `null` means "first page".
  cursor: string | null;
  /// Called when the user clicks First (null) or Next (next cursor).
  onCursorChange: (next: string | null) => void;
  /// Per-row renderer. Caller is responsible for the `<tr>` markup so each
  /// route can attach its own row-specific state (modals, expand/collapse).
  renderRow: (item: T, index: number) => ReactNode;
  /// Stable key getter for `renderRow`. Defaults to `(_, i) => i`.
  rowKey?: (item: T, index: number) => string | number;
  /// Copy shown when `items` is empty. Defaults to "No items.".
  emptyLabel?: string;
}

/**
 * Cursor-paginated table for admin moderation views. Returns the table
 * markup; the route file owns query/loading/error gating around it.
 */
export function QueueTable<T>(props: QueueTableProps<T>) {
  const {
    columns,
    items,
    page,
    cursor,
    onCursorChange,
    renderRow,
    rowKey,
    emptyLabel = 'No items.',
  } = props;

  return (
    <>
      <div className="border border-[color:var(--color-border)] rounded bg-[color:var(--color-surface)] overflow-x-auto">
        <table className="w-full min-w-[40rem] text-sm">
          <thead className="bg-[color:var(--color-bg)] text-left">
            <tr>
              {columns.map((c) => (
                <th key={c.key} className={`p-2 ${c.className ?? ''}`.trim()}>
                  {c.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {items.length === 0 && (
              <tr>
                <td
                  colSpan={columns.length}
                  className="p-6 text-center text-[color:var(--color-muted)]"
                >
                  {emptyLabel}
                </td>
              </tr>
            )}
            {items.map((item, i) => (
              <RowKeyed key={(rowKey ?? defaultRowKey)(item, i)}>{renderRow(item, i)}</RowKeyed>
            ))}
          </tbody>
        </table>
      </div>
      <div className="mt-3 flex justify-end gap-2 text-sm">
        <button
          type="button"
          disabled={!cursor}
          onClick={() => onCursorChange(null)}
          className="px-3 py-1 border border-[color:var(--color-border)] rounded disabled:opacity-40"
        >
          First
        </button>
        <button
          type="button"
          disabled={!page.hasMore}
          onClick={() => onCursorChange(page.nextCursor ?? null)}
          className="px-3 py-1 border border-[color:var(--color-border)] rounded disabled:opacity-40"
        >
          Next →
        </button>
      </div>
    </>
  );
}

function defaultRowKey<T>(_: T, i: number): string | number {
  return i;
}

// RowKeyed is a passthrough so `renderRow` returns can be either a single
// element or a fragment (Approve/Reject modals frequently follow the <tr>).
// React 19 accepts both as children of a Fragment without a wrapper.
function RowKeyed({ children }: { children: ReactNode }) {
  return <>{children}</>;
}
