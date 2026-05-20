import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createFileRoute } from '@tanstack/react-router';
import { type FormEvent, useState } from 'react';
import { RoleGuard } from '@/components/guard';
import { Modal } from '@/components/modal';
import { useToast } from '@/components/toast';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import type { components } from '@/types/api';

type AdminUser = components['schemas']['AdminUser'];
type Role = components['schemas']['UserRole'];

export const Route = createFileRoute('/users')({
  component: GuardedUsersPage,
});

function GuardedUsersPage() {
  return (
    <RoleGuard requires={['admin', 'moderator']}>
      <UsersPage />
    </RoleGuard>
  );
}

function UsersPage() {
  const { isAdmin } = useAuth();
  const [cursor, setCursor] = useState<string | null>(null);
  const [roleFilter, setRoleFilter] = useState<Role | ''>('');
  const [includeDeleted, setIncludeDeleted] = useState(false);

  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin', 'users', cursor, roleFilter, includeDeleted],
    queryFn: async () => {
      const query: {
        cursor?: string;
        role?: Role;
        include_deleted?: '0' | '1';
      } = {};
      if (cursor) query.cursor = cursor;
      if (roleFilter) query.role = roleFilter;
      if (includeDeleted) query.include_deleted = '1';
      const { data: page, error } = await api.GET('/v1/admin/users', { params: { query } });
      if (error || !page) throw new Error('failed_to_load_users');
      return page;
    },
  });

  return (
    <div>
      <h1 className="text-xl font-semibold mb-4">Users</h1>

      <div className="flex gap-3 items-center text-sm mb-3">
        <label className="flex items-center gap-1">
          <span className="text-[color:var(--color-muted)]">Role</span>
          <select
            value={roleFilter}
            onChange={(e) => {
              setRoleFilter(e.target.value as Role | '');
              setCursor(null);
            }}
            className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)]"
          >
            <option value="">all</option>
            <option value="user">user</option>
            <option value="moderator">moderator</option>
            <option value="admin">admin</option>
          </select>
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
          <span>include suspended</span>
        </label>
      </div>

      {isLoading && <p className="text-sm text-[color:var(--color-muted)]">Loading…</p>}
      {isError && <p className="text-sm text-red-700">Failed to load users.</p>}
      {data && (
        <>
          <div className="border border-[color:var(--color-border)] rounded bg-[color:var(--color-surface)] overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-[color:var(--color-bg)] text-left">
                <tr>
                  <th className="p-2">Username</th>
                  <th className="p-2">Email</th>
                  <th className="p-2">Role</th>
                  <th className="p-2">Created</th>
                  <th className="p-2">Deleted</th>
                  <th className="p-2 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {data.items.length === 0 && (
                  <tr>
                    <td
                      colSpan={6}
                      className="p-6 text-center text-[color:var(--color-muted)]"
                    >
                      No users.
                    </td>
                  </tr>
                )}
                {data.items.map((u) => (
                  <UserRow key={u.id} user={u} isAdmin={isAdmin} />
                ))}
              </tbody>
            </table>
          </div>
          <div className="mt-3 flex justify-end gap-2 text-sm">
            <button
              type="button"
              disabled={!cursor}
              onClick={() => setCursor(null)}
              className="px-3 py-1 border border-[color:var(--color-border)] rounded disabled:opacity-40"
            >
              First
            </button>
            <button
              type="button"
              disabled={!data.has_more}
              onClick={() => setCursor(data.next_cursor ?? null)}
              className="px-3 py-1 border border-[color:var(--color-border)] rounded disabled:opacity-40"
            >
              Next →
            </button>
          </div>
        </>
      )}
    </div>
  );
}

function UserRow({ user, isAdmin }: { user: AdminUser; isAdmin: boolean }) {
  const [modal, setModal] = useState<'role' | 'suspend' | null>(null);
  return (
    <>
      <tr className="border-t border-[color:var(--color-border)]">
        <td className="p-2 align-top">{user.display_username}</td>
        <td className="p-2 align-top text-[color:var(--color-muted)]">{user.email}</td>
        <td className="p-2 align-top">{user.role}</td>
        <td className="p-2 align-top whitespace-nowrap text-[color:var(--color-muted)]">
          {new Date(user.created_at).toLocaleString()}
        </td>
        <td className="p-2 align-top whitespace-nowrap text-[color:var(--color-muted)]">
          {user.deleted_at ? new Date(user.deleted_at).toLocaleString() : '—'}
        </td>
        <td className="p-2 align-top text-right whitespace-nowrap">
          <button
            type="button"
            onClick={() => setModal('role')}
            disabled={!isAdmin}
            className="px-2 py-1 border border-[color:var(--color-border)] rounded text-xs mr-1 disabled:opacity-40"
            title={isAdmin ? '' : 'admin only'}
          >
            Change role
          </button>
          <button
            type="button"
            onClick={() => setModal('suspend')}
            disabled={!isAdmin || user.deleted_at != null}
            className="px-2 py-1 bg-red-700 text-white rounded text-xs disabled:opacity-40"
            title={isAdmin ? '' : 'admin only'}
          >
            Suspend
          </button>
        </td>
      </tr>
      {modal === 'role' && <RoleModal user={user} onClose={() => setModal(null)} />}
      {modal === 'suspend' && <SuspendModal user={user} onClose={() => setModal(null)} />}
    </>
  );
}

function RoleModal({ user, onClose }: { user: AdminUser; onClose: () => void }) {
  const toast = useToast();
  const qc = useQueryClient();
  const [role, setRole] = useState<Role>(user.role);
  const [error, setError] = useState<string | null>(null);

  const mut = useMutation({
    mutationFn: async () => {
      const { data, error: err, response } = await api.POST(
        '/v1/admin/users/{id}/role',
        { params: { path: { id: user.id } }, body: { role } },
      );
      if (err || !data) throw new Error(`role_update_failed_${response.status}`);
      return data;
    },
    onSuccess: () => {
      toast.push('Role updated');
      qc.invalidateQueries({ queryKey: ['admin', 'users'] });
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    mut.mutate();
  }

  return (
    <Modal open onClose={onClose} title={`Change role — ${user.display_username}`}>
      <form onSubmit={onSubmit} className="flex flex-col gap-3 text-sm">
        <label className="flex flex-col gap-1">
          <span className="text-[color:var(--color-muted)]">Role</span>
          <select
            value={role}
            onChange={(e) => setRole(e.target.value as Role)}
            className="border border-[color:var(--color-border)] rounded px-2 py-1"
          >
            <option value="user">user</option>
            <option value="moderator">moderator</option>
            <option value="admin">admin</option>
          </select>
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
            disabled={mut.isPending || role === user.role}
            className="px-3 py-1 bg-[color:var(--color-accent)] text-white rounded disabled:opacity-50"
          >
            {mut.isPending ? 'Saving…' : 'Save'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function SuspendModal({ user, onClose }: { user: AdminUser; onClose: () => void }) {
  const toast = useToast();
  const qc = useQueryClient();
  const [error, setError] = useState<string | null>(null);

  const mut = useMutation({
    mutationFn: async () => {
      const { error: err, response } = await api.POST('/v1/admin/users/{id}/suspend', {
        params: { path: { id: user.id } },
      });
      if (err || response.status !== 204) throw new Error(`suspend_failed_${response.status}`);
    },
    onSuccess: () => {
      toast.push(`Suspended ${user.display_username}`);
      qc.invalidateQueries({ queryKey: ['admin', 'users'] });
      onClose();
    },
    onError: (e: Error) => setError(e.message),
  });

  return (
    <Modal open onClose={onClose} title={`Suspend ${user.display_username}?`}>
      <p className="text-sm mb-3">
        This soft-deletes the account, holds the username for 30 days, and immediately
        revokes the user's outstanding access tokens.
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
          type="button"
          onClick={() => mut.mutate()}
          disabled={mut.isPending}
          className="px-3 py-1 bg-red-700 text-white rounded text-sm disabled:opacity-50"
        >
          {mut.isPending ? 'Suspending…' : 'Suspend'}
        </button>
      </div>
    </Modal>
  );
}
