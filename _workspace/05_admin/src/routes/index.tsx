import { createFileRoute, redirect } from '@tanstack/react-router';
import { getAccessToken } from '@/lib/tokens';

export const Route = createFileRoute('/')({
  beforeLoad: () => {
    if (getAccessToken()) {
      throw redirect({ to: '/queue' });
    }
    throw redirect({ to: '/login' });
  },
});
