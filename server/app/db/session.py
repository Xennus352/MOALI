# backend/server/app/db/session.py
from sqlalchemy.orm import Session
from typing import Optional

def commit(db: Session):
    """Commit a database transaction with error handling."""
    try:
        db.commit()
        return True
    except Exception:
        db.rollback()
        raise

def refresh(db: Session, obj):
    """Refresh an object from the database."""
    try:
        db.refresh(obj)
        return obj
    except Exception:
        db.rollback()
        raise

def execute(db: Session, sql):
    """Execute raw SQL safely."""
    result = db.execute(sql)
    db.commit()
    return result