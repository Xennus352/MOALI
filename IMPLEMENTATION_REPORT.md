# MOALI / LBVD Livestock Census — Implementation Report

**Status date:** 2026-10-13
**Repository root:** `/home/kazue/Projects/Personal/moali` (no VCS)
**Stack:** FastAPI (Python 3.12) + SQLAlchemy 2 + Alembic · MySQL 8 (Docker) · React 18 + Vite + Tailwind · Flutter (Material 3)

**How to read this report:** every section states what is **implemented** (verified working
against the live system), what is **partial** (works with limitations), and what is **not
implemented**. Nothing here is claimed to be production-ready unless verified end to end.

---

## 1. Authentication & sessions

**Implemented**
- Cookie-based login flow: `POST /auth/login/cookie` sets an **HttpOnly**, **SameSite=Lax**
  cookie `moali_session`; the token is an **HMAC-SHA256-signed** payload (verified: cookie
  carries a `<payload>.<signature>` form, HttpOnly/SameSite attributes asserted in tests).
- Passwords hashed with **Argon2id** via `argon2-cffi` (default parameters; verified at login).
- **Session revocation**: `user.session_version` is embedded in the signed token and checked
  per request. Bumping it invalidates all existing sessions. Covered by:
  - self `change-password` (old cookie immediately returns 401 — tested),
  - admin `POST /users/{id}/reset-password` and `POST /users/{id}/revoke-sessions`.
- `GET /auth/me`, `POST /auth/logout` (clears cookie), self-registration (`POST /auth/register`)
  which **forces the low-privilege `enumerator` role** even if `role: "admin"` is posted (tested).
- Admin bootstrap from `ADMIN_EMAIL`/`ADMIN_PASSWORD` **refused in production** unless set by
  the environment; logs a warning instead of creating a default admin.

**Partial / limitations**
- Logout is client-side cookie clearing; there is no server-side token denylist (each token is
  self-contained). This is fine for this threat model, but a secret-store-backed session/token
  audit trail is not present.
- No email verification / account recovery flows.

## 2. Database & migrations

**Implemented**
- MySQL 8 in Docker, brought up via
  `docker start moali-mysql || docker run …` (`pnpm db:up` equivalent); connection string
  `mysql+pymysql://moali:password@127.0.0.1:3306/livestock_census?charset=utf8mb4`.
- **Additive, inspector-guarded Alembic migrations only.** Five migrations applied:
  - `e61d735e4805` initial schema
  - `a1b2c3d4e5f6` auth & submission columns
  - `a3f92c4d01b0` add species id
  - `b2c3d4e5f6a7` person age columns
  - `c3d4e5f6a7b8` widen geography codes to `varchar(50)`
- The database is **never dropped or reset**; every step is additive.
- Reference data (gender, animal types/species/breeds, age groups, state regions, published
  census form) is seeded at startup **only when the tables are empty** — idempotent.
- Synthetic/demo records are **opt-in** via `--demo --demo-count N` (never run in production).
  The working database used for validation holds 15 state regions, 1 published form, and **only
  real submissions** — the previously seeded demo rows (`H-1000…`) were removed on request.

**Partial**
- Schema drift is possible (the app also runs `Base.metadata.create_all`); Alembic remains the
  migration-of-record but is not verified in a fresh-team CI flow.
- Tests run on isolated SQLite; MySQL-specific behaviours (e.g. `ON DUPLICATE KEY`, fulltext)
  are not covered by the automated suite.

## 3. Admin console

**Implemented**
- `RequireAuth` + `AdminLayout` shell; sidebar footer "LBVD · National Livestock Census".
- **Dashboard** (`/dashboard`) consumes the **real** `/api/v1/dashboard/kpi`, `/trends`,
  `/recent` endpoints (verified: KPI counters move when rows are inserted — covered by tests).
  Stat cards (`value: string`, honest `delta` from the real series), recent-activity feed with
  action labels (`auth.login`, `submission.create`, `user.reset_password`, …) and hand-rolled
  SVG charts (no chart library) built from `/dashboard/trends`.
- Admin CRUD for users (`/users`), master data (`/master-data`), submissions
  (`/submissions`), analytics (`/analytics`, real KPI/trend data), reports (`/reports`, real
  CSV download), security (`/security`: change password, reset-password, revoke-sessions,
  audit log), settings (`/settings`: change password), messages (`/messages`, routed).
- **Form builder** (`/form-builder`): create forms, **edit sections**, and now **author
  fields** — add/delete inputs (`name`, bilingual titles, `field_type`, required, section,
  `option_source`, master-data `data_binding`, unit, numeric min/max, default value) saved
  through `PUT /forms/{id}/fields` and published as an immutable version. Submission detail
  and CSV export include the admin-authored `additional_data` values.
- **Real-time channel**: `WS /api/v1/ws` accepts the signed session cookie (or `?token=` for
  mobile), rejects unauthenticated/forged sessions with close code 4401, and fans out
  `submission.created` / `submission.status_changed` / `user.changed` events to connected
  clients after the REST transaction commits. Recipients are matched as **explicit user OR
  role** — admins/reviewers receive everything, and the *creator* of a submission also hears
  about their own record (submission.created confirmation, status_changed when reviewed),
  without receiving admin-only events. Fan-out happens on an in-process asyncio loop —
  correct for the documented single-worker deployment (Redis pub/sub would be needed for
  multiple workers; deliberately not introduced).
- The React dashboard connects automatically, shows a live-connection badge, and re-fetches
  KPI/trends/submissions on every event — no manual reload required (verified end to end).
- `tsc -b` and `vite build` both pass; no secrets compiled into the bundle.

## 4. Submission management

**Implemented**
- Create/read/list/detail/export for census submissions with animal counts (`animal_counts`),
  breeding counts ((`breeding_counts`), person age fields (`respondent_age`,
  `household_head_age`), geo hierarchy.
- **Duplicate protection**: same household + township + interview date + form version for a
  non-rejected record returns **409**; `allow_duplicate` explicitly re-surveys; a **rejected**
  submission may be re-surveyed (tested).
- Paginated listing with filters (`status`, date range, `q` search); township / state-region
  Burmese names surfaced on detail and recent feeds.
- Review workflow with a validated state machine
  (`pending/submitted → under_review → approved|rejected|returned → reopened`), admin-only,
  with review history on the record; invalid transitions return 409 (tested).
- Export CSV is `utf-8-sig`, protects against spreadsheet formula injection
  (`= + - @ tab cr`), and now includes `respondent_age` and `household_head_age` alongside the
  geography/status columns (verified on the live server).

## 5. Master data

**Implemented**
- Uniform CRUD for 14 resources: genders, age-groups, age-types, animal-types, animal-categories,
  species, breeds, breeding-categories, states/regions, districts, townships, village-tracts,
  wards, options — via a `_RESOURCES` registry.
- `GET /master/meta` returns per-resource field metadata consumed by the master-data UI
  (verified: `genders` exposes `code/burmese_name/english_name/display_order/is_active`).
- **True partial PATCH** semantics: the update handler now derives a schema where every field is
  optional and applies only `exclude_unset` keys (verified live: patching only `max_age` on an
  age-group preserves the Burmese name and other fields). This was a bug found by the test suite
  and fixed.
- Records are never hard-deleted: `DELETE` deactivates; `include_inactive` lists them (tested).
- Geography hierarchy endpoint `GET /meta/geography` returns regions with nested districts
  (tested by building a state-region→district→township chain through the API).

## 6. RBAC & security

**Implemented**
- Roles `admin` vs `enumerator`. `require_admin` guards users, master-data writes, audit logs;
  enumerators get 403; unauthenticated gets 401 (tested).
- **Security headers** middleware (verified on responses): `Content-Security-Policy` (self-only
  scripts), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, plus
  `X-` hardening.
- **Rate limiting**: sliding-window per-IP limiter; stricter window for auth endpoints
  (verified 429 + `Retry-After` live; unit-tested directly on `SlidingWindowLimiter` and via
  middleware with the public limiter).
- CORS confined to the frontend origin; audit log records actor, action, entity, IP for
  admin-visible review.
- Full-suite security exercised by 55 automated tests (see §9) including session revocation,
  tampered-cookie rejection, role escalation attempts, and 409 duplicate protection.

**Partial**
- Google OAuth is **not live**: `POST /auth/google` returns **501** until
  `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` are set. The web client wires the button to POST
  `/auth/google` and follow `authorization_url` when present, showing a clear error otherwise.
- No rate-limit back-end beyond an in-memory store (single-process only).

## 7. Reports & exports

**Implemented**
- `/reports` page with one-click **full CSV export** (`GET /api/v1/submissions/export.csv`),
  formula-injection protection, utf-8-sig encoding for Excel/Epi Info.
- CSV now carries person-age columns (verified live).
- Analytics page plots real `/dashboard/trends` series (by-region/by-township/by-status/
  by-animal-type/by-gender/breeding category).

**Not implemented**
- Scheduled/batched report jobs (email dispatch, recurring exports), PDF reporting, or
  aggregator-level exports are not present.

## 8. i18n — Burmese / English

**Partial**
- **Burmese native display of data throughout**: geography names, respondent names, and master
  data are stored/returned in Burmese and rendered by both web and Flutter clients.
- Login page claims "15 states & regions" and uses branding, all English.
- **No locale switcher or translated UI strings** for either the React or Flutter apps. Burmese
  labels are data-driven, not UI-localized. Scope was deliberately held back pending a
  translation decision.

## 9. Automated tests

**Implemented** — 67 backend tests, all passing, isolated SQLite + env-pinned settings (no production
DB touched); `cd client && pnpm lint && pnpm build` clean; `cd flutter_app && flutter analyze`
(*No issues found*) and `flutter test` green:
- `tests/test_auth.py` — login/register, Argon2 verification, HMAC-signed HttpOnly cookie,
  session revocation on password change, logout, role-escalation attempts.
- `tests/test_rbac.py` — 401/403 matrix, admin-only audit logs (both `/audit-logs` and the
  `/users/audit-logs` **alias**), security headers.
- `tests/test_submissions.py` — create, duplicate 409, `allow_duplicate`, re-survey after
  rejection, pagination/filters, full review workflow (including invalid transitions),
  CSV export shape incl. age columns, `additional_data` persisted as typed answers on
  create/update, and the CSV `additional_data` column.
- `tests/test_master_data.py` — `/master/meta`, create/deactivate, duplicate codes, **partial
  PATCH**, geo-hierarchy CRUD chain, and `/meta/form/current` exposing the renderable field
  contract (field types, option sources, data bindings).
- `tests/test_dashboard.py` — KPI counters move with real inserts; trends/recent shapes.
- `tests/test_rate_limit.py` — direct `SlidingWindowLimiter` unit tests + middleware 429.
- `tests/test_regressions.py` — the two defects that produced intermittent 500s: a non-JSON
  request body must return a clean **422** (not crash the handler with "Object of type bytes is
  not JSON serializable"), and `SessionLocal` must hand out a **fresh Session per call** (guards
  against reintroducing the thread-local `scoped_session` that corrupted MySQL connections).
- `tests/test_websocket.py` — real-time channel: unauthenticated/forged-token connections are
  closed with 4401, authenticated admin receives `submission.created` / `submission.status_changed`
  fan-out, enumerator connections are scoped, and the **record creator** receives their own
  submission events.
- Run with: `cd server && uv run pytest` (dev deps added: `pytest`, `httpx`).

**Found & fixed by the suite**
1. `/api/v1/users/audit-logs` was shadowed by `GET /users/{user_id}` (422 instead of 200) —
   the audit-log endpoint was **unreachable**; fixed by registering the route (plus alias)
   ahead of the path param.
2. Master-data PATCH rejected partial bodies (422); made partial-update semantics real.
3. CSV export lacked person-age columns; added.
4. Documented that logout/`/users` responses are paginated objects (test assertions aligned).

**Found & fixed while verifying in a real browser (Playwright)**
5. **Every client-side mutation failed.** The shared API client set `isForm = true` for any
   *string* body, and `JSON.stringify` always yields a string — so `Content-Type: application/json`
   was never attached. `fetch` fell back to `text/plain`, FastAPI could not parse the body, and
   the request 422'd (then 500'd — see #6). This silently affected submissions, form-builder
   saves, master-data create/edit, and user creation. Fixed in `client/src/lib/api.ts`.
6. **The `RequestValidationError` handler crashed** with `TypeError: Object of type bytes is not
   JSON serializable` whenever the raw body reached it as bytes, turning a 422 into a 500. Now the
   error payload is JSON-safe (`json.dumps(..., default=str)`).
7. **Intermittent MySQL 500s under concurrency** (`Packet sequence number wrong - got 1 expected 17`).
   `SessionLocal` was a thread-local `scoped_session`; FastAPI can run a sync dependency's teardown
   on a *different* threadpool thread, so `close()` targeted another thread's session and the real
   session's connection leaked, letting reused threads share one MySQL connection. `SessionLocal`
   is now a plain `sessionmaker` (fresh Session per request, closed regardless of thread). Verified
   with 240 concurrent requests → zero 500s.
8. **Web data-entry form is now admin-driven.** `client/src/pages/census-submit.tsx` was hard-coded;
   it now renders sections/fields from `/meta/form/current` and every option from master data
   (geographic cascade, genders, categories/species/age groups), with admin-added fields persisted
   through `additional_data`. Admin form/option changes now apply on the web with no redeploy.
9. **Users page crash** — `GET /api/v1/users` returns a paginated `{items:[…]}` object, but the page
   typed it as an array and called `.map()` on the object. Fixed the client to read `.items`.
10. **Demo data removed** — the 60 seeded demo submissions (`H-1000…`) and their counts were deleted
    from the working database, leaving only real records.

## 10. Flutter app

**Implemented** (compiles clean: `flutter analyze` → *No issues found*;
`flutter test` passes; release/debug APK builds succeed)
- Cookie-auth login **and** self-registration against the real backend API, session restore via
  `GET /auth/me`, explicit logout.
- Dashboard with real KPIs (`totalSubmissions`, `submissionsToday`, `approvedSubmissions`),
  recent submissions, and a **submission history** screen — no mock numbers.
- **Admin-driven census survey** (`lib/survey/`) — the form is **not hard-coded**: the screen
  fetches `GET /api/v1/meta/form/current` and renders whatever sections/fields the published
  form version defines. Section order/titles, labels, `field_type`, `is_required`,
  `option_source`, `data_binding`, units and numeric bounds all come from the definition, and
  every select resolves its options from the admin-managed master data
  (`/api/v1/master/*` + `/api/v1/meta/geography`). Adding a field, retitling a section, adding a
  township/animal type/species or creating a whole new form in the console is reflected in the
  app with **no redeploy**.
  - Field types rendered: geographic (cascading region→district→township→village tract→ward),
    short/long text, telephone, email, integer/number, decimal, date/datetime, single-select,
    boolean (gates the repeating tables that follow it), heading/paragraph, and
    `repeating_group` (livestock `animal_rows`, poultry `poultry_rows`, breeding `breeding_rows`).
  - Fixed-schema field names (household/person/geography/livestock) are grouped into the familiar
    wizard blocks; **any other admin-authored field** renders generically and is submitted through
    `additional_data`, which the backend stores as typed `FormFieldAnswer` rows and returns on the
    submission detail (`GET /api/v1/submissions/{id}`) and in the CSV export.
  - A field whose section was deleted is never dropped — it renders in a trailing "Other" step.
  - The payload is the backend `SubmissionCreate` contract and persists through
    `POST /api/v1/submissions` (duplicate 409 is surfaced with an **intentional re-survey**
    option via `allow_duplicate`). Submitted records come back with a success screen.
- **Drafts**: every keystroke is persisted locally (`shared_preferences`) and restored when
  the survey re-opens, so an interrupted census is never lost.
- **Real-time**: `web_socket_channel` client (`lib/realtime/`) connects to
  `WS /api/v1/ws?token=<session-token>` (mobile can't send a Cookie header), shows a
  live/connecting/offline indicator in the app bar, and triggers a debounced dashboard
  refresh when a server event arrives.
- Material 3 emerald (`#10B981`) / teal (`#008080`) branding, Noto Sans Myanmar via
  `google_fonts`, medium-light surfaces.
- Added brand identity: `_BrandSeal` (CustomPaint MOALI/LBVD emblem) replacing the generic
  placeholder icon, plus bundled `assets/moali_seal.svg` (placeholder emblem) and
  `assets/google.svg` (standard Google G), registered in `pubspec.yaml`.

**Partial / not implemented**
- **Google sign-in on mobile is not implemented.** The backend only supports the browser
  redirect flow (sets a cookie in the browser), which a mobile HTTP client cannot adopt, and
  has no token-exchange endpoint; it also returns 501 without OAuth credentials. Implementing
  this properly requires a backend `/auth/google/token` endpoint + Firebase configuration.
- `assets/moali_seal.svg` is a **placeholder** emblem; official MOALI/LBVD logo files were not
  provided, so official branding is pending original artwork.
- Survey UI strings are Burmese-first for the form itself (mirroring the paper form) and
  English elsewhere; no locale switcher yet (see §8).
- Flutter tests are limited to the generator smoke test (`widget_test.dart`) — the survey
  widget and the WebSocket client are not covered by widget/API tests against the backend.

## 11. Infrastructure & deployment

**Implemented (dev/local)**
- Docker MySQL; additive migrations; backend under `uv`/uvicorn on `127.0.0.1:8000`; Vite dev
  served on `5173`; Flutter web build artifacts under `flutter_app/build/web`.
- `.env`-driven configuration with safe defaults; no real secrets checked in; the Vite bundle
  contains no secrets.

**Not implemented / not verified**
- No HTTPS/TLS, no reverse proxy, no systemd/Docker Compose for the API, no CI/CD pipeline, no
  log aggregation or failover. Nothing here should be treated as **production-deployed** — it is
  a fully working local system with verified behaviour.

## 12. Known limitations & next steps

| Area | Status | Action |
| --- | --- | --- |
| Admin-driven mobile survey (sections/fields from the published form) | Implemented — renders `/meta/form/current` + master-data options; no redeploy on change | Field-test on Android/iOS devices |
| Admin-authored extra inputs | Implemented — form-builder “Add field” UI → `/forms/{id}/fields`; values persist as typed `FormFieldAnswer` rows via `additional_data` | Numeric min/max enforced client-side; optional server-side validation report |
| Flutter survey drafts / resume | Implemented — local `shared_preferences` | Optional backend draft-sync API |
| WebSocket ownership events | Implemented — creator hears `submission.created`/`status_changed` | Confirm with 2-device live test |
| Google OAuth (web redirect) | Partial — 501 without creds | Set `GOOGLE_CLIENT_ID/SECRET`; verify redirect→cookie handoff |
| Google sign-in (Flutter) | Not implemented | Add backend token-exchange endpoint + Firebase config |
| Official MOALI/LBVD logo files | Not implemented | Replace placeholder `moali_seal.svg` with official artwork |
| Burmese/English UI localization | Partial — data bilingual, UI English | Wrap UI strings in an i18n layer |
| CI/CD + Docker Compose for API | Not implemented | Next automation milestone |
| Server-side HTTPS/headers behind proxy | Not implemented | Deploy behind nginx/Caddy; re-verify headers |
| Flutter widget/API tests | Partial (generator smoke test only) | Add survey + realtime widget/API tests |
| Email verification / recovery | Not implemented | Design if required by MOALI |