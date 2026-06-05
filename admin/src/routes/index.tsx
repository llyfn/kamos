import { createFileRoute, redirect } from '@tanstack/react-router';

// Auth state lives in HttpOnly cookies, so we can't synchronously
// inspect "is logged in" before the route activates. Always redirect to
// /queue; the route's own guards push the operator back to /login when
// the session has lapsed.
export const Route = createFileRoute('/')({
  beforeLoad: () => {
    throw redirect({ to: '/queue' });
  },
});
