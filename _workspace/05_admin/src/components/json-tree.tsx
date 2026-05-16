import { useState } from 'react';

interface JsonTreeProps {
  value: unknown;
  initiallyOpen?: boolean;
}

export function JsonTree({ value, initiallyOpen = false }: JsonTreeProps) {
  const [open, setOpen] = useState(initiallyOpen);
  return (
    <div className="text-xs font-mono">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="text-[color:var(--color-muted)] hover:text-[color:var(--color-fg)]"
      >
        {open ? '▾ hide' : '▸ show'} payload
      </button>
      {open && (
        <pre className="mt-1 bg-[color:var(--color-bg)] border border-[color:var(--color-border)] rounded p-2 overflow-x-auto whitespace-pre-wrap break-words">
          {JSON.stringify(value, null, 2)}
        </pre>
      )}
    </div>
  );
}
