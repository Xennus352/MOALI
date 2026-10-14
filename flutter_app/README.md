# MOALI / LBVD Census — Flutter enumerator app

Mobile client for the livestock-census system. Talks to the FastAPI backend
(repo root: `server/`) over REST + WebSocket; session auth uses the HMAC-signed
`moali_session` cookie.

## Features

- **Login / self-registration** against `POST /api/v1/auth/{login,register}`,
  session restore via `GET /api/v1/auth/me`, explicit logout.
- **Dashboard & submission history** with real KPIs from
  `/api/v1/dashboard/kpi` and `/api/v1/dashboard/recent`.
- **Admin-driven census survey** (`lib/survey/`) — the form is rendered from the
  published definition in `GET /api/v1/meta/form/current`, not hard-coded:
  sections, titles, labels, field types, required flags and option sources come
  from the backend, and every select resolves its options from the
  admin-managed master data (`/api/v1/master/*`, `/api/v1/meta/geography`).
  Adding a field/section/township/animal type in the console needs no app
  redeploy.
  - Renders geographic cascades (region→district→township→tract→ward),
    text/phone/email/date/number selects and booleans, and repeating groups
    (livestock / poultry / breeding tables) built from live reference data.
  - Unknown or newly added admin fields render generically and are submitted via
    `additional_data`, which the backend stores as typed field answers.
  - Counts persist through `POST /api/v1/submissions`. Duplicate submissions
    (409) offer an intentional re-survey via `allow_duplicate`.
- **Drafts**: every change is persisted to `shared_preferences` and restored on
  reopen; discard with the app-bar delete action.
- **Real-time**: `web_socket_channel` connects to `WS /api/v1/ws?token=<session>`
  and refreshes the dashboard when an event arrives (own submissions +
  admin/reviewer broadcasts).

## Run

```bash
flutter pub get
flutter run                       # emulator → http://10.0.2.2:8000
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000   # device
flutter analyze
flutter test
flutter build apk --debug
```

See the repo-root `README.md` for the full stack, and
`IMPLEMENTATION_REPORT.md` for an honest implemented/partial/not list.