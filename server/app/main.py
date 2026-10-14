# backend/server/app/main.py
"""FastAPI application entry point for the MOALI / LBVD Livestock Census system."""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager
import json

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import func, text

from app.api.v1.auth_router import router as auth_router
from app.api.v1.router import api_router
from app.api.v1.ws import init_realtime
from app.core.config import settings
from app.core.passwords import hash_password
from app.core.security import RateLimitMiddleware, SecurityHeadersMiddleware
from app.db.base import SessionLocal, engine
from app.db.models import Base, Gender, User
from app.seed import seed_census_form, seed_reference_data

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("moali")


def _bootstrap_admin() -> None:
    """Create the first administrator if the users table has no admin yet.

    In production the credentials *must* come from the environment; a warning is
    logged when the default development password is still in use.
    """
    db = SessionLocal()
    try:
        admin_exists = (
            db.query(User)
            .filter((User.is_superuser == True) | (User.role == "admin"))  # noqa: E712
            .first()
        )
        if admin_exists:
            return

        if settings.is_production and settings.ADMIN_PASSWORD == "Admin@12345":
            logger.warning(
                "Refusing to create a default administrator in production: "
                "set ADMIN_EMAIL and ADMIN_PASSWORD environment variables."
            )
            return

        admin = User(
            email=settings.ADMIN_EMAIL.lower(),
            password_hash=hash_password(settings.ADMIN_PASSWORD),
            name=settings.ADMIN_NAME,
            role="admin",
            is_active=True,
            is_superuser=True,
        )
        db.add(admin)
        db.commit()
        logger.info("Created bootstrap administrator %s", settings.ADMIN_EMAIL)
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Bind the real-time event loop before serving any traffic.
    try:
        init_realtime()
    except Exception as exc:  # pragma: no cover
        logger.error("Could not bind the real-time event loop: %s", exc)

    # Dev convenience: make sure every table defined on the models exists.
    # Schema *changes* are handled by Alembic migrations (see alembic/versions).
    try:
        Base.metadata.create_all(bind=engine)
    except Exception as exc:  # pragma: no cover - depends on DB availability
        logger.error("Could not ensure database tables: %s", exc)

    try:
        _bootstrap_admin()
    except Exception as exc:  # pragma: no cover
        logger.error("Admin bootstrap skipped: %s", exc)

    # Seed the workbook-derived reference data and the initial published census
    # form. Idempotent: only runs while the relevant tables are empty, so it is
    # safe on every start and never touches existing rows.
    try:
        db = SessionLocal()
        try:
            if db.query(Gender).count() == 0:
                for step in seed_reference_data(db):
                    logger.info("seed: %s", step)
                logger.info("seed: reference data initialised")
            from app.db.models import Form

            if not db.query(Form).filter(Form.form_id == "census-2026").first():
                logger.info("seed: %s", seed_census_form(db))
        finally:
            db.close()
    except Exception as exc:  # pragma: no cover
        logger.error("Reference-data seed skipped: %s", exc)

    yield


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Livestock census data collection and administration API.",
    lifespan=lifespan,
)

# --- Middleware (order matters: added last runs first) --------------------
app.add_middleware(RateLimitMiddleware)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_origin_regex=settings.CORS_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Return a clean, translatable error shape for validation failures."""
    raw_errors = exc.errors()
    first = raw_errors[0] if raw_errors else {}
    field = ".".join(str(p) for p in first.get("loc", [])[1:]) or "request"
    payload = {
        "detail": first.get("msg", "Invalid request"),
        "field": field,
        "errors": raw_errors,
    }
    # ``errors()`` can embed the raw request body (bytes results when the client
    # forgot ``Content-Type: application/json``). Round-tripping through JSON with
    # ``default=str`` guarantees the fallback is still a valid JSON response
    # instead of raising TypeError and becoming a 500.
    return JSONResponse(status_code=422, content=json.loads(json.dumps(payload, default=str)))


@app.get("/", tags=["meta"])
def root():
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/health", tags=["meta"])
def health():
    db_ok = True
    try:
        db = SessionLocal()
        try:
            db.execute(text("SELECT 1"))
        finally:
            db.close()
    except Exception as exc:  # pragma: no cover
        db_ok = False
        logger.error("Health check DB error: %s", exc)
    return {"status": "ok" if db_ok else "degraded", "database": db_ok}


# API v1 (dashboard, submissions, master data, forms, users, meta)
app.include_router(api_router)
# Auth at both legacy ``/auth`` and versioned ``/api/v1/auth``.
app.include_router(auth_router)
app.include_router(auth_router, prefix="/api/v1")
