# backend/server/app/core/security.py
"""HTTP security: response headers, rate limiting and small helpers."""
from __future__ import annotations

import threading
import time
from collections import defaultdict, deque
from typing import Callable

from fastapi import HTTPException, Request, Response, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.core.config import settings

# Paths that should never be rate limited / logged noisily.
EXEMPT_PATHS = {"/health", "/healthz", "/api/v1/health", "/docs", "/openapi.json", "/redoc"}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Adds defence-in-depth security headers to every response."""

    @staticmethod
    def _connect_src() -> str:
        origins = ["'self'", settings.FRONTEND_URL, *settings.CORS_ORIGINS, *settings.CSP_CONNECT_SRC]
        # Allow the websocket twin of every http origin so the realtime channel
        # is never blocked by the policy.
        ws_variants: list[str] = []
        for origin in list(origins):
            if origin.startswith("https://"):
                ws_variants.append("wss://" + origin[len("https://"):])
            elif origin.startswith("http://"):
                ws_variants.append("ws://" + origin[len("http://"):])
        ordered = list(dict.fromkeys([*origins, *ws_variants]))
        return " ".join(o for o in ordered if o)

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response: Response = await call_next(request)

        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self'; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
            "img-src 'self' data: https:; "
            f"connect-src {self._connect_src()}; "
            "font-src 'self' https://fonts.gstatic.com; "
            "frame-ancestors 'none'; "
            "form-action 'self'; "
            "base-uri 'self';"
        )
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        if settings.is_production or settings.COOKIE_SECURE:
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains; preload"
            )
        return response


class SlidingWindowLimiter:
    """Thread-safe in-memory sliding-window rate limiter.

    Suitable for a single process / development. For multi-instance production
    deployments use a shared store (e.g. Redis) or an edge proxy.
    """

    def __init__(self, limit: int, window_seconds: int = 60):
        self.limit = max(1, limit)
        self.window = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, key: str) -> tuple[bool, int]:
        """Record a hit. Returns ``(allowed, retry_after_seconds)``."""
        now = time.time()
        cutoff = now - self.window
        with self._lock:
            bucket = self._hits[key]
            while bucket and bucket[0] < cutoff:
                bucket.popleft()
            if len(bucket) >= self.limit:
                retry_after = int(self.window - (now - bucket[0])) + 1
                return False, max(1, retry_after)
            bucket.append(now)
            return True, 0


def get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Global IP rate limiting."""

    def __init__(self, app, limit_per_minute: int | None = None):
        super().__init__(app)
        self.limiter = SlidingWindowLimiter(
            limit_per_minute or settings.RATE_LIMIT_PER_MINUTE, 60
        )

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if request.url.path in EXEMPT_PATHS:
            return await call_next(request)

        allowed, retry_after = self.limiter.check(get_client_ip(request))
        if not allowed:
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={"detail": "Too many requests. Please slow down."},
                headers={"Retry-After": str(retry_after)},
            )
        return await call_next(request)


# Dedicated limiter for authentication endpoints (brute-force protection).
_auth_limiter = SlidingWindowLimiter(settings.AUTH_RATE_LIMIT_PER_MINUTE, 60)


def rate_limit_auth(request: Request) -> None:
    """Dependency that throttles authentication attempts per client IP."""
    allowed, retry_after = _auth_limiter.check(get_client_ip(request))
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many authentication attempts. Please wait and try again.",
            headers={"Retry-After": str(retry_after)},
        )
