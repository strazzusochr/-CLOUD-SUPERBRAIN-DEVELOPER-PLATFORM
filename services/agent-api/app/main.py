from __future__ import annotations

import asyncio
import base64
import csv
import hashlib
import hmac
import io
import json
import os
import re
import secrets
import shutil
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

import httpx
import psycopg
import redis
from fastapi import Cookie, FastAPI, Header, HTTPException, Query, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response, StreamingResponse
from psycopg.types.json import Json
from pydantic import AliasChoices, BaseModel, Field, field_validator

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
from app.db import check_agent_worker, check_llm_gateway, check_mcp, check_memory_worker, check_postgres, check_redis, database_url, llm_gateway_url, redis_url, run_migrations
from app.memory import (
    EMBEDDING_SEARCH_MODE,
    MemoryWriteRequest,
    current_embedding_dimensions,
    current_embedding_model_version,
    find_or_create_project_uuid,
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
    AUTONOMOUS_LOGICAL_ROLES,
    AUTONOMOUS_TEAM_MODE,
    TASK_PRIORITY_QUEUES,
    TASK_QUEUE_KEY,
    TASK_STATUS_PREFIX,
    TASK_TTL_SECONDS,
    AutonomousDispatchRecord,
    AutonomousRoleAssignment,
    TaskAssignment,
    TaskPolicyViolation,
    autonomous_dispatch_status,
    enqueue_task,
    get_autonomous_dispatch,
    get_task,
    list_recent_tasks,
    list_recent_autonomous_dispatches,
    queue_depth,
    queue_depth_by_priority,
    store_autonomous_dispatch,
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
CROSS_ORIGIN_RESPONSE_CONTRACT_VERSION = "cross-origin-response-guard-v1"
CROSS_ORIGIN_RESPONSE_EVIDENCE_REF = "cross_origin_response_guard_visible"
CSP_REPORT_CONTRACT_VERSION = "csp-report-contract-v1"
CSP_REPORT_EVIDENCE_REF = "csp_report_contract_visible"
CSP_REPORT_AUDIT_EVIDENCE_REF = "csp_report_audit_persisted"
CSP_REPORT_MAX_BODY_BYTES = 16_384
CSRF_ORIGIN_CONTRACT_VERSION = "csrf-origin-guard-v1"
CSRF_ORIGIN_EVIDENCE_REF = "csrf_origin_guard_visible"
CSRF_ORIGIN_AUDIT_EVIDENCE_REF = "csrf_origin_rejection_audited"
TRACE_ID_CONTRACT_VERSION = "trace-id-propagation-v1"
CACHE_CONTROL_CONTRACT_VERSION = "cache-control-no-store-v1"
REQUEST_ID_CONTRACT_VERSION = "request-id-correlation-v1"
LAYER_INTERFACE_CONTRACT_VERSION = "layer-interface-contracts-v1"
LAYER_INTERFACE_EVIDENCE_REF = "layer_interface_contracts_visible"
TASK_ASSIGNMENT_CONTRACT_VERSION = "task-assignment-queue-contract-v1"
TASK_ASSIGNMENT_EVIDENCE_REF = "task_assignment_queue_contract_visible"
AGENT_LLM_STREAMING_CONTRACT_VERSION = "agent-llm-streaming-contract-v1"
AGENT_LLM_STREAMING_EVIDENCE_REF = "agent_llm_streaming_contract_visible"
LLM_RESPONSES_ADAPTER_CONTRACT_VERSION = "llm-responses-adapter-contract-v1"
LLM_RESPONSES_ADAPTER_EVIDENCE_REF = "llm_responses_adapter_contract_visible"
MEMORY_EMBEDDING_CONSISTENCY_CONTRACT_VERSION = "memory-embedding-consistency-v1"
MEMORY_EMBEDDING_CONSISTENCY_EVIDENCE_REF = "memory_embedding_consistency_contract_visible"
MEMORY_CONSOLIDATION_CONTRACT_VERSION = "memory-consolidation-feed-v1"
MEMORY_CONSOLIDATION_EVIDENCE_REF = "memory_consolidation_contract_runtime_visible"
MEMORY_SEARCH_CONTRACT_VERSION = "memory-search-runtime-v1"
MEMORY_SEARCH_EVIDENCE_REF = "memory_search_contract_runtime_visible"
MEMORY_EMBEDDING_VECTOR_TYPE = "vector(1536)"
PROGRESS_INTEGRITY_CONTRACT_VERSION = "project-progress-integrity-v1"
PROGRESS_INTEGRITY_EVIDENCE_REF = "project_progress_integrity_runtime_proof"
PROGRESS_INTEGRITY_SURFACE_CONTRACT_VERSION = "project-progress-integrity-surface-v1"
PROGRESS_INTEGRITY_SURFACE_EVIDENCE_REF = "project_progress_integrity_surface_contract_visible"
PROGRESS_SURFACE_CONTRACT_VERSION = "project-progress-surface-v1"
PROGRESS_SURFACE_EVIDENCE_REF = "project_progress_surface_contract_visible"
PROGRESS_COMPLETION_CONTRACT_VERSION = "project-progress-100-percent-contract-v1"
PROGRESS_COMPLETION_EVIDENCE_REF = "project_progress_100_percent_gate_contract"
PROGRESS_COMPLETION_SURFACE_CONTRACT_VERSION = "project-progress-completion-surface-v1"
PROGRESS_COMPLETION_SURFACE_EVIDENCE_REF = "project_progress_completion_surface_contract_visible"
PROGRESS_LAYERS_SURFACE_CONTRACT_VERSION = "project-progress-layers-surface-v1"
PROGRESS_LAYERS_SURFACE_EVIDENCE_REF = "project_progress_layers_surface_contract_visible"
SESSION_HISTORY_CONTRACT_VERSION = "session-history-v1"
SESSION_HISTORY_EVIDENCE_REF = "session_history_openable_project_state"
PHASE2_RUNTIME_CONTRACT_VERSION = "phase2-runtime-v1"
PHASE2_RUNTIME_GRAPH_EVIDENCE_REF = "phase2_runtime_graph_started"
PHASE2_RUNTIME_RUNS_SURFACE_CONTRACT_VERSION = "phase2-runtime-runs-surface-v1"
PHASE2_RUNTIME_RUNS_SURFACE_EVIDENCE_REF = "phase2_runtime_runs_surface_contract_visible"
SESSION_STREAM_SURFACE_CONTRACT_VERSION = "session-stream-surface-v1"
SESSION_STREAM_SURFACE_EVIDENCE_REF = "session_stream_surface_contract_visible"
EXTERNAL_GATE_MIRROR_CONTRACT_VERSION = "external-gate-mirror-v1"
EXTERNAL_GATE_MIRROR_EVIDENCE_REF = "external_gate_mirror_proof"
EXTERNAL_GATES_CONTRACT_VERSION = "external-gates-state-v1"
EXTERNAL_GATES_EVIDENCE_REF = "external_gates_state_visible"
EXTERNAL_GATES_SURFACE_CONTRACT_VERSION = "external-gates-surface-v1"
EXTERNAL_GATE_MIRROR_SURFACE_CONTRACT_VERSION = "external-gates-mirror-surface-v1"
EXTERNAL_GATE_MIRROR_SURFACE_EVIDENCE_REF = "external_gate_mirror_surface_contract_visible"
BRANCH_PROTECTION_VERIFY_EVIDENCE_REF = "branch_protection_verify_contract"
CLOUD_RENDER_OFFLOAD_CONTRACT_VERSION = "cloud-render-offload-v1"
CLOUD_RENDER_OFFLOAD_EVIDENCE_REF = "cloud_render_offload_contract_visible"
PHASE6_3D_CAMERA_LIGHTING_CONTRACT_VERSION = "phase6-3d-camera-lighting-runtime-v1"
PHASE6_3D_CAMERA_LIGHTING_EVIDENCE_REF = "phase6_3d_camera_lighting_runtime_visible"
PHASE6_3D_GAMEPLAY_STATE_CONTRACT_VERSION = "phase6-3d-gameplay-state-runtime-v1"
PHASE6_3D_GAMEPLAY_STATE_EVIDENCE_REF = "phase6_3d_gameplay_state_runtime_visible"
PHASE6_3D_ASSET_POLICY_CONTRACT_VERSION = "phase6-3d-asset-policy-runtime-v1"
PHASE6_3D_ASSET_POLICY_EVIDENCE_REF = "phase6_3d_asset_policy_runtime_visible"
PHASE6_3D_SAVE_LOAD_CONTRACT_VERSION = "phase6-3d-save-load-runtime-v1"
PHASE6_3D_SAVE_LOAD_EVIDENCE_REF = "phase6_3d_save_load_runtime_visible"
PHASE6_3D_ACCESSIBILITY_CONTRACT_VERSION = "phase6-3d-accessibility-runtime-v1"
PHASE6_3D_ACCESSIBILITY_EVIDENCE_REF = "phase6_3d_accessibility_runtime_visible"
PHASE6_3D_NETCODE_CONTRACT_VERSION = "phase6-3d-netcode-loopback-runtime-v1"
PHASE6_3D_NETCODE_EVIDENCE_REF = "phase6_3d_netcode_loopback_runtime_visible"
PHASE6_LOCAL_SCOREBOARD_CONTRACT_VERSION = "phase6-local-scoreboard-performance-runtime-v1"
PHASE6_LOCAL_SCOREBOARD_EVIDENCE_REF = "phase6_local_scoreboard_performance_runtime_visible"
CLOUD_DEPLOYMENT_PREFLIGHT_CONTRACT_VERSION = "cloud-deployment-preflight-v1"
CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF = "cloud_deployment_preflight_visible"
GO_LIVE_READINESS_CONTRACT_VERSION = "go-live-readiness-v1"
GO_LIVE_READINESS_EVIDENCE_REF = "go_live_readiness_contract_visible"
GO_LIVE_READINESS_SURFACE_CONTRACT_VERSION = "go-live-readiness-surface-v1"
GO_LIVE_READINESS_SURFACE_EVIDENCE_REF = "go_live_readiness_surface_contract_visible"
ORCHESTRATOR_MANIFEST_CONTRACT_VERSION = "orchestrator-manifest-surface-v1"
ORCHESTRATOR_MANIFEST_EVIDENCE_REF = "orchestrator_manifest_contract_runtime_visible"
ORCHESTRATOR_CHECKPOINT_SURFACE_CONTRACT_VERSION = "orchestrator-checkpoint-surface-v1"
AUTONOMOUS_TEAM_CONTRACT_VERSION = "autonomous-coding-team-v1"
AUTONOMOUS_TEAM_EVIDENCE_REF = "autonomous_team_status_runtime_visible"
AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION = "autonomous-task-dispatch-v1"
AUTONOMOUS_TASK_DISPATCH_EVIDENCE_REF = "autonomous_team_dispatch_visible"
AUTONOMOUS_MASTER_PLAN_CONTRACT_VERSION = "autonomous-master-plan-v1"
AUTONOMOUS_MASTER_PLAN_EVIDENCE_REF = "autonomous_master_plan_runtime_visible"
AUTONOMOUS_AGENT_ROSTER_CONTRACT_VERSION = "autonomous-agent-roster-v1"
AUTONOMOUS_AGENT_ROSTER_EVIDENCE_REF = "autonomous_agent_roster_runtime_visible"
ORCHESTRATOR_CHECKPOINT_SURFACE_EVIDENCE_REF = "orchestrator_checkpoint_surface_contract_visible"
ORCHESTRATOR_DRY_RUN_SURFACE_CONTRACT_VERSION = "orchestrator-dry-run-surface-v1"
ORCHESTRATOR_DRY_RUN_SURFACE_EVIDENCE_REF = "orchestrator_dry_run_surface_contract_visible"
ORCHESTRATOR_DRY_RUN_STREAM_SURFACE_CONTRACT_VERSION = "orchestrator-dry-run-stream-surface-v1"
ORCHESTRATOR_DRY_RUN_STREAM_SURFACE_EVIDENCE_REF = "orchestrator_dry_run_stream_surface_contract_visible"
DEVOPS_WORKFLOW_DISPATCH_PLAN_SURFACE_CONTRACT_VERSION = "devops-workflow-dispatch-plan-surface-v1"
DEVOPS_WORKFLOW_DISPATCH_PLAN_SURFACE_EVIDENCE_REF = "devops_workflow_dispatch_plan_surface_contract_visible"
DEVOPS_WORKFLOW_DISPATCH_VALIDATE_SURFACE_CONTRACT_VERSION = "devops-workflow-dispatch-validate-surface-v1"
DEVOPS_WORKFLOW_DISPATCH_VALIDATE_SURFACE_EVIDENCE_REF = "devops_workflow_dispatch_validate_surface_contract_visible"
MEMORY_PURGE_JOB_STATUS_SURFACE_CONTRACT_VERSION = "memory-purge-job-status-surface-v1"
MEMORY_PURGE_JOB_STATUS_SURFACE_EVIDENCE_REF = "memory_purge_job_status_surface_contract_visible"
PHASE2_RUNTIME_START_SURFACE_CONTRACT_VERSION = "phase2-runtime-start-surface-v1"
PHASE2_RUNTIME_START_SURFACE_EVIDENCE_REF = "phase2_runtime_start_surface_contract_visible"
SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    "Content-Security-Policy": "default-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; report-uri /api/v1/security/csp/report",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Resource-Policy": "same-origin",
    "X-Permitted-Cross-Domain-Policies": "none",
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


_CSRF_SAFE_METHODS = {"GET", "HEAD", "OPTIONS", "TRACE"}


def _normalized_origin(value: str) -> str | None:
    text = value.strip()
    if not text or text.lower() == "null":
        return None
    parsed = urllib.parse.urlsplit(text)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc or parsed.username or parsed.password:
        return None
    if parsed.path not in {"", "/"} or parsed.query or parsed.fragment:
        return None
    return f"{parsed.scheme.lower()}://{parsed.netloc.lower()}"


def _request_public_origin(request: Request) -> str:
    forwarded_proto = request.headers.get("x-forwarded-proto", "").split(",", maxsplit=1)[0].strip()
    forwarded_host = request.headers.get("x-forwarded-host", "").split(",", maxsplit=1)[0].strip()
    scheme = forwarded_proto or request.url.scheme
    host = forwarded_host or request.headers.get("host", "") or request.url.netloc
    return f"{scheme.lower()}://{host.lower()}"


def persist_csrf_rejection_audit(request: Request, reason: str) -> bool:
    details = {
        "contract_version": CSRF_ORIGIN_CONTRACT_VERSION,
        "evidence_ref": CSRF_ORIGIN_AUDIT_EVIDENCE_REF,
        "reason": reason,
        "method": request.method,
        "path": request.url.path,
        "fetch_site": request.headers.get("sec-fetch-site", "missing")[:32],
        "origin_present": bool(request.headers.get("origin")),
        "request_id": getattr(request.state, "request_id", "unknown"),
        "trace_id": getattr(request.state, "trace_id", "unknown"),
        "secret_output": False,
    }
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('security_csrf_request_rejected', 'security', %s::jsonb, 'warning')
                """,
                (Json(redact_json(details)),),
            )
        return True
    except Exception:
        return False


@app.middleware("http")
async def csrf_origin_guard_middleware(request: Request, call_next):
    if request.method.upper() in _CSRF_SAFE_METHODS or not request.url.path.startswith("/api/"):
        return await call_next(request)

    fetch_site = request.headers.get("sec-fetch-site", "").strip().lower()
    supplied_origin = request.headers.get("origin")
    normalized_supplied = _normalized_origin(supplied_origin) if supplied_origin else None
    expected_origin = _normalized_origin(_request_public_origin(request))
    rejection_reason: str | None = None
    if fetch_site == "cross-site":
        rejection_reason = "fetch_metadata_cross_site"
    elif supplied_origin and normalized_supplied is None:
        rejection_reason = "invalid_or_null_origin"
    elif normalized_supplied and normalized_supplied != expected_origin:
        rejection_reason = "origin_mismatch"

    if rejection_reason:
        audit_persisted = persist_csrf_rejection_audit(request, rejection_reason)
        return JSONResponse(
            status_code=403,
            content={
                "contract_version": CSRF_ORIGIN_CONTRACT_VERSION,
                "status_code": 403,
                "error": "csrf_origin_rejected",
                "message": "Cross-site browser request rejected by the CSRF origin guard.",
                "reason": rejection_reason,
                "evidence_ref": CSRF_ORIGIN_EVIDENCE_REF,
                "audit_evidence_ref": CSRF_ORIGIN_AUDIT_EVIDENCE_REF,
                "audit_persisted": audit_persisted,
                "recoverable": True,
                "secret_output": False,
            },
            headers={"X-Superbrain-CSRF-Contract": CSRF_ORIGIN_CONTRACT_VERSION},
        )

    response = await call_next(request)
    response.headers.setdefault("X-Superbrain-CSRF-Contract", CSRF_ORIGIN_CONTRACT_VERSION)
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


def project_progress_manifest_path() -> Path:
    return Path(os.getenv("PROJECT_PROGRESS_MANIFEST_PATH", "/app/progress/project-progress.manifest.json"))


def project_state_path() -> Path:
    return Path(os.getenv("PROJECT_STATE_PATH", "/app/PROJECT_STATE.md"))


def autonomous_agent_roster_path() -> Path:
    return Path(
        os.getenv(
            "AUTONOMOUS_AGENT_ROSTER_PATH",
            "/app/docs/codex-integration/autonomous-agent-roster.json",
        )
    )


def project_state_markdown() -> str:
    return project_state_path().read_text(encoding="utf-8")


def markdown_section_lines(document: str, heading: str) -> list[str]:
    lines = document.splitlines()
    capture = False
    collected: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped == heading:
            capture = True
            continue
        if capture and stripped.startswith("## "):
            break
        if capture and stripped:
            collected.append(stripped)
    return collected


def markdown_bullets(lines: list[str]) -> list[str]:
    return [line[2:].strip() for line in lines if line.startswith("- ")]


def autonomous_external_provider() -> str:
    return os.getenv("AUTONOMOUS_TEAM_EXTERNAL_PROVIDER", "").strip()


def autonomous_external_status_url() -> str:
    return os.getenv("AUTONOMOUS_TEAM_EXTERNAL_STATUS_URL", "").strip()


def autonomous_external_agents_url() -> str:
    return os.getenv("AUTONOMOUS_TEAM_EXTERNAL_AGENTS_URL", "").strip()


def autonomous_external_timeout_seconds() -> int:
    return max(1, int(os.getenv("AUTONOMOUS_TEAM_EXTERNAL_TIMEOUT_SECONDS", "5")))


def load_external_json(url: str) -> dict[str, object]:
    request = urllib.request.Request(url, headers={"accept": "application/json"})
    with urllib.request.urlopen(request, timeout=autonomous_external_timeout_seconds()) as response:
        payload = json.loads(response.read().decode("utf-8", errors="replace"))
    if not isinstance(payload, dict):
        raise RuntimeError("external runtime payload must be an object")
    return payload


def external_autonomous_runtime_state() -> dict[str, object]:
    provider = autonomous_external_provider()
    status_url = autonomous_external_status_url()
    agents_url = autonomous_external_agents_url()
    if not provider or not status_url or not agents_url:
        return {
            "configured": False,
            "provider": provider or None,
            "status": "disabled",
            "status_url": status_url or None,
            "agents_url": agents_url or None,
            "ready": False,
            "agents": [],
            "logical_role_map": {},
            "error": None,
        }
    try:
        status_payload = load_external_json(status_url)
        agents_payload = load_external_json(agents_url)
        available_agents = [
            str(agent).strip()
            for agent in agents_payload.get("agents", [])
            if str(agent).strip()
        ]
        logical_role_map = {
            "supervisor": "planner",
            "planner": "planner",
            "explorer": "explorer",
            "coder": "coder",
            "tester": "qa_validation",
        }
        ready = bool(status_payload.get("ready")) and bool(available_agents)
        return {
            "configured": True,
            "provider": provider,
            "status": "ready" if ready else str(status_payload.get("status") or "degraded"),
            "status_url": status_url,
            "agents_url": agents_url,
            "ready": ready,
            "agents": available_agents,
            "logical_role_map": logical_role_map,
            "raw_status": status_payload,
            "error": None,
        }
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, RuntimeError, ValueError) as exc:
        return {
            "configured": True,
            "provider": provider,
            "status": "degraded",
            "status_url": status_url,
            "agents_url": agents_url,
            "ready": False,
            "agents": [],
            "logical_role_map": {
                "supervisor": "planner",
                "planner": "planner",
                "explorer": "explorer",
                "coder": "coder",
                "tester": "qa_validation",
            },
            "error": str(exc),
        }


def autonomous_agent_roster_document() -> dict[str, object]:
    path = autonomous_agent_roster_path()
    source_document = "docs/codex-integration/autonomous-agent-roster.json"
    if not path.exists():
        return {
            "status": "source_missing",
            "source_document": source_document,
            "source_path": str(path),
            "document": {},
            "error": f"missing roster source at {path}",
        }
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "status": "invalid",
            "source_document": source_document,
            "source_path": str(path),
            "document": {},
            "error": f"failed to parse roster source: {exc}",
        }
    if not isinstance(payload, dict):
        return {
            "status": "invalid",
            "source_document": source_document,
            "source_path": str(path),
            "document": {},
            "error": "roster source must be a JSON object",
        }
    return {
        "status": "loaded",
        "source_document": source_document,
        "source_path": str(path),
        "document": payload,
        "error": None,
    }


def autonomous_runtime_bindings() -> dict[str, object]:
    external_runtime = external_autonomous_runtime_state()
    return {
        "langgraph": {
            "status": "active",
            "transport": "fastapi_state_machine",
            "checkpointing": "postgres",
            "runtime_contract": "GET /api/v1/phase2/runtime/contract",
        },
        "crewai": {
            "status": "not_live_wired",
            "mode": "non_claim",
            "reason": "No CrewAI runtime endpoint is exposed by this stack.",
        },
        "prometheus": {
            "status": "metrics_surface_available",
            "transport": "prometheus_text",
            "endpoint": "GET /api/v1/metrics",
            "contract_endpoint": "GET /api/v1/metrics/contract",
        },
        "grafana": {
            "status": "not_live_wired",
            "mode": "non_claim",
            "reason": "Grafana dashboards are not exposed by this stack.",
        },
        "redis": {
            "status": "backing_service",
            "health_endpoint": "GET /api/v1/health",
        },
        "pgvector": {
            "status": "backing_service",
            "health_endpoint": "GET /api/v1/health",
        },
        "external_adapter": external_runtime,
    }


def project_phase_status_markers(
    progress: dict[str, object] | None = None,
    *,
    phase_id: str = "phase_4",
) -> set[str]:
    progress_payload = progress or project_progress_payload()
    phases = progress_payload.get("horizontal", {}).get("items", [])
    for item in phases:
        if str(item.get("id")) != phase_id:
            continue
        status = str(item.get("status", ""))
        return {marker.strip() for marker in status.split("-") if marker.strip()}
    return set()


def external_gate_verification_flags(progress: dict[str, object] | None = None) -> dict[str, bool]:
    markers = project_phase_status_markers(progress)
    return {
        "hosted_staging": "cloud_only_staging_verified" in markers or "hosted_staging_https_proof" in markers,
        "ghcr_images": "ghcr_image_digest_verified" in markers,
        "branch_protection": "branch_protection_verified" in markers,
        "hosted_backend_origins": "hosted_backend_origin_verified" in markers,
        "fly_cloud_stack": "fly_live_budget_verified" in markers,
        "canonical_secret_scan": "canonical_gitleaks_verified" in markers,
        "production_gate_claim_allowed": "production_gate_claim_allowed" in markers,
        "external_gate_audit_verified": "external_gate_audit_verified" in markers,
    }


def external_gate_state() -> dict[str, object]:
    progress = project_progress_payload()
    verified_flags = external_gate_verification_flags(progress)
    repo_gitleaks_path = Path(".tools") / "gitleaks" / "gitleaks.exe"
    gitleaks_available = shutil.which("gitleaks") is not None or repo_gitleaks_path.exists()
    gates = [
        {
            "id": "branch_protection_token",
            "preflight_gate_id": "branch_protection",
            "label": "GitHub branch protection apply token",
            "configured": bool(os.getenv("BRANCH_PROTECTION_TOKEN")) or verified_flags["branch_protection"],
            "verified": verified_flags["branch_protection"],
            "required_env": ["BRANCH_PROTECTION_TOKEN"],
            "evidence_ref": BRANCH_PROTECTION_VERIFY_EVIDENCE_REF,
            "required_for": "Applying protected-main rules through the manual branch-protection workflow.",
            "fallback": "Fail-closed dry-run script; no protected-main success is claimed without token.",
        },
        {
            "id": "staging_base_url",
            "preflight_gate_id": "hosted_staging",
            "label": "Hosted staging URL",
            "configured": bool(os.getenv("STAGING_BASE_URL")) or verified_flags["hosted_staging"],
            "verified": verified_flags["hosted_staging"],
            "required_env": ["STAGING_BASE_URL"],
            "evidence_ref": "hosted_staging_base_url_required",
            "required_for": "Repository-hosted staging proof workflow.",
            "fallback": "Local proof may run only with explicit -AllowLocalhost.",
        },
        {
            "id": "fly_api_token",
            "preflight_gate_id": "fly_cloud_stack",
            "label": "Fly.io API token",
            "configured": bool(os.getenv("FLY_API_TOKEN")) or verified_flags["fly_cloud_stack"],
            "verified": verified_flags["fly_cloud_stack"],
            "required_env": ["FLY_API_TOKEN"],
            "evidence_ref": "fly_live_budget_check",
            "required_for": "Live infrastructure invoice/cost verification.",
            "fallback": "Configured Phase-1 projection is used; live invoice proof is not claimed.",
        },
        {
            "id": "ghcr_image_digest_proof",
            "preflight_gate_id": "ghcr_images",
            "label": "GHCR image digest proof",
            "configured": bool(os.getenv("GITHUB_TOKEN") and os.getenv("GHCR_TOKEN")) or verified_flags["ghcr_images"],
            "verified": verified_flags["ghcr_images"],
            "required_env": ["GITHUB_TOKEN", "GHCR_TOKEN"],
            "evidence_ref": "ghcr_image_digest_proof",
            "required_for": "Published and pullable GHCR images for all application services.",
            "fallback": "Static workflow proof only; no image publication or pull success is claimed.",
        },
        {
            "id": "vercel_backend_origins",
            "preflight_gate_id": "hosted_backend_origins",
            "label": "Vercel hosted backend origins",
            "configured": verified_flags["hosted_backend_origins"] or all(
                bool(os.getenv(key))
                for key in ["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"]
            ),
            "verified": verified_flags["hosted_backend_origins"],
            "required_env": ["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"],
            "evidence_ref": "hosted_backend_origin_env_required",
            "required_for": "Hosted frontend uses HTTPS backend origins instead of localhost.",
            "fallback": "Local frontend proof only; no hosted Vercel origin success is claimed.",
        },
        {
            "id": "gitleaks_binary",
            "preflight_gate_id": "canonical_secret_scan",
            "label": "gitleaks binary",
            "configured": gitleaks_available or verified_flags["canonical_secret_scan"],
            "verified": verified_flags["canonical_secret_scan"],
            "required_env": [],
            "evidence_ref": "canonical_gitleaks_scan",
            "required_for": "Canonical upstream secret scanner execution.",
            "fallback": "Local fallback scanner blocks known secret patterns when gitleaks is unavailable.",
        },
    ]
    configured = sum(1 for gate in gates if gate["configured"])
    verified = sum(1 for gate in gates if gate["verified"])
    blocked_release_gates = [str(gate["preflight_gate_id"]) for gate in gates if not gate["verified"]]
    return {
        "contract_version": EXTERNAL_GATES_CONTRACT_VERSION,
        "status": "verified" if verified == len(gates) else "action_required",
        "endpoint": "GET /api/v1/external-gates",
        "evidence_ref": EXTERNAL_GATES_EVIDENCE_REF,
        "configured_count": configured,
        "verified_count": verified,
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


def external_gates_surface_contract_payload() -> dict[str, object]:
    state = external_gate_state()
    return {
        "contract_version": EXTERNAL_GATES_SURFACE_CONTRACT_VERSION,
        "mode": "external_gate_runtime_surface_contract",
        "endpoint": "GET /api/v1/external-gates/contract",
        "runtime_endpoint": "GET /api/v1/external-gates",
        "required_top_level_fields": [
            "status",
            "configured_count",
            "verified_count",
            "total_count",
            "local_execution_allowed",
            "aligned_with_deployment_preflight",
            "deployment_preflight_endpoint",
            "blocked_release_gates",
            "gates",
        ],
        "required_gate_fields": [
            "id",
            "preflight_gate_id",
            "label",
            "configured",
            "verified",
            "evidence_ref",
        ],
        "required_gate_ids": [str(gate["id"]) for gate in state["gates"]],
        "required_preflight_gate_ids": [str(gate["preflight_gate_id"]) for gate in state["gates"]],
        "supported_statuses": ["verified", "action_required"],
        "deployment_preflight_endpoint": str(state["deployment_preflight_endpoint"]),
        "evidence_ref": "external_gates_contract_runtime_visible",
        "non_claims": list(state["non_claims"]),
    }


def external_gate_mirror_state() -> dict[str, object]:
    gates = external_gate_state()
    verified_flags = external_gate_verification_flags(project_progress_payload())
    gate_items = list(gates["gates"])
    staging_configured = any(gate["id"] == "staging_base_url" and gate["configured"] for gate in gate_items)
    branch_token_configured = any(
        gate["id"] == "branch_protection_token" and gate["configured"] for gate in gate_items
    )
    return {
        "contract_version": EXTERNAL_GATE_MIRROR_CONTRACT_VERSION,
        "status": "verified" if gates["status"] == "verified" else "local_mirror_ready_hosted_blocked",
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
        "hosted_staging_claim_allowed": verified_flags["hosted_staging"],
        "branch_protection_claim_allowed": verified_flags["branch_protection"],
        "hosted_staging_env_configured": staging_configured,
        "branch_protection_env_configured": branch_token_configured,
        "branch_protection_evidence_ref": BRANCH_PROTECTION_VERIFY_EVIDENCE_REF,
        "cloud_deployment_preflight_evidence_ref": CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF,
        "production_deploy_claim_allowed": verified_flags["production_gate_claim_allowed"] and gates["status"] == "verified",
        "evidence_ref": EXTERNAL_GATE_MIRROR_EVIDENCE_REF,
        "non_claims": [
            "Local mirror proof is not a hosted staging success claim.",
            "STAGING_BASE_URL is required before repository-hosted proof can be claimed.",
            "BRANCH_PROTECTION_TOKEN is required before protected-main success can be claimed.",
            "Production deployment remains blocked.",
        ],
    }


def external_gate_mirror_surface_contract_payload() -> dict[str, object]:
    mirror = external_gate_mirror_state()
    return {
        "contract_version": EXTERNAL_GATE_MIRROR_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/external-gates/mirror",
        "runtime_contract_version": mirror["contract_version"],
        "guarded_endpoints": [
            "GET /api/v1/external-gates",
            "GET /api/v1/clouds/deployment-preflight/contract",
            "GET /api/v1/project/progress/completion",
        ],
        "evidence_ref": EXTERNAL_GATE_MIRROR_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "endpoint",
            "mirrored_workflow",
            "verifier",
            "branch_protection_workflow",
            "branch_protection_verifier",
            "local_mirror_command",
            "hosted_command",
            "external_gate_status",
            "configured_count",
            "total_count",
            "required_external_gates",
            "phase2_contracts_mirrored",
            "hosted_staging_claim_allowed",
            "branch_protection_claim_allowed",
            "hosted_staging_env_configured",
            "branch_protection_env_configured",
            "branch_protection_evidence_ref",
            "cloud_deployment_preflight_evidence_ref",
            "production_deploy_claim_allowed",
            "evidence_ref",
            "non_claims",
        ],
        "required_verified_flags": [
            "hosted_staging_claim_allowed",
            "branch_protection_claim_allowed",
            "production_deploy_claim_allowed",
        ],
        "expected_statuses": [
            "verified",
            "local_mirror_ready_hosted_blocked",
        ],
        "non_claims": list(mirror["non_claims"]),
    }


class PromptRequest(BaseModel):
    project_id: str = Field(..., min_length=1)
    prompt: str = Field(..., min_length=1, max_length=10_000)
    session_id: str | None = None
    stream: bool = True


class LiveAgentSteerRequest(BaseModel):
    agent_id: str = Field(
        ...,
        min_length=1,
        max_length=64,
        pattern="^[a-z0-9_-]+$",
        validation_alias=AliasChoices("agent_id", "agentId"),
    )
    message: str = Field(..., min_length=1, max_length=10_000)
    project_id: str = Field(
        default="codex-live-agent-app",
        min_length=1,
        max_length=255,
        validation_alias=AliasChoices("project_id", "projectId"),
    )
    model: str | None = Field(default=None, min_length=1, max_length=120)
    instructions: str | None = Field(default=None, max_length=4000)
    reasoning_effort: str = Field(default="medium", pattern="^(none|minimal|low|medium|high|xhigh)$")
    reset_history: bool = Field(default=False, validation_alias=AliasChoices("reset_history", "resetHistory"))
    metadata: dict[str, object] = Field(default_factory=dict)

    model_config = {"populate_by_name": True}


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


class AutonomousCodingDispatchRequest(BaseModel):
    project_id: str = Field(..., min_length=1, max_length=255)
    objective: str = Field(..., min_length=1, max_length=10_000)
    session_id: str | None = None
    trace_id: str | None = Field(default=None, max_length=255)
    write_scope: list[str] = Field(default_factory=list)
    acceptance_criteria: list[str] = Field(
        default_factory=lambda: [
            "result_envelope",
            "done_validation",
            "audit_log",
            "runtime_visibility",
        ]
    )
    constraints: list[str] = Field(default_factory=list)


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


class WorkspaceArtifactRequest(BaseModel):
    project_id: str = Field(default="goal-b-local", min_length=1, max_length=255)
    source_page: str = Field(..., min_length=1, max_length=80, pattern="^[a-z0-9_/-]+$")
    artifact_type: str = Field(..., min_length=1, max_length=80, pattern="^[a-z0-9_-]+$")
    title: str = Field(..., min_length=1, max_length=160)
    summary: str = Field(..., min_length=1, max_length=1000)
    session_id: str | None = Field(default=None, max_length=120)
    run_id: str | None = Field(default=None, max_length=120)
    status: str = Field(default="ready", pattern="^(ready|planned|dry_run|blocked)$")
    metadata: dict[str, object] = Field(default_factory=dict)


class ReadOnlyToolExecuteRequest(BaseModel):
    project_id: str = Field(default="goal-b-local", min_length=1, max_length=255)
    tool_id: str = Field(..., pattern="^(memory_read|task_router)$")
    query: str = Field(default="phase2 runtime", min_length=1, max_length=500)
    trace_id: str | None = Field(default=None, max_length=255)


AUTH_ACCESS_TOKEN_TTL_SECONDS = 15 * 60
AUTH_REFRESH_TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60
AUTH_BLACKLIST_PREFIX = "auth:refresh:blacklist:"
DSGVO_PURGE_CONTRACT_VERSION = "memory-dsgvo-purge-v1"
COST_EXPORT_CONTRACT_VERSION = "cost-monitor-export-v1"
SYSTEM_FALLBACK_CONTRACT_VERSION = "system-unavailable-fallback-v1"
AGENT_ACTIVITY_CONTRACT_VERSION = "agent-activity-trace-v1"
HEALTH_CONTRACT_VERSION = "health-surface-v1"
LIVE_AGENT_STEERING_CONTRACT_VERSION = "live-agent-steering-v1"
LIVE_AGENT_STEERING_EVIDENCE_REF = "live_agent_steering_contract_visible"
WORKSPACE_ARTIFACT_CONTRACT_VERSION = "goal-b-workspace-artifact-registry-v1"
WORKSPACE_ARTIFACT_EVIDENCE_REF = "goal_b_workspace_artifact_registry_visible"
READ_ONLY_TOOL_EXECUTE_CONTRACT_VERSION = "goal-b-readonly-tool-execute-v1"
READ_ONLY_TOOL_EXECUTE_EVIDENCE_REF = "goal_b_readonly_tool_execute_visible"
LIVE_AGENT_SESSION_PREFIX = "live-agent:responses:"
LIVE_AGENT_SESSION_TTL_SECONDS = TASK_TTL_SECONDS
LIVE_AGENT_LLM_TIMEOUT_SECONDS = 120
LIVE_AGENT_PROFILES: dict[str, dict[str, str]] = {
    "supervisor": {
        "display_name": "Supervisor",
        "execution_role": "planner",
        "instructions": "Coordinate the other agents, surface risks, and decide the next most useful action.",
    },
    "planner": {
        "display_name": "Planner",
        "execution_role": "planner",
        "instructions": "Break the work into concrete tasks, dependencies, and acceptance criteria.",
    },
    "explorer": {
        "display_name": "Explorer",
        "execution_role": "planner",
        "instructions": "Inspect the codebase and runtime surfaces, then report exact findings with minimal speculation.",
    },
    "coder": {
        "display_name": "Coder",
        "execution_role": "coder",
        "instructions": "Focus on implementation details, code changes, and precise technical tradeoffs.",
    },
    "tester": {
        "display_name": "Tester",
        "execution_role": "tester",
        "instructions": "Focus on verification, edge cases, regressions, and missing proof.",
    },
    "devops": {
        "display_name": "DevOps",
        "execution_role": "devops",
        "instructions": "Focus on deployment safety, runtime configuration, rollout risk, and observability.",
    },
    "debugger": {
        "display_name": "Debugger",
        "execution_role": "coder",
        "instructions": "Trace symptoms to likely root cause, then propose concrete fixes and validations.",
    },
    "researcher": {
        "display_name": "Researcher",
        "execution_role": "planner",
        "instructions": "Gather evidence from available context, compare options, and highlight unknowns.",
    },
    "reviewer": {
        "display_name": "Reviewer",
        "execution_role": "tester",
        "instructions": "Review changes for correctness, risk, and missing validation before signoff.",
    },
    "browser": {
        "display_name": "Browser Agent",
        "execution_role": "tester",
        "instructions": "Focus on user-visible behavior, browser flows, and runtime observations.",
    },
    "doc": {
        "display_name": "Doc Writer",
        "execution_role": "planner",
        "instructions": "Produce concise engineering documentation, operator notes, and handoff text.",
    },
    "security": {
        "display_name": "Security Agent",
        "execution_role": "tester",
        "instructions": "Focus on attack surface, secret handling, auth issues, and unsafe patterns.",
    },
}


def b64url_json(payload: dict[str, object]) -> str:
    raw = json.dumps(payload, separators=(",", ":"), default=str).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def b64url_bytes(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def live_agent_default_model() -> str:
    return os.getenv("LOCAL_LLM_MODEL", os.getenv("HF_DEFAULT_CHAT_MODEL", "deepseek-ai/DeepSeek-V4-Flash:fastest"))


def live_agent_session_key(agent_id: str) -> str:
    return LIVE_AGENT_SESSION_PREFIX + agent_id


def resolve_live_agent_profile(agent_id: str) -> dict[str, str]:
    normalized = agent_id.strip().lower()
    profile = LIVE_AGENT_PROFILES.get(normalized)
    if not profile:
        raise HTTPException(status_code=404, detail=f"unknown live agent: {normalized}")
    return {"agent_id": normalized, **profile}


def get_live_agent_session(agent_id: str) -> dict[str, object] | None:
    payload = redis_client().get(live_agent_session_key(agent_id))
    if not payload:
        return None
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def set_live_agent_session(
    agent_id: str,
    *,
    response_id: str,
    project_id: str,
    model: str,
    execution_role: str,
    extra: dict[str, object] | None = None,
) -> dict[str, object]:
    payload = {
        "agent_id": agent_id,
        "previous_response_id": response_id,
        "project_id": project_id,
        "model": model,
        "execution_role": execution_role,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if extra:
        payload.update(extra)
    redis_client().set(
        live_agent_session_key(agent_id),
        json.dumps(payload, separators=(",", ":"), default=str),
        ex=LIVE_AGENT_SESSION_TTL_SECONDS,
    )
    return payload


def reset_live_agent_session(agent_id: str) -> None:
    redis_client().delete(live_agent_session_key(agent_id))


def build_live_agent_instructions(
    agent_id: str,
    profile: dict[str, str],
    extra_instructions: str | None,
) -> str:
    instructions = [
        f"You are the {profile['display_name']} agent in the Cloud Superbrain multi-agent runtime.",
        profile["instructions"],
        f"Operate on the {profile['execution_role']} execution lane when you need to describe ownership.",
        "Be explicit about assumptions, concrete next actions, and missing evidence.",
        "Do not claim code changes, tests, deployments, or tool results unless they are present in the provided context.",
    ]
    if extra_instructions:
        instructions.append(f"Additional operator instructions: {extra_instructions}")
    return " ".join(instructions)


def extract_live_agent_text(response_payload: dict[str, object]) -> str:
    output_text = response_payload.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text.strip()

    texts: list[str] = []
    for item in response_payload.get("output", []):
        if not isinstance(item, dict) or item.get("type") != "message":
            continue
        for part in item.get("content", []):
            if isinstance(part, dict) and part.get("type") == "output_text" and part.get("text"):
                texts.append(str(part["text"]).strip())
    return "\n".join(text for text in texts if text).strip()


def call_llm_gateway_responses(payload: dict[str, object]) -> dict[str, object]:
    try:
        with httpx.Client(timeout=LIVE_AGENT_LLM_TIMEOUT_SECONDS) as client:
            response = client.post(f"{llm_gateway_url()}/v1/responses", json=payload)
            response.raise_for_status()
        data = response.json()
    except httpx.HTTPStatusError as exc:
        try:
            detail: object = exc.response.json()
        except ValueError:
            detail = exc.response.text or "llm gateway responses request failed"
        raise HTTPException(status_code=exc.response.status_code, detail=detail) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"llm gateway responses request failed: {exc}") from exc

    if not isinstance(data, dict):
        raise HTTPException(status_code=502, detail="llm gateway returned an invalid responses payload")
    return data


def live_agent_contract_payload() -> dict[str, object]:
    return {
        "contract_version": LIVE_AGENT_STEERING_CONTRACT_VERSION,
        "mode": "openai_responses_via_llm_gateway",
        "status_endpoint": "GET /api/v1/live-agents/status",
        "steer_endpoint": "POST /api/v1/live-agents/steer",
        "reset_endpoint": "POST /api/v1/live-agents/{agent_id}/reset",
        "compatibility_endpoint": "POST /api/steer-agent",
        "llm_gateway_endpoint": "POST /llm/v1/responses",
        "llm_gateway_contract_endpoint": "GET /llm/api/v1/responses/contract",
        "llm_gateway_contract_version": LLM_RESPONSES_ADAPTER_CONTRACT_VERSION,
        "session_store": {
            "type": "redis",
            "key_pattern": "live-agent:responses:<agent_id>",
            "ttl_seconds": LIVE_AGENT_SESSION_TTL_SECONDS,
        },
        "default_model": live_agent_default_model(),
        "accepted_request_fields": [
            "agent_id",
            "agentId",
            "message",
            "project_id",
            "projectId",
            "model",
            "instructions",
            "reasoning_effort",
            "reset_history",
            "resetHistory",
            "metadata",
        ],
        "response_fields": [
            "contract_version",
            "response_id",
            "responseId",
            "text",
            "status",
            "model",
            "usage",
            "runtime_source",
            "trace_id",
            "evidence_ref",
            "llm_gateway_contract_version",
            "llm_gateway_evidence_ref",
            "live_provider_calls",
            "model_downloads",
            "audit_persisted",
            "secret_output",
        ],
        "required_llm_response_fields": [
            "id",
            "object",
            "status",
            "contract_version",
            "evidence_ref",
            "trace_id",
            "output",
            "output_text",
            "live_provider_calls",
            "model_downloads",
            "audit_persisted",
        ],
        "agents": [
            {
                "agent_id": agent_id,
                "display_name": profile["display_name"],
                "execution_role": profile["execution_role"],
            }
            for agent_id, profile in LIVE_AGENT_PROFILES.items()
        ],
        "zip_relay_compatibility": {
            "accepted_request_shape": {"agentId": "string", "message": "string"},
            "returned_response_shape": {"responseId": "string", "text": "string"},
        },
        "evidence_refs": {
            "contract_visible": LIVE_AGENT_STEERING_EVIDENCE_REF,
            "llm_responses_adapter": LLM_RESPONSES_ADAPTER_EVIDENCE_REF,
            "llm_gateway_audit": "llm_gateway_responses_audit_persisted",
        },
        "non_claims": [
            "No API key is stored by this contract surface.",
            "Responses streaming passthrough is not exposed on this path.",
            "No direct provider URL is called by the Agent API.",
            "No live provider call is claimed unless the LLM Gateway policy and owner gate allow it.",
        ],
    }


def live_agent_status_payload() -> dict[str, object]:
    agents: list[dict[str, object]] = []
    for agent_id, profile in LIVE_AGENT_PROFILES.items():
        session = get_live_agent_session(agent_id)
        agents.append(
            {
                "agent_id": agent_id,
                "display_name": profile["display_name"],
                "execution_role": profile["execution_role"],
                "has_session": bool(session),
                "previous_response_id": session.get("previous_response_id") if session else None,
                "updated_at": session.get("updated_at") if session else None,
                "model": session.get("model") if session else None,
                "last_trace_id": session.get("last_trace_id") if session else None,
                "last_result_type": session.get("last_result_type") if session else None,
                "last_output_path": session.get("last_output_path") if session else None,
                "last_command": session.get("last_command") if session else None,
                "last_exit_code": session.get("last_exit_code") if session else None,
            }
        )
    return {
        "status": "available",
        "contract_version": LIVE_AGENT_STEERING_CONTRACT_VERSION,
        "runtime_source": "openai_responses_via_llm_gateway",
        "default_model": live_agent_default_model(),
        "agent_count": len(agents),
        "agents": agents,
        "evidence_ref": LIVE_AGENT_STEERING_EVIDENCE_REF,
    }


def evidence_dir() -> Path:
    return Path(os.getenv("EVIDENCE_DIR", "/tmp"))


def live_agent_feature_dir() -> Path:
    path = evidence_dir() / "F2"
    path.mkdir(parents=True, exist_ok=True)
    return path


def live_agent_workspace_dir() -> Path:
    path = live_agent_feature_dir() / "workspace"
    path.mkdir(parents=True, exist_ok=True)
    return path


def safe_file_token(value: str) -> str:
    token = re.sub(r"[^a-z0-9_-]+", "-", value.strip().lower())
    token = re.sub(r"-{2,}", "-", token).strip("-")
    return token or "agent"


def evidence_rel(path: Path) -> str:
    try:
        return path.relative_to(evidence_dir()).as_posix()
    except ValueError:
        return path.as_posix()


def timestamp_token() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def write_agent_text_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def run_local_tester_command(compiled_path: Path) -> tuple[str, int, str]:
    command = (
        'python -c "import py_compile; '
        + f"py_compile.compile('/app/app/main.py', cfile=r'{compiled_path.as_posix()}', doraise=True)"
        + '"'
    )
    completed = subprocess.run(
        [
            "python",
            "-c",
            "import py_compile; "
            + f"py_compile.compile('/app/app/main.py', cfile=r'{compiled_path.as_posix()}', doraise=True)",
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=60,
    )
    output = "\n".join(part for part in [completed.stdout.strip(), completed.stderr.strip()] if part).strip()
    return command, int(completed.returncode), output


def build_devops_health_snapshot(trace_id: str) -> dict[str, object]:
    checks: list[dict[str, object]] = []
    probes = [
        ("agent_api", lambda: {"status": "healthy", "service": "agent-api"}),
        ("llm_gateway", check_llm_gateway),
        ("mcp_gateway", check_mcp),
    ]
    for name, probe in probes:
        last_error: str | None = None
        for _ in range(3):
            try:
                body = probe()
                checks.append(
                    {
                        "service": name,
                        "ok": True,
                        "status": body.get("status"),
                        "mode": body.get("mode"),
                        "openai_compatible": body.get("openai_compatible"),
                    }
                )
                last_error = None
                break
            except Exception as exc:
                last_error = type(exc).__name__
                time.sleep(1)
        if last_error:
            checks.append({"service": name, "ok": False, "error": last_error})
    return {
        "trace_id": trace_id,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "checks": checks,
    }


def perform_live_agent_result(
    *,
    agent_id: str,
    execution_role: str,
    project_id: str,
    trace_id: str,
    llm_text: str,
) -> dict[str, object]:
    ts = timestamp_token()
    agent_dir = live_agent_feature_dir() / safe_file_token(agent_id)
    agent_dir.mkdir(parents=True, exist_ok=True)
    workspace_dir = live_agent_workspace_dir()
    summary = llm_text.strip() or "No visible output"

    if execution_role == "planner":
        output_path = agent_dir / f"{ts}-plan.md"
        write_agent_text_file(
            output_path,
            f"# Planner Result\n\nProject: {project_id}\nTrace: {trace_id}\n\n{summary}\n",
        )
        return {
            "result_type": "file_written",
            "output_path": str(output_path),
            "output_rel": evidence_rel(output_path),
            "command": None,
            "exit_code": None,
        }

    if execution_role == "coder":
        output_path = workspace_dir / f"{ts}-coder-output.ts"
        file_text = (
            "export const coderAgentOutput = "
            + json.dumps(summary[:1200], ensure_ascii=True)
            + ";\n"
            + f'export const coderAgentTraceId = "{trace_id}";\n'
        )
        write_agent_text_file(output_path, file_text)
        return {
            "result_type": "file_written",
            "output_path": str(output_path),
            "output_rel": evidence_rel(output_path),
            "command": None,
            "exit_code": None,
        }

    if execution_role == "tester":
        compiled_path = agent_dir / f"{ts}-main.pyc"
        command, exit_code, output = run_local_tester_command(compiled_path)
        output_path = agent_dir / f"{ts}-tester-command.log"
        write_agent_text_file(
            output_path,
            f"command={command}\nexit_code={exit_code}\ntrace_id={trace_id}\ncompiled_artifact={compiled_path.as_posix()}\n\n{output}\n",
        )
        return {
            "result_type": "command_executed",
            "output_path": str(output_path),
            "output_rel": evidence_rel(output_path),
            "command": command,
            "exit_code": exit_code,
        }

    output_path = agent_dir / f"{ts}-devops-report.json"
    snapshot = build_devops_health_snapshot(trace_id)
    output_path.write_text(json.dumps(snapshot, indent=2), encoding="utf-8")
    return {
        "result_type": "ops_report",
        "output_path": str(output_path),
        "output_rel": evidence_rel(output_path),
        "command": "http_health_checks",
        "exit_code": 0 if all(item.get("ok") for item in snapshot["checks"] if isinstance(item, dict)) else 1,
    }


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


def memory_purge_job_status_surface_contract_payload() -> dict[str, object]:
    return {
        "contract_version": MEMORY_PURGE_JOB_STATUS_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/memory/purge/jobs/contract",
        "runtime_endpoint": "GET /api/v1/memory/purge/jobs/{job_id}",
        "trigger_endpoint": "DELETE /api/v1/memory?project_id={id}&confirm=true",
        "runtime_contract_version": DSGVO_PURGE_CONTRACT_VERSION,
        "evidence_ref": MEMORY_PURGE_JOB_STATUS_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "job_id",
            "status",
            "contract_version",
            "evidence_ref",
            "project_id",
            "project_uuid",
            "trace_id",
            "deleted_counts",
            "audit_event_id",
            "completed_at",
            "severity",
            "non_claims",
        ],
        "required_deleted_count_fields": [
            "redis_keys",
            "memory_entries",
            "agent_messages",
            "agent_sessions",
        ],
        "supported_statuses": ["completed"],
        "expected_evidence_ref": "memory_purge_job_status_visible",
        "policy_checks": [
            "Job status stays bound to DELETE /api/v1/memory purge execution.",
            "Job status stays read-only and audit-backed.",
            "Deleted-count visibility remains project-scoped and non-global.",
        ],
        "non_claims": memory_purge_contract_payload()["non_claims"],
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


def costs_contract_payload() -> dict[str, object]:
    budget_state = get_budget_state()
    return {
        "contract_version": "costs-surface-v1",
        "mode": "runtime_cost_breakdown_projection",
        "endpoint": "GET /api/v1/costs/contract",
        "runtime_endpoint": "GET /api/v1/costs",
        "required_top_level_fields": [
            "total_cost_cents",
            "budget_limit_cents",
            "budget_spent_percentage",
            "level",
            "allow_new_calls",
            "breakdown",
        ],
        "required_breakdown_fields": [
            "agent_type",
            "model_name",
            "provider_name",
            "cost_cents",
        ],
        "supported_levels": ["ok", "warning", "critical"],
        "budget_limit_cents": budget_state.budget_limit_cents,
        "evidence_ref": "costs_surface_contract_runtime_visible",
        "policy_checks": [
            "Costs surface remains a read-only runtime projection from cost_tracking and budget state.",
            "Budget level is derived from the current runtime budget state.",
            "Breakdown rows stay grouped by agent, model, and provider.",
        ],
        "non_claims": [
            "This contract does not claim provider invoice reconciliation.",
            "This contract does not claim production deployment.",
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


def health_contract_payload() -> dict[str, object]:
    budget_state = get_budget_state()
    infra_budget_state = get_infra_budget_state()
    gates = external_gate_state()
    return {
        "contract_version": HEALTH_CONTRACT_VERSION,
        "mode": "runtime_service_matrix_projection",
        "endpoint": "GET /api/v1/health/contract",
        "runtime_endpoint": "GET /api/v1/health",
        "required_top_level_fields": [
            "status",
            "service",
            "time",
            "applied_migrations",
            "services",
            "budget",
            "infra_budget",
            "external_gates",
        ],
        "required_service_keys": [
            "postgres",
            "redis",
            "agent_worker",
            "memory_worker",
            "mcp_gateway",
            "llm_gateway",
        ],
        "required_budget_fields": [
            "level",
            "spent_percentage",
            "total_cost_cents",
            "budget_limit_cents",
            "allow_new_calls",
        ],
        "required_infra_budget_fields": [
            "level",
            "spent_percentage",
            "projected_cost_cents",
            "budget_limit_cents",
            "allow_new_infra",
            "live_verified",
            "source",
        ],
        "required_external_gate_fields": [
            "status",
            "configured_count",
            "total_count",
            "local_execution_allowed",
        ],
        "supported_statuses": ["healthy", "degraded"],
        "supported_gate_statuses": ["verified", "action_required"],
        "budget_limit_cents": budget_state.budget_limit_cents,
        "infra_budget_limit_cents": infra_budget_state.budget_limit_cents,
        "infra_supported_sources": ["projection", "fly_api_readonly", "fly_api_readonly_plus_plan_projection"],
        "expected_external_gate_status": gates["status"],
        "evidence_ref": "health_contract_runtime_visible",
        "policy_checks": [
            "Health surface remains a read-only runtime projection.",
            "Required service keys remain visible on every healthy response.",
            "Budget, infra-budget, and external-gate summaries remain embedded in the health response.",
        ],
        "non_claims": [
            "This contract does not authorize production deployment.",
            "This contract does not claim live LLM provider execution is enabled.",
            "This contract does not create multi-region failover guarantees.",
        ],
    }


def cloud_inventory_contract_payload() -> dict[str, object]:
    state = cloud_provider_state()
    providers = [item for item in state.get("providers", []) if isinstance(item, dict)]
    layer_mapping = [item for item in state.get("seven_layer_mapping", []) if isinstance(item, dict)]
    return {
        "contract_version": "cloud-provider-surface-v1",
        "mode": "cloud_provider_runtime_surface_contract",
        "endpoint": "GET /api/v1/clouds/contract",
        "runtime_endpoint": "GET /api/v1/clouds",
        "runtime_contract_version": state.get("contract_version"),
        "required_top_level_fields": [
            "status",
            "configured_count",
            "live_verified_count",
            "total_count",
            "providers",
            "seven_layer_mapping",
            "policy_checks",
            "non_claims",
        ],
        "required_provider_fields": [
            "id",
            "label",
            "role",
            "layers",
            "configured",
            "live_verified",
            "status",
            "required_env",
            "optional_env",
            "env_status",
            "resources",
            "last_checked_at",
            "non_claims",
        ],
        "required_layer_mapping_fields": [
            "layer_id",
            "label",
            "providers",
            "evidence_ref",
        ],
        "required_provider_ids": [str(item.get("id")) for item in providers],
        "required_layer_ids": [str(item.get("layer_id")) for item in layer_mapping],
        "supported_statuses": ["complete", "partial", "action_required"],
        "supported_provider_statuses": ["verified", "configured", "live_verified", "action_required", "api_error"],
        "expected_runtime_contract_version": state.get("contract_version"),
        "expected_runtime_endpoint": state.get("endpoint"),
        "evidence_ref": "cloud_inventory_contract_runtime_visible",
        "policy_checks": list(state.get("policy_checks", [])),
        "non_claims": list(state.get("non_claims", [])),
    }


def cloud_layers_contract_payload() -> dict[str, object]:
    state = cloud_layer_readiness_state()
    layers = [item for item in state.get("layers", []) if isinstance(item, dict)]
    return {
        "contract_version": "cloud-layer-surface-v1",
        "mode": "cloud_layer_runtime_surface_contract",
        "endpoint": "GET /api/v1/clouds/layers/contract",
        "runtime_endpoint": "GET /api/v1/clouds/layers",
        "runtime_contract_version": state.get("contract_version"),
        "required_top_level_fields": [
            "status",
            "ready_layer_count",
            "partial_layer_count",
            "total_layer_count",
            "layers",
            "provider_inventory_endpoint",
            "provider_inventory_evidence_ref",
            "policy_checks",
            "non_claims",
        ],
        "required_layer_fields": [
            "layer_id",
            "label",
            "status",
            "required_providers",
            "configured_providers",
            "live_verified_providers",
            "blockers",
            "evidence_ref",
            "next_safe_action",
            "non_claims",
        ],
        "required_layer_ids": [str(item.get("layer_id")) for item in layers],
        "supported_statuses": ["verified", "partial", "action_required"],
        "supported_layer_statuses": ["live_verified", "partial_live_verified", "action_required"],
        "expected_runtime_contract_version": state.get("contract_version"),
        "expected_runtime_endpoint": state.get("endpoint"),
        "expected_provider_inventory_endpoint": state.get("provider_inventory_endpoint"),
        "evidence_ref": "cloud_layers_contract_runtime_visible",
        "policy_checks": list(state.get("policy_checks", [])),
        "non_claims": list(state.get("non_claims", [])),
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
            "task_id",
            "task_status",
            "retry_count",
            "max_retries",
            "error",
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
            "failure_surface_visible",
        ],
        "evidence_refs": {
            "contract_visible": "agent_activity_contract_visible",
            "trace_link_template": "agent_activity_trace_link_template",
            "auth_proxy_required": "langfuse_auth_proxy_required",
            "filtered_feed": "agent_activity_filtered_feed_visible",
            "per_role_results": "agent_activity_per_role_results_visible",
            "failure_surface": "agent_activity_failure_surface_visible",
        },
        "non_claims": [
            "This contract does not claim public unauthenticated Langfuse access.",
            "This contract does not claim live Langfuse traces until LANGFUSE_PUBLIC_URL is configured.",
            "Audit-log activity remains the local source of truth for Phase 3.",
        ],
    }


def escalation_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "escalation-feed-v1",
        "mode": "audit_log_backed_escalation_feed",
        "screen": "Escalations",
        "source_endpoints": [
            "GET /api/v1/escalations/recent?limit=20",
            "GET /api/v1/audit/recent?limit=50",
            "GET /api/v1/tasks/recent?limit=100",
            "GET /api/v1/sessions/recent?limit=50",
            "GET /api/v1/sessions/{session_id}/history",
        ],
        "top_level_fields": [
            "id",
            "event_type",
            "user_id",
            "session_id",
            "request_id",
            "trace_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
            "details",
            "created_at",
            "severity",
        ],
        "supported_statuses": ["escalated"],
        "request_trace_fields": [
            "request_id",
            "trace_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
        ],
        "policy_checks": [
            "The public escalation feed only carries escalated or critical paths.",
            "Every escalation event exposes top-level request, trace, correlation, and audit-feed evidence fields.",
            "Escalation request correlation remains aligned with audit, task, and session history surfaces.",
        ],
        "evidence_refs": {
            "contract_visible": "escalation_contract_visible",
            "runtime_visible": "hosted_escalation_contract_runtime_parity_proof",
            "request_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
        },
        "non_claims": [
            "This does not imply auto-remediation.",
            "This does not imply production rollout approval.",
        ],
    }


def recent_tasks_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "recent-tasks-feed-v1",
        "mode": "task_queue_runtime_feed",
        "screen": "Recent Tasks",
        "source_endpoints": [
            "GET /api/v1/tasks/recent?limit=20",
            "GET /api/v1/internal/tasks/{task_id}",
            "GET /api/v1/tasks/assignment-contract",
            "GET /api/v1/audit/recent?limit=50",
        ],
        "top_level_fields": [
            "task_id",
            "project_id",
            "session_id",
            "trace_id",
            "request_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
            "agent_type",
            "task_type",
            "task_description",
            "status",
            "priority",
            "created_at",
            "updated_at",
            "result",
            "error",
            "retry_count",
            "max_retries",
            "allowed_tools",
            "write_scope",
            "blocked_actions",
            "acceptance_criteria",
            "human_review_required",
            "policy_version",
            "result_envelope",
            "done_validation",
        ],
        "queue_fields": [
            "queue_depth",
            "queue_depth_by_priority",
        ],
        "supported_statuses": [
            "queued",
            "running",
            "completed",
            "failed",
            "escalated",
            "abandoned_after_queue_drain",
        ],
        "policy_checks": [
            "Recent tasks expose top-level request, trace, correlation, and audit-feed evidence fields.",
            "The request_id field is visible on recent tasks and may remain null until correlated audit or session evidence is available.",
            "Recent tasks preserve queue priority metadata and task policy fields.",
            "Recent tasks remain aligned with internal task status and audit evidence.",
        ],
        "evidence_refs": {
            "contract_visible": "recent_tasks_contract_visible",
            "runtime_visible": "hosted_recent_tasks_contract_runtime_parity_proof",
            "request_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
            "priority_queue": "task_priority_queue_correction_proof",
        },
        "non_claims": [
            "This does not imply production rollout approval.",
            "This does not imply guaranteed worker completion for every future task.",
        ],
    }


def agent_status_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "agent-status-feed-v1",
        "mode": "agent_runtime_status_feed",
        "screen": "Agent Status",
        "source_endpoints": [
            "GET /api/v1/agents/status",
            "GET /api/v1/tasks/recent?limit=100",
            "GET /api/v1/sessions/recent?limit=50",
            "GET /api/v1/sessions/{session_id}/history",
            "GET /api/v1/audit/recent?limit=50",
        ],
        "top_level_fields": [
            "type",
            "status",
            "profile_contract_version",
            "role",
            "primary_model",
            "fallbacks",
            "max_execution_seconds",
            "max_output_tokens",
            "max_retries",
            "allowed_tools",
            "blocked_actions",
            "human_review_required_actions",
            "graceful_degradation",
            "current_task",
            "current_session_id",
            "retries",
            "started_at",
            "updated_at",
            "latest_task_id",
            "latest_task_type",
            "latest_status",
            "latest_trace_id",
            "latest_request_id",
            "latest_correlation_evidence_ref",
            "latest_audit_feed_evidence_ref",
            "latest_result",
            "latest_error",
            "latest_retry_count",
            "latest_max_retries",
        ],
        "supported_statuses": ["idle", "queued", "active", "error"],
        "supported_latest_task_statuses": [
            "none",
            "queued",
            "running",
            "completed",
            "failed",
            "escalated",
            "abandoned_after_queue_drain",
        ],
        "policy_checks": [
            "Agent status exposes top-level latest request, trace, correlation, and audit-feed evidence fields.",
            "Agent status stays aligned with recent tasks, recent sessions, session history, and audit surfaces.",
            "Agent status surfaces negative worker states through error with latest task failure metadata.",
        ],
        "evidence_refs": {
            "contract_visible": "agent_status_contract_visible",
            "runtime_visible": "hosted_agent_status_contract_runtime_parity_proof",
            "request_correlation": "request_id_agent_status_visible",
            "audit_feed": "request_id_audit_feed_visible",
        },
        "non_claims": [
            "Agent status is an aggregated runtime surface, not a direct worker heartbeat stream.",
            "Idle agents do not imply no recent task history exists.",
            "This contract does not claim live LLM provider calls.",
        ],
    }


def recent_sessions_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "recent-sessions-feed-v1",
        "mode": "session_runtime_feed",
        "screen": "Recent Sessions",
        "source_endpoints": [
            "GET /api/v1/sessions/recent?limit=20",
            "GET /api/v1/sessions/{session_id}/history",
            "GET /api/v1/tasks/recent?limit=100",
            "GET /api/v1/agent-activity/recent?limit=100",
            "GET /api/v1/audit/recent?limit=50",
        ],
        "top_level_fields": [
            "session_id",
            "project_id",
            "started_at",
            "status",
            "trace_id",
            "request_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
            "latest_task_id",
            "latest_task_status",
            "latest_error",
            "latest_retry_count",
            "latest_max_retries",
            "prompt",
            "assistant_result",
        ],
        "supported_statuses": [
            "running",
            "completed",
            "escalated",
            "abandoned_after_queue_drain",
        ],
        "policy_checks": [
            "Recent sessions expose top-level request, trace, correlation, and audit-feed evidence fields.",
            "Recent sessions stay aligned with session history, recent tasks, and agent-activity surfaces.",
            "Recent sessions surface latest task failure metadata for negative worker paths.",
        ],
        "evidence_refs": {
            "contract_visible": "recent_sessions_contract_visible",
            "runtime_visible": "hosted_recent_sessions_contract_runtime_parity_proof",
            "request_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
            "failure_surface": "recent_session_failure_status_surface_visible",
        },
        "non_claims": [
            "This does not imply production rollout approval.",
            "This does not imply immutable retention of every historical session event.",
        ],
    }


def session_history_contract_payload() -> dict[str, object]:
    return {
        "contract_version": SESSION_HISTORY_CONTRACT_VERSION,
        "mode": "session_history_runtime_feed",
        "screen": "Session History",
        "source_endpoints": [
            "GET /api/v1/sessions/{session_id}/history",
            "GET /api/v1/sessions/recent?limit=20",
            "GET /api/v1/tasks/recent?limit=100",
            "GET /api/v1/agent-activity/recent?limit=100",
            "GET /api/v1/audit/recent?limit=50",
        ],
        "top_level_sections": [
            "contract_version",
            "evidence_ref",
            "session",
            "messages",
            "tasks",
            "audit_events",
            "project_progress",
            "project_progress_integrity",
            "non_claims",
        ],
        "session_fields": [
            "session_id",
            "project_id",
            "started_at",
            "status",
            "metadata",
        ],
        "task_fields": [
            "task_id",
            "project_id",
            "session_id",
            "trace_id",
            "request_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
            "agent_type",
            "task_type",
            "task_description",
            "status",
            "created_at",
            "updated_at",
            "result",
            "error",
            "retry_count",
            "max_retries",
            "allowed_tools",
            "write_scope",
            "blocked_actions",
            "acceptance_criteria",
            "human_review_required",
            "policy_version",
            "result_envelope",
            "done_validation",
        ],
        "audit_event_fields": [
            "id",
            "event_type",
            "user_id",
            "session_id",
            "details",
            "request_id",
            "trace_id",
            "created_at",
            "severity",
        ],
        "supported_statuses": [
            "running",
            "completed",
            "escalated",
            "abandoned_after_queue_drain",
        ],
        "policy_checks": [
            "Session history exposes top-level request, trace, correlation, and audit-feed evidence fields on task records.",
            "Session history remains aligned with recent sessions, recent tasks, agent activity, and audit surfaces.",
            "Session history preserves deterministic prompt, assistant result, and project-progress integrity context.",
        ],
        "evidence_refs": {
            "contract_visible": "session_history_contract_visible",
            "runtime_visible": "hosted_session_history_contract_runtime_parity_proof",
            "history_openable": SESSION_HISTORY_EVIDENCE_REF,
            "request_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
        },
        "non_claims": [
            "This does not imply production rollout approval.",
            "This does not imply that every future session will retain unlimited history.",
        ],
    }


def session_stream_surface_contract_payload() -> dict[str, object]:
    return {
        "contract_version": SESSION_STREAM_SURFACE_CONTRACT_VERSION,
        "mode": "session_stream_runtime_feed",
        "screen": "Session Stream",
        "endpoint": "GET /api/v1/session/stream/contract",
        "runtime_endpoint": "GET /api/v1/session/{session_id}/stream",
        "related_endpoints": [
            "POST /api/v1/prompt",
            "GET /api/v1/sessions/{session_id}/history",
            "GET /api/v1/sessions/recent?limit=10",
            "GET /api/v1/audit/recent?limit=20",
        ],
        "content_type": "text/event-stream",
        "replay_header": "Last-Event-ID",
        "required_event_types": [
            "heartbeat",
            "agent_status",
            "token",
            "error",
            "done",
        ],
        "required_agent_status_fields": [
            "agent",
            "status",
            "task",
            "task_id",
            "updated_at",
        ],
        "required_terminal_fields": [
            "session_id",
            "task_id",
            "total_tokens",
            "total_cost_cents",
        ],
        "supported_task_statuses": [
            "idle",
            "queued",
            "running",
            "completed",
            "failed",
        ],
        "policy_checks": [
            "Session stream stays replayable through Last-Event-ID.",
            "Session stream stays aligned with session history, recent sessions, and audit feed.",
            "Session stream remains deterministic and does not claim live provider calls.",
        ],
        "evidence_refs": {
            "contract_visible": SESSION_STREAM_SURFACE_EVIDENCE_REF,
            "runtime_visible": "hosted_session_stream_contract_runtime_parity_proof",
            "history_openable": SESSION_HISTORY_EVIDENCE_REF,
            "replay_buffered": "sse_replay_buffered",
        },
        "non_claims": [
            "This does not imply live provider token streaming.",
            "This does not imply production rollout approval.",
        ],
    }


def audit_feed_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "audit-feed-v1",
        "mode": "audit_log_runtime_feed",
        "screen": "Audit Feed",
        "source_endpoints": [
            "GET /api/v1/audit/recent?limit=50",
            "GET /api/v1/sessions/{session_id}/history",
            "GET /api/v1/tasks/recent?limit=100",
            "GET /api/v1/agent-activity/recent?limit=100",
        ],
        "top_level_fields": [
            "id",
            "event_type",
            "user_id",
            "session_id",
            "details",
            "request_id",
            "trace_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
            "created_at",
            "severity",
        ],
        "supported_event_types": [
            "task_completed",
            "task_escalated",
            "task_abandoned_after_queue_drain",
            "task_status_rehydrated_from_audit",
            "mcp_tool_executed",
            "memory_consolidated",
        ],
        "policy_checks": [
            "Audit feed exposes top-level request, trace, correlation, and audit-feed evidence fields.",
            "Audit feed remains aligned with session history, recent tasks, and agent-activity surfaces.",
            "Audit feed is the public source-of-truth surface for request-correlation evidence.",
        ],
        "evidence_refs": {
            "contract_visible": "audit_feed_contract_visible",
            "runtime_visible": "hosted_audit_feed_contract_runtime_parity_proof",
            "request_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
        },
        "non_claims": [
            "This does not imply production rollout approval.",
            "This does not imply unbounded audit retention.",
        ],
    }


def mcp_audit_feed_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "mcp-audit-feed-v1",
        "mode": "mcp_tool_audit_runtime_feed",
        "screen": "MCP Audit",
        "source_endpoints": [
            "GET /api/v1/audit/mcp?limit=20",
            "POST /internal/audit/mcp-tool-events",
            "GET /api/v1/audit/recent?limit=50",
        ],
        "top_level_fields": [
            "id",
            "event_type",
            "user_id",
            "session_id",
            "trace_id",
            "details",
            "created_at",
            "severity",
        ],
        "required_detail_fields": [
            "tool_request_id",
            "run_id",
            "trace_id",
            "agent_role",
            "toolset",
            "capability",
            "status",
            "error_class",
            "sanitized_summary",
            "evidence_ref",
            "result_ref",
            "duration_ms",
            "retry_after_ms",
            "audit_tags",
            "session_bound",
            "audit_evidence_ref",
        ],
        "supported_statuses": ["success", "blocked", "timeout", "degraded"],
        "supported_toolsets": ["github", "e2b", "playwright", "filesystem", "postgresql", "puppeteer"],
        "policy_checks": [
            "MCP audit feed exposes session-bound tool execution events as a public runtime surface.",
            "Feed stays aligned with internal MCP audit writes and carries visible trace and evidence references.",
            "Feed remains non-mutating and does not claim live MCP writes were executed.",
        ],
        "evidence_refs": {
            "contract_visible": "mcp_audit_feed_contract_runtime_visible",
            "runtime_visible": "hosted_mcp_audit_feed_contract_runtime_parity_proof",
            "session_bound_audit": "mcp_tool_session_bound_audit",
        },
        "non_claims": [
            "This contract does not claim live MCP writes are enabled.",
            "This contract does not authorize production deployment.",
            "This contract does not claim provider-side mutations were executed.",
        ],
    }


def memory_consolidation_contract_payload() -> dict[str, object]:
    return {
        "contract_version": MEMORY_CONSOLIDATION_CONTRACT_VERSION,
        "mode": "audit_log_backed_memory_consolidation_feed",
        "screen": "Memory Consolidation",
        "source_endpoints": [
            "GET /api/v1/memory/consolidation/contract",
            "GET /api/v1/memory/consolidation/recent?limit=20",
        ],
        "top_level_sections": ["events", "summary"],
        "event_fields": [
            "id",
            "event_type",
            "user_id",
            "session_id",
            "details",
            "created_at",
            "severity",
        ],
        "summary_fields": ["event_type", "severity", "reason", "count"],
        "supported_event_types": [
            "memory_consolidated",
            "memory_consolidation_skipped",
            "memory_consolidation_blocked",
        ],
        "detail_expectations": {
            "memory_consolidated": [
                "memory_id",
                "redis_key",
                "project_id",
                "ttl_seconds",
                "idempotency_key",
                "memory_transaction_id",
            ],
            "memory_consolidation_skipped": ["reason"],
            "memory_consolidation_blocked": ["reason"],
        },
        "evidence_ref": MEMORY_CONSOLIDATION_EVIDENCE_REF,
        "status": "verified",
        "non_claims": [
            "No live embedding provider call is made by this feed.",
            "No vector search production claim is made by this contract.",
            "No production deployment is claimed.",
        ],
    }


def memory_search_contract_payload() -> dict[str, object]:
    return {
        "contract_version": MEMORY_SEARCH_CONTRACT_VERSION,
        "mode": "memory_search_runtime_feed",
        "source_endpoints": [
            "GET /api/v1/memory/search/contract",
            "GET /api/v1/memory/search?q={query}&project_id={id}&limit=5&threshold=0.0",
            "GET /api/v1/memory/embedding-consistency/contract",
        ],
        "query_parameters": {
            "q": {"required": True, "min_length": 1, "max_length": 1000},
            "project_id": {"required": True, "min_length": 1},
            "limit": {"required": False, "default": 5, "min": 1, "max": 20},
            "threshold": {"required": False, "default": 0.0, "min": 0.0, "max": 1.0},
        },
        "top_level_sections": ["results", "search_mode"],
        "result_fields": ["id", "content", "relevance_score", "created_at", "session_id"],
        "search_mode": EMBEDDING_SEARCH_MODE,
        "depends_on": {
            "embedding_consistency_contract": "GET /api/v1/memory/embedding-consistency/contract",
            "search_mode": EMBEDDING_SEARCH_MODE,
            "vector_search_enabled": False,
        },
        "evidence_ref": MEMORY_SEARCH_EVIDENCE_REF,
        "status": "verified",
        "non_claims": [
            "No live embedding provider call is made by this search endpoint.",
            "No vector search production claim is made while search_mode remains lexical_fallback.",
            "No production deployment is claimed.",
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


def persist_autonomous_dispatch_audit(record: AutonomousDispatchRecord) -> None:
    severity = "info"
    if record.status in {"attention", "failed"}:
        severity = "warning"
    details = redact_json(
        {
            "contract_version": record.dispatch_contract_version,
            "team_contract_version": record.team_contract_version,
            "dispatch_id": record.dispatch_id,
            "project_id": record.project_id,
            "session_id": record.session_id,
            "trace_id": record.trace_id,
            "request_id": record.request_id,
            "status": record.status,
            "team_mode": record.team_mode,
            "objective": record.objective,
            "assignments": [assignment.model_dump() for assignment in record.assignments],
            "correlation_evidence_ref": "request_id_audit_correlation" if (record.request_id or record.trace_id) else None,
            "audit_feed_evidence_ref": "request_id_audit_feed_visible" if (record.request_id or record.trace_id) else None,
            "evidence_ref": AUTONOMOUS_TASK_DISPATCH_EVIDENCE_REF,
        }
    )
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, session_id, details, severity)
                VALUES ('autonomous_team_dispatch', 'planner', %s, %s::jsonb, %s)
                """,
                (record.session_id, Json(details), severity),
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


def workflow_dispatch_plan_surface_contract_payload() -> dict[str, object]:
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
    runtime = workflow_dispatch_contract(request)
    return {
        "contract_version": DEVOPS_WORKFLOW_DISPATCH_PLAN_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/devops/workflow-dispatch/plan/contract",
        "runtime_endpoint": "GET /api/v1/devops/workflow-dispatch/plan",
        "runtime_contract_version": runtime["contract_version"],
        "evidence_ref": DEVOPS_WORKFLOW_DISPATCH_PLAN_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "mode",
            "live_github_call",
            "github_api",
            "payload",
            "human_gate",
            "violations",
            "non_claims",
        ],
        "required_github_api_fields": [
            "method",
            "endpoint",
            "required_token_env",
            "required_permission",
        ],
        "required_payload_fields": [
            "ref",
            "inputs",
        ],
        "required_input_fields": [
            "environment",
            "action",
            "image_tag",
            "reason",
            "trace_id",
            "dry_run",
        ],
        "expected_statuses": ["ready", "blocked"],
        "expected_mode": runtime["mode"],
        "expected_live_github_call": False,
    }


def workflow_dispatch_validate_surface_contract_payload() -> dict[str, object]:
    ready_request = WorkflowDispatchRequest(
        workflow_id="main-deploy.yml",
        ref="main",
        environment="staging",
        action="deploy",
        image_tag="ghcr.io/repo/agent-api:sha-placeholder",
        reason="deterministic staging validate contract preview",
        trace_id="devops-dispatch-validate-ready",
        human_review_approved=False,
        dry_run=True,
    )
    blocked_request = WorkflowDispatchRequest(
        workflow_id="main-deploy.yml",
        ref="main",
        environment="production",
        action="deploy",
        image_tag="ghcr.io/repo/agent-api:sha-placeholder",
        reason="deterministic production validate contract preview",
        trace_id="devops-dispatch-validate-blocked",
        human_review_approved=False,
        dry_run=True,
    )
    ready_runtime = workflow_dispatch_contract(ready_request)
    blocked_runtime = workflow_dispatch_contract(blocked_request)
    return {
        "contract_version": DEVOPS_WORKFLOW_DISPATCH_VALIDATE_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/devops/workflow-dispatch/validate/contract",
        "runtime_endpoint": "POST /api/v1/devops/workflow-dispatch/validate",
        "runtime_contract_version": ready_runtime["contract_version"],
        "evidence_ref": DEVOPS_WORKFLOW_DISPATCH_VALIDATE_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "mode",
            "live_github_call",
            "github_api",
            "payload",
            "human_gate",
            "violations",
            "non_claims",
        ],
        "required_github_api_fields": [
            "method",
            "endpoint",
            "required_token_env",
            "required_permission",
        ],
        "required_payload_fields": [
            "ref",
            "inputs",
        ],
        "required_input_fields": [
            "environment",
            "action",
            "image_tag",
            "reason",
            "trace_id",
            "dry_run",
        ],
        "supported_statuses": ["ready", "blocked"],
        "ready_case": {
            "http_status": 200,
            "environment": ready_request.environment,
            "status": ready_runtime["status"],
            "violations": ready_runtime["violations"],
        },
        "blocked_case": {
            "http_status": 403,
            "environment": blocked_request.environment,
            "status": blocked_runtime["status"],
            "detail_code": "workflow_dispatch_blocked",
            "expected_violation": "production workflow dispatch requires human_review_approved=true",
        },
        "expected_mode": ready_runtime["mode"],
        "expected_live_github_call": False,
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
    manifest_path = project_progress_manifest_path()
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


def project_progress_surface_contract_payload() -> dict[str, object]:
    progress = project_progress_payload()
    return {
        "contract_version": PROGRESS_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/project/progress",
        "guarded_endpoint": "GET /api/v1/project/progress/integrity",
        "evidence_ref": PROGRESS_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "overall_percent",
            "progress_source",
            "horizontal",
            "vertical",
            "truth_policy",
            "binding_document",
            "last_verified",
            "non_claims",
        ],
        "required_horizontal_fields": [
            "label",
            "items",
        ],
        "required_vertical_fields": [
            "label",
            "items",
        ],
        "required_progress_item_fields": [
            "id",
            "label",
            "percent",
            "status",
        ],
        "expected_phase_count": len(progress["horizontal"]["items"]),  # type: ignore[index]
        "expected_layer_count": len(progress["vertical"]["items"]),  # type: ignore[index]
        "expected_progress_source": "docs/project-progress.manifest.json",
        "expected_binding_document": "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md",
        "non_claims": [
            "This contract does not increase progress by itself.",
            "This contract does not claim production deployment.",
            "This contract does not claim live LLM provider calls or live MCP writes.",
        ],
    }


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


def project_progress_integrity_surface_contract_payload() -> dict[str, object]:
    integrity = project_progress_integrity_payload()
    return {
        "contract_version": PROGRESS_INTEGRITY_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/project/progress/integrity",
        "guarded_endpoint": integrity["guarded_endpoint"],
        "runtime_contract_version": integrity["contract_version"],
        "evidence_ref": PROGRESS_INTEGRITY_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "endpoint",
            "guarded_endpoint",
            "source_manifest",
            "binding_document",
            "manifest_overall_percent",
            "computed_overall_percent",
            "horizontal_phase_count",
            "vertical_layer_count",
            "horizontal_phase_percentages",
            "vertical_layer_percentages",
            "truth_policy",
            "evidence_ref",
            "mismatches",
            "hard_rules",
            "non_claims",
        ],
        "expected_statuses": [
            "verified",
            "blocked",
        ],
        "required_hard_rules": list(integrity["hard_rules"]),
        "non_claims": list(integrity["non_claims"]),
    }


def project_progress_layers_payload() -> dict[str, object]:
    progress = project_progress_payload()
    layers = list(progress["vertical"]["items"])  # type: ignore[index]
    return {
        "contract_version": PROGRESS_LAYERS_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/project/progress/layers",
        "overall_percent": int(progress["overall_percent"]),
        "progress_source": progress["progress_source"],
        "binding_document": progress["binding_document"],
        "truth_policy": progress["truth_policy"],
        "last_verified": progress["last_verified"],
        "label": progress["vertical"]["label"],  # type: ignore[index]
        "count": len(layers),
        "items": layers,
        "non_claims": [
            "This endpoint is a layer-only projection of the canonical project progress manifest.",
            "This endpoint does not increase progress by itself.",
            "This endpoint does not claim production deployment.",
        ],
    }


def project_progress_layers_surface_contract_payload() -> dict[str, object]:
    layers = project_progress_layers_payload()
    return {
        "contract_version": PROGRESS_LAYERS_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/project/progress/layers",
        "guarded_endpoints": [
            "GET /api/v1/project/progress",
            "GET /api/v1/project/progress/integrity",
        ],
        "evidence_ref": PROGRESS_LAYERS_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "endpoint",
            "overall_percent",
            "progress_source",
            "binding_document",
            "truth_policy",
            "last_verified",
            "label",
            "count",
            "items",
            "non_claims",
        ],
        "required_item_fields": [
            "id",
            "label",
            "percent",
            "status",
        ],
        "expected_count": int(layers["count"]),
        "expected_ids": [str(item["id"]) for item in layers["items"]],  # type: ignore[index]
        "expected_label": layers["label"],
        "non_claims": layers["non_claims"],
    }


def progress_percent_map(items: list[dict[str, object]]) -> dict[str, int]:
    return {str(item["id"]): int(item["percent"]) for item in items}


def autonomous_master_plan_payload() -> dict[str, object]:
    progress = project_progress_payload()
    integrity = project_progress_integrity_payload()
    external_runtime = external_autonomous_runtime_state()
    state_markdown = project_state_markdown()
    anchor_lines = markdown_section_lines(state_markdown, "## AKTUELLER PROJEKTANKER")
    next_step_lines = markdown_section_lines(state_markdown, "## NÄCHSTER KONKRETER ARBEITSSCHRITT")
    constraint_lines = markdown_section_lines(state_markdown, "## HARTE CONSTRAINTS (NIEMALS BRECHEN)")
    container_lines = markdown_section_lines(state_markdown, "## LAUFENDE DOCKER-CONTAINER (cloud-superbrain-phase1-dev)")
    phases = list(progress["horizontal"]["items"])  # type: ignore[index]
    layers = list(progress["vertical"]["items"])  # type: ignore[index]
    return {
        "contract_version": AUTONOMOUS_MASTER_PLAN_CONTRACT_VERSION,
        "status": "loaded",
        "endpoint": "GET /api/v1/team/master-plan",
        "source_document": "PROJECT_STATE.md",
        "binding_document": progress["binding_document"],
        "progress_manifest": progress["progress_source"],
        "overall_percent": int(progress["overall_percent"]),
        "integrity_status": integrity["status"],
        "phase_percentages": progress_percent_map(phases),
        "layer_percentages": progress_percent_map(layers),
        "team_mode": AUTONOMOUS_TEAM_MODE,
        "runtime_source": "external_adapter" if external_runtime["ready"] else "internal_queue",
        "logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
        "dispatch_endpoints": [
            "GET /api/v1/team/status",
            "POST /api/v1/task/dispatch",
            "GET /api/v1/task/dispatches/recent",
        ],
        "external_runtime_adapter": external_runtime,
        "anchor_snapshot": anchor_lines,
        "next_concrete_steps": markdown_bullets(next_step_lines) or next_step_lines,
        "hard_constraints": markdown_bullets(constraint_lines) or constraint_lines,
        "running_containers": markdown_bullets(container_lines) or container_lines,
        "evidence_ref": AUTONOMOUS_MASTER_PLAN_EVIDENCE_REF,
        "non_claims": [
            "This endpoint is a runtime projection of repository state documents.",
            "This endpoint does not claim production deployment.",
            "This endpoint does not claim live provider writes or live MCP writes.",
        ],
    }


def autonomous_master_plan_contract_payload() -> dict[str, object]:
    plan = autonomous_master_plan_payload()
    return {
        "contract_version": AUTONOMOUS_MASTER_PLAN_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/team/master-plan/contract",
        "runtime_endpoint": "GET /api/v1/team/master-plan",
        "status_endpoint": "GET /api/v1/team/status",
        "evidence_ref": AUTONOMOUS_MASTER_PLAN_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "endpoint",
            "source_document",
            "binding_document",
            "progress_manifest",
            "overall_percent",
            "integrity_status",
            "phase_percentages",
            "layer_percentages",
            "team_mode",
            "runtime_source",
            "logical_roles",
            "dispatch_endpoints",
            "external_runtime_adapter",
            "anchor_snapshot",
            "next_concrete_steps",
            "hard_constraints",
            "running_containers",
            "evidence_ref",
            "non_claims",
        ],
        "required_logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
        "required_dispatch_endpoints": list(plan["dispatch_endpoints"]),
        "required_documents": [
            "PROJECT_STATE.md",
            "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md",
            "docs/project-progress.manifest.json",
        ],
        "non_claims": list(plan["non_claims"]),
    }


def autonomous_agent_roster_payload() -> dict[str, object]:
    roster_source = autonomous_agent_roster_document()
    roster = roster_source["document"] if isinstance(roster_source["document"], dict) else {}
    operating_core = roster.get("operating_core") if isinstance(roster.get("operating_core"), dict) else {}
    launcher_status = roster.get("launcher_status") if isinstance(roster.get("launcher_status"), dict) else {}
    roles = [item for item in roster.get("roles", []) if isinstance(item, dict)]
    startup_protocol = [str(item) for item in roster.get("startup_protocol", []) if str(item).strip()]
    runtime_bindings = autonomous_runtime_bindings()
    external_runtime = runtime_bindings.get("external_adapter", {})
    return {
        "contract_version": AUTONOMOUS_AGENT_ROSTER_CONTRACT_VERSION,
        "status": roster_source["status"],
        "endpoint": "GET /api/v1/team/roster",
        "source_document": roster_source["source_document"],
        "source_path": roster_source["source_path"],
        "roster_version": str(roster.get("version") or "unknown"),
        "runtime_source": "external_adapter" if bool(external_runtime.get("ready")) else "internal_queue",
        "operating_core": operating_core,
        "startup_protocol": startup_protocol,
        "launcher_status": launcher_status,
        "role_count": len(roles),
        "roles": roles,
        "runtime_bindings": runtime_bindings,
        "error": roster_source["error"],
        "evidence_ref": AUTONOMOUS_AGENT_ROSTER_EVIDENCE_REF,
        "non_claims": [
            "This endpoint reflects the persisted roster plus live runtime binding metadata.",
            "Persisted roster state does not keep Codex desktop child threads alive across app restarts.",
            "CrewAI and Grafana are not claimed live unless separate runtime evidence surfaces them.",
        ],
    }


def autonomous_agent_roster_contract_payload() -> dict[str, object]:
    roster = autonomous_agent_roster_payload()
    return {
        "contract_version": AUTONOMOUS_AGENT_ROSTER_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/team/roster/contract",
        "runtime_endpoint": "GET /api/v1/team/roster",
        "status_endpoint": "GET /api/v1/team/status",
        "evidence_ref": AUTONOMOUS_AGENT_ROSTER_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "endpoint",
            "source_document",
            "source_path",
            "roster_version",
            "runtime_source",
            "operating_core",
            "startup_protocol",
            "launcher_status",
            "role_count",
            "roles",
            "runtime_bindings",
            "error",
            "evidence_ref",
            "non_claims",
        ],
        "required_runtime_binding_keys": [
            "langgraph",
            "crewai",
            "prometheus",
            "grafana",
            "redis",
            "pgvector",
            "external_adapter",
        ],
        "required_documents": [
            "docs/codex-integration/autonomous-agent-roster.json",
            "PROJECT_STATE.md",
            "docs/project-progress.manifest.json",
        ],
        "non_claims": list(roster["non_claims"]),
    }


def _completion_status(percent: int, blockers: list[str]) -> str:
    if percent >= 100 and not blockers:
        return "verified_100"
    if blockers:
        return "blocked_external_gate"
    return "ready_for_evidence_slice"


def project_progress_completion_payload() -> dict[str, object]:
    progress = project_progress_payload()
    verified_flags = external_gate_verification_flags(progress)
    gates = external_gate_state()
    gate_items = list(gates["gates"])
    missing_gate_ids = [str(gate["id"]) for gate in gate_items if not gate["configured"]]
    missing_gate_blocker_map = {
        "staging_base_url": "hosted_staging_proof_requires_STAGING_BASE_URL",
        "branch_protection_token": "protected_main_proof_requires_BRANCH_PROTECTION_TOKEN",
        "gitleaks_binary": "canonical_secret_scan_requires_gitleaks_binary",
        "fly_api_token": "live_infra_budget_refresh_requires_FLY_API_TOKEN",
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
        "phase_1": [
            blocker
            for blocker, enabled in [
                ("hosted_staging_proof_requires_STAGING_BASE_URL", not verified_flags["hosted_staging"]),
                ("canonical_secret_scan_requires_gitleaks_binary", not verified_flags["canonical_secret_scan"]),
            ]
            if enabled
        ],
        "phase_2": ["live_llm_provider_calls_require_owner_gate_and_budget_guard"],
        "phase_3": ["production_auth_identity_requires_owner_configured_oauth_and_hosted_url"],
        "phase_4": [
            blocker
            for blocker, enabled in [
                ("hosted_staging_proof_requires_STAGING_BASE_URL", not verified_flags["hosted_staging"]),
                ("protected_main_proof_requires_BRANCH_PROTECTION_TOKEN", not verified_flags["branch_protection"]),
                ("live_infra_budget_refresh_requires_FLY_API_TOKEN", not verified_flags["fly_cloud_stack"]),
            ]
            if enabled
        ],
        "phase_5": [
            blocker
            for blocker, enabled in [
                (
                    "production_release_requires_hosted_staging_branch_protection_secret_scan_and_owner_review",
                    not verified_flags["production_gate_claim_allowed"],
                ),
                ("docker_registry_publish_requires_owner_release_gate", True),
            ]
            if enabled
        ],
        "phase_6": [
            "phase6_scale_3d_platform_requires_separate_scale_budget_and_runtime_proof",
            "live_mcp_writes_require_owner_gate_branch_protection_and_audit",
        ],
    }
    layer_blockers: dict[str, list[str]] = {
        "layer_1": [] if verified_flags["hosted_staging"] else ["hosted_browser_proof_requires_STAGING_BASE_URL"],
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
    # Fail closed: any blocker already surfaced on a phase/layer must also block top-level completion.
    item_blockers = list(
        dict.fromkeys(blocker for blockers in [*phase_blockers.values(), *layer_blockers.values()] for blocker in blockers)
    )
    hard_blockers = list(dict.fromkeys([*missing_gate_ids, *missing_external_gate_blockers, *item_blockers]))
    if has_progress_gaps:
        hard_blockers.append("local_progress_gaps_require_verified_evidence_for_each_phase_and_layer")
    status = "ready_for_100_percent_review"
    if hard_blockers:
        status = "blocked_external_gates"
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


def project_progress_completion_surface_contract_payload() -> dict[str, object]:
    completion = project_progress_completion_payload()
    return {
        "contract_version": PROGRESS_COMPLETION_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/project/progress/completion",
        "runtime_contract_version": completion["contract_version"],
        "evidence_ref": PROGRESS_COMPLETION_SURFACE_EVIDENCE_REF,
        "visibility_endpoints": [
            "/api/v1/project/progress",
            "/api/v1/project/progress/integrity",
            "/api/v1/project/progress/completion",
            "/api/v1/external-gates",
        ],
        "required_top_level_fields": [
            "contract_version",
            "status",
            "requested_target_percent",
            "current_overall_percent",
            "can_set_all_to_100",
            "truth_policy",
            "hard_blockers",
            "phase_completion",
            "layer_completion",
        ],
        "expected_statuses": [
            "ready_for_100_percent_review",
            "blocked_external_gates",
        ],
        "required_hard_blockers": [
            "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer",
        ],
        "non_claims": completion["non_claims"],
    }


@app.on_event("startup")
def startup() -> None:
    # DB-optional boot: on a free/hostless deploy there may be no managed
    # Postgres/Redis. The read/contract/organism/clouds/inventory/metrics
    # surfaces need no DB, so the app must still come up — DB-backed actions
    # degrade honestly (their own connect() raises a clear 5xx) instead of
    # crashing the whole process at startup.
    app.state.applied_migrations = []
    app.state.db_available = False
    app.state.db_error = None
    if not os.getenv("DATABASE_URL"):
        app.state.db_error = "DATABASE_URL unset (degraded: DB-backed actions unavailable)"
        return
    try:
        app.state.applied_migrations = run_migrations()
        ensure_postgres_checkpointer()
        app.state.db_available = True
    except Exception as exc:  # noqa: BLE001 — never let DB outage block liveness
        app.state.db_error = f"{type(exc).__name__}: {exc}"


@app.get("/api/v1/project/progress")
def project_progress() -> dict[str, object]:
    return project_progress_payload()


@app.get("/api/v1/project/progress/contract")
def project_progress_contract() -> dict[str, object]:
    return project_progress_surface_contract_payload()


@app.get("/api/v1/project/progress/integrity")
def project_progress_integrity() -> dict[str, object]:
    return project_progress_integrity_payload()


@app.get("/api/v1/project/progress/integrity/contract")
def project_progress_integrity_contract() -> dict[str, object]:
    return project_progress_integrity_surface_contract_payload()


@app.get("/api/v1/project/progress/layers")
def project_progress_layers() -> dict[str, object]:
    return project_progress_layers_payload()


@app.get("/api/v1/project/progress/layers/contract")
def project_progress_layers_contract() -> dict[str, object]:
    return project_progress_layers_surface_contract_payload()


@app.get("/api/v1/project/progress/completion")
def project_progress_completion() -> dict[str, object]:
    return project_progress_completion_payload()


@app.get("/api/v1/project/progress/completion/contract")
def project_progress_completion_contract() -> dict[str, object]:
    return project_progress_completion_surface_contract_payload()


def cloud_render_offload_state() -> dict[str, object]:
    required_env = [
        "STAGING_BASE_URL",
        "AGENT_API_BASE_URL",
        "MCP_GATEWAY_BASE_URL",
        "LLM_GATEWAY_BASE_URL",
        "FLY_API_TOKEN",
    ]
    optional_env = [
        "VERCEL_TOKEN",
        "CLOUDFLARE_API_TOKEN",
        "GITHUB_TOKEN",
        "GHCR_TOKEN",
        "GRAFANA_CLOUD_API_KEY",
        "GRAFANA_CLOUD_URL",
    ]
    env_status = [{"key": key, "configured": bool(os.getenv(key))} for key in [*required_env, *optional_env]]
    missing_required = [key for key in required_env if not os.getenv(key)]
    blockers = [f"cloud_render_offload_requires_{key}" for key in missing_required]
    return {
        "contract_version": CLOUD_RENDER_OFFLOAD_CONTRACT_VERSION,
        "status": "cloud_runtime_ready" if not blockers else "action_required",
        "endpoint": "GET /api/v1/clouds/render-offload",
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
                "id": "fly_runtime_budget",
                "required_env": "FLY_API_TOKEN",
                "configured": bool(os.getenv("FLY_API_TOKEN")),
                "evidence_ref": "fly_live_budget_check",
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
            "Cloud render offload does not bypass the Vercel/Fly.io/GHCR/Grafana Cloud budget guard.",
            "The cloud-only staging verifier remains the release gate for hosted frontend/API/MCP/LLM proof.",
        ],
        "non_claims": [
            "This contract does not start cloud servers.",
            "This contract does not claim production deployment.",
            "This contract does not claim live LLM provider calls.",
            "This contract does not store or return provider token values.",
        ],
    }


def cloud_render_offload_contract_payload() -> dict[str, object]:
    state = cloud_render_offload_state()
    return {
        "contract_version": "cloud-render-offload-surface-v1",
        "mode": "cloud_render_offload_runtime_surface_contract",
        "endpoint": "GET /api/v1/clouds/render-offload/contract",
        "runtime_endpoint": "GET /api/v1/clouds/render-offload",
        "runtime_contract_version": state.get("contract_version"),
        "required_top_level_fields": [
            "status",
            "localhost_role",
            "localhost_heavy_render_allowed",
            "home_pc_protection",
            "required_env",
            "optional_env",
            "env_status",
            "missing_required_env",
            "blockers",
            "cloud_gates",
            "workloads",
            "policy_checks",
            "non_claims",
        ],
        "required_gate_fields": [
            "id",
            "required_env",
            "configured",
            "evidence_ref",
        ],
        "required_workload_fields": [
            "id",
            "label",
            "local_allowed",
            "required_runtime",
            "blocker",
        ],
        "required_gate_ids": [str(item.get("id")) for item in state.get("cloud_gates", []) if isinstance(item, dict)],
        "required_workload_ids": [str(item.get("id")) for item in state.get("workloads", []) if isinstance(item, dict)],
        "supported_statuses": ["cloud_runtime_ready", "action_required"],
        "expected_runtime_contract_version": state.get("contract_version"),
        "expected_runtime_endpoint": state.get("endpoint"),
        "evidence_ref": "cloud_render_offload_contract_runtime_visible",
        "policy_checks": list(state.get("policy_checks", [])),
        "non_claims": list(state.get("non_claims", [])),
    }


def phase6_3d_camera_lighting_runtime_contract_payload() -> dict[str, object]:
    scenarios = [
        {
            "scenario": "camera_preset_switch_visible",
            "decision": "switch_browser_local_camera_rig_between_wide_close_top",
            "evidence_ref": "phase6_camera_preset_switch_visible",
        },
        {
            "scenario": "fov_step_control_visible",
            "decision": "adjust_safe_fov_steps_without_network_or_provider_call",
            "evidence_ref": "phase6_fov_step_control_visible",
        },
        {
            "scenario": "lighting_profile_switch_visible",
            "decision": "switch_local_lighting_profiles_with_bounded_intensity",
            "evidence_ref": "phase6_lighting_profile_switch_visible",
        },
        {
            "scenario": "safe_exposure_bounds_visible",
            "decision": "keep_exposure_state_inside_safe_local_bounds",
            "evidence_ref": "phase6_safe_exposure_bounds_visible",
        },
        {
            "scenario": "camera_lighting_state_overlay_visible",
            "decision": "surface_applied_camera_lighting_state_in_hud",
            "evidence_ref": "phase6_camera_lighting_state_overlay_visible",
        },
        {
            "scenario": "local_camera_lighting_state_only",
            "decision": "keep_camera_lighting_state_in_browser_memory_only",
            "evidence_ref": "phase6_local_camera_lighting_state_only",
        },
        {
            "scenario": "cloud_render_boundary_still_closed",
            "decision": "keep_proof_inside_lightweight_client_render",
            "evidence_ref": CLOUD_RENDER_OFFLOAD_EVIDENCE_REF,
        },
        {
            "scenario": "phase6_progress_gate_bound_to_camera_lighting_verifier",
            "decision": "raise_phase6_only_after_camera_lighting_browser_and_manifest_proof",
            "evidence_ref": "phase6_camera_lighting_progress_gate_visible",
        },
    ]
    guarded_scenarios = [
        {
            **scenario,
            "local_model_downloads": False,
            "external_asset_fetch": False,
            "shader_hotload_started": False,
            "server_side_gpu_started": False,
            "heavy_local_render_allowed": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
            "pass": True,
        }
        for scenario in scenarios
    ]
    return {
        "contract_version": PHASE6_3D_CAMERA_LIGHTING_CONTRACT_VERSION,
        "mode": "phase6_lightweight_threejs_camera_lighting_runtime_contract",
        "endpoint": "GET /api/v1/phase6/3d-camera-lighting/contract",
        "frontend_surface": "Organism 3D camera and lighting controls",
        "evidence_ref": PHASE6_3D_CAMERA_LIGHTING_EVIDENCE_REF,
        "client_runtime_evidence_ref": "phase6_3d_client_runtime_visible",
        "interaction_runtime_evidence_ref": "phase6_3d_interaction_runtime_visible",
        "scene_state_runtime_evidence_ref": "phase6_3d_scene_state_runtime_visible",
        "performance_budget_evidence_ref": "phase6_3d_performance_budget_runtime_visible",
        "cloud_render_offload_evidence_ref": CLOUD_RENDER_OFFLOAD_EVIDENCE_REF,
        "camera_lighting_strategy": "local_camera_rig_lighting_profile_state",
        "camera_presets": [
            {"id": "wide", "position": [0.0, 0.6, 7.0], "target": [0.0, 0.0, 0.0]},
            {"id": "close", "position": [0.0, 0.35, 5.0], "target": [0.0, 0.0, 0.0]},
            {"id": "top", "position": [0.2, 6.8, 1.4], "target": [0.0, 0.0, 0.0]},
        ],
        "lighting_profiles": [
            {"id": "studio", "default_exposure": 1.0, "bounded_intensity": True},
            {"id": "night", "default_exposure": 0.82, "bounded_intensity": True},
            {"id": "sunrise", "default_exposure": 1.12, "bounded_intensity": True},
        ],
        "safe_fov_degrees": [38, 45, 58],
        "safe_exposure_range": {"min": 0.72, "max": 1.18, "step": 0.02},
        "camera_preset_controls_required": True,
        "fov_step_controls_required": True,
        "lighting_profile_controls_required": True,
        "safe_exposure_bounds_required": True,
        "state_overlay_required": True,
        "applied_runtime_state_attributes_required": True,
        "local_camera_lighting_state_only_required": True,
        "localhost_heavy_render_allowed": False,
        "server_side_gpu_required": False,
        "shader_hotload_allowed": False,
        "external_asset_fetch_allowed": False,
        "network_calls_required": False,
        "phase6_progress_after_proof": 40,
        "phase6_progress_status_marker": "phase6_3d_camera_lighting_runtime_visible-camera_lighting_controls_verified",
        "scenario_count": len(guarded_scenarios),
        "pass_count": len(guarded_scenarios),
        "all_scenarios_pass": True,
        "scenarios": guarded_scenarios,
        "guard_policy": {
            "local_model_downloads": False,
            "external_asset_fetch": False,
            "shader_hotload_started": False,
            "server_side_gpu_started": False,
            "heavy_local_render_allowed": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
        },
        "browser_proof_requirements": [
            "three camera preset controls are visible and applied",
            "safe FOV step control is visible and applied",
            "three lighting profiles are visible and applied",
            "exposure remains between 0.72 and 1.18",
            "applied camera and lighting state is visible in the runtime overlay",
            "camera and lighting state remains browser-local",
        ],
        "non_claims": [
            "No shader hotload or external asset fetch is performed.",
            "No server-side GPU or heavy local render workload is started.",
            "No provider write, live MCP write, live provider call, production deployment, secret output, or release promotion is performed.",
            "Localhost proof remains DEV-ONLY and is not hosted staging proof.",
        ],
    }


def phase6_3d_gameplay_state_runtime_contract_payload() -> dict[str, object]:
    scenarios = [
        {
            "scenario": "objective_state_overlay_visible",
            "decision": "surface_current_objective_state_in_browser_hud",
            "evidence_ref": "phase6_objective_state_overlay_visible",
        },
        {
            "scenario": "local_score_counter_visible",
            "decision": "increment_score_counter_in_browser_memory_only",
            "evidence_ref": "phase6_local_score_counter_visible",
        },
        {
            "scenario": "checkpoint_counter_visible",
            "decision": "increment_checkpoint_counter_without_network_sync",
            "evidence_ref": "phase6_checkpoint_counter_visible",
        },
        {
            "scenario": "deterministic_gameplay_state_machine",
            "decision": "cycle_collect_checkpoint_survive_objectives_locally",
            "evidence_ref": "phase6_deterministic_gameplay_state_machine_visible",
        },
        {
            "scenario": "pause_safe_game_loop_state",
            "decision": "keep_gameplay_loop_pause_safe_and_replayable",
            "evidence_ref": "phase6_pause_safe_game_loop_state_visible",
        },
        {
            "scenario": "input_event_binding_reused",
            "decision": "reuse_existing_pointer_keyboard_input_without_new_network_path",
            "evidence_ref": "phase6_input_event_binding_reused_visible",
        },
        {
            "scenario": "local_gameplay_state_only",
            "decision": "keep_gameplay_state_in_browser_memory_only",
            "evidence_ref": "phase6_local_gameplay_state_only",
        },
        {
            "scenario": "phase6_progress_gate_bound_to_gameplay_state_verifier",
            "decision": "raise_phase6_only_after_gameplay_state_browser_and_manifest_proof",
            "evidence_ref": "phase6_gameplay_state_progress_gate_visible",
        },
    ]
    guarded_scenarios = [
        {
            **scenario,
            "local_model_downloads": False,
            "multiplayer_netcode_started": False,
            "server_authoritative_sync_started": False,
            "physics_engine_started": False,
            "external_asset_fetch": False,
            "server_side_gpu_started": False,
            "heavy_local_render_allowed": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
            "pass": True,
        }
        for scenario in scenarios
    ]
    return {
        "contract_version": PHASE6_3D_GAMEPLAY_STATE_CONTRACT_VERSION,
        "mode": "phase6_lightweight_threejs_gameplay_state_runtime_contract",
        "endpoint": "GET /api/v1/phase6/3d-gameplay-state/contract",
        "frontend_surface": "Organism 3D gameplay state controls",
        "evidence_ref": PHASE6_3D_GAMEPLAY_STATE_EVIDENCE_REF,
        "client_runtime_evidence_ref": "phase6_3d_client_runtime_visible",
        "interaction_runtime_evidence_ref": "phase6_3d_interaction_runtime_visible",
        "scene_state_runtime_evidence_ref": "phase6_3d_scene_state_runtime_visible",
        "performance_budget_evidence_ref": "phase6_3d_performance_budget_runtime_visible",
        "camera_lighting_evidence_ref": PHASE6_3D_CAMERA_LIGHTING_EVIDENCE_REF,
        "cloud_render_offload_evidence_ref": CLOUD_RENDER_OFFLOAD_EVIDENCE_REF,
        "gameplay_state_strategy": "local_objective_score_checkpoint_state_machine",
        "objectives": ["collect", "checkpoint", "survive"],
        "objective_transitions": {
            "collect": {"next": "checkpoint", "score_delta": 10, "checkpoint_delta": 0},
            "checkpoint": {"next": "survive", "score_delta": 0, "checkpoint_delta": 1},
            "survive": {"next": "collect", "score_delta": 10, "checkpoint_delta": 0},
        },
        "score_increment": 10,
        "checkpoint_increment": 1,
        "loop_interval_ms": 1000,
        "objective_overlay_required": True,
        "score_counter_required": True,
        "checkpoint_counter_required": True,
        "pause_safe_loop_required": True,
        "local_gameplay_state_only_required": True,
        "input_binding_reuse_required": True,
        "applied_runtime_state_attributes_required": True,
        "localhost_heavy_render_allowed": False,
        "server_side_gpu_required": False,
        "multiplayer_netcode_allowed": False,
        "server_authoritative_sync_allowed": False,
        "physics_engine_required": False,
        "external_asset_fetch_allowed": False,
        "network_calls_required": False,
        "phase6_progress_after_proof": 48,
        "phase6_progress_status_marker": "phase6_3d_gameplay_state_runtime_visible-gameplay_state_controls_verified",
        "scenario_count": len(guarded_scenarios),
        "pass_count": len(guarded_scenarios),
        "all_scenarios_pass": True,
        "scenarios": guarded_scenarios,
        "guard_policy": {
            "local_model_downloads": False,
            "multiplayer_netcode_started": False,
            "server_authoritative_sync_started": False,
            "physics_engine_started": False,
            "external_asset_fetch": False,
            "server_side_gpu_started": False,
            "heavy_local_render_allowed": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
        },
        "browser_proof_requirements": [
            "objective, score, checkpoint, completion, input, and loop state are visible",
            "collect, checkpoint, and survive transitions are deterministic",
            "the gameplay tick stops while paused and resumes afterward",
            "button and keyboard input use the same state transition",
            "applied gameplay state is visible on the 3D runtime wrapper",
            "gameplay state remains browser-local without network requests",
        ],
        "non_claims": [
            "No multiplayer, netcode, server-authoritative synchronization, or physics engine is claimed.",
            "No external asset fetch, server-side GPU, or heavy local render workload is started.",
            "No provider write, live MCP write, live provider call, production deployment, secret output, or release promotion is performed.",
            "Localhost proof remains DEV-ONLY and is not hosted staging proof.",
        ],
    }


def phase6_3d_asset_policy_runtime_contract_payload() -> dict[str, object]:
    scenarios = [
        {
            "scenario": "procedural_asset_catalog_visible",
            "decision": "surface_local_procedural_primitive_asset_catalog",
            "evidence_ref": "phase6_procedural_asset_catalog_visible",
        },
        {
            "scenario": "asset_profile_switch_visible",
            "decision": "switch_browser_local_asset_profile_without_fetch",
            "evidence_ref": "phase6_asset_profile_switch_visible",
        },
        {
            "scenario": "material_policy_variant_visible",
            "decision": "switch_material_policy_variant_from_local_allowlist",
            "evidence_ref": "phase6_material_policy_variant_visible",
        },
        {
            "scenario": "local_asset_manifest_visible",
            "decision": "show_sanitized_local_asset_manifest_counts_only",
            "evidence_ref": "phase6_local_asset_manifest_visible",
        },
        {
            "scenario": "external_asset_fetch_blocked",
            "decision": "block_remote_asset_fetch_and_cdn_loading",
            "evidence_ref": "phase6_external_asset_fetch_blocked",
        },
        {
            "scenario": "binary_asset_upload_blocked",
            "decision": "block_binary_asset_upload_and_asset_pipeline_start",
            "evidence_ref": "phase6_binary_asset_upload_blocked",
        },
        {
            "scenario": "local_asset_policy_only",
            "decision": "keep_asset_policy_state_in_browser_memory_only",
            "evidence_ref": "phase6_local_asset_policy_only",
        },
        {
            "scenario": "phase6_progress_gate_bound_to_asset_policy_verifier",
            "decision": "raise_phase6_only_after_asset_policy_browser_and_manifest_proof",
            "evidence_ref": "phase6_asset_policy_progress_gate_visible",
        },
    ]
    guarded_scenarios = [
        {
            **scenario,
            "local_model_downloads": False,
            "external_asset_fetch": False,
            "binary_asset_upload": False,
            "remote_cdn_fetch": False,
            "asset_pipeline_service_started": False,
            "server_side_gpu_started": False,
            "heavy_local_render_allowed": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
            "pass": True,
        }
        for scenario in scenarios
    ]
    return {
        "contract_version": PHASE6_3D_ASSET_POLICY_CONTRACT_VERSION,
        "mode": "phase6_lightweight_threejs_asset_policy_runtime_contract",
        "endpoint": "GET /api/v1/phase6/3d-asset-policy/contract",
        "frontend_surface": "Organism 3D procedural asset policy controls",
        "evidence_ref": PHASE6_3D_ASSET_POLICY_EVIDENCE_REF,
        "client_runtime_evidence_ref": "phase6_3d_client_runtime_visible",
        "interaction_runtime_evidence_ref": "phase6_3d_interaction_runtime_visible",
        "scene_state_runtime_evidence_ref": "phase6_3d_scene_state_runtime_visible",
        "performance_budget_evidence_ref": "phase6_3d_performance_budget_runtime_visible",
        "camera_lighting_evidence_ref": PHASE6_3D_CAMERA_LIGHTING_EVIDENCE_REF,
        "gameplay_state_evidence_ref": PHASE6_3D_GAMEPLAY_STATE_EVIDENCE_REF,
        "cloud_render_offload_evidence_ref": CLOUD_RENDER_OFFLOAD_EVIDENCE_REF,
        "asset_policy_strategy": "local_procedural_primitive_asset_catalog",
        "asset_profiles": [
            {"id": "cube", "geometry": "boxGeometry", "source": "procedural"},
            {"id": "beacon", "geometry": "coneGeometry", "source": "procedural"},
            {"id": "ring", "geometry": "torusGeometry", "source": "procedural"},
        ],
        "material_variants": [
            {"id": "cyan", "color": "#00e5ff", "source": "allowlist"},
            {"id": "amber", "color": "#f59e0b", "source": "allowlist"},
            {"id": "rose", "color": "#fb7185", "source": "allowlist"},
        ],
        "asset_catalog_count": 3,
        "material_variant_count": 3,
        "remote_asset_count": 0,
        "uploaded_asset_count": 0,
        "asset_policy_overlay_required": True,
        "procedural_primitives_only_required": True,
        "local_asset_manifest_only_required": True,
        "applied_runtime_state_attributes_required": True,
        "localhost_heavy_render_allowed": False,
        "server_side_gpu_required": False,
        "external_asset_fetch_allowed": False,
        "binary_asset_upload_allowed": False,
        "remote_cdn_allowed": False,
        "asset_pipeline_service_started": False,
        "network_calls_required": False,
        "phase6_progress_after_proof": 56,
        "phase6_progress_status_marker": "phase6_3d_asset_policy_runtime_visible-asset_policy_controls_verified",
        "scenario_count": len(guarded_scenarios),
        "pass_count": len(guarded_scenarios),
        "all_scenarios_pass": True,
        "scenarios": guarded_scenarios,
        "guard_policy": {
            "local_model_downloads": False,
            "external_asset_fetch": False,
            "binary_asset_upload": False,
            "remote_cdn_fetch": False,
            "asset_pipeline_service_started": False,
            "server_side_gpu_started": False,
            "heavy_local_render_allowed": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
        },
        "browser_proof_requirements": [
            "three procedural asset profiles are visible and applied",
            "three allowlisted material variants are visible and applied",
            "sanitized local manifest counts are visible",
            "applied asset policy state is visible on the Three.js runtime wrapper",
            "external fetch, remote CDN, binary upload, and pipeline startup stay blocked",
            "asset policy interactions perform no network requests",
        ],
        "non_claims": [
            "No external asset fetch, binary upload, remote CDN path, or asset pipeline service is started.",
            "No server-side GPU or heavy local render workload is started.",
            "No provider write, live MCP write, live provider call, production deployment, secret output, or release promotion is performed.",
            "Localhost proof remains DEV-ONLY and is not hosted staging proof.",
        ],
    }


def phase6_3d_save_load_runtime_contract_payload() -> dict[str, object]:
    scenarios = [
        {
            "scenario": "scene_snapshot_capture_visible",
            "decision": "capture_allowlisted_scene_state_in_react_memory",
            "evidence_ref": "phase6_scene_snapshot_capture_visible",
        },
        {
            "scenario": "scene_snapshot_restore_visible",
            "decision": "restore_allowlisted_scene_state_without_network_sync",
            "evidence_ref": "phase6_scene_snapshot_restore_visible",
        },
        {
            "scenario": "scene_snapshot_clear_visible",
            "decision": "clear_volatile_snapshot_without_mutating_restored_scene",
            "evidence_ref": "phase6_scene_snapshot_clear_visible",
        },
        {
            "scenario": "load_without_snapshot_blocked",
            "decision": "disable_restore_until_a_valid_browser_memory_snapshot_exists",
            "evidence_ref": "phase6_load_without_snapshot_blocked",
        },
        {
            "scenario": "volatile_browser_memory_only",
            "decision": "discard_snapshot_on_page_reload_or_unmount",
            "evidence_ref": "phase6_volatile_browser_memory_only",
        },
        {
            "scenario": "persistent_browser_storage_blocked",
            "decision": "block_local_storage_indexeddb_cookie_and_cache_persistence",
            "evidence_ref": "phase6_persistent_browser_storage_blocked",
        },
        {
            "scenario": "cloud_save_sync_blocked",
            "decision": "block_cloud_sync_upload_and_server_snapshot_write",
            "evidence_ref": "phase6_cloud_save_sync_blocked",
        },
        {
            "scenario": "phase6_progress_gate_bound_to_save_load_verifier",
            "decision": "raise_phase6_only_after_save_load_browser_and_manifest_proof",
            "evidence_ref": "phase6_save_load_progress_gate_visible",
        },
    ]
    guarded_scenarios = [
        {
            **scenario,
            "local_storage_write": False,
            "indexeddb_write": False,
            "cookie_write": False,
            "service_worker_cache_write": False,
            "cloud_save_sync": False,
            "binary_snapshot_upload": False,
            "server_snapshot_write": False,
            "network_calls": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
            "pass": True,
        }
        for scenario in scenarios
    ]
    snapshot_fields = [
        "auto_rotate",
        "reduced_motion",
        "camera_preset",
        "fov_degrees",
        "lighting_profile",
        "exposure",
        "gameplay_objective",
        "gameplay_score",
        "gameplay_checkpoints",
        "gameplay_completions",
        "gameplay_input_events",
        "gameplay_ticks",
        "gameplay_paused",
        "asset_profile",
        "material_variant",
    ]
    return {
        "contract_version": PHASE6_3D_SAVE_LOAD_CONTRACT_VERSION,
        "mode": "phase6_volatile_browser_memory_scene_snapshot_contract",
        "endpoint": "GET /api/v1/phase6/3d-save-load/contract",
        "frontend_surface": "Organism 3D volatile save and load controls",
        "evidence_ref": PHASE6_3D_SAVE_LOAD_EVIDENCE_REF,
        "asset_policy_evidence_ref": PHASE6_3D_ASSET_POLICY_EVIDENCE_REF,
        "save_load_strategy": "typed_allowlisted_react_state_snapshot",
        "snapshot_fields": snapshot_fields,
        "snapshot_field_count": len(snapshot_fields),
        "snapshot_slots": 1,
        "capture_required": True,
        "restore_required": True,
        "clear_required": True,
        "load_disabled_without_snapshot_required": True,
        "volatile_browser_memory_only_required": True,
        "snapshot_discarded_on_reload_required": True,
        "local_storage_allowed": False,
        "indexeddb_allowed": False,
        "cookie_persistence_allowed": False,
        "service_worker_cache_allowed": False,
        "cloud_save_sync_allowed": False,
        "binary_snapshot_upload_allowed": False,
        "server_snapshot_write_allowed": False,
        "network_calls_required": False,
        "phase6_progress_after_proof": 64,
        "phase6_progress_status_marker": "phase6_3d_save_load_runtime_visible-browser_memory_snapshot_restore_verified",
        "scenario_count": len(guarded_scenarios),
        "pass_count": len(guarded_scenarios),
        "all_scenarios_pass": True,
        "scenarios": guarded_scenarios,
        "guard_policy": {
            "local_storage_write": False,
            "indexeddb_write": False,
            "cookie_write": False,
            "service_worker_cache_write": False,
            "cloud_save_sync": False,
            "binary_snapshot_upload": False,
            "server_snapshot_write": False,
            "network_calls": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
        },
        "browser_proof_requirements": [
            "load is disabled before capture and after clear",
            "all fifteen allowlisted state fields are captured",
            "mutated camera, lighting, gameplay, and asset state is restored",
            "restored state is reflected by visible controls and Three.js runtime attributes",
            "snapshot state disappears after page reload",
            "save, load, and clear perform no network requests or persistent browser writes",
        ],
        "non_claims": [
            "No LocalStorage, IndexedDB, cookie, service-worker cache, cloud sync, upload, or server snapshot write is performed.",
            "No provider write, live MCP write, live provider call, production deployment, secret output, or release promotion is performed.",
            "Localhost proof remains DEV-ONLY and is not hosted staging proof.",
        ],
    }


def phase6_3d_accessibility_runtime_contract_payload() -> dict[str, object]:
    scenarios = [
        {
            "scenario": "manual_reduced_motion_toggle_visible",
            "decision": "switch_between_3d_and_static_2d_with_pressed_state",
            "evidence_ref": "phase6_manual_reduced_motion_toggle_visible",
        },
        {
            "scenario": "system_reduced_motion_preference_honored",
            "decision": "observe_prefers_reduced_motion_and_force_static_2d",
            "evidence_ref": "phase6_system_reduced_motion_preference_honored",
        },
        {
            "scenario": "semantic_2d_fallback_region_visible",
            "decision": "expose_named_region_and_described_static_topology",
            "evidence_ref": "phase6_semantic_2d_fallback_region_visible",
        },
        {
            "scenario": "keyboard_fallback_navigation_visible",
            "decision": "navigate_fallback_items_with_arrow_home_end_and_enter",
            "evidence_ref": "phase6_keyboard_fallback_navigation_visible",
        },
        {
            "scenario": "focus_visible_and_programmatic_focus_visible",
            "decision": "retain_global_focus_ring_and_scene_focus_command",
            "evidence_ref": "phase6_focus_visible_visible",
        },
        {
            "scenario": "accessible_status_live_region_visible",
            "decision": "announce_motion_render_and_focus_state_without_audio_service",
            "evidence_ref": "phase6_accessible_status_live_region_visible",
        },
        {
            "scenario": "accessibility_local_only",
            "decision": "keep_accessibility_preferences_and_announcements_in_browser_state",
            "evidence_ref": "phase6_accessibility_local_only",
        },
        {
            "scenario": "phase6_progress_gate_bound_to_accessibility_verifier",
            "decision": "raise_phase6_only_after_accessibility_browser_and_manifest_proof",
            "evidence_ref": "phase6_accessibility_progress_gate_visible",
        },
    ]
    guarded_scenarios = [
        {
            **scenario,
            "speech_service_started": False,
            "accessibility_telemetry_export": False,
            "persistent_preference_write": False,
            "network_calls": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
            "pass": True,
        }
        for scenario in scenarios
    ]
    return {
        "contract_version": PHASE6_3D_ACCESSIBILITY_CONTRACT_VERSION,
        "mode": "phase6_accessible_reduced_motion_2d_fallback_contract",
        "endpoint": "GET /api/v1/phase6/3d-accessibility/contract",
        "frontend_surface": "Organism accessibility and reduced-motion controls",
        "evidence_ref": PHASE6_3D_ACCESSIBILITY_EVIDENCE_REF,
        "save_load_evidence_ref": PHASE6_3D_SAVE_LOAD_EVIDENCE_REF,
        "accessibility_strategy": "system_aware_reduced_motion_semantic_keyboard_fallback",
        "manual_reduced_motion_toggle_required": True,
        "system_preference_detection_required": True,
        "static_2d_fallback_required": True,
        "semantic_region_required": True,
        "keyboard_navigation_keys": ["ArrowDown", "ArrowRight", "ArrowUp", "ArrowLeft", "Home", "End", "Enter", "Space"],
        "programmatic_scene_focus_required": True,
        "global_focus_visible_required": True,
        "aria_pressed_state_required": True,
        "aria_controls_required": True,
        "live_status_region_required": True,
        "accessible_item_count": 10,
        "browser_local_preference_only_required": True,
        "speech_service_required": False,
        "accessibility_telemetry_export_allowed": False,
        "persistent_preference_write_allowed": False,
        "network_calls_required": False,
        "phase6_progress_after_proof": 72,
        "phase6_progress_status_marker": "phase6_3d_accessibility_runtime_visible-reduced_motion_keyboard_focus_verified",
        "scenario_count": len(guarded_scenarios),
        "pass_count": len(guarded_scenarios),
        "all_scenarios_pass": True,
        "scenarios": guarded_scenarios,
        "guard_policy": {
            "speech_service_started": False,
            "accessibility_telemetry_export": False,
            "persistent_preference_write": False,
            "network_calls": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
        },
        "browser_proof_requirements": [
            "manual reduced-motion toggle exposes pressed and controls relationships",
            "prefers-reduced-motion forces the semantic 2D fallback",
            "the fallback exposes ten named focusable topology items",
            "arrow, Home, End, Enter, and Space keyboard behavior is deterministic",
            "scene focus command and global focus-visible ring remain observable",
            "motion and render status is exposed through a polite live region",
            "accessibility controls perform no network requests",
        ],
        "non_claims": [
            "No external speech, telemetry, preference persistence, or accessibility provider service is started.",
            "No provider write, live MCP write, live provider call, production deployment, secret output, or release promotion is performed.",
            "Localhost proof remains DEV-ONLY and is not hosted staging proof.",
        ],
    }


def phase6_3d_netcode_loopback_runtime_contract_payload() -> dict[str, object]:
    scenarios = [
        {"scenario": "loopback_session_lifecycle_visible", "decision": "create_and_close_one_browser_memory_session", "evidence_ref": "phase6_loopback_session_lifecycle_visible"},
        {"scenario": "two_peer_join_leave_visible", "decision": "join_and_disconnect_one_deterministic_guest", "evidence_ref": "phase6_two_peer_join_leave_visible"},
        {"scenario": "two_peer_ready_barrier_visible", "decision": "start_only_after_host_and_guest_are_ready", "evidence_ref": "phase6_two_peer_ready_barrier_visible"},
        {"scenario": "deterministic_lockstep_tick_visible", "decision": "advance_one_tick_and_two_packets_per_manual_step", "evidence_ref": "phase6_deterministic_lockstep_tick_visible"},
        {"scenario": "monotonic_packet_sequence_visible", "decision": "increase_sequence_without_duplicates_or_reordering", "evidence_ref": "phase6_monotonic_packet_sequence_visible"},
        {"scenario": "guest_disconnect_fail_closed_visible", "decision": "stop_lockstep_immediately_when_guest_disconnects", "evidence_ref": "phase6_guest_disconnect_fail_closed_visible"},
        {"scenario": "remote_transport_boundary_closed", "decision": "keep_websocket_webrtc_matchmaking_and_server_sync_disabled", "evidence_ref": "phase6_remote_transport_boundary_closed"},
        {"scenario": "phase6_progress_gate_bound_to_netcode_verifier", "decision": "raise_phase6_only_after_loopback_browser_and_manifest_proof", "evidence_ref": "phase6_netcode_progress_gate_visible"},
    ]
    guarded = [
        {**scenario, "websocket_started": False, "webrtc_started": False, "matchmaking_started": False, "public_lobby_started": False, "server_authoritative_sync_started": False, "network_calls": False, "provider_write": False, "live_mcp_write": False, "production_deploy": False, "secret_values_returned": False, "release_promotion": False, "pass": True}
        for scenario in scenarios
    ]
    return {
        "contract_version": PHASE6_3D_NETCODE_CONTRACT_VERSION,
        "mode": "phase6_two_peer_browser_loopback_lockstep_contract",
        "endpoint": "GET /api/v1/phase6/3d-netcode/contract",
        "frontend_surface": "Organism deterministic multiplayer loopback controls",
        "evidence_ref": PHASE6_3D_NETCODE_EVIDENCE_REF,
        "accessibility_evidence_ref": PHASE6_3D_ACCESSIBILITY_EVIDENCE_REF,
        "netcode_strategy": "two_peer_manual_lockstep_browser_loopback",
        "transport": "loopback",
        "session_slots": 1,
        "maximum_peers": 2,
        "peer_ids": ["host", "guest"],
        "ready_barrier_required": True,
        "manual_lockstep_required": True,
        "packets_per_tick": 2,
        "sequence_monotonic_required": True,
        "disconnect_stops_simulation_required": True,
        "threejs_remote_peer_marker_required": True,
        "browser_memory_only_required": True,
        "websocket_allowed": False,
        "webrtc_allowed": False,
        "matchmaking_allowed": False,
        "public_lobby_allowed": False,
        "server_authoritative_sync_allowed": False,
        "network_calls_required": False,
        "phase6_progress_after_proof": 80,
        "phase6_progress_status_marker": "phase6_3d_netcode_loopback_runtime_visible-two_peer_lockstep_verified",
        "scenario_count": len(guarded),
        "pass_count": len(guarded),
        "all_scenarios_pass": True,
        "scenarios": guarded,
        "guard_policy": {"websocket_started": False, "webrtc_started": False, "matchmaking_started": False, "public_lobby_started": False, "server_authoritative_sync_started": False, "network_calls": False, "provider_write": False, "live_mcp_write": False, "production_deploy": False, "secret_values_returned": False, "release_promotion": False},
        "browser_proof_requirements": [
            "session create and close transitions are visible",
            "guest join increments peer count and sequence",
            "lockstep start remains disabled until both peers are ready",
            "each manual lockstep step increments tick by one, packets and sequence by two",
            "guest disconnect stops simulation and disables tick immediately",
            "the procedural remote peer marker mirrors connected and running state",
            "loopback controls perform no fetch or XHR requests",
        ],
        "non_claims": [
            "No WebSocket, WebRTC, matchmaking, public lobby, hosted relay, or server-authoritative synchronization is started.",
            "This is deterministic local loopback evidence, not hosted multiplayer capacity or production netcode proof.",
            "No provider write, live MCP write, deployment, secret output, or release promotion is performed.",
            "Localhost proof remains DEV-ONLY.",
        ],
    }


def phase6_local_scoreboard_performance_runtime_contract_payload() -> dict[str, object]:
    scenarios = [
        {"scenario": "volatile_top_three_runs_visible", "decision": "rank_at_most_three_captured_gameplay_runs_in_browser_memory", "evidence_ref": "phase6_local_leaderboard_runtime_visible"},
        {"scenario": "deterministic_score_ordering_visible", "decision": "sort_by_score_descending_then_completion_descending_then_capture_sequence_ascending", "evidence_ref": "phase6_deterministic_top3_ordering_verified"},
        {"scenario": "leaderboard_reset_visible", "decision": "clear_all_volatile_entries_without_persistent_or_network_write", "evidence_ref": "phase6_local_leaderboard_reset_verified"},
        {"scenario": "bounded_frame_sample_visible", "decision": "aggregate_existing_renderer_fps_and_frame_time_over_twelve_samples", "evidence_ref": "phase6_performance_sample_runtime_visible"},
        {"scenario": "frame_budget_result_visible", "decision": "classify_pass_only_when_average_fps_is_at_least_twenty_five_and_average_frame_time_is_at_most_forty_ms", "evidence_ref": "phase6_frame_budget_classification_verified"},
        {"scenario": "remote_score_sync_boundary_closed", "decision": "keep_leaderboard_sync_accounts_telemetry_and_persistent_storage_disabled", "evidence_ref": "phase6_leaderboard_sync_blocked"},
        {"scenario": "capacity_claim_boundary_closed", "decision": "treat_client_frame_sample_as_local_interaction_evidence_not_scale_capacity", "evidence_ref": "phase6_capacity_claim_blocked"},
        {"scenario": "phase6_progress_gate_bound_to_scoreboard_verifier", "decision": "raise_phase6_only_after_local_scoreboard_browser_and_manifest_proof", "evidence_ref": "phase6_local_scoreboard_progress_gate_visible"},
    ]
    guarded = [
        {
            **scenario,
            "leaderboard_sync_started": False,
            "persistent_storage_started": False,
            "telemetry_started": False,
            "network_calls": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
            "scale_capacity_claimed": False,
            "pass": True,
        }
        for scenario in scenarios
    ]
    return {
        "contract_version": PHASE6_LOCAL_SCOREBOARD_CONTRACT_VERSION,
        "mode": "phase6_volatile_scoreboard_bounded_frame_sample_contract",
        "endpoint": "GET /api/v1/phase6/local-scoreboard-performance/contract",
        "frontend_surface": "Organism local leaderboard and bounded performance sample controls",
        "evidence_ref": PHASE6_LOCAL_SCOREBOARD_EVIDENCE_REF,
        "netcode_evidence_ref": PHASE6_3D_NETCODE_EVIDENCE_REF,
        "leaderboard_scope": "volatile_browser_memory",
        "leaderboard_maximum_entries": 3,
        "leaderboard_sort_order": ["score_desc", "completions_desc", "capture_sequence_asc"],
        "leaderboard_entry_fields": ["capture_sequence", "score", "completions"],
        "leaderboard_user_input_fields": [],
        "score_source": "current_deterministic_gameplay_state",
        "performance_sample_source": "existing_threejs_renderer_stats",
        "performance_sample_count": 12,
        "performance_sample_cadence": "renderer_stats_update_approximately_500ms",
        "performance_aggregation": "arithmetic_mean_rounded_to_one_decimal",
        "performance_frame_interval_semantics": "derived_from_fps_not_independent_gpu_timing",
        "performance_invalid_sample_policy": "ignore_non_finite_zero_or_negative_samples",
        "performance_timeout_seconds": 10,
        "performance_timeout_result": "fail_renderer_inactive_timeout",
        "performance_restart_policy": "discard_previous_samples_and_restart_at_zero",
        "performance_minimum_fps": 25,
        "performance_maximum_frame_ms": 40,
        "performance_result_values": ["idle", "sampling", "pass", "fail"],
        "browser_memory_only_required": True,
        "leaderboard_sync_allowed": False,
        "persistent_storage_allowed": False,
        "account_identity_required": False,
        "telemetry_allowed": False,
        "network_calls_required": False,
        "scale_capacity_claim_allowed": False,
        "phase6_progress_after_proof": 90,
        "phase6_progress_status_marker": "phase6_local_scoreboard_performance_runtime_visible-local_top3_frame_sample_verified",
        "scenario_semantics": "static_policy_requirements_not_runtime_evidence",
        "runtime_browser_evidence_required": True,
        "scenario_count": len(guarded),
        "pass_count": len(guarded),
        "all_scenarios_pass": True,
        "scenarios": guarded,
        "guard_policy": {
            "leaderboard_sync_started": False,
            "persistent_storage_started": False,
            "telemetry_started": False,
            "network_calls": False,
            "provider_write": False,
            "live_mcp_write": False,
            "production_deploy": False,
            "secret_values_returned": False,
            "release_promotion": False,
            "scale_capacity_claimed": False,
        },
        "browser_proof_requirements": [
            "captured gameplay runs are ranked deterministically and capped at three entries",
            "leaderboard reset clears every volatile entry",
            "bounded performance sampling reaches a terminal pass or fail result from real renderer stats",
            "the sample result exposes count average fps average frame time and budget thresholds",
            "scoreboard and sampling controls perform no fetch XHR WebSocket or persistent browser write",
            "the Three.js canvas remains nonblank and browser console errors remain zero",
        ],
        "non_claims": [
            "No account-backed, remote, hosted, or production leaderboard synchronization is started.",
            "No LocalStorage, IndexedDB, cookie, cache, telemetry, provider, or server write is performed.",
            "The bounded client frame sample is interaction evidence, not scale, load, concurrency, capacity, or production performance proof.",
            "No provider write, live MCP write, deployment, secret output, or release promotion is performed.",
            "Localhost proof remains DEV-ONLY.",
        ],
    }


def cloud_deployment_preflight_state() -> dict[str, object]:
    def env_ready(keys: list[str]) -> bool:
        return all(bool(os.getenv(key)) for key in keys)

    verified_flags = external_gate_verification_flags(project_progress_payload())
    gates = [
        {
            "id": "ghcr_images",
            "label": "GHCR application images",
            "required_env": ["GITHUB_TOKEN", "GHCR_TOKEN"],
            "required_artifact": ".github/workflows/main-deploy.yml",
            "verifier": "scripts/verify-phase1.ps1",
            "environment_configured": env_ready(["GITHUB_TOKEN", "GHCR_TOKEN"]),
            "configured": verified_flags["ghcr_images"],
            "verified": verified_flags["ghcr_images"],
            "evidence_ref": "ghcr_image_digest_proof",
            "required_evidence_artifact": "published GHCR image digests for all six application services",
            "next_action": "dispatch_main_deploy_workflow_after_github_auth_is_repaired",
        },
        {
            "id": "fly_cloud_stack",
            "label": "Fly.io pull-based cloud stack",
            "required_env": ["FLY_API_TOKEN"],
            "required_artifact": "docker-compose.cloud.yml",
            "verifier": "scripts/check_fly_infra_budget.py",
            "environment_configured": env_ready(["FLY_API_TOKEN"]),
            "configured": verified_flags["fly_cloud_stack"],
            "verified": verified_flags["fly_cloud_stack"],
            "evidence_ref": "fly_live_budget_check",
            "required_evidence_artifact": "current Fly.io budget proof plus reachable cloud compose health checks",
            "next_action": "run_cloud_compose_pull_and_up_on_fly_host_with_environment_only_secrets",
        },
        {
            "id": "hosted_backend_origins",
            "label": "Vercel backend origin environment",
            "required_env": ["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"],
            "required_artifact": "docs/runbooks/cloud-secret-runtime-injection.md",
            "verifier": "scripts/verify-cloud-only-staging.ps1",
            "environment_configured": env_ready(["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"]),
            "configured": verified_flags["hosted_backend_origins"],
            "verified": verified_flags["hosted_backend_origins"],
            "evidence_ref": "hosted_backend_origin_env_required",
            "required_evidence_artifact": "cloud-only staging proof with hosted backend origin URLs",
            "next_action": "configure_vercel_backend_origin_urls_after_fly_stack_is_reachable",
        },
        {
            "id": "hosted_staging",
            "label": "Hosted staging proof URL",
            "required_env": ["STAGING_BASE_URL"],
            "required_artifact": ".github/workflows/hosted-staging-proof.yml",
            "verifier": "scripts/verify-hosted-staging.ps1",
            "environment_configured": env_ready(["STAGING_BASE_URL"]),
            "configured": verified_flags["hosted_staging"],
            "verified": verified_flags["hosted_staging"],
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
            "configured": verified_flags["branch_protection"],
            "verified": verified_flags["branch_protection"],
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
            "configured": verified_flags["canonical_secret_scan"],
            "verified": verified_flags["canonical_secret_scan"],
            "evidence_ref": "canonical_gitleaks_scan",
            "required_evidence_artifact": "current gitleaks scan artifact with no findings",
            "next_action": "install_or_use_gitleaks_before_release_claim",
        },
    ]
    missing_or_blocked = [gate["id"] for gate in gates if not gate["verified"]]
    preflight_ready = not missing_or_blocked
    production_gate_claim_allowed = verified_flags["production_gate_claim_allowed"]
    return {
        "contract_version": CLOUD_DEPLOYMENT_PREFLIGHT_CONTRACT_VERSION,
        "status": "verified" if production_gate_claim_allowed and preflight_ready else ("ready_for_external_execution" if preflight_ready else "action_required"),
        "endpoint": "GET /api/v1/clouds/deployment-preflight",
        "evidence_ref": CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF,
        "required_sequence": [
            "publish_ghcr_images",
            "start_fly_runtime_stack",
            "configure_vercel_backend_origins",
            "run_hosted_staging_verifier",
            "verify_branch_protection",
            "run_canonical_secret_scan",
            "owner_review_before_production",
        ],
        "gates": gates,
        "missing_or_blocked_gates": missing_or_blocked,
        "preflight_ready": preflight_ready,
        "external_execution_ready": preflight_ready,
        "cloud_deploy_claim_allowed": preflight_ready,
        "production_deploy_claim_allowed": production_gate_claim_allowed and preflight_ready,
        "localhost_role": "dev_control_plane_only",
        "manual_external_actions": [
            "gh workflow run main-deploy.yml",
            "fly deploy --remote-only",
            "fly status",
            "powershell -ExecutionPolicy Bypass -File scripts\\verify-hosted-staging.ps1",
            "py -3 scripts\\apply_github_branch_protection.py --verify-only",
            "gitleaks detect --no-git --source .",
        ],
        "claim_policy": "environment presence only never creates a cloud, hosted staging, or production deployment claim",
        "policy_checks": [
            "All secrets are referenced by environment variable name only.",
            "GHCR image publication, Fly.io runtime execution, Vercel env writes, and branch-protection writes remain external gated actions.",
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


def cloud_deployment_preflight_payload() -> dict[str, object]:
    state = cloud_deployment_preflight_state()
    return {
        "contract_version": "cloud-deployment-preflight-surface-v1",
        "mode": "cloud_deployment_preflight_runtime_surface_contract",
        "endpoint": "GET /api/v1/clouds/deployment-preflight/contract",
        "runtime_endpoint": "GET /api/v1/clouds/deployment-preflight",
        "runtime_contract_version": state.get("contract_version"),
        "required_top_level_fields": [
            "status",
            "required_sequence",
            "gates",
            "missing_or_blocked_gates",
            "preflight_ready",
            "external_execution_ready",
            "cloud_deploy_claim_allowed",
            "production_deploy_claim_allowed",
            "localhost_role",
            "manual_external_actions",
            "claim_policy",
            "policy_checks",
            "non_claims",
        ],
        "required_gate_fields": [
            "id",
            "label",
            "required_env",
            "required_artifact",
            "verifier",
            "environment_configured",
            "configured",
            "verified",
            "evidence_ref",
            "required_evidence_artifact",
            "next_action",
        ],
        "required_gate_ids": [str(item.get("id")) for item in state.get("gates", []) if isinstance(item, dict)],
        "supported_statuses": ["verified", "ready_for_external_execution", "action_required"],
        "expected_runtime_contract_version": state.get("contract_version"),
        "expected_runtime_endpoint": state.get("endpoint"),
        "evidence_ref": "cloud_deployment_preflight_contract_runtime_visible",
        "policy_checks": list(state.get("policy_checks", [])),
        "non_claims": list(state.get("non_claims", [])),
    }


def external_gate_summary_path() -> Path:
    configured = os.getenv("EXTERNAL_GATE_SUMMARY_PATH", "/app/progress/external-gate-summary.json")
    return Path(configured)


def external_gate_summary_state() -> dict[str, object]:
    path = external_gate_summary_path()
    if not path.exists():
        return {
            "contract_version": "external-gate-summary-v1",
            "source_contract_version": "external-gate-audit-v1",
            "source_artifact": "",
            "status": "missing_summary",
            "configured": False,
            "production_deploy_claim_allowed": False,
            "missing_or_failed_gates": [],
            "failed_hosted_required_probe_ids": [],
            "failed_vercel_origin_probe_ids": [],
            "non_claims": [
                "External gate summary is not mounted in this runtime.",
                "Hosted, production, branch-protection, Fly budget, and Vercel-origin claims remain blocked without a current external-gate audit summary.",
            ],
        }
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        return {
            "contract_version": "external-gate-summary-v1",
            "source_contract_version": "external-gate-audit-v1",
            "source_artifact": str(path),
            "status": "invalid_summary",
            "configured": True,
            "production_deploy_claim_allowed": False,
            "missing_or_failed_gates": ["external_gate_summary_invalid"],
            "failed_hosted_required_probe_ids": [],
            "failed_vercel_origin_probe_ids": [],
            "error": type(exc).__name__,
            "non_claims": [
                "External gate summary could not be parsed.",
                "Hosted, production, branch-protection, Fly budget, and Vercel-origin claims remain blocked.",
            ],
        }

    allowed_keys = {
        "contract_version",
        "source_contract_version",
        "source_artifact",
        "generated_at_utc",
        "status",
        "frontend_preview_claim_allowed",
        "hosted_staging_claim_allowed",
        "branch_protection_claim_allowed",
        "ghcr_image_digest_claim_allowed",
        "vercel_backend_origins_claim_allowed",
        "canonical_gitleaks_claim_allowed",
        "fly_live_budget_claim_allowed",
        "gitlab_identity_claim_allowed",
        "huggingface_identity_claim_allowed",
        "grafana_cloud_claim_allowed",
        "production_deploy_claim_allowed",
        "missing_or_failed_gates",
        "failed_hosted_required_probe_ids",
        "failed_vercel_origin_probe_ids",
        "non_claims",
    }
    sanitized = {key: payload.get(key) for key in allowed_keys if key in payload}
    sanitized["configured"] = True
    sanitized["source_path"] = str(path)
    sanitized["missing_or_failed_gates"] = [
        str(item) for item in sanitized.get("missing_or_failed_gates", []) if str(item).strip()
    ]
    sanitized["failed_hosted_required_probe_ids"] = [
        str(item) for item in sanitized.get("failed_hosted_required_probe_ids", []) if str(item).strip()
    ]
    sanitized["failed_vercel_origin_probe_ids"] = [
        str(item) for item in sanitized.get("failed_vercel_origin_probe_ids", []) if str(item).strip()
    ]
    return sanitized


def go_live_readiness_state() -> dict[str, object]:
    progress = project_progress_payload()
    completion = project_progress_completion_payload()
    external_gates = external_gate_state()
    preflight = cloud_deployment_preflight_state()
    cloud_layers = cloud_layer_readiness_state()
    workspace = workspace_wiring_payload()
    external_audit_summary = external_gate_summary_state()

    preflight_gates = [gate for gate in preflight.get("gates", []) if isinstance(gate, dict)]
    audit_missing_gates = [str(item) for item in external_audit_summary.get("missing_or_failed_gates", [])]
    audit_required_env_map = {
        "hosted_agent_api_contracts": ["STAGING_BASE_URL", "AGENT_API_BASE_URL"],
        "github_branch_protection_current_verify": ["BRANCH_PROTECTION_TOKEN"],
        "vercel_backend_origin_health": ["AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"],
        "fly_live_budget_check": ["FLY_API_TOKEN"],
    }
    audit_required_inputs = [
        env_name
        for gate_id in audit_missing_gates
        for env_name in audit_required_env_map.get(gate_id, [])
    ]
    required_owner_inputs = sorted({
        str(env_name)
        for gate in preflight_gates
        if not bool(gate.get("verified"))
        for env_name in gate.get("required_env", [])
        if str(env_name).strip()
    } | {str(env_name) for env_name in audit_required_inputs if str(env_name).strip()})
    missing_or_blocked_gates = [str(item) for item in preflight.get("missing_or_blocked_gates", [])]
    hard_blockers = [str(item) for item in completion.get("hard_blockers", [])]
    cloud_layer_items = [item for item in cloud_layers.get("layers", []) if isinstance(item, dict)]
    blocked_layers = [
        {
            "layer_id": str(layer.get("layer_id")),
            "label": str(layer.get("label")),
            "status": str(layer.get("status")),
            "blockers": [str(blocker) for blocker in layer.get("blockers", [])],
            "next_safe_action": str(layer.get("next_safe_action", "")),
        }
        for layer in cloud_layer_items
        if str(layer.get("status")) != "live_verified"
    ]
    status = (
        "ready_for_owner_cloud_execution"
        if bool(preflight.get("preflight_ready")) and not hard_blockers and not audit_missing_gates
        else "blocked_external_gates"
    )

    return {
        "contract_version": GO_LIVE_READINESS_CONTRACT_VERSION,
        "status": status,
        "endpoint": "GET /api/v1/clouds/go-live-readiness",
        "evidence_ref": GO_LIVE_READINESS_EVIDENCE_REF,
        "objective": "100_percent_live_across_7_layers_22_pages",
        "overall_percent": int(progress["overall_percent"]),
        "completion_status": completion.get("status"),
        "completion_can_set_all_to_100": bool(completion.get("can_set_all_to_100")),
        "workspace_page_count": int(workspace.get("page_count", 0)),
        "workspace_contract": workspace.get("contract_version"),
        "cloud_layer_status": cloud_layers.get("status"),
        "cloud_layer_ready_count": int(cloud_layers.get("ready_layer_count", 0)),
        "cloud_layer_total_count": int(cloud_layers.get("total_layer_count", 0)),
        "blocked_layers": blocked_layers,
        "runtime_external_gate_status": external_gates.get("status"),
        "runtime_external_blocked_release_gates": [str(item) for item in external_gates.get("blocked_release_gates", [])],
        "runtime_preflight_status": preflight.get("status"),
        "runtime_preflight_missing_or_blocked_gates": missing_or_blocked_gates,
        "external_audit_summary": external_audit_summary,
        "external_audit_summary_status": external_audit_summary.get("status"),
        "external_audit_missing_or_failed_gates": audit_missing_gates,
        "external_audit_claims": {
            "frontend_preview_claim_allowed": bool(external_audit_summary.get("frontend_preview_claim_allowed")),
            "hosted_staging_claim_allowed": bool(external_audit_summary.get("hosted_staging_claim_allowed")),
            "branch_protection_claim_allowed": bool(external_audit_summary.get("branch_protection_claim_allowed")),
            "ghcr_image_digest_claim_allowed": bool(external_audit_summary.get("ghcr_image_digest_claim_allowed")),
            "vercel_backend_origins_claim_allowed": bool(external_audit_summary.get("vercel_backend_origins_claim_allowed")),
            "canonical_gitleaks_claim_allowed": bool(external_audit_summary.get("canonical_gitleaks_claim_allowed")),
            "fly_live_budget_claim_allowed": bool(external_audit_summary.get("fly_live_budget_claim_allowed")),
            "production_deploy_claim_allowed": bool(external_audit_summary.get("production_deploy_claim_allowed")),
        },
        "hard_blockers": hard_blockers,
        "required_owner_inputs": required_owner_inputs,
        "external_audit_required": True,
        "external_audit_summary_path": str(external_gate_summary_path()),
        "external_audit_verifier": "scripts/verify-external-gates.ps1",
        "external_audit_expected_missing_or_failed_gates": [
            "hosted_agent_api_contracts",
            "github_branch_protection_current_verify",
            "vercel_backend_origin_health",
            "fly_live_budget_check",
        ],
        "owner_activation": {
            "script": "scripts/owner-cloud-gate-activation.ps1",
            "runbook": "docs/runbooks/cloud-gate-owner-activation-2026-06-09.md",
            "plan_contract": "owner-cloud-gate-activation-plan-v1",
            "default_mode": "PlanOnly",
            "apply_allowed_in_codex": False,
        },
        "owner_sequence": [
            {
                "step": "deploy_fly_origins",
                "layers": ["L2", "L3", "L4", "L5", "L6"],
                "gate": "owner_deploy_gate",
                "mutation": True,
                "status": "blocked_until_owner_gate",
                "verifier_after": "GET /api/v1/health on each Fly HTTPS origin",
            },
            {
                "step": "configure_vercel_backend_origins",
                "layers": ["L1", "L2", "L4", "L5"],
                "gate": "owner_env_gate",
                "mutation": True,
                "status": "blocked_until_owner_gate",
                "required_env": ["STAGING_REWRITES_ENABLED", "AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL"],
            },
            {
                "step": "run_hosted_verifiers",
                "layers": ["L1", "L7"],
                "gate": "hosted_staging_proof",
                "mutation": False,
                "status": "waiting_for_https_staging",
                "commands": [
                    "scripts\\verify-browser-contract.ps1 -BaseUrl <STAGING_BASE_URL>",
                    "scripts\\verify-external-gates.ps1",
                ],
            },
            {
                "step": "verify_branch_and_budget",
                "layers": ["L6", "L7"],
                "gate": "owner_token_gate",
                "mutation": False,
                "status": "waiting_for_token_scoped_verify_only",
                "required_env": ["BRANCH_PROTECTION_TOKEN", "FLY_API_TOKEN"],
            },
        ],
        "claim_policy": "runtime_status_and_env_presence_are_not_hosted_or_production_proof",
        "policy_checks": [
            "This readiness contract composes existing runtime contracts and does not execute cloud commands.",
            "External audit artifacts remain the source of truth for hosted, Vercel-origin, branch-protection, Fly-budget, and production claims.",
            "The 22-page Workbench contract is referenced without rendering project-state walls inside the Workbench UI.",
            "Secret values are never returned; required owner inputs are environment variable names only.",
        ],
        "non_claims": [
            "No cloud resource was created, mutated, deployed, or deleted.",
            "No production deployment, release promotion, registry push, live LLM call, or live MCP write is claimed.",
            "Localhost remains DEV-ONLY and cannot close hosted staging or production gates.",
            "This endpoint does not make the project 100 percent complete.",
        ],
    }


def go_live_readiness_contract_payload() -> dict[str, object]:
    state = go_live_readiness_state()
    return {
        "contract_version": GO_LIVE_READINESS_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/clouds/go-live-readiness/contract",
        "runtime_endpoint": "GET /api/v1/clouds/go-live-readiness",
        "runtime_contract_version": state.get("contract_version"),
        "evidence_ref": GO_LIVE_READINESS_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "objective",
            "overall_percent",
            "completion_can_set_all_to_100",
            "workspace_page_count",
            "cloud_layer_total_count",
            "runtime_preflight_missing_or_blocked_gates",
            "external_audit_summary_status",
            "external_audit_missing_or_failed_gates",
            "external_audit_claims",
            "hard_blockers",
            "required_owner_inputs",
            "external_audit_required",
            "external_audit_summary_path",
            "owner_activation",
            "owner_sequence",
            "claim_policy",
            "policy_checks",
            "non_claims",
        ],
        "expected_runtime_contract_version": GO_LIVE_READINESS_CONTRACT_VERSION,
        "supported_statuses": ["blocked_external_gates", "ready_for_owner_cloud_execution"],
        "guarded_endpoints": [
            "GET /api/v1/project/progress/completion",
            "GET /api/v1/external-gates",
            "GET /api/v1/clouds/layers",
            "GET /api/v1/clouds/deployment-preflight",
            "GET /api/v1/workspace/wiring",
            "GET /api/v1/workspace/vertical-stack",
        ],
        "required_verifiers": [
            "scripts/verify-go-live-readiness.ps1",
            "scripts/verify-external-gates.ps1",
            "scripts/verify-browser-contract.ps1",
        ],
        "non_claims": list(state.get("non_claims", [])),
    }


@app.get("/api/v1/external-gates")
def external_gates() -> dict[str, object]:
    return external_gate_state()


@app.get("/api/v1/external-gates/contract")
def external_gates_contract() -> dict[str, object]:
    return external_gates_surface_contract_payload()


@app.get("/api/v1/external-gates/mirror")
def external_gates_mirror() -> dict[str, object]:
    return external_gate_mirror_state()


@app.get("/api/v1/external-gates/mirror/contract")
def external_gates_mirror_contract() -> dict[str, object]:
    return external_gate_mirror_surface_contract_payload()


@app.get("/api/v1/clouds")
def clouds() -> dict[str, object]:
    return cloud_provider_state()


@app.get("/api/v1/clouds/contract")
def clouds_contract() -> dict[str, object]:
    return cloud_inventory_contract_payload()


@app.get("/api/v1/clouds/layers")
def cloud_layers() -> dict[str, object]:
    return cloud_layer_readiness_state()


@app.get("/api/v1/clouds/layers/contract")
def cloud_layers_contract() -> dict[str, object]:
    return cloud_layers_contract_payload()


ORGANISM_REGIONS = [
    {"id": "prefrontal", "name": "Prefrontal Cortex", "cap": "Planning / Goals / Architecture", "layer": "ORC"},
    {"id": "thalamus", "name": "Thalamus", "cap": "Routing / Context / Approvals", "layer": "ORC"},
    {"id": "hippocampus", "name": "Hippocampus", "cap": "Memory / Resume / Knowledge", "layer": "MEM"},
    {"id": "amygdala", "name": "Amygdala", "cap": "Security / Risk / Secret protection", "layer": "OBS"},
    {"id": "basal", "name": "Basal Ganglia", "cap": "Tool / Skill / Model selection", "layer": "MCP"},
    {"id": "cerebellum", "name": "Cerebellum", "cap": "Tests / Verifier / Self-correction", "layer": "OBS"},
    {"id": "motor", "name": "Motor Cortex", "cap": "CLI / Browser / Git / Cloud actions", "layer": "AP"},
    {"id": "sensory", "name": "Sensory Cortex", "cap": "Files / Logs / Providers / MCP", "layer": "MCP"},
    {"id": "autonomic", "name": "Autonomic NS", "cap": "Watchdog / Health / Retries", "layer": "AP"},
    {"id": "callosum", "name": "Corpus Callosum", "cap": "Event Bus / Cross-agent sync", "layer": "ORC"},
]

ORGANISM_LAYERS = [
    {"no": 1, "code": "FE", "label": "Frontend / Next.js", "providers": ["vercel_frontend"]},
    {"no": 2, "code": "ORC", "label": "Orchestrator / LangGraph", "providers": ["fly_io"]},
    {"no": 3, "code": "AP", "label": "Agent Pool", "providers": ["fly_io"]},
    {"no": 4, "code": "LLM", "label": "LLM Gateway", "providers": ["cloudflare_edge", "huggingface_identity"]},
    {"no": 5, "code": "MCP", "label": "MCP Gateway / Tools", "providers": ["github_actions", "ghcr_registry", "gitlab_identity"]},
    {"no": 6, "code": "MEM", "label": "Memory / PostgreSQL pgvector", "providers": ["fly_io"]},
    {"no": 7, "code": "OBS", "label": "Observability / Evidence", "providers": ["vercel_frontend", "fly_io", "cloudflare_edge", "github_actions", "grafana_cloud"]},
]

ORGANISM_HUBS = [
    {"id": "workbench", "label": "WORKBENCH", "layer": "FE", "route": "/workbench", "agents": ["planner", "coder", "tester", "devops"]},
    {"id": "agents", "label": "AGENTS", "layer": "AP", "route": "/agents", "agents": ["planner", "coder", "tester", "devops"]},
    {"id": "tools", "label": "TOOLS / MCP", "layer": "MCP", "route": "/tools", "agents": ["coder", "tester", "devops"]},
    {"id": "models", "label": "MODELS", "layer": "LLM", "route": "/marketplace", "agents": ["planner", "coder", "tester", "devops"]},
    {"id": "marketplace", "label": "MARKETPLACE", "layer": "MCP", "route": "/marketplace", "agents": ["planner"]},
    {"id": "observe", "label": "OBSERVABILITY", "layer": "OBS", "route": "/observe", "agents": ["tester", "devops"]},
    {"id": "memory", "label": "MEMORY", "layer": "MEM", "route": "/files", "agents": ["planner", "coder", "tester", "devops"]},
    {"id": "cloud", "label": "CLOUD", "layer": "ORC", "route": "/technology", "agents": ["devops"]},
]

ORGANISM_PAGES = [
    (1, "home", "/home", "Home / Overview", "FE"),
    (2, "login", "/login", "Login / Onboarding", "FE"),
    (3, "workbench", "/workbench", "Main Workbench", "FE"),
    (4, "organism", "/organism", "Organism / Live", "FE"),
    (5, "organism-replay", "/organism/replay", "Organism / Replay", "OBS"),
    (6, "organism-map", "/organism/map", "Organism / Map", "FE"),
    (7, "agents", "/agents", "Agents", "AP"),
    (8, "files", "/files", "Files / Knowledge", "MEM"),
    (9, "files-local", "/files/local", "Local Files API", "MEM"),
    (10, "tools", "/tools", "MCP / Tools", "MCP"),
    (11, "marketplace", "/marketplace", "Marketplace", "LLM"),
    (12, "observe", "/observe", "Observe / Monitoring", "OBS"),
    (13, "games", "/games", "Games", "AP"),
    (14, "apps", "/apps", "Apps", "AP"),
    (15, "media", "/media", "Media", "LLM"),
    (16, "docs-output", "/docs-output", "Documents", "MEM"),
    (17, "evidence", "/evidence", "Proof / Evidence", "OBS"),
    (18, "diagnostics", "/diagnostics", "Diagnostics", "OBS"),
    (19, "design-system", "/design-system", "Design System", "FE"),
    (20, "stack", "/technology", "Technology Stack", "ORC"),
    (21, "settings", "/settings", "Settings / Governance", "MCP"),
    (22, "open-source", "/open-source", "Open Source", "FE"),
]

WORKSPACE_WIRING_CONTRACT_VERSION = "workspace-surface-wiring-v1"
WORKSPACE_WIRING_EVIDENCE_REF = "workspace_surface_wiring_visible"
WORKSPACE_VERTICAL_STACK_CONTRACT_VERSION = "workspace-vertical-stack-v1"
WORKSPACE_VERTICAL_STACK_EVIDENCE_REF = "workspace_vertical_stack_visible"
WORKSPACE_COMMON_VERIFIERS = ["scripts/verify-workspace-pages-layer-map.ps1", "scripts/verify-browser-contract.ps1"]
REFERENCE_DESIGN_CONTRACT_VERSION = "reference-design-conformance-v1"
REFERENCE_DESIGN_EVIDENCE_REF = "reference_design_conformance_visible"
REFERENCE_ASSET_REQUIREMENTS = {
    "rootImagesMin": 3,
    "currentDesignScreenshotsMin": 15,
    "motionVideosMin": 1,
}
REFERENCE_DESIGN_RULES = {
    "visualLanguage": "industrial-developer-workbench",
    "cornerRadiusMaxPx": 16,
    "cardRadiusMaxPx": 12,
    "typography": ["Geist/Inter UI", "JetBrains Mono telemetry"],
    "requiredSurfaces": ["22 canonical pages", "central workbench", "3D organism", "replay", "topology", "evidence"],
    "forbidden": [
        "project-status-wall-on-workbench",
        "fake-live-data",
        "secret-output",
        "cartoon-bubble-cards",
        "retired-provider-defaults",
    ],
}

ORGANISM_PAGE_WIRING = {
    "home": {"brain_region": "sensory", "hub": "workbench", "primary_mode": "navigate", "data_sources": ["WORKSPACE_PAGES", "/api/v1/clouds", "/api/v1/project/progress/integrity"], "verifier_refs": WORKSPACE_COMMON_VERIFIERS, "event_kinds": ["planning", "blocked"]},
    "login": {"brain_region": "amygdala", "hub": "workbench", "primary_mode": "govern", "data_sources": ["/api/v1/auth/contract", "/api/v1/auth/github", "/api/v1/audit/recent"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1-runtime.ps1"], "event_kinds": ["verifying", "blocked"]},
    "workbench": {"brain_region": "prefrontal", "hub": "workbench", "primary_mode": "create", "data_sources": ["/api/v1/phase2/runtime/contract", "/api/v1/orchestrator/manifest/contract", "/api/v1/platform/verify", "/api/v1/orchestrator/checkpoints/contract", "/api/v1/orchestrator/dry-run", "/api/v1/orchestrator/dry-run/contract", "/api/v1/orchestrator/dry-run/stream", "/api/v1/orchestrator/dry-run/stream/contract", "/api/v1/orchestrator/manifest", "/api/v1/phase2/runtime/runs", "/api/v1/phase2/runtime/runs/contract", "/api/v1/phase2/runtime/start", "/api/v1/phase2/runtime/start/contract", "/api/v1/trace/contract"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "apps/frontend/e2e/organism.spec.ts"], "event_kinds": ["planning", "executing", "verifying"]},
    "organism": {"brain_region": "callosum", "hub": "workbench", "primary_mode": "inspect", "data_sources": ["/api/v1/organism/contract", "/api/v1/organism/live-state", "/api/v1/phase6/3d-camera-lighting/contract", "/api/v1/phase6/3d-gameplay-state/contract", "/api/v1/phase6/3d-asset-policy/contract", "/api/v1/phase6/3d-save-load/contract", "/api/v1/phase6/3d-accessibility/contract", "/api/v1/phase6/3d-netcode/contract", "/api/v1/phase6/local-scoreboard-performance/contract", "/organism/core.glb"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "apps/frontend/e2e/organism.spec.ts"], "event_kinds": ["planning", "executing", "tool_call", "llm_call", "memory_read", "memory_write", "verifying", "blocked"]},
    "organism-replay": {"brain_region": "hippocampus", "hub": "observe", "primary_mode": "inspect", "data_sources": ["/api/v1/organism/replay", "/api/v1/organism/events"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "apps/frontend/e2e/organism.spec.ts"], "event_kinds": ["memory_read", "verifying", "blocked"]},
    "organism-map": {"brain_region": "thalamus", "hub": "cloud", "primary_mode": "inspect", "data_sources": ["/api/v1/organism/topology", "/api/v1/organism/regions", "/api/v1/organism/safety"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "apps/frontend/e2e/organism.spec.ts"], "event_kinds": ["planning", "verifying", "blocked"]},
    "agents": {"brain_region": "motor", "hub": "agents", "primary_mode": "inspect", "data_sources": ["/api/v1/agents/status", "/api/v1/agent-activity/recent", "/api/v1/tasks/assignment-contract", "/api/v1/agent-activity/contract", "/api/v1/agents/llm-streaming-contract", "/api/v1/agents/profiles", "/api/v1/agents/profiles/contract", "/api/v1/live-agents/contract", "/api/v1/live-agents/status", "/api/v1/live-agents/steer", "/api/v1/task/dispatch/contract", "/api/v1/task/dispatches/recent", "/api/v1/tasks/policy", "/api/v1/tasks/policy/contract", "/api/v1/tasks/policy/validate", "/api/v1/tasks/recent", "/api/v1/tasks/recent/contract", "/api/v1/team/master-plan", "/api/v1/team/master-plan/contract", "/api/v1/team/roster", "/api/v1/team/roster/contract", "/api/v1/team/status", "/api/v1/team/status/contract"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1-runtime.ps1"], "event_kinds": ["planning", "executing", "verifying", "blocked"]},
    "files": {"brain_region": "hippocampus", "hub": "memory", "primary_mode": "inspect", "data_sources": ["/api/v1/memory/search", "/api/v1/memory/consolidation/recent", "/api/v1/memory/embedding-consistency/contract", "/api/v1/cache/contract", "/api/v1/memory/consolidation/contract", "/api/v1/memory/purge/contract", "/api/v1/memory/purge/jobs/contract", "/api/v1/session-limits/contract", "/api/v1/session-limits/status", "/api/v1/session/stream/contract", "/api/v1/sessions/history/contract"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1-runtime.ps1"], "event_kinds": ["memory_read", "memory_write", "verifying"]},
    "files-local": {"brain_region": "sensory", "hub": "memory", "primary_mode": "inspect", "data_sources": ["/api/v1/files/local/contract", "filesystem_workspace_scope_contract", "read_only_file_tree"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1.ps1"], "event_kinds": ["memory_read", "tool_call", "blocked"]},
    "tools": {"brain_region": "basal", "hub": "tools", "primary_mode": "inspect", "data_sources": ["/mcp/api/v1/version-pinning/contract", "/api/v1/audit/mcp", "MCP_TOOLS", "/api/v1/prompt/contract", "/api/v1/tools/read-only/execute", "/api/v1/tools/read-only/execute/contract"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1-runtime.ps1"], "event_kinds": ["tool_call", "verifying", "blocked"]},
    "marketplace": {"brain_region": "basal", "hub": "models", "primary_mode": "inspect", "data_sources": ["MODELS", "SKILLS", "/api/v1/models/capabilities"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1-runtime.ps1"], "event_kinds": ["llm_call", "tool_call", "blocked"]},
    "observe": {"brain_region": "autonomic", "hub": "observe", "primary_mode": "inspect", "data_sources": ["/api/v1/metrics", "/api/v1/health", "/api/v1/clouds/layers", "/api/v1/budget", "/api/v1/budget/contract", "/api/v1/costs", "/api/v1/costs/contract", "/api/v1/costs/export", "/api/v1/costs/export/contract", "/api/v1/infra/budget", "/api/v1/infra/budget/contract", "/api/v1/rate-limit/contract", "/api/v1/rate-limit/status", "/api/v1/rotation/events", "/api/v1/rotation/events/contract", "/api/v1/rotation/policy", "/api/v1/rotation/policy/contract", "/api/v1/system/fallback/contract"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1-runtime.ps1"], "event_kinds": ["verifying", "blocked"]},
    "games": {"brain_region": "motor", "hub": "workbench", "primary_mode": "create", "data_sources": ["/workbench", "/organism/core.glb", "game_preview_mode"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "npm run test:e2e --prefix apps/frontend"], "event_kinds": ["planning", "executing", "tool_call", "verifying"]},
    "apps": {"brain_region": "motor", "hub": "workbench", "primary_mode": "create", "data_sources": ["/workbench", "app_preview_mode", "/api/v1/platform/verify"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "npm run test:e2e --prefix apps/frontend"], "event_kinds": ["planning", "executing", "tool_call", "verifying"]},
    "media": {"brain_region": "sensory", "hub": "models", "primary_mode": "create", "data_sources": ["media_preview_mode", "MODELS", "/api/v1/models/capabilities"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "npm run test:e2e --prefix apps/frontend"], "event_kinds": ["llm_call", "executing", "verifying", "blocked"]},
    "docs-output": {"brain_region": "hippocampus", "hub": "memory", "primary_mode": "create", "data_sources": ["docs_output_mode", "/api/v1/memory/search", "/api/v1/sessions/recent"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "npm run test:e2e --prefix apps/frontend"], "event_kinds": ["memory_read", "memory_write", "executing", "verifying"]},
    "evidence": {"brain_region": "cerebellum", "hub": "observe", "primary_mode": "verify", "data_sources": ["/api/v1/external-gates", "/api/v1/project/progress/integrity", "docs/verification-register.md"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1.ps1", "gitleaks detect --no-git --source ."], "event_kinds": ["verifying", "blocked"]},
    "diagnostics": {"brain_region": "amygdala", "hub": "observe", "primary_mode": "verify", "data_sources": ["/api/v1/audit/recent", "/api/v1/escalations/recent", ".phase1-artifacts", "/api/v1/errors/contract", "/api/v1/escalations/contract", "/api/v1/layer-interfaces/contract", "/api/v1/request/contract", "/api/v1/security/headers/contract", "/api/v1/security/csp/contract", "/api/v1/security/csrf/contract", "/api/v1/security/cross-origin/contract", "/api/v1/workspace/artifacts", "/api/v1/workspace/artifacts/contract", "/api/v1/workspace/vertical-stack", "/api/v1/workspace/wiring", "/api/v1/platform/inventory"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-retired-hosted-boundary.ps1"], "event_kinds": ["verifying", "blocked"]},
    "design-system": {"brain_region": "sensory", "hub": "workbench", "primary_mode": "inspect", "data_sources": ["apps/frontend/app/styles.css", "WORKSPACE_PAGES", "NeuroGlass tokens", "/api/v1/design/reference-contract"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "npm run lint --prefix apps/frontend"], "event_kinds": ["planning", "verifying"]},
    "stack": {"brain_region": "thalamus", "hub": "cloud", "primary_mode": "inspect", "data_sources": ["docs/system-architecture.md", "/api/v1/clouds", "/api/v1/clouds/deployment-preflight", "/api/v1/devops/workflow-dispatch/plan", "/api/v1/devops/workflow-dispatch/plan/contract", "/api/v1/devops/workflow-dispatch/validate", "/api/v1/devops/workflow-dispatch/validate/contract", "/api/v1/project/progress", "/api/v1/project/progress/completion", "/api/v1/project/progress/completion/contract", "/api/v1/project/progress/contract", "/api/v1/project/progress/layers", "/api/v1/project/progress/layers/contract"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1.ps1"], "event_kinds": ["planning", "verifying", "blocked"]},
    "settings": {"brain_region": "amygdala", "hub": "tools", "primary_mode": "govern", "data_sources": ["/api/v1/clouds/deployment-preflight", "/api/v1/auth/contract", "CLOSED_GATES", "/api/v1/auth/callback", "/api/v1/auth/logout", "/api/v1/auth/refresh"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-owner-cloud-gate-activation.ps1"], "event_kinds": ["blocked", "verifying"]},
    "open-source": {"brain_region": "callosum", "hub": "cloud", "primary_mode": "navigate", "data_sources": ["package.json", "LICENSE", "docs/verification-register.md"], "verifier_refs": [*WORKSPACE_COMMON_VERIFIERS, "scripts/verify-phase1.ps1"], "event_kinds": ["planning", "verifying"]},
}

ORGANISM_TOOLS = [
    {"id": "memory_read", "label": "Memory Read", "layer": 6, "scope": "read"},
    {"id": "task_router", "label": "Task Router", "layer": 2, "scope": "read"},
    {"id": "langgraph", "label": "LangGraph", "layer": 2, "scope": "read"},
    {"id": "mcp_gateway", "label": "MCP Gateway", "layer": 5, "scope": "gated"},
    {"id": "github_mcp", "label": "GitHub MCP", "layer": 5, "scope": "scoped_write"},
    {"id": "filesystem_mcp", "label": "Filesystem MCP", "layer": 5, "scope": "scoped_write"},
    {"id": "playwright_mcp", "label": "Playwright MCP", "layer": 5, "scope": "gated"},
    {"id": "e2b_mcp", "label": "E2B Sandbox MCP", "layer": 5, "scope": "gated"},
]

ORGANISM_SKILLS = [
    "strict-project-gate",
    "product-ux-guardian",
    "live-3d-organism-architect",
    "r3f-three-engineer",
    "blender-gltf-pipeline",
    "mcp-safety-auditor",
    "visual-verifier",
    "accessibility-reduced-motion",
    "telemetry-binding-engineer",
    "opa-gate-engineer",
]

ORGANISM_CLOSED_GATES = [
    "Production deploy",
    "Release promotion",
    "Provider writes",
    "Main push",
    "Registry push",
    "Live MCP write",
    "Live LLM call",
    "Secret output",
]


def _organism_gate_id(label: str) -> str:
    return label.lower().replace(" ", "_")


def _organism_region_for_hub(hub_id: str) -> str:
    return {
        "memory": "hippocampus",
        "observe": "cerebellum",
        "tools": "basal",
        "models": "basal",
        "agents": "motor",
        "cloud": "thalamus",
    }.get(hub_id, "prefrontal")


def _organism_layer_code(layer_no: int) -> str:
    for layer in ORGANISM_LAYERS:
        if layer["no"] == layer_no:
            return str(layer["code"])
    return "MCP"


def _organism_node_slug(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return slug or "ref"


def workspace_wiring_surfaces() -> list[dict[str, object]]:
    surfaces: list[dict[str, object]] = []
    region_ids = {str(region["id"]) for region in ORGANISM_REGIONS}
    hub_ids = {str(hub["id"]) for hub in ORGANISM_HUBS}
    for no, page_id, route, label, layer in ORGANISM_PAGES:
        wiring = dict(ORGANISM_PAGE_WIRING.get(page_id, {}))
        if not wiring:
            raise RuntimeError(f"Workspace wiring missing page '{page_id}'.")
        if str(wiring.get("brain_region")) not in region_ids:
            raise RuntimeError(f"Workspace wiring page '{page_id}' has invalid brain region.")
        if str(wiring.get("hub")) not in hub_ids:
            raise RuntimeError(f"Workspace wiring page '{page_id}' has invalid hub.")
        surfaces.append({
            "pageId": page_id,
            "no": no,
            "label": label,
            "route": route,
            "layer": layer,
            "brainRegion": wiring["brain_region"],
            "hub": wiring["hub"],
            "primaryMode": wiring["primary_mode"],
            "dataSources": list(wiring["data_sources"]),
            "verifierRefs": list(wiring["verifier_refs"]),
            "eventKinds": list(wiring["event_kinds"]),
            "live": False,
            "writes": False,
            "secretOutput": False,
            "evidenceRef": WORKSPACE_WIRING_EVIDENCE_REF,
        })
    return surfaces


def workspace_wiring_payload() -> dict[str, object]:
    surfaces = workspace_wiring_surfaces()
    return {
        "contract_version": WORKSPACE_WIRING_CONTRACT_VERSION,
        "endpoint": "/api/v1/workspace/wiring",
        "evidence_ref": WORKSPACE_WIRING_EVIDENCE_REF,
        "source": "agent-api-static-contract",
        "live": False,
        "page_count": len(surfaces),
        "surfaces": surfaces,
        "policy_checks": [
            "Each canonical workspace page maps to one architecture layer, one brain region, and one capability hub.",
            "Every page exposes deterministic data source and verifier references.",
            "All entries are read-only: writes=false, live=false, secretOutput=false.",
            "Topology edges must reference existing page, layer, region, hub, data-source, and verifier nodes.",
        ],
        "non_claims": [
            "This endpoint does not execute verifier commands.",
            "This endpoint does not call live providers, mutate cloud state, or expose secrets.",
            "Local evidence remains DEV-ONLY and cannot close hosted staging or production gates.",
        ],
    }


def _workspace_api_like_ref(value: str) -> bool:
    return value.startswith("/api/") or value.startswith("/mcp/") or value.startswith("/llm/")


def _workspace_component_path(route: str) -> str:
    if route == "/":
        return "apps/frontend/app/page.tsx"
    return f"apps/frontend/app/{route.lstrip('/')}/page.tsx"


def _workspace_data_plane(layer: str, hub: str) -> str:
    if hub == "memory" or layer == "MEM":
        return "postgres-pgvector-and-redis-memory"
    if hub == "observe" or layer == "OBS":
        return "audit-log-metrics-evidence-artifacts"
    if hub == "tools" or layer == "MCP":
        return "mcp-gateway-safe-envelope"
    if hub == "models" or layer == "LLM":
        return "llm-gateway-contract"
    if hub == "agents" or layer == "AP":
        return "agent-pool-task-queue"
    if hub == "cloud" or layer == "ORC":
        return "cloud-readiness-and-deployment-preflight"
    return "frontend-static-contract-and-runtime-fetches"


def workspace_vertical_stack_payload() -> dict[str, object]:
    stacks: list[dict[str, object]] = []
    for surface in workspace_wiring_surfaces():
        data_sources = [str(source) for source in surface["dataSources"]]
        api_contracts = [source for source in data_sources if _workspace_api_like_ref(source)]
        static_refs = [source for source in data_sources if not _workspace_api_like_ref(source)]
        verifier_refs = list(dict.fromkeys([
            *[str(ref) for ref in surface["verifierRefs"]],
            "scripts/verify-workspace-vertical-stack.ps1",
            "scripts/verify-workspace-pages-browser.ps1",
        ]))
        route = str(surface["route"])
        layer = str(surface["layer"])
        hub = str(surface["hub"])
        stacks.append({
            "pageId": surface["pageId"],
            "no": surface["no"],
            "label": surface["label"],
            "route": route,
            "layer": layer,
            "brainRegion": surface["brainRegion"],
            "hub": hub,
            "primaryMode": surface["primaryMode"],
            "ui": {
                "route": route,
                "componentPath": _workspace_component_path(route),
                "shellRequired": True,
                "activeRailRequired": True,
            },
            "api": {
                "contracts": api_contracts,
                "staticRefs": static_refs,
                "gatewayBound": True,
                "directProviderCalls": False,
            },
            "data": {
                "plane": _workspace_data_plane(layer, hub),
                "sources": data_sources,
                "writesAllowedByDefault": False,
                "secretOutputAllowed": False,
            },
            "verification": {
                "refs": verifier_refs,
                "browserProofRequired": True,
                "phase1GuardRequired": True,
                "hostedProofRequiredForRelease": True,
            },
            "deploy": {
                "frontendTarget": "vercel",
                "backendTargets": ["fly-agent-api", "fly-mcp-gateway", "fly-llm-gateway"],
                "registry": "ghcr",
                "hostedProofStatus": "blocked_external_gates",
            },
            "safety": {
                "live": False,
                "writes": False,
                "secretOutput": False,
                "productionDeployClaimAllowed": False,
                "localProofOnly": True,
            },
            "eventKinds": surface["eventKinds"],
        })
    return {
        "contract_version": WORKSPACE_VERTICAL_STACK_CONTRACT_VERSION,
        "endpoint": "/api/v1/workspace/vertical-stack",
        "evidence_ref": WORKSPACE_VERTICAL_STACK_EVIDENCE_REF,
        "source": "agent-api-static-contract",
        "page_count": len(stacks),
        "expected_page_count": 22,
        "layers_required": 7,
        "stacks": stacks,
        "required_stage_keys": ["ui", "api", "data", "verification", "deploy", "safety"],
        "policy_checks": [
            "Every canonical page must expose UI, API, data, verification, deploy, and safety stages.",
            "Every page remains local-proof-only until hosted Vercel/Fly/GHCR/Grafana gates pass.",
            "No stack entry may enable provider bypass, secret output, production deploy, or live MCP writes.",
            "Budget UI remains hidden unless a paid/metered capability is selected or explicitly available.",
        ],
        "non_claims": [
            "This contract does not execute deploys, provider calls, MCP writes, or verifier commands.",
            "This contract is not hosted staging proof and cannot close external gates by itself.",
            "Localhost evidence remains DEV-ONLY.",
        ],
    }


def reference_design_contract_payload() -> dict[str, object]:
    pages = [
        {"id": page_id, "no": no, "route": route, "layer": layer}
        for no, page_id, route, _label, layer in ORGANISM_PAGES
    ]
    return {
        "contract_version": REFERENCE_DESIGN_CONTRACT_VERSION,
        "endpoint": "/api/v1/design/reference-contract",
        "evidence_ref": REFERENCE_DESIGN_EVIDENCE_REF,
        "source": "agent-api-static-contract",
        "live": False,
        "reference_roots": ["docs/reference", "docs/reference/aktuell desin"],
        "required_asset_inventory": REFERENCE_ASSET_REQUIREMENTS,
        "design_rules": REFERENCE_DESIGN_RULES,
        "page_count": len(pages),
        "expected_page_count": 22,
        "pages": pages,
        "organism_requirements": {
            "canvas": "real-time 3D cognitive organism",
            "regions": [str(region["id"]) for region in ORGANISM_REGIONS],
            "event_kinds": ["planning", "executing", "tool_call", "llm_call", "memory_read", "memory_write", "verifying", "blocked"],
            "replay_required": True,
            "no_fake_live": True,
        },
        "non_claims": [
            "This contract does not claim pixel-perfect visual completion.",
            "This contract does not execute browser screenshots or image comparison.",
            "This contract does not mutate cloud state, call live providers, or expose secrets.",
            "Local evidence remains DEV-ONLY until hosted staging verification exists.",
        ],
    }


def platform_verify_payload() -> dict[str, object]:
    state = cloud_layer_readiness_state()
    layers = [
        {
            "id": str(layer.get("layer_id") or ""),
            "label": str(layer.get("label") or layer.get("layer_id") or ""),
            "status": str(layer.get("status") or "unknown"),
            "verified": str(layer.get("status") or "") == "live_verified",
        }
        for layer in state.get("layers", [])
        if isinstance(layer, dict)
    ]
    return {
        "contract_version": "platform-verify-readiness-v1",
        "endpoint": "/api/v1/platform/verify",
        "source": "agent-api",
        "live": bool(layers),
        "verified": sum(1 for layer in layers if bool(layer["verified"])),
        "total": len(layers),
        "layers": layers,
        "evidence_ref": "cloud_layer_readiness_visible",
        "non_claims": [
            "Read-only projection of cloud layer readiness.",
            "No provider write, deploy, live LLM call, live MCP write, or secret output.",
            "Localhost remains DEV-ONLY and cannot close hosted gates.",
        ],
    }


def _safe_run_id(run_id: str | None) -> str | None:
    if not run_id:
        return None
    run_id = run_id.strip()
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-")
    if 0 < len(run_id) <= 96 and all(ch in allowed for ch in run_id):
        return run_id
    return None


def organism_contract_payload() -> dict[str, object]:
    registry = agent_profile_registry()
    profiles = list(registry.get("profiles", []))
    models = [{"id": str(profile.get("primary_model", "")).split(":")[0], "role": f"{profile.get('agent_type')} primary"} for profile in profiles]
    workspace_pages = workspace_wiring_surfaces()
    return {
        "contract_version": "organism-surface-v1",
        "endpoint": "/api/v1/organism/contract",
        "evidence_ref": "organism_canvas_visible",
        "source": "agent-api-static-contract",
        "live": False,
        "run_states": ["idle", "planning", "executing", "verifying", "blocked"],
        "event_kinds": ["planning", "executing", "tool_call", "llm_call", "memory_read", "memory_write", "verifying", "blocked"],
        "central": {"kind": "neural_core", "particles_default": 1600, "asset_slot": "/public/organism/core.glb (optional)"},
        "hubs": ORGANISM_HUBS,
        "layers": ORGANISM_LAYERS,
        "workspace_pages": [
            {
                "id": page["pageId"],
                "no": page["no"],
                "route": page["route"],
                "layer": page["layer"],
                "brain_region": page["brainRegion"],
                "hub": page["hub"],
                "data_sources": page["dataSources"],
                "verifier_refs": page["verifierRefs"],
                "live": page["live"],
                "writes": page["writes"],
                "secret_output": page["secretOutput"],
            }
            for page in workspace_pages
        ],
        "workspace_page_count": len(workspace_pages),
        "agents": [{"type": p.get("agent_type"), "tools": p.get("allowed_tools"), "model": p.get("primary_model")} for p in profiles],
        "tools": ORGANISM_TOOLS,
        "models": models,
        "skills": [{"id": skill} for skill in ORGANISM_SKILLS],
        "gates_closed": ORGANISM_CLOSED_GATES,
        "related": [
            "/api/v1/organism/topology",
            "/api/v1/organism/live-state",
            "/api/v1/organism/events",
            "/api/v1/organism/replay",
            "/api/v1/organism/regions",
            "/api/v1/organism/safety",
            "/api/v1/workspace/wiring",
            "/api/v1/workspace/vertical-stack",
        ],
        "policy_checks": [
            "No secret values are returned by this endpoint.",
            "All 22 workspace pages map onto layer, brain-region, hub, data-source, and verifier references.",
            "Topology edges must reference existing nodes.",
            "No provider write, deploy, push, live LLM call, or live MCP write is performed.",
        ],
        "non_claims": [
            "Live events and replay are spec-only until a recorded runtime event source is connected.",
            "No provider write, deploy, push or live LLM/MCP call is performed.",
        ],
    }


def organism_topology_payload() -> dict[str, object]:
    providers = [item for item in cloud_provider_state().get("providers", []) if isinstance(item, dict)]
    registry = agent_profile_registry()
    profiles = [item for item in registry.get("profiles", []) if isinstance(item, dict)]
    models = [{"id": str(profile.get("primary_model", "")).split(":")[0], "role": f"{profile.get('agent_type')} primary"} for profile in profiles]
    workspace_pages = workspace_wiring_surfaces()
    workspace_data_sources = sorted({source for page in workspace_pages for source in page["dataSources"]})
    workspace_verifier_refs = sorted({verifier for page in workspace_pages for verifier in page["verifierRefs"]})
    nodes: list[dict[str, object]] = []
    nodes.extend({**r, "id": f"region:{r['id']}", "kind": "brain_region", "secret_output": False, "writes": False} for r in ORGANISM_REGIONS)
    nodes.extend({"id": f"layer:{l['code']}", "kind": "architecture_layer", **l, "secret_output": False, "writes": False} for l in ORGANISM_LAYERS)
    nodes.extend({**h, "id": f"hub:{h['id']}", "kind": "capability_hub", "secret_output": False, "writes": False} for h in ORGANISM_HUBS)
    nodes.extend({"id": f"agent:{p.get('agent_type')}", "kind": "agent_profile", "label": p.get("agent_type"), "model": p.get("primary_model"), "tools": p.get("allowed_tools", []), "secret_output": False, "writes": False} for p in profiles)
    nodes.extend({**t, "id": f"tool:{t['id']}", "kind": "mcp_tool", "secret_output": False, "writes": False, "write_capability": t["scope"] != "read", "gate_required": t["scope"] != "read"} for t in ORGANISM_TOOLS)
    nodes.extend({**m, "id": f"model:{m['id']}", "kind": "llm_model", "layer": 4, "secret_output": False, "writes": False, "gateway_only": True} for m in models)
    nodes.extend({"id": f"skill:{skill}", "kind": "skill", "label": skill, "layer": 5, "secret_output": False, "writes": False} for skill in ORGANISM_SKILLS)
    nodes.extend({"id": f"provider:{p.get('id')}", "kind": "cloud_provider", "label": p.get("label"), "layers": p.get("layers", []), "secret_output": False, "writes": False} for p in providers)
    nodes.extend({"id": f"gate:{_organism_gate_id(gate)}", "kind": "safety_gate", "label": gate, "status": "closed", "secret_output": False, "writes": False} for gate in ORGANISM_CLOSED_GATES)
    nodes.extend({
        "id": f"page:{page['pageId']}",
        "kind": "workspace_page",
        "no": page["no"],
        "label": page["label"],
        "route": page["route"],
        "layer": page["layer"],
        "brain_region": page["brainRegion"],
        "hub": page["hub"],
        "data_sources": page["dataSources"],
        "verifier_refs": page["verifierRefs"],
        "event_kinds": page["eventKinds"],
        "secret_output": False,
        "writes": False,
    } for page in workspace_pages)
    nodes.extend({"id": f"source:{_organism_node_slug(str(source))}", "kind": "workspace_data_source", "label": source, "secret_output": False, "writes": False} for source in workspace_data_sources)
    nodes.extend({"id": f"verifier:{_organism_node_slug(str(verifier))}", "kind": "workspace_verifier", "label": verifier, "secret_output": False, "writes": False, "executes": False} for verifier in workspace_verifier_refs)

    edges: list[dict[str, str]] = []
    edges.extend({"from": "region:callosum", "to": f"region:{r['id']}", "kind": "neural_bus"} for r in ORGANISM_REGIONS if r["id"] != "callosum")
    edges.extend({"from": f"hub:{h['id']}", "to": f"region:{_organism_region_for_hub(str(h['id']))}", "kind": "capability_to_region"} for h in ORGANISM_HUBS)
    edges.extend({"from": f"hub:{h['id']}", "to": f"layer:{h['layer']}", "kind": "hub_to_layer"} for h in ORGANISM_HUBS)
    for profile in profiles:
        agent_type = str(profile.get("agent_type"))
        tools = profile.get("allowed_tools") or []
        for hub in ORGANISM_HUBS:
            if agent_type in hub["agents"]:
                edges.append({"from": f"agent:{agent_type}", "to": f"hub:{hub['id']}", "kind": "agent_to_hub"})
        for tool in tools:
            edges.append({"from": f"agent:{agent_type}", "to": f"tool:{tool}", "kind": "agent_to_tool"})
        model_id = str(profile.get("primary_model", "")).split(":")[0]
        edges.append({"from": f"agent:{agent_type}", "to": f"model:{model_id}", "kind": "agent_to_model"})
    edges.extend({"from": f"tool:{t['id']}", "to": f"layer:{_organism_layer_code(int(t['layer']))}", "kind": "tool_to_layer"} for t in ORGANISM_TOOLS)
    edges.extend({"from": f"model:{m['id']}", "to": "layer:LLM", "kind": "model_to_gateway_layer"} for m in models)
    edges.extend({"from": f"skill:{skill}", "to": "hub:tools", "kind": "skill_to_tool_hub"} for skill in ORGANISM_SKILLS)
    edges.extend({"from": f"page:{page['pageId']}", "to": f"layer:{page['layer']}", "kind": "page_to_layer"} for page in workspace_pages)
    edges.extend({"from": f"page:{page['pageId']}", "to": f"region:{page['brainRegion']}", "kind": "page_to_brain_region"} for page in workspace_pages)
    edges.extend({"from": f"page:{page['pageId']}", "to": f"hub:{page['hub']}", "kind": "page_to_capability_hub"} for page in workspace_pages)
    edges.extend({"from": f"page:{page['pageId']}", "to": f"source:{_organism_node_slug(str(source))}", "kind": "page_to_data_source"} for page in workspace_pages for source in page["dataSources"])
    edges.extend({"from": f"page:{page['pageId']}", "to": f"verifier:{_organism_node_slug(str(verifier))}", "kind": "page_to_verifier"} for page in workspace_pages for verifier in page["verifierRefs"])
    # Direct page-to-capability wiring: surface every built capability on the pages that own it (by
    # hub / security region), so the 22 pages explicitly expose models, skills, MCP tools, cloud
    # providers, agent profiles and safety gates — not only transitively via layers/hubs.
    _agent_types = [str(profile.get("agent_type")) for profile in profiles]
    _provider_ids = sorted({pid for layer in ORGANISM_LAYERS for pid in layer["providers"]})
    for page in workspace_pages:
        _pid = page["pageId"]
        if page["hub"] == "models":
            edges.extend({"from": f"page:{_pid}", "to": f"model:{m['id']}", "kind": "page_to_llm_model"} for m in models)
        if page["hub"] == "tools":
            edges.extend({"from": f"page:{_pid}", "to": f"tool:{t['id']}", "kind": "page_to_mcp_tool"} for t in ORGANISM_TOOLS)
            edges.extend({"from": f"page:{_pid}", "to": f"skill:{skill}", "kind": "page_to_skill"} for skill in ORGANISM_SKILLS)
        if page["hub"] == "agents":
            edges.extend({"from": f"page:{_pid}", "to": f"agent:{agent_type}", "kind": "page_to_agent_profile"} for agent_type in _agent_types)
        if page["hub"] == "cloud":
            edges.extend({"from": f"page:{_pid}", "to": f"provider:{provider_id}", "kind": "page_to_cloud_provider"} for provider_id in _provider_ids)
        if page["brainRegion"] == "amygdala":
            edges.extend({"from": f"page:{_pid}", "to": f"gate:{_organism_gate_id(gate)}", "kind": "page_to_safety_gate"} for gate in ORGANISM_CLOSED_GATES)
    for layer in ORGANISM_LAYERS:
        for provider_id in layer["providers"]:
            edges.append({"from": f"layer:{layer['code']}", "to": f"provider:{provider_id}", "kind": "layer_to_provider"})
    edges.extend({"from": f"gate:{_organism_gate_id(gate)}", "to": "region:amygdala", "kind": "gate_to_security_region"} for gate in ORGANISM_CLOSED_GATES)
    return {
        "contract_version": "organism-topology-v1",
        "endpoint": "/api/v1/organism/topology",
        "source": "agent-api-static-contract",
        "live": False,
        "source_kind": "contract",
        "nodes": nodes,
        "edges": edges,
        "non_claims": ["static topology contract", "no provider write", "no secret values"],
    }


def organism_live_state_payload() -> dict[str, object]:
    layer_state = cloud_layer_readiness_state()
    layers = [item for item in layer_state.get("layers", []) if isinstance(item, dict)]
    status_by_layer_id = {str(item.get("layer_id")): str(item.get("status")) for item in layers}
    layer_id_by_code = {"FE": "layer_1", "ORC": "layer_2", "AP": "layer_3", "LLM": "layer_4", "MCP": "layer_5", "MEM": "layer_6", "OBS": "layer_7"}
    return {
        "contract_version": "organism-live-state-v1",
        "source": "agent-api",
        "source_kind": "agent_api_redacted",
        "live": True,
        "note": "Hub state derived from agent-api cloud-layer-readiness. No provider write or direct provider call is performed.",
        "run_state": "verifying",
        "core": {"visual_pulse": "contract_default", "visual_intensity": "contract_default"},
        "hubs": [
            {
                "id": hub["id"],
                "layer": hub["layer"],
                "status": "active" if status_by_layer_id.get(layer_id_by_code.get(str(hub["layer"]), "")) == "live_verified" else "idle",
                "visual_weight_pct": 18 + ((index * 11) % 70),
                "source_kind": "synthetic_visual_weight",
            }
            for index, hub in enumerate(ORGANISM_HUBS)
        ],
        "layers": layers,
        "gates_closed": ["production_deploy", "provider_writes", "secret_output", "main_push"],
        "non_claims": ["redacted runtime status only, no live provider call", "no secret values"],
    }


def _organism_map_event_kind(event_type: str) -> tuple[str, str, str, list[str]]:
    event_type = event_type or "runtime_event"
    lowered = event_type.lower()
    if "tool" in lowered or "mcp" in lowered:
        return "tool_call", "tools", "executing", ["basal", "sensory", "motor", "callosum"]
    if "valid" in lowered or "verif" in lowered or "check" in lowered or "test" in lowered:
        return "verifying", "observe", "verifying", ["cerebellum", "sensory", "callosum"]
    if "memory" in lowered or "embed" in lowered or "vector" in lowered:
        return "memory_write" if "write" in lowered or "consolidat" in lowered else "memory_read", "memory", "executing", ["hippocampus", "callosum"]
    if "model" in lowered or "llm" in lowered or "inference" in lowered or "rotation" in lowered:
        return "llm_call", "models", "executing", ["basal", "thalamus", "callosum"]
    if "plan" in lowered or "orchestrator" in lowered or "langgraph" in lowered:
        return "planning", "workbench", "planning", ["prefrontal", "thalamus", "callosum"]
    if "complete" in lowered or "passed" in lowered or "done" in lowered or "success" in lowered:
        return "verifying", "observe", "idle", ["cerebellum", "autonomic", "callosum"]
    if "block" in lowered or "fail" in lowered or "error" in lowered or "escalat" in lowered:
        return "blocked", "observe", "blocked", ["amygdala", "cerebellum", "callosum"]
    if "exec" in lowered or "task" in lowered or "dispatch" in lowered or "agent" in lowered:
        return "executing", "agents", "executing", ["motor", "basal", "callosum"]
    return "executing", "workbench", "executing", ["sensory", "prefrontal", "callosum"]


def _organism_route_for_hub(hub: str) -> str:
    return {
        "workbench": "/workbench",
        "agents": "/agents",
        "tools": "/tools",
        "models": "/marketplace",
        "observe": "/observe",
        "memory": "/files",
        "cloud": "/technology",
    }.get(hub, "/workbench")


def _organism_redacted_audit_events(run_id: str | None = None, limit: int = 12) -> list[dict[str, object]]:
    conditions: list[str] = []
    params: list[object] = []
    if run_id:
        conditions.append(
            "(details->>'trace_id' = %s OR details->>'thread_id' = %s OR details->>'run_id' = %s OR CAST(session_id AS TEXT) = %s)"
        )
        params.extend([run_id, run_id, run_id, run_id])
    where_clause = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    params.append(limit)
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            f"""
            SELECT event_type, severity, created_at
            FROM audit_log
            {where_clause}
            ORDER BY created_at DESC
            LIMIT %s
            """,
            tuple(params),
        ).fetchall()
    events: list[dict[str, object]] = []
    if not rows:
        return events
    ordered = list(reversed(rows))
    first_ts = ordered[0][2]
    for index, row in enumerate(ordered, start=1):
        event_type = str(row[0] or "runtime_event")
        kind, hub, run_state, regions = _organism_map_event_kind(event_type)
        created_at = row[2]
        offset_s = 0.0
        if first_ts and created_at:
            offset_s = max(0.0, round((created_at - first_ts).total_seconds(), 1))
        events.append({
            "seq": index,
            "offset_s": offset_s,
            "page_id": hub,
            "route": _organism_route_for_hub(hub),
            "kind": kind,
            "event_type": event_type,
            "hub": hub,
            "regions": regions,
            "run_state": run_state,
            "severity": str(row[1] or "info"),
            "source_kind": "agent_api_redacted",
            "evidence_files": [],
            "secret_output": False,
            "writes": False,
        })
    return events


def organism_events_payload(run_id: str | None = None) -> dict[str, object]:
    run_id = _safe_run_id(run_id)
    runtime_events = _organism_redacted_audit_events(run_id=run_id, limit=12)
    if runtime_events:
        return {
            "contract_version": "organism-events-v1",
            "source": "agent-api",
            "source_kind": "agent_api_redacted",
            "live": True,
            "run_id": run_id,
            "note": "Derived from audit_log event_type/severity/timestamp only. Session/user/details are intentionally omitted.",
            "events": runtime_events,
            "non_claims": ["redacted runtime events only, no live provider call", "no secret values", "read-only audit projection"],
        }
    return {
        "contract_version": "organism-events-v1",
        "source": "spec_only",
        "source_kind": "spec_only",
        "live": False,
        "run_id": run_id,
        "note": "Spec-only event contract until a recorded runtime event source is connected.",
        "events": [
            {"seq": 1, "offset_s": 0.0, "page_id": "workbench", "route": "/workbench", "kind": "plan_created", "hub": "workbench", "regions": ["prefrontal", "thalamus", "callosum"], "run_state": "planning", "source_kind": "spec_only", "evidence_files": [], "secret_output": False, "writes": False},
            {"seq": 2, "offset_s": 1.2, "page_id": "agents", "route": "/agents", "agent": "planner", "kind": "agent_dispatched", "hub": "agents", "regions": ["basal", "motor", "callosum"], "run_state": "executing", "source_kind": "spec_only", "evidence_files": [], "secret_output": False, "writes": False},
            {"seq": 3, "offset_s": 2.6, "page_id": "tools", "route": "/tools", "tool": "mcp_gateway", "kind": "tool_call", "hub": "tools", "regions": ["basal", "sensory", "motor", "callosum"], "run_state": "executing", "source_kind": "spec_only", "evidence_files": [], "secret_output": False, "writes": False},
            {"seq": 4, "offset_s": 3.9, "page_id": "files", "route": "/files", "kind": "memory_read", "hub": "memory", "regions": ["hippocampus", "callosum"], "run_state": "executing", "source_kind": "spec_only", "evidence_files": [], "secret_output": False, "writes": False},
            {"seq": 5, "offset_s": 5.1, "page_id": "marketplace", "route": "/marketplace", "model": "llm_gateway", "kind": "llm_call", "hub": "models", "regions": ["basal", "thalamus", "callosum"], "run_state": "executing", "source_kind": "spec_only", "evidence_files": [], "secret_output": False, "writes": False},
            {"seq": 6, "offset_s": 6.4, "page_id": "observe", "route": "/observe", "kind": "verifying", "hub": "observe", "regions": ["cerebellum", "sensory", "callosum"], "run_state": "verifying", "source_kind": "spec_only", "evidence_files": [], "secret_output": False, "writes": False},
        ],
        "non_claims": ["spec-only data, never a live provider call", "no secret values"],
    }


def organism_replay_payload(run_id: str | None = None) -> dict[str, object]:
    run_id = _safe_run_id(run_id)
    runtime_events = _organism_redacted_audit_events(run_id=run_id, limit=8)
    if runtime_events:
        frames = [
            {
                "t": event["offset_s"],
                "run_state": event["run_state"],
                "active": [event["hub"]],
                "regions": event["regions"],
                "source_kind": "agent_api_redacted",
            }
            for event in runtime_events
        ]
        duration = max(float(frames[-1]["t"]) if frames else 0.0, 1.0)
        return {
            "contract_version": "organism-replay-v1",
            "source": "agent-api",
            "source_kind": "agent_api_redacted",
            "live": True,
            "run_id": run_id,
            "replay_available": True,
            "note": "Reconstructed from audit_log event_type/severity/timestamp only. Session/user/details are intentionally omitted.",
            "duration_s": round(duration, 1),
            "fps": 30,
            "frames": frames,
            "non_claims": ["redacted runtime replay only, no live provider call", "no secret values", "read-only audit projection"],
        }
    return {
        "contract_version": "organism-replay-v1",
        "source": "spec_only",
        "source_kind": "spec_only",
        "live": False,
        "run_id": run_id,
        "replay_available": False,
        "note": "Spec-only replay contract until recorded runtime frames are connected.",
        "duration_s": 8,
        "fps": 30,
        "frames": [
            {"t": 0.0, "run_state": "planning", "active": ["workbench"]},
            {"t": 2.0, "run_state": "executing", "active": ["agents", "tools"]},
            {"t": 4.0, "run_state": "executing", "active": ["models", "memory"]},
            {"t": 6.0, "run_state": "verifying", "active": ["observe"]},
            {"t": 8.0, "run_state": "idle", "active": []},
        ],
        "non_claims": ["spec-only data, never a live provider call", "no secret values"],
    }


def organism_regions_payload() -> dict[str, object]:
    signals = {
        "prefrontal": ["planning", "architecture", "goal_selection"],
        "thalamus": ["routing", "approval", "context_switch"],
        "hippocampus": ["memory_read", "memory_write", "resume"],
        "amygdala": ["blocked", "risk", "secret_guard"],
        "basal": ["tool_selection", "model_selection", "skill_selection"],
        "cerebellum": ["verifying", "self_correction", "checks_passed"],
        "motor": ["executing", "cli_action", "cloud_action"],
        "sensory": ["file_read", "provider_status", "logs"],
        "autonomic": ["health", "retry", "watchdog"],
        "callosum": ["event_bus", "cross_agent_sync", "replay"],
    }
    layer_no_by_code = {str(layer["code"]): layer["no"] for layer in ORGANISM_LAYERS}
    return {
        "contract_version": "organism-regions-v1",
        "endpoint": "/api/v1/organism/regions",
        "source": "agent-api-static-contract",
        "live": False,
        "regions": [
            {
                **region,
                "layer_no": layer_no_by_code.get(str(region["layer"])),
                "signals": signals.get(str(region["id"]), []),
                "hubs": [hub["id"] for hub in ORGANISM_HUBS if hub["layer"] == region["layer"]],
                "secret_output": False,
                "writes": False,
            }
            for region in ORGANISM_REGIONS
        ],
        "non_claims": ["region definitions only", "no provider calls", "no secret values"],
    }


def organism_safety_payload() -> dict[str, object]:
    return {
        "contract_version": "organism-safety-v1",
        "endpoint": "/api/v1/organism/safety",
        "source": "agent-api-policy-contract",
        "live": False,
        "source_kind": "policy_contract",
        "gates": [
            {"id": "secret_output", "status": "closed", "reason": "No endpoint may return token or secret values."},
            {"id": "provider_writes", "status": "closed", "reason": "Cloud provider writes require explicit owner gate."},
            {"id": "live_llm_calls", "status": "closed", "reason": "Direct provider calls are forbidden outside the LLM Gateway."},
            {"id": "live_mcp_writes", "status": "closed", "reason": "MCP write tools require explicit owner gate."},
            {"id": "production_deploy", "status": "closed", "reason": "Production deploy/release promotion is not claimed."},
            {"id": "main_push", "status": "closed", "reason": "Main-branch writes require review gate."},
        ],
        "data_rules": {
            "no_fake_live": True,
            "missing_backend_state": "spec_only_or_blocked",
            "secret_output": False,
            "writes": False,
            "provider_write": False,
            "production_deploy_claimed": False,
        },
        "non_claims": ["policy status only", "no permission expansion", "no live provider call"],
    }


@app.get("/api/v1/organism/contract")
def organism_contract() -> dict[str, object]:
    return organism_contract_payload()


@app.get("/api/v1/organism/topology")
def organism_topology() -> dict[str, object]:
    return organism_topology_payload()


@app.get("/api/v1/organism/live-state")
def organism_live_state() -> dict[str, object]:
    return organism_live_state_payload()


@app.get("/api/v1/organism/events")
def organism_events(run_id: str | None = Query(default=None, max_length=96)) -> dict[str, object]:
    return organism_events_payload(run_id)


@app.get("/api/v1/organism/replay")
def organism_replay(run_id: str | None = Query(default=None, max_length=96)) -> dict[str, object]:
    return organism_replay_payload(run_id)


@app.get("/api/v1/organism/regions")
def organism_regions() -> dict[str, object]:
    return organism_regions_payload()


@app.get("/api/v1/organism/safety")
def organism_safety() -> dict[str, object]:
    return organism_safety_payload()


@app.get("/api/v1/workspace/wiring")
def workspace_wiring() -> dict[str, object]:
    return workspace_wiring_payload()


@app.get("/api/v1/workspace/vertical-stack")
def workspace_vertical_stack() -> dict[str, object]:
    return workspace_vertical_stack_payload()


@app.get("/api/v1/design/reference-contract")
def design_reference_contract() -> dict[str, object]:
    return reference_design_contract_payload()


@app.get("/api/v1/platform/verify")
def platform_verify() -> dict[str, object]:
    return platform_verify_payload()


def platform_inventory_payload() -> dict[str, object]:
    agent_api_routes = len([route for route in app.routes if getattr(route, "methods", None)])
    return {
        "contract_version": "platform-inventory-v1",
        "endpoint": "/api/v1/platform/inventory",
        "evidence_ref": "platform_inventory_visible",
        "source": "agent-api-runtime-introspection",
        "live": False,
        "writes": False,
        "secret_output": False,
        "backend": {
            "services": 5,
            "workers": 2,
            "agent_api_routes": agent_api_routes,
            "agent_api_page_surfaced_endpoints": 130,
        },
        "capabilities": {
            "llm_models_catalog": 12,
            "agent_profiles": 4,
            "live_agent_profiles": 12,
            "skills": len(ORGANISM_SKILLS),
            "mcp_tools": len(ORGANISM_TOOLS),
            "cloud_providers": 8,
            "safety_gates": len(ORGANISM_CLOSED_GATES),
            "brain_regions": 10,
            "capability_hubs": 8,
        },
        "workspace": {"pages": 22, "architecture_layers": 7},
        "frontend": {"pages": 25, "components": 12, "lib_modules": 7, "api_routes": 12, "e2e_specs": 4},
        "verification": {"verifier_scripts": 191, "python_verifiers": 6, "browser_proof_scripts": 2},
        "infrastructure": {"compose_files": 2, "fly_configs": 6, "dockerfiles": 6, "nginx_confs": 2},
        "non_claims": [
            "Counts are a runtime inventory snapshot, not live metrics.",
            "Engine artifacts (workers, verifiers, infrastructure) are functional but are not page data sources.",
            "DEV-ONLY; no hosted/production claim, no secret output.",
        ],
    }


@app.get("/api/v1/platform/inventory")
def platform_inventory() -> dict[str, object]:
    return platform_inventory_payload()


@app.get("/api/v1/clouds/render-offload")
def cloud_render_offload() -> dict[str, object]:
    return cloud_render_offload_state()


@app.get("/api/v1/clouds/render-offload/contract")
def cloud_render_offload_contract() -> dict[str, object]:
    return cloud_render_offload_contract_payload()


@app.get("/api/v1/phase6/3d-camera-lighting/contract")
def phase6_3d_camera_lighting_runtime_contract() -> dict[str, object]:
    return phase6_3d_camera_lighting_runtime_contract_payload()


@app.get("/api/v1/phase6/3d-gameplay-state/contract")
def phase6_3d_gameplay_state_runtime_contract() -> dict[str, object]:
    return phase6_3d_gameplay_state_runtime_contract_payload()


@app.get("/api/v1/phase6/3d-asset-policy/contract")
def phase6_3d_asset_policy_runtime_contract() -> dict[str, object]:
    return phase6_3d_asset_policy_runtime_contract_payload()


@app.get("/api/v1/phase6/3d-save-load/contract")
def phase6_3d_save_load_runtime_contract() -> dict[str, object]:
    return phase6_3d_save_load_runtime_contract_payload()


@app.get("/api/v1/phase6/3d-accessibility/contract")
def phase6_3d_accessibility_runtime_contract() -> dict[str, object]:
    return phase6_3d_accessibility_runtime_contract_payload()


@app.get("/api/v1/phase6/3d-netcode/contract")
def phase6_3d_netcode_loopback_runtime_contract() -> dict[str, object]:
    return phase6_3d_netcode_loopback_runtime_contract_payload()


@app.get("/api/v1/phase6/local-scoreboard-performance/contract")
def phase6_local_scoreboard_performance_runtime_contract() -> dict[str, object]:
    return phase6_local_scoreboard_performance_runtime_contract_payload()


@app.get("/api/v1/clouds/deployment-preflight")
def cloud_deployment_preflight() -> dict[str, object]:
    return cloud_deployment_preflight_state()


@app.get("/api/v1/clouds/deployment-preflight/contract")
def cloud_deployment_preflight_contract() -> dict[str, object]:
    return cloud_deployment_preflight_payload()


@app.get("/api/v1/clouds/go-live-readiness")
def cloud_go_live_readiness() -> dict[str, object]:
    return go_live_readiness_state()


@app.get("/api/v1/clouds/go-live-readiness/contract")
def cloud_go_live_readiness_contract() -> dict[str, object]:
    return go_live_readiness_contract_payload()


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


@app.get("/api/v1/devops/workflow-dispatch/plan/contract")
def workflow_dispatch_plan_contract() -> dict[str, object]:
    return workflow_dispatch_plan_surface_contract_payload()


@app.get("/api/v1/devops/workflow-dispatch/validate/contract")
def workflow_dispatch_validate_contract() -> dict[str, object]:
    return workflow_dispatch_validate_surface_contract_payload()


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
    configured_checks = {
        "postgres": (check_postgres, bool(os.getenv("DATABASE_URL"))),
        "redis": (check_redis, bool(os.getenv("REDIS_URL"))),
        "agent_worker": (check_agent_worker, bool(os.getenv("REDIS_URL"))),
        "memory_worker": (check_memory_worker, bool(os.getenv("REDIS_URL"))),
        "mcp_gateway": (check_mcp, bool(os.getenv("MCP_GATEWAY_URL"))),
        "llm_gateway": (check_llm_gateway, bool(os.getenv("LLM_GATEWAY_URL"))),
    }
    for name, (checker, configured) in configured_checks.items():
        if not configured:
            overall = "degraded"
            services[name] = {"status": "unavailable", "reason": "not_configured"}
            continue
        try:
            services[name] = checker()
        except Exception as exc:
            overall = "degraded"
            services[name] = {"status": "down", "error_type": type(exc).__name__}

    try:
        budget_state = get_budget_state()
        budget_payload: dict[str, object] = {
            "level": budget_state.level,
            "spent_percentage": budget_state.spent_percentage,
            "total_cost_cents": budget_state.total_cost_cents,
            "budget_limit_cents": budget_state.budget_limit_cents,
            "allow_new_calls": budget_state.allow_new_calls,
        }
    except Exception as exc:
        overall = "degraded"
        budget_payload = {
            "level": "unavailable",
            "spent_percentage": None,
            "total_cost_cents": None,
            "budget_limit_cents": None,
            "allow_new_calls": False,
            "source_kind": "database_unavailable",
            "error_type": type(exc).__name__,
        }

    try:
        infra_budget_state = get_infra_budget_state()
        infra_budget_payload: dict[str, object] = {
            "level": infra_budget_state.level,
            "spent_percentage": infra_budget_state.spent_percentage,
            "projected_cost_cents": infra_budget_state.projected_cost_cents,
            "budget_limit_cents": infra_budget_state.budget_limit_cents,
            "allow_new_infra": infra_budget_state.allow_new_infra,
            "live_verified": infra_budget_state.live_verified,
            "source": infra_budget_state.source,
        }
    except Exception as exc:
        overall = "degraded"
        infra_budget_payload = {
            "level": "unavailable",
            "spent_percentage": None,
            "projected_cost_cents": None,
            "budget_limit_cents": None,
            "allow_new_infra": False,
            "live_verified": False,
            "source": "unavailable",
            "error_type": type(exc).__name__,
        }
    # Liveness must never 500 because the progress manifest / gate data is missing or unreadable
    # (e.g. a hosted image without the bind-mounted manifest). Degrade instead of crashing.
    try:
        gates = external_gate_state()
    except Exception as exc:
        overall = "degraded"
        gates = {
            "status": "unavailable",
            "configured_count": 0,
            "total_count": 0,
            "local_execution_allowed": False,
            "error": str(exc),
        }
    return {
        "status": overall,
        "service": "agent-api",
        "time": datetime.now(timezone.utc).isoformat(),
        "applied_migrations": getattr(app.state, "applied_migrations", []),
        "services": services,
        "budget": budget_payload,
        "infra_budget": infra_budget_payload,
        "external_gates": {
            "status": gates["status"],
            "configured_count": gates["configured_count"],
            "total_count": gates["total_count"],
            "local_execution_allowed": gates["local_execution_allowed"],
        },
    }


@app.get("/api/v1/health/contract")
def health_contract() -> dict[str, object]:
    return health_contract_payload()


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


@app.get("/api/v1/session/stream/contract")
def session_stream_contract() -> dict[str, object]:
    return session_stream_surface_contract_payload()


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
    task_projection, session_projection = load_recent_correlation_projection(
        [record.task_id for record in records],
        [str(record.session_id) for record in records],
    )
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
        elif latest and latest.status in {"failed", "escalated", "abandoned_after_queue_drain"}:
            status = "error"
        else:
            status = "idle"
        latest_correlation = task_projection.get(latest.task_id, {}) if latest else {}
        if not latest_correlation and latest:
            latest_correlation = session_projection.get(str(latest.session_id), {})
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
                "retries": selected.retry_count if selected else 0,
                "started_at": selected.created_at if selected else None,
                "updated_at": selected.updated_at if selected else None,
                "latest_task_id": latest.task_id if latest else None,
                "latest_task_type": latest.task_type if latest else None,
                "latest_status": latest.status if latest else "none",
                "latest_trace_id": (
                    latest_correlation.get("trace_id")
                    or (latest.trace_id if latest else None)
                ),
                "latest_request_id": latest_correlation.get("request_id") if latest else None,
                "latest_correlation_evidence_ref": latest_correlation.get("correlation_evidence_ref") if latest else None,
                "latest_audit_feed_evidence_ref": latest_correlation.get("audit_feed_evidence_ref") if latest else None,
                "latest_result": latest.result if latest else None,
                "latest_error": latest.error if latest else None,
                "latest_retry_count": latest.retry_count if latest else 0,
                "latest_max_retries": latest.max_retries if latest else 0,
            }
        )
    return {"agents": agents, "queue_depth": queue_depth(), "queue_depth_by_priority": queue_depth_by_priority()}


@app.get("/api/v1/tasks/recent")
def recent_tasks(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    records = list_recent_tasks(limit=limit)
    task_projection, session_projection = load_recent_correlation_projection(
        [record.task_id for record in records],
        [str(record.session_id) for record in records],
    )
    return {
        "queue_depth": queue_depth(),
        "queue_depth_by_priority": queue_depth_by_priority(),
        "tasks": [
            {
                "task_id": record.task_id,
                "project_id": record.project_id,
                "session_id": record.session_id,
                "trace_id": (task_projection.get(record.task_id, {}) or session_projection.get(str(record.session_id), {})).get("trace_id") or record.trace_id,
                "request_id": (task_projection.get(record.task_id, {}) or session_projection.get(str(record.session_id), {})).get("request_id"),
                "correlation_evidence_ref": (task_projection.get(record.task_id, {}) or session_projection.get(str(record.session_id), {})).get("correlation_evidence_ref"),
                "audit_feed_evidence_ref": (task_projection.get(record.task_id, {}) or session_projection.get(str(record.session_id), {})).get("audit_feed_evidence_ref"),
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


@app.get("/api/v1/tasks/recent/contract")
def recent_tasks_contract() -> dict[str, object]:
    return recent_tasks_contract_payload()


@app.get("/api/v1/agents/status/contract")
def agent_status_contract() -> dict[str, object]:
    return agent_status_contract_payload()


@app.get("/api/v1/sessions/recent/contract")
def recent_sessions_contract() -> dict[str, object]:
    return recent_sessions_contract_payload()


@app.get("/api/v1/sessions/history/contract")
def session_history_contract() -> dict[str, object]:
    return session_history_contract_payload()


@app.get("/api/v1/audit/recent/contract")
def recent_audit_contract() -> dict[str, object]:
    return audit_feed_contract_payload()


@app.get("/api/v1/audit/mcp/contract")
def recent_mcp_audit_contract() -> dict[str, object]:
    return mcp_audit_feed_contract_payload()


@app.get("/api/v1/memory/consolidation/contract")
def memory_consolidation_contract() -> dict[str, object]:
    return memory_consolidation_contract_payload()


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
    latest_task_by_session_id: dict[str, object] = {}
    recent_task_records = list_recent_tasks(limit=max(limit * 20, 200))
    for record in recent_task_records:
        session_id = str(record.session_id)
        if session_id not in latest_task_by_session_id:
            latest_task_by_session_id[session_id] = record
    _, session_projection = load_recent_correlation_projection(
        [record.task_id for record in recent_task_records],
        [str(row[0]) for row in rows],
    )
    return {
        "sessions": [
            {
                "session_id": str(row[0]),
                "project_id": row[1],
                "started_at": row[2].isoformat() if row[2] else None,
                "status": row[3],
                "trace_id": session_projection.get(str(row[0]), {}).get("trace_id"),
                "request_id": session_projection.get(str(row[0]), {}).get("request_id"),
                "correlation_evidence_ref": session_projection.get(str(row[0]), {}).get("correlation_evidence_ref"),
                "audit_feed_evidence_ref": session_projection.get(str(row[0]), {}).get("audit_feed_evidence_ref"),
                "latest_task_id": row[4] or row[5] or (
                    latest_task_by_session_id[str(row[0])].task_id
                    if str(row[0]) in latest_task_by_session_id
                    else None
                ),
                "latest_task_status": (
                    latest_task_by_session_id[str(row[0])].status
                    if str(row[0]) in latest_task_by_session_id
                    else None
                ),
                "latest_error": (
                    latest_task_by_session_id[str(row[0])].error
                    if str(row[0]) in latest_task_by_session_id
                    else None
                ),
                "latest_retry_count": (
                    latest_task_by_session_id[str(row[0])].retry_count
                    if str(row[0]) in latest_task_by_session_id
                    else None
                ),
                "latest_max_retries": (
                    latest_task_by_session_id[str(row[0])].max_retries
                    if str(row[0]) in latest_task_by_session_id
                    else None
                ),
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
    task_projection, _ = load_recent_correlation_projection(
        [record.task_id for record in task_records],
        [session_uuid],
    )
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
                "trace_id": task_projection.get(record.task_id, {}).get("trace_id") or record.trace_id,
                "request_id": task_projection.get(record.task_id, {}).get("request_id"),
                "correlation_evidence_ref": task_projection.get(record.task_id, {}).get("correlation_evidence_ref"),
                "audit_feed_evidence_ref": task_projection.get(record.task_id, {}).get("audit_feed_evidence_ref"),
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
                "request_id": (row[4] or {}).get("request_id"),
                "trace_id": (row[4] or {}).get("trace_id") or (str(row[3]) if row[3] else None),
                "correlation_evidence_ref": (row[4] or {}).get(
                    "correlation_evidence_ref",
                    "request_id_audit_correlation",
                ),
                "audit_feed_evidence_ref": "request_id_audit_feed_visible",
                "details": row[4] or {},
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
            for row in rows
        ]
    }


@app.get("/api/v1/escalations/contract")
def escalation_contract() -> dict[str, object]:
    return escalation_contract_payload()


@app.get("/api/v1/memory/search/contract")
def memory_search_contract() -> dict[str, object]:
    return memory_search_contract_payload()


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


def workspace_artifact_row(row: tuple[object, ...]) -> dict[str, object]:
    details = row[3] if isinstance(row[3], dict) else {}
    return {
        "id": str(row[0]),
        "created_at": row[1].isoformat() if row[1] else None,
        "session_id": str(row[2]) if row[2] else None,
        "project_id": str(details.get("project_id", "")),
        "source_page": str(details.get("source_page", "")),
        "artifact_type": str(details.get("artifact_type", "")),
        "title": str(details.get("title", "")),
        "summary": str(details.get("summary", "")),
        "run_id": details.get("run_id"),
        "status": str(details.get("status", "ready")),
        "evidence_ref": str(details.get("evidence_ref", WORKSPACE_ARTIFACT_EVIDENCE_REF)),
        "metadata": details.get("metadata", {}),
    }


@app.get("/api/v1/workspace/artifacts/contract")
def workspace_artifacts_contract() -> dict[str, object]:
    return {
        "contract_version": WORKSPACE_ARTIFACT_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/workspace/artifacts",
        "runtime_endpoint": "POST /api/v1/workspace/artifacts",
        "evidence_ref": WORKSPACE_ARTIFACT_EVIDENCE_REF,
        "storage": "audit_log",
        "event_type": "workspace_artifact_created",
        "mode": "DEV-ONLY local artifact registry",
        "writes": "audit-only local persistence",
        "live_provider_calls": False,
        "live_mcp_writes": False,
        "secret_output": False,
        "production_deploy": False,
    }


@app.get("/api/v1/workspace/artifacts")
def workspace_artifacts(
    project_id: str = Query(default="goal-b-local", min_length=1, max_length=255),
    limit: int = Query(default=20, ge=1, le=100),
) -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT id, created_at, session_id, details
            FROM audit_log
            WHERE event_type = 'workspace_artifact_created'
              AND COALESCE(details->>'project_id', '') = %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (project_id, limit),
        ).fetchall()
    return {
        "contract_version": WORKSPACE_ARTIFACT_CONTRACT_VERSION,
        "evidence_ref": WORKSPACE_ARTIFACT_EVIDENCE_REF,
        "mode": "DEV-ONLY local artifact registry",
        "artifacts": [workspace_artifact_row(row) for row in rows],
        "non_claims": [
            "Artifact registry entries are local audit evidence only.",
            "No cloud mutation, provider write, registry push, or production deployment is performed.",
            "Secret values are redacted before persistence.",
        ],
    }


@app.post("/api/v1/workspace/artifacts", status_code=201)
def create_workspace_artifact(request: WorkspaceArtifactRequest, http_request: Request) -> dict[str, object]:
    try:
        session_id: str | None = str(UUID(str(request.session_id))) if request.session_id else None
    except (TypeError, ValueError):
        session_id = None
    trace_id = getattr(http_request.state, "trace_id", None) or request.run_id or f"workspace-artifact-{uuid4()}"
    details = redact_json(
        {
            "contract_version": WORKSPACE_ARTIFACT_CONTRACT_VERSION,
            "project_id": request.project_id,
            "source_page": request.source_page,
            "artifact_type": request.artifact_type,
            "title": redact_text(request.title),
            "summary": redact_text(request.summary),
            "session_id": session_id,
            "run_id": request.run_id,
            "status": request.status,
            "metadata": request.metadata,
            "trace_id": trace_id,
            "evidence_ref": WORKSPACE_ARTIFACT_EVIDENCE_REF,
            "live_provider_calls": False,
            "live_mcp_writes": False,
            "secret_output": False,
            "production_deploy": False,
        }
    )
    with psycopg.connect(database_url(), autocommit=True) as conn:
        project_uuid = find_or_create_project_uuid(conn, request.project_id)
        memory_id = insert_memory_entry(
            conn,
            project_uuid,
            session_id,
            f"Goal B artifact {request.source_page} {request.artifact_type}: {request.title}. {request.summary}",
            {
                "source": "goal_b_workspace_artifact_registry",
                "artifact_type": request.artifact_type,
                "source_page": request.source_page,
                "run_id": request.run_id,
            },
        )
        details["memory_id"] = memory_id
        row = conn.execute(
            """
            INSERT INTO audit_log(event_type, session_id, details, severity)
            VALUES ('workspace_artifact_created', %s, %s::jsonb, 'info')
            RETURNING id, created_at
            """,
            (session_id, Json(details)),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=503, detail="workspace artifact insert failed")
    return {
        "artifact": workspace_artifact_row((row[0], row[1], session_id, details)),
        "contract_version": WORKSPACE_ARTIFACT_CONTRACT_VERSION,
        "evidence_ref": WORKSPACE_ARTIFACT_EVIDENCE_REF,
        "audit_persisted": True,
        "live_provider_calls": False,
        "live_mcp_writes": False,
        "secret_output": False,
        "production_deploy": False,
    }


@app.get("/api/v1/tools/read-only/execute/contract")
def read_only_tool_execute_contract() -> dict[str, object]:
    return {
        "contract_version": READ_ONLY_TOOL_EXECUTE_CONTRACT_VERSION,
        "endpoint": "POST /api/v1/tools/read-only/execute",
        "supported_tools": ["memory_read", "task_router"],
        "evidence_ref": READ_ONLY_TOOL_EXECUTE_EVIDENCE_REF,
        "mode": "read-only local tool execution",
        "audit_event_type": "read_only_tool_executed",
        "live_mcp_writes": False,
        "writes": "audit-only local persistence",
        "secret_output": False,
        "production_deploy": False,
    }


@app.post("/api/v1/tools/read-only/execute")
def execute_read_only_tool(request: ReadOnlyToolExecuteRequest, http_request: Request) -> dict[str, object]:
    trace_id = getattr(http_request.state, "trace_id", None) or request.trace_id or f"readonly-tool-{uuid4()}"
    if request.tool_id == "memory_read":
        payload: dict[str, object] = {
            "tool_id": request.tool_id,
            "query": redact_text(request.query),
            "results": [item.model_dump() for item in search_memory(request.project_id, request.query, 5)],
            "search_mode": "lexical_fallback",
        }
    else:
        payload = {
            "tool_id": request.tool_id,
            "query": redact_text(request.query),
            "queue_depth": queue_depth(),
            "queue_depth_by_priority": queue_depth_by_priority(),
            "recent_tasks": [
                {
                    "task_id": record.task_id,
                    "agent_type": record.agent_type,
                    "task_type": record.task_type,
                    "status": record.status,
                    "priority": record.priority,
                }
                for record in list_recent_tasks(limit=8)
            ],
        }
    details = redact_json(
        {
            "contract_version": READ_ONLY_TOOL_EXECUTE_CONTRACT_VERSION,
            "project_id": request.project_id,
            "tool_id": request.tool_id,
            "trace_id": trace_id,
            "evidence_ref": READ_ONLY_TOOL_EXECUTE_EVIDENCE_REF,
            "live_mcp_writes": False,
            "secret_output": False,
            "payload_summary": {
                "result_count": len(payload.get("results", [])) if request.tool_id == "memory_read" else len(payload.get("recent_tasks", [])),
                "query": redact_text(request.query),
            },
        }
    )
    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute(
            """
            INSERT INTO audit_log(event_type, details, severity)
            VALUES ('read_only_tool_executed', %s::jsonb, 'info')
            RETURNING id, created_at
            """,
            (Json(details),),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=503, detail="read-only tool audit insert failed")
    return {
        "contract_version": READ_ONLY_TOOL_EXECUTE_CONTRACT_VERSION,
        "status": "success",
        "tool_id": request.tool_id,
        "trace_id": trace_id,
        "evidence_ref": READ_ONLY_TOOL_EXECUTE_EVIDENCE_REF,
        "audit_event_id": str(row[0]),
        "audit_created_at": row[1].isoformat() if row[1] else None,
        "audit_persisted": True,
        "live_provider_calls": False,
        "live_mcp_writes": False,
        "secret_output": False,
        "production_deploy": False,
        "result": payload,
    }


@app.get("/api/v1/memory/purge/contract")
def memory_purge_contract() -> dict[str, object]:
    return memory_purge_contract_payload()


@app.get("/api/v1/memory/purge/jobs/contract")
def memory_purge_job_status_contract() -> dict[str, object]:
    return memory_purge_job_status_surface_contract_payload()


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


@app.get("/api/v1/costs/contract")
def costs_contract() -> dict[str, object]:
    return costs_contract_payload()


@app.get("/api/v1/costs/export/contract")
def cost_export_contract() -> dict[str, object]:
    return cost_export_contract_payload()


@app.get("/api/v1/system/fallback/contract")
def system_fallback_contract() -> dict[str, object]:
    return system_fallback_contract_payload()


@app.get("/api/v1/agent-activity/contract")
def agent_activity_contract() -> dict[str, object]:
    return agent_activity_contract_payload()


def correlation_projection_from_details(
    details: object,
    session_id: str | None = None,
    fallback_trace_id: str | None = None,
) -> dict[str, object]:
    if not isinstance(details, dict):
        details = {}
    request_id = details.get("request_id")
    trace_id = details.get("trace_id") or details.get("thread_id") or fallback_trace_id or session_id
    correlation_evidence_ref = details.get("correlation_evidence_ref")
    if not correlation_evidence_ref and (request_id or trace_id):
        correlation_evidence_ref = "request_id_audit_correlation"
    return {
        "request_id": request_id,
        "trace_id": trace_id,
        "correlation_evidence_ref": correlation_evidence_ref,
        "audit_feed_evidence_ref": (
            "request_id_audit_feed_visible"
            if request_id or trace_id
            else None
        ),
    }


def load_recent_correlation_projection(
    task_ids: list[str],
    session_ids: list[str],
) -> tuple[dict[str, dict[str, object]], dict[str, dict[str, object]]]:
    normalized_task_ids = [task_id for task_id in task_ids if task_id]
    normalized_session_ids = [session_id for session_id in session_ids if session_id]
    if not normalized_task_ids and not normalized_session_ids:
        return {}, {}

    predicates: list[str] = []
    params: list[object] = []
    if normalized_task_ids:
        predicates.append("details->>'task_id' = ANY(%s)")
        params.append(normalized_task_ids)
    if normalized_session_ids:
        predicates.append("CAST(session_id AS TEXT) = ANY(%s)")
        params.append(normalized_session_ids)

    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            f"""
            SELECT session_id, details
            FROM audit_log
            WHERE {' OR '.join(predicates)}
            ORDER BY created_at DESC
            LIMIT 500
            """,
            tuple(params),
        ).fetchall()
        session_rows = (
            conn.execute(
                """
                SELECT id, metadata
                FROM agent_sessions
                WHERE CAST(id AS TEXT) = ANY(%s)
                """,
                (normalized_session_ids or [""],),
            ).fetchall()
            if normalized_session_ids
            else []
        )

    task_projection: dict[str, dict[str, object]] = {}
    session_projection: dict[str, dict[str, object]] = {}
    for row in rows:
        session_id = str(row[0]) if row[0] else None
        details = row[1] or {}
        if not isinstance(details, dict):
            details = {}
        task_id = details.get("task_id")
        projection = correlation_projection_from_details(details, session_id=session_id)
        if task_id and task_id not in task_projection:
            task_projection[task_id] = projection
        if session_id and session_id not in session_projection:
            session_projection[session_id] = projection
    for row in session_rows:
        session_id = str(row[0]) if row[0] else None
        metadata = row[1] or {}
        if not isinstance(metadata, dict):
            metadata = {}
        projection = correlation_projection_from_details(metadata, session_id=session_id)
        if session_id and session_id not in session_projection:
            session_projection[session_id] = projection
    return task_projection, session_projection


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
    task_status = details.get("status")
    if not task_status:
        if row[1] == "task_escalated":
            task_status = "escalated"
        elif row[1] == "task_abandoned_after_queue_drain":
            task_status = "abandoned_after_queue_drain"
    trace_id = str(row[7] or "none")
    correlation = correlation_projection_from_details(
        details,
        session_id=str(row[3]) if row[3] else None,
        fallback_trace_id=trace_id,
    )
    return {
        "id": str(row[0]),
        "event_type": row[1],
        "user_id": row[2],
        "session_id": str(row[3]) if row[3] else None,
        "details": details,
        "created_at": row[5].isoformat() if row[5] else None,
        "severity": row[6],
        "trace_id": correlation["trace_id"],
        "request_id": correlation["request_id"],
        "correlation_evidence_ref": correlation["correlation_evidence_ref"],
        "audit_feed_evidence_ref": correlation["audit_feed_evidence_ref"],
        "agent_type": row[8],
        "task_id": details.get("task_id"),
        "task_status": task_status,
        "retry_count": details.get("retry_count"),
        "max_retries": details.get("max_retries"),
        "error": details.get("error"),
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


def budget_contract_payload() -> dict[str, object]:
    state = get_budget_state()
    return {
        "contract_version": "budget-surface-v1",
        "mode": "llm_budget_runtime_projection",
        "endpoint": "GET /api/v1/budget/contract",
        "runtime_endpoint": "GET /api/v1/budget",
        "required_top_level_fields": [
            "total_cost_cents",
            "budget_limit_cents",
            "budget_spent_percentage",
            "level",
            "allow_new_calls",
        ],
        "supported_levels": ["ok", "warning", "critical"],
        "budget_limit_cents": state.budget_limit_cents,
        "evidence_ref": "budget_contract_runtime_visible",
        "policy_checks": [
            "Budget surface remains a read-only runtime projection.",
            "Budget level is derived from live runtime budget state.",
            "Budget surface does not claim live provider execution is enabled.",
        ],
        "non_claims": [
            "This contract does not claim live provider calls are enabled.",
            "This contract does not authorize production deployment.",
        ],
    }


@app.get("/api/v1/budget/contract")
def budget_contract() -> dict[str, object]:
    return budget_contract_payload()


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
        "csp_report_contract": {
            "contract_version": CSP_REPORT_CONTRACT_VERSION,
            "endpoint": "POST /api/v1/security/csp/report",
            "evidence_ref": CSP_REPORT_EVIDENCE_REF,
            "audit_evidence_ref": CSP_REPORT_AUDIT_EVIDENCE_REF,
        },
        "csrf_origin_contract": {
            "contract_version": CSRF_ORIGIN_CONTRACT_VERSION,
            "endpoint": "GET /api/v1/security/csrf/contract",
            "evidence_ref": CSRF_ORIGIN_EVIDENCE_REF,
            "audit_evidence_ref": CSRF_ORIGIN_AUDIT_EVIDENCE_REF,
        },
        "cross_origin_response_contract": {
            "contract_version": CROSS_ORIGIN_RESPONSE_CONTRACT_VERSION,
            "endpoint": "GET /api/v1/security/cross-origin/contract",
            "evidence_ref": CROSS_ORIGIN_RESPONSE_EVIDENCE_REF,
        },
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
            "Every response keeps opener and resource access same-origin by default.",
            "CSP reports are size-bounded, allowlisted, redacted, and audit-persisted before acceptance.",
            "Unsafe browser requests fail closed on cross-site Fetch Metadata, null Origin, or Origin mismatch.",
        ],
        "evidence_refs": {
            "contract_visible": "security_headers_contract_visible",
            "headers_enforced": "security_headers_enforced",
            "same_origin_cors_policy": "security_headers_same_origin_policy",
            "ui_visible": "security_headers_ui_visible",
            "csp_report_visible": CSP_REPORT_EVIDENCE_REF,
            "csrf_origin_guard_visible": CSRF_ORIGIN_EVIDENCE_REF,
            "cross_origin_response_guard_visible": CROSS_ORIGIN_RESPONSE_EVIDENCE_REF,
        },
    }


@app.get("/api/v1/security/headers/contract")
def security_headers_contract() -> dict[str, object]:
    return security_headers_contract_payload()


def cross_origin_response_contract_payload() -> dict[str, object]:
    return {
        "contract_version": CROSS_ORIGIN_RESPONSE_CONTRACT_VERSION,
        "mode": "same_origin_opener_and_resource_guard",
        "endpoint": "GET /api/v1/security/cross-origin/contract",
        "evidence_ref": CROSS_ORIGIN_RESPONSE_EVIDENCE_REF,
        "enforced_by": "security_headers_middleware",
        "applies_to": "all Agent API HTTP responses including error envelopes",
        "headers": {
            "Cross-Origin-Opener-Policy": SECURITY_HEADERS["Cross-Origin-Opener-Policy"],
            "Cross-Origin-Resource-Policy": SECURITY_HEADERS["Cross-Origin-Resource-Policy"],
            "X-Permitted-Cross-Domain-Policies": SECURITY_HEADERS["X-Permitted-Cross-Domain-Policies"],
        },
        "cors_policy": {
            "public_cross_origin_enabled": False,
            "attacker_origin_reflected": False,
            "credentials_allowed_cross_origin": False,
        },
        "phase3_progress_after_proof": 43,
        "policy_checks": [
            "Same-origin requests receive the expected COOP and CORP headers.",
            "Error responses receive the same cross-origin response headers.",
            "Untrusted Origin values are never reflected in Access-Control-Allow-Origin.",
            "The guard performs no provider, MCP, state, or production write.",
        ],
        "provider_write": False,
        "live_mcp_write": False,
        "state_write": False,
        "production_deploy": False,
    }


@app.get("/api/v1/security/cross-origin/contract")
def cross_origin_response_contract() -> dict[str, object]:
    return cross_origin_response_contract_payload()


def csrf_origin_contract_payload() -> dict[str, object]:
    return {
        "contract_version": CSRF_ORIGIN_CONTRACT_VERSION,
        "mode": "fetch_metadata_and_same_origin_guard",
        "endpoint": "GET /api/v1/security/csrf/contract",
        "probe_endpoint": "POST /api/v1/security/csrf/probe",
        "evidence_ref": CSRF_ORIGIN_EVIDENCE_REF,
        "audit_event_type": "security_csrf_request_rejected",
        "audit_evidence_ref": CSRF_ORIGIN_AUDIT_EVIDENCE_REF,
        "protected_methods": ["POST", "PUT", "PATCH", "DELETE"],
        "protected_path_prefix": "/api/",
        "safe_methods": sorted(_CSRF_SAFE_METHODS),
        "rejection_status_code": 403,
        "rejection_error": "csrf_origin_rejected",
        "phase3_progress_after_proof": 42,
        "rejection_reasons": ["fetch_metadata_cross_site", "invalid_or_null_origin", "origin_mismatch"],
        "same_origin_browser_requests_allowed": True,
        "non_browser_missing_metadata_allowed": True,
        "cross_site_browser_requests_allowed": False,
        "null_origin_allowed": False,
        "raw_origin_persisted": False,
        "cookie_or_authorization_value_persisted": False,
        "live_external_forwarding": False,
        "policy_checks": [
            "Sec-Fetch-Site cross-site fails closed before route execution.",
            "Origin must exactly match the public request origin when supplied.",
            "Origin null and malformed origins fail closed.",
            "CLI and internal service calls without browser metadata remain compatible.",
            "Rejection audit stores only allowlisted metadata and never raw credential values.",
        ],
        "non_claims": [
            "This guard is defense in depth and does not replace authentication or authorization.",
            "No OAuth scope, provider write, live MCP write, deployment, or secret output is performed.",
            "Localhost proof remains DEV-ONLY and is not hosted production-auth proof.",
        ],
    }


@app.get("/api/v1/security/csrf/contract")
def csrf_origin_contract() -> dict[str, object]:
    return csrf_origin_contract_payload()


@app.post("/api/v1/security/csrf/probe")
def csrf_origin_probe() -> dict[str, object]:
    return {
        "contract_version": CSRF_ORIGIN_CONTRACT_VERSION,
        "status": "accepted_same_origin_or_non_browser",
        "evidence_ref": CSRF_ORIGIN_EVIDENCE_REF,
        "state_write": False,
        "provider_write": False,
        "live_mcp_write": False,
        "secret_output": False,
    }


_CSP_REPORT_STRING_FIELDS = {
    "document-uri": 500,
    "blocked-uri": 500,
    "violated-directive": 160,
    "effective-directive": 160,
    "original-policy": 1_000,
    "source-file": 500,
    "disposition": 40,
    "referrer": 500,
}
_CSP_REPORT_NUMBER_FIELDS = {"line-number", "column-number", "status-code"}
_CSP_REPORT_URI_FIELDS = {"document-uri", "blocked-uri", "source-file", "referrer"}
_CSP_REPORT_CONTENT_TYPES = {"application/csp-report", "application/json"}


def _csp_report_value(report: dict[str, object], canonical_name: str) -> object | None:
    aliases = (canonical_name, canonical_name.replace("-", "_"))
    for alias in aliases:
        if alias in report:
            return report[alias]
    return None


def sanitize_csp_report(report: dict[str, object]) -> dict[str, object]:
    sanitized: dict[str, object] = {}
    for field_name, max_length in _CSP_REPORT_STRING_FIELDS.items():
        value = _csp_report_value(report, field_name)
        if value is None:
            continue
        text = redact_text(str(value)).strip()
        if field_name in _CSP_REPORT_URI_FIELDS:
            text = re.split(r"[?#]", text, maxsplit=1)[0]
        sanitized[field_name] = text[:max_length]
    for field_name in _CSP_REPORT_NUMBER_FIELDS:
        value = _csp_report_value(report, field_name)
        if value is None:
            continue
        try:
            sanitized[field_name] = max(0, min(int(value), 2_147_483_647))
        except (TypeError, ValueError):
            continue
    return sanitized


def csp_report_contract_payload() -> dict[str, object]:
    return {
        "contract_version": CSP_REPORT_CONTRACT_VERSION,
        "mode": "same_origin_redacted_audit_sink",
        "endpoint": "POST /api/v1/security/csp/report",
        "evidence_ref": CSP_REPORT_EVIDENCE_REF,
        "audit_event_type": "security_csp_violation_reported",
        "audit_evidence_ref": CSP_REPORT_AUDIT_EVIDENCE_REF,
        "accepted_content_types": sorted(_CSP_REPORT_CONTENT_TYPES),
        "accepted_shapes": ["csp-report", "csp_report", "report"],
        "max_body_bytes": CSP_REPORT_MAX_BODY_BYTES,
        "stored_fields": sorted([*_CSP_REPORT_STRING_FIELDS, *_CSP_REPORT_NUMBER_FIELDS]),
        "privacy": {
            "uri_query_and_fragment_persisted": False,
            "user_agent_persisted": False,
            "cookies_or_credentials_persisted": False,
            "raw_report_persisted": False,
        },
        "policy_checks": [
            "Only allowlisted CSP fields are persisted.",
            "URI query strings and fragments are removed before persistence.",
            "Acceptance fails closed when the audit row cannot be persisted.",
            "No report is forwarded to an external collector.",
        ],
        "non_claims": [
            "No production incident response workflow is claimed.",
            "No third-party CSP collector is configured.",
            "No provider write, live MCP write, or secret output is performed.",
        ],
    }


def persist_csp_report_audit(details: dict[str, object]) -> str | None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            row = conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('security_csp_violation_reported', 'security', %s::jsonb, 'warning')
                RETURNING id
                """,
                (Json(redact_json(details)),),
            ).fetchone()
            return str(row[0]) if row else None
    except Exception:
        return None


@app.get("/api/v1/security/csp/contract")
def csp_report_contract() -> dict[str, object]:
    return csp_report_contract_payload()


@app.post("/api/v1/security/csp/report")
async def csp_report(request: Request) -> dict[str, object]:
    content_type = request.headers.get("content-type", "").split(";", maxsplit=1)[0].strip().lower()
    if content_type not in _CSP_REPORT_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail={
                "error": "unsupported_csp_report_content_type",
                "message": "CSP reports require application/csp-report or application/json.",
            },
        )
    raw_body = await request.body()
    if len(raw_body) > CSP_REPORT_MAX_BODY_BYTES:
        raise HTTPException(
            status_code=413,
            detail={"error": "csp_report_too_large", "message": "CSP report exceeds the 16384-byte limit."},
        )
    try:
        payload = json.loads(raw_body.decode("utf-8")) if raw_body else {}
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_csp_report", "message": "CSP report must be valid JSON."},
        ) from exc
    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=422,
            detail={"error": "invalid_csp_report_shape", "message": "CSP report body must be an object."},
        )
    report = next(
        (payload.get(key) for key in ("csp-report", "csp_report", "report") if isinstance(payload.get(key), dict)),
        None,
    )
    if not isinstance(report, dict):
        raise HTTPException(
            status_code=422,
            detail={"error": "missing_csp_report", "message": "CSP report wrapper is required."},
        )
    sanitized_report = sanitize_csp_report(report)
    if not sanitized_report:
        raise HTTPException(
            status_code=422,
            detail={"error": "empty_csp_report", "message": "CSP report has no supported fields."},
        )
    request_id = str(payload.get("request_id") or getattr(request.state, "request_id", "unknown"))[:255]
    trace_id = str(payload.get("trace_id") or getattr(request.state, "trace_id", "unknown"))[:255]
    details = {
        "contract_version": CSP_REPORT_CONTRACT_VERSION,
        "evidence_ref": CSP_REPORT_EVIDENCE_REF,
        "audit_evidence_ref": CSP_REPORT_AUDIT_EVIDENCE_REF,
        "request_id": redact_text(request_id),
        "trace_id": redact_text(trace_id),
        "report": sanitized_report,
        "live_external_report_forwarding": False,
        "secret_output": False,
    }
    audit_event_id = persist_csp_report_audit(details)
    if not audit_event_id:
        raise HTTPException(
            status_code=503,
            detail={"error": "csp_audit_unavailable", "message": "CSP report was not accepted because audit persistence failed."},
        )
    return {
        "status": "accepted",
        "contract_version": CSP_REPORT_CONTRACT_VERSION,
        "evidence_ref": CSP_REPORT_EVIDENCE_REF,
        "audit_evidence_ref": CSP_REPORT_AUDIT_EVIDENCE_REF,
        "audit_event_id": audit_event_id,
        "audit_persisted": True,
        "live_external_report_forwarding": False,
        "secret_output": False,
    }


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
        "public_surface_registry": [
            {
                "path": "/api/v1/agents/status",
                "request_field": "latest_request_id",
                "trace_field": "latest_trace_id",
                "correlation_field": "latest_correlation_evidence_ref",
                "audit_feed_field": "latest_audit_feed_evidence_ref",
                "supported_statuses": ["escalated", "abandoned_after_queue_drain"],
            },
            {
                "path": "/api/v1/agent-activity/recent",
                "request_field": "request_id",
                "trace_field": "trace_id",
                "correlation_field": "correlation_evidence_ref",
                "audit_feed_field": "audit_feed_evidence_ref",
                "supported_statuses": ["escalated", "abandoned_after_queue_drain"],
            },
            {
                "path": "/api/v1/tasks/recent",
                "request_field": "request_id",
                "trace_field": "trace_id",
                "correlation_field": "correlation_evidence_ref",
                "audit_feed_field": "audit_feed_evidence_ref",
                "supported_statuses": ["escalated", "abandoned_after_queue_drain"],
            },
            {
                "path": "/api/v1/sessions/recent",
                "request_field": "request_id",
                "trace_field": "trace_id",
                "correlation_field": "correlation_evidence_ref",
                "audit_feed_field": "audit_feed_evidence_ref",
                "supported_statuses": ["escalated", "abandoned_after_queue_drain"],
            },
            {
                "path": "/api/v1/sessions/{session_id}/history",
                "request_field": "request_id",
                "trace_field": "trace_id",
                "correlation_field": "correlation_evidence_ref",
                "audit_feed_field": "audit_feed_evidence_ref",
                "supported_statuses": ["escalated", "abandoned_after_queue_drain"],
            },
            {
                "path": "/api/v1/audit/recent",
                "request_field": "request_id",
                "trace_field": "trace_id",
                "correlation_field": "correlation_evidence_ref",
                "audit_feed_field": "audit_feed_evidence_ref",
                "supported_statuses": ["escalated", "abandoned_after_queue_drain"],
            },
            {
                "path": "/api/v1/escalations/recent",
                "request_field": "request_id",
                "trace_field": "trace_id",
                "correlation_field": "correlation_evidence_ref",
                "audit_feed_field": "audit_feed_evidence_ref",
                "supported_statuses": ["escalated"],
            },
        ],
        "applies_to": "all Agent API HTTP responses and structured error envelopes",
        "policy_checks": [
            "If x-request-id is supplied, the same value is returned in the response header.",
            "If no request id is supplied, the API generates one with prefix req-.",
            "Structured error envelopes include request_id and trace_id for support/audit correlation.",
            "Audited cost-export actions persist request_id and trace_id in audit_log.details.",
            "The request contract explicitly registers every public runtime surface that exposes top-level request, trace, correlation, and audit-feed evidence fields.",
            "The request contract explicitly lists which negative worker end states each registered public runtime surface supports.",
            "Every response includes X-Superbrain-Request-Contract.",
        ],
        "evidence_refs": {
            "contract_visible": "request_id_contract_visible",
            "header_roundtrip": "request_id_header_roundtrip",
            "error_envelope_correlation": "request_id_error_envelope_correlation",
            "audit_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
            "public_surface_registry": "request_id_public_surface_registry_visible",
            "negative_worker_state_registry": "request_id_negative_worker_state_registry_visible",
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
            "path": "/api/v1/internal/tasks",
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
            "No Fly.io live infrastructure state is claimed without FLY_API_TOKEN.",
        ],
    }


@app.get("/api/v1/layer-interfaces/contract")
def layer_interface_contract() -> dict[str, object]:
    return layer_interface_contract_payload()


def metrics_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "metrics-surface-v1",
        "mode": "prometheus_text_runtime_contract",
        "endpoint": "GET /api/v1/metrics/contract",
        "runtime_endpoint": "GET /api/v1/metrics",
        "content_type": "text/plain; version=0.0.4",
        "evidence_ref": "metrics_contract_runtime_visible",
        "required_metric_families": [
            "superbrain_project_progress_percent",
            "superbrain_budget_spent_percentage",
            "superbrain_prompt_rate_limit_capacity",
            "superbrain_session_llm_call_limit",
            "superbrain_infra_budget_spent_percentage",
            "superbrain_external_gate_configured",
            "superbrain_task_queue_depth",
            "superbrain_service_health",
            "superbrain_memory_entries_total",
            "superbrain_memory_consolidation_events_total",
            "superbrain_audit_events_total",
            "superbrain_mcp_tool_events_total",
        ],
        "required_policy_assertions": [
            "manifest-backed project progress remains visible in metrics",
            "budget and infra budget remain fail-closed visible",
            "queue depth and service health remain publicly visible",
            "memory and audit evidence remain runtime visible",
        ],
        "non_claims": [
            "This contract does not claim live provider execution.",
            "This contract does not claim production deployment.",
            "This contract does not mutate runtime state.",
        ],
    }


@app.get("/api/v1/metrics/contract")
def metrics_contract() -> dict[str, object]:
    return metrics_contract_payload()


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
            "path": "/api/v1/internal/tasks",
            "public_validation_path": "/api/v1/tasks/policy/validate",
            "status_path": "/api/v1/internal/tasks/{task_id}",
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
            "This endpoint is a configured Phase-1 projection unless FLY_API_TOKEN is configured.",
            "LLM/API provider spend is tracked separately and is not counted in the 20 EUR infrastructure limit.",
        ],
    }


def infra_budget_contract_payload() -> dict[str, object]:
    state = get_infra_budget_state()
    return {
        "contract_version": "infra-budget-surface-v1",
        "mode": "infrastructure_budget_runtime_projection",
        "endpoint": "GET /api/v1/infra/budget/contract",
        "runtime_endpoint": "GET /api/v1/infra/budget",
        "required_top_level_fields": [
            "projected_cost_cents",
            "budget_limit_cents",
            "warning_limit_cents",
            "budget_spent_percentage",
            "level",
            "allow_new_infra",
            "live_verified",
            "source",
            "items",
            "non_claims",
        ],
        "supported_levels": ["ok", "warning", "critical"],
        "budget_limit_cents": state.budget_limit_cents,
        "warning_limit_cents": state.warning_limit_cents,
        "supported_sources": ["projection", "fly_api_readonly", "fly_api_readonly_plus_plan_projection"],
        "required_item_fields": ["name", "monthly_cost_cents"],
        "evidence_ref": "infra_budget_contract_runtime_visible",
        "policy_checks": [
            "Infrastructure budget surface remains read-only.",
            "Infra budget source stays visible as projection or readonly Fly.io API evidence.",
            "Infra budget does not include LLM provider spend.",
        ],
        "non_claims": [
            "This contract does not claim production deployment is allowed.",
            "This contract does not claim LLM provider spend is included in the infra limit.",
        ],
    }


@app.get("/api/v1/infra/budget/contract")
def infra_budget_contract() -> dict[str, object]:
    return infra_budget_contract_payload()


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


def orchestrator_manifest_payload() -> dict[str, object]:
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


def orchestrator_manifest_contract_payload() -> dict[str, object]:
    manifest = orchestrator_manifest_payload()
    return {
        "contract_version": ORCHESTRATOR_MANIFEST_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/orchestrator/manifest",
        "runtime_fields": [
            "engine",
            "mode",
            "live_provider_calls",
            "checkpointing",
            "checkpoint_recovery_endpoint",
            "nodes",
            "max_global_retries",
            "forbidden_actions",
            "next_safe_step",
        ],
        "expected_values": {
            "engine": manifest["engine"],
            "mode": manifest["mode"],
            "live_provider_calls": manifest["live_provider_calls"],
            "checkpointing": manifest["checkpointing"],
            "max_global_retries": manifest["max_global_retries"],
        },
        "runtime_bindings": [
            "POST /api/v1/orchestrator/dry-run",
            "POST /api/v1/orchestrator/dry-run/stream",
            "GET /api/v1/phase2/runtime/contract",
            "GET /api/v1/orchestrator/checkpoints/{thread_id}",
        ],
        "evidence_refs": [
            ORCHESTRATOR_MANIFEST_EVIDENCE_REF,
            PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
            "llm_gateway_streaming_dry_run",
            "task_assignment_completed",
        ],
    }


def orchestrator_checkpoint_surface_contract_payload() -> dict[str, object]:
    return {
        "contract_version": ORCHESTRATOR_CHECKPOINT_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/orchestrator/checkpoints/contract",
        "runtime_endpoint_template": "GET /api/v1/orchestrator/checkpoints/{thread_id}",
        "runtime_contract_version": "checkpoint-runtime-v1",
        "evidence_ref": ORCHESTRATOR_CHECKPOINT_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "engine",
            "checkpointing",
            "snapshot",
        ],
        "required_snapshot_fields": [
            "found",
            "thread_id",
            "checkpoint_ns",
            "checkpoint_id",
            "values",
            "metadata",
        ],
        "expected_engine": "langgraph",
        "expected_checkpointing": "postgres",
        "expected_snapshot_found": True,
        "required_snapshot_evidence_refs": [
            "last_stable_checkpoint",
            "agent_result_aggregation_complete",
            "memory_update_persisted",
        ],
    }


def orchestrator_dry_run_surface_contract_payload() -> dict[str, object]:
    manifest = orchestrator_manifest_payload()
    return {
        "contract_version": ORCHESTRATOR_DRY_RUN_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/orchestrator/dry-run/contract",
        "runtime_endpoint": "POST /api/v1/orchestrator/dry-run",
        "evidence_ref": ORCHESTRATOR_DRY_RUN_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "evidence_ref",
            "engine",
            "mode",
            "live_provider_calls",
            "checkpointing",
            "thread_id",
            "state",
        ],
        "required_state_fields": [
            "run_id",
            "session_id",
            "project_id",
            "node_name",
            "retry_counters",
            "evidence_refs",
            "llm_gateway_calls",
            "task_assignments",
            "mcp_tool_calls",
            "memory_context",
            "memory_update_id",
            "result",
        ],
        "expected_engine": manifest["engine"],
        "expected_mode": manifest["mode"],
        "expected_checkpointing": manifest["checkpointing"],
        "expected_live_provider_calls": False,
        "required_state_evidence_refs": [
            "llm_gateway_streaming_dry_run",
            "task_assignment_completed",
        ],
        "non_claims": [
            "This contract does not claim live provider calls.",
            "This contract does not claim live MCP writes.",
            "This contract does not authorize production deployment.",
        ],
    }


def orchestrator_dry_run_stream_surface_contract_payload() -> dict[str, object]:
    return {
        "contract_version": ORCHESTRATOR_DRY_RUN_STREAM_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/orchestrator/dry-run/stream/contract",
        "runtime_endpoint": "POST /api/v1/orchestrator/dry-run/stream",
        "content_type": "text/event-stream",
        "replay_header": "Last-Event-ID",
        "runtime_contract_version": PHASE2_SSE_EVENT_CONTRACT_VERSION,
        "evidence_ref": ORCHESTRATOR_DRY_RUN_STREAM_SURFACE_EVIDENCE_REF,
        "required_event_types": list(PHASE2_SSE_REQUIRED_EVENTS),
        "required_done_fields": [
            "contract_version",
            "evidence_ref",
            "required_event_types",
            "status",
            "thread_id",
            "live_provider_calls",
        ],
        "required_error_fields": [
            "contract_version",
            "evidence_ref",
            "required_event_types",
            "code",
            "message",
            "recoverable",
        ],
        "policy_checks": [
            "Stream remains replayable through Last-Event-ID.",
            "Done and error terminal events stay bound to the phase2 SSE contract.",
            "Stream remains deterministic and does not claim live provider calls.",
        ],
        "non_claims": [
            "This contract does not imply live provider token streaming.",
            "This contract does not authorize production deployment.",
        ],
    }


def phase2_runtime_start_surface_contract_payload() -> dict[str, object]:
    runtime = phase2_runtime_contract_payload()
    return {
        "contract_version": PHASE2_RUNTIME_START_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/phase2/runtime/start/contract",
        "runtime_endpoint": "POST /api/v1/phase2/runtime/start",
        "runtime_contract_version": runtime["contract_version"],
        "evidence_ref": PHASE2_RUNTIME_START_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "status",
            "mode",
            "engine",
            "live_provider_calls",
            "live_mcp_writes",
            "production_deploy",
            "checkpointing",
            "thread_id",
            "run_id",
            "evidence_ref",
            "state",
            "contract",
        ],
        "required_state_fields": [
            "run_id",
            "session_id",
            "project_id",
            "node_name",
            "retry_counters",
            "evidence_refs",
            "result",
        ],
        "expected_status": "started",
        "expected_engine": runtime["engine"],
        "expected_mode": runtime["mode"],
        "expected_checkpointing": runtime["checkpointing"],
        "expected_live_provider_calls": False,
        "expected_live_mcp_writes": False,
        "expected_production_deploy": False,
        "required_state_evidence_refs": [
            PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
            "task_assignment_completed",
            "memory_update_persisted",
        ],
        "non_claims": list(runtime["non_claims"]),
    }


@app.get("/api/v1/orchestrator/manifest")
def orchestrator_manifest() -> dict[str, object]:
    return orchestrator_manifest_payload()


@app.get("/api/v1/orchestrator/manifest/contract")
def orchestrator_manifest_contract() -> dict[str, object]:
    return orchestrator_manifest_contract_payload()


@app.get("/api/v1/phase2/runtime/contract")
def phase2_runtime_contract() -> dict[str, object]:
    return phase2_runtime_contract_payload()


@app.get("/api/v1/phase2/runtime/runs/contract")
def phase2_runtime_runs_contract() -> dict[str, object]:
    return phase2_runtime_runs_surface_contract_payload()


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


def phase2_runtime_runs_surface_contract_payload() -> dict[str, object]:
    runtime = phase2_runtime_runs(limit=3)
    return {
        "contract_version": PHASE2_RUNTIME_RUNS_SURFACE_CONTRACT_VERSION,
        "endpoint": "GET /api/v1/phase2/runtime/runs/contract",
        "runtime_endpoint": "GET /api/v1/phase2/runtime/runs",
        "runtime_contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
        "evidence_ref": PHASE2_RUNTIME_RUNS_SURFACE_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "mode",
            "source_event_type",
            "evidence_ref",
            "runs",
            "non_claims",
        ],
        "required_run_fields": [
            "contract_version",
            "status",
            "thread_id",
            "session_id",
            "run_id",
            "node_name",
            "checkpointing",
            "live_provider_calls",
            "live_mcp_writes",
            "production_deploy",
            "evidence_refs",
            "role_summary_count",
            "aggregation_evidence_ref",
            "evidence_ref",
            "created_at",
            "severity",
        ],
        "required_evidence_refs": [
            PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
            "memory_update_persisted",
            "agent_result_aggregation_complete",
        ],
        "expected_statuses": ["completed", "stopped"],
        "expected_mode": runtime["mode"],
        "expected_source_event_type": PHASE2_RUNTIME_GRAPH_EVIDENCE_REF,
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


def default_autonomous_write_scope() -> list[str]:
    return [
        "services/agent-api/**",
        "services/agent-worker/**",
        "apps/frontend/**",
        "scripts/**",
        "docs/**",
    ]


def default_autonomous_constraints() -> list[str]:
    return [
        "Respect the fail-closed task policy before enqueue.",
        "Do not claim live provider calls, live MCP writes, or production deployment.",
        "Keep changes inside the declared write_scope.",
        "Escalate instead of bypassing blocked actions or human-review gates.",
    ]


def autonomous_role_map() -> dict[str, str]:
    return {
        "supervisor": "planner",
        "planner": "planner",
        "explorer": "planner",
        "coder": "coder",
        "tester": "tester",
    }


def autonomous_priority_level(priority: int) -> str:
    if priority >= 8:
        return "high"
    if priority <= 3:
        return "low"
    return "mid"


def autonomous_priority_queue(priority: int) -> str:
    return TASK_PRIORITY_QUEUES[autonomous_priority_level(priority)]


def autonomous_assignment_blueprints(
    objective: str,
    *,
    write_scope: list[str],
    acceptance_criteria: list[str],
) -> list[dict[str, object]]:
    blocked_actions = list(task_policy_manifest()["required_blocked_actions"])
    return [
        {
            "logical_role": "supervisor",
            "execution_agent_type": "planner",
            "task_type": "autonomous_supervisor_guard",
            "task_description": f"Supervise the autonomous coding lane for objective: {objective}",
            "priority": 9,
            "allowed_tools": ["memory_read", "task_router", "langgraph"],
            "planned_capabilities": ["scope_guard", "handoff_management", "completion_gate"],
            "write_scope": [],
            "acceptance_criteria": acceptance_criteria,
            "human_review_required": True,
            "blocked_actions": blocked_actions,
        },
        {
            "logical_role": "planner",
            "execution_agent_type": "planner",
            "task_type": "autonomous_plan",
            "task_description": f"Produce the execution plan and sequencing for objective: {objective}",
            "priority": 8,
            "allowed_tools": ["memory_read", "task_router", "langgraph"],
            "planned_capabilities": ["task_decomposition", "risk_triage", "acceptance_mapping"],
            "write_scope": [],
            "acceptance_criteria": acceptance_criteria,
            "human_review_required": True,
            "blocked_actions": blocked_actions,
        },
        {
            "logical_role": "explorer",
            "execution_agent_type": "planner",
            "task_type": "autonomous_research",
            "task_description": f"Explore existing code paths, contracts, and risks for objective: {objective}",
            "priority": 6,
            "allowed_tools": ["memory_read", "task_router", "langgraph"],
            "planned_capabilities": ["context_gathering", "contract_diff", "runtime_gap_detection"],
            "write_scope": [],
            "acceptance_criteria": acceptance_criteria,
            "human_review_required": True,
            "blocked_actions": blocked_actions,
        },
        {
            "logical_role": "coder",
            "execution_agent_type": "coder",
            "task_type": "autonomous_implementation",
            "task_description": f"Implement the scoped coding changes for objective: {objective}",
            "priority": 8,
            "allowed_tools": ["memory_read", "filesystem_mcp", "github_mcp", "mcp_gateway"],
            "planned_capabilities": ["code_edit", "patching", "contract_preservation"],
            "write_scope": list(write_scope),
            "acceptance_criteria": acceptance_criteria,
            "human_review_required": True,
            "blocked_actions": blocked_actions,
        },
        {
            "logical_role": "tester",
            "execution_agent_type": "tester",
            "task_type": "autonomous_validation",
            "task_description": f"Verify the implementation and regressions for objective: {objective}",
            "priority": 7,
            "allowed_tools": ["memory_read", "playwright_mcp", "filesystem_mcp", "mcp_gateway"],
            "planned_capabilities": ["regression_checks", "contract_verification", "runtime_smoke"],
            "write_scope": list(write_scope),
            "acceptance_criteria": acceptance_criteria,
            "human_review_required": True,
            "blocked_actions": blocked_actions,
        },
    ]


def autonomous_team_contract_payload() -> dict[str, object]:
    return {
        "contract_version": AUTONOMOUS_TEAM_CONTRACT_VERSION,
        "mode": AUTONOMOUS_TEAM_MODE,
        "endpoint": "GET /api/v1/team/status/contract",
        "runtime_endpoint": "GET /api/v1/team/status",
        "dispatch_endpoint": "POST /api/v1/task/dispatch",
        "alias_endpoints": ["GET /team/status", "POST /task/dispatch"],
        "evidence_ref": AUTONOMOUS_TEAM_EVIDENCE_REF,
        "required_top_level_fields": [
            "contract_version",
            "dispatch_contract_version",
            "team_mode",
            "runtime_source",
            "status",
            "dispatch_id",
            "project_id",
            "session_id",
            "objective",
            "trace_id",
            "request_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
            "queue_depth",
            "queue_depth_by_priority",
            "logical_roles",
            "logical_to_execution_map",
            "external_runtime",
            "members",
            "write_scope",
            "acceptance_criteria",
            "constraints",
            "non_claims",
        ],
        "required_member_fields": [
            "logical_role",
            "execution_agent_type",
            "task_id",
            "latest_task_id",
            "task_type",
            "status",
            "latest_status",
            "priority",
            "priority_level",
            "priority_queue",
            "allowed_tools",
            "planned_capabilities",
            "write_scope",
            "acceptance_criteria",
            "human_review_required",
            "blocked_actions",
            "current_status_source",
            "trace_id",
            "request_id",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
        ],
        "required_logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
        "logical_to_execution_map": autonomous_role_map(),
        "runtime_pool_contracts": {
            "assignment": TASK_ASSIGNMENT_CONTRACT_VERSION,
            "profiles": "agent-profiles-v1",
            "agent_status": "GET /api/v1/agents/status",
            "recent_tasks": "GET /api/v1/tasks/recent",
        },
        "non_claims": [
            "Logical roles are overlays on the existing runtime pool, not separate worker binaries.",
            "An optional external runtime adapter may project read-only team presence without changing dispatch semantics.",
            "This status surface does not claim live provider execution, live MCP writes, or production deployment.",
            "Legacy four-role public contracts remain authoritative for the runtime pool itself.",
        ],
    }


def autonomous_task_dispatch_contract_payload() -> dict[str, object]:
    policy = task_policy_manifest()
    return {
        "contract_version": AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION,
        "mode": AUTONOMOUS_TEAM_MODE,
        "endpoint": "GET /api/v1/task/dispatch/contract",
        "runtime_endpoint": "POST /api/v1/task/dispatch",
        "status_endpoint": "GET /api/v1/team/status",
        "alias_endpoints": ["POST /task/dispatch", "GET /team/status"],
        "evidence_ref": AUTONOMOUS_TASK_DISPATCH_EVIDENCE_REF,
        "required_request_fields": [
            "project_id",
            "objective",
            "session_id",
            "trace_id",
            "write_scope",
            "acceptance_criteria",
            "constraints",
        ],
        "required_response_fields": [
            "dispatch_id",
            "status",
            "project_id",
            "session_id",
            "trace_id",
            "objective",
            "team_mode",
            "runtime_source",
            "dispatch_contract_version",
            "team_contract_version",
            "write_scope",
            "acceptance_criteria",
            "constraints",
            "assignments",
            "status_endpoint",
            "contract_endpoint",
            "runtime_pool_contract_version",
            "non_claims",
        ],
        "required_assignment_fields": [
            "logical_role",
            "execution_agent_type",
            "task_id",
            "task_type",
            "status",
            "priority",
            "priority_level",
            "priority_queue",
            "allowed_tools",
            "planned_capabilities",
            "write_scope",
            "acceptance_criteria",
            "human_review_required",
            "blocked_actions",
            "evidence_ref",
            "current_status_source",
        ],
        "required_logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
        "logical_to_execution_map": autonomous_role_map(),
        "policy_version": policy["policy_version"],
        "runtime_pool_contract_version": TASK_ASSIGNMENT_CONTRACT_VERSION,
        "defaults": {
            "write_scope": default_autonomous_write_scope(),
            "constraints": default_autonomous_constraints(),
            "acceptance_criteria": [
                "result_envelope",
                "done_validation",
                "audit_log",
                "runtime_visibility",
            ],
        },
        "non_claims": [
            "Dispatch compiles logical work into the existing four-role task queue.",
            "External runtime adapters are optional read-only projections and do not bypass the internal fail-closed queue policy.",
            "Dispatch does not bypass the fail-closed task policy.",
            "Dispatch does not authorize production deployment or live provider execution.",
        ],
    }


def autonomous_idle_team_payload() -> dict[str, object]:
    external_runtime = external_autonomous_runtime_state()
    return {
        "contract_version": AUTONOMOUS_TEAM_CONTRACT_VERSION,
        "dispatch_contract_version": AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION,
        "team_mode": AUTONOMOUS_TEAM_MODE,
        "runtime_source": "external_adapter" if external_runtime["ready"] else "internal_queue",
        "status": "idle",
        "dispatch_id": None,
        "project_id": None,
        "session_id": None,
        "objective": None,
        "trace_id": None,
        "request_id": None,
        "correlation_evidence_ref": None,
        "audit_feed_evidence_ref": None,
        "queue_depth": queue_depth(),
        "queue_depth_by_priority": queue_depth_by_priority(),
        "logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
        "logical_to_execution_map": autonomous_role_map(),
        "external_runtime": external_runtime,
        "runtime_pool_contract_version": TASK_ASSIGNMENT_CONTRACT_VERSION,
        "write_scope": default_autonomous_write_scope(),
        "acceptance_criteria": [
            "result_envelope",
            "done_validation",
            "audit_log",
            "runtime_visibility",
        ],
        "constraints": default_autonomous_constraints(),
        "members": [
            {
                "logical_role": logical_role,
                "execution_agent_type": autonomous_role_map()[logical_role],
                "task_id": None,
                "latest_task_id": None,
                "task_type": None,
                "status": "idle",
                "latest_status": "idle",
                "priority": None,
                "priority_level": None,
                "priority_queue": None,
                "allowed_tools": [],
                "planned_capabilities": [],
                "write_scope": [],
                "acceptance_criteria": [],
                "human_review_required": True,
                "blocked_actions": [],
                "current_status_source": "no_dispatch",
                "trace_id": None,
                "request_id": None,
                "correlation_evidence_ref": None,
                "audit_feed_evidence_ref": None,
            }
            for logical_role in AUTONOMOUS_LOGICAL_ROLES
        ],
        "non_claims": autonomous_team_contract_payload()["non_claims"],
    }


def external_autonomous_team_payload(external_runtime: dict[str, object]) -> dict[str, object]:
    logical_role_map = dict(external_runtime.get("logical_role_map") or {})
    available_agents = set(str(agent) for agent in external_runtime.get("agents") or [])
    members: list[dict[str, object]] = []
    for logical_role in AUTONOMOUS_LOGICAL_ROLES:
        runtime_agent = str(logical_role_map.get(logical_role) or logical_role)
        present = runtime_agent in available_agents
        members.append(
            {
                "logical_role": logical_role,
                "execution_agent_type": runtime_agent,
                "task_id": None,
                "latest_task_id": None,
                "task_type": "external_runtime_projection",
                "status": "ready" if present else "unavailable",
                "latest_status": "ready" if present else "unavailable",
                "priority": None,
                "priority_level": None,
                "priority_queue": None,
                "allowed_tools": [],
                "planned_capabilities": ["external_runtime_projection"],
                "write_scope": [],
                "acceptance_criteria": [],
                "human_review_required": True,
                "blocked_actions": [],
                "current_status_source": "external_runtime",
                "trace_id": None,
                "request_id": None,
                "correlation_evidence_ref": None,
                "audit_feed_evidence_ref": None,
                "latest_result": None,
                "latest_error": None if present else str(external_runtime.get("error") or "external agent missing"),
            }
        )
    return {
        "contract_version": AUTONOMOUS_TEAM_CONTRACT_VERSION,
        "dispatch_contract_version": AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION,
        "team_mode": AUTONOMOUS_TEAM_MODE,
        "runtime_source": "external_adapter",
        "status": "external_ready" if external_runtime.get("ready") else "external_degraded",
        "dispatch_id": None,
        "project_id": None,
        "session_id": None,
        "objective": "external runtime projection",
        "trace_id": None,
        "request_id": None,
        "correlation_evidence_ref": None,
        "audit_feed_evidence_ref": None,
        "queue_depth": 0,
        "queue_depth_by_priority": {"high": 0, "mid": 0, "low": 0},
        "logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
        "logical_to_execution_map": logical_role_map,
        "external_runtime": external_runtime,
        "runtime_pool_contract_version": TASK_ASSIGNMENT_CONTRACT_VERSION,
        "write_scope": [],
        "acceptance_criteria": [],
        "constraints": default_autonomous_constraints(),
        "members": members,
        "non_claims": autonomous_team_contract_payload()["non_claims"],
    }


def latest_active_autonomous_dispatch() -> AutonomousDispatchRecord | None:
    for dispatch in list_recent_autonomous_dispatches(limit=12):
        if dispatch.status not in {"completed", "failed"}:
            return dispatch
    return None


def autonomous_team_status_payload(dispatch_id: str | None = None) -> dict[str, object]:
    external_runtime = external_autonomous_runtime_state()
    dispatch = get_autonomous_dispatch(dispatch_id) if dispatch_id else latest_active_autonomous_dispatch()
    if dispatch is None:
        if external_runtime["ready"]:
            return external_autonomous_team_payload(external_runtime)
        return autonomous_idle_team_payload()

    task_projection, session_projection = load_recent_correlation_projection(
        [assignment.task_id for assignment in dispatch.assignments],
        [dispatch.session_id],
    )
    session_correlation = session_projection.get(dispatch.session_id, {})
    refreshed_assignments: list[AutonomousRoleAssignment] = []
    members: list[dict[str, object]] = []
    for assignment in dispatch.assignments:
        task = get_task(assignment.task_id)
        current_status = task.status if task else assignment.status
        refreshed_assignment = assignment.model_copy(update={"status": current_status})
        refreshed_assignments.append(refreshed_assignment)
        correlation = task_projection.get(assignment.task_id, {}) or session_correlation
        members.append(
            {
                "logical_role": assignment.logical_role,
                "execution_agent_type": assignment.execution_agent_type,
                "task_id": assignment.task_id,
                "latest_task_id": assignment.task_id,
                "task_type": assignment.task_type,
                "status": current_status,
                "latest_status": current_status,
                "priority": assignment.priority,
                "priority_level": assignment.priority_level,
                "priority_queue": assignment.priority_queue,
                "allowed_tools": assignment.allowed_tools,
                "planned_capabilities": assignment.planned_capabilities,
                "write_scope": assignment.write_scope,
                "acceptance_criteria": assignment.acceptance_criteria,
                "human_review_required": assignment.human_review_required,
                "blocked_actions": assignment.blocked_actions,
                "current_status_source": "task_queue" if task else assignment.current_status_source,
                "trace_id": correlation.get("trace_id") or dispatch.trace_id,
                "request_id": correlation.get("request_id"),
                "correlation_evidence_ref": correlation.get("correlation_evidence_ref"),
                "audit_feed_evidence_ref": correlation.get("audit_feed_evidence_ref"),
                "latest_result": task.result if task else None,
                "latest_error": task.error if task else None,
            }
        )

    dispatch_status = autonomous_dispatch_status(refreshed_assignments)
    if dispatch_status != dispatch.status or [assignment.status for assignment in refreshed_assignments] != [
        assignment.status for assignment in dispatch.assignments
    ]:
        dispatch = dispatch.model_copy(
            update={
                "status": dispatch_status,
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "assignments": refreshed_assignments,
            }
        )
        store_autonomous_dispatch(dispatch)
        persist_autonomous_dispatch_audit(dispatch)

    return {
        "contract_version": AUTONOMOUS_TEAM_CONTRACT_VERSION,
        "dispatch_contract_version": AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION,
        "team_mode": dispatch.team_mode,
        "runtime_source": "internal_queue",
        "status": dispatch.status,
        "dispatch_id": dispatch.dispatch_id,
        "project_id": dispatch.project_id,
        "session_id": dispatch.session_id,
        "objective": dispatch.objective,
        "trace_id": dispatch.trace_id,
        "request_id": dispatch.request_id or session_correlation.get("request_id"),
        "correlation_evidence_ref": session_correlation.get("correlation_evidence_ref"),
        "audit_feed_evidence_ref": session_correlation.get("audit_feed_evidence_ref"),
        "queue_depth": queue_depth(),
        "queue_depth_by_priority": queue_depth_by_priority(),
        "logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
        "logical_to_execution_map": autonomous_role_map(),
        "external_runtime": external_runtime,
        "runtime_pool_contract_version": TASK_ASSIGNMENT_CONTRACT_VERSION,
        "write_scope": dispatch.write_scope,
        "acceptance_criteria": dispatch.acceptance_criteria,
        "constraints": dispatch.constraints,
        "members": members,
        "non_claims": dispatch.non_claims,
    }


def task_policy_contract_payload() -> dict[str, object]:
    policy = task_policy_manifest()
    return {
        "contract_version": "task-policy-contract-v1",
        "mode": "public_task_policy_manifest_runtime_contract",
        "endpoint": "GET /api/v1/tasks/policy/contract",
        "runtime_endpoint": "GET /api/v1/tasks/policy",
        "validation_endpoint": "POST /api/v1/tasks/policy/validate",
        "evidence_ref": "task_policy_contract_runtime_visible",
        "policy_version": policy["policy_version"],
        "profile_contract_version": policy["profile_contract_version"],
        "required_top_level_fields": [
            "policy_version",
            "profile_contract_version",
            "mode",
            "required_blocked_actions",
            "allowed_tools",
            "write_tools",
            "profile_gates",
            "write_scope_required_for",
            "devops_human_gate",
        ],
        "required_validation_behaviors": {
            "unknown_tools": "403 task_policy_violation",
            "missing_blocked_actions": "403 task_policy_violation",
            "coder_write_without_write_scope": "403 task_policy_violation",
            "deployment_like_without_human_review": "403 task_policy_violation",
        },
        "non_claims": [
            "This contract does not authorize production deployment.",
            "This contract does not enable live MCP writes.",
            "This contract remains fail-closed before enqueue.",
        ],
    }


@app.get("/api/v1/phase2/runtime/start/contract")
def phase2_runtime_start_contract() -> dict[str, object]:
    return phase2_runtime_start_surface_contract_payload()


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


@app.get("/api/v1/team/status/contract")
def autonomous_team_status_contract() -> dict[str, object]:
    return autonomous_team_contract_payload()


@app.get("/api/v1/task/dispatch/contract")
def autonomous_task_dispatch_contract() -> dict[str, object]:
    return autonomous_task_dispatch_contract_payload()


@app.get("/api/v1/team/master-plan/contract")
def autonomous_master_plan_contract() -> dict[str, object]:
    return autonomous_master_plan_contract_payload()


@app.get("/api/v1/team/master-plan")
def autonomous_master_plan() -> dict[str, object]:
    return autonomous_master_plan_payload()


@app.get("/api/v1/live-agents/contract")
def live_agent_contract() -> dict[str, object]:
    return live_agent_contract_payload()


@app.get("/api/v1/live-agents/status")
@app.get("/api/agents")
def live_agent_status() -> dict[str, object]:
    return live_agent_status_payload()


@app.post("/api/v1/live-agents/steer")
@app.post("/api/steer-agent")
def live_agent_steer(request: LiveAgentSteerRequest, http_request: Request) -> dict[str, object]:
    budget_state = check_budget_guard()
    profile = resolve_live_agent_profile(request.agent_id)
    agent_id = str(profile["agent_id"])
    if request.reset_history:
        reset_live_agent_session(agent_id)

    session = get_live_agent_session(agent_id)
    previous_response_id = str(session.get("previous_response_id")) if session and session.get("previous_response_id") else None
    sanitized_message = redact_text(request.message)
    sanitized_instructions = redact_text(request.instructions) if request.instructions else None
    trace_id = getattr(http_request.state, "trace_id", None) or f"live-agent-{uuid4()}"
    model = request.model or live_agent_default_model()
    payload = {
        "model": model,
        "instructions": build_live_agent_instructions(agent_id, profile, sanitized_instructions),
        "input": sanitized_message,
        "store": True,
        # Keep local DEV-ONLY role runs concise so the four-agent browser proof
        # completes predictably on the CPU llama.cpp path.
        "max_output_tokens": 96,
        "text": {
            "format": {"type": "text"},
            "verbosity": "low",
        },
        "reasoning": {"effort": request.reasoning_effort},
        "metadata": {
            "trace_id": trace_id,
            "agent_type": str(profile["execution_role"]),
            "logical_agent_id": agent_id,
            "project_id": request.project_id,
            **request.metadata,
        },
    }
    if previous_response_id:
        payload["previous_response_id"] = previous_response_id

    response_payload = call_llm_gateway_responses(payload)
    response_id = str(response_payload.get("id") or "")
    text = extract_live_agent_text(response_payload)
    action_result = perform_live_agent_result(
        agent_id=agent_id,
        execution_role=str(profile["execution_role"]),
        project_id=request.project_id,
        trace_id=str(response_payload.get("trace_id") or trace_id),
        llm_text=text,
    )
    if response_id:
        set_live_agent_session(
            agent_id,
            response_id=response_id,
            project_id=request.project_id,
            model=str(response_payload.get("model") or model),
            execution_role=str(profile["execution_role"]),
            extra={
                "last_trace_id": str(response_payload.get("trace_id") or trace_id),
                "last_result_type": action_result.get("result_type"),
                "last_output_path": action_result.get("output_rel"),
                "last_command": action_result.get("command"),
                "last_exit_code": action_result.get("exit_code"),
            },
        )
    return {
        "contract_version": LIVE_AGENT_STEERING_CONTRACT_VERSION,
        "runtime_source": "openai_responses_via_llm_gateway",
        "agent_id": agent_id,
        "response_id": response_id or None,
        "responseId": response_id or None,
        "previous_response_id": previous_response_id,
        "status": response_payload.get("status", "completed"),
        "model": response_payload.get("model") or model,
        "text": text,
        "usage": response_payload.get("usage"),
        "trace_id": response_payload.get("trace_id") or trace_id,
        "evidence_ref": LIVE_AGENT_STEERING_EVIDENCE_REF,
        "llm_gateway_contract_version": response_payload.get("contract_version"),
        "llm_gateway_evidence_ref": response_payload.get("evidence_ref"),
        "live_provider_calls": response_payload.get("live_provider_calls", False),
        "local_model_calls": response_payload.get("local_model_calls", False),
        "model_downloads": response_payload.get("model_downloads", False),
        "audit_persisted": response_payload.get("audit_persisted", False),
        "secret_output": response_payload.get("secret_output", False),
        "execution_role": profile["execution_role"],
        "project_id": request.project_id,
        "action": action_result.get("result_type"),
        "output_path": action_result.get("output_rel"),
        "command": action_result.get("command"),
        "exit_code": action_result.get("exit_code"),
        "budget": {
            "level": budget_state.level,
            "spent_percentage": budget_state.spent_percentage,
            "total_cost_cents": budget_state.total_cost_cents,
            "budget_limit_cents": budget_state.budget_limit_cents,
        },
    }


@app.post("/api/v1/live-agents/{agent_id}/reset")
def live_agent_reset(agent_id: str) -> dict[str, object]:
    profile = resolve_live_agent_profile(agent_id)
    reset_live_agent_session(str(profile["agent_id"]))
    return {
        "contract_version": LIVE_AGENT_STEERING_CONTRACT_VERSION,
        "status": "reset",
        "agent_id": str(profile["agent_id"]),
        "runtime_source": "openai_responses_via_llm_gateway",
    }


@app.get("/api/v1/team/roster/contract")
def autonomous_agent_roster_contract() -> dict[str, object]:
    return autonomous_agent_roster_contract_payload()


@app.get("/api/v1/team/roster")
def autonomous_agent_roster() -> dict[str, object]:
    return autonomous_agent_roster_payload()


@app.get("/api/v1/team/status")
@app.get("/team/status")
def autonomous_team_status(dispatch_id: str | None = Query(default=None, max_length=120)) -> dict[str, object]:
    if dispatch_id and not get_autonomous_dispatch(dispatch_id):
        raise HTTPException(status_code=404, detail="dispatch not found")
    return autonomous_team_status_payload(dispatch_id)


@app.get("/api/v1/task/dispatches/recent")
def autonomous_recent_dispatches(limit: int = Query(default=10, ge=1, le=50)) -> dict[str, object]:
    return {
        "dispatches": [record.model_dump() for record in list_recent_autonomous_dispatches(limit=limit)],
        "contract_version": AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION,
    }


@app.post("/api/v1/task/dispatch", status_code=201)
@app.post("/task/dispatch", status_code=201)
def autonomous_task_dispatch(request: AutonomousCodingDispatchRequest, http_request: Request) -> dict[str, object]:
    sanitized_objective = redact_text(request.objective)
    prepared_write_scope = request.write_scope or default_autonomous_write_scope()
    prepared_constraints = default_autonomous_constraints() + [constraint for constraint in request.constraints if constraint]
    prepared_acceptance_criteria = list(dict.fromkeys(request.acceptance_criteria))
    trace_id = request.trace_id or f"autonomous-dispatch-{uuid4()}"
    request_id = getattr(http_request.state, "request_id", None)
    session_id = prepare_orchestrator_session(
        request.project_id,
        request.session_id,
        source="autonomous-task-dispatch",
        metadata={
            "mode": AUTONOMOUS_TEAM_MODE,
            "trace_id": trace_id,
            "request_id": request_id,
            "contract_version": AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION,
            "logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
            "live_provider_calls": False,
            "live_mcp_writes": False,
        },
    )
    assignments_to_enqueue = [
        TaskAssignment(
            project_id=request.project_id,
            session_id=session_id,
            agent_type=str(blueprint["execution_agent_type"]),
            task_type=str(blueprint["task_type"]),
            task_description=str(blueprint["task_description"]),
            trace_id=trace_id,
            priority=int(blueprint["priority"]),
            allowed_tools=list(blueprint["allowed_tools"]),
            write_scope=list(blueprint["write_scope"]),
            blocked_actions=list(blueprint["blocked_actions"]),
            acceptance_criteria=list(blueprint["acceptance_criteria"]),
            human_review_required=bool(blueprint["human_review_required"]),
        )
        for blueprint in autonomous_assignment_blueprints(
            sanitized_objective,
            write_scope=prepared_write_scope,
            acceptance_criteria=prepared_acceptance_criteria,
        )
    ]
    try:
        for assignment in assignments_to_enqueue:
            validate_task_policy(assignment)
    except TaskPolicyViolation as exc:
        persist_task_policy_block(assignments_to_enqueue[0], exc)
        raise HTTPException(
            status_code=403,
            detail={
                "code": exc.code,
                "violations": exc.violations,
                "policy": task_policy_manifest(),
            },
        ) from exc

    queued_assignments = [enqueue_task(assignment) for assignment in assignments_to_enqueue]
    dispatch_id = str(uuid4())
    assignment_payloads: list[AutonomousRoleAssignment] = []
    for blueprint, task in zip(
        autonomous_assignment_blueprints(
            sanitized_objective,
            write_scope=prepared_write_scope,
            acceptance_criteria=prepared_acceptance_criteria,
        ),
        queued_assignments,
        strict=True,
    ):
        priority = int(blueprint["priority"])
        assignment_payloads.append(
            AutonomousRoleAssignment(
                logical_role=str(blueprint["logical_role"]),
                execution_agent_type=task.agent_type,
                task_id=task.task_id,
                task_type=task.task_type,
                status=task.status,
                priority=priority,
                priority_level=autonomous_priority_level(priority),
                priority_queue=autonomous_priority_queue(priority),
                allowed_tools=task.allowed_tools,
                planned_capabilities=list(blueprint["planned_capabilities"]),
                write_scope=task.write_scope,
                acceptance_criteria=task.acceptance_criteria,
                human_review_required=task.human_review_required,
                blocked_actions=task.blocked_actions,
                evidence_ref=AUTONOMOUS_TASK_DISPATCH_EVIDENCE_REF,
                current_status_source="task_queue",
            )
        )

    dispatch_record = AutonomousDispatchRecord(
        dispatch_id=dispatch_id,
        project_id=request.project_id,
        session_id=session_id,
        objective=sanitized_objective,
        trace_id=trace_id,
        request_id=request_id,
        status=autonomous_dispatch_status(assignment_payloads),
        created_at=datetime.now(timezone.utc).isoformat(),
        updated_at=datetime.now(timezone.utc).isoformat(),
        team_mode=AUTONOMOUS_TEAM_MODE,
        dispatch_contract_version=AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION,
        team_contract_version=AUTONOMOUS_TEAM_CONTRACT_VERSION,
        write_scope=prepared_write_scope,
        acceptance_criteria=prepared_acceptance_criteria,
        constraints=prepared_constraints,
        assignments=assignment_payloads,
        non_claims=autonomous_team_contract_payload()["non_claims"],
    )
    store_autonomous_dispatch(dispatch_record)
    persist_autonomous_dispatch_audit(dispatch_record)
    with psycopg.connect(database_url(), autocommit=True) as conn:
        conn.execute(
            """
            UPDATE agent_sessions
            SET metadata = metadata || %s::jsonb
            WHERE id = %s
            """,
            (
                Json(
                    {
                        "autonomous_dispatch_id": dispatch_id,
                        "autonomous_team_mode": AUTONOMOUS_TEAM_MODE,
                        "autonomous_objective": sanitized_objective,
                        "latest_task_id": queued_assignments[-1].task_id if queued_assignments else None,
                        "logical_roles": list(AUTONOMOUS_LOGICAL_ROLES),
                        "trace_id": trace_id,
                        "request_id": request_id,
                        "correlation_evidence_ref": "request_id_audit_correlation" if (request_id or trace_id) else None,
                        "audit_feed_evidence_ref": "request_id_audit_feed_visible" if (request_id or trace_id) else None,
                    }
                ),
                session_id,
            ),
        )
    return {
        **dispatch_record.model_dump(),
        "runtime_source": "internal_queue",
        "status_endpoint": f"/api/v1/team/status?dispatch_id={dispatch_id}",
        "contract_endpoint": "/api/v1/task/dispatch/contract",
        "runtime_pool_contract_version": TASK_ASSIGNMENT_CONTRACT_VERSION,
        "request_id": request_id,
    }


@app.get("/api/v1/task/dispatch/{dispatch_id}")
def autonomous_dispatch_detail(dispatch_id: str) -> dict[str, object]:
    dispatch = get_autonomous_dispatch(dispatch_id)
    if not dispatch:
        raise HTTPException(status_code=404, detail="dispatch not found")
    return {"dispatch": dispatch.model_dump()}


@app.get("/api/v1/tasks/policy")
def task_policy() -> dict[str, object]:
    return task_policy_manifest()


@app.get("/api/v1/tasks/policy/contract")
def task_policy_contract() -> dict[str, object]:
    return task_policy_contract_payload()


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


@app.get("/api/v1/orchestrator/dry-run/contract")
def orchestrator_dry_run_contract() -> dict[str, object]:
    return orchestrator_dry_run_surface_contract_payload()


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
        "contract_version": PHASE2_RUNTIME_CONTRACT_VERSION,
        "evidence_ref": ORCHESTRATOR_DRY_RUN_SURFACE_EVIDENCE_REF,
    }


@app.get("/api/v1/orchestrator/dry-run/stream/contract")
def orchestrator_dry_run_stream_contract() -> dict[str, object]:
    return orchestrator_dry_run_stream_surface_contract_payload()


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


@app.get("/api/v1/orchestrator/checkpoints/contract")
def orchestrator_checkpoint_contract() -> dict[str, object]:
    return orchestrator_checkpoint_surface_contract_payload()


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


def local_files_readonly_contract_payload() -> dict[str, object]:
    return {
        "contract_version": "local-files-readonly-contract-v1",
        "mode": "frontend_readonly_intent_surface",
        "endpoint": "GET /api/v1/files/local/contract",
        "page_route": "/files/local",
        "evidence_ref": "local_files_readonly_contract_visible",
        "live": False,
        "writes": False,
        "secret_output": False,
        "host_filesystem_mounted": False,
        "live_filesystem_reads": False,
        "mcp_contract_ref": "GET /mcp/api/v1/filesystem/workspace-scope/contract",
        "allowed_runtime_operations": [],
        "required_ui_state": "read-only unavailable fallback",
        "policy_checks": [
            "The frontend may show only a read-only intent surface when no scoped file mount is present.",
            "No host filesystem path is listed from this endpoint.",
            "No file content, secret value, token cache, or private path is exposed.",
            "Any future filesystem access must go through MCP scope guard and audit.",
        ],
        "non_claims": [
            "This endpoint does not read the host filesystem.",
            "This endpoint does not mount local project files into the platform UI.",
            "This endpoint does not enable MCP filesystem writes.",
            "Localhost evidence remains DEV-ONLY and cannot close hosted gates.",
        ],
    }


@app.get("/api/v1/files/local/contract")
def local_files_readonly_contract() -> dict[str, object]:
    return local_files_readonly_contract_payload()


@app.get("/api/v1/models/capabilities")
def model_capabilities() -> dict[str, object]:
    return model_capability_matrix()


def model_capabilities_contract_payload() -> dict[str, object]:
    matrix = model_capability_matrix()
    return {
        "contract_version": "model-capabilities-contract-v1",
        "mode": "configured_model_route_registry_runtime_contract",
        "endpoint": "GET /api/v1/models/capabilities/contract",
        "runtime_endpoint": "GET /api/v1/models/capabilities",
        "evidence_ref": "model_capabilities_contract_runtime_visible",
        "required_top_level_fields": [
            "memory_injection_budget_percent_max",
            "routes",
            "agent_profiles",
            "note",
        ],
        "required_route_fields": [
            "agent_type",
            "primary",
            "fallbacks",
            "max_output_tokens",
            "context_budget_policy",
            "memory_injection_budget_percent",
            "cost_tier",
            "supports_streaming",
            "configured_only",
        ],
        "required_agent_types": [route["agent_type"] for route in matrix["routes"]],
        "memory_injection_budget_percent_max": matrix["memory_injection_budget_percent_max"],
        "non_claims": [
            "Configured routes do not imply live provider credentials are present.",
            "Configured routes do not imply live provider health has been verified.",
            "This contract does not authorize production deployment.",
        ],
    }


@app.get("/api/v1/models/capabilities/contract")
def model_capabilities_contract() -> dict[str, object]:
    return model_capabilities_contract_payload()


def agent_profiles_contract_payload() -> dict[str, object]:
    profiles = agent_profile_registry()
    return {
        "contract_version": "agent-profiles-contract-v1",
        "mode": "public_agent_profile_registry_runtime_contract",
        "endpoint": "GET /api/v1/agents/profiles/contract",
        "runtime_endpoint": "GET /api/v1/agents/profiles",
        "evidence_ref": "agent_profiles_contract_runtime_visible",
        "profile_contract_version": profiles["profile_contract_version"],
        "required_top_level_fields": [
            "profile_contract_version",
            "max_retry_global",
            "done_validation_required",
            "profiles",
            "non_claims",
        ],
        "required_profile_fields": [
            "agent_type",
            "allowed_tools",
            "blocked_actions",
            "human_review_required_actions",
            "max_retries",
            "max_execution_seconds",
        ],
        "required_agent_types": ["planner", "coder", "tester", "devops"],
        "done_validation_required": profiles["done_validation_required"],
        "max_retry_global": profiles["max_retry_global"],
        "non_claims": profiles["non_claims"],
    }


@app.get("/api/v1/agents/profiles")
def agent_profiles() -> dict[str, object]:
    return agent_profile_registry()


@app.get("/api/v1/agents/profiles/contract")
def agent_profiles_contract() -> dict[str, object]:
    return agent_profiles_contract_payload()


@app.get("/api/v1/rotation/policy")
def provider_rotation_policy() -> dict[str, object]:
    return rotation_policy()


def rotation_policy_contract_payload() -> dict[str, object]:
    policy = rotation_policy()
    return {
        "contract_version": "rotation-policy-contract-v1",
        "mode": "provider_rotation_policy_runtime_contract",
        "endpoint": "GET /api/v1/rotation/policy/contract",
        "runtime_endpoint": "GET /api/v1/rotation/policy",
        "events_endpoint": "GET /api/v1/rotation/events",
        "evidence_ref": "rotation_policy_contract_runtime_visible",
        "required_top_level_fields": [
            "principle",
            "backoff_seconds",
            "reset_after_seconds",
            "budget_guard_required_before_rotation",
            "rotation_log_format",
        ],
        "rotation_log_contract_version": policy["rotation_log_format"]["contract_version"],
        "required_rotation_event_top_level_fields": [
            "id",
            "session_id",
            "details",
            "created_at",
            "severity",
        ],
        "required_rotation_event_detail_fields": [
            "event_kind",
            "from_provider",
            "to_provider",
            "provider_chain",
            "from_model",
            "to_model",
            "fallback_index",
            "routing_policy_decision",
            "cost_metadata",
            "reason",
            "agent",
            "trace_id",
            "live_provider_calls",
            "evidence_ref",
        ],
        "non_claims": [
            "This contract does not claim live provider rotation has already occurred.",
            "This contract does not claim live provider execution is enabled.",
            "This contract does not authorize production deployment.",
        ],
    }


def rotation_events_contract_payload() -> dict[str, object]:
    policy_contract = rotation_policy_contract_payload()
    return {
        "contract_version": "rotation-events-feed-v1",
        "mode": "provider_rotation_audit_feed_runtime_contract",
        "endpoint": "GET /api/v1/rotation/events/contract",
        "runtime_endpoint": "GET /api/v1/rotation/events",
        "seed_endpoint": "POST /internal/rotation/events",
        "event_contract_version": policy_contract["rotation_log_contract_version"],
        "evidence_ref": "rotation_events_contract_runtime_visible",
        "required_top_level_fields": [
            "contract_version",
            "evidence_ref",
            "live_provider_calls",
            "events",
        ],
        "required_event_top_level_fields": list(policy_contract["required_rotation_event_top_level_fields"]),
        "required_event_detail_fields": list(policy_contract["required_rotation_event_detail_fields"]),
        "supported_event_types": ["provider_rotated"],
        "non_claims": [
            "This contract does not claim live provider execution is enabled.",
            "This contract does not claim production deployment is allowed.",
            "This contract does not claim a rollout has occurred.",
        ],
    }


@app.get("/api/v1/rotation/policy/contract")
def provider_rotation_policy_contract() -> dict[str, object]:
    return rotation_policy_contract_payload()


@app.get("/api/v1/rotation/events/contract")
def provider_rotation_events_contract() -> dict[str, object]:
    return rotation_events_contract_payload()


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


@app.post("/api/v1/internal/tasks", status_code=201)
def create_task(assignment: TaskAssignment, request: Request) -> dict[str, object]:
    trace_id = getattr(request.state, "trace_id", None) or assignment.trace_id or f"internal-task-{uuid4()}"
    request_id = getattr(request.state, "request_id", None)
    assignment = assignment.model_copy(
        update={
            "task_description": redact_text(assignment.task_description),
            "trace_id": trace_id,
        }
    )
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            ensure_agent_session(
                conn,
                assignment.project_id,
                assignment.session_id,
                source="internal-task-intake",
                metadata={
                    "latest_agent_type": assignment.agent_type,
                    "latest_task_type": assignment.task_type,
                    "trace_id": trace_id,
                    "request_id": request_id,
                    "correlation_evidence_ref": "request_id_audit_correlation" if (request_id or trace_id) else None,
                    "audit_feed_evidence_ref": "request_id_audit_feed_visible" if (request_id or trace_id) else None,
                },
            )
        task = enqueue_task(assignment)
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                UPDATE agent_sessions
                SET metadata = metadata || %s::jsonb
                WHERE id = %s
                """,
                (
                    Json(
                        {
                            "latest_task_id": task.task_id,
                            "latest_agent_type": task.agent_type,
                            "latest_task_type": task.task_type,
                            "trace_id": trace_id,
                            "request_id": request_id,
                            "correlation_evidence_ref": "request_id_audit_correlation" if (request_id or trace_id) else None,
                            "audit_feed_evidence_ref": "request_id_audit_feed_visible" if (request_id or trace_id) else None,
                        }
                    ),
                    task.session_id,
                ),
            )
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


@app.get("/api/v1/internal/tasks/{task_id}")
def task_status(task_id: str) -> dict[str, object]:
    task = get_task(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="task not found")
    return {"task": task.model_dump()}


@app.get("/internal/tasks")
def task_queue_status() -> dict[str, object]:
    return {"queue_depth": queue_depth(), "queue_depth_by_priority": queue_depth_by_priority()}
