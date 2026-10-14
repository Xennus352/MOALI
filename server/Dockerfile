# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# MOALI / LBVD API — production image (Railway and any other Docker host).
#
# The image builds from the `server/` directory alone, so on Railway set the
# service "Root Directory" to `server`. Runtime layout:
#
#   /app        app/, alembic/, alembic.ini, start.sh
#   /usr/local  uv-managed virtualenv (uvicorn, alembic on PATH)
#
# Only the pure-Python PyMySQL driver talks to MySQL, so no system MySQL
# client libraries or compilers are needed: every dependency (cryptography,
# argon2-cffi, pymysql) ships a manylinux wheel.
# ---------------------------------------------------------------------------
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/usr/local

# uv is this project's package manager (pyproject.toml [tool.uv]); pin the same
# version the lock file was created with so `--frozen` always validates.
COPY --from=ghcr.io/astral-sh/uv:0.12.22 /uv /uvx /bin/

WORKDIR /app

# 1) Dependency layer — cached until pyproject.toml / uv.lock change.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project --no-dev

# 2) Application layer.
COPY . .
RUN uv sync --frozen --no-dev

# Run unprivileged; the container writes nothing to disk at runtime.
RUN useradd --create-home --uid 10001 appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

# start.sh waits for MySQL, runs `alembic upgrade head`, then serves ONE
# uvicorn worker (the realtime fan-out in app/api/v1/ws.py is process-local —
# see DEPLOYMENT.md §3). Railway injects $PORT.
ENTRYPOINT ["/bin/sh", "/app/start.sh"]
