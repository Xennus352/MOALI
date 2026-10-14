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
- The container image in §8 builds and boots, but no Railway project has been
  exercised from this repository yet.
- No CD/CI pipeline or managed log/metrics.
- Google OAuth (web) stays 501 until credentials are configured; mobile
  Google sign-in needs a token-exchange endpoint (see IMPLEMENTATION_REPORT §12).

---

## 8. Railway (GitHub-connected, Docker)

Railway runs each service from its own Docker image. This repository ships the
two pieces the API needs:

```
server/Dockerfile      # FastAPI + Alembic + uvicorn, one worker
server/start.sh        # wait for MySQL -> alembic upgrade head -> uvicorn
server/railway.json    # builder + healthcheck, read from the service root
server/.dockerignore   # keeps .venv/.env/__pycache__ out of the image
```

MySQL is **not** built by you: add Railway's managed MySQL service (it is a
`mysql:8` container with a persistent volume). It publishes connection variables
that the API service references, so no credentials live in the repo.

### 8.1 Push to GitHub

`server/Dockerfile`, `server/start.sh`, `server/railway.json`,
`server/.dockerignore`, the `config.py` change and this file must be committed:

```bash
git add server/Dockerfile server/start.sh server/railway.json \
        server/.dockerignore server/app/core/config.py .gitignore DEPLOYMENT.md
git commit -m "Add Railway/Docker deployment for the API service"
git push origin main
```

Tracked `__pycache__`/`.pyc` files predate this change; `.dockerignore` already
keeps them out of the image. To stop tracking them:

```bash
git rm -r --cached server/__pycache__ server/app/__pycache__ \
    server/moali_server.egg-info
```

### 8.2 Create the project

1. <https://railway.com> → **New Project → Deploy from GitHub repo** → pick
   `Xennus352/MOALI` and authorise the Railway GitHub App.
2. **New → Database → MySQL** (in the *same* project).
3. Open the API service → **Settings**:
   - **Root Directory** = `server`  ← the image builds from `server/` only
   - Railway detects `railway.json` and builds `server/Dockerfile`.

### 8.3 Wire the database

On the **API** service → **Variables → New Variable**:

```
DATABASE_URL = ${{MySQL.MYSQL_URL}}
```

`MySQL` must match the MySQL service name exactly (case-sensitive).
`MYSQL_URL` is `mysql://user:pass@host:port/db`; `app/core/config.py` rewrites it
to the installed `mysql+pymysql://` driver and appends `charset=utf8mb4`, so it
works as-is. This talks over Railway's private network — the database stays
unexposed. (Referencing the parts, `${{MySQL.MYSQLHOST}}` etc., also works; if
you build the URL by hand, percent-encode the password.)

### 8.4 Required variables on the API service

```
ENVIRONMENT=production
DEBUG=False
SECRET_KEY=<64+ random chars, fixed across restarts>
ADMIN_EMAIL=<your admin login>
ADMIN_PASSWORD=<strong, not Admin@12345>
ADMIN_NAME=System Administrator
ADMIN_NAME_EN=LBVD Census Admin
FRONTEND_URL=https://<your console origin>
CORS_ORIGINS=https://<your console origin>
```

- `ENVIRONMENT=production` forces `COOKIE_SECURE`; `start.sh` runs uvicorn with
  `--proxy-headers`, so Railway's TLS terminator makes `https`/`wss` URLs resolve
  correctly.
- Do **not** set `PORT`/`HOST` — Railway injects `PORT` and `start.sh` binds it.
- Set `FRONTEND_URL`/`CORS_ORIGINS` to the deployed console origin, otherwise the
  browser console is blocked by CORS. `CSP_CONNECT_SRC` only needs extra entries
  if the WebSocket lives on a different host.
- If the users table is empty, startup creates the admin from `ADMIN_EMAIL`/
  `ADMIN_PASSWORD`; with the default dev password in production it refuses (safe).

### 8.5 Deploy and verify

Railway redeploys on every push to `main`. Read the deploy log; it should end
with:

```
[start] database reachable
[start] applying migrations (alembic upgrade head)...
[start] serving on 0.0.0.0:8000 with a single uvicorn worker
INFO:     Application startup complete.
```

Then, from the service's **Settings → Networking → Generate Domain**:

```bash
curl -s https://<service>.up.railway.app/health
# {"status":"ok","database":true}
```

Interactive docs: `https://<service>.up.railway.app/docs`.

### 8.6 Constraints that still apply

- **One worker.** `start.sh` pins `--workers 1`; the realtime fan-out in
  `app/api/v1/ws.py` is process-local (§3). Scaling out requires Redis pub/sub.
- **In-memory rate limiting.** `RateLimitMiddleware` counts per process; with a
  single worker that is correct, but do not scale to N replicas without a shared
  store.
- **Migrations run on deploy.** `alembic upgrade head` executes once per
  container start; migrations are additive (§5 of README) and safe to re-run.

### 8.7 Point the mobile app at it

```bash
cd flutter_app
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<service>.up.railway.app
```

HTTPS is required for release builds (see §6).