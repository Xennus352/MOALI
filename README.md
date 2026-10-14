# MOALI / LBVD Livestock Census Management System

A livestock-census platform for the Ministry of Agriculture, Livestock and
Irrigation (MOALI) — Department of Livestock Breeding and Veterinary (LBVD) —
with three front-ends around one API:

| Component | Path | Stack |
| --- | --- | --- |
| Admin & field-web console | `client/` | React 18 + Vite + Tailwind (TypeScript) |
| Enumerator mobile app | `flutter_app/` | Flutter (Material 3) — Burmese-first |
| API / backend | `server/` | FastAPI + SQLAlchemy 2 + Alembic + MySQL 8 |

Everything below is **verified working** in this repository (see
[IMPLEMENTATION_REPORT.md](./IMPLEMENTATION_REPORT.md) for the honest
implemented / partial / not-implemented matrix).

---

## 1. Architecture at a glance

```
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ React console │   │ Flutter app   │   │  curl / API   │
└──────┬────────┘   └───────┬───────┘   └───────┬───────┘
       │  REST + WS         │  REST + WS        │
       ▼                    ▼                   ▼
                     ┌──────────────┐
                     │  FastAPI     │  uvicorn :8000
                     │  (auth, RBAC,│  HMAC-signed httpOnly
                     │  rate-limit) │  session cookie
                     └──────┬───────┘
                            │ SQLAlchemy 2 (utf8mb4)
                            ▼
                     ┌──────────────┐
                     │  MySQL 8     │  Docker :3306
                     └──────────────┘
```

- **Auth**: HMAC-SHA256-signed, httpOnly, SameSite=Lax session cookie
  (`moali_session`). Argon2id password hashing; per-user `session_version`
  enables revocation. In development, an unset `SECRET_KEY` rotates per
  process — restarting the backend logs everyone out (expected dev behaviour).
- **RBAC**: `admin` vs `enumerator`. Admin-only: user management, master-data
  writes, audit logs, review actions. Enumerators can submit and see their own
  work; permissions are enforced server-side, never by the UI.
- **Real-time**: one authenticated WebSocket per client at
  `WS /api/v1/ws` (cookie for browsers, `?token=<session-token>` for mobile).
  Fan-out is in-process asyncio — correct for the documented single-worker
  deployment. Events: `submission.created`, `submission.status_changed`,
  `user.changed`.
- **Migrations**: additive, inspector-guarded Alembic migrations only. The
  database is never dropped or reset.

## 2. Quick start (local)

### 2.1 MySQL

```bash
docker compose up -d db          # or: docker start moali-mysql
```

Connects as `moali:password@127.0.0.1:3306/livestock_census` (utf8mb4).

### 2.2 Backend (port 8000)

```bash
cd server
python -m venv .venv && source .venv/bin/activate   # Python 3.12
uv pip install -e .[dev]                            # or: pip install -e ".[dev]"

cp .env.example .env                                # optional
uv run alembic upgrade head                         # apply migrations
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

On first startup the lifespan (a) runs `Base.metadata.create_all` as a safety
net, (b) **seeds reference data + the published census form only when the
corresponding tables are empty** (idempotent), and (c) bootstraps the first
admin from `ADMIN_EMAIL` / `ADMIN_PASSWORD`.

Health check: `curl http://localhost:8000/api/v1/health`.

### 2.3 React console (port 5173)

```bash
cd client
pnpm install
pnpm dev            # http://localhost:5173 (proxies API + WS to :8000)
```

Quality gates: `pnpm lint`, `pnpm build` (tsc + vite). For distributed
deployments set `VITE_WS_URL=wss://<host>/api/v1/ws` — by default the client
derives `ws(s)://<same-host>:8000/api/v1/ws`.

**Admin-driven forms.** Nothing about the survey is hard-coded in the client.
`/census-responses/new` renders its sections, fields, labels, required flags and
types from the published definition at `/api/v1/meta/form/current`, and every
dropdown option (state/region → ward, genders, animal categories, species, age
groups, breeding categories) from master data. The `/form-builder` page authors
sections/fields and `/database` manages the option lists, so an administrator
can add or remove inputs and options and the change appears on web **and** mobile
with no redeploy. Inputs the admin adds beyond the fixed schema are stored as
typed `additional_data` answers.

### 2.4 Flutter app

```bash
cd flutter_app
flutter pub get
flutter run                        # emulator → http://10.0.2.2:8000
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000   # physical device
```

The app renders the **admin-defined census survey** from
`GET /api/v1/meta/form/current` — sections, labels, field types and select
options all come from the backend/master data, so adding an input, section or
township in the console needs **no app redeploy**. It also has local draft
persistence via `shared_preferences`, `additional_data` submission for
admin-added fields, duplicate-submission handling, and a live event channel
(`web_socket_channel`, session token passed as `?token=`).

## 3. Default credentials

Bootstrap creates `admin@moali.gov.mm` / `Admin@12345` in development
(`ADMIN_EMAIL` / `ADMIN_PASSWORD` in `server/.env`). **In production the
bootstrap is refused** unless the credentials are explicitly provided by the
environment.

## 4. Seeding

- **Reference data & published form** — auto-seeded at startup when empty
  (genders, animal types/species/breeds, age groups/types, breeding
  categories, 15 state/regions, published census form v1). Workbook
  identifiers (`laID01`, `atID01`, `g01`, …) are preserved verbatim in the
  `code` columns.
- **Geography below region** (districts/townships/village tracts/wards) is
  loaded **from the authoritative `seed_geography` data** and is *not*
  fabricated by any client. Manage or fix it in the master-data UI.
- **Demo submissions** are opt-in:
  `cd server && uv run python -m app.seed --demo --demo-count N` (never for
  production).

## 5. Migrations & schema changes

All migrations live in `server/alembic/versions/` and are applied with
`uv run alembic upgrade head`. The current chain:

```
e61d735e4805  initial schema
a1b2c3d4e5f6  auth & submission columns
b2c3d4e5f6a7  person age columns
c3d4e5f6a7b8  widen geography codes → varchar(50)
a3f92c4d01b0  add species_id to submission animal counts
```

New columns are added with inspector-guarded migrations — never destructive.
If you need a new migration: `uv run alembic revision -m "description"`.

## 6. Test suites

```bash
cd server && uv run pytest          # 59 tests (SQLite, isolated; never MySQL)
cd client && pnpm lint && pnpm build
cd flutter_app && flutter analyze && flutter test
```

Key coverage: auth/session revocation, RBAC matrix, security headers, rate
limit, submission review workflow + duplicate 409, master-data partial PATCH,
geography hierarchy CRUD, realtime channel (auth reject, admin fan-out,
enumerator scope), dashboard KPI integrity.

## 7. WebSocket event contract

| Event | Payload highlights | Recipients |
| --- | --- | --- |
| `submission.created` | `id`, `household_no`, `township_id`, `collection_status` | admins/reviewers **and the submitter** |
| `submission.status_changed` | `id`, `household_no`, `action`, `review_status` | admins/reviewers **and the record's creator** |
| `user.changed` | `id`, `email`, `role`, `is_active` | admins only |

Recipients are matched as *explicit recipient OR role* (admin/reviewer), so an
enumerator hears about their own submissions without receiving admin events.

## 8. Directory layout

```
├── client/            React admin console
│   └── src/
│       ├── components/    UI kit, layout, charts (dependency-free SVG)
│       ├── pages/         dashboard, submissions, census-submit, users,
│       │                  master-data, analytics, reports, security, …
│       ├── features/form-builder/
│       ├── lib/           api client, realtime provider/badge
│       └── App.tsx
├── flutter_app/
│   ├── lib/
│   │   ├── api/api_client.dart        cookie-session HTTP client
│   │   ├── survey/survey_models.dart  draft + reference models
│   │   ├── survey/survey_screen.dart  definition-driven survey wizard
│   │   ├── realtime/realtime_service.dart
│   │   └── main.dart                  auth gate, dashboard, history
│   └── pubspec.yaml
├── server/
│   ├── app/
│   │   ├── api/v1/      routers: auth, forms, submissions, users, master,
│   │   │                dashboard, ws (realtime), meta, …
│   │   ├── core/        config, security, session, passwords
│   │   ├── db/          models, base
│   │   ├── schemas/     pydantic contracts
│   │   └── seed.py      idempotent workbook-derived reference data
│   ├── alembic/         migration chain (additive only)
│   ├── tests/           67 passing tests
│   └── pyproject.toml
├── docker-compose.yml   MySQL 8
└── IMPLEMENTATION_REPORT.md   verified status per requirement
```

## 9. Notes for production

- Set a **fixed `SECRET_KEY`** and `ENVIRONMENT=production` (forces
  `COOKIE_SECURE` and refuses default-admin bootstrap).
- The WebSocket fan-out is in-process: deploy exactly **one** uvicorn worker, or
  introduce Redis pub/sub (see `server/app/api/v1/ws.py`).
- See [DEPLOYMENT.md](./DEPLOYMENT.md) for reverse proxy / TLS / deployment
  guidance.# MOALI
