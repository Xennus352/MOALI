#!/bin/sh
# ---------------------------------------------------------------------------
# Container entrypoint: wait for MySQL, apply migrations, serve the API.
#
# Invoked as `/bin/sh /app/start.sh` from the Dockerfile, so it does not need
# the executable bit. Everything is driven by environment variables, which
# Railway injects (DATABASE_URL pointing at the MySQL service, PORT, ...).
# ---------------------------------------------------------------------------
set -e

PORT="${PORT:-8000}"

echo "[start] waiting for the database to accept connections..."
python - <<'PY'
import sys
import time

from sqlalchemy import create_engine, text

from app.core.config import settings

url = settings.DATABASE_URL
# Print only the host/database tail, never the credentials.
print(f"[start] database target: ...{url.split('@')[-1]}")

for attempt in range(1, 61):
    try:
        engine = create_engine(url, pool_pre_ping=True)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        engine.dispose()
        print("[start] database reachable")
        sys.exit(0)
    except Exception as exc:  # noqa: BLE001 - we retry anything transient
        print(f"[start] not ready yet ({attempt}/60): {type(exc).__name__}: {exc}")
        time.sleep(2)

sys.exit("[start] FATAL: database unreachable after 120s; check DATABASE_URL")
PY

echo "[start] applying migrations (alembic upgrade head)..."
alembic upgrade head

echo "[start] serving on 0.0.0.0:${PORT} with a single uvicorn worker"
exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port "${PORT}" \
    --workers 1 \
    --proxy-headers \
    --forwarded-allow-ips "*"
