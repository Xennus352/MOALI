# MOALI / LBVD Census — Admin & field console (React)

Web control room for the livestock-census system. React 18 + Vite + Tailwind +
TypeScript, talking to the FastAPI backend (`server/`) through `src/lib/api.ts`.

## Pages

| Route | Purpose |
| --- | --- |
| `/dashboard` | Live KPI band + trends + recent activity (WebSocket auto-refresh) |
| `/census-responses/new` | Data-entry form **rendered from the admin-published definition** (`/meta/form/current`) + live master-data options — nothing is hard-coded |
| `/census-responses` | List / detail / review / filters / CSV export · **infinite scroll** (page-based loader) |
| `/form-builder` | Create form versions, edit **sections and fields** (add/remove inputs, bind master data), publish |
| `/database` | Master-data CRUD — the option lists that feed every form dropdown (state/region → ward, genders, categories, species, age groups, breeding categories, …) |
| `/users` | User administration (server-enforced RBAC) · **infinite scroll** |
| `/analytics`, `/reports` | Real series from `/api/v1/dashboard/trends` + exports |
| `/security`, `/settings` | Password, session revocation, audit log · **infinite scroll** on the audit trail |
| `/messages` | Notification inbox |

## Quality

```bash
pnpm lint
pnpm build           # tsc -b && vite build
pnpm dev             # http://localhost:5173
```

The dashboard keeps the gpt-tasteskill design language (Satoshi display font,
KPI band, 3×2 bento grid); charts are dependency-free inline SVG built from the
real `/dashboard/trends` data.

## Real-time

`src/lib/realtime.tsx` opens `WS /api/v1/ws` (session cookie), shows a
live-connection badge, and invalidates dashboard/submission/user caches so the
UI updates without a manual reload. Default WS URL is
`ws(s)://<host>:8000/api/v1/ws`; override with `VITE_WS_URL`.

See repo-root `README.md` for the full stack.