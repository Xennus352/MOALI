"""Unit tests for the sliding-window rate limiter and its middleware wiring.

We test the limiter class directly (deterministic, no HTTP needed) and assert
the middleware returns 429 with a Retry-After header once the configured limit
is exceeded.
"""
from __future__ import annotations

import time

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.security import RateLimitMiddleware, SlidingWindowLimiter, get_client_ip


def test_limiter_allows_up_to_limit_and_blocks_after():
    limiter = SlidingWindowLimiter(limit=3, window_seconds=60)
    for _ in range(3):
        allowed, retry = limiter.check("1.2.3.4")
        assert allowed is True
        assert retry == 0
    allowed, retry = limiter.check("1.2.3.4")
    assert allowed is False
    assert retry >= 1


def test_limiter_is_per_key():
    limiter = SlidingWindowLimiter(limit=1, window_seconds=60)
    assert limiter.check("a")[0] is True
    assert limiter.check("b")[0] is True
    assert limiter.check("a")[0] is False


def test_limiter_window_expires():
    limiter = SlidingWindowLimiter(limit=1, window_seconds=1)
    assert limiter.check("k")[0] is True
    assert limiter.check("k")[0] is False
    time.sleep(1.1)
    assert limiter.check("k")[0] is True


def test_get_client_ip_prefers_forwarded_header():
    # Build a stand-in request object with the header attributes the helper reads.
    class _Fake:
        headers = {"x-forwarded-for": "203.0.113.9, 10.0.0.1"}

        class client:
            host = "10.0.0.1"

    assert get_client_ip(_Fake()) == "203.0.113.9"


def test_rate_limit_middleware_returns_429(tmp_path):
    app = FastAPI()

    @app.get("/ping")
    def ping():
        return {"pong": True}

    app.add_middleware(RateLimitMiddleware, limit_per_minute=2)
    with TestClient(app) as c:
        assert c.get("/ping").status_code == 200
        assert c.get("/ping").status_code == 200
        blocked = c.get("/ping")
        assert blocked.status_code == 429
        assert "retry-after" in blocked.headers


def test_rate_limit_middleware_exempts_health():
    app = FastAPI()

    @app.get("/health")
    def health():
        return {"ok": True}

    app.add_middleware(RateLimitMiddleware, limit_per_minute=1)
    with TestClient(app) as c:
        assert c.get("/health").status_code == 200
        assert c.get("/health").status_code == 200  # exempt path, not limited