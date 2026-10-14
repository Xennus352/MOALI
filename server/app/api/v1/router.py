# backend/server/app/api/v1/router.py
"""Aggregates all v1 API routers under a single ``/api/v1`` prefix."""
from fastapi import APIRouter

from app.api.v1 import admin, dashboard, forms, master_data, meta, submissions, users, ws

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(meta.router)
api_router.include_router(dashboard.router)
api_router.include_router(submissions.router)
api_router.include_router(master_data.router)
api_router.include_router(forms.router)
api_router.include_router(users.router)
api_router.include_router(admin.router)
api_router.include_router(ws.router)

# The auth router is added at both ``/auth`` and ``/api/v1/auth`` by ``main``.
