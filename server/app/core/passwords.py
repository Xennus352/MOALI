# backend/server/app/core/passwords.py
"""Argon2id password hashing helpers."""
from __future__ import annotations

from argon2 import PasswordHasher
from argon2.exceptions import Argon2Error, VerifyMismatchError

# A single, tuned Argon2id hasher for the whole process.
_ph = PasswordHasher()

# Sentinel value stored for accounts that must never authenticate with a
# password (e.g. OAuth-only accounts created before a password was set).
UNUSABLE_PASSWORD = "!"


def hash_password(password: str) -> str:
    """Hash a plaintext password with Argon2id."""
    if not isinstance(password, str):
        raise TypeError("password must be a string")
    return _ph.hash(password)


def verify_password(password: str, password_hash: str | None) -> bool:
    """Return ``True`` if *password* matches *password_hash*."""
    if not password_hash or password_hash == UNUSABLE_PASSWORD:
        return False
    try:
        return _ph.verify(password_hash, password)
    except VerifyMismatchError:
        return False
    except Argon2Error:
        return False
    except Exception:
        return False


def needs_rehash(password_hash: str) -> bool:
    try:
        return _ph.check_needs_rehash(password_hash)
    except Argon2Error:
        return True
