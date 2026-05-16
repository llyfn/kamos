import { createFileRoute } from '@tanstack/react-router';

export const Route = createFileRoute('/users')({
  component: () => (
    <div>
      <h1 className="text-xl font-semibold mb-4">Users</h1>
      <p className="text-[color:var(--color-muted)] text-sm">Coming in commit 4.</p>
    </div>
  ),
});
