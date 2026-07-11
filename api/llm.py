"""Vercel ASGI entry point for the deterministic LLM gateway."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "services" / "llm-gateway"
sys.path.insert(0, str(SERVICE_ROOT))

os.environ.setdefault("LLM_GATEWAY_MODE", "deterministic_dry_run")
os.environ.setdefault("LLM_LIVE_PROVIDER_DEFAULT", "false")

from app.main import app as service_app  # noqa: E402


app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


@app.middleware("http")
async def read_only_contract_origin(request: Request, call_next):
    if request.method not in {"GET", "HEAD", "OPTIONS"}:
        return JSONResponse(
            status_code=503,
            content={
                "status": "blocked",
                "reason": "stateless_contract_origin_read_only",
                "live_provider_calls": False,
            },
        )
    return await call_next(request)


app.mount("/llm", service_app)
