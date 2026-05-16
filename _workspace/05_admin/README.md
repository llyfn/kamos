# KAMOS Admin

Operator console for KAMOS. Moderator/admin only — shares `/v1/auth/login`
with the user app and gates every route on `users.role in {moderator,admin}`.

## Stack

- React 19 + Vite 6
- TanStack Router (file-based) + TanStack Query
- Tailwind CSS v4 (CSS-first config)
- TypeScript 5.7 (strict)
- `openapi-typescript` + `openapi-fetch` (typed client from backend's `openapi.yaml`)
- Vitest 2
- Biome (lint + format)

## Dev workflow

```sh
npm install          # or: bun install
npm run codegen      # regenerate src/types/api.d.ts from ../02_backend/api/openapi.yaml
npm run dev          # http://localhost:5174
npm run build        # tsc + vite build
npm run test
```

The kamos-api server is expected on `http://localhost:8080` (override with
`VITE_API_BASE_URL` in `.env.local`).

## Path rule

This is the admin codebase under the workspace path. It is intentionally
separate from `_workspace/03_frontend/` (Flutter mobile) and from the backend.
Per `.claude/CLAUDE.md`, if `admin/` is later promoted to the repo root, write
production code there and stop writing here.
