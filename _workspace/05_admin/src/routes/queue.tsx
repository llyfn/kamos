import { createFileRoute } from '@tanstack/react-router';

export const Route = createFileRoute('/queue')({
  component: () => (
    <div>
      <h1 className="text-xl font-semibold mb-4">Beverage request queue</h1>
      <p className="text-[color:var(--color-muted)] text-sm">Coming in commit 3.</p>
    </div>
  ),
});
