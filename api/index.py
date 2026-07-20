"""Vercel ASGI entry point for the Cloud Superbrain Agent API."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "services" / "agent-api"
sys.path.insert(0, str(SERVICE_ROOT))

# This free serverless target is a stateless contract origin. Provider credentials
# belong to explicit verifier runs, never to public request handlers.
for provider_secret in (
    "BRANCH_PROTECTION_TOKEN",
    "CLOUDFLARE_API_TOKEN",
    "FLY_API_TOKEN",
    "GHCR_TOKEN",
    "GITHUB_TOKEN",
    "GITLAB_TOKEN",
    "GRAFANA_CLOUD_API_KEY",
    "HF_TOKEN",
    "VERCEL_TOKEN",
):
    os.environ.pop(provider_secret, None)

os.environ.setdefault(
    "PROJECT_PROGRESS_MANIFEST_PATH",
    str(ROOT / "docs" / "project-progress.manifest.json"),
)
os.environ.setdefault("PROJECT_STATE_PATH", str(ROOT / "PROJECT_STATE.md"))
os.environ.setdefault(
    "AUTONOMOUS_AGENT_ROSTER_PATH",
    str(ROOT / "docs" / "codex-integration" / "autonomous-agent-roster.json"),
)
os.environ.setdefault(
    "EXTERNAL_GATE_SUMMARY_PATH",
    str(ROOT / "docs" / "runtime-state" / "external-gate-summary.json"),
)
os.environ.setdefault("EVIDENCE_DIR", "/tmp")

from app.main import app as service_app  # noqa: E402
from app.main import health as service_health  # noqa: E402


app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)


@app.middleware("http")
async def read_only_contract_origin(request: Request, call_next):
    mutation_get_paths = {"/api/v1/auth/callback"}
    if request.method not in {"GET", "HEAD", "OPTIONS"} or request.url.path in mutation_get_paths:
        return JSONResponse(
            status_code=503,
            content={
                "contract_version": "stateless-contract-origin-v1",
                "status": "blocked",
                "reason": "stateless_contract_origin_read_only",
                "live": False,
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


@app.get("/health")
def health_alias() -> dict[str, object]:
    return service_health()


app.mount("/", service_app)
