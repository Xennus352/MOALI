# MOALI / LBVD — Deployment Guide

This document describes how to deploy the census system beyond the developer
laptop. It focuses on a **single-host, reverse-proxied** deployment, which is
the topology the WebSocket architecture supports out of the box.

> **Current status:** the repository is a fully-working *local* system. No
> HTTPS, reverse proxy, or managed hosting has been validated in this
> repository yet — everything in this file is normative guidance, not a claim
> that production has been exercised.

---

## 1. Reference topology

```
                 ┌────────────────────────────────────────────┐
 Browser (react) │  Caddy/nginx :443  (TLS termination,        │
 Mobile (flutter)│  static React build, WS upgrade proxy)      │
                 └───────┬────────────────────────────────────┘
                         │ https://census.example.com/api/*  (wss upgrade)
                         ▼
                 ┌────────────────┐        ┌──────────────┐
                 │ uvicorn :8000  │  ────► │ MySQL :3306  │
                 │ (ONE worker)   │        └──────────────┘
                 └────────────────┘
```

- Frontend assets: build the React app (`cd client && pnpm build`) and serve
  `client/dist` from the reverse proxy.
- API + WebSocket: one `uvicorn` worker behind the proxy. The in-process
  real-time fan-out (see §3) is what constrains this to a single worker.

## 2. Environment (server/.env)

Production-friendly settings:

```dotenv
ENVIRONMENT=production
DEBUG=False
SECRET_KEY=<64+ random chars, fixed across restarts>
COOKIE_SAMESITE=lax
COOKIE_SECURE=True            # auto-set by ENVIRONMENT=production
FRONTEND_URL=https://census.example.com
DATABASE_URL=mysql+pymysql://moali:<strong>@db.example.com:3306/livestock_census?charset=utf8mb4

# Admin bootstrap is REFUSED in production unless explicitly provided:
ADMIN_EMAIL=root@example.com
ADMIN_PASSWORD=<strong>
ADMIN_NAME=Runbook Admin
ADMIN_NAME_EN=LBVD Census Admin
```

Notes:

- **Never** rely on the per-process fallback `SECRET_KEY` in production —
  every restart would invalidate all sessions. Set a fixed key.
- The startup bootstrap only creates an admin when the users table has none,
  and in production it is skipped entirely unless `ADMIN_EMAIL`/`ADMIN_PASSWORD`
  are set by the environment (the default dev password is refused).
- `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` are optional; the web "Sign in with
  Google" button returns 501 until they are configured and the redirect flow is
  exercised through `FRONTEND_URL`.

## 3. WebSocket — single-worker constraint

`server/app/api/v1/ws.py` keeps connected sockets in a process-local table and
fans out via `run_coroutine_threadsafe` on the event loop. This is **correct
for exactly one uvicorn worker** and wrong (silent misdelivery) for several.

Two options:

1. **Run one worker** (recommended here):
   `uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1`
2. **Scale horizontally**: replace the loop fan-out with Redis pub/sub
   (`redis.asyncio` pubsub, one subscriber per worker re-broadcasting to its
   local sockets). The event payload contract (§6 in README) does not change.

The HTTP API itself is stateless (sessions are signed tokens) and would scale
behind a load balancer with `--workers N`; only realtime restricts it to 1.

## 4. Reverse proxy (Caddy example)

```caddyfile
census.example.com {
    encode gzip

    # Static React build
    root * /srv/moali/client/dist
    try_files {path} /index.html

    # API + WebSocket upgrade
    handle_path /api/* {
        reverse_proxy 127.0.0.1:8000
        # Caddy enables HTTP/1.1 + WebSocket upgrades automatically.
    }
    handle_path /ws/* {
        reverse_proxy 127.0.0.1:8000
    }

    header {
        Strict-Transport-Security "max-age=31536000"
    }
}
```

If the React client is served from a different origin than the API, set both
`FRONTEND_URL` (CORS) and `VITE_WS_URL=wss://census.example.com/api/v1/ws` at
build time. When they share an origin, `VITE_WS_URL` is unnecessary — the
client derives `wss://<same-host>/api/v1/ws`.

### nginx equivalent

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```

(and a second `location /ws/` block with the same upgrade headers, or route
`/api/v1/ws` through the `location /api/` above.)

## 5. Operational checklist

```bash
cd server
uv run alembic upgrade head          # additive migrations
uv run pytest                        # 59 tests before every release
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1
```

- Backups: `mysqldump` the `livestock_census` database; restore into a fresh
  MySQL container, run `alembic upgrade head`, start the API.
- The demo seeder is `uv run python -m app.seed --demo --demo-count N` — never
  run it against production data.
- Audit logs are written by the app itself (`audit_logs` table) and are
  visible to admins; ship them to a log aggregator via the proxy access logs.

## 6. Flutter app deployment

- Release builds: `cd flutter_app && flutter build apk --release` (see
  `flutter build --help` for appbundle/ios).
- Point the app at the API with
  `flutter build apk --dart-define=API_BASE_URL=https://census.example.com`.
- HTTPS is mandatory for release builds on Android/iOS (cleartext HTTP is
  blocked by default outside the emulator).
- Drafts are stored on-device (`shared_preferences`); submissions survive the
  app being killed mid-survey and are deduplicated server-side (409 duplicate
  guard).

## 7. Not yet deployed / validated

- TLS / reverse proxy configuration above is guidance, not tested here.
- No CD/CI pipeline, container image for the API, or managed log/metrics.
- Google OAuth (web) stays 501 until credentials are configured; mobile
  Google sign-in needs a token-exchange endpoint (see IMPLEMENTATION_REPORT §12).