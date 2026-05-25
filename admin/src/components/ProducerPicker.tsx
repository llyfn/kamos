// Typeahead producer picker. Hits GET /v1/admin/producers?q=&limit=10
// and renders a small dropdown of matches. Selecting one sets the
// `producer_id` and bubbles up an opaque display name so the parent
// can show "Name (id…)" without re-fetching.
//
// Used by:
//   - CatalogBeverageForm (mandatory producer_id field)
//   - /beverages list page (optional producer filter)

import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '@/lib/api';
import { useDebounced } from '@/lib/use-debounced';
import type { components } from '@/types/api';

type AdminProducer = components['schemas']['AdminProducer'];

export interface ProducerPickerValue {
  id: string;
  /** display name resolved from name_i18n (en→ja fallback). May be empty if cleared. */
  label: string;
}

interface ProducerPickerProps {
  value: ProducerPickerValue | null;
  onChange: (next: ProducerPickerValue | null) => void;
  label?: string;
  required?: boolean;
  placeholder?: string;
}

export function preferredName(name: components['schemas']['I18nText']): string {
  return name.en || name.ja || name.ko || '';
}

export function ProducerPicker({
  value,
  onChange,
  label = 'Producer',
  required = false,
  placeholder = 'Search by name…',
}: ProducerPickerProps) {
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(false);
  const debouncedQ = useDebounced(q.trim(), 300);

  const { data, isFetching } = useQuery({
    queryKey: ['admin', 'producer-typeahead', debouncedQ],
    queryFn: async () => {
      const query: { q?: string; limit: number } = { limit: 10 };
      if (debouncedQ) query.q = debouncedQ;
      const { data: page, error } = await api.GET('/v1/admin/producers', {
        params: { query },
      });
      if (error || !page) throw new Error('producer_typeahead_failed');
      return page.items;
    },
    enabled: open,
    staleTime: 30_000,
  });

  function select(b: AdminProducer) {
    onChange({ id: b.id, label: preferredName(b.name) });
    setQ('');
    setOpen(false);
  }

  function clear() {
    onChange(null);
    setQ('');
  }

  return (
    <div className="flex flex-col gap-1 relative">
      <span className="text-[color:var(--color-muted)] text-sm">
        {label}
        {required ? ' *' : ''}
      </span>
      {value ? (
        <div className="flex items-center gap-2 border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-bg)] text-sm">
          <span className="flex-1">
            {value.label || '(unnamed)'}
            <span className="ml-2 text-xs font-mono text-[color:var(--color-muted)]">
              {value.id.slice(0, 8)}…
            </span>
          </span>
          <button
            type="button"
            onClick={clear}
            className="text-xs text-[color:var(--color-muted)] hover:text-[color:var(--color-fg)]"
            aria-label="Clear producer"
          >
            ✕
          </button>
        </div>
      ) : (
        <input
          type="text"
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onBlur={() => {
            // Delay close so the click handler on the option can fire.
            setTimeout(() => setOpen(false), 150);
          }}
          placeholder={placeholder}
          required={required && !value}
          className="border border-[color:var(--color-border)] rounded px-2 py-1"
        />
      )}
      {open && !value && (
        <ul className="absolute top-full mt-1 left-0 right-0 z-10 max-h-64 overflow-y-auto border border-[color:var(--color-border)] rounded bg-[color:var(--color-surface)] shadow text-sm">
          {isFetching && <li className="px-2 py-1 text-[color:var(--color-muted)]">Loading…</li>}
          {!isFetching && (data?.length ?? 0) === 0 && (
            <li className="px-2 py-1 text-[color:var(--color-muted)]">No matches.</li>
          )}
          {data?.map((b) => (
            <li key={b.id}>
              <button
                type="button"
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => select(b)}
                className="block w-full text-left px-2 py-1 hover:bg-[color:var(--color-bg)]"
              >
                <span>{preferredName(b.name) || '(unnamed)'}</span>
                <span className="ml-2 text-xs font-mono text-[color:var(--color-muted)]">
                  {b.id.slice(0, 8)}…
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
