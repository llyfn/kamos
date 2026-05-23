import { fileURLToPath, URL } from 'node:url';
import { TanStackRouterVite } from '@tanstack/router-plugin/vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [
    TanStackRouterVite({
      routesDirectory: 'src/routes',
      generatedRouteTree: 'src/routeTree.gen.ts',
      routeFileIgnorePattern: '\\.test\\.(t|j)sx?$',
    }),
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5174,
    strictPort: true,
    // Local mirror of the production same-origin model: the SPA calls
    // relative /v1/* (VITE_API_BASE_URL empty in .env.development) and the
    // dev server proxies to the local API. Keeps the admin's SameSite=Strict
    // cookies first-party on localhost:5174 — no CORS, no cross-site cookies.
    proxy: {
      '/v1': {
        target: process.env.KAMOS_DEV_API ?? 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
});
