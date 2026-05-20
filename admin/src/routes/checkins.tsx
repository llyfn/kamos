import { useMutation } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { RoleGuard } from '@/components/guard';
import { useToast } from '@/components/toast';
import { api } from '@/lib/api';

export const Route = createFileRoute('/checkins')({
  component: GuardedCheckinsPage,
});

function GuardedCheckinsPage() {
  return (
    <RoleGuard requires={['admin', 'moderator']}>
      <CheckinsPage />
    </RoleGuard>
  );
}

function CheckinsPage() {
  const toast = useToast();
  const [id, setId] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);

  const mut = useMutation({
    mutationFn: async () => {
      const body = notes.trim() ? { notes: notes.trim() } : undefined;
      const init = body ? { body } : {};
      const { error: err, response } = await api.POST('/v1/admin/check-ins/{id}/moderate', {
        params: { path: { id: id.trim() } },
        ...init,
      });
      if (err || response.status !== 204) throw new Error(`moderate_failed_${response.status}`);
    },
    onSuccess: () => {
      toast.push('Check-in moderated (soft-deleted)');
      setId('');
      setNotes('');
    },
    onError: (e: Error) => setError(e.message),
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    mut.mutate();
  }

  return (
    <div className="max-w-xl">
      <h1 className="text-xl font-semibold mb-2">Check-in moderation</h1>
      <p className="text-sm text-[color:var(--color-muted)] mb-4">
        Soft-delete a check-in by its UUID. A dedicated queue lands in Phase 6 along
        with comments moderation.
      </p>
      <form onSubmit={onSubmit} className="flex flex-col gap-3 text-sm">
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Check-in ID (uuid)</span>
          <input
            type="text"
            value={id}
            onChange={(e) => setId(e.target.value)}
            required
            className="border border-[color:var(--color-border)] rounded px-2 py-1 font-mono"
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Moderation notes (optional, ≤500)</span>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={500}
            rows={4}
            className="border border-[color:var(--color-border)] rounded px-2 py-1"
          />
        </label>
        {error && <p className="text-red-700 text-xs">{error}</p>}
        <div>
          <button
            type="submit"
            disabled={mut.isPending}
            className="px-3 py-2 bg-red-700 text-white rounded disabled:opacity-50"
          >
            {mut.isPending ? 'Moderating…' : 'Soft-delete check-in'}
          </button>
        </div>
      </form>
    </div>
  );
}
