import type { ReactNode } from 'react';

interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}

export function Modal({ open, onClose, title, children }: ModalProps) {
  if (!open) return null;
  return (
    <div
      className="fixed inset-0 bg-black/40 flex items-center justify-center z-40 p-4"
      onClick={onClose}
      onKeyDown={(e) => {
        if (e.key === 'Escape') onClose();
      }}
      // biome-ignore lint/a11y/useSemanticElements: native <dialog> would change focus/scroll semantics; revisit when this modal pattern is consolidated
      role="dialog"
      aria-modal="true"
    >
      <div
        className="bg-[color:var(--color-surface)] rounded shadow-lg w-full max-w-lg p-5"
        onClick={(e) => e.stopPropagation()}
        onKeyDown={(e) => e.stopPropagation()}
        role="document"
      >
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold">{title}</h2>
          <button
            type="button"
            onClick={onClose}
            className="text-[color:var(--color-muted)] hover:text-[color:var(--color-fg)]"
            aria-label="close"
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
