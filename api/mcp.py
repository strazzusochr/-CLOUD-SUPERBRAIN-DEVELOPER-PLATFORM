"""Vercel ASGI entry point for the read-only MCP gateway."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "services" / "mcp-gateway"
sys.path.insert(0, str(SERVICE_ROOT))

os.environ.setdefault("FILESYSTEM_ROOT", "/tmp/agent-workspace")

from app.main import app as service_app  # noqa: E402


app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


@app.middleware("http")
async def read_only_contract_origin(request: Request, call_next):
    if request.method not in {"GET", "HEAD", "OPTIONS"}:
        return JSONResponse(
            status_code=503,
            content={
                "contract_version": "stateless-contract-origin-v1",
                "status": "blocked",
                "reason": "stateless_contract_origin_read_only",
                "accepted": False,
                "persisted": False,
                "audit_persisted": False,
                "direct_provider_calls": False,
                "live_provider_calls": False,
                "live_mcp_writes": False,
                "production_deploy": False,
                "secret_output": False,
            },
        )
    return await call_next(request)


app.mount("/mcp", service_app)
