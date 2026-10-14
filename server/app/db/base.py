# backend/server/app/db/base.py
"""Database engine and session factory.

The single source of truth for the declarative ``Base`` is
``app.db.models``; this module only builds the engine and session factory so
there is exactly one metadata object for migrations and ``create_all``.
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.db.models import Base  # noqa: F401  (re-exported for convenience)

_url = settings.DATABASE_URL
_connect_args = {}
if _url.startswith("sqlite"):
    # Allow the SQLite connection to be shared across FastAPI's threadpool.
    _connect_args = {"check_same_thread": False}

engine = create_engine(
    _url,
    pool_pre_ping=True,
    future=True,
    connect_args=_connect_args,
    **({} if _url.startswith("sqlite") else {"pool_size": 10, "max_overflow": 20}),
)

session_factory = sessionmaker(autocommit=False, autoflush=False, bind=engine, future=True)
# A plain sessionmaker, *not* a scoped_session: FastAPI runs sync dependencies in
# a threadpool and can run their teardown on a different worker thread than the
# one that created the session. A thread-local ``scoped_session`` would then leak
# the original session's connection (close() would target another thread's
# session), which corrupts the shared MySQL connection ("Packet sequence number
# wrong"). Creating a fresh Session per request and closing that exact object is
# the thread-safe pattern.
SessionLocal = session_factory


def get_db():
    """FastAPI dependency that yields a scoped database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
