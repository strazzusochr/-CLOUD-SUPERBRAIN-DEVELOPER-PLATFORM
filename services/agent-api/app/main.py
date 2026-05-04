from __future__ import annotations

import asyncio
import base64
import csv
import hashlib
import hmac
import io
import json
import os
import secrets
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

import psycopg
import redis
from fastapi import Cookie, FastAPI, Header, HTTPException, Query, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response, StreamingResponse
from psycopg.types.json import Json
from pydantic import BaseModel, Field, field_validator

from app.budget import (
    check_budget_guard,
    get_budget_state,
    get_infra_budget_state,
    get_prompt_rate_limit_status,
    get_session_llm_call_status,
    prompt_rate_limit_capacity,
    prompt_rate_limit_window_seconds,
    rate_limit_prompt,
    register_session_llm_call,
    session_llm_call_limit,
)
from app.clouds import cloud_layer_readiness_state, cloud_provider_state
from app.db import check_agent_worker, check_llm_gateway, check_mcp, check_memory_worker, check_postgres, check_redis, database_url, redis_url, run_migrations
from app.memory import (
    EMBEDDING_SEARCH_MODE,
    MemoryWriteRequest,
    current_embedding_dimensions,
    current_embedding_model_version,
    insert_memory_entry,
    search_memory,
    store_memory,
)
from app.models import agent_profile_registry, model_capability_matrix, rotation_policy
from app.orchestrator import (
    LANGGRAPH_MCP_TIMEOUT_EVIDENCE_REF,
    MCP_TIMEOUT_PROBE_PREFIX,
    PHASE2_SSE_EVENT_CONTRACT_VERSION,
    PHASE2_SSE_EVENT_EVIDENCE_REF,
    PHASE2_SSE_REQUIRED_EVENTS,
    ensure_postgres_checkpointer,
    recover_dry_graph_state,
    run_dry_graph,
    stream_dry_graph_events,
)
from app.security import redact_json, redact_text
from app.tasks import (
    TASK_PRIORITY_QUEUES,
    TASK_QUEUE_KEY,
    TASK_STATUS_PREFIX,
    TASK_TTL_SECONDS,
    TaskAssignment,
    TaskPolicyViolation,
    enqueue_task,
    get_task,
    list_recent_tasks,
    queue_depth,
    queue_depth_by_priority,
    task_policy_manifest,
    validate_task_policy,
)

app = FastAPI(title="Cloud Superbrain Agent API", version="0.1.0")

SSE_BUFFER_LIMIT = 50
SSE_BUFFER_TTL_SECONDS = 60 * 60
SSE_BUFFER_PREFIX = "sse:session:"
SSE_EVENT_ID_PREFIX = "sse:event-id:"
RATE_LIMIT_CONTRACT_VERSION = "rate-limit-guard-v1"
SESSION_LIMIT_CONTRACT_VERSION = "session-llm-call-limit-v1"
PROMPT_INPUT_CONTRACT_VERSION = "prompt-input-contract-v1"
ERROR_RESPONSE_CONTRACT_VERSION = "error-response-contract-v1"
SECURITY_HEADERS_CONTRACT_VERSION = "security-headers-v1"
TRACE_ID_CONTRACT_VERSION = "trace-id-propagation-v1"
CACHE_CONTROL_CONTRACT_VERSION = "cache-control-no-store-v1"
REQUEST_ID_CONTRACT_VERSION = "request-id-correlation-v1"
LAYER_INTERFACE_CONTRACT_VERSION = "layer-interface-contracts-v1"
LAYER_INTERFACE_EVIDENCE_REF = "layer_interface_contracts_visible"
TASK_ASSIGNMENT_CONTRACT_VERSION = "task-assignment-queue-contract-v1"
TASK_ASSIGNMENT_EVIDENCE_REF = "task_assignment_queue_contract_visible"
AGENT_LLM_STREAMING_CONTRACT_VERSION = "agent-llm-streaming-contract-v1"
AGENT_LLM_STREAMING_EVIDENCE_REF = "agent_llm_streaming_contract_visible"
MEMORY_EMBEDDING_CONSISTENCY_CONTRACT_VERSION = "memory-embedding-consistency-v1"
MEMORY_EMBEDDING_CONSISTENCY_EVIDENCE_REF = "memory_embedding_consistency_contract_visible"
MEMORY_EMBEDDING_VECTOR_TYPE = "vector(1536)"
PROGRESS_INTEGRITY_CONTRACT_VERSION = "project-progress-integrity-v1"
PROGRESS_INTEGRITY_EVIDENCE_REF = "project_progress_integrity_runtime_proof"
PROGRESS_COMPLETION_CONTRACT_VERSION = "project-progress-100-percent-contract-v1"
PROGRESS_COMPLETION_EVIDENCE_REF = "project_progress_100_percent_gate_contract"
SESSION_HISTORY_CONTRACT_VERSION = "session-history-v1"
SESSION_HISTORY_EVIDENCE_REF = "session_history_openable_project_state"
PHASE2_RUNTIME_CONTRACT_VERSION = "phase2-runtime-v1"
PHASE2_RUNTIME_GRAPH_EVIDENCE_REF = "phase2_runtime_graph_started"
EXTERNAL_GATE_MIRROR_CONTRACT_VERSION = "external-gate-mirror-v1"
EXTERNAL_GATE_MIRROR_EVIDENCE_REF = "external_gate_mirror_proof"
EXTERNAL_GATES_CONTRACT_VERSION = "external-gates-state-v1"
EXTERNAL_GATES_EVIDENCE_REF = "external_gates_state_visible"
BRANCH_PROTECTION_VERIFY_EVIDENCE_REF = "branch_protection_verify_contract"
CLOUD_RENDER_OFFLOAD_CONTRACT_VERSION = "cloud-render-offload-v1"
CLOUD_RENDER_OFFLOAD_EVIDENCE_REF = "cloud_render_offload_contract_visible"
CLOUD_DEPLOYMENT_PREFLIGHT_CONTRACT_VERSION = "cloud-deployment-preflight-v1"
CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF = "cloud_deployment_preflight_visible"
SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    "Content-Security-Policy": "default-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
}
CACHE_CONTROL_HEADERS = {
    "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
    "Pragma": "no-cache",
    "Expires": "0",
}


def error_slug(value: object, fallback: str) -> str:
    text = str(value or fallback).strip().lower().replace(" ", "_").replace("-", "_")
    return "".join(char for char in text if char.isalnum() or char == "_") or fallback


def error_evidence_ref(status_code: int) -> str:
    if status_code == 422:
        return "error_response_422_visible"
    if status_code == 429:
        return "error_response_429_visible"
    return "error_response_contract_visible"


def error_envelope(
    *,
    status_code: int,
    detail: object,
    request: Request,
    fallback_error: str,
    message: str | None = None,
) -> dict[str, object]:
    request_id = (
        getattr(request.state, "request_id", None)
        or request.headers.get("x-request-id")
        or request.query_params.get("request_id")
        or "unknown"
    )
    trace_id = (
        getattr(request.state, "trace_id", None)
        or request.headers.get("x-trace-id")
        or request.query_params.get("trace_id")
        or "unknown"
    )
    error = fallback_error
    if isinstance(detail, dict):
        error = error_slug(detail.get("error") or detail.get("code"), fallback_error)
        message = message or str(detail.get("message") or detail.get("detail") or error)
    elif isinstance(detail, str):
        error = error_slug(detail, fallback_error)
        message = message or detail
    else:
        message = message or fallback_error
    return {
        "contract_version": ERROR_RESPONSE_CONTRACT_VERSION,
        "status_code": status_code,
        "error": error,
        "message": message,
        "detail": detail,
        "recoverable": status_code in {400, 401, 403, 404, 429, 503},
        "evidence_ref": error_evidence_ref(status_code),
        "correlation_evidence_ref": "request_id_error_envelope_correlation",
        "request_id": request_id,
        "trace_id": trace_id,
        "path": request.url.path,
    }


@app.exception_handler(HTTPException)
async def http_exception_envelope_handler(request: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content=error_envelope(
            status_code=exc.status_code,
            detail=exc.detail,
            request=request,
            fallback_error=f"http_{exc.status_code}",
        ),
        headers=getattr(exc, "headers", None),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_envelope_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content=error_envelope(
            status_code=422,
            detail=jsonable_encoder(exc.errors()),
            request=request,
            fallback_error="validation_error",
            message="request validation failed",
        ),
    )


@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    for header, value in SECURITY_HEADERS.items():
        response.headers.setdefault(header, value)
    response.headers.setdefault("X-Superbrain-Security-Contract", SECURITY_HEADERS_CONTRACT_VERSION)
    return response


@app.middleware("http")
async def trace_id_middleware(request: Request, call_next):
    supplied_trace_id = request.headers.get("x-trace-id") or request.query_params.get("trace_id")
    trace_id = supplied_trace_id.strip() if supplied_trace_id else f"trace-{uuid4()}"
    request.state.trace_id = trace_id
    response = await call_next(request)
    response.headers.setdefault("X-Trace-Id", trace_id)
    response.headers.setdefault("X-Superbrain-Trace-Contract", TRACE_ID_CONTRACT_VERSION)
    return response


@app.middleware("http")
async def cache_control_middleware(request: Request, call_next):
    response = await call_next(request)
    for header, value in CACHE_CONTROL_HEADERS.items():
        response.headers.setdefault(header, value)
    response.headers.setdefault("X-Superbrain-Cache-Contract", CACHE_CONTROL_CONTRACT_VERSION)
    return response


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    supplied_request_id = request.headers.get("x-request-id") or request.query_params.get("request_id")
    request_id = supplied_request_id.strip() if supplied_request_id else f"req-{uuid4()}"
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers.setdefault("X-Request-Id", request_id)
    response.headers.setdefault("X-Superbrain-Request-Contract", REQUEST_ID_CONTRACT_VERSION)
    return response


def metric_label_value(value: object) -> str:
    text = str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return text


def metric_sample(name: str, value: int | float, labels: dict[str, object] | None = None) -> str:
    if not labels:
        return f"{name} {value}"
    label_text = ",".join(f'{key}="{metric_label_value(item)}"' for key, item in sorted(labels.items()))
    return f"{name}{{{label_text}}} {value}"


def redis_client() -> redis.Redis:
    return redis.Redis.from_url(redis_url(), socket_timeout=3, socket_connect_timeout=3, decode_responses=True)


def encode_sse_event(event_id: int, event: str, payload: dict[str, object]) -> str:
    return f"id: {event_id}\nevent: {event}\ndata: {json.dumps(payload, separators=(',', ':'), default=str)}\n\n"


def record_sse_event(session_id: str, event: str, payload: dict[str, object]) -> str:
    client = redis_client()
    event_id = int(client.incr(SSE_EVENT_ID_PREFIX + session_id))
    record = {"id": event_id, "event": event, "payload": payload}
    key = SSE_BUFFER_PREFIX + session_id
    client.rpush(key, json.dumps(record, separators=(",", ":"), default=str))
    client.ltrim(key, -SSE_BUFFER_LIMIT, -1)
    client.expire(key, SSE_BUFFER_TTL_SECONDS)
    client.expire(SSE_EVENT_ID_PREFIX + session_id, SSE_BUFFER_TTL_SECONDS)
    return encode_sse_event(event_id, event, payload)


def orchestrator_sse_key(thread_id: str) -> str:
    return f"orchestrator:{thread_id}"


def replay_sse_events(session_id: str, last_event_id: str | None) -> list[str]:
    if last_event_id is None:
        return []
    try:
        since = int(last_event_id)
    except ValueError:
        since = 0
    events: list[str] = []
    for raw in redis_client().lrange(SSE_BUFFER_PREFIX + session_id, 0, -1):
        try:
            record = json.loads(raw)
            event_id = int(record["id"])
            if event_id > since:
                payload = dict(record.get("payload") or {})
                payload["replay"] = True
                events.append(encode_sse_event(event_id, str(record["event"]), payload))
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            continue
    return events


def external_gate_state() -> dict[str, object]:
    repo_gitleaks_path = Path(".tools") / "gitleaks" / "gitleaks.exe"
    gitleaks_available = shutil.which("gitleaks") is not None or repo_gitleaks_path.exists()
    gates = [
        {
            "id": "branch_protection_token",
            "preflight_gate_id": "branch_protection",
            "label": "GitHub branch protection apply token",
            "configured": bool(os.getenv("BRANCH_PROTECTION_TOKEN")),
            "required_env": ["BRANCH_PROTECTION_TOKEN"],
            "evidence_ref": BRANCH_PROTECTION_VERIFY_EVIDENCE_REF,
            "required_for": "Applying protected-main rules through the manual branch-protection workflow.",
            "fallback": "Fail-closed dry-run script; no protected-main success is claimed without token.",
        },
        {
            "id": "staging_base_url",
            "preflight_gate_id": "hosted_staging",
            "label": "Hosted staging URL",
            "configured": bool(os.getenv("STAGING_BASE_URL")),
            "required_env": ["STAGING_BASE_URL"],
            "evidence_ref": "hosted_staging_base_url_required",
            "required_for": "Repository-hosted staging proof workflow.",
            "fallback": "Local proof may run only with explicit -AllowLocalhost.",
        },
        {
            "id": "hetzner_api_token",
            "preflight_gate_id": "hetzner_cloud_stack",
            "label": "Hetzner API token",
            "configured": bool(os.getenv("HETZNER_API_TOKEN")),
            "required_env": ["HETZNER_API_TOKEN"],
            "evidence_ref": "hetzner_live_budget_check",
            "required_for": "Live infrastructure invoice/cost verification.",
            "fallback": "Configured Phase-1 projection is used; live invoice proof is not claimed.",
        },
        {
            "id": "ghcr_image_digest_proof",
            "preflight_gate_id": "ghcr_images",
            "label": "GHCR image digest proof",
            "configured": bool(os.getenv("GITHUB_TOKEN") and os.getenv("GHCR_TOKEN")),
            "required_env": ["GITHUB_TOKEN", "GHCR_TOKEN"],
            "evidence_ref": "ghcr_image_digest_proof",
            "required_for": "Published and pullable GHCR images for all application services.",
            "fallback": "Static workflow proof only; no image publication or pull success is claimed.",
        },
        {
            "id": "vercel_backend_origins",
            "preflight_gate_id": "hosted_backend_origins",
            "label": "Vercel hosted backend origins",
            "configured": all(
                bool(os.getenv(key))
                for key in ["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"]
            ),
            "required_env": ["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"],
            "evidence_ref": "hosted_backend_origin_env_required",
            "required_for": "Hosted frontend uses HTTPS backend origins instead of localhost.",
            "fallback": "Local frontend proof only; no hosted Vercel origin success is claimed.",
        },
        {
            "id": "gitleaks_binary",
            "preflight_gate_id": "canonical_secret_scan",
            "label": "gitleaks binary",
            "configured": gitleaks_available,
            "required_env": [],
            "evidence_ref": "canonical_gitleaks_scan",
            "required_for": "Canonical upstream secret scanner execution.",
            "fallback": "Local fallback scanner blocks known secret patterns when gitleaks is unavailable.",
        },
    ]
    configured = sum(1 for gate in gates if gate["configured"])
    blocked_release_gates = [str(gate["preflight_gate_id"]) for gate in gates if not gate["configured"]]
    return {
        "contract_version": EXTERNAL_GATES_CONTRACT_VERSION,
        "status": "complete" if configured == len(gates) else "action_required",
        "endpoint": "GET /api/v1/external-gates",
        "evidence_ref": EXTERNAL_GATES_EVIDENCE_REF,
        "configured_count": configured,
        "total_count": len(gates),
        "local_execution_allowed": True,
        "aligned_with_deployment_preflight": True,
        "deployment_preflight_endpoint": "GET /api/v1/clouds/deployment-preflight/contract",
        "blocked_release_gates": blocked_release_gates,
        "gates": gates,
        "non_claims": [
            "Missing external gates are reported explicitly and are not treated as verified.",
            "Local development may continue, but production/repository-hosted proof remains gated.",
            "Configured environment variables are prerequisites, not hosted verification proof.",
        ],
    }


def external_gate_mirror_state() -> dict[str, object]:
    gates = external_gate_state()
    gate_items = list(gates["gates"])
    staging_configured = any(gate["id"] == "staging_base_url" and gate["configured"] for gate in gate_items)
    branch_token_configured = any(
        gate["id"] == "branch_protection_token" and gate["configured"] for gate in gate_items
    )
    return {
        "contract_version": EXTERNAL_GATE_MIRROR_CONTRACT_VERSION,
        "status": "local_mirror_ready_hosted_blocked",
        "endpoint": "GET /api/v1/external-gates/mirror",
        "mirrored_workflow": ".github/workflows/hosted-staging-proof.yml",
        "verifier": "scripts/verify-hosted-staging.ps1",
        "branch_protection_workflow": ".github/workflows/branch-protection.yml",
        "branch_protection_verifier": "scripts/apply_github_branch_protection.py --verify-only",
        "local_mirror_command": "powershell -ExecutionPolicy Bypass -File scripts\\verify-hosted-staging.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost",
        "hosted_command": "powershell -ExecutionPolicy Bypass -File scripts\\verify-hosted-staging.ps1",
        "external_gate_status": gates["status"],
        "configured_count": gates["configured_count"],
        "total_count": gates["total_count"],
        "required_external_gates": [gate["id"] for gate in gate_items],
        "phase2_contracts_mirrored": [
            {
                "name": "Phase 2 runtime contract",
                "endpoint": "GET /api/v1/phase2/runtime/contract",
                "contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
                "evidence_ref": PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
            },
            {
                "name": "Phase 2 SSE event contract",
                "endpoint": "POST /api/v1/orchestrator/dry-run/stream",
                "contract_version": PHASE2_SSE_EVENT_CONTRACT_VERSION,
                "required_event_types": list(PHASE2_SSE_REQUIRED_EVENTS),
                "evidence_ref": PHASE2_SSE_EVENT_EVIDENCE_REF,
            },
            {
                "name": "Project progress manifest",
                "endpoint": "GET /api/v1/project/progress",
                "contract_version": "project-progress-manifest",
                "evidence_ref": "project_progress_manifest_proof",
            },
        ],
        "hosted_staging_claim_allowed": False,
        "branch_protection_claim_allowed": False,
        "hosted_staging_env_configured": staging_configured,
        "branch_protection_env_configured": branch_token_configured,
        "branch_protection_evidence_ref": BRANCH_PROTECTION_VERIFY_EVIDENCE_REF,
        "cloud_deployment_preflight_evidence_ref": CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF,
        "production_deploy_claim_allowed": False,
        "evidence_ref": EXTERNAL_GATE_MIRROR_EVIDENCE_REF,
        "non_claims": [
            "Local mirror proof is not a hosted staging success claim.",
            "STAGING_BASE_URL is required before repository-hosted proof can be claimed.",
            "BRANCH_PROTECTION_TOKEN is required before protected-main success can be claimed.",
            "Production deployment remains blocked.",
        ],
    }


class PromptRequest(BaseModel):
    project_id: str = Field(..., min_length=1)
    prompt: str = Field(..., min_length=1, max_length=10_000)
    session_id: str | None = None
    stream: bool = True


class RotationEventRequest(BaseModel):
    from_provider: str = Field(..., min_length=1, max_length=100)
    to_provider: str = Field(..., min_length=1, max_length=100)
    reason: str = Field(..., pattern="^(rate_limited|provider_down|timeout|budget_guard)$")
    agent: str = Field(..., pattern="^(planner|coder|tester|devops|research)$")
    session_id: str | None = None
    trace_id: str | None = Field(default=None, max_length=255)
    from_model: str | None = Field(default=None, max_length=120)
    to_model: str | None = Field(default=None, max_length=120)
    fallback_index: int = Field(default=1, ge=1, le=5)
    routing_policy_decision: str = Field(default="allow_fallback", max_length=120)
    input_tokens: int = Field(default=0, ge=0)
    output_tokens: int = Field(default=0, ge=0)
    estimated_cost_cents: int = Field(default=0, ge=0)
    budget_level: str = Field(default="ok", pattern="^(ok|warning|critical)$")


class OrchestratorDryRunRequest(BaseModel):
    project_id: str = Field(..., min_length=1)
    prompt: str = Field(..., min_length=1, max_length=10_000)
    session_id: str | None = None


class AutopilotStreamRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=10_000)
    project_id: str = Field(default="autopilot-mode", min_length=1)
    session_id: str | None = None


class WorkflowDispatchRequest(BaseModel):
    workflow_id: str = Field(default="main-deploy.yml", min_length=1, max_length=120)
    ref: str = Field(default="main", min_length=1, max_length=120)
    environment: str = Field(default="staging", pattern="^(staging|production)$")
    action: str = Field(default="deploy", pattern="^(deploy|rollback|health_check)$")
    image_tag: str | None = Field(default=None, max_length=160)
    reason: str = Field(default="phase2-devops-dispatch-contract", min_length=1, max_length=500)
    trace_id: str | None = Field(default=None, max_length=255)
    human_review_approved: bool = False
    dry_run: bool = True


class McpToolAuditRequest(BaseModel):
    tool_request_id: str = Field(..., min_length=1, max_length=120)
    run_id: str = Field(..., min_length=1, max_length=120)
    session_id: str | None = Field(default=None, max_length=120)
    trace_id: str | None = Field(default=None, max_length=255)
    agent_role: str = Field(..., pattern="^(planner|coder|tester|devops)$")
    toolset: str = Field(..., pattern="^(github|e2b|playwright|filesystem|postgresql|puppeteer)$")
    capability: str = Field(..., min_length=1, max_length=120)
    status: str = Field(..., pattern="^(success|blocked|timeout|degraded)$")
    error_class: str = Field(..., min_length=1, max_length=120)
    sanitized_summary: str = Field(..., min_length=1, max_length=500)
    evidence_ref: str = Field(..., min_length=1, max_length=120)
    result_ref: str = Field(..., min_length=1, max_length=180)
    duration_ms: int = Field(..., ge=0)
    retry_after_ms: int = Field(..., ge=0)
    audit_tags: list[str] = Field(default_factory=list)

    @field_validator("session_id")
    @classmethod
    def validate_session_uuid(cls, value: str | None) -> str | None:
        if value is None:
            return None
        try:
            return str(UUID(value))
        except (TypeError, ValueError) as exc:
            raise ValueError("session_id must be a valid UUID") from exc


class LlmGatewayAuditRequest(BaseModel):
    trace_id: str = Field(..., min_length=1, max_length=255)
    model_name: str = Field(..., min_length=1, max_length=120)
    provider_name: str = Field(..., min_length=1, max_length=120)
    agent_type: str = Field(default="unknown", max_length=50)
    status: str = Field(..., pattern="^(dry_run|success|blocked|error)$")
    input_tokens: int = Field(..., ge=0)
    output_tokens: int = Field(..., ge=0)
    cost_cents: int = Field(..., ge=0)
    live_provider_calls: bool = False
    summary: str = Field(..., min_length=1, max_length=500)


class AuthRefreshRequest(BaseModel):
    refresh_token: str | None = Field(default=None, max_length=512)
    trace_id: str | None = Field(default=None, max_length=255)


class MemoryPurgeRequest(BaseModel):
    project_id: str = Field(..., min_length=1, max_length=255)
    confirm: bool = False
    reason: str = Field(default="dsgvo_user_requested_purge", min_length=1, max_length=255)
    trace_id: str | None = Field(default=None, max_length=255)


class MemoryEntryDeleteRequest(BaseModel):
    project_id: str = Field(..., min_length=1, max_length=255)
    memory_id: str = Field(..., min_length=1, max_length=255)
    confirm: bool = False
    reason: str = Field(default="user_requested_single_memory_delete", min_length=1, max_length=255)
    trace_id: str | None = Field(default=None, max_length=255)


AUTH_ACCESS_TOKEN_TTL_SECONDS = 15 * 60
AUTH_REFRESH_TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60
AUTH_BLACKLIST_PREFIX = "auth:refresh:blacklist:"
DSGVO_PURGE_CONTRACT_VERSION = "memory-dsgvo-purge-v1"
COST_EXPORT_CONTRACT_VERSION = "cost-monitor-export-v1"
SYSTEM_FALLBACK_CONTRACT_VERSION = "system-unavailable-fallback-v1"
AGENT_ACTIVITY_CONTRACT_VERSION = "agent-activity-trace-v1"


def b64url_json(payload: dict[str, object]) -> str:
    raw = json.dumps(payload, separators=(",", ":"), default=str).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def b64url_bytes(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def auth_secret() -> bytes:
    return os.getenv("JWT_SIGNING_SECRET", "phase3-local-dry-run-signing-secret").encode("utf-8")


def create_access_jwt(subject: str, trace_id: str | None = None) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": subject,
        "iat": now,
        "exp": now + AUTH_ACCESS_TOKEN_TTL_SECONDS,
        "iss": "cloud-superbrain-agent-api",
        "aud": "cloud-superbrain-frontend",
        "trace_id": trace_id or f"auth-{uuid4()}",
        "mode": "local_contract",
    }
    signing_input = f"{b64url_json(header)}.{b64url_json(payload)}"
    signature = hmac.new(auth_secret(), signing_input.encode("ascii"), hashlib.sha256).digest()
    return f"{signing_input}.{b64url_bytes(signature)}"


def create_refresh_token() -> str:
    return "csr_" + secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def auth_blacklist_key(token: str) -> str:
    return AUTH_BLACKLIST_PREFIX + hash_token(token)


def set_auth_cookies(response: Response, access_token: str, refresh_token: str) -> None:
    response.set_cookie(
        "access_token",
        access_token,
        max_age=AUTH_ACCESS_TOKEN_TTL_SECONDS,
        httponly=True,
        secure=True,
        samesite="strict",
    )
    response.set_cookie(
        "refresh_token",
        refresh_token,
        max_age=AUTH_REFRESH_TOKEN_TTL_SECONDS,
        httponly=True,
        secure=True,
        samesite="strict",
    )


def clear_auth_cookies(response: Response) -> None:
    response.delete_cookie("access_token", httponly=True, secure=True, samesite="strict")
    response.delete_cookie("refresh_token", httponly=True, secure=True, samesite="strict")


def persist_auth_audit(event_type: str, details: dict[str, object], severity: str = "info") -> None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES (%s, 'auth', %s::jsonb, %s)
                """,
                (event_type, Json(redact_json(details)), severity),
            )
    except Exception:
        pass


def auth_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "auth-github-jwt-refresh-v1",
        "mode": "local_contract_with_dry_run_oauth",
        "live_github_oauth_call": False,
        "github_oauth_configured": bool(os.getenv("GITHUB_OAUTH_CLIENT_ID") and os.getenv("GITHUB_OAUTH_CLIENT_SECRET")),
        "jwt": {
            "algorithm": "HS256",
            "access_token_ttl_seconds": AUTH_ACCESS_TOKEN_TTL_SECONDS,
            "issuer": "cloud-superbrain-agent-api",
            "audience": "cloud-superbrain-frontend",
        },
        "refresh_token": {
            "ttl_seconds": AUTH_REFRESH_TOKEN_TTL_SECONDS,
            "rotation_required": True,
            "blacklist_store": "redis",
            "blacklist_key_pattern": f"{AUTH_BLACKLIST_PREFIX}<sha256(refresh_token)>",
        },
        "cookie_flags": {
            "HttpOnly": True,
            "Secure": True,
            "SameSite": "Strict",
        },
        "endpoints": {
            "github_start": "/api/v1/auth/github",
            "callback": "/api/v1/auth/callback",
            "refresh": "/api/v1/auth/refresh",
            "logout": "/api/v1/auth/logout",
        },
        "evidence_refs": {
            "contract": "auth_contract_visible",
            "refresh_rotated": "auth_refresh_rotated",
            "refresh_reuse_blocked": "auth_refresh_reuse_blocked",
            "logout_revoked": "auth_logout_revoked",
        },
        "policy_checks": [
            "Access JWT expires after 900 seconds.",
            "Refresh token expires after 604800 seconds.",
            "Refresh token is rotated on every refresh request.",
            "Old refresh token hash is stored in Redis blacklist.",
            "Auth cookies are HttpOnly, Secure, and SameSite=Strict.",
            "No live GitHub OAuth call is made in local contract mode.",
        ],
        "non_claims": [
            "No live GitHub OAuth exchange is claimed without GitHub OAuth credentials.",
            "This local proof validates token lifecycle mechanics, not production identity ownership.",
        ],
    }


def memory_purge_contract_payload() -> dict[str, object]:
    return {
        "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
        "mode": "accepted_local_purge_with_audit_job_status",
        "endpoint": "DELETE /api/v1/memory?project_id={id}&confirm=true",
        "job_status_endpoint": "GET /api/v1/memory/purge/jobs/{job_id}",
        "single_entry_endpoint": "DELETE /api/v1/memory/{memory_id}?project_id={id}&confirm=true",
        "requires_confirmation": True,
        "purge_scope": [
            "Redis working-memory keys for the project",
            "PostgreSQL memory_entries for the project",
            "PostgreSQL agent_messages linked through project sessions",
            "PostgreSQL agent_sessions for the project",
        ],
        "audit": {
            "event_type": "memory_purge_completed",
            "retention_days": 30,
            "stored_after_purge": True,
        },
        "evidence_refs": {
            "contract": "memory_purge_contract_visible",
            "completed": "memory_purge_completed",
            "blocked": "memory_purge_confirmation_required",
            "job_status": "memory_purge_job_status_visible",
            "entry_deleted": "memory_entry_delete_completed",
            "entry_blocked": "memory_entry_delete_confirmation_required",
        },
        "policy_checks": [
            "Purge requires confirm=true.",
            "Purge returns a job_id that can be checked through the job status endpoint.",
            "Single-entry delete requires confirm=true and project_id scope.",
            "Purge is scoped by project_id, never global by default.",
            "Audit event is retained after data purge.",
            "Single-entry delete soft-deletes by setting memory_entries.status=deleted.",
            "Redis keys matching project:{project_id}:* are deleted.",
            "PostgreSQL project sessions, messages, and memory entries are deleted for the scoped project.",
        ],
        "non_claims": [
            "This local proof does not delete Langfuse traces because Langfuse is not yet live-wired in this stack.",
            "This local proof does not delete provider-side data because no live provider calls are claimed.",
        ],
    }


def execute_memory_entry_delete(request: MemoryEntryDeleteRequest) -> dict[str, object]:
    if not request.confirm:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "confirmation_required",
                "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
                "evidence_ref": "memory_entry_delete_confirmation_required",
            },
        )

    trace_id = request.trace_id or f"memory-entry-delete-{uuid4()}"
    with psycopg.connect(database_url(), autocommit=True) as conn:
        project_row = conn.execute(
            "SELECT id FROM projects WHERE metadata->>'external_id' = %s OR name = %s LIMIT 1",
            (request.project_id, request.project_id),
        ).fetchone()
        if not project_row:
            raise HTTPException(status_code=404, detail={"error": "project_not_found"})
        project_uuid = str(project_row[0])
        row = conn.execute(
            """
            UPDATE memory_entries
            SET status = 'deleted',
                metadata = COALESCE(metadata, '{}'::jsonb) || %s::jsonb
            WHERE id = %s
              AND project_id = %s
              AND status = 'active'
            RETURNING id, session_id, content_text, created_at
            """,
            (
                Json(
                    redact_json(
                        {
                            "deleted_at": datetime.now(timezone.utc).isoformat(),
                            "delete_reason": request.reason,
                            "delete_trace_id": trace_id,
                        }
                    )
                ),
                request.memory_id,
                project_uuid,
            ),
        ).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail={"error": "memory_entry_not_found_or_already_deleted"})
        details = redact_json(
            {
                "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
                "trace_id": trace_id,
                "project_id": request.project_id,
                "project_uuid": project_uuid,
                "memory_id": request.memory_id,
                "session_id": str(row[1]) if row[1] else None,
                "reason": request.reason,
                "delete_mode": "soft_delete_status_deleted",
                "evidence_ref": "memory_entry_delete_completed",
            }
        )
        audit_row = conn.execute(
            """
            INSERT INTO audit_log(event_type, user_id, session_id, details, severity)
            VALUES ('memory_entry_deleted', 'memory', %s, %s::jsonb, 'warning')
            RETURNING id, created_at
            """,
            (row[1], Json(details)),
        ).fetchone()
    return {
        "status": "deleted",
        "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
        "evidence_ref": "memory_entry_delete_completed",
        "project_id": request.project_id,
        "memory_id": request.memory_id,
        "delete_mode": "soft_delete_status_deleted",
        "audit_event_id": str(audit_row[0]) if audit_row else None,
        "completed_at": audit_row[1].isoformat() if audit_row and audit_row[1] else datetime.now(timezone.utc).isoformat(),
    }


def execute_memory_purge(request: MemoryPurgeRequest) -> dict[str, object]:
    if not request.confirm:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "confirmation_required",
                "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
                "evidence_ref": "memory_purge_confirmation_required",
            },
        )

    trace_id = request.trace_id or f"memory-purge-{uuid4()}"
    project_uuid: str | None = None
    deleted_counts = {
        "redis_keys": 0,
        "memory_entries": 0,
        "agent_messages": 0,
        "agent_sessions": 0,
    }

    client = redis_client()
    for key in list(client.scan_iter(match=f"project:{request.project_id}:*")):
        client.delete(key)
        deleted_counts["redis_keys"] += 1

    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute(
            "SELECT id FROM projects WHERE metadata->>'external_id' = %s OR name = %s LIMIT 1",
            (request.project_id, request.project_id),
        ).fetchone()
        if row:
            project_uuid = str(row[0])
            session_rows = conn.execute(
                "SELECT id FROM agent_sessions WHERE project_id = %s",
                (project_uuid,),
            ).fetchall()
            session_ids = [str(item[0]) for item in session_rows]
            if session_ids:
                deleted_messages = conn.execute(
                    "DELETE FROM agent_messages WHERE session_id = ANY(%s::uuid[])",
                    (session_ids,),
                ).rowcount
                deleted_counts["agent_messages"] = int(deleted_messages or 0)
            deleted_memory = conn.execute(
                "DELETE FROM memory_entries WHERE project_id = %s",
                (project_uuid,),
            ).rowcount
            deleted_sessions = conn.execute(
                "DELETE FROM agent_sessions WHERE project_id = %s",
                (project_uuid,),
            ).rowcount
            deleted_counts["memory_entries"] = int(deleted_memory or 0)
            deleted_counts["agent_sessions"] = int(deleted_sessions or 0)

        details = redact_json(
            {
                "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
                "trace_id": trace_id,
                "project_id": request.project_id,
                "project_uuid": project_uuid,
                "reason": request.reason,
                "deleted_counts": deleted_counts,
                "audit_retention_days": 30,
                "langfuse_trace_purge": "not_live_wired_no_claim",
                "provider_side_purge": "not_applicable_no_live_provider_calls",
            }
        )
        audit_row = conn.execute(
            """
            INSERT INTO audit_log(event_type, user_id, details, severity)
            VALUES ('memory_purge_completed', 'memory', %s::jsonb, 'warning')
            RETURNING id, created_at
            """,
            (Json(details),),
        ).fetchone()

    return {
        "job_id": str(audit_row[0]) if audit_row else trace_id,
        "status": "completed",
        "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
        "evidence_ref": "memory_purge_completed",
        "job_status_url": f"/api/v1/memory/purge/jobs/{audit_row[0]}" if audit_row else None,
        "project_id": request.project_id,
        "project_found": project_uuid is not None,
        "deleted_counts": deleted_counts,
        "audit_event_id": str(audit_row[0]) if audit_row else None,
        "completed_at": audit_row[1].isoformat() if audit_row and audit_row[1] else datetime.now(timezone.utc).isoformat(),
        "non_claims": memory_purge_contract_payload()["non_claims"],
    }


def get_memory_purge_job_status(job_id: str) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute(
            """
            SELECT id, details, created_at, severity
            FROM audit_log
            WHERE event_type = 'memory_purge_completed'
              AND (id::text = %s OR details->>'trace_id' = %s)
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (job_id, job_id),
        ).fetchone()
    if not row:
        raise HTTPException(
            status_code=404,
            detail={
                "error": "memory_purge_job_not_found",
                "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
                "evidence_ref": "memory_purge_job_status_missing",
            },
        )
    details = row[1] or {}
    return {
        "job_id": str(row[0]),
        "status": "completed",
        "contract_version": DSGVO_PURGE_CONTRACT_VERSION,
        "evidence_ref": "memory_purge_job_status_visible",
        "project_id": details.get("project_id"),
        "project_uuid": details.get("project_uuid"),
        "trace_id": details.get("trace_id"),
        "deleted_counts": details.get("deleted_counts", {}),
        "audit_event_id": str(row[0]),
        "completed_at": row[2].isoformat() if row[2] else None,
        "severity": row[3],
        "non_claims": memory_purge_contract_payload()["non_claims"],
    }


def cost_export_contract_payload() -> dict[str, object]:
    return {
        "contract_version": COST_EXPORT_CONTRACT_VERSION,
        "mode": "local_csv_export",
        "endpoint": "GET /api/v1/costs/export?format=csv&group_by=agent|model|session",
        "supported_formats": ["csv"],
        "supported_group_by": ["agent", "model", "session"],
        "default_group_by": "agent",
        "budget_limit_cents": get_budget_state().budget_limit_cents,
        "filename_pattern": "superbrain-costs-{group_by}.csv",
        "columns": [
            "group_by",
            "agent_type",
            "model_name",
            "provider_name",
            "session_id",
            "input_tokens",
            "output_tokens",
            "cost_cents",
            "from_cache",
            "row_count",
        ],
        "evidence_refs": {
            "contract": "cost_export_contract_visible",
            "csv": "cost_export_csv_generated",
            "audit": "cost_export_audit_persisted",
        },
        "policy_checks": [
            "CSV is generated from local cost_tracking rows.",
            "Export supports group_by agent, model, or session.",
            "Export includes budget limit metadata.",
            "Export writes a cost_export_generated audit event.",
            "No paid external reporting service is used.",
        ],
        "non_claims": [
            "This local export is not a provider invoice.",
            "This local export is not a Helicone billing export.",
            "This local export does not claim production cost reconciliation.",
        ],
    }


def system_fallback_contract_payload() -> dict[str, object]:
    return {
        "contract_version": SYSTEM_FALLBACK_CONTRACT_VERSION,
        "mode": "frontend_error_recovery_contract",
        "health_endpoint": "GET /api/v1/health",
        "ui_state": "System Unavailable",
        "trigger_conditions": [
            "GET /api/v1/health returns non-200",
            "GET /api/v1/health cannot be reached",
            "health.status is degraded or down",
            "any required service reports status down",
        ],
        "recovery_actions": [
            "show persistent System Unavailable Fallback panel",
            "show failed or degraded service names",
            "keep retry button visible",
            "do not claim healthy until health endpoint confirms healthy",
        ],
        "policy_checks": [
            "no_fake_healthy_claim",
            "failed_service_visible",
            "manual_retry_available",
            "health_endpoint_named",
        ],
        "evidence_refs": {
            "contract_visible": "system_fallback_contract_visible",
            "unavailable_state": "system_unavailable_ui_state",
            "degraded_service": "system_degraded_service_visible",
        },
        "non_claims": [
            "This is not a high-availability guarantee.",
            "This does not create multi-region failover.",
            "This does not hide degraded service state from the user.",
        ],
    }


def agent_activity_contract_payload() -> dict[str, object]:
    langfuse_public_url = os.getenv("LANGFUSE_PUBLIC_URL", "").rstrip("/")
    auth_proxy_path = os.getenv("LANGFUSE_AUTH_PROXY_PATH", "/observability/langfuse")
    deep_link_template = (
        f"{langfuse_public_url}/trace/{{trace_id}}"
        if langfuse_public_url
        else f"{auth_proxy_path}/trace/{{trace_id}}"
    )
    return {
        "contract_version": AGENT_ACTIVITY_CONTRACT_VERSION,
        "mode": "audit_log_backed_trace_view",
        "screen": "Agent Activity",
        "source_endpoints": [
            "GET /api/v1/agent-activity/recent?limit=50&severity=&event_type=&agent_type=&trace_id=",
            "GET /api/v1/audit/recent?limit=50",
            "GET /api/v1/audit/mcp?limit=50",
            "GET /api/v1/escalations/recent?limit=50",
        ],
        "trace_fields": [
            "trace_id",
            "session_id",
            "event_type",
            "severity",
            "created_at",
            "details",
            "per_role_results",
            "role_summary_count",
            "partial_failure",
            "partial_failure_reasons",
            "aggregation_evidence_ref",
        ],
        "langfuse": {
            "live_langfuse_deep_link": bool(langfuse_public_url),
            "auth_proxy_required": True,
            "auth_proxy_strategy": "nginx-basic-auth-or-vpn",
            "public_url_configured": bool(langfuse_public_url),
            "deep_link_template": deep_link_template,
        },
        "filters": ["agent_type", "event_type", "severity", "time_range", "trace_id"],
        "policy_checks": [
            "trace_id_visible",
            "langfuse_access_requires_auth_proxy",
            "audit_log_is_source_of_truth",
            "no_public_langfuse_without_auth",
            "per_role_results_visible",
        ],
        "evidence_refs": {
            "contract_visible": "agent_activity_contract_visible",
            "trace_link_template": "agent_activity_trace_link_template",
            "auth_proxy_required": "langfuse_auth_proxy_required",
            "filtered_feed": "agent_activity_filtered_feed_visible",
            "per_role_results": "agent_activity_per_role_results_visible",
        },
        "non_claims": [
            "This contract does not claim public unauthenticated Langfuse access.",
            "This contract does not claim live Langfuse traces until LANGFUSE_PUBLIC_URL is configured.",
            "Audit-log activity remains the local source of truth for Phase 3.",
        ],
    }


def cost_export_rows(group_by: str) -> list[dict[str, object]]:
    if group_by not in {"agent", "model", "session"}:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_group_by", "allowed": ["agent", "model", "session"]},
        )

    select_by_group = {
        "agent": "COALESCE(agent_type, 'unknown')",
        "model": "model_name",
        "session": "COALESCE(session_id::text, 'none')",
    }[group_by]
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            f"""
            SELECT
              {select_by_group} AS group_value,
              COALESCE(agent_type, 'unknown') AS agent_type,
              model_name,
              provider_name,
              COALESCE(session_id::text, '') AS session_id,
              COALESCE(SUM(input_tokens), 0) AS input_tokens,
              COALESCE(SUM(output_tokens), 0) AS output_tokens,
              COALESCE(SUM(cost_cents), 0) AS cost_cents,
              BOOL_OR(from_cache) AS from_cache,
              COUNT(*) AS row_count
            FROM cost_tracking
            GROUP BY group_value, agent_type, model_name, provider_name, session_id
            ORDER BY cost_cents DESC, group_value ASC
            """,
        ).fetchall()

    return [
        {
            "group_by": row[0],
            "agent_type": row[1],
            "model_name": row[2],
            "provider_name": row[3],
            "session_id": row[4],
            "input_tokens": int(row[5] or 0),
            "output_tokens": int(row[6] or 0),
            "cost_cents": int(row[7] or 0),
            "from_cache": bool(row[8]),
            "row_count": int(row[9] or 0),
        }
        for row in rows
    ]


def build_cost_export_csv(group_by: str) -> str:
    output = io.StringIO()
    fieldnames = cost_export_contract_payload()["columns"]
    writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    for row in cost_export_rows(group_by):
        writer.writerow(row)
    return output.getvalue()


def persist_cost_export_audit(group_by: str, row_count: int, trace_id: str, request_id: str) -> None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('cost_export_generated', 'cost-monitor', %s::jsonb, 'info')
                """,
                (
                    Json(
                        redact_json(
                            {
                                "contract_version": COST_EXPORT_CONTRACT_VERSION,
                                "trace_id": trace_id,
                                "request_id": request_id,
                                "group_by": group_by,
                                "format": "csv",
                                "row_count": row_count,
                                "correlation_evidence_ref": "request_id_audit_correlation",
                                "evidence_ref": "cost_export_audit_persisted",
                            }
                        )
                    ),
                ),
            )
    except Exception:
        pass


def persist_task_policy_block(assignment: TaskAssignment, violation: TaskPolicyViolation) -> None:
    try:
        session_id: str | None = str(UUID(assignment.session_id))
    except ValueError:
        session_id = None
    details = redact_json({
        "code": violation.code,
        "violations": violation.violations,
        "assignment": assignment.model_dump(),
        "policy": task_policy_manifest(),
    })
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, session_id, details, severity)
                VALUES ('task_policy_blocked', %s, %s, %s::jsonb, 'critical')
                """,
                (assignment.agent_type, session_id, Json(details)),
            )
    except Exception:
        pass


def persist_langgraph_dry_run_audit(state: dict[str, object]) -> None:
    node_name = str(state.get("node_name") or "unknown")
    event_type = "langgraph_dry_run_completed" if node_name == "completed" else "langgraph_dry_run_stopped"
    severity = "info" if node_name == "completed" else "warning"
    raw_session_id = state.get("session_id")
    try:
        session_id: str | None = str(UUID(str(raw_session_id)))
    except (TypeError, ValueError):
        session_id = None

    result = state.get("result")
    if not isinstance(result, dict):
        result = {}
    per_role_results = result.get("per_role_results")
    if not isinstance(per_role_results, list):
        per_role_results = []
    partial_failure = bool(result.get("partial_failure", False))
    partial_failure_reasons = result.get("partial_failure_reasons")
    if not isinstance(partial_failure_reasons, list):
        partial_failure_reasons = []
    aggregation_evidence_ref = None
    if per_role_results:
        aggregation_evidence_ref = (
            "agent_result_aggregation_partial_failure_detected"
            if partial_failure
            else "agent_result_aggregation_complete"
        )
    details = redact_json(
        {
            "thread_id": raw_session_id,
            "run_id": state.get("run_id"),
            "node_name": node_name,
            "hard_stop_reason": state.get("hard_stop_reason"),
            "retry_counters": state.get("retry_counters", {}),
            "structured_intent": state.get("structured_intent", {}),
            "budget_decisions": state.get("budget_decisions", []),
            "evidence_refs": state.get("evidence_refs", []),
            "live_provider_calls": False,
            "checkpointing": "postgres",
            "result_summary": result.get("summary"),
            "per_role_results": per_role_results,
            "role_summary_count": len(per_role_results),
            "partial_failure": partial_failure,
            "partial_failure_reasons": partial_failure_reasons,
            "aggregation_evidence_ref": aggregation_evidence_ref,
        }
    )
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, session_id, details, severity)
                VALUES (%s, %s, %s::jsonb, %s)
                """,
                (event_type, session_id, Json(details), severity),
            )
    except Exception:
        pass


def phase2_runtime_contract_payload() -> dict[str, object]:
    return {
        "contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
        "mode": "deterministic_local_runtime",
        "engine": "langgraph",
        "backing_graph": "services/agent-api/app/orchestrator.py",
        "start_endpoint": "POST /api/v1/phase2/runtime/start",
        "stream_endpoint": "POST /api/v1/orchestrator/dry-run/stream",
        "runs_endpoint": "GET /api/v1/phase2/runtime/runs",
        "contract_endpoint": "GET /api/v1/phase2/runtime/contract",
        "sse_event_contract": {
            "contract_version": PHASE2_SSE_EVENT_CONTRACT_VERSION,
            "content_type": "text/event-stream",
            "required_event_types": list(PHASE2_SSE_REQUIRED_EVENTS),
            "event_id_replay": True,
            "evidence_ref": PHASE2_SSE_EVENT_EVIDENCE_REF,
            "error_probe": "force_phase2_sse_error_event",
        },
        "mcp_timeout_contract": {
            "probe": f"{MCP_TIMEOUT_PROBE_PREFIX}tester",
            "gateway_capability": "simulate_timeout",
            "gateway_evidence_ref": "mcp_timeout_guard",
            "orchestrator_evidence_ref": LANGGRAPH_MCP_TIMEOUT_EVIDENCE_REF,
            "controlled_result": "partial_failure",
            "terminal_stream_event": "done",
        },
        "checkpointing": "postgres",
        "live_provider_calls": False,
        "live_mcp_writes": False,
        "production_deploy": False,
        "gates": {
            "gate_d_live_providers": "closed",
            "gate_e_live_writes_and_deploy": "closed",
        },
        "required_evidence_refs": [
            PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
            PHASE2_SSE_EVENT_EVIDENCE_REF,
            LANGGRAPH_MCP_TIMEOUT_EVIDENCE_REF,
            "langgraph_dry_run",
            "llm_gateway_dry_run",
            "llm_gateway_streaming_dry_run",
            "llm_routing_policy_primary_allowed",
            "memory_context_injected",
            "task_assignment_completed",
            "mcp_tool_success",
            "memory_update_persisted",
        ],
        "non_claims": [
            "This starts the local deterministic Phase 2 LangGraph runtime contract only.",
            "It does not call live LLM providers.",
            "It does not perform live MCP writes.",
            "It does not deploy to production.",
        ],
    }


def persist_phase2_runtime_audit(state: dict[str, object]) -> None:
    raw_session_id = state.get("session_id")
    try:
        session_id: str | None = str(UUID(str(raw_session_id)))
    except (TypeError, ValueError):
        session_id = None
    result = state.get("result")
    if not isinstance(result, dict):
        result = {}
    per_role_results = result.get("per_role_results")
    if not isinstance(per_role_results, list):
        per_role_results = []
    partial_failure = bool(result.get("partial_failure", False))
    partial_failure_reasons = result.get("partial_failure_reasons")
    if not isinstance(partial_failure_reasons, list):
        partial_failure_reasons = []
    aggregation_evidence_ref = None
    if per_role_results:
        aggregation_evidence_ref = (
            "agent_result_aggregation_partial_failure_detected"
            if partial_failure
            else "agent_result_aggregation_complete"
        )
    details = redact_json(
        {
            "contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
            "thread_id": raw_session_id,
            "run_id": state.get("run_id"),
            "node_name": state.get("node_name"),
            "checkpointing": "postgres",
            "live_provider_calls": False,
            "live_mcp_writes": False,
            "production_deploy": False,
            "evidence_refs": state.get("evidence_refs", []),
            "memory_update_id": state.get("memory_update_id"),
            "result_summary": result.get("summary"),
            "per_role_results": per_role_results,
            "role_summary_count": len(per_role_results),
            "partial_failure": partial_failure,
            "partial_failure_reasons": partial_failure_reasons,
            "aggregation_evidence_ref": aggregation_evidence_ref,
        }
    )
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, session_id, details, severity)
                VALUES (%s, %s, %s::jsonb, 'info')
                """,
                (PHASE2_RUNTIME_GRAPH_EVIDENCE_REF, session_id, Json(details)),
            )
    except Exception:
        pass


def phase2_runtime_run_from_audit_row(row: tuple[object, ...]) -> dict[str, object]:
    details = dict(row[0] or {})
    node_name = details.get("node_name")
    status = "completed" if node_name == "completed" else "stopped"
    per_role_results = details.get("per_role_results")
    if not isinstance(per_role_results, list):
        per_role_results = []
    partial_failure_reasons = details.get("partial_failure_reasons")
    if not isinstance(partial_failure_reasons, list):
        partial_failure_reasons = []
    return {
        "contract_version": details.get("contract_version", PHASE2_RUNTIME_CONTRACT_VERSION),
        "status": status,
        "thread_id": details.get("thread_id") or (str(row[3]) if row[3] else None),
        "session_id": str(row[3]) if row[3] else None,
        "run_id": details.get("run_id"),
        "node_name": node_name,
        "checkpointing": details.get("checkpointing", "postgres"),
        "live_provider_calls": bool(details.get("live_provider_calls", False)),
        "live_mcp_writes": bool(details.get("live_mcp_writes", False)),
        "production_deploy": bool(details.get("production_deploy", False)),
        "evidence_refs": details.get("evidence_refs", []),
        "memory_update_id": details.get("memory_update_id"),
        "role_summary_count": int(details.get("role_summary_count", len(per_role_results)) or 0),
        "per_role_results": per_role_results,
        "partial_failure": bool(details.get("partial_failure", False)),
        "partial_failure_reasons": partial_failure_reasons,
        "aggregation_evidence_ref": details.get("aggregation_evidence_ref"),
        "created_at": row[1].isoformat() if row[1] else None,
        "severity": row[2],
        "evidence_ref": "phase2_runtime_run_status_visible",
    }


def workflow_dispatch_contract(request: WorkflowDispatchRequest) -> dict[str, object]:
    owner = os.getenv("GITHUB_REPOSITORY_OWNER", "strazzusochr")
    repository = os.getenv("GITHUB_REPOSITORY_NAME", "-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM")
    workflow_id = request.workflow_id.strip()
    ref = request.ref.strip()
    inputs = {
        "environment": request.environment,
        "action": request.action,
        "image_tag": request.image_tag or "dry-run-image-tag-required-before-live-dispatch",
        "reason": redact_text(request.reason),
        "trace_id": request.trace_id or f"devops-dispatch-{uuid4()}",
        "dry_run": "true",
    }
    payload = {"ref": ref, "inputs": inputs}
    endpoint = f"/repos/{owner}/{repository}/actions/workflows/{workflow_id}/dispatches"
    violations: list[str] = []
    if request.environment == "production" and not request.human_review_approved:
        violations.append("production workflow dispatch requires human_review_approved=true")
    if not request.dry_run:
        violations.append("live GitHub workflow dispatch is blocked in Phase 2 local runtime")
    if request.action == "rollback" and request.environment == "production" and not request.human_review_approved:
        violations.append("production rollback requires human review gate")
    status = "blocked" if violations else "ready"
    return {
        "contract_version": "devops-workflow-dispatch-v1",
        "status": status,
        "mode": "dry_run_contract_only",
        "live_github_call": False,
        "github_api": {
            "method": "POST",
            "endpoint": endpoint,
            "required_token_env": "GITHUB_TOKEN",
            "required_permission": "actions:write",
        },
        "payload": payload,
        "human_gate": {
            "required_for": ["production", "rollback_production", "resource_limit_increase"],
            "approved": request.human_review_approved,
        },
        "violations": violations,
        "non_claims": [
            "No GitHub Actions workflow was dispatched by this local proof.",
            "Production deployment remains blocked without human review and hosted staging proof.",
        ],
    }


def persist_workflow_dispatch_audit(request: WorkflowDispatchRequest, contract: dict[str, object]) -> None:
    severity = "info" if contract["status"] == "ready" else "critical"
    details = redact_json({
        "request": request.model_dump(),
        "contract": contract,
    })
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('devops_workflow_dispatch_contract', 'devops', %s::jsonb, %s)
                """,
                (Json(details), severity),
            )
    except Exception:
        pass


def project_progress_payload() -> dict[str, object]:
    manifest_path = Path(os.getenv("PROJECT_PROGRESS_MANIFEST_PATH", "/app/progress/project-progress.manifest.json"))
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    phases = payload.get("horizontal", {}).get("items", [])
    layers = payload.get("vertical", {}).get("items", [])
    if len(phases) != 7:
        raise RuntimeError("project progress manifest must contain exactly 7 phase items")
    if len(layers) != 7:
        raise RuntimeError("project progress manifest must contain exactly 7 architecture layer items")
    for item in [*phases, *layers]:
        percent = int(item["percent"])
        if percent < 0 or percent > 100:
            raise RuntimeError(f"project progress percent out of range for {item.get('id')}")
    expected_overall = round(sum(int(item["percent"]) for item in phases) / len(phases))
    if int(payload.get("overall_percent", -1)) != expected_overall:
        raise RuntimeError("project progress overall_percent must equal rounded average of phase percentages")
    return payload


def project_progress_integrity_payload() -> dict[str, object]:
    progress = project_progress_payload()
    phases = list(progress["horizontal"]["items"])  # type: ignore[index]
    layers = list(progress["vertical"]["items"])  # type: ignore[index]
    phase_percents = [int(item["percent"]) for item in phases]
    layer_percents = [int(item["percent"]) for item in layers]
    computed_overall = round(sum(phase_percents) / len(phase_percents))
    manifest_overall = int(progress["overall_percent"])
    mismatches: list[str] = []
    if manifest_overall != computed_overall:
        mismatches.append("overall_percent_mismatch")
    if progress.get("progress_source") != "docs/project-progress.manifest.json":
        mismatches.append("progress_source_mismatch")
    if progress.get("binding_document") != "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md":
        mismatches.append("binding_document_mismatch")
    if PROGRESS_INTEGRITY_EVIDENCE_REF not in str(phases[4].get("status", "")):
        mismatches.append("phase4_integrity_evidence_missing")
    return {
        "contract_version": PROGRESS_INTEGRITY_CONTRACT_VERSION,
        "status": "verified" if not mismatches else "blocked",
        "endpoint": "GET /api/v1/project/progress/integrity",
        "guarded_endpoint": "GET /api/v1/project/progress",
        "source_manifest": progress.get("progress_source"),
        "binding_document": progress.get("binding_document"),
        "manifest_overall_percent": manifest_overall,
        "computed_overall_percent": computed_overall,
        "horizontal_phase_count": len(phases),
        "vertical_layer_count": len(layers),
        "horizontal_phase_percentages": {str(item["id"]): int(item["percent"]) for item in phases},
        "vertical_layer_percentages": {str(item["id"]): int(item["percent"]) for item in layers},
        "truth_policy": progress.get("truth_policy"),
        "evidence_ref": PROGRESS_INTEGRITY_EVIDENCE_REF,
        "mismatches": mismatches,
        "hard_rules": [
            "overall_percent must equal rounded average of the seven horizontal phase percentages",
            "progress source must remain docs/project-progress.manifest.json",
            "binding document must remain docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md",
            "new progress claims require code, runtime proof, verifier proof, and documentation update",
        ],
        "non_claims": [
            "This endpoint does not increase progress by itself.",
            "This endpoint does not claim live LLM provider calls.",
            "This endpoint does not claim hosted staging or production deployment.",
        ],
    }


def _completion_status(percent: int, blockers: list[str]) -> str:
    if percent >= 100 and not blockers:
        return "verified_100"
    if blockers:
        return "blocked_external_gate"
    return "ready_for_evidence_slice"


def project_progress_completion_payload() -> dict[str, object]:
    progress = project_progress_payload()
    gates = external_gate_state()
    gate_items = list(gates["gates"])
    missing_gate_ids = [str(gate["id"]) for gate in gate_items if not gate["configured"]]
    missing_gate_blocker_map = {
        "staging_base_url": "hosted_staging_proof_requires_STAGING_BASE_URL",
        "branch_protection_token": "protected_main_proof_requires_BRANCH_PROTECTION_TOKEN",
        "gitleaks_binary": "canonical_secret_scan_requires_gitleaks_binary",
        "hetzner_api_token": "live_infra_budget_refresh_requires_HETZNER_API_TOKEN",
    }
    missing_external_gate_blockers = [
        blocker for gate_id, blocker in missing_gate_blocker_map.items() if gate_id in missing_gate_ids
    ]
    production_release_blocker = "production_release_requires_hosted_staging_branch_protection_secret_scan_and_owner_review"
    release_gate_ids = {"staging_base_url", "branch_protection_token", "gitleaks_binary"}
    if any(gate_id in missing_gate_ids for gate_id in release_gate_ids):
        missing_external_gate_blockers.append(production_release_blocker)
    phase_blockers: dict[str, list[str]] = {
        "phase_0": [],
        "phase_1": ["hosted_staging_proof_requires_STAGING_BASE_URL", "canonical_secret_scan_requires_gitleaks_binary"],
        "phase_2": ["live_llm_provider_calls_require_owner_gate_and_budget_guard"],
        "phase_3": ["production_auth_identity_requires_owner_configured_oauth_and_hosted_url"],
        "phase_4": [
            "hosted_staging_proof_requires_STAGING_BASE_URL",
            "protected_main_proof_requires_BRANCH_PROTECTION_TOKEN",
            "live_infra_budget_refresh_requires_HETZNER_API_TOKEN",
        ],
        "phase_5": [
            "production_release_requires_hosted_staging_branch_protection_secret_scan_and_owner_review",
            "docker_registry_publish_requires_owner_release_gate",
        ],
        "phase_6": [
            "phase6_scale_3d_platform_requires_separate_scale_budget_and_runtime_proof",
            "live_mcp_writes_require_owner_gate_branch_protection_and_audit",
        ],
    }
    layer_blockers: dict[str, list[str]] = {
        "layer_1": ["hosted_browser_proof_requires_STAGING_BASE_URL"],
        "layer_2": [],
        "layer_3": ["live_agent_tool_writes_require_owner_gate"],
        "layer_4": ["live_llm_provider_calls_require_owner_gate_and_budget_guard"],
        "layer_5": ["live_mcp_writes_require_owner_gate_branch_protection_and_audit"],
        "layer_6": ["live_embeddings_or_external_memory_provider_requires_owner_gate"],
        "layer_7": ["hosted_langfuse_or_grafana_proof_requires_owner_configured_endpoint"],
    }

    phases = []
    for item in progress["horizontal"]["items"]:  # type: ignore[index]
        percent = int(item["percent"])
        blockers = phase_blockers.get(str(item["id"]), [])
        phases.append({
            "id": item["id"],
            "label": item["label"],
            "current_percent": percent,
            "target_percent": 100,
            "remaining_percent": max(0, 100 - percent),
            "status": _completion_status(percent, blockers),
            "blockers": blockers,
            "next_safe_action": "continue_local_evidence_slices" if not blockers else "configure_external_gate_then_run_verifier",
        })

    layers = []
    for item in progress["vertical"]["items"]:  # type: ignore[index]
        percent = int(item["percent"])
        blockers = layer_blockers.get(str(item["id"]), [])
        layers.append({
            "id": item["id"],
            "label": item["label"],
            "current_percent": percent,
            "target_percent": 100,
            "remaining_percent": max(0, 100 - percent),
            "status": _completion_status(percent, blockers),
            "blockers": blockers,
            "next_safe_action": "continue_local_evidence_slices" if not blockers else "configure_external_gate_then_run_verifier",
        })

    has_progress_gaps = any(int(item["percent"]) < 100 for item in progress["horizontal"]["items"]) or any(  # type: ignore[index]
        int(item["percent"]) < 100 for item in progress["vertical"]["items"]  # type: ignore[index]
    )
    hard_blockers = [*missing_gate_ids, *missing_external_gate_blockers]
    if has_progress_gaps:
        hard_blockers.append("local_progress_gaps_require_verified_evidence_for_each_phase_and_layer")
    status = "ready_for_100_percent_review"
    if missing_external_gate_blockers:
        status = "blocked_external_gates"
    elif has_progress_gaps:
        status = "blocked_unverified_progress_gaps"
    return {
        "contract_version": PROGRESS_COMPLETION_CONTRACT_VERSION,
        "status": status,
        "endpoint": "GET /api/v1/project/progress/completion",
        "requested_target_percent": 100,
        "current_overall_percent": int(progress["overall_percent"]),
        "can_set_all_to_100": not hard_blockers,
        "evidence_ref": PROGRESS_COMPLETION_EVIDENCE_REF,
        "truth_policy": progress["truth_policy"],
        "missing_external_gates": missing_gate_ids,
        "missing_external_gate_blockers": missing_external_gate_blockers,
        "hard_blockers": hard_blockers,
        "phase_completion": phases,
        "layer_completion": layers,
        "safe_autonomy": [
            "Autonomous code, verifier, UI, and deterministic runtime work may continue.",
            "Percentages cannot be raised to 100 while required external gates are missing.",
            "Localhost proof remains DEV-ONLY and cannot close hosted staging, production, live-provider, or live-MCP claims.",
        ],
        "non_claims": [
            "This contract does not set progress to 100.",
            "This contract does not claim hosted staging success.",
            "This contract does not claim production deployment.",
            "This contract does not claim live LLM provider calls or live MCP writes.",
        ],
    }


@app.on_event("startup")
def startup() -> None:
    app.state.applied_migrations = run_migrations()
    ensure_postgres_checkpointer()


@app.get("/api/v1/project/progress")
def project_progress() -> dict[str, object]:
    return project_progress_payload()


@app.get("/api/v1/project/progress/integrity")
def project_progress_integrity() -> dict[str, object]:
    return project_progress_integrity_payload()


@app.get("/api/v1/project/progress/completion")
def project_progress_completion() -> dict[str, object]:
    return project_progress_completion_payload()


def cloud_render_offload_contract_payload() -> dict[str, object]:
    required_env = [
        "STAGING_BASE_URL",
        "AGENT_API_BASE_URL",
        "MCP_GATEWAY_BASE_URL",
        "LLM_GATEWAY_BASE_URL",
        "HETZNER_API_TOKEN",
    ]
    optional_env = [
        "VERCEL_TOKEN",
        "CLOUDFLARE_API_TOKEN",
        "GITHUB_TOKEN",
        "GHCR_TOKEN",
        "GITKRAKEN_API_TOKEN",
    ]
    env_status = [{"key": key, "configured": bool(os.getenv(key))} for key in [*required_env, *optional_env]]
    missing_required = [key for key in required_env if not os.getenv(key)]
    blockers = [f"cloud_render_offload_requires_{key}" for key in missing_required]
    return {
        "contract_version": CLOUD_RENDER_OFFLOAD_CONTRACT_VERSION,
        "status": "cloud_runtime_ready" if not blockers else "action_required",
        "endpoint": "GET /api/v1/clouds/render-offload/contract",
        "evidence_ref": CLOUD_RENDER_OFFLOAD_EVIDENCE_REF,
        "localhost_role": "dev_control_plane_only",
        "localhost_heavy_render_allowed": False,
        "home_pc_protection": True,
        "required_env": required_env,
        "optional_env": optional_env,
        "env_status": env_status,
        "missing_required_env": missing_required,
        "blockers": blockers,
        "example_blocker": "cloud_render_offload_requires_STAGING_BASE_URL",
        "cloud_gates": [
            {
                "id": "hosted_frontend",
                "required_env": "STAGING_BASE_URL",
                "configured": bool(os.getenv("STAGING_BASE_URL")),
                "evidence_ref": "hosted_frontend_preview_visible",
            },
            {
                "id": "hosted_agent_api",
                "required_env": "AGENT_API_BASE_URL",
                "configured": bool(os.getenv("AGENT_API_BASE_URL")),
                "evidence_ref": "hosted_agent_api_health_required",
            },
            {
                "id": "hosted_mcp_gateway",
                "required_env": "MCP_GATEWAY_BASE_URL",
                "configured": bool(os.getenv("MCP_GATEWAY_BASE_URL")),
                "evidence_ref": "cloud_mcp_gateway_health",
            },
            {
                "id": "hosted_llm_gateway",
                "required_env": "LLM_GATEWAY_BASE_URL",
                "configured": bool(os.getenv("LLM_GATEWAY_BASE_URL")),
                "evidence_ref": "cloud_llm_gateway_health",
            },
            {
                "id": "hetzner_runtime_budget",
                "required_env": "HETZNER_API_TOKEN",
                "configured": bool(os.getenv("HETZNER_API_TOKEN")),
                "evidence_ref": "hetzner_live_budget_check",
            },
        ],
        "workloads": [
            {
                "id": "webgl_3d_rendering",
                "label": "WebGL / 3D rendering",
                "local_allowed": False,
                "required_runtime": "hosted_cloud_browser_or_cloud_gpu_worker",
                "blocker": "webgl_3d_rendering_requires_hosted_cloud_runtime",
            },
            {
                "id": "browser_gpu_smoke",
                "label": "Browser GPU smoke and screenshots",
                "local_allowed": False,
                "required_runtime": "hosted_cloud_browser_proof",
                "blocker": "browser_gpu_smoke_requires_STAGING_BASE_URL",
            },
            {
                "id": "asset_generation",
                "label": "Generated graphics, textures, previews, and video capture",
                "local_allowed": False,
                "required_runtime": "cloud_worker_queue",
                "blocker": "asset_generation_requires_cloud_worker_runtime",
            },
            {
                "id": "control_plane",
                "label": "Local dashboard, API contracts, and fail-closed verifiers",
                "local_allowed": True,
                "required_runtime": "localhost_dev_control_plane_only",
                "blocker": None,
            },
        ],
        "policy_checks": [
            "Localhost may run lightweight API and dashboard checks only.",
            "3D/WebGL rendering, browser GPU smoke, screenshots, and generated asset workloads require hosted cloud runtime proof.",
            "Cloud render offload does not bypass the Hetzner budget guard.",
            "The cloud-only staging verifier remains the release gate for hosted frontend/API/MCP/LLM proof.",
        ],
        "non_claims": [
            "This contract does not start cloud servers.",
            "This contract does not claim production deployment.",
            "This contract does not claim live LLM provider calls.",
            "This contract does not store or return provider token values.",
        ],
    }


def cloud_deployment_preflight_payload() -> dict[str, object]:
    def env_ready(keys: list[str]) -> bool:
        return all(bool(os.getenv(key)) for key in keys)

    gates = [
        {
            "id": "ghcr_images",
            "label": "GHCR application images",
            "required_env": ["GITHUB_TOKEN", "GHCR_TOKEN"],
            "required_artifact": ".github/workflows/main-deploy.yml",
            "verifier": "scripts/verify-phase1.ps1",
            "environment_configured": env_ready(["GITHUB_TOKEN", "GHCR_TOKEN"]),
            "configured": False,
            "verified": False,
            "evidence_ref": "ghcr_image_digest_proof",
            "required_evidence_artifact": "published GHCR image digests for all six application services",
            "next_action": "dispatch_main_deploy_workflow_after_github_auth_is_repaired",
        },
        {
            "id": "hetzner_cloud_stack",
            "label": "Hetzner pull-based cloud stack",
            "required_env": ["HETZNER_API_TOKEN"],
            "required_artifact": "docker-compose.cloud.yml",
            "verifier": "scripts/check_hetzner_infra_budget.py",
            "environment_configured": env_ready(["HETZNER_API_TOKEN"]),
            "configured": False,
            "verified": False,
            "evidence_ref": "hetzner_live_budget_check",
            "required_evidence_artifact": "current Hetzner budget proof plus reachable cloud compose health checks",
            "next_action": "run_cloud_compose_pull_and_up_on_hetzner_host_with_environment_only_secrets",
        },
        {
            "id": "hosted_backend_origins",
            "label": "Vercel backend origin environment",
            "required_env": ["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"],
            "required_artifact": "docs/runbooks/cloud-secret-runtime-injection.md",
            "verifier": "scripts/verify-cloud-only-staging.ps1",
            "environment_configured": env_ready(["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"]),
            "configured": False,
            "verified": False,
            "evidence_ref": "hosted_backend_origin_env_required",
            "required_evidence_artifact": "cloud-only staging proof with hosted backend origin URLs",
            "next_action": "configure_vercel_backend_origin_urls_after_hetzner_stack_is_reachable",
        },
        {
            "id": "hosted_staging",
            "label": "Hosted staging proof URL",
            "required_env": ["STAGING_BASE_URL"],
            "required_artifact": ".github/workflows/hosted-staging-proof.yml",
            "verifier": "scripts/verify-hosted-staging.ps1",
            "environment_configured": env_ready(["STAGING_BASE_URL"]),
            "configured": False,
            "verified": False,
            "evidence_ref": "hosted_staging_base_url_required",
            "required_evidence_artifact": "hosted staging verifier artifact from a non-localhost HTTPS URL",
            "next_action": "run_hosted_staging_verifier_against_staging_base_url",
        },
        {
            "id": "branch_protection",
            "label": "Protected main branch verification",
            "required_env": ["BRANCH_PROTECTION_TOKEN"],
            "required_artifact": ".github/workflows/branch-protection.yml",
            "verifier": "scripts/apply_github_branch_protection.py --verify-only",
            "environment_configured": env_ready(["BRANCH_PROTECTION_TOKEN"]),
            "configured": False,
            "verified": False,
            "evidence_ref": BRANCH_PROTECTION_VERIFY_EVIDENCE_REF,
            "required_evidence_artifact": "branch protection verify-only pass against the live GitHub repository",
            "next_action": "verify_branch_protection_with_repository_admin_token",
        },
        {
            "id": "canonical_secret_scan",
            "label": "Canonical secret scan",
            "required_env": [],
            "required_artifact": "gitleaks",
            "verifier": "gitleaks detect --no-git --source .",
            "environment_configured": True,
            "tool_configured": shutil.which("gitleaks") is not None,
            "configured": False,
            "verified": False,
            "evidence_ref": "canonical_gitleaks_scan",
            "required_evidence_artifact": "current gitleaks scan artifact with no findings",
            "next_action": "install_or_use_gitleaks_before_release_claim",
        },
    ]
    missing_or_blocked = [gate["id"] for gate in gates if not gate["verified"]]
    return {
        "contract_version": CLOUD_DEPLOYMENT_PREFLIGHT_CONTRACT_VERSION,
        "status": "ready_for_external_execution" if not missing_or_blocked else "action_required",
        "endpoint": "GET /api/v1/clouds/deployment-preflight/contract",
        "evidence_ref": CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF,
        "required_sequence": [
            "publish_ghcr_images",
            "start_hetzner_pull_based_stack",
            "configure_vercel_backend_origins",
            "run_hosted_staging_verifier",
            "verify_branch_protection",
            "run_canonical_secret_scan",
            "owner_review_before_production",
        ],
        "gates": gates,
        "missing_or_blocked_gates": missing_or_blocked,
        "preflight_ready": not missing_or_blocked,
        "external_execution_ready": not missing_or_blocked,
        "cloud_deploy_claim_allowed": False,
        "production_deploy_claim_allowed": False,
        "localhost_role": "dev_control_plane_only",
        "manual_external_actions": [
            "gh workflow run main-deploy.yml",
            "docker compose -f docker-compose.cloud.yml pull",
            "docker compose -f docker-compose.cloud.yml up -d",
            "powershell -ExecutionPolicy Bypass -File scripts\\verify-hosted-staging.ps1",
            "py -3 scripts\\apply_github_branch_protection.py --verify-only",
            "gitleaks detect --no-git --source .",
        ],
        "claim_policy": "environment presence only never creates a cloud, hosted staging, or production deployment claim",
        "policy_checks": [
            "All secrets are referenced by environment variable name only.",
            "GHCR image publication, Hetzner compose execution, Vercel env writes, and branch-protection writes remain external gated actions.",
            "Localhost proof is development-only and cannot satisfy hosted staging.",
            "Production deployment requires hosted staging, branch protection, canonical secret scan, budget proof, and owner review.",
        ],
        "non_claims": [
            "This endpoint does not push images.",
            "This endpoint does not create, mutate, deploy, or delete cloud resources.",
            "This endpoint does not configure Vercel or GitHub settings.",
            "This endpoint does not return or store provider token values.",
            "This endpoint does not claim hosted staging success or production deployment.",
        ],
    }


@app.get("/api/v1/external-gates")
def external_gates() -> dict[str, object]:
    return external_gate_state()


@app.get("/api/v1/external-gates/mirror")
def external_gates_mirror() -> dict[str, object]:
    return external_gate_mirror_state()


@app.get("/api/v1/clouds")
def clouds() -> dict[str, object]:
    return cloud_provider_state()


@app.get("/api/v1/clouds/layers")
def cloud_layers() -> dict[str, object]:
    return cloud_layer_readiness_state()


@app.get("/api/v1/clouds/render-offload/contract")
def cloud_render_offload_contract() -> dict[str, object]:
    return cloud_render_offload_contract_payload()


@app.get("/api/v1/clouds/deployment-preflight/contract")
def cloud_deployment_preflight_contract() -> dict[str, object]:
    return cloud_deployment_preflight_payload()


@app.get("/api/v1/auth/contract")
def auth_contract() -> dict[str, object]:
    return auth_contract_payload()


@app.get("/api/v1/auth/github")
@app.post("/api/v1/auth/github")
def auth_github_start() -> dict[str, object]:
    contract = auth_contract_payload()
    client_id = os.getenv("GITHUB_OAUTH_CLIENT_ID", "not-configured")
    state = "phase3-auth-state-" + secrets.token_urlsafe(12)
    authorize_url = (
        "https://github.com/login/oauth/authorize"
        f"?client_id={client_id}&scope=read:user%20user:email&state={state}"
    )
    return {
        "contract_version": contract["contract_version"],
        "status": "ready" if contract["github_oauth_configured"] else "configuration_required",
        "mode": contract["mode"],
        "live_github_oauth_call": False,
        "authorize_url_template": authorize_url,
        "state_required": True,
        "non_claims": contract["non_claims"],
    }


@app.get("/api/v1/auth/callback")
def auth_callback(
    response: Response,
    code: str = Query(..., min_length=1, max_length=255),
    state: str = Query(..., min_length=1, max_length=255),
) -> dict[str, object]:
    trace_id = f"auth-callback-{uuid4()}"
    access_token = create_access_jwt("github:local-contract-user", trace_id)
    refresh_token = create_refresh_token()
    set_auth_cookies(response, access_token, refresh_token)
    persist_auth_audit(
        "auth_github_callback_contract",
        {
            "trace_id": trace_id,
            "state": state,
            "code_present": bool(code),
            "live_github_oauth_call": False,
            "cookie_flags": auth_contract_payload()["cookie_flags"],
        },
    )
    return {
        "status": "authenticated",
        "contract_version": "auth-github-jwt-refresh-v1",
        "mode": "local_contract_with_dry_run_oauth",
        "live_github_oauth_call": False,
        "access_token_issued": True,
        "refresh_token_issued": True,
        "access_token_expires_in": AUTH_ACCESS_TOKEN_TTL_SECONDS,
        "refresh_token_expires_in": AUTH_REFRESH_TOKEN_TTL_SECONDS,
        "cookie_flags": auth_contract_payload()["cookie_flags"],
        "trace_id": trace_id,
        "non_claims": auth_contract_payload()["non_claims"],
    }


@app.post("/api/v1/auth/refresh")
def auth_refresh(
    response: Response,
    request: AuthRefreshRequest | None = None,
    refresh_token_cookie: str | None = Cookie(default=None, alias="refresh_token"),
) -> dict[str, object]:
    supplied_token = (request.refresh_token if request else None) or refresh_token_cookie
    if not supplied_token:
        raise HTTPException(status_code=401, detail={"error": "refresh_token_missing"})
    client = redis_client()
    blacklist_key = auth_blacklist_key(supplied_token)
    if client.get(blacklist_key):
        persist_auth_audit(
            "auth_refresh_reuse_blocked",
            {"trace_id": request.trace_id if request else None, "blacklist_key": blacklist_key},
            "critical",
        )
        raise HTTPException(status_code=401, detail={"error": "refresh_token_invalid", "reason": "blacklisted"})
    client.setex(blacklist_key, AUTH_REFRESH_TOKEN_TTL_SECONDS, "rotated")
    trace_id = (request.trace_id if request else None) or f"auth-refresh-{uuid4()}"
    access_token = create_access_jwt("github:local-contract-user", trace_id)
    new_refresh_token = create_refresh_token()
    set_auth_cookies(response, access_token, new_refresh_token)
    persist_auth_audit(
        "auth_refresh_rotated",
        {
            "trace_id": trace_id,
            "old_refresh_blacklisted": True,
            "blacklist_key": blacklist_key,
            "new_refresh_issued": True,
            "cookie_flags": auth_contract_payload()["cookie_flags"],
        },
    )
    return {
        "status": "rotated",
        "contract_version": "auth-github-jwt-refresh-v1",
        "access_token_issued": True,
        "refresh_token_rotated": True,
        "old_refresh_token_blacklisted": True,
        "blacklist_key": blacklist_key,
        "access_token_expires_in": AUTH_ACCESS_TOKEN_TTL_SECONDS,
        "refresh_token_expires_in": AUTH_REFRESH_TOKEN_TTL_SECONDS,
        "cookie_flags": auth_contract_payload()["cookie_flags"],
        "trace_id": trace_id,
    }


@app.post("/api/v1/auth/logout")
def auth_logout(
    response: Response,
    request: AuthRefreshRequest | None = None,
    refresh_token_cookie: str | None = Cookie(default=None, alias="refresh_token"),
) -> dict[str, object]:
    supplied_token = (request.refresh_token if request else None) or refresh_token_cookie
    blacklist_key = None
    if supplied_token:
        blacklist_key = auth_blacklist_key(supplied_token)
        redis_client().setex(blacklist_key, AUTH_REFRESH_TOKEN_TTL_SECONDS, "logout")
    clear_auth_cookies(response)
    trace_id = (request.trace_id if request else None) or f"auth-logout-{uuid4()}"
    persist_auth_audit(
        "auth_logout_revoked",
        {
            "trace_id": trace_id,
            "refresh_token_revoked": bool(supplied_token),
            "blacklist_key": blacklist_key,
            "cookies_cleared": True,
        },
    )
    return {
        "status": "logged_out",
        "contract_version": "auth-github-jwt-refresh-v1",
        "refresh_token_revoked": bool(supplied_token),
        "cookies_cleared": True,
        "blacklist_key": blacklist_key,
        "trace_id": trace_id,
    }


@app.get("/api/v1/devops/workflow-dispatch/plan")
def workflow_dispatch_plan() -> dict[str, object]:
    request = WorkflowDispatchRequest(
        workflow_id="main-deploy.yml",
        ref="main",
        environment="staging",
        action="deploy",
        image_tag="ghcr.io/repo/agent-api:sha-placeholder",
        reason="deterministic staging dispatch contract preview",
        trace_id="devops-dispatch-plan",
        human_review_approved=False,
        dry_run=True,
    )
    return workflow_dispatch_contract(request)


@app.post("/api/v1/devops/workflow-dispatch/validate")
def validate_workflow_dispatch(request: WorkflowDispatchRequest) -> dict[str, object]:
    contract = workflow_dispatch_contract(request)
    persist_workflow_dispatch_audit(request, contract)
    if contract["status"] == "blocked":
        raise HTTPException(
            status_code=403,
            detail={
                "code": "workflow_dispatch_blocked",
                "contract": contract,
            },
        )
    return contract


@app.get("/api/v1/health")
def health() -> dict[str, object]:
    services: dict[str, object] = {}
    overall = "healthy"
    for name, checker in {
        "postgres": check_postgres,
        "redis": check_redis,
        "agent_worker": check_agent_worker,
        "memory_worker": check_memory_worker,
        "mcp_gateway": check_mcp,
        "llm_gateway": check_llm_gateway,
    }.items():
        try:
            services[name] = checker()
        except Exception as exc:
            overall = "degraded"
            services[name] = {"status": "down", "error": str(exc)}

    budget_state = get_budget_state()
    infra_budget_state = get_infra_budget_state()
    gates = external_gate_state()
    return {
        "status": overall,
        "service": "agent-api",
        "time": datetime.now(timezone.utc).isoformat(),
        "applied_migrations": getattr(app.state, "applied_migrations", []),
        "services": services,
        "budget": {
            "level": budget_state.level,
            "spent_percentage": budget_state.spent_percentage,
            "total_cost_cents": budget_state.total_cost_cents,
            "budget_limit_cents": budget_state.budget_limit_cents,
            "allow_new_calls": budget_state.allow_new_calls,
        },
        "infra_budget": {
            "level": infra_budget_state.level,
            "spent_percentage": infra_budget_state.spent_percentage,
            "projected_cost_cents": infra_budget_state.projected_cost_cents,
            "budget_limit_cents": infra_budget_state.budget_limit_cents,
            "allow_new_infra": infra_budget_state.allow_new_infra,
            "live_verified": infra_budget_state.live_verified,
            "source": infra_budget_state.source,
        },
        "external_gates": {
            "status": gates["status"],
            "configured_count": gates["configured_count"],
            "total_count": gates["total_count"],
            "local_execution_allowed": gates["local_execution_allowed"],
        },
    }


def ensure_project(conn: psycopg.Connection, project_id: str) -> str:
    with conn.cursor() as cur:
        existing = cur.execute(
            "SELECT id FROM projects WHERE metadata->>'external_id' = %s LIMIT 1",
            (project_id,),
        ).fetchone()
        if existing:
            return str(existing[0])
        created = cur.execute(
            """
            INSERT INTO projects(name, owner_id, metadata)
            VALUES (%s, %s, %s::jsonb)
            RETURNING id
            """,
            (project_id, "phase1-local", Json({"external_id": project_id})),
        ).fetchone()
        if not created:
            raise RuntimeError("project insert did not return an id")
        return str(created[0])


def ensure_agent_session(
    conn: psycopg.Connection,
    project_id: str,
    session_id: str,
    *,
    source: str,
    metadata: dict[str, object] | None = None,
) -> str:
    project_uuid = ensure_project(conn, project_id)
    conn.execute(
        """
        INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
        VALUES (%s, %s, %s, %s::jsonb)
        ON CONFLICT (id) DO UPDATE
        SET metadata = agent_sessions.metadata || EXCLUDED.metadata
        """,
        (
            session_id,
            project_uuid,
            ["planner", "coder", "tester", "devops"],
            Json({"source": source, **(metadata or {})}),
        ),
    )
    return project_uuid


@app.post("/api/v1/prompt", status_code=201)
def create_prompt(request: PromptRequest) -> dict[str, object]:
    session_id = request.session_id or str(uuid4())
    sanitized_prompt = redact_text(request.prompt)
    try:
        budget_state = check_budget_guard()
        rate_limit = rate_limit_prompt(request.project_id)
        llm_call_count = register_session_llm_call(session_id)
    except RuntimeError as exc:
        detail = str(exc)
        status_code = 402 if "budget" in detail.lower() else 429
        raise HTTPException(status_code=status_code, detail=detail) from exc

    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            project_uuid = ensure_project(conn, request.project_id)
            conn.execute(
                """
                INSERT INTO agent_sessions(id, project_id, agent_list, metadata)
                VALUES (%s, %s, %s, %s::jsonb)
                ON CONFLICT (id) DO NOTHING
                """,
                (session_id, project_uuid, ["planner"], Json({"source": "phase1-smoke"})),
            )
            conn.execute(
                """
                INSERT INTO agent_messages(session_id, agent_type, role, content_short, token_count)
                VALUES (%s, 'user', 'user', %s, %s)
                """,
                (session_id, sanitized_prompt, len(sanitized_prompt.split())),
            )
            memory_id = insert_memory_entry(
                conn,
                project_uuid,
                session_id,
                sanitized_prompt,
                {"source": "prompt", "search_mode": "lexical_fallback", "redaction_applied": sanitized_prompt != request.prompt},
            )
            task = enqueue_task(
                TaskAssignment(
                    project_id=request.project_id,
                    session_id=session_id,
                    agent_type="planner",
                    task_type="prompt_intake",
                    task_description=sanitized_prompt,
                    allowed_tools=["memory_read", "task_router"],
                )
            )
            conn.execute(
                """
                UPDATE agent_sessions
                SET metadata = metadata || %s::jsonb
                WHERE id = %s
                """,
                (Json({"latest_task_id": task.task_id, "latest_memory_id": memory_id}), session_id),
            )
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"session persistence failed: {exc}") from exc

    return {
        "session_id": session_id,
        "stream_url": f"/api/v1/session/{session_id}/stream",
        "budget": {
            "level": budget_state.level,
            "spent_percentage": budget_state.spent_percentage,
            "total_cost_cents": budget_state.total_cost_cents,
            "budget_limit_cents": budget_state.budget_limit_cents,
        },
        "rate_limit": rate_limit,
        "session_llm_call_count": llm_call_count,
        "task_id": task.task_id,
        "memory_id": memory_id,
    }


@app.get("/api/v1/session/{session_id}/stream")
def stream_session(session_id: str, last_event_id: str | None = Header(default=None, alias="Last-Event-ID")) -> StreamingResponse:
    async def events():
        yielded_terminal = False
        last_status: str | None = None
        for replay_event in replay_sse_events(session_id, last_event_id):
            yield replay_event
        yield record_sse_event(session_id, "heartbeat", {"session_id": session_id, "status": "connected"})
        for _ in range(30):
            records = [record for record in list_recent_tasks() if record.session_id == session_id]
            latest = records[0] if records else None
            if not latest:
                yield record_sse_event(session_id, "agent_status", {"agent": "planner", "status": "idle", "task": None})
                await asyncio.sleep(1)
                continue

            if latest.status != last_status:
                yield record_sse_event(
                    session_id,
                    "agent_status",
                    {
                        "agent": latest.agent_type,
                        "status": latest.status,
                        "task": latest.task_description,
                        "task_id": latest.task_id,
                        "updated_at": latest.updated_at,
                    },
                )
                last_status = latest.status

            if latest.status == "completed":
                if latest.result:
                    yield record_sse_event(session_id, "token", {"agent": latest.agent_type, "content": latest.result, "task_id": latest.task_id})
                yield record_sse_event(session_id, "done", {"session_id": session_id, "task_id": latest.task_id, "total_tokens": 0, "total_cost_cents": 0})
                yielded_terminal = True
                break

            if latest.status == "failed":
                yield record_sse_event(
                    session_id,
                    "error",
                    {
                        "code": "task_failed",
                        "message": latest.error or "Task failed",
                        "task_id": latest.task_id,
                        "recoverable": False,
                    },
                )
                yield record_sse_event(session_id, "done", {"session_id": session_id, "task_id": latest.task_id, "total_tokens": 0, "total_cost_cents": 0})
                yielded_terminal = True
                break

            await asyncio.sleep(1)

        if not yielded_terminal:
            yield record_sse_event(session_id, "done", {"session_id": session_id, "task_id": None, "total_tokens": 0, "total_cost_cents": 0})

    return StreamingResponse(events(), media_type="text/event-stream")


@app.get("/api/v1/agents/status")
def agent_status() -> dict[str, object]:
    records = list_recent_tasks()
    profiles = {
        str(profile["agent_type"]): profile
        for profile in agent_profile_registry()["profiles"]
    }
    agents: list[dict[str, object]] = []
    for agent_type in ["planner", "coder", "tester", "devops"]:
        agent_records = [record for record in records if record.agent_type == agent_type]
        active = next((record for record in agent_records if record.status == "running"), None)
        queued = next((record for record in agent_records if record.status == "queued"), None)
        latest = agent_records[0] if agent_records else None
        selected = active or queued or latest
        if active:
            status = "active"
        elif queued:
            status = "queued"
        elif latest and latest.status == "failed":
            status = "error"
        else:
            status = "idle"
        agents.append(
            {
                "type": agent_type,
                "status": status,
                "profile_contract_version": "agent-profiles-v1",
                "role": profiles[agent_type]["role"],
                "primary_model": profiles[agent_type]["primary_model"],
                "fallbacks": profiles[agent_type]["fallbacks"],
                "max_execution_seconds": profiles[agent_type]["max_execution_seconds"],
                "max_output_tokens": profiles[agent_type]["max_output_tokens"],
                "max_retries": profiles[agent_type]["max_retries"],
                "allowed_tools": profiles[agent_type]["allowed_tools"],
                "blocked_actions": profiles[agent_type]["blocked_actions"],
                "human_review_required_actions": profiles[agent_type]["human_review_required_actions"],
                "graceful_degradation": profiles[agent_type]["graceful_degradation"],
                "current_task": selected.task_description if selected and selected.status in {"queued", "running"} else None,
                "current_session_id": selected.session_id if selected else None,
                "retries": 0,
                "started_at": selected.created_at if selected else None,
                "updated_at": selected.updated_at if selected else None,
                "latest_task_id": latest.task_id if latest else None,
                "latest_task_type": latest.task_type if latest else None,
                "latest_status": latest.status if latest else "none",
                "latest_result": latest.result if latest else None,
                "latest_error": latest.error if latest else None,
            }
        )
    return {"agents": agents, "queue_depth": queue_depth(), "queue_depth_by_priority": queue_depth_by_priority()}


@app.get("/api/v1/tasks/recent")
def recent_tasks(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    records = list_recent_tasks(limit=limit)
    return {
        "queue_depth": queue_depth(),
        "queue_depth_by_priority": queue_depth_by_priority(),
        "tasks": [
            {
                "task_id": record.task_id,
                "project_id": record.project_id,
                "session_id": record.session_id,
                "agent_type": record.agent_type,
                "task_type": record.task_type,
                "task_description": record.task_description,
                "status": record.status,
                "priority": record.priority,
                "created_at": record.created_at,
                "updated_at": record.updated_at,
                "result": record.result,
                "error": record.error,
                "retry_count": record.retry_count,
                "max_retries": record.max_retries,
                "allowed_tools": record.allowed_tools,
                "write_scope": record.write_scope,
                "blocked_actions": record.blocked_actions,
                "acceptance_criteria": record.acceptance_criteria,
                "human_review_required": record.human_review_required,
                "policy_version": record.policy_version,
                "result_envelope": record.result_envelope,
                "done_validation": record.done_validation,
            }
            for record in records
        ],
    }


@app.get("/api/v1/sessions/recent")
def recent_sessions(limit: int = Query(default=10, ge=1, le=50)) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT
              s.id,
              p.metadata->>'external_id' AS project_external_id,
              s.started_at,
              s.status,
              s.metadata->>'latest_task_id' AS latest_task_id,
              s.metadata->>'latest_worker_task_id' AS latest_worker_task_id,
              s.metadata->>'latest_worker_result' AS latest_worker_result,
              (
                SELECT m.content_short
                FROM agent_messages m
                WHERE m.session_id = s.id AND m.role = 'user'
                ORDER BY m.created_at ASC
                LIMIT 1
              ) AS prompt,
              (
                SELECT m.content_short
                FROM agent_messages m
                WHERE m.session_id = s.id AND m.role = 'assistant'
                ORDER BY m.created_at DESC
                LIMIT 1
              ) AS assistant_result
            FROM agent_sessions s
            JOIN projects p ON p.id = s.project_id
            ORDER BY s.started_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()
    return {
        "sessions": [
            {
                "session_id": str(row[0]),
                "project_id": row[1],
                "started_at": row[2].isoformat() if row[2] else None,
                "status": row[3],
                "latest_task_id": row[4] or row[5],
                "prompt": row[7],
                "assistant_result": row[8] or row[6],
            }
            for row in rows
        ]
    }


@app.get("/api/v1/sessions/{session_id}/history")
def session_history(
    session_id: str,
    audit_limit: int = Query(default=20, ge=1, le=100),
    task_limit: int = Query(default=20, ge=1, le=100),
) -> dict[str, object]:
    try:
        session_uuid = str(UUID(session_id))
    except (TypeError, ValueError) as exc:
        raise HTTPException(status_code=422, detail="session_id must be a valid UUID") from exc

    with psycopg.connect(database_url(), autocommit=True) as conn:
        session_row = conn.execute(
            """
            SELECT
              s.id,
              p.metadata->>'external_id' AS project_external_id,
              s.started_at,
              s.status,
              s.metadata,
              p.name
            FROM agent_sessions s
            JOIN projects p ON p.id = s.project_id
            WHERE s.id = %s
            LIMIT 1
            """,
            (session_uuid,),
        ).fetchone()
        if not session_row:
            raise HTTPException(status_code=404, detail="session not found")

        message_rows = conn.execute(
            """
            SELECT id, role, agent_type, content_short, token_count, created_at
            FROM agent_messages
            WHERE session_id = %s
            ORDER BY created_at ASC, id ASC
            """,
            (session_uuid,),
        ).fetchall()
        audit_rows = conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE session_id = %s
               OR details->>'session_id' = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (session_uuid, session_uuid, audit_limit),
        ).fetchall()

    task_records = [
        record
        for record in list_recent_tasks(limit=100)
        if str(record.session_id) == session_uuid
    ][:task_limit]
    progress = project_progress_payload()
    integrity = project_progress_integrity_payload()
    return {
        "contract_version": SESSION_HISTORY_CONTRACT_VERSION,
        "evidence_ref": SESSION_HISTORY_EVIDENCE_REF,
        "session": {
            "session_id": str(session_row[0]),
            "project_id": session_row[1] or session_row[5],
            "started_at": session_row[2].isoformat() if session_row[2] else None,
            "status": session_row[3],
            "metadata": session_row[4] or {},
        },
        "messages": [
            {
                "id": str(row[0]),
                "role": row[1],
                "agent_type": row[2],
                "content": row[3],
                "token_count": int(row[4] or 0),
                "created_at": row[5].isoformat() if row[5] else None,
            }
            for row in message_rows
        ],
        "tasks": [
            {
                "task_id": record.task_id,
                "project_id": record.project_id,
                "session_id": record.session_id,
                "agent_type": record.agent_type,
                "task_type": record.task_type,
                "task_description": record.task_description,
                "status": record.status,
                "created_at": record.created_at,
                "updated_at": record.updated_at,
                "result": record.result,
                "error": record.error,
                "retry_count": record.retry_count,
                "max_retries": record.max_retries,
                "allowed_tools": record.allowed_tools,
                "write_scope": record.write_scope,
                "blocked_actions": record.blocked_actions,
                "acceptance_criteria": record.acceptance_criteria,
                "human_review_required": record.human_review_required,
                "policy_version": record.policy_version,
                "result_envelope": record.result_envelope,
                "done_validation": record.done_validation,
            }
            for record in task_records
        ],
        "audit_events": [
            {
                "id": str(row[0]),
                "event_type": row[1],
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "details": row[4] or {},
                "request_id": (row[4] or {}).get("request_id"),
                "trace_id": (row[4] or {}).get("trace_id"),
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
            for row in audit_rows
        ],
        "project_progress": {
            "overall_percent": progress.get("overall_percent"),
            "last_verified": progress.get("last_verified"),
            "truth_policy": progress.get("truth_policy"),
            "binding_document": progress.get("binding_document"),
        },
        "project_progress_integrity": {
            "status": integrity.get("status"),
            "manifest_overall_percent": integrity.get("manifest_overall_percent"),
            "computed_overall_percent": integrity.get("computed_overall_percent"),
            "evidence_ref": integrity.get("evidence_ref"),
            "mismatches": integrity.get("mismatches", []),
        },
        "non_claims": [
            "Session history is read-only.",
            "Project progress is the current evidence manifest snapshot, not a per-message progress increase.",
            "Audit rows are limited by audit_limit and ordered newest first.",
        ],
    }


@app.get("/api/v1/audit/recent")
def recent_audit_events(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()
    return {
        "events": [
            {
                "id": str(row[0]),
                "event_type": row[1],
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "details": row[4] or {},
                "request_id": (row[4] or {}).get("request_id"),
                "trace_id": (row[4] or {}).get("trace_id"),
                "correlation_evidence_ref": (row[4] or {}).get(
                    "correlation_evidence_ref",
                    "request_id_audit_feed_visible",
                ),
                "audit_feed_evidence_ref": "request_id_audit_feed_visible",
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
            for row in rows
        ]
    }


@app.get("/api/v1/audit/mcp")
def recent_mcp_audit_events(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type = 'mcp_tool_executed'
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()
    return {
        "events": [
            {
                "id": str(row[0]),
                "event_type": row[1],
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "trace_id": (row[4] or {}).get("trace_id") or (str(row[3]) if row[3] else None),
                "details": row[4] or {},
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
            for row in rows
        ]
    }


@app.get("/api/v1/memory/consolidation/recent")
def recent_memory_consolidation_events(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type IN (
              'memory_consolidated',
              'memory_consolidation_skipped',
              'memory_consolidation_blocked'
            )
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()
        summary_rows = conn.execute(
            """
            SELECT event_type, severity, COALESCE(details->>'reason', 'none') AS reason, COUNT(*)
            FROM audit_log
            WHERE event_type IN (
              'memory_consolidated',
              'memory_consolidation_skipped',
              'memory_consolidation_blocked'
            )
            GROUP BY event_type, severity, reason
            ORDER BY event_type, severity, reason
            """
        ).fetchall()
    return {
        "events": [
            {
                "id": str(row[0]),
                "event_type": row[1],
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "details": row[4] or {},
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
            for row in rows
        ],
        "summary": [
            {
                "event_type": row[0],
                "severity": row[1],
                "reason": row[2],
                "count": int(row[3]),
            }
            for row in summary_rows
        ],
    }


@app.get("/api/v1/escalations/recent")
def recent_escalations(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type = 'task_escalated' OR severity = 'critical'
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()
    return {
        "events": [
            {
                "id": str(row[0]),
                "event_type": row[1],
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "details": row[4] or {},
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
            for row in rows
        ]
    }


@app.get("/api/v1/memory/search")
def memory_search(
    q: str = Query(..., min_length=1, max_length=1_000),
    project_id: str = Query(..., min_length=1),
    limit: int = Query(default=5, ge=1, le=20),
    threshold: float = Query(default=0.0, ge=0.0, le=1.0),
) -> dict[str, object]:
    results = [item.model_dump() for item in search_memory(project_id, q, limit)]
    return {
        "results": [item for item in results if item["relevance_score"] >= threshold],
        "search_mode": "lexical_fallback",
    }


@app.get("/api/v1/memory/purge/contract")
def memory_purge_contract() -> dict[str, object]:
    return memory_purge_contract_payload()


@app.delete("/api/v1/memory", status_code=202)
def purge_memory(
    project_id: str = Query(..., min_length=1, max_length=255),
    confirm: bool = Query(default=False),
    reason: str = Query(default="dsgvo_user_requested_purge", min_length=1, max_length=255),
    trace_id: str | None = Query(default=None, max_length=255),
) -> dict[str, object]:
    return execute_memory_purge(
        MemoryPurgeRequest(
            project_id=project_id,
            confirm=confirm,
            reason=reason,
            trace_id=trace_id,
        )
    )


@app.get("/api/v1/memory/purge/jobs/{job_id}")
def memory_purge_job_status(job_id: str) -> dict[str, object]:
    return get_memory_purge_job_status(job_id)


@app.delete("/api/v1/memory/{memory_id}", status_code=200)
def delete_memory_entry(
    memory_id: str,
    project_id: str = Query(..., min_length=1, max_length=255),
    confirm: bool = Query(default=False),
    reason: str = Query(default="user_requested_single_memory_delete", min_length=1, max_length=255),
    trace_id: str | None = Query(default=None, max_length=255),
) -> dict[str, object]:
    return execute_memory_entry_delete(
        MemoryEntryDeleteRequest(
            project_id=project_id,
            memory_id=memory_id,
            confirm=confirm,
            reason=reason,
            trace_id=trace_id,
        )
    )


@app.post("/internal/memory", status_code=201)
def create_memory(request: MemoryWriteRequest) -> dict[str, object]:
    try:
        memory_id = store_memory(request)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {
        "memory_id": memory_id,
        "search_mode": EMBEDDING_SEARCH_MODE,
        "embedding_model_version": current_embedding_model_version(),
        "evidence_ref": "embedding_model_version_persisted",
    }


@app.get("/api/v1/costs")
def costs() -> dict[str, object]:
    budget_state = get_budget_state()
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT agent_type, model_name, provider_name, COALESCE(SUM(cost_cents), 0) AS cost_cents
            FROM cost_tracking
            GROUP BY agent_type, model_name, provider_name
            ORDER BY cost_cents DESC
            """
        ).fetchall()
    return {
        "total_cost_cents": budget_state.total_cost_cents,
        "budget_limit_cents": budget_state.budget_limit_cents,
        "budget_spent_percentage": budget_state.spent_percentage,
        "level": budget_state.level,
        "allow_new_calls": budget_state.allow_new_calls,
        "breakdown": [
            {
                "agent_type": row[0],
                "model_name": row[1],
                "provider_name": row[2],
                "cost_cents": int(row[3]),
            }
            for row in rows
        ],
    }


@app.get("/api/v1/costs/export/contract")
def cost_export_contract() -> dict[str, object]:
    return cost_export_contract_payload()


@app.get("/api/v1/system/fallback/contract")
def system_fallback_contract() -> dict[str, object]:
    return system_fallback_contract_payload()


@app.get("/api/v1/agent-activity/contract")
def agent_activity_contract() -> dict[str, object]:
    return agent_activity_contract_payload()


def agent_activity_row_to_event(row: tuple[object, ...]) -> dict[str, object]:
    details = row[4] or {}
    if not isinstance(details, dict):
        details = {}
    per_role_results = details.get("per_role_results")
    if not isinstance(per_role_results, list):
        per_role_results = []
    partial_failure_reasons = details.get("partial_failure_reasons")
    if not isinstance(partial_failure_reasons, list):
        partial_failure_reasons = []
    aggregation_evidence_ref = details.get("aggregation_evidence_ref")
    if not aggregation_evidence_ref and per_role_results:
        aggregation_evidence_ref = (
            "agent_result_aggregation_partial_failure_detected"
            if bool(details.get("partial_failure", False))
            else "agent_result_aggregation_complete"
        )
    trace_id = str(row[7] or "none")
    return {
        "id": str(row[0]),
        "event_type": row[1],
        "user_id": row[2],
        "session_id": str(row[3]) if row[3] else None,
        "details": details,
        "created_at": row[5].isoformat() if row[5] else None,
        "severity": row[6],
        "trace_id": trace_id,
        "agent_type": row[8],
        "per_role_results": per_role_results,
        "role_summary_count": len(per_role_results),
        "partial_failure": bool(details.get("partial_failure", False)),
        "partial_failure_reasons": partial_failure_reasons,
        "aggregation_evidence_ref": aggregation_evidence_ref,
        "langfuse_trace_url": agent_activity_contract_payload()["langfuse"]["deep_link_template"].replace(
            "{trace_id}", trace_id
        ),
    }


@app.get("/api/v1/agent-activity/recent")
def recent_agent_activity(
    limit: int = Query(default=20, ge=1, le=100),
    severity: str | None = Query(default=None, pattern="^(info|warning|critical)$"),
    event_type: str | None = Query(default=None, min_length=1, max_length=100),
    agent_type: str | None = Query(default=None, min_length=1, max_length=50),
    trace_id: str | None = Query(default=None, min_length=1, max_length=255),
) -> dict[str, object]:
    conditions: list[str] = []
    params: list[object] = []
    if severity:
        conditions.append("severity = %s")
        params.append(severity)
    if event_type:
        conditions.append("event_type = %s")
        params.append(event_type)
    if agent_type:
        conditions.append(
            "(user_id = %s OR details->>'agent' = %s OR details->>'agent_type' = %s OR details->>'agent_role' = %s)"
        )
        params.extend([agent_type, agent_type, agent_type, agent_type])
    if trace_id:
        trace_pattern = f"%{trace_id}%"
        conditions.append(
            "(details->>'trace_id' ILIKE %s OR details->>'thread_id' ILIKE %s OR CAST(session_id AS TEXT) ILIKE %s)"
        )
        params.extend([trace_pattern, trace_pattern, trace_pattern])
    where_clause = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    params.append(limit)
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            f"""
            SELECT
              id,
              event_type,
              user_id,
              session_id,
              details,
              created_at,
              severity,
              COALESCE(details->>'trace_id', details->>'thread_id', CAST(session_id AS TEXT), 'none') AS trace_id,
              COALESCE(details->>'agent', details->>'agent_type', details->>'agent_role', user_id, 'unknown') AS agent_type
            FROM audit_log
            {where_clause}
            ORDER BY created_at DESC
            LIMIT %s
            """,
            tuple(params),
        ).fetchall()
    return {
        "contract_version": AGENT_ACTIVITY_CONTRACT_VERSION,
        "mode": "audit_log_backed_filtered_feed",
        "applied_filters": {
            "severity": severity,
            "event_type": event_type,
            "agent_type": agent_type,
            "trace_id": trace_id,
            "limit": limit,
        },
        "evidence_ref": "agent_activity_filtered_feed_visible",
        "events": [agent_activity_row_to_event(row) for row in rows],
    }


@app.get("/api/v1/costs/export")
def export_costs(
    request: Request,
    format: str = Query(default="csv", pattern="^csv$"),
    group_by: str = Query(default="agent", pattern="^(agent|model|session)$"),
    trace_id: str | None = Query(default=None, max_length=255),
    request_id: str | None = Query(default=None, max_length=255),
) -> Response:
    if format != "csv":
        raise HTTPException(status_code=400, detail={"error": "unsupported_format", "allowed": ["csv"]})
    csv_payload = build_cost_export_csv(group_by)
    row_count = max(0, len(csv_payload.splitlines()) - 1)
    resolved_trace_id = trace_id or f"cost-export-{uuid4()}"
    resolved_request_id = (
        request_id
        or getattr(request.state, "request_id", None)
        or request.headers.get("x-request-id")
        or f"req-{uuid4()}"
    )
    persist_cost_export_audit(group_by, row_count, resolved_trace_id, resolved_request_id)
    filename = f"superbrain-costs-{group_by}.csv"
    return Response(
        csv_payload,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-Contract-Version": COST_EXPORT_CONTRACT_VERSION,
            "X-Evidence-Ref": "cost_export_csv_generated",
            "X-Trace-Id": resolved_trace_id,
            "X-Request-Id": resolved_request_id,
        },
    )


@app.get("/api/v1/budget")
def budget() -> dict[str, object]:
    state = get_budget_state()
    return {
        "total_cost_cents": state.total_cost_cents,
        "budget_limit_cents": state.budget_limit_cents,
        "budget_spent_percentage": state.spent_percentage,
        "level": state.level,
        "allow_new_calls": state.allow_new_calls,
    }


def rate_limit_contract_payload() -> dict[str, object]:
    return {
        "contract_version": RATE_LIMIT_CONTRACT_VERSION,
        "mode": "redis_fixed_window_project_prompt_guard",
        "protected_endpoints": ["POST /api/v1/prompt"],
        "status_endpoint": "GET /api/v1/rate-limit/status?project_id={id}",
        "limit": prompt_rate_limit_capacity(),
        "window_seconds": prompt_rate_limit_window_seconds(),
        "failure_status": 429,
        "failure_detail": "prompt rate limit exceeded",
        "redis_key_pattern": "rate_limit:prompt:{project_id}:{window}",
        "policy_checks": [
            "Rate limit is checked before any session LLM-call registration.",
            "Each project receives an independent fixed Redis window.",
            "Overflow fails closed with HTTP 429 and no prompt execution claim.",
            "Status endpoint reads the guard state without incrementing usage.",
        ],
        "evidence_refs": {
            "contract_visible": "rate_limit_contract_visible",
            "status_visible": "rate_limit_status_visible",
            "overflow_blocked": "rate_limit_429_enforced",
        },
    }


@app.get("/api/v1/rate-limit/contract")
def rate_limit_contract() -> dict[str, object]:
    return rate_limit_contract_payload()


@app.get("/api/v1/rate-limit/status")
def rate_limit_status(project_id: str = Query(..., min_length=1, max_length=255)) -> dict[str, object]:
    status = get_prompt_rate_limit_status(project_id)
    return {
        **status,
        "contract_version": RATE_LIMIT_CONTRACT_VERSION,
        "status": "limited" if int(status["remaining"]) <= 0 else "available",
        "evidence_ref": "rate_limit_status_visible",
    }


def session_limit_contract_payload() -> dict[str, object]:
    return {
        "contract_version": SESSION_LIMIT_CONTRACT_VERSION,
        "mode": "redis_session_llm_call_guard",
        "protected_endpoints": ["POST /api/v1/prompt"],
        "status_endpoint": "GET /api/v1/session-limits/status?session_id={id}",
        "limit": session_llm_call_limit(),
        "ttl_seconds": 60 * 60 * 24,
        "failure_status": 429,
        "failure_detail": "session LLM call limit exceeded",
        "redis_key_pattern": "session:{session_id}:llm_calls",
        "policy_checks": [
            "Session call count is checked before prompt execution is accepted.",
            "Each session receives an independent 24-hour Redis counter.",
            "Overflow fails closed with HTTP 429 and no done claim.",
            "Status endpoint reads the guard state without incrementing usage.",
        ],
        "evidence_refs": {
            "contract_visible": "session_limit_contract_visible",
            "status_visible": "session_limit_status_visible",
            "overflow_blocked": "session_limit_429_enforced",
        },
    }


@app.get("/api/v1/session-limits/contract")
def session_limit_contract() -> dict[str, object]:
    return session_limit_contract_payload()


@app.get("/api/v1/session-limits/status")
def session_limit_status(session_id: str = Query(..., min_length=1, max_length=255)) -> dict[str, object]:
    status = get_session_llm_call_status(session_id)
    return {
        **status,
        "contract_version": SESSION_LIMIT_CONTRACT_VERSION,
        "status": "limited" if int(status["remaining"]) <= 0 else "available",
        "evidence_ref": "session_limit_status_visible",
    }


def prompt_contract_payload() -> dict[str, object]:
    return {
        "contract_version": PROMPT_INPUT_CONTRACT_VERSION,
        "mode": "pydantic_prompt_input_guard",
        "protected_endpoints": ["POST /api/v1/prompt"],
        "max_prompt_chars": 10_000,
        "min_prompt_chars": 1,
        "failure_status": 422,
        "failure_detail": "prompt must be between 1 and 10000 characters",
        "request_schema": {
            "project_id": "string min_length=1",
            "prompt": "string min_length=1 max_length=10000",
            "session_id": "string optional",
            "stream": "boolean default=true",
        },
        "policy_checks": [
            "Prompt body is validated before persistence, task enqueue, memory write, or LLM-call guard mutation.",
            "Overlong prompts fail closed through FastAPI/Pydantic validation.",
            "Frontend textarea exposes maxLength=10000 and a visible character counter.",
            "No prompt is accepted when prompt text is empty.",
        ],
        "evidence_refs": {
            "contract_visible": "prompt_input_contract_visible",
            "frontend_counter_visible": "prompt_input_counter_visible",
            "overflow_blocked": "prompt_input_422_enforced",
        },
    }


@app.get("/api/v1/prompt/contract")
def prompt_contract() -> dict[str, object]:
    return prompt_contract_payload()


def error_response_contract_payload() -> dict[str, object]:
    return {
        "contract_version": ERROR_RESPONSE_CONTRACT_VERSION,
        "mode": "structured_http_error_contract",
        "source": "FastAPI HTTPException and Pydantic validation",
        "enforced_by": [
            "http_exception_envelope_handler",
            "validation_exception_envelope_handler",
        ],
        "envelope_schema": {
            "contract_version": "error-response-contract-v1",
            "status_code": "integer",
            "error": "stable machine-readable string",
            "message": "human-readable string",
            "detail": "original FastAPI detail payload",
            "recoverable": "boolean",
            "evidence_ref": "error_response_*",
            "path": "request path",
        },
        "covered_statuses": [400, 401, 402, 403, 404, 422, 429, 503],
        "sample_errors": [
            {"status": 400, "error": "confirmation_required", "source": "memory purge confirmation"},
            {"status": 422, "error": "string_too_long", "source": "prompt max_length validation"},
            {"status": 429, "error": "prompt rate limit exceeded", "source": "rate limit guard"},
            {"status": 429, "error": "session LLM call limit exceeded", "source": "session limit guard"},
            {"status": 503, "error": "session persistence failed", "source": "persistence failure path"},
        ],
        "policy_checks": [
            "Error responses expose a stable HTTP status.",
            "Validation errors fail before persistence/task/memory mutation.",
            "Rate/session overflow returns 429 and no done claim.",
            "UI surfaces error text instead of marking completion.",
            "Every handled HTTP error response includes contract_version and status_code.",
        ],
        "evidence_refs": {
            "contract_visible": "error_response_contract_visible",
            "validation_error_blocked": "error_response_422_visible",
            "rate_limit_error_blocked": "error_response_429_visible",
            "ui_error_state": "error_response_ui_state_visible",
            "envelope_enforced": "error_response_envelope_enforced",
        },
    }


@app.get("/api/v1/errors/contract")
def error_response_contract() -> dict[str, object]:
    return error_response_contract_payload()


def security_headers_contract_payload() -> dict[str, object]:
    return {
        "contract_version": SECURITY_HEADERS_CONTRACT_VERSION,
        "mode": "api_response_security_headers",
        "enforced_by": "security_headers_middleware",
        "applies_to": "all Agent API HTTP responses including error envelopes",
        "headers": SECURITY_HEADERS,
        "cors_policy": {
            "mode": "same_origin_by_default",
            "reason": "Frontend reaches Agent API through the same Nginx origin in Phase 1.",
            "public_cross_origin_enabled": False,
        },
        "policy_checks": [
            "Every response includes X-Content-Type-Options=nosniff.",
            "Every response includes X-Frame-Options=DENY.",
            "Every response includes Referrer-Policy=no-referrer.",
            "Every response includes a restrictive Permissions-Policy.",
            "Every response includes a default self Content-Security-Policy.",
        ],
        "evidence_refs": {
            "contract_visible": "security_headers_contract_visible",
            "headers_enforced": "security_headers_enforced",
            "same_origin_cors_policy": "security_headers_same_origin_policy",
            "ui_visible": "security_headers_ui_visible",
        },
    }


@app.get("/api/v1/security/headers/contract")
def security_headers_contract() -> dict[str, object]:
    return security_headers_contract_payload()


def trace_id_contract_payload() -> dict[str, object]:
    return {
        "contract_version": TRACE_ID_CONTRACT_VERSION,
        "mode": "response_trace_id_propagation",
        "enforced_by": "trace_id_middleware",
        "request_header": "x-trace-id",
        "request_query_param": "trace_id",
        "response_header": "x-trace-id",
        "contract_header": "x-superbrain-trace-contract",
        "generated_prefix": "trace-",
        "applies_to": "all Agent API HTTP responses including errors, health, SSE bootstrap responses, and contracts",
        "policy_checks": [
            "If x-trace-id is supplied, the same value is returned in the response header.",
            "If no trace id is supplied, the API generates one with prefix trace-.",
            "Every response includes X-Superbrain-Trace-Contract.",
            "Trace IDs remain visible without writing secrets into logs or UI.",
        ],
        "evidence_refs": {
            "contract_visible": "trace_id_contract_visible",
            "header_roundtrip": "trace_id_header_roundtrip",
            "generated_trace_visible": "trace_id_generated_visible",
            "ui_visible": "trace_id_ui_visible",
        },
    }


@app.get("/api/v1/trace/contract")
def trace_id_contract() -> dict[str, object]:
    return trace_id_contract_payload()


def cache_control_contract_payload() -> dict[str, object]:
    return {
        "contract_version": CACHE_CONTROL_CONTRACT_VERSION,
        "mode": "api_response_no_store_cache_control",
        "enforced_by": "cache_control_middleware",
        "applies_to": "all Agent API HTTP responses including project, cost, memory, auth, trace, and error payloads",
        "headers": CACHE_CONTROL_HEADERS,
        "policy_checks": [
            "Every Agent API response includes Cache-Control no-store.",
            "Every Agent API response includes Pragma no-cache.",
            "Every Agent API response includes Expires 0.",
            "Sensitive project, memory, cost, auth, trace, and error payloads are not intentionally browser-cacheable.",
        ],
        "evidence_refs": {
            "contract_visible": "cache_control_contract_visible",
            "headers_enforced": "cache_control_headers_enforced",
            "sensitive_payload_no_store": "cache_control_sensitive_payload_no_store",
            "ui_visible": "cache_control_ui_visible",
        },
    }


@app.get("/api/v1/cache/contract")
def cache_control_contract() -> dict[str, object]:
    return cache_control_contract_payload()


def request_id_contract_payload() -> dict[str, object]:
    return {
        "contract_version": REQUEST_ID_CONTRACT_VERSION,
        "mode": "request_response_audit_correlation",
        "enforced_by": "request_id_middleware",
        "request_header": "x-request-id",
        "request_query_param": "request_id",
        "response_header": "x-request-id",
        "contract_header": "x-superbrain-request-contract",
        "generated_prefix": "req-",
        "error_envelope_fields": ["request_id", "trace_id", "path"],
        "audit_correlation_fields": ["request_id", "trace_id"],
        "applies_to": "all Agent API HTTP responses and structured error envelopes",
        "policy_checks": [
            "If x-request-id is supplied, the same value is returned in the response header.",
            "If no request id is supplied, the API generates one with prefix req-.",
            "Structured error envelopes include request_id and trace_id for support/audit correlation.",
            "Audited cost-export actions persist request_id and trace_id in audit_log.details.",
            "Every response includes X-Superbrain-Request-Contract.",
        ],
        "evidence_refs": {
            "contract_visible": "request_id_contract_visible",
            "header_roundtrip": "request_id_header_roundtrip",
            "error_envelope_correlation": "request_id_error_envelope_correlation",
            "audit_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
            "ui_visible": "request_id_ui_visible",
        },
    }


@app.get("/api/v1/request/contract")
def request_id_contract() -> dict[str, object]:
    return request_id_contract_payload()


def layer_interface_contract_payload() -> dict[str, object]:
    interfaces = [
        {
            "id": "L1-L2",
            "source_layer": "Frontend / Next.js",
            "target_layer": "Agent API",
            "transport": "HTTP JSON",
            "method": "POST",
            "path": "/api/v1/prompt",
            "request_schema": ["project_id:string", "prompt:string 1..10000", "session_id?:uuid", "stream:boolean"],
            "response_schema": ["session_id:uuid", "stream_url:string", "task_id?:uuid", "memory_id?:uuid", "budget.level:string"],
            "evidence_ref": "prompt_input_contract_visible",
            "status": "verified",
        },
        {
            "id": "L2-L2SSE",
            "source_layer": "Frontend / Next.js",
            "target_layer": "Agent API SSE",
            "transport": "HTTP SSE",
            "method": "POST",
            "path": "/api/v1/orchestrator/dry-run/stream",
            "request_schema": ["project_id:string", "prompt:string", "session_id?:uuid"],
            "response_schema": ["event:heartbeat", "event:agent_status", "event:error", "event:done"],
            "evidence_ref": "phase2_sse_event_contract_proof",
            "status": "verified",
        },
        {
            "id": "L2-L3",
            "source_layer": "Agent API / Orchestrator",
            "target_layer": "Agent Pool",
            "transport": "HTTP JSON + Redis queue",
            "method": "POST",
            "path": "/internal/tasks",
            "request_schema": ["project_id:string", "session_id:uuid", "agent_type:planner|coder|tester|devops", "task_type:string", "blocked_actions:string[]"],
            "response_schema": ["task_id:uuid", "status:queued|running|completed|escalated", "policy_version:task-policy-v1"],
            "evidence_ref": "task_session_uuid_fail_closed_proof",
            "status": "verified",
        },
        {
            "id": "L2-L4",
            "source_layer": "Orchestrator / LangGraph",
            "target_layer": "LLM Gateway",
            "transport": "OpenAI-compatible HTTP/SSE",
            "method": "POST",
            "path": "/llm/v1/chat/completions",
            "request_schema": ["model:string", "messages:array", "stream:boolean", "metadata.trace_id:string", "metadata.agent_type:string"],
            "response_schema": ["choices[].message.content", "model:string", "live_provider_calls:false", "trace_id:string"],
            "evidence_ref": "llm_gateway_streaming_dry_run",
            "status": "verified",
        },
        {
            "id": "L2-L5",
            "source_layer": "Orchestrator / LangGraph",
            "target_layer": "MCP Gateway",
            "transport": "HTTP JSON",
            "method": "POST",
            "path": "/mcp/api/v1/tools/execute",
            "request_schema": ["tool_request_id:string", "run_id:uuid", "session_id:uuid", "trace_id:string", "toolset:string", "capability:string"],
            "response_schema": ["status:success|blocked|timeout|degraded", "evidence_ref:string", "audit_persisted:boolean", "result_ref:string"],
            "evidence_ref": "mcp_tool_session_bound_audit",
            "status": "verified",
        },
        {
            "id": "L2-L6",
            "source_layer": "Agent API / Memory Worker",
            "target_layer": "PostgreSQL pgvector Memory",
            "transport": "HTTP JSON + PostgreSQL transaction",
            "method": "GET/DELETE",
            "path": "/api/v1/memory/search and /api/v1/memory",
            "request_schema": ["project_id:string", "query?:string", "confirm?:boolean", "reason?:string", "trace_id?:string"],
            "response_schema": ["results:array", "deleted_counts?:object", "evidence_ref:string", "job_status_url?:string"],
            "evidence_ref": "memory_purge_completed",
            "status": "verified",
        },
        {
            "id": "L7-OBS",
            "source_layer": "All runtime layers",
            "target_layer": "Observability",
            "transport": "HTTP JSON / Prometheus text",
            "method": "GET",
            "path": "/api/v1/audit/recent, /api/v1/audit/mcp, /api/v1/agent-activity/recent, /api/v1/metrics",
            "request_schema": ["limit?:int", "event_type?:string", "agent_type?:string", "trace_id?:string"],
            "response_schema": ["events:array", "trace_id:string", "request_id?:string", "metrics:text"],
            "evidence_ref": "agent_activity_filtered_feed_visible",
            "status": "verified",
        },
    ]
    return {
        "contract_version": LAYER_INTERFACE_CONTRACT_VERSION,
        "mode": "seven_layer_boundary_interface_register",
        "endpoint": "GET /api/v1/layer-interfaces/contract",
        "evidence_ref": LAYER_INTERFACE_EVIDENCE_REF,
        "coverage": "7 runtime layer boundaries",
        "interfaces": interfaces,
        "policy_checks": [
            "Every listed boundary declares method, path, request schema, response schema, status, and evidence_ref.",
            "External or write-capable interfaces remain dry-run or blocked until their gates are configured.",
            "Localhost evidence is valid only for deterministic local proof, not production deployment.",
            "No live provider calls, live MCP writes, or production deploys are claimed by this register.",
        ],
        "non_claims": [
            "No hosted staging success is claimed without STAGING_BASE_URL.",
            "No GitHub branch protection success is claimed without BRANCH_PROTECTION_TOKEN.",
            "No Hetzner live infrastructure state is claimed without HETZNER_API_TOKEN.",
        ],
    }


@app.get("/api/v1/layer-interfaces/contract")
def layer_interface_contract() -> dict[str, object]:
    return layer_interface_contract_payload()


def task_assignment_contract_payload() -> dict[str, object]:
    policy = task_policy_manifest()
    return {
        "contract_version": TASK_ASSIGNMENT_CONTRACT_VERSION,
        "mode": "layer_2_to_3_task_assignment_queue_contract",
        "audit_gap": "L-06",
        "endpoint": "GET /api/v1/tasks/assignment-contract",
        "evidence_ref": TASK_ASSIGNMENT_EVIDENCE_REF,
        "covered_boundary": "L2-L3 Agent API / Orchestrator to Agent Pool",
        "intake": {
            "method": "POST",
            "path": "/internal/tasks",
            "public_validation_path": "/api/v1/tasks/policy/validate",
            "status_path": "/internal/tasks/{task_id}",
            "public_recent_path": "/api/v1/tasks/recent",
            "policy_version": policy["policy_version"],
            "mode": policy["mode"],
        },
        "queue": {
            "backend": "redis",
            "queue_key": TASK_QUEUE_KEY,
            "priority_queues": TASK_PRIORITY_QUEUES,
            "priority_order": ["high", "mid", "low"],
            "priority_rules": {
                "high": "priority >= 8; manager roles planner/devops in orchestrator task plan",
                "mid": "priority 4..7; default work queue and legacy queue key",
                "low": "priority <= 3; background or best-effort work",
            },
            "status_key_pattern": f"{TASK_STATUS_PREFIX}{{task_id}}",
            "ttl_seconds": TASK_TTL_SECONDS,
            "consumer_service": "agent-worker",
            "visibility_endpoints": ["/api/v1/agents/status", "/api/v1/tasks/recent", "/api/v1/metrics"],
            "metrics": ["superbrain_task_queue_depth"],
        },
        "assignment_schema": {
            "required": ["project_id", "session_id", "agent_type", "task_type", "task_description"],
            "fields": {
                "project_id": "string non-empty",
                "session_id": "uuid string fail-closed before enqueue",
                "agent_type": "planner|coder|tester|devops",
                "task_type": "string 1..120",
                "task_description": "string 1..10000 redacted before persistence",
                "trace_id": "optional string",
                "priority": "integer 1..10 default 5",
                "max_retries": "integer 1..5 bounded by agent profile",
                "allowed_tools": "array constrained by agent profile",
                "write_scope": "array required for coder write-like tasks",
                "blocked_actions": "array must include required policy blocks",
                "acceptance_criteria": "must include result_envelope, done_validation, audit_log",
                "human_review_required": "boolean, required for deployment-like devops tasks",
                "policy_version": "task-policy-v1",
            },
        },
        "result_schema": {
            "task_id": "uuid",
            "status": "queued|running|completed|failed|escalated|abandoned_after_queue_drain",
            "retry_count": "integer",
            "result_envelope": "object or null",
            "done_validation": "implemented/tested/integrated/reported/logged booleans or null",
            "queue_depth": "integer from Redis llen",
            "queue_depth_by_priority": "object keyed by high/mid/low Redis queue depth",
        },
        "backpressure": {
            "queue_depth_source": "sum of Redis LLEN high/mid/low priority queues",
            "max_retries": "profile-gated 1..5",
            "priority_consumption": "agent-worker BLPOP consumes high before mid before low; no duplicate legacy enqueue",
            "bounded_wait": "orchestrator aggregation refreshes non-terminal tasks and marks drained queued records as partial_failure",
            "stale_queue_rescue": "agent-worker finalizes stale queued records after bounded rescue window",
            "fail_closed_before_enqueue": True,
            "policy_block_audit_event": "task_policy_blocked",
        },
        "evidence_refs": [
            TASK_ASSIGNMENT_EVIDENCE_REF,
            "task_assignment_completed",
            "worker_status_regression_harness",
            "worker_stale_queued_finalized",
            "task_session_uuid_fail_closed_proof",
            "agent_activity_per_role_results_visible",
        ],
        "policy_checks": [
            "TaskAssignment validates session_id as UUID before Redis enqueue.",
            "Task policy rejects unknown tools, profile tool drift, missing blocked actions, missing write_scope, and unsafe deployment routing.",
            "Queue depth is visible through public status, recent task feed, and Prometheus metrics.",
            "Priority routing is visible through high/mid/low queue keys and worker consumption order.",
            "Stale queued tasks are reconciled by the worker and do not produce false completed claims.",
        ],
        "non_claims": [
            "No live provider call is required for deterministic local task assignment proof.",
            "No live MCP write is enabled by this contract.",
            "No production deployment or main-branch mutation is enabled by this contract.",
        ],
    }


@app.get("/api/v1/tasks/assignment-contract")
def task_assignment_contract() -> dict[str, object]:
    return task_assignment_contract_payload()


def agent_llm_streaming_contract_payload() -> dict[str, object]:
    return {
        "contract_version": AGENT_LLM_STREAMING_CONTRACT_VERSION,
        "mode": "layer_3_to_4_agent_llm_gateway_streaming_contract",
        "audit_gap": "L-07",
        "endpoint": "GET /api/v1/agents/llm-streaming-contract",
        "evidence_ref": AGENT_LLM_STREAMING_EVIDENCE_REF,
        "covered_boundary": "L3-L4 Agent Pool to LLM Gateway",
        "agent_consumer": {
            "module": "services/agent-api/app/orchestrator.py",
            "function": "call_llm_gateway_for_task",
            "parser": "parse_llm_gateway_sse_line",
            "required_state_fields": [
                "llm_gateway_calls[].streaming_used",
                "llm_gateway_calls[].streaming_protocol",
                "llm_gateway_calls[].stream_chunk_count",
                "llm_gateway_calls[].stream_done_seen",
                "llm_gateway_calls[].live_provider_calls",
                "llm_gateway_calls[].audit_persisted",
            ],
        },
        "gateway_contract": {
            "stream_contract_endpoint": "GET /llm/api/v1/streaming/contract",
            "chat_completion_endpoint": "POST /llm/v1/chat/completions",
            "routing_resolve_endpoint": "POST /llm/api/v1/routing/resolve",
            "routing_policy_endpoint": "POST /llm/api/v1/routing/policy/evaluate",
            "protocol": "openai_compatible_sse",
            "content_type": "text/event-stream",
            "request_flag": {"stream": True},
            "frames": [
                "data: {chat.completion.chunk}",
                "data: {chat.completion.chunk finish_reason=stop}",
                "data: [DONE]",
            ],
        },
        "request_schema": {
            "model": "selected_model from routing resolver",
            "messages": "system and user messages with memory context",
            "stream": "true",
            "metadata.trace_id": "langgraph-{run_id}-{task_id}",
            "metadata.agent_type": "planner|coder|tester|devops",
            "metadata.session_id": "uuid",
            "metadata.run_id": "uuid",
        },
        "response_schema": {
            "chunk.object": "chat.completion.chunk",
            "choices[].delta.content": "string chunk content",
            "choices[].finish_reason": "null|stop",
            "terminal_frame": "data: [DONE]",
            "live_provider_calls": "false in deterministic local mode",
            "audit_persisted": "boolean from LLM audit sink",
        },
        "policy_checks": [
            "Agents request streaming through the LLM Gateway and never through direct provider URLs.",
            "Routing policy is evaluated before the streaming chat completion request.",
            "The Agent executor records stream_done_seen=true before claiming streaming completion.",
            "A policy-blocked route records streaming_used=false and does not enqueue follow-up live provider work.",
            "Deterministic local proof keeps live_provider_calls=false and cost_cents=0.",
        ],
        "evidence_refs": [
            AGENT_LLM_STREAMING_EVIDENCE_REF,
            "llm_gateway_streaming_dry_run",
            "llm_routing_policy_primary_allowed",
            "llm_routing_policy_sensitive_cache_blocked",
            "agent_result_aggregation_complete",
        ],
        "non_claims": [
            "No live provider stream is opened by this contract.",
            "No provider credential is required or exposed by this contract.",
            "No production deployment is claimed by this local streaming proof.",
        ],
    }


@app.get("/api/v1/agents/llm-streaming-contract")
def agent_llm_streaming_contract() -> dict[str, object]:
    return agent_llm_streaming_contract_payload()


def memory_embedding_schema_columns() -> dict[str, str]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT a.attname, format_type(a.atttypid, a.atttypmod)
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relname = 'memory_entries'
              AND a.attname IN ('content_embedding', 'embedding_model_version', 'metadata', 'status')
              AND a.attnum > 0
              AND NOT a.attisdropped
            ORDER BY a.attname
            """
        ).fetchall()
    return {str(row[0]): str(row[1]) for row in rows}


def memory_embedding_consistency_contract_payload() -> dict[str, object]:
    expected_schema = {
        "content_embedding": MEMORY_EMBEDDING_VECTOR_TYPE,
        "embedding_model_version": "character varying(100)",
        "metadata": "jsonb",
        "status": "character varying(50)",
    }
    schema_error = None
    try:
        actual_schema = memory_embedding_schema_columns()
    except Exception as exc:
        actual_schema = {}
        schema_error = str(exc)
    mismatches = [
        f"{column}_missing_or_mismatch"
        for column, expected_type in expected_schema.items()
        if actual_schema.get(column) != expected_type
    ]
    return {
        "contract_version": MEMORY_EMBEDDING_CONSISTENCY_CONTRACT_VERSION,
        "mode": "deterministic_local_embedding_version_contract",
        "audit_gap": "L-09",
        "endpoint": "GET /api/v1/memory/embedding-consistency/contract",
        "evidence_ref": MEMORY_EMBEDDING_CONSISTENCY_EVIDENCE_REF,
        "status": "verified" if not mismatches and not schema_error else "blocked",
        "schema": {
            "table": "memory_entries",
            "expected_columns": expected_schema,
            "actual_columns": actual_schema,
            "mismatches": mismatches,
            "error": schema_error,
        },
        "current_embedding": {
            "model_version": current_embedding_model_version(),
            "dimensions": current_embedding_dimensions(),
            "search_mode": EMBEDDING_SEARCH_MODE,
            "generation_mode": "disabled_until_live_embedding_gate",
            "live_embedding_provider_calls": False,
        },
        "write_policy": {
            "version_source": "MEMORY_EMBEDDING_MODEL_VERSION env or deterministic default",
            "persisted_column": "memory_entries.embedding_model_version",
            "metadata_mirror": "metadata.embedding_model_version",
            "default_model_version": current_embedding_model_version(),
        },
        "read_policy": {
            "vector_search_enabled": False,
            "safe_fallback": EMBEDDING_SEARCH_MODE,
            "must_not_mix_vector_versions": True,
            "filter_field_when_vector_search_enabled": "embedding_model_version",
        },
        "reembedding_policy": {
            "trigger": "Changing MEMORY_EMBEDDING_MODEL_VERSION or embedding dimensions requires a new re-embedding plan before vector search is enabled.",
            "required_steps": [
                "record old and new embedding_model_version",
                "queue bounded re-embedding job per project",
                "write new vectors only after provider and budget gates are open",
                "mark stale rows deprecated or keep them lexical_fallback-only until re-embedded",
                "publish audit evidence before raising memory-layer progress",
            ],
            "stale_row_policy": "Rows with non-current embedding_model_version are excluded from future vector search.",
            "rollback": "Revert MEMORY_EMBEDDING_MODEL_VERSION and keep lexical_fallback search active.",
        },
        "evidence_refs": [
            MEMORY_EMBEDDING_CONSISTENCY_EVIDENCE_REF,
            "embedding_model_version_persisted",
            "embedding_vector_dimension_guard",
            "reembedding_strategy_fail_closed",
        ],
        "non_claims": [
            "No live embedding provider call is made by this contract.",
            "No vector search production claim is made while generation_mode is disabled_until_live_embedding_gate.",
            "No production deployment is claimed.",
        ],
    }


@app.get("/api/v1/memory/embedding-consistency/contract")
def memory_embedding_consistency_contract() -> dict[str, object]:
    return memory_embedding_consistency_contract_payload()


@app.get("/api/v1/infra/budget")
def infra_budget() -> dict[str, object]:
    state = get_infra_budget_state()
    return {
        "projected_cost_cents": state.projected_cost_cents,
        "budget_limit_cents": state.budget_limit_cents,
        "warning_limit_cents": state.warning_limit_cents,
        "budget_spent_percentage": state.spent_percentage,
        "level": state.level,
        "allow_new_infra": state.allow_new_infra,
        "live_verified": state.live_verified,
        "source": state.source,
        "items": state.items,
        "non_claims": [
            "This endpoint is a configured Phase-1 projection unless HETZNER_API_TOKEN is configured.",
            "LLM/API provider spend is tracked separately and is not counted in the 20 EUR infrastructure limit.",
        ],
    }


@app.get("/api/v1/metrics")
def prometheus_metrics() -> Response:
    budget_state = get_budget_state()
    infra_budget_state = get_infra_budget_state()
    rate_limit_metrics_project = os.getenv("RATE_LIMIT_METRICS_PROJECT_ID", "browser-workspace")
    rate_limit_state = get_prompt_rate_limit_status(rate_limit_metrics_project)
    session_limit_metrics_session = os.getenv("SESSION_LIMIT_METRICS_SESSION_ID", "browser-session")
    session_limit_state = get_session_llm_call_status(session_limit_metrics_session)
    gates = external_gate_state()
    task_records = list_recent_tasks(limit=100)
    task_status_counts: dict[str, int] = {}
    for record in task_records:
        task_status_counts[record.status] = task_status_counts.get(record.status, 0) + 1

    lines = [
        "# HELP superbrain_project_progress_percent Evidence-based total project implementation progress percent.",
        "# TYPE superbrain_project_progress_percent gauge",
        metric_sample("superbrain_project_progress_percent", project_progress_payload()["overall_percent"]),
        "# HELP superbrain_budget_spent_percentage Current LLM budget spent percentage.",
        "# TYPE superbrain_budget_spent_percentage gauge",
        metric_sample("superbrain_budget_spent_percentage", budget_state.spent_percentage),
        "# HELP superbrain_budget_cost_cents_total Current accumulated LLM cost in cents.",
        "# TYPE superbrain_budget_cost_cents_total gauge",
        metric_sample("superbrain_budget_cost_cents_total", budget_state.total_cost_cents),
        "# HELP superbrain_budget_allow_new_calls Whether the budget guard allows new LLM calls.",
        "# TYPE superbrain_budget_allow_new_calls gauge",
        metric_sample("superbrain_budget_allow_new_calls", 1 if budget_state.allow_new_calls else 0, {"level": budget_state.level}),
        "# HELP superbrain_prompt_rate_limit_capacity Prompt rate limit capacity per project window.",
        "# TYPE superbrain_prompt_rate_limit_capacity gauge",
        metric_sample("superbrain_prompt_rate_limit_capacity", rate_limit_state["limit"], {"project_id": rate_limit_metrics_project}),
        "# HELP superbrain_prompt_rate_limit_remaining Prompt rate limit remaining calls for the metrics project.",
        "# TYPE superbrain_prompt_rate_limit_remaining gauge",
        metric_sample("superbrain_prompt_rate_limit_remaining", rate_limit_state["remaining"], {"project_id": rate_limit_metrics_project}),
        "# HELP superbrain_prompt_rate_limit_used Prompt rate limit used calls for the metrics project.",
        "# TYPE superbrain_prompt_rate_limit_used gauge",
        metric_sample("superbrain_prompt_rate_limit_used", rate_limit_state["used"], {"project_id": rate_limit_metrics_project}),
        "# HELP superbrain_session_llm_call_limit Session LLM call limit per 24h counter.",
        "# TYPE superbrain_session_llm_call_limit gauge",
        metric_sample("superbrain_session_llm_call_limit", session_limit_state["limit"], {"session_id": session_limit_metrics_session}),
        "# HELP superbrain_session_llm_call_remaining Session LLM calls remaining for the metrics session.",
        "# TYPE superbrain_session_llm_call_remaining gauge",
        metric_sample("superbrain_session_llm_call_remaining", session_limit_state["remaining"], {"session_id": session_limit_metrics_session}),
        "# HELP superbrain_session_llm_call_used Session LLM calls used for the metrics session.",
        "# TYPE superbrain_session_llm_call_used gauge",
        metric_sample("superbrain_session_llm_call_used", session_limit_state["used"], {"session_id": session_limit_metrics_session}),
        "# HELP superbrain_infra_budget_spent_percentage Current infrastructure budget spent percentage.",
        "# TYPE superbrain_infra_budget_spent_percentage gauge",
        metric_sample("superbrain_infra_budget_spent_percentage", infra_budget_state.spent_percentage, {"source": infra_budget_state.source}),
        "# HELP superbrain_infra_budget_projected_cost_cents Projected monthly infrastructure cost in cents.",
        "# TYPE superbrain_infra_budget_projected_cost_cents gauge",
        metric_sample("superbrain_infra_budget_projected_cost_cents", infra_budget_state.projected_cost_cents, {"level": infra_budget_state.level}),
        "# HELP superbrain_infra_budget_allow_new Whether the infrastructure budget allows new infrastructure.",
        "# TYPE superbrain_infra_budget_allow_new gauge",
        metric_sample("superbrain_infra_budget_allow_new", 1 if infra_budget_state.allow_new_infra else 0, {"level": infra_budget_state.level}),
        "# HELP superbrain_external_gate_configured Whether an external proof gate is configured.",
        "# TYPE superbrain_external_gate_configured gauge",
        "# HELP superbrain_task_queue_depth Current Redis agent task queue depth.",
        "# TYPE superbrain_task_queue_depth gauge",
        metric_sample("superbrain_task_queue_depth", queue_depth()),
        "# HELP superbrain_recent_tasks_total Recent Redis task count by status.",
        "# TYPE superbrain_recent_tasks_total gauge",
    ]
    for status, count in sorted(task_status_counts.items()):
        lines.append(metric_sample("superbrain_recent_tasks_total", count, {"status": status}))
    for gate in gates["gates"]:
        lines.append(
            metric_sample(
                "superbrain_external_gate_configured",
                1 if gate["configured"] else 0,
                {"gate": gate["id"], "status": gates["status"]},
            )
        )

    try:
        services = {
            "postgres": check_postgres().get("status") == "healthy",
            "redis": check_redis().get("status") == "healthy",
            "agent_worker": check_agent_worker().get("status") == "healthy",
            "memory_worker": check_memory_worker().get("status") == "healthy",
            "mcp_gateway": check_mcp().get("status") == "healthy",
            "llm_gateway": check_llm_gateway().get("status") == "healthy",
        }
    except Exception:
        services = {"postgres": False, "redis": False, "agent_worker": False, "memory_worker": False, "mcp_gateway": False, "llm_gateway": False}

    lines.extend(
        [
            "# HELP superbrain_service_health Service health gauge, 1 healthy and 0 unhealthy.",
            "# TYPE superbrain_service_health gauge",
        ]
    )
    for service, healthy in sorted(services.items()):
        lines.append(metric_sample("superbrain_service_health", 1 if healthy else 0, {"service": service}))

    with psycopg.connect(database_url(), autocommit=True) as conn:
        totals = conn.execute(
            """
            SELECT
              (SELECT COUNT(*) FROM projects) AS projects,
              (SELECT COUNT(*) FROM agent_sessions) AS sessions,
              (SELECT COUNT(*) FROM agent_messages) AS messages,
              (SELECT COUNT(*) FROM memory_entries) AS memory_entries,
              (
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema = 'public'
                  AND table_name IN (
                    'checkpoint_migrations', 'checkpoints',
                    'checkpoint_blobs', 'checkpoint_writes'
                  )
              ) AS checkpoint_tables
            """
        ).fetchone()
        audit_rows = conn.execute(
            """
            SELECT event_type, severity, COUNT(*)
            FROM audit_log
            GROUP BY event_type, severity
            ORDER BY event_type, severity
            """
        ).fetchall()
        mcp_audit_rows = conn.execute(
            """
            SELECT
              COALESCE(details->>'toolset', 'unknown') AS toolset,
              COALESCE(details->>'status', 'unknown') AS status,
              COALESCE(details->>'error_class', 'none') AS error_class,
              COUNT(*)
            FROM audit_log
            WHERE event_type = 'mcp_tool_executed'
            GROUP BY toolset, status, error_class
            ORDER BY toolset, status, error_class
            """
        ).fetchall()
        memory_consolidation_rows = conn.execute(
            """
            SELECT
              event_type,
              severity,
              COALESCE(details->>'reason', 'none') AS reason,
              COUNT(*)
            FROM audit_log
            WHERE event_type IN (
              'memory_consolidated',
              'memory_consolidation_skipped',
              'memory_consolidation_blocked'
            )
            GROUP BY event_type, severity, reason
            ORDER BY event_type, severity, reason
            """
        ).fetchall()

    lines.extend(
        [
            "# HELP superbrain_projects_total Total projects persisted in PostgreSQL.",
            "# TYPE superbrain_projects_total gauge",
            metric_sample("superbrain_projects_total", int(totals[0]) if totals else 0),
            "# HELP superbrain_agent_sessions_total Total agent sessions persisted in PostgreSQL.",
            "# TYPE superbrain_agent_sessions_total gauge",
            metric_sample("superbrain_agent_sessions_total", int(totals[1]) if totals else 0),
            "# HELP superbrain_agent_messages_total Total agent messages persisted in PostgreSQL.",
            "# TYPE superbrain_agent_messages_total gauge",
            metric_sample("superbrain_agent_messages_total", int(totals[2]) if totals else 0),
            "# HELP superbrain_memory_entries_total Total memory entries persisted in PostgreSQL.",
            "# TYPE superbrain_memory_entries_total gauge",
            metric_sample("superbrain_memory_entries_total", int(totals[3]) if totals else 0),
            "# HELP superbrain_checkpoint_tables_total LangGraph checkpoint tables available in PostgreSQL.",
            "# TYPE superbrain_checkpoint_tables_total gauge",
            metric_sample("superbrain_checkpoint_tables_total", int(totals[4]) if totals else 0),
            "# HELP superbrain_audit_events_total Audit events grouped by type and severity.",
            "# TYPE superbrain_audit_events_total counter",
        ]
    )
    for event_type, severity, count in audit_rows:
        lines.append(
            metric_sample(
                "superbrain_audit_events_total",
                int(count),
                {"event_type": event_type, "severity": severity},
            )
        )
    lines.extend(
        [
            "# HELP superbrain_mcp_tool_events_total MCP tool audit events grouped by toolset, status, and error class.",
            "# TYPE superbrain_mcp_tool_events_total counter",
        ]
    )
    for toolset, status, error_class, count in mcp_audit_rows:
        lines.append(
            metric_sample(
                "superbrain_mcp_tool_events_total",
                int(count),
                {"toolset": toolset, "status": status, "error_class": error_class},
            )
        )
    lines.extend(
        [
            "# HELP superbrain_memory_consolidation_events_total Memory consolidation audit events grouped by type, severity, and reason.",
            "# TYPE superbrain_memory_consolidation_events_total counter",
        ]
    )
    for event_type, severity, reason, count in memory_consolidation_rows:
        lines.append(
            metric_sample(
                "superbrain_memory_consolidation_events_total",
                int(count),
                {"event_type": event_type, "severity": severity, "reason": reason},
            )
        )

    return Response("\n".join(lines) + "\n", media_type="text/plain; version=0.0.4; charset=utf-8")


@app.get("/api/v1/orchestrator/manifest")
def orchestrator_manifest() -> dict[str, object]:
    return {
        "engine": "langgraph",
        "mode": "deterministic_dry_run",
        "live_provider_calls": False,
        "checkpointing": "postgres",
        "checkpoint_recovery_endpoint": "/api/v1/orchestrator/checkpoints/{thread_id}",
        "nodes": [
            "intent_parser",
            "budget_guard",
            "task_router",
            "agent_executor",
            "result_aggregator",
            "memory_updater",
            "error_handler",
        ],
        "max_global_retries": 5,
        "forbidden_actions": ["push_main", "prod_deploy", "secret_change", "live_provider_call"],
        "next_safe_step": "Add PostgreSQL checkpointer initialization and restart recovery proof.",
    }


@app.get("/api/v1/phase2/runtime/contract")
def phase2_runtime_contract() -> dict[str, object]:
    return phase2_runtime_contract_payload()


@app.get("/api/v1/phase2/runtime/runs")
def phase2_runtime_runs(limit: int = Query(default=10, ge=1, le=50)) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT details, created_at, severity, session_id
            FROM audit_log
            WHERE event_type = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (PHASE2_RUNTIME_GRAPH_EVIDENCE_REF, limit),
        ).fetchall()
    return {
        "contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
        "mode": "audit_log_backed_phase2_runtime_runs",
        "source_event_type": PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
        "evidence_ref": "phase2_runtime_run_status_visible",
        "runs": [phase2_runtime_run_from_audit_row(row) for row in rows],
        "non_claims": [
            "This endpoint reports deterministic local Phase 2 runtime audit records only.",
            "It does not claim live LLM provider execution.",
            "It does not claim live MCP writes or production deployment.",
        ],
    }


def prepare_orchestrator_session(
    project_id: str,
    session_id: str | None,
    *,
    source: str,
    metadata: dict[str, object] | None = None,
) -> str:
    prepared_session_id = session_id or str(uuid4())
    try:
        prepared_session_id = str(UUID(prepared_session_id))
    except (TypeError, ValueError):
        prepared_session_id = str(uuid4())
    with psycopg.connect(database_url(), autocommit=True) as conn:
        ensure_agent_session(
            conn,
            project_id,
            prepared_session_id,
            source=source,
            metadata=metadata,
        )
    return prepared_session_id


@app.post("/api/v1/phase2/runtime/start")
def phase2_runtime_start(request: OrchestratorDryRunRequest) -> dict[str, object]:
    runtime_prompt = f"phase2 runtime start: {request.prompt}"
    runtime_session_id = prepare_orchestrator_session(
        request.project_id,
        request.session_id,
        source="phase2-runtime-start",
        metadata={
            "contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
            "mode": "deterministic_local_runtime",
            "live_provider_calls": False,
            "live_mcp_writes": False,
            "production_deploy": False,
        },
    )
    state = run_dry_graph(project_id=request.project_id, prompt=runtime_prompt, session_id=runtime_session_id)
    persist_phase2_runtime_audit(state)
    return {
        "contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
        "status": "started",
        "mode": "deterministic_local_runtime",
        "engine": "langgraph",
        "live_provider_calls": False,
        "live_mcp_writes": False,
        "production_deploy": False,
        "checkpointing": "postgres",
        "thread_id": state["session_id"],
        "run_id": state["run_id"],
        "evidence_ref": PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
        "state": state,
        "contract": phase2_runtime_contract_payload(),
    }


@app.get("/api/v1/tasks/policy")
def task_policy() -> dict[str, object]:
    return task_policy_manifest()


@app.post("/api/v1/tasks/policy/validate")
def validate_task_assignment_policy(assignment: TaskAssignment) -> dict[str, object]:
    assignment = assignment.model_copy(update={"task_description": redact_text(assignment.task_description)})
    try:
        validate_task_policy(assignment)
    except TaskPolicyViolation as exc:
        persist_task_policy_block(assignment, exc)
        raise HTTPException(
            status_code=403,
            detail={
                "code": exc.code,
                "violations": exc.violations,
                "policy": task_policy_manifest(),
            },
        ) from exc
    return {"status": "accepted", "policy": task_policy_manifest(), "assignment": assignment.model_dump()}


@app.post("/api/v1/orchestrator/dry-run")
def orchestrator_dry_run(request: OrchestratorDryRunRequest) -> dict[str, object]:
    session_id = prepare_orchestrator_session(
        request.project_id,
        request.session_id,
        source="orchestrator-dry-run",
        metadata={"mode": "deterministic_dry_run", "live_provider_calls": False},
    )
    state = run_dry_graph(project_id=request.project_id, prompt=request.prompt, session_id=session_id)
    persist_langgraph_dry_run_audit(state)
    return {
        "engine": "langgraph",
        "mode": "deterministic_dry_run",
        "live_provider_calls": False,
        "checkpointing": "postgres",
        "thread_id": state["session_id"],
        "state": state,
    }


@app.post("/api/v1/orchestrator/dry-run/stream")
def orchestrator_dry_run_stream(
    request: OrchestratorDryRunRequest,
    last_event_id: str | None = Header(default=None, alias="Last-Event-ID"),
) -> StreamingResponse:
    thread_id = prepare_orchestrator_session(
        request.project_id,
        request.session_id,
        source="orchestrator-dry-run-stream",
        metadata={"mode": "deterministic_dry_run_stream", "live_provider_calls": False},
    )
    stream_key = orchestrator_sse_key(thread_id)

    def events():
        try:
            replayed = replay_sse_events(stream_key, last_event_id)
            if replayed:
                for replay_event in replayed:
                    yield replay_event
                return
            for payload in stream_dry_graph_events(
                project_id=request.project_id,
                prompt=request.prompt,
                session_id=thread_id,
            ):
                event = str(payload.get("event", "message"))
                data = {key: value for key, value in payload.items() if key != "event"}
                if event == "done" and isinstance(payload.get("state"), dict):
                    persist_langgraph_dry_run_audit(payload["state"])
                yield record_sse_event(stream_key, event, data)
        except Exception as exc:
            yield record_sse_event(
                stream_key,
                "error",
                {
                    "contract_version": PHASE2_SSE_EVENT_CONTRACT_VERSION,
                    "evidence_ref": PHASE2_SSE_EVENT_EVIDENCE_REF,
                    "required_event_types": list(PHASE2_SSE_REQUIRED_EVENTS),
                    "code": "orchestrator_stream_failed",
                    "message": str(exc),
                    "recoverable": False,
                },
            )
            yield record_sse_event(
                stream_key,
                "done",
                {
                    "contract_version": PHASE2_SSE_EVENT_CONTRACT_VERSION,
                    "evidence_ref": PHASE2_SSE_EVENT_EVIDENCE_REF,
                    "required_event_types": list(PHASE2_SSE_REQUIRED_EVENTS),
                    "status": "error",
                    "thread_id": thread_id,
                    "live_provider_calls": False,
                },
            )

    return StreamingResponse(events(), media_type="text/event-stream")


@app.post("/api/stream")
def autopilot_stream(request: AutopilotStreamRequest) -> StreamingResponse:
    thread_id = prepare_orchestrator_session(
        request.project_id,
        request.session_id,
        source="autopilot-stream",
        metadata={"mode": "deterministic_autopilot_stream", "live_provider_calls": False},
    )

    def event(name: str, payload: dict[str, object]) -> str:
        return f"event: {name}\ndata: {json.dumps(payload)}\n\n"

    def events():
        yield event(
            "status",
            {
                "status": "init",
                "message": "Agent gestartet",
                "thread_id": thread_id,
                "evidence_ref": "autopilot-mode-stream-proof",
            },
        )
        yield event(
            "status",
            {
                "status": "llm",
                "message": "LLM wird aufgerufen",
                "live_provider_calls": False,
                "note": "live_provider_calls=false",
            },
        )
        state = run_dry_graph(project_id=request.project_id, prompt=request.prompt, session_id=thread_id)
        persist_langgraph_dry_run_audit(state)
        yield event(
            "token",
            {
                "content": "LLM gateway deterministic dry-run response",
                "node_name": state.get("node_name"),
                "live_provider_calls": False,
                "evidence_ref": "autopilot-mode-stream-proof",
            },
        )
        yield event(
            "done",
            {
                "success": True,
                "thread_id": thread_id,
                "node_name": state.get("node_name"),
                "checkpointing": "postgres",
                "live_provider_calls": False,
                "evidence_ref": "autopilot-mode-stream-proof",
            },
        )

    return StreamingResponse(events(), media_type="text/event-stream")


@app.get("/api/v1/orchestrator/checkpoints/{thread_id}")
def orchestrator_checkpoint(thread_id: str) -> dict[str, object]:
    snapshot = recover_dry_graph_state(thread_id)
    if not snapshot["found"]:
        raise HTTPException(status_code=404, detail="checkpoint not found")
    return {
        "engine": "langgraph",
        "checkpointing": "postgres",
        "snapshot": snapshot,
    }


@app.get("/api/v1/models/capabilities")
def model_capabilities() -> dict[str, object]:
    return model_capability_matrix()


@app.get("/api/v1/agents/profiles")
def agent_profiles() -> dict[str, object]:
    return agent_profile_registry()


@app.get("/api/v1/rotation/policy")
def provider_rotation_policy() -> dict[str, object]:
    return rotation_policy()


@app.get("/api/v1/rotation/events")
def recent_rotation_events(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type = 'provider_rotated'
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()
    return {
        "contract_version": "provider-fallback-event-v1",
        "evidence_ref": "provider_fallback_structured_event",
        "live_provider_calls": False,
        "events": [
            {
                "id": str(row[0]),
                "session_id": str(row[1]) if row[1] else None,
                "details": row[2] or {},
                "created_at": row[3].isoformat() if row[3] else None,
                "severity": row[4],
            }
            for row in rows
        ]
    }


@app.post("/internal/rotation/events", status_code=201)
def create_rotation_event(request: RotationEventRequest) -> dict[str, object]:
    details = redact_json({
        "contract_version": "provider-fallback-event-v1",
        "event_kind": "provider_fallback",
        "from_provider": request.from_provider,
        "to_provider": request.to_provider,
        "provider_chain": [request.from_provider, request.to_provider],
        "from_model": request.from_model,
        "to_model": request.to_model,
        "reason": request.reason,
        "agent": request.agent,
        "trace_id": request.trace_id,
        "fallback_index": request.fallback_index,
        "routing_policy_decision": request.routing_policy_decision,
        "cost_metadata": {
            "input_tokens": request.input_tokens,
            "output_tokens": request.output_tokens,
            "estimated_cost_cents": request.estimated_cost_cents,
            "budget_level": request.budget_level,
            "currency": "cents",
            "live_billing": False,
        },
        "live_provider_calls": False,
        "evidence_ref": "provider_fallback_structured_event",
    })
    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute(
            """
            INSERT INTO audit_log(event_type, session_id, details, severity)
            VALUES ('provider_rotated', %s, %s::jsonb, 'info')
            RETURNING id, created_at
            """,
            (request.session_id, Json(details)),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=503, detail="rotation event insert failed")
    return {
        "event_id": str(row[0]),
        "event_type": "provider_rotated",
        "contract_version": "provider-fallback-event-v1",
        "evidence_ref": "provider_fallback_structured_event",
        "live_provider_calls": False,
        "created_at": row[1].isoformat() if row[1] else None,
        "details": details,
    }


@app.post("/internal/audit/mcp-tool-events", status_code=201)
def create_mcp_tool_audit_event(request: McpToolAuditRequest) -> dict[str, object]:
    severity = "info"
    if request.status in {"timeout", "degraded"}:
        severity = "warning"
    if request.status == "blocked":
        severity = "critical" if "violation" in request.error_class else "warning"

    try:
        session_id: str | None = str(UUID(str(request.session_id))) if request.session_id else None
    except (TypeError, ValueError):
        session_id = None
    details = redact_json(
        {
            **request.model_dump(),
            "session_bound": session_id is not None,
            "trace_id": request.trace_id or request.session_id or request.run_id,
            "evidence_ref": request.evidence_ref,
            "audit_evidence_ref": "mcp_tool_session_bound_audit",
        }
    )
    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute(
            """
            INSERT INTO audit_log(event_type, user_id, session_id, details, severity)
            VALUES ('mcp_tool_executed', %s, %s, %s::jsonb, %s)
            RETURNING id, created_at
            """,
            (request.agent_role, session_id, Json(details), severity),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=503, detail="mcp tool audit insert failed")
    return {
        "event_id": str(row[0]),
        "event_type": "mcp_tool_executed",
        "created_at": row[1].isoformat() if row[1] else None,
        "severity": severity,
    }


@app.post("/internal/audit/llm-events", status_code=201)
def create_llm_gateway_audit_event(request: LlmGatewayAuditRequest) -> dict[str, object]:
    severity = "info" if request.status == "dry_run" else "warning"
    if request.live_provider_calls:
        severity = "critical"
    details = redact_json(request.model_dump())
    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute(
            """
            INSERT INTO audit_log(event_type, user_id, details, severity)
            VALUES ('llm_gateway_request', %s, %s::jsonb, %s)
            RETURNING id, created_at
            """,
            (request.agent_type, Json(details), severity),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=503, detail="llm gateway audit insert failed")
    return {
        "event_id": str(row[0]),
        "event_type": "llm_gateway_request",
        "created_at": row[1].isoformat() if row[1] else None,
        "severity": severity,
    }


@app.post("/internal/tasks", status_code=201)
def create_task(assignment: TaskAssignment) -> dict[str, object]:
    assignment = assignment.model_copy(update={"task_description": redact_text(assignment.task_description)})
    try:
        task = enqueue_task(assignment)
    except TaskPolicyViolation as exc:
        persist_task_policy_block(assignment, exc)
        raise HTTPException(
            status_code=403,
            detail={
                "code": exc.code,
                "violations": exc.violations,
                "policy": task_policy_manifest(),
            },
        ) from exc
    return {"task": task.model_dump(), "queue_depth": queue_depth()}


@app.get("/internal/tasks/{task_id}")
def task_status(task_id: str) -> dict[str, object]:
    task = get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="task not found")
    return {"task": task.model_dump()}


@app.get("/internal/tasks")
def task_queue_status() -> dict[str, object]:
    return {"queue_depth": queue_depth(), "queue_depth_by_priority": queue_depth_by_priority()}
