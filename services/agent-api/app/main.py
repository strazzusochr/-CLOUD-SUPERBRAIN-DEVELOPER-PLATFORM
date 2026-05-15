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
import urllib.error
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
CSP_REPORT_CONTRACT_VERSION = "csp-report-contract-v1"
CSP_REPORT_EVIDENCE_REF = "csp_report_contract_visible"
SECURITY_AUDIT_SURFACE_CONTRACT_VERSION = "security-audit-surface-v1"
SECURITY_AUDIT_SURFACE_EVIDENCE_REF = "security_audit_surface_visible"
SECURITY_AUDIT_EVENT_EVIDENCE_REF = "security_audit_event_visible"
SECURITY_REVIEW_QUEUE_CONTRACT_VERSION = "security-review-queue-v1"
SECURITY_REVIEW_QUEUE_EVIDENCE_REF = "security_review_queue_visible"
SECURITY_REVIEW_ITEM_EVIDENCE_REF = "security_review_item_visible"
SECURITY_REVIEW_REDACTION_EVIDENCE_REF = "security_review_redaction_enforced"
SECURITY_REVIEW_MUTATION_BLOCK_EVIDENCE_REF = "security_review_mutation_blocked"
SECURITY_REVIEW_FILTER_EVIDENCE_REF = "security_review_filter_state_visible"
SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF = "security_review_decision_history_visible"
SECURITY_REVIEW_SNAPSHOT_EVIDENCE_REF = "security_review_evidence_snapshot_visible"
SECURITY_REVIEW_GATE_EVIDENCE_REF = "security_review_gate_summary_visible"
SECURITY_REVIEW_EXPORT_CONTRACT_VERSION = "security-review-queue-export-v1"
SECURITY_REVIEW_EXPORT_EVIDENCE_REF = "security_review_queue_export_visible"
SECURITY_REVIEW_EXPORT_AUDIT_EVIDENCE_REF = "security_review_queue_export_audit_persisted"
TRACE_ID_CONTRACT_VERSION = "trace-id-propagation-v1"
CACHE_CONTROL_CONTRACT_VERSION = "cache-control-no-store-v1"
REQUEST_ID_CONTRACT_VERSION = "request-id-correlation-v1"
LAYER_INTERFACE_CONTRACT_VERSION = "layer-interface-contracts-v1"
LAYER_INTERFACE_EVIDENCE_REF = "layer_interface_contracts_visible"
TASK_ASSIGNMENT_CONTRACT_VERSION = "task-assignment-queue-contract-v1"
TASK_ASSIGNMENT_EVIDENCE_REF = "task_assignment_queue_contract_visible"
AGENT_LLM_STREAMING_CONTRACT_VERSION = "agent-llm-streaming-contract-v1"
AGENT_LLM_STREAMING_EVIDENCE_REF = "agent_llm_streaming_contract_visible"
LLM_RUNTIME_GUARD_PARITY_CONTRACT_VERSION = "llm-runtime-guard-parity-v1"
LLM_RUNTIME_GUARD_PARITY_EVIDENCE_REF = "llm_runtime_guard_parity_visible"
LLM_AUDIT_FEED_CONTRACT_VERSION = "llm-audit-feed-v1"
LLM_AUDIT_FEED_EVIDENCE_REF = "llm_audit_feed_visible"
LLM_AUDIT_SNAPSHOT_EVIDENCE_REF = "llm_audit_snapshot_visible"
LLM_AUDIT_REDACTION_EVIDENCE_REF = "llm_audit_redaction_enforced"
LLM_AUDIT_EXPORT_CONTRACT_VERSION = "llm-audit-export-v1"
LLM_AUDIT_EXPORT_EVIDENCE_REF = "llm_audit_export_visible"
LLM_AUDIT_EXPORT_AUDIT_EVIDENCE_REF = "llm_audit_export_audit_persisted"
LLM_AUDIT_NO_LIVE_PROVIDER_EVIDENCE_REF = "llm_audit_no_live_provider_guard"
GATEWAY_CORRELATION_CONTRACT_VERSION = "gateway-correlation-snapshot-v1"
GATEWAY_CORRELATION_RISK_ROLLUP_CONTRACT_VERSION = "gateway-correlation-risk-rollup-v1"
GATEWAY_CORRELATION_TIMELINE_CONTRACT_VERSION = "gateway-correlation-timeline-v1"
GATEWAY_CORRELATION_EXPORT_CONTRACT_VERSION = "gateway-correlation-export-v1"
GATEWAY_CORRELATION_EVIDENCE_REF = "gateway_correlation_snapshot_visible"
GATEWAY_CORRELATION_RISK_ROLLUP_EVIDENCE_REF = "gateway_correlation_risk_rollup_visible"
GATEWAY_CORRELATION_TIMELINE_EVIDENCE_REF = "gateway_correlation_timeline_visible"
GATEWAY_CORRELATION_EXPORT_EVIDENCE_REF = "gateway_correlation_export_visible"
GATEWAY_CORRELATION_EXPORT_AUDIT_EVIDENCE_REF = "gateway_correlation_export_audit_persisted"
GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF = "gateway_correlation_redaction_enforced"
GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF = "gateway_correlation_no_live_write_guard"
MCP_AUDIT_FEED_CONTRACT_VERSION = "mcp-audit-feed-v1"
MCP_AUDIT_FEED_EVIDENCE_REF = "mcp_audit_feed_contract_runtime_visible"
MCP_AUDIT_SNAPSHOT_EVIDENCE_REF = "mcp_audit_snapshot_visible"
MCP_AUDIT_REDACTION_EVIDENCE_REF = "mcp_audit_redaction_enforced"
MCP_AUDIT_EXPORT_CONTRACT_VERSION = "mcp-audit-export-v1"
MCP_AUDIT_EXPORT_EVIDENCE_REF = "mcp_audit_export_visible"
MCP_AUDIT_EXPORT_AUDIT_EVIDENCE_REF = "mcp_audit_export_audit_persisted"
MCP_AUDIT_NO_LIVE_WRITE_EVIDENCE_REF = "mcp_audit_no_live_write_guard"
LANGFUSE_TRACE_ACCESS_CONTRACT_VERSION = "langfuse-trace-access-v1"
LANGFUSE_TRACE_ACCESS_EVIDENCE_REF = "langfuse_trace_access_visible"
LANGFUSE_TRACE_EVENT_EVIDENCE_REF = "langfuse_trace_event_visible"
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
CLOUD_DEPLOYMENT_PREFLIGHT_CONTRACT_VERSION = "cloud-deployment-preflight-v1"
CLOUD_DEPLOYMENT_PREFLIGHT_EVIDENCE_REF = "cloud_deployment_preflight_visible"
ORCHESTRATOR_MANIFEST_CONTRACT_VERSION = "orchestrator-manifest-surface-v1"
ORCHESTRATOR_MANIFEST_EVIDENCE_REF = "orchestrator_manifest_contract_runtime_visible"
ORCHESTRATOR_CHECKPOINT_SURFACE_CONTRACT_VERSION = "orchestrator-checkpoint-surface-v1"
AUTONOMOUS_TEAM_CONTRACT_VERSION = "autonomous-coding-team-v1"
AUTONOMOUS_TEAM_EVIDENCE_REF = "autonomous_team_status_runtime_visible"
AUTONOMOUS_TASK_DISPATCH_CONTRACT_VERSION = "autonomous-task-dispatch-v1"
AUTONOMOUS_TASK_DISPATCH_EVIDENCE_REF = "autonomous_team_dispatch_visible"
AUTONOMOUS_TASK_DISPATCH_UI_EVIDENCE_REF = "autonomous_team_dispatch_ui_visible"
AUTONOMOUS_TASK_DISPATCH_STATUS_EVIDENCE_REF = "autonomous_team_dispatch_status_visible"
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


def llm_gateway_url() -> str:
    return (
        os.getenv("LLM_GATEWAY_URL")
        or os.getenv("LLM_GATEWAY_BASE_URL")
        or "http://llm-gateway:4000"
    ).rstrip("/")


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
        "hetzner_cloud_stack": "hetzner_live_budget_verified" in markers,
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
            "id": "hetzner_api_token",
            "preflight_gate_id": "hetzner_cloud_stack",
            "label": "Hetzner API token",
            "configured": bool(os.getenv("HETZNER_API_TOKEN")) or verified_flags["hetzner_cloud_stack"],
            "verified": verified_flags["hetzner_cloud_stack"],
            "required_env": ["HETZNER_API_TOKEN"],
            "evidence_ref": "hetzner_live_budget_check",
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
        "production_deploy_claim_allowed": verified_flags["production_gate_claim_allowed"],
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


class CspViolationReportRequest(BaseModel):
    report: dict[str, object] = Field(default_factory=dict, validation_alias=AliasChoices("report", "csp-report", "csp_report"))
    user_agent: str | None = Field(default=None, max_length=500, validation_alias=AliasChoices("user_agent", "userAgent"))
    request_id: str | None = Field(default=None, max_length=255, validation_alias=AliasChoices("request_id", "requestId"))
    trace_id: str | None = Field(default=None, max_length=255, validation_alias=AliasChoices("trace_id", "traceId"))

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
    request_id: str | None = Field(default=None, max_length=255)
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
    request_id: str | None = Field(default=None, max_length=255)
    session_id: str | None = Field(default=None, max_length=64)
    model_name: str = Field(..., min_length=1, max_length=120)
    provider_name: str = Field(..., min_length=1, max_length=120)
    agent_type: str = Field(default="unknown", max_length=50)
    status: str = Field(..., pattern="^(dry_run|success|blocked|error)$")
    input_tokens: int = Field(..., ge=0)
    output_tokens: int = Field(..., ge=0)
    cost_cents: int = Field(..., ge=0)
    live_provider_calls: bool = False
    summary: str = Field(..., min_length=1, max_length=500)
    prompt_body_stored: bool = False
    redaction_evidence_ref: str | None = Field(default=None, max_length=120)

    @field_validator("session_id")
    @classmethod
    def validate_session_uuid(cls, value: str | None) -> str | None:
        if value is None:
            return None
        try:
            return str(UUID(value))
        except (TypeError, ValueError) as exc:
            raise ValueError("session_id must be a valid UUID") from exc


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
AUTH_AUDIT_SNAPSHOT_CONTRACT_VERSION = "auth-audit-snapshot-v1"
AUTH_AUDIT_RISK_ROLLUP_CONTRACT_VERSION = "auth-audit-risk-rollup-v1"
AUTH_AUDIT_TIMELINE_CONTRACT_VERSION = "auth-audit-timeline-v1"
AUTH_AUDIT_EXPORT_CONTRACT_VERSION = "auth-audit-export-v1"
AUTH_AUDIT_SNAPSHOT_EVIDENCE_REF = "auth_audit_snapshot_visible"
AUTH_AUDIT_RISK_ROLLUP_EVIDENCE_REF = "auth_audit_risk_rollup_visible"
AUTH_AUDIT_TIMELINE_EVIDENCE_REF = "auth_audit_timeline_visible"
AUTH_AUDIT_EXPORT_EVIDENCE_REF = "auth_audit_export_visible"
AUTH_AUDIT_EXPORT_AUDIT_EVIDENCE_REF = "auth_audit_export_audit_persisted"
AUTH_AUDIT_REDACTION_EVIDENCE_REF = "auth_audit_redaction_enforced"
AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF = "auth_no_live_oauth_guard"
AUTH_PUBLIC_TRACE_ID_ALLOWED_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-")
PUBLIC_AUDIT_OMIT_DETAIL_KEYS = {
    "access-token",
    "refresh-token",
    "blacklist-key",
    "authorization",
    "authorization-header",
    "cookie",
    "set-cookie",
    "code",
    "state",
}
PUBLIC_AUDIT_SENSITIVE_KEY_PREFIXES = (
    "accesstoken",
    "refreshtoken",
    "blacklistkey",
    "authorization",
    "cookie",
    "setcookie",
    "jwttoken",
    "bearertoken",
    "tokenhash",
)
PUBLIC_AUDIT_SENSITIVE_KEY_EXACT = {
    "code",
    "codes",
    "oauthcode",
    "oauthcodes",
    "state",
    "states",
    "oauthstate",
    "oauthstates",
    "jwt",
    "bearer",
}
DSGVO_PURGE_CONTRACT_VERSION = "memory-dsgvo-purge-v1"
COST_EXPORT_CONTRACT_VERSION = "cost-monitor-export-v1"
SYSTEM_FALLBACK_CONTRACT_VERSION = "system-unavailable-fallback-v1"
AGENT_ACTIVITY_CONTRACT_VERSION = "agent-activity-trace-v1"
HEALTH_CONTRACT_VERSION = "health-surface-v1"
LIVE_AGENT_STEERING_CONTRACT_VERSION = "live-agent-steering-v1"
LIVE_AGENT_STEERING_EVIDENCE_REF = "live_agent_steering_contract_visible"
LIVE_AGENT_SESSION_PREFIX = "live-agent:responses:"
LIVE_AGENT_SESSION_TTL_SECONDS = TASK_TTL_SECONDS
LIVE_AGENT_LLM_TIMEOUT_SECONDS = 120
LIVE_AGENT_RESERVED_METADATA_KEYS = {
    "agent_id",
    "agent_type",
    "logical_agent_id",
    "live_provider_calls_allowed",
    "previous_response_id",
    "project_id",
    "response_id",
    "runtime_policy",
    "trace_id",
}
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
    return os.getenv("HF_DEFAULT_CHAT_MODEL", "deepseek-ai/DeepSeek-V4-Flash:fastest")


def sanitize_live_agent_metadata(metadata: dict[str, object] | None) -> dict[str, object]:
    safe_metadata: dict[str, object] = {}
    for raw_key, value in (metadata or {}).items():
        key = str(raw_key).strip()
        normalized_key = key.lower()
        if (
            not key
            or len(key) > 64
            or normalized_key in LIVE_AGENT_RESERVED_METADATA_KEYS
            or normalized_key.startswith(("live_provider", "agent_", "logical_agent", "trace_", "project_", "response_"))
        ):
            continue
        if isinstance(value, (str, int, float, bool)) or value is None:
            safe_metadata[key] = value
    return safe_metadata


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
) -> dict[str, object]:
    payload = {
        "agent_id": agent_id,
        "previous_response_id": response_id,
        "project_id": project_id,
        "model": model,
        "execution_role": execution_role,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
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
        "history_endpoint": "GET /api/v1/live-agents/history",
        "compatibility_endpoint": "POST /api/steer-agent",
        "llm_gateway_endpoint": "POST /llm/v1/responses",
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
            "response_id",
            "responseId",
            "text",
            "status",
            "model",
            "usage",
            "runtime_source",
            "audit_persisted",
            "audit_evidence_ref",
            "trace_id",
            "request_id",
        ],
        "history_fields": [
            "agent_id",
            "execution_role",
            "project_id",
            "response_id",
            "previous_response_id",
            "status",
            "model",
            "trace_id",
            "request_id",
            "response_preview",
            "created_at",
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
        "metadata_policy": {
            "reserved_keys_stripped": sorted(LIVE_AGENT_RESERVED_METADATA_KEYS),
            "reserved_prefixes_stripped": ["live_provider", "agent_", "logical_agent", "trace_", "project_", "response_"],
            "live_provider_calls_allowed": False,
            "system_metadata_wins": True,
        },
        "evidence_refs": {
            "contract_visible": LIVE_AGENT_STEERING_EVIDENCE_REF,
            "ui_visible": "live_agent_steering_ui_visible",
            "security_guard": "live_agent_metadata_guard_enforced",
            "audit_persisted": "live_agent_steering_audit_persisted",
            "history_visible": "live_agent_steering_history_visible",
        },
        "non_claims": [
            "No API key is stored by this contract surface.",
            "Responses streaming passthrough is not exposed on this path.",
            "End-user metadata cannot enable live provider calls or override system trace/agent fields.",
            "Live agent history is a read-only audit-log projection and does not execute a model request.",
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
            }
        )
    return {
        "status": "available",
        "contract_version": LIVE_AGENT_STEERING_CONTRACT_VERSION,
        "runtime_source": "openai_responses_via_llm_gateway",
        "default_model": live_agent_default_model(),
        "agent_count": len(agents),
        "agents": agents,
        "history_endpoint": "GET /api/v1/live-agents/history",
        "evidence_ref": LIVE_AGENT_STEERING_EVIDENCE_REF,
    }


def live_agent_history_row_to_event(row: tuple[object, ...]) -> dict[str, object]:
    details = row[4] or {}
    if not isinstance(details, dict):
        details = {}
    return {
        "id": str(row[0]),
        "event_type": row[1],
        "agent_id": str(details.get("agent") or details.get("agent_id") or "unknown"),
        "execution_role": str(details.get("agent_type") or details.get("agent_role") or row[2] or "unknown"),
        "project_id": details.get("project_id"),
        "response_id": details.get("response_id"),
        "previous_response_id": details.get("previous_response_id"),
        "status": details.get("status"),
        "model": details.get("model"),
        "trace_id": str(details.get("trace_id") or "none"),
        "request_id": str(details.get("request_id") or "none"),
        "response_preview": str(details.get("response_preview") or ""),
        "runtime_source": details.get("runtime_source") or "openai_responses_via_llm_gateway",
        "live_provider_calls": bool(details.get("live_provider_calls", False)),
        "audit_persisted": True,
        "evidence_ref": details.get("evidence_ref") or "live_agent_steering_audit_persisted",
        "created_at": row[5].isoformat() if row[5] else None,
        "severity": row[6],
    }


def live_agent_history_payload(
    agent_id: str | None = None,
    project_id: str | None = None,
    limit: int = 10,
) -> dict[str, object]:
    conditions = ["event_type = 'live_agent_steered'"]
    params: list[object] = []
    if agent_id:
        profile = resolve_live_agent_profile(agent_id)
        resolved_agent_id = str(profile["agent_id"])
        conditions.append("details->>'agent' = %s")
        params.append(resolved_agent_id)
    if project_id:
        conditions.append("details->>'project_id' = %s")
        params.append(project_id)
    params.append(limit)
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            f"""
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE {' AND '.join(conditions)}
            ORDER BY created_at DESC
            LIMIT %s
            """,
            tuple(params),
        ).fetchall()
    events = [live_agent_history_row_to_event(row) for row in rows]
    return {
        "contract_version": LIVE_AGENT_STEERING_CONTRACT_VERSION,
        "status": "available",
        "mode": "audit_log_backed_live_agent_history",
        "history_endpoint": "GET /api/v1/live-agents/history",
        "applied_filters": {"agent_id": agent_id, "project_id": project_id, "limit": limit},
        "history_count": len(events),
        "events": events,
        "evidence_ref": "live_agent_steering_history_visible",
        "non_claims": [
            "History reads existing live_agent_steered audit rows only.",
            "History retrieval does not call the LLM Gateway or any model provider.",
        ],
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
                (event_type, Json(auth_audit_details(details)), severity),
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
            "audit_contract": "/api/v1/audit/auth/contract",
            "audit_snapshot": "/api/v1/audit/auth/snapshot",
            "audit_risk_rollup": "/api/v1/audit/auth/risk-rollup",
            "audit_timeline": "/api/v1/audit/auth/timeline",
        },
        "evidence_refs": {
            "contract": "auth_contract_visible",
            "refresh_rotated": "auth_refresh_rotated",
            "refresh_reuse_blocked": "auth_refresh_reuse_blocked",
            "logout_revoked": "auth_logout_revoked",
            "audit_snapshot": AUTH_AUDIT_SNAPSHOT_EVIDENCE_REF,
            "audit_risk_rollup": AUTH_AUDIT_RISK_ROLLUP_EVIDENCE_REF,
            "audit_timeline": AUTH_AUDIT_TIMELINE_EVIDENCE_REF,
            "audit_export": AUTH_AUDIT_EXPORT_EVIDENCE_REF,
            "audit_redaction": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
            "no_live_oauth": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
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


AUTH_AUDIT_EVENT_TYPES = (
    "auth_github_callback_contract",
    "auth_refresh_rotated",
    "auth_refresh_reuse_blocked",
    "auth_logout_revoked",
)


def auth_audit_contract_payload() -> dict[str, object]:
    return {
        "contract_version": AUTH_AUDIT_SNAPSHOT_CONTRACT_VERSION,
        "parent_contract_version": "auth-github-jwt-refresh-v1",
        "mode": "read_only_auth_audit_snapshot",
        "endpoint": "GET /api/v1/audit/auth/snapshot",
        "risk_rollup_endpoint": "GET /api/v1/audit/auth/risk-rollup",
        "timeline_endpoint": "GET /api/v1/audit/auth/timeline",
        "export_endpoint": "GET /api/v1/audit/auth/export?format=csv&limit=80",
        "export_contract_endpoint": "GET /api/v1/audit/auth/export/contract",
        "contract_endpoint": "GET /api/v1/audit/auth/contract",
        "risk_rollup_contract_version": AUTH_AUDIT_RISK_ROLLUP_CONTRACT_VERSION,
        "timeline_contract_version": AUTH_AUDIT_TIMELINE_CONTRACT_VERSION,
        "export_contract_version": AUTH_AUDIT_EXPORT_CONTRACT_VERSION,
        "supported_export_formats": ["csv"],
        "source_table": "audit_log",
        "source_event_types": list(AUTH_AUDIT_EVENT_TYPES),
        "evidence_ref": AUTH_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "risk_rollup_evidence_ref": AUTH_AUDIT_RISK_ROLLUP_EVIDENCE_REF,
        "timeline_evidence_ref": AUTH_AUDIT_TIMELINE_EVIDENCE_REF,
        "export_evidence_ref": AUTH_AUDIT_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": AUTH_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
        "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
        "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_github_oauth_call_claimed": False,
        "tokens_returned": False,
        "cookies_returned": False,
        "authorization_headers_returned": False,
        "blacklist_keys_returned": False,
        "oauth_codes_returned": False,
        "oauth_states_returned": False,
        "safe_event_fields": [
            "event_id",
            "event_type",
            "trace_id",
            "lifecycle_step",
            "status",
            "severity",
            "created_at",
            "code_present",
            "cookie_flags",
            "live_github_oauth_call",
            "evidence_ref",
            "redaction_evidence_ref",
            "no_live_oauth_evidence_ref",
        ],
        "timeline_fields": [
            "sequence_index",
            "event_id",
            "created_at",
            "event_type",
            "timeline_leg",
            "trace_id",
            "lifecycle_step",
            "status",
            "severity",
            "code_present",
            "cookie_flags",
            "live_github_oauth_call",
            "evidence_ref",
            "redaction_evidence_ref",
            "no_live_oauth_evidence_ref",
        ],
        "export_columns": [
            "sequence_index",
            "event_id",
            "created_at",
            "event_type",
            "lifecycle_step",
            "status",
            "severity",
            "trace_id",
            "code_present",
            "cookie_http_only",
            "cookie_secure",
            "cookie_same_site",
            "live_github_oauth_call",
            "evidence_ref",
            "redaction_evidence_ref",
            "no_live_oauth_evidence_ref",
        ],
        "policy_checks": [
            "Snapshot reads audit_log only and never starts OAuth, refresh, logout, or token issuance flows.",
            "Returned events are reduced to safe auth lifecycle fields only.",
            "Refresh tokens, access tokens, cookies, authorization headers, OAuth code/state values, and Redis blacklist keys are omitted.",
            "Any live GitHub OAuth call claim or forbidden credential pattern blocks the snapshot.",
            "The risk rollup is computed from the same safe auth audit projection and never performs auth writes or live OAuth calls.",
            "The timeline is computed from the same safe auth audit projection and never returns raw audit_log details.",
            "The CSV export is generated from the same safe auth audit projection and logs only redacted export metadata.",
        ],
        "non_claims": [
            "This endpoint does not perform or prove a live GitHub OAuth exchange.",
            "This endpoint does not return tokens, cookies, OAuth codes, OAuth states, Redis blacklist keys, or authorization headers.",
            "This endpoint does not authorize production identity rollout or release promotion.",
            "The export is operator evidence only and is not a SOC/SIEM completion claim.",
        ],
    }


def auth_audit_rows(limit: int) -> list[object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        return conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type IN (
              'auth_github_callback_contract',
              'auth_refresh_rotated',
              'auth_refresh_reuse_blocked',
              'auth_logout_revoked'
            )
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()


def auth_lifecycle_step(event_type: str) -> str:
    if event_type == "auth_github_callback_contract":
        return "dry_run_callback"
    if event_type == "auth_refresh_rotated":
        return "refresh_rotation"
    if event_type == "auth_refresh_reuse_blocked":
        return "refresh_reuse_block"
    if event_type == "auth_logout_revoked":
        return "logout_revoke"
    return "unknown"


def public_correlation_id(value: object, redacted_prefix: str) -> str | None:
    if value is None:
        return None
    text = redact_text(str(value).strip())
    if not text:
        return None
    if len(text) > 96 or any(char not in AUTH_PUBLIC_TRACE_ID_ALLOWED_CHARS for char in text):
        return redacted_prefix + "-redacted-" + hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    if redact_text(text) != text:
        return redacted_prefix + "-redacted-" + hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    return text


def public_trace_id(value: object) -> str | None:
    return public_correlation_id(value, "trace")


def public_request_id(value: object) -> str | None:
    return public_correlation_id(value, "request")


def public_audit_key_is_sensitive(key: str) -> bool:
    compact = "".join(char for char in key.lower() if char.isalnum())
    return compact in PUBLIC_AUDIT_SENSITIVE_KEY_EXACT or any(
        compact.startswith(prefix) for prefix in PUBLIC_AUDIT_SENSITIVE_KEY_PREFIXES
    )


def public_audit_details(value: object) -> object:
    redacted = redact_json(value)
    if isinstance(redacted, dict):
        public: dict[str, object] = {}
        for raw_key, item in redacted.items():
            key = str(raw_key)
            normalized = key.strip().lower().replace("_", "-")
            if normalized in PUBLIC_AUDIT_OMIT_DETAIL_KEYS or public_audit_key_is_sensitive(key):
                public[f"{normalized.replace('-', '_')}_redacted"] = True
                continue
            public[key] = public_audit_details(item)
        if "trace_id" in public:
            public["trace_id"] = public_trace_id(public.get("trace_id"))
        if "request_id" in public:
            public["request_id"] = public_request_id(public.get("request_id"))
        return public
    if isinstance(redacted, list):
        return [public_audit_details(item) for item in redacted]
    if isinstance(redacted, tuple):
        return [public_audit_details(item) for item in redacted]
    return redacted


def auth_audit_details(details: dict[str, object]) -> dict[str, object]:
    safe_details = public_audit_details(details)
    return safe_details if isinstance(safe_details, dict) else {}


def safe_auth_audit_event(row: object) -> dict[str, object]:
    details = auth_audit_details(row[4] or {})
    if not isinstance(details, dict):
        details = {}
    event_type = str(row[1])
    trace_id = public_trace_id(details.get("trace_id"))
    live_github_oauth_call = bool(details.get("live_github_oauth_call") is True)
    cookie_flags = details.get("cookie_flags") if isinstance(details.get("cookie_flags"), dict) else {}
    return {
        "event_id": str(row[0]),
        "event_type": event_type,
        "trace_id": trace_id,
        "lifecycle_step": auth_lifecycle_step(event_type),
        "status": "blocked" if event_type == "auth_refresh_reuse_blocked" else "verified",
        "severity": row[6],
        "created_at": row[5].isoformat() if row[5] else None,
        "code_present": bool(details.get("code_present")) if "code_present" in details else None,
        "cookie_flags": {
            "HttpOnly": bool(cookie_flags.get("HttpOnly")) if "HttpOnly" in cookie_flags else None,
            "Secure": bool(cookie_flags.get("Secure")) if "Secure" in cookie_flags else None,
            "SameSite": str(cookie_flags.get("SameSite")) if cookie_flags.get("SameSite") else None,
        },
        "live_github_oauth_call": live_github_oauth_call,
        "evidence_ref": event_type,
        "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
        "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
    }


def auth_audit_forbidden_pattern_hits(events: list[dict[str, object]]) -> int:
    forbidden = (
        "sk-proj-",
        "sk-",
        "ghp_",
        "github_pat_",
        "vck_",
        "cfat_",
        "hcloud_",
        "hf_",
        "glpat-",
        "authorization:",
        "cookie:",
        "set-cookie",
        '"access_token":',
        '"refresh_token":',
        '"blacklist_key":',
        '"code":',
        '"state":',
        "private key",
    )
    text = json.dumps(events, sort_keys=True).lower()
    return sum(1 for marker in forbidden if marker in text)


def build_auth_audit_snapshot(events: list[dict[str, object]]) -> dict[str, object]:
    forbidden_pattern_hits = auth_audit_forbidden_pattern_hits(events)
    live_github_oauth_call_count = sum(1 for event in events if event.get("live_github_oauth_call") is True)
    return {
        **auth_audit_contract_payload(),
        "events_scanned": len(events),
        "event_type_counts": count_by_key([str(event.get("event_type")) for event in events]),
        "lifecycle_step_counts": count_by_key([str(event.get("lifecycle_step")) for event in events]),
        "severity_counts": count_by_key([str(event.get("severity")) if event.get("severity") else None for event in events]),
        "live_github_oauth_call_count": live_github_oauth_call_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "oauth_status": "dry_run_only" if live_github_oauth_call_count == 0 else "blocked",
        "events": events[:20],
    }


def build_auth_audit_risk_rollup(events: list[dict[str, object]]) -> dict[str, object]:
    forbidden_pattern_hits = auth_audit_forbidden_pattern_hits(events)
    live_github_oauth_call_count = sum(1 for event in events if event.get("live_github_oauth_call") is True)
    event_type_counts = count_by_key([str(event.get("event_type")) for event in events])
    lifecycle_step_counts = count_by_key([str(event.get("lifecycle_step")) for event in events])
    status_counts = count_by_key([str(event.get("status")) if event.get("status") else None for event in events])
    severity_counts = count_by_key([str(event.get("severity")) if event.get("severity") else None for event in events])
    dry_run_callback_count = int(event_type_counts.get("auth_github_callback_contract", 0))
    refresh_rotation_count = int(event_type_counts.get("auth_refresh_rotated", 0))
    refresh_reuse_block_count = int(event_type_counts.get("auth_refresh_reuse_blocked", 0))
    logout_revoke_count = int(event_type_counts.get("auth_logout_revoked", 0))
    blocker_count = forbidden_pattern_hits + live_github_oauth_call_count
    review_count = refresh_reuse_block_count
    if blocker_count > 0:
        risk_status = "blocked"
    elif review_count > 0:
        risk_status = "review"
    else:
        risk_status = "clear"
    risk_badges = [
        {
            "id": "redaction",
            "label": "Redaction",
            "status": "clear" if forbidden_pattern_hits == 0 else "blocked",
            "count": forbidden_pattern_hits,
            "evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
        },
        {
            "id": "no_live_oauth",
            "label": "No Live OAuth",
            "status": "clear" if live_github_oauth_call_count == 0 else "blocked",
            "count": live_github_oauth_call_count,
            "evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
        },
        {
            "id": "refresh_reuse_blocked",
            "label": "Refresh Reuse Blocked",
            "status": "review" if refresh_reuse_block_count > 0 else "clear",
            "count": refresh_reuse_block_count,
            "evidence_ref": "auth_refresh_reuse_blocked",
        },
        {
            "id": "refresh_rotation",
            "label": "Refresh Rotation",
            "status": "verified" if refresh_rotation_count > 0 else "watch",
            "count": refresh_rotation_count,
            "evidence_ref": "auth_refresh_rotated",
        },
        {
            "id": "logout_revoke",
            "label": "Logout Revoke",
            "status": "verified" if logout_revoke_count > 0 else "watch",
            "count": logout_revoke_count,
            "evidence_ref": "auth_logout_revoked",
        },
    ]
    return {
        "contract_version": AUTH_AUDIT_RISK_ROLLUP_CONTRACT_VERSION,
        "parent_contract_version": AUTH_AUDIT_SNAPSHOT_CONTRACT_VERSION,
        "mode": "read_only_auth_audit_risk_rollup",
        "endpoint": "GET /api/v1/audit/auth/risk-rollup",
        "snapshot_endpoint": "GET /api/v1/audit/auth/snapshot",
        "contract_endpoint": "GET /api/v1/audit/auth/contract",
        "source_table": "audit_log",
        "source_event_types": list(AUTH_AUDIT_EVENT_TYPES),
        "evidence_ref": AUTH_AUDIT_RISK_ROLLUP_EVIDENCE_REF,
        "snapshot_evidence_ref": AUTH_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
        "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
        "read_only": True,
        "live_github_oauth_call_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "tokens_returned": False,
        "cookies_returned": False,
        "authorization_headers_returned": False,
        "blacklist_keys_returned": False,
        "oauth_codes_returned": False,
        "oauth_states_returned": False,
        "events_scanned": len(events),
        "risk_status": risk_status,
        "blocker_count": blocker_count,
        "review_count": review_count,
        "dry_run_callback_count": dry_run_callback_count,
        "refresh_rotation_count": refresh_rotation_count,
        "refresh_reuse_block_count": refresh_reuse_block_count,
        "logout_revoke_count": logout_revoke_count,
        "live_github_oauth_call_count": live_github_oauth_call_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "oauth_status": "dry_run_only" if live_github_oauth_call_count == 0 else "blocked",
        "event_type_counts": event_type_counts,
        "lifecycle_step_counts": lifecycle_step_counts,
        "status_counts": status_counts,
        "severity_counts": severity_counts,
        "risk_badges": risk_badges,
        "policy_checks": [
            "Risk rollup reads audit_log through the safe auth audit projection only.",
            "Risk rollup never starts OAuth, refresh, logout, token issuance, deployment, or production promotion flows.",
            "Refresh-token reuse blocks are review evidence, not release blockers, when redaction and no-live-OAuth guards stay clear.",
            "Any forbidden pattern or live GitHub OAuth claim raises blocker_count and risk_status=blocked.",
        ],
        "non_claims": auth_audit_contract_payload()["non_claims"],
    }


def build_auth_audit_timeline(events: list[dict[str, object]]) -> dict[str, object]:
    forbidden_pattern_hits = auth_audit_forbidden_pattern_hits(events)
    ordered_events = sorted(events, key=lambda event: str(event.get("created_at") or ""))
    timeline: list[dict[str, object]] = []
    for index, event in enumerate(ordered_events[:80], start=1):
        event_type = str(event.get("event_type") or "unknown")
        timeline.append(
            {
                "sequence_index": index,
                "event_id": event.get("event_id"),
                "created_at": event.get("created_at"),
                "event_type": event_type,
                "timeline_leg": auth_lifecycle_step(event_type),
                "trace_id": public_trace_id(event.get("trace_id")),
                "lifecycle_step": event.get("lifecycle_step"),
                "status": event.get("status"),
                "severity": event.get("severity"),
                "code_present": event.get("code_present"),
                "cookie_flags": event.get("cookie_flags"),
                "live_github_oauth_call": event.get("live_github_oauth_call") is True,
                "evidence_ref": event.get("evidence_ref"),
                "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
                "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
            }
        )
    live_github_oauth_call_count = sum(1 for event in timeline if event["live_github_oauth_call"] is True)
    return {
        "contract_version": AUTH_AUDIT_TIMELINE_CONTRACT_VERSION,
        "parent_contract_version": AUTH_AUDIT_SNAPSHOT_CONTRACT_VERSION,
        "mode": "read_only_auth_audit_timeline",
        "endpoint": "GET /api/v1/audit/auth/timeline",
        "snapshot_endpoint": "GET /api/v1/audit/auth/snapshot",
        "risk_rollup_endpoint": "GET /api/v1/audit/auth/risk-rollup",
        "contract_endpoint": "GET /api/v1/audit/auth/contract",
        "source_table": "audit_log",
        "source_event_types": list(AUTH_AUDIT_EVENT_TYPES),
        "evidence_ref": AUTH_AUDIT_TIMELINE_EVIDENCE_REF,
        "snapshot_evidence_ref": AUTH_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "risk_rollup_evidence_ref": AUTH_AUDIT_RISK_ROLLUP_EVIDENCE_REF,
        "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
        "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
        "read_only": True,
        "live_github_oauth_call_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "tokens_returned": False,
        "cookies_returned": False,
        "authorization_headers_returned": False,
        "blacklist_keys_returned": False,
        "oauth_codes_returned": False,
        "oauth_states_returned": False,
        "events_scanned": len(events),
        "timeline_count": len(timeline),
        "live_github_oauth_call_count": live_github_oauth_call_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "oauth_status": "dry_run_only" if live_github_oauth_call_count == 0 else "blocked",
        "event_type_counts": count_by_key([str(event.get("event_type")) for event in events]),
        "timeline_leg_counts": count_by_key([str(event.get("timeline_leg")) for event in timeline]),
        "status_counts": count_by_key([str(event.get("status")) if event.get("status") else None for event in timeline]),
        "severity_counts": count_by_key([str(event.get("severity")) if event.get("severity") else None for event in timeline]),
        "timeline": timeline,
        "policy_checks": [
            "Timeline reads audit_log through the safe auth audit projection only.",
            "Timeline never starts OAuth, refresh, logout, token issuance, deployment, or production promotion flows.",
            "Timeline entries expose ordering and lifecycle fields only; raw audit_log details remain omitted.",
            "Any forbidden pattern or live GitHub OAuth claim raises redaction/oauth blocked status.",
        ],
        "non_claims": auth_audit_contract_payload()["non_claims"],
    }


def auth_audit_export_contract_payload() -> dict[str, object]:
    contract = auth_audit_contract_payload()
    return {
        "contract_version": AUTH_AUDIT_EXPORT_CONTRACT_VERSION,
        "parent_contract_version": AUTH_AUDIT_SNAPSHOT_CONTRACT_VERSION,
        "mode": "read_only_auth_audit_csv_export",
        "endpoint": "GET /api/v1/audit/auth/export?format=csv&limit=80",
        "contract_endpoint": "GET /api/v1/audit/auth/export/contract",
        "snapshot_endpoint": "GET /api/v1/audit/auth/snapshot",
        "risk_rollup_endpoint": "GET /api/v1/audit/auth/risk-rollup",
        "timeline_endpoint": "GET /api/v1/audit/auth/timeline",
        "source_table": "audit_log",
        "source_event_types": list(AUTH_AUDIT_EVENT_TYPES),
        "supported_formats": ["csv"],
        "default_format": "csv",
        "default_limit": 80,
        "max_limit": 200,
        "filename_pattern": "superbrain-auth-audit.csv",
        "columns": contract["export_columns"],
        "evidence_ref": AUTH_AUDIT_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": AUTH_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
        "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
        "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_github_oauth_call_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "tokens_returned": False,
        "cookies_returned": False,
        "authorization_headers_returned": False,
        "blacklist_keys_returned": False,
        "oauth_codes_returned": False,
        "oauth_states_returned": False,
        "raw_details_returned": False,
        "policy_checks": [
            "Export reads audit_log through the safe auth audit projection only.",
            "Export emits CSV columns from the allowlisted auth audit fields only.",
            "Export never starts OAuth, refresh, logout, token issuance, deployment, or production promotion flows.",
            "Export audit logging stores only redacted metadata: contract version, row count, trace id, request id, format, and evidence ref.",
            "Any forbidden pattern in exported rows blocks the verifier.",
        ],
        "non_claims": contract["non_claims"],
    }


def csv_safe_value(value: object) -> object:
    if value is None or isinstance(value, bool | int | float):
        return value
    text = str(value)
    if text.startswith(("=", "+", "-", "@", "\t", "\r", "\n")):
        return "'" + text
    return text


def build_auth_audit_export_csv(events: list[dict[str, object]]) -> str:
    output = io.StringIO()
    fieldnames = auth_audit_export_contract_payload()["columns"]
    writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    ordered_events = sorted(events, key=lambda event: str(event.get("created_at") or ""))
    for index, event in enumerate(ordered_events, start=1):
        cookie_flags = event.get("cookie_flags") if isinstance(event.get("cookie_flags"), dict) else {}
        row = {
            "sequence_index": index,
            "event_id": event.get("event_id"),
            "created_at": event.get("created_at"),
            "event_type": event.get("event_type"),
            "lifecycle_step": event.get("lifecycle_step"),
            "status": event.get("status"),
            "severity": event.get("severity"),
            "trace_id": public_trace_id(event.get("trace_id")),
            "code_present": event.get("code_present"),
            "cookie_http_only": cookie_flags.get("HttpOnly"),
            "cookie_secure": cookie_flags.get("Secure"),
            "cookie_same_site": cookie_flags.get("SameSite"),
            "live_github_oauth_call": event.get("live_github_oauth_call") is True,
            "evidence_ref": event.get("evidence_ref"),
            "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
            "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
        }
        writer.writerow({key: csv_safe_value(value) for key, value in row.items()})
    return output.getvalue()


def persist_auth_audit_export_audit(format: str, row_count: int, trace_id: str, request_id: str) -> None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('auth_audit_export_generated', 'auth-audit', %s::jsonb, 'info')
                """,
                (
                    Json(
                        redact_json(
                            {
                                "contract_version": AUTH_AUDIT_EXPORT_CONTRACT_VERSION,
                                "trace_id": trace_id,
                                "request_id": request_id,
                                "format": format,
                                "row_count": row_count,
                                "evidence_ref": AUTH_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
                                "redaction_evidence_ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
                                "no_live_oauth_evidence_ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
                            }
                        )
                    ),
                ),
            )
    except Exception as exc:  # pragma: no cover - audit persistence must not break exports
        print(f"auth audit export audit failed: {exc}")


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
        "infra_supported_sources": ["projection", "hetzner_api_readonly"],
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
            "GET /api/v1/observability/langfuse/trace/{trace_id}",
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
            "response_id",
            "runtime_source",
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
            "live_agent_steering_audit_visible",
            "langfuse_trace_access_audit_backed",
        ],
        "evidence_refs": {
            "contract_visible": "agent_activity_contract_visible",
            "trace_link_template": "agent_activity_trace_link_template",
            "auth_proxy_required": "langfuse_auth_proxy_required",
            "filtered_feed": "agent_activity_filtered_feed_visible",
            "per_role_results": "agent_activity_per_role_results_visible",
            "failure_surface": "agent_activity_failure_surface_visible",
            "live_agent_steering_audit": "live_agent_steering_audit_persisted",
            "trace_access": LANGFUSE_TRACE_ACCESS_EVIDENCE_REF,
            "trace_event": LANGFUSE_TRACE_EVENT_EVIDENCE_REF,
        },
        "non_claims": [
            "This contract does not claim public unauthenticated Langfuse access.",
            "This contract does not claim live Langfuse traces until LANGFUSE_PUBLIC_URL is configured.",
            "Audit-log activity remains the local source of truth for Phase 3.",
        ],
    }


def langfuse_trace_access_contract_payload() -> dict[str, object]:
    langfuse_public_url = os.getenv("LANGFUSE_PUBLIC_URL", "").rstrip("/")
    auth_proxy_path = os.getenv("LANGFUSE_AUTH_PROXY_PATH", "/observability/langfuse")
    deep_link_template = (
        f"{langfuse_public_url}/trace/{{trace_id}}"
        if langfuse_public_url
        else f"{auth_proxy_path}/trace/{{trace_id}}"
    )
    return {
        "contract_version": LANGFUSE_TRACE_ACCESS_CONTRACT_VERSION,
        "mode": "audit_log_backed_trace_access",
        "screen": "Langfuse Trace Access",
        "endpoint": "GET /api/v1/observability/langfuse/trace/{trace_id}",
        "contract_endpoint": "GET /api/v1/observability/langfuse/contract",
        "source_table": "audit_log",
        "source_endpoint": "GET /api/v1/agent-activity/recent?trace_id={trace_id}",
        "deep_link_template": deep_link_template,
        "langfuse_public_url_configured": bool(langfuse_public_url),
        "auth_proxy_required": True,
        "read_only": True,
        "live_langfuse_trace_claimed": bool(langfuse_public_url),
        "provider_trace_export": False,
        "evidence_ref": LANGFUSE_TRACE_ACCESS_EVIDENCE_REF,
        "event_evidence_ref": LANGFUSE_TRACE_EVENT_EVIDENCE_REF,
        "required_trace_fields": ["trace_id", "event_type", "severity", "created_at", "details"],
        "policy_checks": [
            "Trace lookup reads audit_log only.",
            "No public unauthenticated Langfuse access is claimed.",
            "Provider trace export remains disabled until live Langfuse is configured.",
            "The response redacts audit details before returning them.",
        ],
        "non_claims": [
            "No live Langfuse deployment is claimed unless LANGFUSE_PUBLIC_URL is configured.",
            "No provider-side trace export or purge is claimed.",
            "No production observability auth proxy is claimed.",
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
            "dispatch_id",
            "logical_role",
            "provenance_evidence_ref",
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
            "Recent tasks expose autonomous dispatch_id, logical_role, and provenance evidence when created by the autonomous team dispatcher.",
            "Recent tasks remain aligned with internal task status and audit evidence.",
        ],
        "evidence_refs": {
            "contract_visible": "recent_tasks_contract_visible",
            "runtime_visible": "hosted_recent_tasks_contract_runtime_parity_proof",
            "request_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
            "priority_queue": "task_priority_queue_correction_proof",
            "dispatch_provenance": "autonomous_team_dispatch_task_provenance",
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
        "contract_version": MCP_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "mcp_tool_audit_runtime_feed",
        "endpoint": "GET /api/v1/audit/mcp",
        "snapshot_endpoint": "GET /api/v1/audit/mcp/snapshot",
        "export_endpoint": "GET /api/v1/audit/mcp/export?format=csv&limit=80",
        "export_contract_endpoint": "GET /api/v1/audit/mcp/export/contract",
        "export_contract_version": MCP_AUDIT_EXPORT_CONTRACT_VERSION,
        "source_event_type": "mcp_tool_executed",
        "source_table": "audit_log",
        "supported_export_formats": ["csv"],
        "screen": "MCP Audit",
        "evidence_ref": MCP_AUDIT_FEED_EVIDENCE_REF,
        "snapshot_evidence_ref": MCP_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "redaction_evidence_ref": MCP_AUDIT_REDACTION_EVIDENCE_REF,
        "export_evidence_ref": MCP_AUDIT_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": MCP_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
        "no_live_write_evidence_ref": MCP_AUDIT_NO_LIVE_WRITE_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_mcp_writes_claimed": False,
        "input_refs_returned": False,
        "provider_credentials_returned": False,
        "raw_details_returned": False,
        "source_endpoints": [
            "GET /api/v1/audit/mcp?limit=20",
            "GET /api/v1/audit/mcp/snapshot",
            "GET /api/v1/audit/mcp/export?format=csv&limit=80",
            "POST /internal/audit/mcp-tool-events",
            "GET /api/v1/audit/recent?limit=50",
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
        "required_detail_fields": [
            "tool_request_id",
            "run_id",
            "request_id",
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
            "redaction_evidence_ref",
            "input_ref_stored",
            "correlation_evidence_ref",
            "audit_feed_evidence_ref",
        ],
        "export_columns": [
            "sequence_index",
            "event_id",
            "created_at",
            "event_type",
            "severity",
            "trace_id",
            "request_id",
            "session_id",
            "agent_role",
            "toolset",
            "capability",
            "status",
            "error_class",
            "duration_ms",
            "retry_after_ms",
            "session_bound",
            "input_ref_stored",
            "live_mcp_writes",
            "evidence_ref",
            "audit_feed_evidence_ref",
            "correlation_evidence_ref",
            "redaction_evidence_ref",
            "no_live_mcp_write_evidence_ref",
        ],
        "blocked_detail_fields": [
            "denied_tool_correlation_evidence_ref",
        ],
        "supported_statuses": ["success", "blocked", "timeout", "degraded"],
        "supported_toolsets": ["github", "e2b", "playwright", "filesystem", "postgresql", "puppeteer"],
        "policy_checks": [
            "MCP audit feed exposes session-bound tool execution events as a public runtime surface.",
            "Feed stays aligned with internal MCP audit writes and carries visible trace and evidence references.",
            "Feed remains non-mutating and does not claim live MCP writes were executed.",
            "The snapshot endpoint aggregates redacted audit fields and never returns tool input refs.",
            "The CSV export emits only allowlisted MCP audit fields and logs redacted export metadata.",
        ],
        "evidence_refs": {
            "contract_visible": MCP_AUDIT_FEED_EVIDENCE_REF,
            "runtime_visible": "hosted_mcp_audit_feed_contract_runtime_parity_proof",
            "session_bound_audit": "mcp_tool_session_bound_audit",
            "snapshot_visible": MCP_AUDIT_SNAPSHOT_EVIDENCE_REF,
            "redaction_enforced": MCP_AUDIT_REDACTION_EVIDENCE_REF,
            "export_visible": MCP_AUDIT_EXPORT_EVIDENCE_REF,
            "export_audit_persisted": MCP_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
            "no_live_write_guard": MCP_AUDIT_NO_LIVE_WRITE_EVIDENCE_REF,
            "denied_tool_correlation": "mcp_denied_tool_audit_correlation",
            "request_correlation": "request_id_audit_correlation",
            "audit_feed_visibility": "request_id_audit_feed_visible",
        },
        "non_claims": [
            "This contract does not claim live MCP writes are enabled.",
            "This contract does not authorize production deployment.",
            "This contract does not claim provider-side mutations were executed.",
        ],
    }


def mcp_audit_rows(limit: int) -> list[object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        return conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type = 'mcp_tool_executed'
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()


def mcp_audit_forbidden_pattern_hits(events: list[dict[str, object]]) -> int:
    forbidden = (
        "redaction-proof-value",
        "sk-proj-",
        "sk-",
        "ghp_",
        "github_pat_",
        "vck_",
        "cfat_",
        "hcloud_",
        "hf_",
        "glpat-",
        "authorization:",
        "cookie:",
        "private key",
    )
    text = json.dumps(events, sort_keys=True).lower()
    return sum(1 for marker in forbidden if marker in text)


def mcp_audit_export_contract_payload() -> dict[str, object]:
    contract = mcp_audit_feed_contract_payload()
    return {
        "contract_version": MCP_AUDIT_EXPORT_CONTRACT_VERSION,
        "parent_contract_version": MCP_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "read_only_mcp_audit_csv_export",
        "endpoint": "GET /api/v1/audit/mcp/export?format=csv&limit=80",
        "contract_endpoint": "GET /api/v1/audit/mcp/export/contract",
        "feed_endpoint": "GET /api/v1/audit/mcp",
        "snapshot_endpoint": "GET /api/v1/audit/mcp/snapshot",
        "source_table": "audit_log",
        "source_event_type": "mcp_tool_executed",
        "supported_formats": ["csv"],
        "default_format": "csv",
        "default_limit": 80,
        "max_limit": 200,
        "filename_pattern": "superbrain-mcp-audit.csv",
        "columns": contract["export_columns"],
        "evidence_ref": MCP_AUDIT_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": MCP_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
        "feed_evidence_ref": MCP_AUDIT_FEED_EVIDENCE_REF,
        "audit_feed_evidence_ref": "request_id_audit_feed_visible",
        "snapshot_evidence_ref": MCP_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "redaction_evidence_ref": MCP_AUDIT_REDACTION_EVIDENCE_REF,
        "no_live_mcp_write_evidence_ref": MCP_AUDIT_NO_LIVE_WRITE_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_mcp_writes_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "input_refs_returned": False,
        "provider_credentials_returned": False,
        "raw_details_returned": False,
        "provider_side_mutation_claimed": False,
        "policy_checks": [
            "Export reads only audit_log rows with event_type=mcp_tool_executed.",
            "Export emits CSV columns from the allowlisted MCP audit fields only.",
            "Export never executes MCP tools and never writes to external MCP providers.",
            "Export audit logging stores only redacted metadata: contract version, row count, trace id, request id, format, and evidence ref.",
            "Any forbidden pattern in exported rows blocks the verifier.",
        ],
        "non_claims": contract["non_claims"],
    }


def build_mcp_audit_export_csv(rows: list[object]) -> str:
    output = io.StringIO()
    fieldnames = mcp_audit_export_contract_payload()["columns"]
    writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    ordered_rows = sorted(rows, key=lambda row: row[5].isoformat() if row[5] else "")
    for index, row in enumerate(ordered_rows, start=1):
        details = public_audit_details(row[4] or {})
        details = details if isinstance(details, dict) else {}
        csv_row = {
            "sequence_index": index,
            "event_id": str(row[0]),
            "created_at": row[5].isoformat() if row[5] else None,
            "event_type": row[1],
            "severity": row[6],
            "trace_id": public_trace_id(details.get("trace_id") or (str(row[3]) if row[3] else None)),
            "request_id": public_request_id(details.get("request_id")),
            "session_id": str(row[3]) if row[3] else None,
            "agent_role": details.get("agent_role") or row[2],
            "toolset": details.get("toolset"),
            "capability": details.get("capability"),
            "status": details.get("status"),
            "error_class": details.get("error_class"),
            "duration_ms": details.get("duration_ms"),
            "retry_after_ms": details.get("retry_after_ms"),
            "session_bound": details.get("session_bound") is True,
            "input_ref_stored": details.get("input_ref_stored", False) is True,
            "live_mcp_writes": details.get("live_mcp_write") is True or details.get("live_mcp_writes") is True,
            "evidence_ref": MCP_AUDIT_EXPORT_EVIDENCE_REF,
            "audit_feed_evidence_ref": details.get("audit_feed_evidence_ref", "request_id_audit_feed_visible"),
            "correlation_evidence_ref": details.get("correlation_evidence_ref", "request_id_audit_correlation"),
            "redaction_evidence_ref": details.get("redaction_evidence_ref", MCP_AUDIT_REDACTION_EVIDENCE_REF),
            "no_live_mcp_write_evidence_ref": MCP_AUDIT_NO_LIVE_WRITE_EVIDENCE_REF,
        }
        writer.writerow({key: csv_safe_value(value) for key, value in csv_row.items()})
    return output.getvalue()


def persist_mcp_audit_export_audit(format: str, row_count: int, trace_id: str, request_id: str) -> None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('mcp_audit_export_generated', 'mcp-audit', %s::jsonb, 'info')
                """,
                (
                    Json(
                        redact_json(
                            {
                                "contract_version": MCP_AUDIT_EXPORT_CONTRACT_VERSION,
                                "trace_id": trace_id,
                                "request_id": request_id,
                                "format": format,
                                "row_count": row_count,
                                "evidence_ref": MCP_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
                                "redaction_evidence_ref": MCP_AUDIT_REDACTION_EVIDENCE_REF,
                                "no_live_mcp_write_evidence_ref": MCP_AUDIT_NO_LIVE_WRITE_EVIDENCE_REF,
                            }
                        )
                    ),
                ),
            )
    except Exception as exc:  # pragma: no cover - audit persistence must not break exports
        print(f"mcp audit export audit failed: {exc}")


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
            "q": {"required": True, "min_length": 1, "min_trimmed_length": 1, "max_length": 1000},
            "project_id": {"required": True, "min_length": 1},
            "limit": {"required": False, "default": 5, "min": 1, "max": 20},
            "threshold": {"required": False, "default": 0.0, "min": 0.0, "max": 1.0},
        },
        "empty_query_policy": {
            "status_code": 422,
            "error": "memory_search_empty_query",
            "evidence_ref": "memory_search_empty_query_blocked",
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


def persist_live_agent_steer_audit(
    *,
    agent_id: str,
    execution_role: str,
    project_id: str,
    response_id: str,
    previous_response_id: str | None,
    model: str,
    status: object,
    text: str,
    usage: object,
    trace_id: str,
    request_id: str,
    safe_metadata_keys: list[str],
) -> bool:
    details = redact_json(
        {
            "contract_version": LIVE_AGENT_STEERING_CONTRACT_VERSION,
            "agent": agent_id,
            "agent_type": execution_role,
            "agent_role": execution_role,
            "project_id": project_id,
            "response_id": response_id or None,
            "previous_response_id": previous_response_id,
            "model": model,
            "status": status,
            "runtime_source": "openai_responses_via_llm_gateway",
            "live_provider_calls": False,
            "metadata_fields_forwarded": safe_metadata_keys,
            "response_preview": redact_text(text)[:280],
            "usage": usage,
            "trace_id": trace_id,
            "request_id": request_id,
            "correlation_evidence_ref": "request_id_audit_correlation",
            "audit_feed_evidence_ref": "request_id_audit_feed_visible",
            "evidence_ref": "live_agent_steering_audit_persisted",
        }
    )
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('live_agent_steered', %s, %s::jsonb, 'info')
                """,
                (execution_role, Json(details)),
            )
        return True
    except Exception:
        return False


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
                ("live_infra_budget_refresh_requires_HETZNER_API_TOKEN", not verified_flags["hetzner_cloud_stack"]),
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
    app.state.applied_migrations = run_migrations()
    ensure_postgres_checkpointer()


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
            "id": "hetzner_cloud_stack",
            "label": "Hetzner pull-based cloud stack",
            "required_env": ["HETZNER_API_TOKEN"],
            "required_artifact": "docker-compose.cloud.yml",
            "verifier": "scripts/check_hetzner_infra_budget.py",
            "environment_configured": env_ready(["HETZNER_API_TOKEN"]),
            "configured": verified_flags["hetzner_cloud_stack"],
            "verified": verified_flags["hetzner_cloud_stack"],
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
            "configured": verified_flags["hosted_backend_origins"],
            "verified": verified_flags["hosted_backend_origins"],
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
    production_gate_claim_allowed = verified_flags["production_gate_claim_allowed"]
    return {
        "contract_version": CLOUD_DEPLOYMENT_PREFLIGHT_CONTRACT_VERSION,
        "status": "verified" if production_gate_claim_allowed else ("ready_for_external_execution" if not missing_or_blocked else "action_required"),
        "endpoint": "GET /api/v1/clouds/deployment-preflight",
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
        "cloud_deploy_claim_allowed": not missing_or_blocked,
        "production_deploy_claim_allowed": production_gate_claim_allowed,
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


@app.get("/api/v1/clouds/render-offload")
def cloud_render_offload() -> dict[str, object]:
    return cloud_render_offload_state()


@app.get("/api/v1/clouds/render-offload/contract")
def cloud_render_offload_contract() -> dict[str, object]:
    return cloud_render_offload_contract_payload()


@app.get("/api/v1/clouds/deployment-preflight")
def cloud_deployment_preflight() -> dict[str, object]:
    return cloud_deployment_preflight_state()


@app.get("/api/v1/clouds/deployment-preflight/contract")
def cloud_deployment_preflight_contract() -> dict[str, object]:
    return cloud_deployment_preflight_payload()


@app.get("/api/v1/auth/contract")
def auth_contract() -> dict[str, object]:
    return auth_contract_payload()


@app.get("/api/v1/audit/auth/contract")
@app.get("/api/v1/auth/audit/contract")
def auth_audit_contract() -> dict[str, object]:
    return auth_audit_contract_payload()


@app.get("/api/v1/audit/auth/export/contract")
@app.get("/api/v1/auth/audit/export/contract")
def auth_audit_export_contract() -> dict[str, object]:
    return auth_audit_export_contract_payload()


@app.get("/api/v1/audit/auth/snapshot")
@app.get("/api/v1/auth/audit/snapshot")
def auth_audit_snapshot(limit: int = Query(default=80, ge=1, le=200)) -> dict[str, object]:
    rows = auth_audit_rows(limit)
    events = [safe_auth_audit_event(row) for row in rows]
    return build_auth_audit_snapshot(events)


@app.get("/api/v1/audit/auth/risk-rollup")
@app.get("/api/v1/auth/audit/risk-rollup")
def auth_audit_risk_rollup(limit: int = Query(default=80, ge=1, le=200)) -> dict[str, object]:
    rows = auth_audit_rows(limit)
    events = [safe_auth_audit_event(row) for row in rows]
    return build_auth_audit_risk_rollup(events)


@app.get("/api/v1/audit/auth/timeline")
@app.get("/api/v1/auth/audit/timeline")
def auth_audit_timeline(limit: int = Query(default=80, ge=1, le=200)) -> dict[str, object]:
    rows = auth_audit_rows(limit)
    events = [safe_auth_audit_event(row) for row in rows]
    return build_auth_audit_timeline(events)


@app.get("/api/v1/audit/auth/export")
@app.get("/api/v1/auth/audit/export")
def auth_audit_export(
    request: Request,
    format: str = Query(default="csv", pattern="^csv$"),
    limit: int = Query(default=80, ge=1, le=200),
    trace_id: str | None = Query(default=None, max_length=255),
    request_id: str | None = Query(default=None, max_length=255),
) -> Response:
    if format != "csv":
        raise HTTPException(status_code=400, detail={"error": "unsupported_format", "allowed": ["csv"]})
    rows = auth_audit_rows(limit)
    events = [safe_auth_audit_event(row) for row in rows]
    csv_payload = build_auth_audit_export_csv(events)
    row_count = max(0, len(csv_payload.splitlines()) - 1)
    resolved_trace_id = public_trace_id(trace_id) or f"auth-audit-export-{uuid4()}"
    resolved_request_id = (
        public_request_id(request_id)
        or public_request_id(getattr(request.state, "request_id", None))
        or public_request_id(request.headers.get("x-request-id"))
        or f"req-{uuid4()}"
    )
    persist_auth_audit_export_audit(format, row_count, resolved_trace_id, resolved_request_id)
    filename = "superbrain-auth-audit.csv"
    return Response(
        csv_payload,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-Contract-Version": AUTH_AUDIT_EXPORT_CONTRACT_VERSION,
            "X-Evidence-Ref": AUTH_AUDIT_EXPORT_EVIDENCE_REF,
            "X-Export-Audit-Evidence-Ref": AUTH_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
            "X-Redaction-Evidence-Ref": AUTH_AUDIT_REDACTION_EVIDENCE_REF,
            "X-No-Live-Oauth-Evidence-Ref": AUTH_AUDIT_NO_LIVE_OAUTH_EVIDENCE_REF,
            "X-Trace-Id": resolved_trace_id,
            "X-Request-Id": resolved_request_id,
        },
    )


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
            "state_present": bool(state),
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
            {
                "trace_id": request.trace_id if request else None,
                "blacklist_key_present": True,
                "blacklist_key_ref": "auth_blacklist_key_redacted",
            },
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
            "blacklist_key_present": True,
            "blacklist_key_ref": "auth_blacklist_key_redacted",
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
        "blacklist_key_returned": False,
        "blacklist_key_ref": "auth_blacklist_key_redacted",
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
            "blacklist_key_present": bool(blacklist_key),
            "blacklist_key_ref": "auth_blacklist_key_redacted" if blacklist_key else None,
            "cookies_cleared": True,
        },
    )
    return {
        "status": "logged_out",
        "contract_version": "auth-github-jwt-refresh-v1",
        "refresh_token_revoked": bool(supplied_token),
        "cookies_cleared": True,
        "blacklist_key_returned": False,
        "blacklist_key_ref": "auth_blacklist_key_redacted" if blacklist_key else None,
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
                "dispatch_id": record.dispatch_id,
                "logical_role": record.logical_role,
                "provenance_evidence_ref": record.provenance_evidence_ref,
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


@app.get("/api/v1/audit/mcp/export/contract")
def mcp_audit_export_contract() -> dict[str, object]:
    return mcp_audit_export_contract_payload()


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
                "details": public_audit_details(row[4] or {}),
                "request_id": public_request_id((row[4] or {}).get("request_id")),
                "trace_id": public_trace_id((row[4] or {}).get("trace_id")),
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
                "details": public_audit_details(row[4] or {}),
                "request_id": public_request_id((row[4] or {}).get("request_id")),
                "trace_id": public_trace_id((row[4] or {}).get("trace_id")),
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
    rows = mcp_audit_rows(limit)
    return {
        "contract_version": MCP_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "mcp_tool_audit_runtime_feed",
        "evidence_ref": MCP_AUDIT_FEED_EVIDENCE_REF,
        "snapshot_evidence_ref": MCP_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "redaction_evidence_ref": MCP_AUDIT_REDACTION_EVIDENCE_REF,
        "source_event_type": "mcp_tool_executed",
        "read_only": True,
        "live_mcp_writes_claimed": False,
        "events": [
            {
                "id": str(row[0]),
                "event_type": row[1],
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "request_id": public_request_id((row[4] or {}).get("request_id")),
                "trace_id": public_trace_id((row[4] or {}).get("trace_id") or (str(row[3]) if row[3] else None)),
                "correlation_evidence_ref": (row[4] or {}).get(
                    "correlation_evidence_ref",
                    "request_id_audit_correlation",
                ),
                "audit_feed_evidence_ref": (row[4] or {}).get(
                    "audit_feed_evidence_ref",
                    "request_id_audit_feed_visible",
                ),
                "details": public_audit_details(row[4] or {}),
                "redaction_evidence_ref": (row[4] or {}).get(
                    "redaction_evidence_ref",
                    MCP_AUDIT_REDACTION_EVIDENCE_REF,
                ),
                "input_ref_stored": (row[4] or {}).get("input_ref_stored", False),
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
            for row in rows
        ],
        "count": len(rows),
        "non_claims": mcp_audit_feed_contract_payload()["non_claims"],
    }


@app.get("/api/v1/audit/mcp/snapshot")
def mcp_audit_snapshot(limit: int = Query(default=50, ge=1, le=200)) -> dict[str, object]:
    rows = mcp_audit_rows(limit)
    events = [
        {
            "event_id": str(row[0]),
            "severity": row[6],
            "details": public_audit_details(row[4] or {}),
        }
        for row in rows
    ]
    details = [event["details"] for event in events if isinstance(event.get("details"), dict)]
    status_counts = count_by_key([str(item.get("status")) if item.get("status") is not None else None for item in details])
    toolset_counts = count_by_key([str(item.get("toolset")) if item.get("toolset") is not None else None for item in details])
    capability_counts = count_by_key(
        [str(item.get("capability")) if item.get("capability") is not None else None for item in details]
    )
    error_class_counts = count_by_key(
        [str(item.get("error_class")) if item.get("error_class") is not None else None for item in details]
    )
    agent_role_counts = count_by_key(
        [str(item.get("agent_role")) if item.get("agent_role") is not None else None for item in details]
    )
    blocked_count = sum(1 for item in details if item.get("status") == "blocked")
    denied_tool_correlation_count = sum(
        1 for item in details if item.get("denied_tool_correlation_evidence_ref") == "mcp_denied_tool_audit_correlation"
    )
    session_bound_count = sum(1 for item in details if item.get("session_bound") is True)
    live_mcp_write_count = sum(
        1 for item in details if item.get("live_mcp_write") is True or item.get("live_mcp_writes") is True
    )
    forbidden_pattern_hits = mcp_audit_forbidden_pattern_hits(events)
    return {
        "contract_version": MCP_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "read_only_mcp_audit_redaction_snapshot",
        "endpoint": "GET /api/v1/audit/mcp/snapshot",
        "source_endpoint": "GET /api/v1/audit/mcp",
        "source_event_type": "mcp_tool_executed",
        "source_table": "audit_log",
        "evidence_ref": MCP_AUDIT_FEED_EVIDENCE_REF,
        "snapshot_evidence_ref": MCP_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "redaction_evidence_ref": MCP_AUDIT_REDACTION_EVIDENCE_REF,
        "read_only": True,
        "live_mcp_writes_claimed": False,
        "input_refs_returned": False,
        "provider_credentials_returned": False,
        "events_scanned": len(events),
        "blocked_count": blocked_count,
        "denied_tool_correlation_count": denied_tool_correlation_count,
        "session_bound_count": session_bound_count,
        "live_mcp_write_count": live_mcp_write_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "status_counts": status_counts,
        "toolset_counts": toolset_counts,
        "capability_counts": capability_counts,
        "error_class_counts": error_class_counts,
        "agent_role_counts": agent_role_counts,
        "safe_fields": [
            "tool_request_id",
            "run_id",
            "request_id",
            "trace_id",
            "agent_role",
            "toolset",
            "capability",
            "status",
            "error_class",
            "sanitized_summary",
            "evidence_ref",
            "audit_evidence_ref",
            "redaction_evidence_ref",
            "input_ref_stored",
        ],
        "policy_checks": [
            "Snapshot reads audit_log only.",
            "Snapshot aggregates safe MCP audit fields and does not return tool input refs.",
            "Snapshot reports forbidden_pattern_hits before any release claim.",
            "Snapshot never executes MCP tools or external MCP writes.",
        ],
        "non_claims": mcp_audit_feed_contract_payload()["non_claims"],
    }


@app.get("/api/v1/audit/mcp/export")
def mcp_audit_export(
    request: Request,
    format: str = Query(default="csv", pattern="^csv$"),
    limit: int = Query(default=80, ge=1, le=200),
    trace_id: str | None = Query(default=None, max_length=255),
    request_id: str | None = Query(default=None, max_length=255),
) -> Response:
    if format != "csv":
        raise HTTPException(status_code=400, detail={"error": "unsupported_format", "allowed": ["csv"]})
    rows = mcp_audit_rows(limit)
    csv_payload = build_mcp_audit_export_csv(rows)
    row_count = max(0, len(csv_payload.splitlines()) - 1)
    resolved_trace_id = public_trace_id(trace_id) or f"mcp-audit-export-{uuid4()}"
    resolved_request_id = (
        public_request_id(request_id)
        or public_request_id(getattr(request.state, "request_id", None))
        or public_request_id(request.headers.get("x-request-id"))
        or f"req-{uuid4()}"
    )
    persist_mcp_audit_export_audit(format, row_count, resolved_trace_id, resolved_request_id)
    filename = "superbrain-mcp-audit.csv"
    return Response(
        csv_payload,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-Contract-Version": MCP_AUDIT_EXPORT_CONTRACT_VERSION,
            "X-Evidence-Ref": MCP_AUDIT_EXPORT_EVIDENCE_REF,
            "X-Export-Audit-Evidence-Ref": MCP_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
            "X-Redaction-Evidence-Ref": MCP_AUDIT_REDACTION_EVIDENCE_REF,
            "X-No-Live-Mcp-Write-Evidence-Ref": MCP_AUDIT_NO_LIVE_WRITE_EVIDENCE_REF,
            "X-Trace-Id": resolved_trace_id,
            "X-Request-Id": resolved_request_id,
        },
    )


def llm_audit_feed_contract_payload() -> dict[str, object]:
    return {
        "contract_version": LLM_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "audit_log_backed_llm_gateway_feed",
        "endpoint": "GET /api/v1/audit/llm",
        "snapshot_endpoint": "GET /api/v1/audit/llm/snapshot",
        "export_endpoint": "GET /api/v1/audit/llm/export?format=csv&limit=80",
        "export_contract_endpoint": "GET /api/v1/audit/llm/export/contract",
        "export_contract_version": LLM_AUDIT_EXPORT_CONTRACT_VERSION,
        "source_event_type": "llm_gateway_request",
            "source_table": "audit_log",
            "supported_export_formats": ["csv"],
            "evidence_ref": LLM_AUDIT_FEED_EVIDENCE_REF,
            "audit_feed_evidence_ref": "llm_audit_feed_event_visible",
            "correlation_evidence_ref": "request_id_audit_correlation",
            "snapshot_evidence_ref": LLM_AUDIT_SNAPSHOT_EVIDENCE_REF,
            "redaction_evidence_ref": LLM_AUDIT_REDACTION_EVIDENCE_REF,
        "export_evidence_ref": LLM_AUDIT_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": LLM_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
        "no_live_provider_evidence_ref": LLM_AUDIT_NO_LIVE_PROVIDER_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_provider_calls_claimed": False,
        "prompt_bodies_returned": False,
        "provider_credentials_returned": False,
        "raw_details_returned": False,
        "export_columns": [
            "sequence_index",
            "event_id",
            "created_at",
            "event_type",
            "severity",
            "trace_id",
            "model_name",
            "provider_name",
            "agent_type",
            "status",
            "input_tokens",
            "output_tokens",
            "cost_cents",
            "live_provider_calls",
            "prompt_body_stored",
            "evidence_ref",
            "audit_feed_evidence_ref",
            "redaction_evidence_ref",
            "no_live_provider_evidence_ref",
        ],
        "required_detail_fields": [
            "trace_id",
            "request_id",
            "session_id",
            "model_name",
            "provider_name",
            "agent_type",
            "status",
            "input_tokens",
            "output_tokens",
            "cost_cents",
            "live_provider_calls",
            "summary",
            "prompt_body_stored",
            "redaction_evidence_ref",
        ],
        "policy_checks": [
            "The feed only reads audit_log rows with event_type=llm_gateway_request.",
            "Every returned event exposes trace_id and live_provider_calls=false for dry-run proofs.",
            "Request and session identifiers are surfaced when provided so LLM audit rows join cross-gateway correlation safely.",
            "The endpoint never calls an LLM provider and never changes routing policy.",
            "Provider credentials and prompts are not returned by this feed.",
            "The snapshot endpoint aggregates redacted audit fields and never returns prompt bodies.",
            "The CSV export emits only allowlisted LLM audit fields and logs redacted export metadata.",
        ],
        "non_claims": [
            "No live provider call is enabled by this feed.",
            "No production deployment or provider billing proof is claimed.",
            "This is not a long-term telemetry warehouse or Langfuse replacement.",
        ],
    }


def llm_audit_rows(limit: int) -> list[object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        return conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type = 'llm_gateway_request'
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()


def count_by_key(values: list[str | None]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for value in values:
        key = value or "unknown"
        counts[key] = counts.get(key, 0) + 1
    return counts


def llm_audit_forbidden_pattern_hits(events: list[dict[str, object]]) -> int:
    forbidden = (
        "sk-proj-",
        "sk-",
        "ghp_",
        "github_pat_",
        "vck_",
        "cfat_",
        "hf_",
        "glpat-",
        "authorization:",
        "cookie:",
        "private key",
    )
    text = json.dumps(events, sort_keys=True).lower()
    return sum(1 for marker in forbidden if marker in text)


def llm_audit_export_contract_payload() -> dict[str, object]:
    contract = llm_audit_feed_contract_payload()
    return {
        "contract_version": LLM_AUDIT_EXPORT_CONTRACT_VERSION,
        "parent_contract_version": LLM_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "read_only_llm_audit_csv_export",
        "endpoint": "GET /api/v1/audit/llm/export?format=csv&limit=80",
        "contract_endpoint": "GET /api/v1/audit/llm/export/contract",
        "feed_endpoint": "GET /api/v1/audit/llm",
        "snapshot_endpoint": "GET /api/v1/audit/llm/snapshot",
        "source_table": "audit_log",
        "source_event_type": "llm_gateway_request",
        "supported_formats": ["csv"],
        "default_format": "csv",
        "default_limit": 80,
        "max_limit": 200,
        "filename_pattern": "superbrain-llm-audit.csv",
        "columns": contract["export_columns"],
        "evidence_ref": LLM_AUDIT_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": LLM_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
        "feed_evidence_ref": LLM_AUDIT_FEED_EVIDENCE_REF,
        "audit_feed_evidence_ref": "llm_audit_feed_event_visible",
        "snapshot_evidence_ref": LLM_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "redaction_evidence_ref": LLM_AUDIT_REDACTION_EVIDENCE_REF,
        "no_live_provider_evidence_ref": LLM_AUDIT_NO_LIVE_PROVIDER_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_provider_calls_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "prompt_bodies_returned": False,
        "provider_credentials_returned": False,
        "raw_details_returned": False,
        "provider_trace_export": False,
        "policy_checks": [
            "Export reads only audit_log rows with event_type=llm_gateway_request.",
            "Export emits CSV columns from the allowlisted LLM audit fields only.",
            "Export never calls live providers and never changes routing policy.",
            "Export audit logging stores only redacted metadata: contract version, row count, trace id, request id, format, and evidence ref.",
            "Any forbidden pattern in exported rows blocks the verifier.",
        ],
        "non_claims": contract["non_claims"],
    }


def build_llm_audit_export_csv(rows: list[object]) -> str:
    output = io.StringIO()
    fieldnames = llm_audit_export_contract_payload()["columns"]
    writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    ordered_rows = sorted(rows, key=lambda row: row[5].isoformat() if row[5] else "")
    for index, row in enumerate(ordered_rows, start=1):
        details = public_audit_details(row[4] or {})
        csv_row = {
            "sequence_index": index,
            "event_id": str(row[0]),
            "created_at": row[5].isoformat() if row[5] else None,
            "event_type": row[1],
            "severity": row[6],
            "trace_id": public_trace_id(details.get("trace_id")),
            "model_name": details.get("model_name"),
            "provider_name": details.get("provider_name"),
            "agent_type": details.get("agent_type") or row[2],
            "status": details.get("status"),
            "input_tokens": details.get("input_tokens"),
            "output_tokens": details.get("output_tokens"),
            "cost_cents": details.get("cost_cents"),
            "live_provider_calls": details.get("live_provider_calls") is True,
            "prompt_body_stored": details.get("prompt_body_stored", False) is True,
            "evidence_ref": LLM_AUDIT_EXPORT_EVIDENCE_REF,
            "audit_feed_evidence_ref": "llm_audit_feed_event_visible",
            "redaction_evidence_ref": LLM_AUDIT_REDACTION_EVIDENCE_REF,
            "no_live_provider_evidence_ref": LLM_AUDIT_NO_LIVE_PROVIDER_EVIDENCE_REF,
        }
        writer.writerow({key: csv_safe_value(value) for key, value in csv_row.items()})
    return output.getvalue()


def persist_llm_audit_export_audit(format: str, row_count: int, trace_id: str, request_id: str) -> None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('llm_audit_export_generated', 'llm-audit', %s::jsonb, 'info')
                """,
                (
                    Json(
                        redact_json(
                            {
                                "contract_version": LLM_AUDIT_EXPORT_CONTRACT_VERSION,
                                "trace_id": trace_id,
                                "request_id": request_id,
                                "format": format,
                                "row_count": row_count,
                                "evidence_ref": LLM_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
                                "redaction_evidence_ref": LLM_AUDIT_REDACTION_EVIDENCE_REF,
                                "no_live_provider_evidence_ref": LLM_AUDIT_NO_LIVE_PROVIDER_EVIDENCE_REF,
                            }
                        )
                    ),
                ),
            )
    except Exception as exc:  # pragma: no cover - audit persistence must not break exports
        print(f"llm audit export audit failed: {exc}")


@app.get("/api/v1/audit/llm/contract")
def llm_audit_feed_contract() -> dict[str, object]:
    return llm_audit_feed_contract_payload()


@app.get("/api/v1/audit/llm/export/contract")
def llm_audit_export_contract() -> dict[str, object]:
    return llm_audit_export_contract_payload()


@app.get("/api/v1/audit/llm")
def recent_llm_audit_events(limit: int = Query(default=20, ge=1, le=100)) -> dict[str, object]:
    rows = llm_audit_rows(limit)
    events = [
        {
            "id": str(row[0]),
            "event_type": row[1],
            "user_id": row[2],
            "session_id": str(row[3]) if row[3] else None,
            "trace_id": public_trace_id((row[4] or {}).get("trace_id")),
            "request_id": public_request_id((row[4] or {}).get("request_id")),
            "correlation_evidence_ref": (row[4] or {}).get(
                "correlation_evidence_ref",
                "request_id_audit_correlation",
            ),
            "model_name": (row[4] or {}).get("model_name"),
            "provider_name": (row[4] or {}).get("provider_name"),
            "agent_type": (row[4] or {}).get("agent_type") or row[2],
            "status": (row[4] or {}).get("status"),
            "live_provider_calls": (row[4] or {}).get("live_provider_calls"),
            "cost_cents": (row[4] or {}).get("cost_cents"),
            "prompt_body_stored": (row[4] or {}).get("prompt_body_stored", False),
            "redaction_evidence_ref": (row[4] or {}).get(
                "redaction_evidence_ref",
                LLM_AUDIT_REDACTION_EVIDENCE_REF,
            ),
            "details": public_audit_details(row[4] or {}),
            "evidence_ref": LLM_AUDIT_FEED_EVIDENCE_REF,
            "audit_feed_evidence_ref": "llm_audit_feed_event_visible",
            "created_at": row[5].isoformat() if row[5] else None,
            "severity": row[6],
        }
        for row in rows
    ]
    return {
        "contract_version": LLM_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "audit_log_backed_llm_gateway_feed",
        "evidence_ref": LLM_AUDIT_FEED_EVIDENCE_REF,
        "source_event_type": "llm_gateway_request",
        "read_only": True,
        "live_provider_calls_claimed": False,
        "events": events,
        "count": len(events),
        "non_claims": llm_audit_feed_contract_payload()["non_claims"],
    }


@app.get("/api/v1/audit/llm/snapshot")
def llm_audit_snapshot(limit: int = Query(default=50, ge=1, le=200)) -> dict[str, object]:
    rows = llm_audit_rows(limit)
    events = [
        {
            "event_id": str(row[0]),
            "severity": row[6],
            "details": public_audit_details(row[4] or {}),
        }
        for row in rows
    ]
    details = [event["details"] for event in events if isinstance(event.get("details"), dict)]
    status_counts = count_by_key([str(item.get("status")) if item.get("status") is not None else None for item in details])
    provider_counts = count_by_key(
        [str(item.get("provider_name")) if item.get("provider_name") is not None else None for item in details]
    )
    agent_counts = count_by_key([str(item.get("agent_type")) if item.get("agent_type") is not None else None for item in details])
    model_counts = count_by_key([str(item.get("model_name")) if item.get("model_name") is not None else None for item in details])
    live_provider_call_count = sum(1 for item in details if item.get("live_provider_calls") is True)
    forbidden_pattern_hits = llm_audit_forbidden_pattern_hits(events)
    return {
        "contract_version": LLM_AUDIT_FEED_CONTRACT_VERSION,
        "mode": "read_only_llm_audit_redaction_snapshot",
        "endpoint": "GET /api/v1/audit/llm/snapshot",
        "source_endpoint": "GET /api/v1/audit/llm",
        "source_event_type": "llm_gateway_request",
        "source_table": "audit_log",
        "evidence_ref": LLM_AUDIT_FEED_EVIDENCE_REF,
        "snapshot_evidence_ref": LLM_AUDIT_SNAPSHOT_EVIDENCE_REF,
        "redaction_evidence_ref": LLM_AUDIT_REDACTION_EVIDENCE_REF,
        "read_only": True,
        "live_provider_calls_claimed": False,
        "prompt_bodies_returned": False,
        "provider_credentials_returned": False,
        "events_scanned": len(events),
        "dry_run_count": status_counts.get("dry_run", 0),
        "live_provider_call_count": live_provider_call_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "status_counts": status_counts,
        "provider_counts": provider_counts,
        "agent_counts": agent_counts,
        "model_counts": model_counts,
        "safe_fields": [
            "trace_id",
            "request_id",
            "session_id",
            "model_name",
            "provider_name",
            "agent_type",
            "status",
            "cost_cents",
            "live_provider_calls",
            "prompt_body_stored",
            "redaction_evidence_ref",
        ],
        "policy_checks": [
            "Snapshot reads audit_log only.",
            "Snapshot aggregates safe fields and does not return prompt bodies.",
            "Snapshot reports forbidden_pattern_hits before any release claim.",
            "Snapshot never calls LLM providers.",
        ],
        "non_claims": llm_audit_feed_contract_payload()["non_claims"],
    }


@app.get("/api/v1/audit/llm/export")
def llm_audit_export(
    request: Request,
    format: str = Query(default="csv", pattern="^csv$"),
    limit: int = Query(default=80, ge=1, le=200),
    trace_id: str | None = Query(default=None, max_length=255),
    request_id: str | None = Query(default=None, max_length=255),
) -> Response:
    if format != "csv":
        raise HTTPException(status_code=400, detail={"error": "unsupported_format", "allowed": ["csv"]})
    rows = llm_audit_rows(limit)
    csv_payload = build_llm_audit_export_csv(rows)
    row_count = max(0, len(csv_payload.splitlines()) - 1)
    resolved_trace_id = public_trace_id(trace_id) or f"llm-audit-export-{uuid4()}"
    resolved_request_id = (
        public_request_id(request_id)
        or public_request_id(getattr(request.state, "request_id", None))
        or public_request_id(request.headers.get("x-request-id"))
        or f"req-{uuid4()}"
    )
    persist_llm_audit_export_audit(format, row_count, resolved_trace_id, resolved_request_id)
    filename = "superbrain-llm-audit.csv"
    return Response(
        csv_payload,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-Contract-Version": LLM_AUDIT_EXPORT_CONTRACT_VERSION,
            "X-Evidence-Ref": LLM_AUDIT_EXPORT_EVIDENCE_REF,
            "X-Export-Audit-Evidence-Ref": LLM_AUDIT_EXPORT_AUDIT_EVIDENCE_REF,
            "X-Redaction-Evidence-Ref": LLM_AUDIT_REDACTION_EVIDENCE_REF,
            "X-No-Live-Provider-Evidence-Ref": LLM_AUDIT_NO_LIVE_PROVIDER_EVIDENCE_REF,
            "X-Trace-Id": resolved_trace_id,
            "X-Request-Id": resolved_request_id,
        },
    )


GATEWAY_CORRELATION_EVENT_TYPES = (
    "task_completed",
    "autonomous_team_dispatch",
    "langgraph_dry_run_completed",
    "langgraph_dry_run_stopped",
    "llm_gateway_request",
    "mcp_tool_executed",
)


def gateway_correlation_contract_payload() -> dict[str, object]:
    return {
        "contract_version": GATEWAY_CORRELATION_CONTRACT_VERSION,
        "mode": "read_only_agent_llm_mcp_correlation_snapshot",
        "endpoint": "GET /api/v1/security/gateway-correlation/snapshot",
        "risk_rollup_endpoint": "GET /api/v1/security/gateway-correlation/risk-rollup",
        "timeline_endpoint": "GET /api/v1/security/gateway-correlation/timeline",
        "export_endpoint": "GET /api/v1/security/gateway-correlation/export?format=csv&limit=80",
        "contract_endpoint": "GET /api/v1/security/gateway-correlation/contract",
        "export_contract_endpoint": "GET /api/v1/security/gateway-correlation/export/contract",
        "risk_rollup_contract_version": GATEWAY_CORRELATION_RISK_ROLLUP_CONTRACT_VERSION,
        "timeline_contract_version": GATEWAY_CORRELATION_TIMELINE_CONTRACT_VERSION,
        "export_contract_version": GATEWAY_CORRELATION_EXPORT_CONTRACT_VERSION,
        "source_table": "audit_log",
        "source_event_types": list(GATEWAY_CORRELATION_EVENT_TYPES),
        "supported_export_formats": ["csv"],
        "evidence_ref": GATEWAY_CORRELATION_EVIDENCE_REF,
        "risk_rollup_evidence_ref": GATEWAY_CORRELATION_RISK_ROLLUP_EVIDENCE_REF,
        "timeline_evidence_ref": GATEWAY_CORRELATION_TIMELINE_EVIDENCE_REF,
        "export_evidence_ref": GATEWAY_CORRELATION_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": GATEWAY_CORRELATION_EXPORT_AUDIT_EVIDENCE_REF,
        "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
        "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_provider_calls_claimed": False,
        "live_mcp_writes_claimed": False,
        "safe_event_fields": [
            "event_id",
            "event_type",
            "session_id",
            "trace_id",
            "request_id",
            "agent_type",
            "status",
            "evidence_ref",
            "created_at",
            "severity",
        ],
        "group_fields": [
            "correlation_key",
            "trace_id",
            "session_id",
            "request_id",
            "event_types",
            "has_agent_task",
            "has_llm_audit",
            "has_mcp_audit",
            "live_provider_call_count",
            "live_mcp_write_count",
            "correlation_state",
        ],
        "risk_rollup_fields": [
            "risk_status",
            "blocker_count",
            "review_count",
            "missing_leg_counts",
            "risk_badges",
            "promotion_allowed",
            "production_rollout_claimed",
        ],
        "timeline_fields": [
            "sequence_index",
            "event_id",
            "created_at",
            "event_type",
            "timeline_leg",
            "correlation_key",
            "trace_id",
            "request_id",
            "session_id",
            "agent_type",
            "status",
            "severity",
            "evidence_ref",
            "redaction_evidence_ref",
            "no_live_write_evidence_ref",
        ],
        "export_columns": [
            "sequence_index",
            "correlation_key",
            "trace_id",
            "request_id",
            "session_id",
            "correlation_state",
            "event_count",
            "event_types",
            "has_agent_task",
            "has_llm_audit",
            "has_mcp_audit",
            "risk_status",
            "missing_legs",
            "live_provider_call_count",
            "live_mcp_write_count",
            "evidence_ref",
            "snapshot_evidence_ref",
            "risk_rollup_evidence_ref",
            "timeline_evidence_ref",
            "export_audit_evidence_ref",
            "redaction_evidence_ref",
            "no_live_write_evidence_ref",
        ],
        "policy_checks": [
            "Snapshot reads audit_log only and never executes an agent, LLM provider, MCP tool, or deployment action.",
            "Returned events are reduced to safe correlation fields; raw prompts, tool input refs, provider credentials, and raw details are omitted.",
            "A full correlation requires agent task evidence, LLM audit evidence, and MCP audit evidence sharing a trace, request, or session key.",
            "The snapshot fails closed when live_provider_calls or live_mcp_writes appear in correlated evidence.",
            "The risk rollup is computed from the same read-only snapshot groups and never performs seed writes or live calls.",
            "The timeline is computed from the same safe event projection and never returns raw audit_log details.",
            "The CSV export emits allowlisted correlation group fields and persists only redacted export metadata.",
        ],
        "non_claims": [
            "This endpoint does not authorize production rollout or release promotion.",
            "This endpoint does not claim live provider calls, live MCP writes, provider billing proof, or external SOC/SIEM completeness.",
            "This endpoint does not return secrets, prompt bodies, raw tool inputs, cookies, authorization headers, or full audit details.",
        ],
    }


def gateway_correlation_rows(limit: int) -> list[object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        return conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE event_type IN (
              'task_completed',
              'autonomous_team_dispatch',
              'langgraph_dry_run_completed',
              'langgraph_dry_run_stopped',
              'llm_gateway_request',
              'mcp_tool_executed'
            )
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (limit,),
        ).fetchall()


def safe_gateway_correlation_event(row: object) -> dict[str, object]:
    details = row[4] or {}
    if not isinstance(details, dict):
        details = {}
    event_type = str(row[1])
    session_id = str(row[3]) if row[3] else str(details.get("session_id") or "") or None
    trace_id = str(details.get("trace_id") or session_id or "") or None
    request_id = str(details.get("request_id") or "") or None
    agent_type = str(
        details.get("agent_type")
        or details.get("agent_role")
        or details.get("logical_role")
        or row[2]
        or "unknown"
    )
    status = str(details.get("status") or ("completed" if event_type == "task_completed" else "visible"))
    live_provider_calls = bool(details.get("live_provider_calls") is True)
    live_mcp_writes = bool(details.get("live_mcp_write") is True or details.get("live_mcp_writes") is True)
    return {
        "event_id": str(row[0]),
        "event_type": event_type,
        "session_id": session_id,
        "trace_id": trace_id,
        "request_id": request_id,
        "agent_type": agent_type,
        "status": status,
        "evidence_ref": str(details.get("evidence_ref") or details.get("provenance_evidence_ref") or event_type),
        "audit_feed_evidence_ref": str(details.get("audit_feed_evidence_ref") or "request_id_audit_feed_visible"),
        "correlation_evidence_ref": str(details.get("correlation_evidence_ref") or GATEWAY_CORRELATION_EVIDENCE_REF),
        "redaction_evidence_ref": str(
            details.get("redaction_evidence_ref") or GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF
        ),
        "live_provider_calls": live_provider_calls,
        "live_mcp_writes": live_mcp_writes,
        "created_at": row[5].isoformat() if row[5] else None,
        "severity": row[6],
    }


def gateway_correlation_forbidden_pattern_hits(events: list[dict[str, object]]) -> int:
    forbidden = (
        "redaction-proof-value",
        "sk-proj-",
        "sk-",
        "ghp_",
        "github_pat_",
        "vck_",
        "cfat_",
        "hcloud_",
        "hf_",
        "glpat-",
        "authorization:",
        "cookie:",
        "private key",
        "prompt_body",
        "input_ref",
    )
    text = json.dumps(events, sort_keys=True).lower()
    return sum(1 for marker in forbidden if marker in text)


def gateway_correlation_event_key(event: dict[str, object]) -> str:
    return str(event.get("trace_id") or event.get("request_id") or event.get("session_id") or event["event_id"])


def gateway_correlation_timeline_leg(event_type: str) -> str:
    if event_type in {
        "task_completed",
        "autonomous_team_dispatch",
        "langgraph_dry_run_completed",
        "langgraph_dry_run_stopped",
    }:
        return "agent_task"
    if event_type == "llm_gateway_request":
        return "llm_audit"
    if event_type == "mcp_tool_executed":
        return "mcp_audit"
    return "unknown"


def build_gateway_correlation_groups(events: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[str, list[dict[str, object]]] = {}
    for event in events:
        key = gateway_correlation_event_key(event)
        grouped.setdefault(key, []).append(event)

    groups: list[dict[str, object]] = []
    for key, group_events in grouped.items():
        event_types = sorted({str(event["event_type"]) for event in group_events})
        trace_ids = sorted({str(event["trace_id"]) for event in group_events if event.get("trace_id")})
        session_ids = sorted({str(event["session_id"]) for event in group_events if event.get("session_id")})
        request_ids = sorted({str(event["request_id"]) for event in group_events if event.get("request_id")})
        has_agent_task = any(
            event_type in event_types
            for event_type in ("task_completed", "autonomous_team_dispatch", "langgraph_dry_run_completed", "langgraph_dry_run_stopped")
        )
        has_llm_audit = "llm_gateway_request" in event_types
        has_mcp_audit = "mcp_tool_executed" in event_types
        live_provider_call_count = sum(1 for event in group_events if event.get("live_provider_calls") is True)
        live_mcp_write_count = sum(1 for event in group_events if event.get("live_mcp_writes") is True)
        if has_agent_task and has_llm_audit and has_mcp_audit:
            correlation_state = "agent_llm_mcp_correlated"
        elif has_llm_audit and has_mcp_audit:
            correlation_state = "gateway_pair_correlated"
        else:
            correlation_state = "partial_correlation"
        groups.append(
            {
                "correlation_key": key,
                "trace_id": trace_ids[0] if trace_ids else None,
                "session_id": session_ids[0] if session_ids else None,
                "request_id": request_ids[0] if request_ids else None,
                "event_types": event_types,
                "event_count": len(group_events),
                "has_agent_task": has_agent_task,
                "has_llm_audit": has_llm_audit,
                "has_mcp_audit": has_mcp_audit,
                "trace_id_count": len(trace_ids),
                "session_id_count": len(session_ids),
                "request_id_count": len(request_ids),
                "live_provider_call_count": live_provider_call_count,
                "live_mcp_write_count": live_mcp_write_count,
                "correlation_state": correlation_state,
                "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
                "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
                "events": group_events[:8],
            }
        )
    return sorted(groups, key=lambda item: int(item["event_count"]), reverse=True)


def build_gateway_correlation_timeline(events: list[dict[str, object]]) -> dict[str, object]:
    forbidden_pattern_hits = gateway_correlation_forbidden_pattern_hits(events)
    ordered_events = sorted(
        events,
        key=lambda event: str(event.get("created_at") or ""),
    )
    timeline: list[dict[str, object]] = []
    for index, event in enumerate(ordered_events, start=1):
        event_type = str(event.get("event_type") or "unknown")
        timeline.append(
            {
                "sequence_index": index,
                "event_id": event.get("event_id"),
                "created_at": event.get("created_at"),
                "event_type": event_type,
                "timeline_leg": gateway_correlation_timeline_leg(event_type),
                "correlation_key": gateway_correlation_event_key(event),
                "trace_id": event.get("trace_id"),
                "request_id": event.get("request_id"),
                "session_id": event.get("session_id"),
                "agent_type": event.get("agent_type"),
                "status": event.get("status"),
                "severity": event.get("severity"),
                "evidence_ref": event.get("evidence_ref"),
                "redaction_evidence_ref": event.get("redaction_evidence_ref"),
                "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
                "live_provider_calls": event.get("live_provider_calls") is True,
                "live_mcp_writes": event.get("live_mcp_writes") is True,
            }
        )
    live_provider_call_count = sum(1 for event in timeline if event["live_provider_calls"] is True)
    live_mcp_write_count = sum(1 for event in timeline if event["live_mcp_writes"] is True)
    return {
        "contract_version": GATEWAY_CORRELATION_TIMELINE_CONTRACT_VERSION,
        "parent_contract_version": GATEWAY_CORRELATION_CONTRACT_VERSION,
        "mode": "read_only_gateway_correlation_timeline",
        "endpoint": "GET /api/v1/security/gateway-correlation/timeline",
        "snapshot_endpoint": "GET /api/v1/security/gateway-correlation/snapshot",
        "risk_rollup_endpoint": "GET /api/v1/security/gateway-correlation/risk-rollup",
        "contract_endpoint": "GET /api/v1/security/gateway-correlation/contract",
        "source_table": "audit_log",
        "source_event_types": list(GATEWAY_CORRELATION_EVENT_TYPES),
        "evidence_ref": GATEWAY_CORRELATION_TIMELINE_EVIDENCE_REF,
        "snapshot_evidence_ref": GATEWAY_CORRELATION_EVIDENCE_REF,
        "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
        "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        "read_only": True,
        "live_provider_calls_claimed": False,
        "live_mcp_writes_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "prompt_bodies_returned": False,
        "tool_input_refs_returned": False,
        "provider_credentials_returned": False,
        "events_scanned": len(events),
        "timeline_count": len(timeline),
        "live_provider_call_count": live_provider_call_count,
        "live_mcp_write_count": live_mcp_write_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "event_type_counts": count_by_key([str(event.get("event_type")) for event in events]),
        "timeline_leg_counts": count_by_key([str(event.get("timeline_leg")) for event in timeline]),
        "timeline": timeline[:80],
        "policy_checks": [
            "Timeline reads audit_log through the safe gateway correlation projection only.",
            "Timeline never seeds audit rows, executes agents, calls LLM providers, executes MCP tools, or dispatches deployments.",
            "Timeline entries expose ordering and correlation keys only; raw audit_log details remain omitted.",
            "Production rollout and promotion remain false even when full correlation evidence exists.",
        ],
        "non_claims": gateway_correlation_contract_payload()["non_claims"],
    }


def gateway_correlation_group_risk(group: dict[str, object]) -> dict[str, object]:
    missing_legs: list[str] = []
    if group.get("has_agent_task") is not True:
        missing_legs.append("agent_task")
    if group.get("has_llm_audit") is not True:
        missing_legs.append("llm_audit")
    if group.get("has_mcp_audit") is not True:
        missing_legs.append("mcp_audit")
    live_provider_call_count = int(group.get("live_provider_call_count") or 0)
    live_mcp_write_count = int(group.get("live_mcp_write_count") or 0)
    has_live_violation = live_provider_call_count > 0 or live_mcp_write_count > 0
    if has_live_violation:
        risk_status = "blocked"
        severity = "critical"
    elif missing_legs:
        risk_status = "review"
        severity = "warning"
    else:
        risk_status = "verified"
        severity = "info"
    return {
        "correlation_key": group.get("correlation_key"),
        "trace_id": group.get("trace_id"),
        "session_id": group.get("session_id"),
        "request_id": group.get("request_id"),
        "correlation_state": group.get("correlation_state"),
        "event_count": int(group.get("event_count") or 0),
        "missing_legs": missing_legs,
        "risk_status": risk_status,
        "severity": severity,
        "live_provider_call_count": live_provider_call_count,
        "live_mcp_write_count": live_mcp_write_count,
        "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
        "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
    }


def build_gateway_correlation_risk_rollup(
    events: list[dict[str, object]],
    groups: list[dict[str, object]],
) -> dict[str, object]:
    group_risks = [gateway_correlation_group_risk(group) for group in groups]
    forbidden_pattern_hits = gateway_correlation_forbidden_pattern_hits(events)
    full_correlation_count = sum(1 for group in groups if group.get("correlation_state") == "agent_llm_mcp_correlated")
    partial_correlation_count = sum(1 for group in groups if group.get("correlation_state") == "partial_correlation")
    gateway_pair_count = sum(1 for group in groups if group.get("correlation_state") == "gateway_pair_correlated")
    live_provider_call_count = sum(int(group.get("live_provider_call_count") or 0) for group in groups)
    live_mcp_write_count = sum(int(group.get("live_mcp_write_count") or 0) for group in groups)
    missing_leg_counts = {
        "agent_task": sum(1 for risk in group_risks if "agent_task" in risk["missing_legs"]),
        "llm_audit": sum(1 for risk in group_risks if "llm_audit" in risk["missing_legs"]),
        "mcp_audit": sum(1 for risk in group_risks if "mcp_audit" in risk["missing_legs"]),
    }
    blocker_count = live_provider_call_count + live_mcp_write_count + forbidden_pattern_hits
    review_count = sum(1 for risk in group_risks if risk["risk_status"] == "review")
    if blocker_count > 0:
        risk_status = "blocked"
    elif review_count > 0 or partial_correlation_count > 0 or gateway_pair_count > 0:
        risk_status = "review"
    else:
        risk_status = "clear"
    risk_badges = [
        {
            "id": "redaction",
            "label": "Redaction",
            "status": "clear" if forbidden_pattern_hits == 0 else "blocked",
            "count": forbidden_pattern_hits,
            "evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
        },
        {
            "id": "live_provider",
            "label": "Live Provider",
            "status": "clear" if live_provider_call_count == 0 else "blocked",
            "count": live_provider_call_count,
            "evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        },
        {
            "id": "live_mcp_write",
            "label": "Live MCP Write",
            "status": "clear" if live_mcp_write_count == 0 else "blocked",
            "count": live_mcp_write_count,
            "evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        },
        {
            "id": "full_correlation",
            "label": "Full Correlation",
            "status": "verified" if full_correlation_count > 0 else "watch",
            "count": full_correlation_count,
            "evidence_ref": GATEWAY_CORRELATION_RISK_ROLLUP_EVIDENCE_REF,
        },
    ]
    return {
        "contract_version": GATEWAY_CORRELATION_RISK_ROLLUP_CONTRACT_VERSION,
        "parent_contract_version": GATEWAY_CORRELATION_CONTRACT_VERSION,
        "mode": "read_only_gateway_correlation_risk_rollup",
        "endpoint": "GET /api/v1/security/gateway-correlation/risk-rollup",
        "snapshot_endpoint": "GET /api/v1/security/gateway-correlation/snapshot",
        "contract_endpoint": "GET /api/v1/security/gateway-correlation/contract",
        "source_table": "audit_log",
        "source_event_types": list(GATEWAY_CORRELATION_EVENT_TYPES),
        "evidence_ref": GATEWAY_CORRELATION_RISK_ROLLUP_EVIDENCE_REF,
        "snapshot_evidence_ref": GATEWAY_CORRELATION_EVIDENCE_REF,
        "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
        "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        "read_only": True,
        "live_provider_calls_claimed": False,
        "live_mcp_writes_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "prompt_bodies_returned": False,
        "tool_input_refs_returned": False,
        "provider_credentials_returned": False,
        "events_scanned": len(events),
        "groups_scanned": len(groups),
        "risk_status": risk_status,
        "blocker_count": blocker_count,
        "review_count": review_count,
        "full_correlation_count": full_correlation_count,
        "partial_correlation_count": partial_correlation_count,
        "gateway_pair_count": gateway_pair_count,
        "missing_leg_counts": missing_leg_counts,
        "live_provider_call_count": live_provider_call_count,
        "live_mcp_write_count": live_mcp_write_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "correlation_state_counts": count_by_key([str(group.get("correlation_state")) for group in groups]),
        "risk_status_counts": count_by_key([str(risk.get("risk_status")) for risk in group_risks]),
        "risk_badges": risk_badges,
        "group_risks": group_risks[:12],
        "policy_checks": [
            "Risk rollup reads audit_log through the safe gateway correlation projection only.",
            "Risk rollup never seeds audit rows, executes agents, calls LLM providers, executes MCP tools, or dispatches deployments.",
            "Production rollout and promotion remain false even when full correlation evidence exists.",
            "Any forbidden pattern, live provider call, or live MCP write raises blocker_count and risk_status=blocked.",
        ],
        "non_claims": gateway_correlation_contract_payload()["non_claims"],
    }


def gateway_correlation_export_contract_payload() -> dict[str, object]:
    contract = gateway_correlation_contract_payload()
    return {
        "contract_version": GATEWAY_CORRELATION_EXPORT_CONTRACT_VERSION,
        "parent_contract_version": GATEWAY_CORRELATION_CONTRACT_VERSION,
        "mode": "read_only_gateway_correlation_csv_export",
        "endpoint": "GET /api/v1/security/gateway-correlation/export?format=csv&limit=80",
        "contract_endpoint": "GET /api/v1/security/gateway-correlation/export/contract",
        "snapshot_endpoint": "GET /api/v1/security/gateway-correlation/snapshot",
        "risk_rollup_endpoint": "GET /api/v1/security/gateway-correlation/risk-rollup",
        "timeline_endpoint": "GET /api/v1/security/gateway-correlation/timeline",
        "source_table": "audit_log",
        "source_event_types": list(GATEWAY_CORRELATION_EVENT_TYPES),
        "supported_formats": ["csv"],
        "default_format": "csv",
        "default_limit": 80,
        "max_limit": 200,
        "filename_pattern": "superbrain-gateway-correlation.csv",
        "columns": contract["export_columns"],
        "evidence_ref": GATEWAY_CORRELATION_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": GATEWAY_CORRELATION_EXPORT_AUDIT_EVIDENCE_REF,
        "snapshot_evidence_ref": GATEWAY_CORRELATION_EVIDENCE_REF,
        "risk_rollup_evidence_ref": GATEWAY_CORRELATION_RISK_ROLLUP_EVIDENCE_REF,
        "timeline_evidence_ref": GATEWAY_CORRELATION_TIMELINE_EVIDENCE_REF,
        "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
        "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_provider_calls_claimed": False,
        "live_mcp_writes_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "prompt_bodies_returned": False,
        "tool_input_refs_returned": False,
        "provider_credentials_returned": False,
        "raw_details_returned": False,
        "policy_checks": [
            "Export reads audit_log through the same safe gateway correlation projection used by snapshot, risk rollup, and timeline.",
            "Export emits allowlisted CSV columns over correlation groups only; raw audit details, prompts, tool inputs, and credentials are omitted.",
            "Export never executes agents, calls LLM providers, executes MCP tools, writes external provider state, or promotes production.",
            "Export audit logging stores only redacted metadata: contract version, row count, trace id, request id, format, and evidence refs.",
        ],
        "non_claims": contract["non_claims"],
    }


def build_gateway_correlation_export_csv(
    events: list[dict[str, object]],
    groups: list[dict[str, object]],
) -> str:
    output = io.StringIO()
    fieldnames = gateway_correlation_export_contract_payload()["columns"]
    writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    risk_by_key = {
        str(risk.get("correlation_key")): risk
        for risk in (gateway_correlation_group_risk(group) for group in groups)
    }
    ordered_groups = sorted(groups, key=lambda group: str(group.get("correlation_key") or ""))
    for index, group in enumerate(ordered_groups, start=1):
        key = str(group.get("correlation_key") or "")
        risk = risk_by_key.get(key, {})
        event_types = group.get("event_types") if isinstance(group.get("event_types"), list) else []
        missing_legs = risk.get("missing_legs") if isinstance(risk.get("missing_legs"), list) else []
        csv_row = {
            "sequence_index": index,
            "correlation_key": key,
            "trace_id": public_trace_id(group.get("trace_id")),
            "request_id": public_request_id(group.get("request_id")),
            "session_id": group.get("session_id"),
            "correlation_state": group.get("correlation_state"),
            "event_count": group.get("event_count"),
            "event_types": "|".join(str(item) for item in event_types),
            "has_agent_task": group.get("has_agent_task") is True,
            "has_llm_audit": group.get("has_llm_audit") is True,
            "has_mcp_audit": group.get("has_mcp_audit") is True,
            "risk_status": risk.get("risk_status"),
            "missing_legs": "|".join(str(item) for item in missing_legs),
            "live_provider_call_count": group.get("live_provider_call_count"),
            "live_mcp_write_count": group.get("live_mcp_write_count"),
            "evidence_ref": GATEWAY_CORRELATION_EXPORT_EVIDENCE_REF,
            "snapshot_evidence_ref": GATEWAY_CORRELATION_EVIDENCE_REF,
            "risk_rollup_evidence_ref": GATEWAY_CORRELATION_RISK_ROLLUP_EVIDENCE_REF,
            "timeline_evidence_ref": GATEWAY_CORRELATION_TIMELINE_EVIDENCE_REF,
            "export_audit_evidence_ref": GATEWAY_CORRELATION_EXPORT_AUDIT_EVIDENCE_REF,
            "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
            "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        }
        writer.writerow({field: csv_safe_value(csv_row.get(field)) for field in fieldnames})
    return output.getvalue()


def persist_gateway_correlation_export_audit(format: str, row_count: int, trace_id: str, request_id: str) -> None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('gateway_correlation_export_generated', 'gateway-correlation', %s::jsonb, 'info')
                """,
                (
                    Json(
                        redact_json(
                            {
                                "contract_version": GATEWAY_CORRELATION_EXPORT_CONTRACT_VERSION,
                                "trace_id": trace_id,
                                "request_id": request_id,
                                "format": format,
                                "row_count": row_count,
                                "evidence_ref": GATEWAY_CORRELATION_EXPORT_AUDIT_EVIDENCE_REF,
                                "export_evidence_ref": GATEWAY_CORRELATION_EXPORT_EVIDENCE_REF,
                                "snapshot_evidence_ref": GATEWAY_CORRELATION_EVIDENCE_REF,
                                "risk_rollup_evidence_ref": GATEWAY_CORRELATION_RISK_ROLLUP_EVIDENCE_REF,
                                "timeline_evidence_ref": GATEWAY_CORRELATION_TIMELINE_EVIDENCE_REF,
                                "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
                                "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
                                "live_provider_calls_claimed": False,
                                "live_mcp_writes_claimed": False,
                                "production_rollout_claimed": False,
                                "promotion_allowed": False,
                            }
                        )
                    ),
                ),
            )
    except Exception as exc:  # pragma: no cover - audit persistence must not break exports
        print(f"gateway correlation export audit failed: {exc}")


@app.get("/api/v1/security/gateway-correlation/contract")
def gateway_correlation_contract() -> dict[str, object]:
    return gateway_correlation_contract_payload()


@app.get("/api/v1/security/gateway-correlation/export/contract")
def gateway_correlation_export_contract() -> dict[str, object]:
    return gateway_correlation_export_contract_payload()


@app.get("/api/v1/security/gateway-correlation/export")
def gateway_correlation_export(
    request: Request,
    format: str = Query(default="csv", pattern="^csv$"),
    limit: int = Query(default=80, ge=1, le=200),
    trace_id: str | None = Query(default=None, max_length=255),
    request_id: str | None = Query(default=None, max_length=255),
) -> Response:
    if format != "csv":
        raise HTTPException(status_code=400, detail={"error": "unsupported_format", "allowed": ["csv"]})
    rows = gateway_correlation_rows(limit)
    events = [safe_gateway_correlation_event(row) for row in rows]
    groups = build_gateway_correlation_groups(events)
    csv_payload = build_gateway_correlation_export_csv(events, groups)
    row_count = max(0, len(csv_payload.splitlines()) - 1)
    resolved_trace_id = public_trace_id(trace_id) or f"gateway-correlation-export-{uuid4()}"
    resolved_request_id = (
        public_request_id(request_id)
        or public_request_id(getattr(request.state, "request_id", None))
        or public_request_id(request.headers.get("x-request-id"))
        or f"req-{uuid4()}"
    )
    persist_gateway_correlation_export_audit(format, row_count, resolved_trace_id, resolved_request_id)
    filename = "superbrain-gateway-correlation.csv"
    return Response(
        csv_payload,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-Contract-Version": GATEWAY_CORRELATION_EXPORT_CONTRACT_VERSION,
            "X-Evidence-Ref": GATEWAY_CORRELATION_EXPORT_EVIDENCE_REF,
            "X-Export-Audit-Evidence-Ref": GATEWAY_CORRELATION_EXPORT_AUDIT_EVIDENCE_REF,
            "X-Redaction-Evidence-Ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
            "X-No-Live-Write-Evidence-Ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
            "X-Trace-Id": resolved_trace_id,
            "X-Request-Id": resolved_request_id,
        },
    )


@app.get("/api/v1/security/gateway-correlation/snapshot")
def gateway_correlation_snapshot(limit: int = Query(default=80, ge=1, le=200)) -> dict[str, object]:
    rows = gateway_correlation_rows(limit)
    events = [safe_gateway_correlation_event(row) for row in rows]
    groups = build_gateway_correlation_groups(events)
    full_correlations = [group for group in groups if group["correlation_state"] == "agent_llm_mcp_correlated"]
    live_provider_call_count = sum(int(group["live_provider_call_count"]) for group in groups)
    live_mcp_write_count = sum(int(group["live_mcp_write_count"]) for group in groups)
    forbidden_pattern_hits = gateway_correlation_forbidden_pattern_hits(events)
    return {
        "contract_version": GATEWAY_CORRELATION_CONTRACT_VERSION,
        "mode": "read_only_agent_llm_mcp_correlation_snapshot",
        "endpoint": "GET /api/v1/security/gateway-correlation/snapshot",
        "contract_endpoint": "GET /api/v1/security/gateway-correlation/contract",
        "source_table": "audit_log",
        "source_event_types": list(GATEWAY_CORRELATION_EVENT_TYPES),
        "evidence_ref": GATEWAY_CORRELATION_EVIDENCE_REF,
        "redaction_evidence_ref": GATEWAY_CORRELATION_REDACTION_EVIDENCE_REF,
        "no_live_write_evidence_ref": GATEWAY_CORRELATION_NO_LIVE_WRITE_EVIDENCE_REF,
        "read_only": True,
        "live_provider_calls_claimed": False,
        "live_mcp_writes_claimed": False,
        "prompt_bodies_returned": False,
        "tool_input_refs_returned": False,
        "provider_credentials_returned": False,
        "events_scanned": len(events),
        "groups_scanned": len(groups),
        "full_correlation_count": len(full_correlations),
        "live_provider_call_count": live_provider_call_count,
        "live_mcp_write_count": live_mcp_write_count,
        "forbidden_pattern_hits": forbidden_pattern_hits,
        "redaction_status": "clear" if forbidden_pattern_hits == 0 else "blocked",
        "event_type_counts": count_by_key([str(event.get("event_type")) for event in events]),
        "agent_counts": count_by_key([str(event.get("agent_type")) if event.get("agent_type") else None for event in events]),
        "correlation_state_counts": count_by_key([str(group.get("correlation_state")) for group in groups]),
        "groups": groups[:12],
        "policy_checks": gateway_correlation_contract_payload()["policy_checks"],
        "non_claims": gateway_correlation_contract_payload()["non_claims"],
    }


@app.get("/api/v1/security/gateway-correlation/risk-rollup")
def gateway_correlation_risk_rollup(limit: int = Query(default=80, ge=1, le=200)) -> dict[str, object]:
    rows = gateway_correlation_rows(limit)
    events = [safe_gateway_correlation_event(row) for row in rows]
    groups = build_gateway_correlation_groups(events)
    return build_gateway_correlation_risk_rollup(events, groups)


@app.get("/api/v1/security/gateway-correlation/timeline")
def gateway_correlation_timeline(limit: int = Query(default=80, ge=1, le=200)) -> dict[str, object]:
    rows = gateway_correlation_rows(limit)
    events = [safe_gateway_correlation_event(row) for row in rows]
    return build_gateway_correlation_timeline(events)


SECURITY_AUDIT_EVENT_CATEGORIES = {
    "security_csp_violation_reported": "browser_security_policy",
    "auth_refresh_rotated": "auth_lifecycle",
    "auth_refresh_reuse_blocked": "auth_lifecycle",
    "auth_logout_revoked": "auth_lifecycle",
    "mcp_tool_executed": "mcp_guard",
    "llm_gateway_request": "llm_gateway_guard",
}


def security_audit_surface_contract_payload() -> dict[str, object]:
    return {
        "contract_version": SECURITY_AUDIT_SURFACE_CONTRACT_VERSION,
        "mode": "read_only_security_product_audit_surface",
        "screen": "Security Audit Surface",
        "endpoint": "GET /api/v1/security/events",
        "contract_endpoint": "GET /api/v1/security/events/contract",
        "source_table": "audit_log",
        "source_endpoints": [
            "POST /api/v1/security/csp/report",
            "POST /api/v1/auth/refresh",
            "POST /api/v1/auth/logout",
            "POST /mcp/api/v1/tools/execute",
            "POST /llm/v1/chat/completions",
        ],
        "supported_event_types": list(SECURITY_AUDIT_EVENT_CATEGORIES.keys()),
        "category_map": SECURITY_AUDIT_EVENT_CATEGORIES,
        "filters": ["limit", "event_type", "severity"],
        "read_only": True,
        "evidence_refs": {
            "surface_visible": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
            "event_visible": SECURITY_AUDIT_EVENT_EVIDENCE_REF,
            "csp_audit_persisted": "csp_report_audit_persisted",
            "mcp_deny_correlation": "mcp_denied_tool_audit_correlation",
            "llm_audit_event": "llm_audit_feed_event_visible",
        },
        "policy_checks": [
            "The surface reads audit_log only and never executes tools or provider calls.",
            "Events expose request_id and trace_id when the source event recorded them.",
            "Returned details are already redacted by the source audit writers.",
            "MCP denied-tool rows keep mcp_denied_tool_audit_correlation visible.",
            "LLM rows keep live_provider_calls visible so dry-run proofs cannot look like live billing.",
        ],
        "non_claims": [
            "No production SOC, SIEM, or incident-response workflow is claimed.",
            "No live provider calls or live MCP writes are enabled by this read-only feed.",
            "No secrets, prompt bodies, or browser cookies are intentionally returned.",
        ],
    }


@app.get("/api/v1/security/events/contract")
def security_audit_surface_contract() -> dict[str, object]:
    return security_audit_surface_contract_payload()


@app.get("/api/v1/security/events")
def recent_security_audit_events(
    limit: int = Query(default=20, ge=1, le=100),
    event_type: str | None = Query(default=None),
    severity: str | None = Query(default=None),
) -> dict[str, object]:
    allowed_event_types = set(SECURITY_AUDIT_EVENT_CATEGORIES.keys())
    if event_type is not None and event_type not in allowed_event_types:
        raise HTTPException(status_code=400, detail="unsupported_security_audit_event_type")

    where_clauses = [
        """
        event_type IN (
          'security_csp_violation_reported',
          'auth_refresh_rotated',
          'auth_refresh_reuse_blocked',
          'auth_logout_revoked',
          'mcp_tool_executed',
          'llm_gateway_request'
        )
        """
    ]
    params: list[object] = []
    if event_type:
        where_clauses.append("event_type = %s")
        params.append(event_type)
    if severity:
        where_clauses.append("severity = %s")
        params.append(severity)
    params.append(limit)

    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            f"""
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE {" AND ".join(where_clauses)}
            ORDER BY created_at DESC
            LIMIT %s
            """,
            tuple(params),
        ).fetchall()

    events = []
    for row in rows:
        details = public_audit_details(row[4] or {})
        if not isinstance(details, dict):
            details = {}
        trace_id = public_trace_id(details.get("trace_id") or (str(row[3]) if row[3] else None))
        events.append(
            {
                "id": str(row[0]),
                "event_type": row[1],
                "category": SECURITY_AUDIT_EVENT_CATEGORIES.get(row[1], "security_audit"),
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "request_id": public_request_id(details.get("request_id")),
                "trace_id": trace_id,
                "evidence_ref": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
                "audit_feed_evidence_ref": details.get(
                    "audit_feed_evidence_ref",
                    SECURITY_AUDIT_EVENT_EVIDENCE_REF,
                ),
                "security_surface_evidence_ref": SECURITY_AUDIT_EVENT_EVIDENCE_REF,
                "summary": details.get("summary")
                or details.get("sanitized_summary")
                or details.get("error_class")
                or row[1],
                "details": details,
                "created_at": row[5].isoformat() if row[5] else None,
                "severity": row[6],
            }
        )

    return {
        "contract_version": SECURITY_AUDIT_SURFACE_CONTRACT_VERSION,
        "mode": "read_only_security_product_audit_surface",
        "evidence_ref": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
        "event_evidence_ref": SECURITY_AUDIT_EVENT_EVIDENCE_REF,
        "read_only": True,
        "filters": {
            "event_type": event_type,
            "severity": severity,
            "limit": limit,
        },
        "events": events,
        "count": len(events),
        "non_claims": security_audit_surface_contract_payload()["non_claims"],
    }


def security_review_queue_contract_payload() -> dict[str, object]:
    return {
        "contract_version": SECURITY_REVIEW_QUEUE_CONTRACT_VERSION,
        "mode": "read_only_redacted_security_review_queue",
        "screen": "Security Review Queue",
        "endpoint": "GET /api/v1/security/review-queue",
        "contract_endpoint": "GET /api/v1/security/review-queue/contract",
        "snapshot_endpoint": "GET /api/v1/security/review-queue/snapshot",
        "gate_endpoint": "GET /api/v1/security/review-queue/gate",
        "export_endpoint": "GET /api/v1/security/review-queue/export?format=csv&limit=80",
        "export_contract_endpoint": "GET /api/v1/security/review-queue/export/contract",
        "export_contract_version": SECURITY_REVIEW_EXPORT_CONTRACT_VERSION,
        "source_table": "audit_log",
        "source_surface": "GET /api/v1/security/events",
        "supported_event_types": list(SECURITY_AUDIT_EVENT_CATEGORIES.keys()),
        "supported_export_formats": ["csv"],
        "filters": ["limit", "status", "severity", "category"],
        "read_only": True,
        "audit_persisted": True,
        "mutation_endpoints_blocked": [
            "POST /api/v1/security/review-queue",
            "PATCH /api/v1/security/review-queue",
            "PUT /api/v1/security/review-queue",
            "DELETE /api/v1/security/review-queue",
        ],
        "required_item_fields": [
            "queue_item_id",
            "source_event_id",
            "event_type",
            "category",
            "severity",
            "status",
            "summary",
            "request_id",
            "trace_id",
            "created_at",
            "evidence_ref",
            "item_evidence_ref",
            "redaction_evidence_ref",
        ],
        "export_columns": [
            "sequence_index",
            "queue_item_id",
            "source_event_id",
            "created_at",
            "event_type",
            "category",
            "severity",
            "status",
            "risk_badge",
            "request_id",
            "trace_id",
            "summary",
            "redaction_applied",
            "detail_keys",
            "evidence_ref",
            "item_evidence_ref",
            "redaction_evidence_ref",
            "filter_evidence_ref",
            "decision_history_evidence_ref",
            "source_security_surface_evidence_ref",
        ],
        "safe_fields": [
            "ids",
            "event_type",
            "category",
            "severity",
            "status",
            "request_id",
            "trace_id",
            "redacted_summary",
            "detail_key_names_only",
            "evidence_refs",
        ],
        "forbidden_fields": [
            "token",
            "api_key",
            "password",
            "authorization_header",
            "cookie",
            "secret_value",
            "prompt_body",
            "browser_session",
            "raw_file_contents",
        ],
        "status_values": ["needs_review", "monitoring"],
        "evidence_refs": {
            "queue_visible": SECURITY_REVIEW_QUEUE_EVIDENCE_REF,
            "item_visible": SECURITY_REVIEW_ITEM_EVIDENCE_REF,
            "redaction_enforced": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
            "mutation_blocked": SECURITY_REVIEW_MUTATION_BLOCK_EVIDENCE_REF,
            "filter_state": SECURITY_REVIEW_FILTER_EVIDENCE_REF,
            "decision_history": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
            "evidence_snapshot": SECURITY_REVIEW_SNAPSHOT_EVIDENCE_REF,
            "gate_summary": SECURITY_REVIEW_GATE_EVIDENCE_REF,
            "export_visible": SECURITY_REVIEW_EXPORT_EVIDENCE_REF,
            "export_audit_persisted": SECURITY_REVIEW_EXPORT_AUDIT_EVIDENCE_REF,
            "source_security_surface": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
        },
        "policy_checks": [
            "The review queue reads audit_log only and never executes tools, deploys code, or calls providers.",
            "Items return summaries and detail key names only; raw detail payloads are not returned.",
            "Mutation methods are blocked with security_review_mutation_blocked.",
            "Risk badges, filters, decision history, and evidence snapshots are derived from read-only audit rows.",
            "The gate summary is advisory and cannot approve a production rollout.",
            "The CSV export emits allowlisted queue columns only and persists redacted export metadata.",
            "Secrets, prompt bodies, cookies, authorization headers, and raw files are forbidden from queue responses.",
            "Production release decisions remain outside this read-only queue.",
        ],
        "non_claims": [
            "No production SOC, SIEM, incident ownership, or remediation workflow is claimed.",
            "No live provider calls, live MCP writes, file edits, or cloud mutations are enabled by this queue.",
            "No secret values, raw prompt bodies, screenshots, browser cookies, or raw file contents are returned.",
        ],
    }


def security_review_status_for_event(event_type: str, severity: str | None, details: dict[str, object]) -> str:
    severity_text = str(severity or "").lower()
    event_status = str(details.get("status") or "").lower()
    if severity_text in {"critical", "high", "warning", "error"}:
        return "needs_review"
    if event_type in {"auth_refresh_reuse_blocked", "security_csp_violation_reported"}:
        return "needs_review"
    if event_type == "mcp_tool_executed" and event_status in {"blocked", "denied", "failed"}:
        return "needs_review"
    return "monitoring"


def security_review_summary(event_type: str, category: str, details: dict[str, object]) -> tuple[str, bool, list[str]]:
    raw_summary = (
        details.get("summary")
        or details.get("sanitized_summary")
        or details.get("error_class")
        or details.get("status")
        or event_type
    )
    text = redact_text(str(raw_summary))
    key_names = sorted(str(key) for key in details.keys())
    detail_text = json.dumps(details, sort_keys=True, default=str)
    detail_text_redacted = redact_text(detail_text)
    redaction_indicators = ("token", "api_key", "authorization", "password", "cookie", "secret", "private key")
    redaction_applied = (
        text != str(raw_summary)
        or detail_text_redacted != detail_text
        or any(indicator in detail_text.lower() for indicator in redaction_indicators)
    )
    return text[:280], redaction_applied, key_names


def security_review_risk_badge(status: str, severity: str | None, category: str) -> str:
    severity_text = str(severity or "").lower()
    if status == "needs_review" and severity_text in {"critical", "high", "error"}:
        return "release_blocker_review"
    if status == "needs_review":
        return "review_required"
    if category in {"mcp", "llm"}:
        return "runtime_monitor"
    return "monitor"


def security_review_decision_history(source_event_id: str, status: str, created_at: object) -> list[dict[str, object]]:
    created_at_text = created_at.isoformat() if hasattr(created_at, "isoformat") else None
    return [
        {
            "state": "audit_event_ingested",
            "source_event_id": source_event_id,
            "evidence_ref": SECURITY_AUDIT_EVENT_EVIDENCE_REF,
            "created_at": created_at_text,
        },
        {
            "state": status,
            "source_event_id": source_event_id,
            "evidence_ref": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
            "created_at": created_at_text,
        },
    ]


def build_security_review_queue(
    limit: int,
    status: str | None,
    severity: str | None,
    category: str | None,
) -> dict[str, object]:
    allowed_statuses = {"needs_review", "monitoring"}
    if status is not None and status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="unsupported_security_review_status")
    allowed_categories = set(SECURITY_AUDIT_EVENT_CATEGORIES.values())
    if category is not None and category not in allowed_categories:
        raise HTTPException(status_code=400, detail="unsupported_security_review_category")

    where_clauses = [
        """
        event_type IN (
          'security_csp_violation_reported',
          'auth_refresh_rotated',
          'auth_refresh_reuse_blocked',
          'auth_logout_revoked',
          'mcp_tool_executed',
          'llm_gateway_request'
        )
        """
    ]
    params: list[object] = []
    if severity:
        where_clauses.append("severity = %s")
        params.append(severity)
    params.append(limit)

    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            f"""
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE {" AND ".join(where_clauses)}
            ORDER BY created_at DESC
            LIMIT %s
            """,
            tuple(params),
        ).fetchall()

    items: list[dict[str, object]] = []
    for row in rows:
        details = public_audit_details(row[4] or {})
        if not isinstance(details, dict):
            details = {}
        row_category = SECURITY_AUDIT_EVENT_CATEGORIES.get(row[1], "security_audit")
        row_status = security_review_status_for_event(row[1], row[6], details)
        if status is not None and row_status != status:
            continue
        if category is not None and row_category != category:
            continue
        summary, redaction_applied, detail_keys = security_review_summary(row[1], row_category, details)
        trace_id = public_trace_id(details.get("trace_id") or (str(row[3]) if row[3] else None))
        source_event_id = str(row[0])
        risk_badge = security_review_risk_badge(row_status, row[6], row_category)
        items.append(
            {
                "queue_item_id": f"security-review-{source_event_id}",
                "source_event_id": source_event_id,
                "event_type": row[1],
                "category": row_category,
                "severity": row[6],
                "status": row_status,
                "risk_badge": risk_badge,
                "summary": summary,
                "request_id": public_request_id(details.get("request_id")),
                "trace_id": trace_id,
                "detail_keys": detail_keys,
                "redaction_applied": redaction_applied,
                "redaction_marker": "***MASKED_SECRET***" if redaction_applied else None,
                "created_at": row[5].isoformat() if row[5] else None,
                "decision_history": security_review_decision_history(source_event_id, row_status, row[5]),
                "evidence_snapshot": {
                    "queue_visible": SECURITY_REVIEW_QUEUE_EVIDENCE_REF,
                    "item_visible": SECURITY_REVIEW_ITEM_EVIDENCE_REF,
                    "redaction_enforced": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
                    "mutation_blocked": SECURITY_REVIEW_MUTATION_BLOCK_EVIDENCE_REF,
                    "filter_state": SECURITY_REVIEW_FILTER_EVIDENCE_REF,
                    "decision_history": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
                    "source_security_surface": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
                },
                "evidence_ref": SECURITY_REVIEW_QUEUE_EVIDENCE_REF,
                "item_evidence_ref": SECURITY_REVIEW_ITEM_EVIDENCE_REF,
                "redaction_evidence_ref": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
                "filter_evidence_ref": SECURITY_REVIEW_FILTER_EVIDENCE_REF,
                "decision_history_evidence_ref": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
                "source_security_surface_evidence_ref": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
            }
        )

    status_counts = {
        "needs_review": sum(1 for item in items if item["status"] == "needs_review"),
        "monitoring": sum(1 for item in items if item["status"] == "monitoring"),
    }
    category_counts = {
        item_category: sum(1 for item in items if item["category"] == item_category)
        for item_category in sorted({str(item["category"]) for item in items})
    }
    risk_badges = {
        risk_badge: sum(1 for item in items if item["risk_badge"] == risk_badge)
        for risk_badge in sorted({str(item["risk_badge"]) for item in items})
    }
    return {
        "items": items,
        "count": len(items),
        "status_counts": status_counts,
        "category_counts": category_counts,
        "risk_badges": risk_badges,
    }


def build_security_review_gate(limit: int, severity: str | None, category: str | None) -> dict[str, object]:
    queue = build_security_review_queue(limit=limit, status=None, severity=severity, category=category)
    blockers = [item for item in queue["items"] if item["status"] == "needs_review"]
    gate_status = "blocked_by_open_security_reviews" if blockers else "clear_for_security_review_queue_only"
    return {
        "contract_version": SECURITY_REVIEW_QUEUE_CONTRACT_VERSION,
        "mode": "read_only_security_review_gate_summary",
        "endpoint": "GET /api/v1/security/review-queue/gate",
        "queue_endpoint": "GET /api/v1/security/review-queue",
        "snapshot_endpoint": "GET /api/v1/security/review-queue/snapshot",
        "evidence_ref": SECURITY_REVIEW_GATE_EVIDENCE_REF,
        "queue_evidence_ref": SECURITY_REVIEW_QUEUE_EVIDENCE_REF,
        "snapshot_evidence_ref": SECURITY_REVIEW_SNAPSHOT_EVIDENCE_REF,
        "read_only": True,
        "filters": {
            "limit": limit,
            "severity": severity,
            "category": category,
        },
        "gate_status": gate_status,
        "blocker_count": len(blockers),
        "monitoring_count": int(queue["status_counts"].get("monitoring", 0)),
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "release_authority": "outside_security_review_queue",
        "risk_badges": queue["risk_badges"],
        "blockers": [
            {
                "queue_item_id": item["queue_item_id"],
                "source_event_id": item["source_event_id"],
                "event_type": item["event_type"],
                "category": item["category"],
                "severity": item["severity"],
                "status": item["status"],
                "risk_badge": item["risk_badge"],
                "request_id": item["request_id"],
                "trace_id": item["trace_id"],
                "evidence_ref": item["evidence_ref"],
                "redaction_evidence_ref": item["redaction_evidence_ref"],
            }
            for item in blockers[:10]
        ],
        "policy_checks": [
            "This gate summary is read-only and derived from security review queue items.",
            "Open needs_review items block this advisory security-review gate.",
            "This endpoint never approves production promotion or release rollout.",
            "Blockers expose IDs and evidence refs only; raw audit detail payloads stay hidden.",
        ],
        "non_claims": [
            "No production rollout is claimed or authorized.",
            "No production release approval is granted by this endpoint.",
            "No live provider calls, live MCP writes, file edits, or cloud mutations are enabled.",
            "No secret values, raw prompt bodies, cookies, authorization headers, or raw files are returned.",
        ],
    }


def security_review_queue_export_contract_payload() -> dict[str, object]:
    contract = security_review_queue_contract_payload()
    return {
        "contract_version": SECURITY_REVIEW_EXPORT_CONTRACT_VERSION,
        "parent_contract_version": SECURITY_REVIEW_QUEUE_CONTRACT_VERSION,
        "mode": "read_only_security_review_queue_csv_export",
        "endpoint": "GET /api/v1/security/review-queue/export?format=csv&limit=80",
        "contract_endpoint": "GET /api/v1/security/review-queue/export/contract",
        "queue_endpoint": "GET /api/v1/security/review-queue",
        "snapshot_endpoint": "GET /api/v1/security/review-queue/snapshot",
        "gate_endpoint": "GET /api/v1/security/review-queue/gate",
        "source_table": "audit_log",
        "source_surface": "GET /api/v1/security/events",
        "source_event_types": list(SECURITY_AUDIT_EVENT_CATEGORIES.keys()),
        "supported_formats": ["csv"],
        "default_format": "csv",
        "default_limit": 80,
        "max_limit": 200,
        "filename_pattern": "superbrain-security-review-queue.csv",
        "columns": contract["export_columns"],
        "evidence_ref": SECURITY_REVIEW_EXPORT_EVIDENCE_REF,
        "export_audit_evidence_ref": SECURITY_REVIEW_EXPORT_AUDIT_EVIDENCE_REF,
        "queue_evidence_ref": SECURITY_REVIEW_QUEUE_EVIDENCE_REF,
        "item_evidence_ref": SECURITY_REVIEW_ITEM_EVIDENCE_REF,
        "redaction_evidence_ref": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
        "mutation_block_evidence_ref": SECURITY_REVIEW_MUTATION_BLOCK_EVIDENCE_REF,
        "filter_evidence_ref": SECURITY_REVIEW_FILTER_EVIDENCE_REF,
        "decision_history_evidence_ref": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
        "source_security_surface_evidence_ref": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
        "read_only": True,
        "audit_persisted": True,
        "live_provider_calls_claimed": False,
        "live_mcp_writes_claimed": False,
        "production_rollout_claimed": False,
        "promotion_allowed": False,
        "prompt_bodies_returned": False,
        "provider_credentials_returned": False,
        "cookies_returned": False,
        "authorization_headers_returned": False,
        "raw_details_returned": False,
        "policy_checks": [
            "Export reads audit_log through the same safe security review queue projection.",
            "Export emits CSV columns from the allowlisted security review fields only.",
            "Export never executes tools, calls providers, writes external state, deploys code, or promotes production.",
            "Export audit logging stores only redacted metadata: contract version, row count, trace id, request id, format, and evidence refs.",
            "Raw audit details, prompt bodies, cookies, authorization headers, screenshots, and raw files are omitted.",
        ],
        "non_claims": contract["non_claims"],
    }


def build_security_review_export_csv(items: list[dict[str, object]]) -> str:
    output = io.StringIO()
    fieldnames = security_review_queue_export_contract_payload()["columns"]
    writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    ordered_items = sorted(items, key=lambda item: str(item.get("created_at") or ""))
    for index, item in enumerate(ordered_items, start=1):
        detail_keys = item.get("detail_keys") if isinstance(item.get("detail_keys"), list) else []
        export_detail_keys = []
        for key in detail_keys:
            safe_key = redact_text(str(key))
            compact_key = "".join(char for char in safe_key.lower() if char.isalnum())
            if any(marker in compact_key for marker in ("prompt", "token", "secret", "password", "cookie", "authorization", "rawfile")):
                export_detail_keys.append("sensitive_key_redacted")
            else:
                export_detail_keys.append(safe_key)
        csv_row = {
            "sequence_index": index,
            "queue_item_id": item.get("queue_item_id"),
            "source_event_id": item.get("source_event_id"),
            "created_at": item.get("created_at"),
            "event_type": item.get("event_type"),
            "category": item.get("category"),
            "severity": item.get("severity"),
            "status": item.get("status"),
            "risk_badge": item.get("risk_badge"),
            "request_id": public_request_id(item.get("request_id")),
            "trace_id": public_trace_id(item.get("trace_id")),
            "summary": redact_text(str(item.get("summary") or "")),
            "redaction_applied": item.get("redaction_applied") is True,
            "detail_keys": "|".join(sorted(set(export_detail_keys))),
            "evidence_ref": SECURITY_REVIEW_EXPORT_EVIDENCE_REF,
            "item_evidence_ref": item.get("item_evidence_ref") or SECURITY_REVIEW_ITEM_EVIDENCE_REF,
            "redaction_evidence_ref": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
            "filter_evidence_ref": SECURITY_REVIEW_FILTER_EVIDENCE_REF,
            "decision_history_evidence_ref": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
            "source_security_surface_evidence_ref": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
        }
        writer.writerow({field: csv_safe_value(csv_row.get(field)) for field in fieldnames})
    return output.getvalue()


def persist_security_review_export_audit(format: str, row_count: int, trace_id: str, request_id: str) -> None:
    try:
        with psycopg.connect(database_url(), autocommit=True) as conn:
            conn.execute(
                """
                INSERT INTO audit_log(event_type, user_id, details, severity)
                VALUES ('security_review_queue_export_generated', 'security-review', %s::jsonb, 'info')
                """,
                (
                    Json(
                        redact_json(
                            {
                                "contract_version": SECURITY_REVIEW_EXPORT_CONTRACT_VERSION,
                                "trace_id": trace_id,
                                "request_id": request_id,
                                "format": format,
                                "row_count": row_count,
                                "evidence_ref": SECURITY_REVIEW_EXPORT_AUDIT_EVIDENCE_REF,
                                "export_evidence_ref": SECURITY_REVIEW_EXPORT_EVIDENCE_REF,
                                "queue_evidence_ref": SECURITY_REVIEW_QUEUE_EVIDENCE_REF,
                                "item_evidence_ref": SECURITY_REVIEW_ITEM_EVIDENCE_REF,
                                "redaction_evidence_ref": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
                                "mutation_block_evidence_ref": SECURITY_REVIEW_MUTATION_BLOCK_EVIDENCE_REF,
                                "source_security_surface_evidence_ref": SECURITY_AUDIT_SURFACE_EVIDENCE_REF,
                                "live_provider_calls_claimed": False,
                                "live_mcp_writes_claimed": False,
                                "production_rollout_claimed": False,
                                "promotion_allowed": False,
                            }
                        )
                    ),
                ),
            )
    except Exception as exc:  # pragma: no cover - audit persistence must not break exports
        print(f"security review export audit failed: {exc}")


@app.get("/api/v1/security/review-queue/contract")
def security_review_queue_contract() -> dict[str, object]:
    return security_review_queue_contract_payload()


@app.get("/api/v1/security/review-queue/export/contract")
def security_review_queue_export_contract() -> dict[str, object]:
    return security_review_queue_export_contract_payload()


@app.get("/api/v1/security/review-queue")
def security_review_queue(
    limit: int = Query(default=20, ge=1, le=100),
    status: str | None = Query(default=None),
    severity: str | None = Query(default=None),
    category: str | None = Query(default=None),
) -> dict[str, object]:
    queue = build_security_review_queue(limit=limit, status=status, severity=severity, category=category)
    return {
        "contract_version": SECURITY_REVIEW_QUEUE_CONTRACT_VERSION,
        "mode": "read_only_redacted_security_review_queue",
        "evidence_ref": SECURITY_REVIEW_QUEUE_EVIDENCE_REF,
        "item_evidence_ref": SECURITY_REVIEW_ITEM_EVIDENCE_REF,
        "redaction_evidence_ref": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
        "filter_evidence_ref": SECURITY_REVIEW_FILTER_EVIDENCE_REF,
        "decision_history_evidence_ref": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
        "evidence_snapshot_ref": SECURITY_REVIEW_SNAPSHOT_EVIDENCE_REF,
        "read_only": True,
        "filters": {
            "limit": limit,
            "status": status,
            "severity": severity,
            "category": category,
        },
        "items": queue["items"],
        "count": queue["count"],
        "status_counts": queue["status_counts"],
        "category_counts": queue["category_counts"],
        "risk_badges": queue["risk_badges"],
        "source_surface": "GET /api/v1/security/events",
        "non_claims": security_review_queue_contract_payload()["non_claims"],
    }


@app.get("/api/v1/security/review-queue/snapshot")
def security_review_queue_snapshot(
    limit: int = Query(default=50, ge=1, le=100),
    status: str | None = Query(default=None),
    severity: str | None = Query(default=None),
    category: str | None = Query(default=None),
) -> dict[str, object]:
    queue = build_security_review_queue(limit=limit, status=status, severity=severity, category=category)
    return {
        "contract_version": SECURITY_REVIEW_QUEUE_CONTRACT_VERSION,
        "mode": "read_only_security_review_evidence_snapshot",
        "endpoint": "GET /api/v1/security/review-queue/snapshot",
        "queue_endpoint": "GET /api/v1/security/review-queue",
        "evidence_ref": SECURITY_REVIEW_SNAPSHOT_EVIDENCE_REF,
        "filter_evidence_ref": SECURITY_REVIEW_FILTER_EVIDENCE_REF,
        "decision_history_evidence_ref": SECURITY_REVIEW_DECISION_HISTORY_EVIDENCE_REF,
        "read_only": True,
        "filters": {
            "limit": limit,
            "status": status,
            "severity": severity,
            "category": category,
        },
        "counts": {
            "items": queue["count"],
            "status": queue["status_counts"],
            "category": queue["category_counts"],
            "risk_badges": queue["risk_badges"],
        },
        "latest_decisions": [
            {
                "queue_item_id": item["queue_item_id"],
                "request_id": item["request_id"],
                "trace_id": item["trace_id"],
                "status": item["status"],
                "risk_badge": item["risk_badge"],
                "decision_history": item["decision_history"],
                "evidence_snapshot": item["evidence_snapshot"],
            }
            for item in queue["items"][:10]
        ],
        "policy_checks": [
            "Evidence snapshots are derived from read-only audit_log rows.",
            "Filter state is explicit and visible through security_review_filter_state_visible.",
            "Decision history is read-only and cannot approve or reject release boundaries.",
        ],
        "non_claims": security_review_queue_contract_payload()["non_claims"],
    }


@app.get("/api/v1/security/review-queue/gate")
def security_review_queue_gate(
    limit: int = Query(default=50, ge=1, le=100),
    severity: str | None = Query(default=None),
    category: str | None = Query(default=None),
) -> dict[str, object]:
    return build_security_review_gate(limit=limit, severity=severity, category=category)


@app.get("/api/v1/security/review-queue/export")
def security_review_queue_export(
    request: Request,
    format: str = Query(default="csv", pattern="^csv$"),
    limit: int = Query(default=80, ge=1, le=200),
    status: str | None = Query(default=None),
    severity: str | None = Query(default=None),
    category: str | None = Query(default=None),
    trace_id: str | None = Query(default=None, max_length=255),
    request_id: str | None = Query(default=None, max_length=255),
) -> Response:
    if format != "csv":
        raise HTTPException(status_code=400, detail={"error": "unsupported_format", "allowed": ["csv"]})
    queue = build_security_review_queue(limit=limit, status=status, severity=severity, category=category)
    items = queue["items"] if isinstance(queue.get("items"), list) else []
    csv_payload = build_security_review_export_csv(items)
    row_count = max(0, len(csv_payload.splitlines()) - 1)
    resolved_trace_id = public_trace_id(trace_id) or f"security-review-export-{uuid4()}"
    resolved_request_id = (
        public_request_id(request_id)
        or public_request_id(getattr(request.state, "request_id", None))
        or public_request_id(request.headers.get("x-request-id"))
        or f"req-{uuid4()}"
    )
    persist_security_review_export_audit(format, row_count, resolved_trace_id, resolved_request_id)
    filename = "superbrain-security-review-queue.csv"
    return Response(
        csv_payload,
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "X-Contract-Version": SECURITY_REVIEW_EXPORT_CONTRACT_VERSION,
            "X-Evidence-Ref": SECURITY_REVIEW_EXPORT_EVIDENCE_REF,
            "X-Export-Audit-Evidence-Ref": SECURITY_REVIEW_EXPORT_AUDIT_EVIDENCE_REF,
            "X-Redaction-Evidence-Ref": SECURITY_REVIEW_REDACTION_EVIDENCE_REF,
            "X-Mutation-Block-Evidence-Ref": SECURITY_REVIEW_MUTATION_BLOCK_EVIDENCE_REF,
            "X-Trace-Id": resolved_trace_id,
            "X-Request-Id": resolved_request_id,
        },
    )


@app.api_route(
    "/api/v1/security/review-queue",
    methods=["POST", "PUT", "PATCH", "DELETE"],
)
def security_review_queue_mutation_blocked() -> None:
    raise HTTPException(
        status_code=403,
        detail={
            "error": "security_review_queue_is_read_only",
            "evidence_ref": SECURITY_REVIEW_MUTATION_BLOCK_EVIDENCE_REF,
            "read_only": True,
            "allowed_method": "GET",
        },
    )


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
                "details": public_audit_details(row[4] or {}),
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
                "request_id": public_request_id((row[4] or {}).get("request_id")),
                "trace_id": public_trace_id((row[4] or {}).get("trace_id") or (str(row[3]) if row[3] else None)),
                "correlation_evidence_ref": (row[4] or {}).get(
                    "correlation_evidence_ref",
                    "request_id_audit_correlation",
                ),
                "audit_feed_evidence_ref": "request_id_audit_feed_visible",
                "details": public_audit_details(row[4] or {}),
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
    normalized_query = q.strip()
    if not normalized_query:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "memory_search_empty_query",
                "message": "memory search query must contain at least one non-whitespace character",
                "evidence_ref": "memory_search_empty_query_blocked",
            },
        )
    results = [item.model_dump() for item in search_memory(project_id, normalized_query, limit)]
    return {
        "results": [item for item in results if item["relevance_score"] >= threshold],
        "search_mode": "lexical_fallback",
        "evidence_ref": MEMORY_SEARCH_EVIDENCE_REF,
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
    details = public_audit_details(details)
    if not isinstance(details, dict):
        details = {}
    request_id = public_request_id(details.get("request_id"))
    trace_id = public_trace_id(details.get("trace_id") or details.get("thread_id") or fallback_trace_id or session_id)
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
    details = public_audit_details(row[4] or {})
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


@app.get("/api/v1/observability/langfuse/contract")
def langfuse_trace_access_contract() -> dict[str, object]:
    return langfuse_trace_access_contract_payload()


@app.get("/api/v1/observability/langfuse/trace/{trace_id}")
def langfuse_trace_access(
    trace_id: str,
    limit: int = Query(default=20, ge=1, le=100),
) -> dict[str, object]:
    if not trace_id or len(trace_id) > 255:
        raise HTTPException(status_code=422, detail="trace_id must be between 1 and 255 characters")
    trace_pattern = f"%{trace_id}%"
    with psycopg.connect(database_url(), autocommit=True) as conn:
        rows = conn.execute(
            """
            SELECT id, event_type, user_id, session_id, details, created_at, severity
            FROM audit_log
            WHERE details->>'trace_id' ILIKE %s
               OR details->>'thread_id' ILIKE %s
               OR CAST(session_id AS TEXT) ILIKE %s
            ORDER BY created_at DESC
            LIMIT %s
            """,
            (trace_pattern, trace_pattern, trace_pattern, limit),
        ).fetchall()
    events = []
    for row in rows:
        details = public_audit_details(row[4] or {})
        if not isinstance(details, dict):
            details = {}
        resolved_trace_id = public_trace_id(details.get("trace_id") or details.get("thread_id") or (str(row[3]) if row[3] else trace_id))
        events.append(
            {
                "id": str(row[0]),
                "event_type": row[1],
                "user_id": row[2],
                "session_id": str(row[3]) if row[3] else None,
                "trace_id": resolved_trace_id,
                "severity": row[6],
                "created_at": row[5].isoformat() if row[5] else None,
                "details": details,
                "evidence_ref": LANGFUSE_TRACE_EVENT_EVIDENCE_REF,
            }
        )
    contract = langfuse_trace_access_contract_payload()
    return {
        "contract_version": LANGFUSE_TRACE_ACCESS_CONTRACT_VERSION,
        "mode": "audit_log_backed_trace_access",
        "trace_id": public_trace_id(trace_id),
        "evidence_ref": LANGFUSE_TRACE_ACCESS_EVIDENCE_REF,
        "event_evidence_ref": LANGFUSE_TRACE_EVENT_EVIDENCE_REF,
        "langfuse_trace_url": str(contract["deep_link_template"]).replace("{trace_id}", public_trace_id(trace_id) or "trace-redacted"),
        "langfuse_public_url_configured": contract["langfuse_public_url_configured"],
        "auth_proxy_required": contract["auth_proxy_required"],
        "read_only": True,
        "provider_trace_export": False,
        "events": events,
        "count": len(events),
        "non_claims": contract["non_claims"],
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
            "audit_event_type": "security_csp_violation_reported",
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
            "CSP violation reports are accepted through a same-origin endpoint and persisted without raw secrets.",
        ],
        "evidence_refs": {
            "contract_visible": "security_headers_contract_visible",
            "headers_enforced": "security_headers_enforced",
            "same_origin_cors_policy": "security_headers_same_origin_policy",
            "ui_visible": "security_headers_ui_visible",
            "csp_report_visible": CSP_REPORT_EVIDENCE_REF,
        },
    }


@app.get("/api/v1/security/headers/contract")
def security_headers_contract() -> dict[str, object]:
    return security_headers_contract_payload()


def csp_report_contract_payload() -> dict[str, object]:
    return {
        "contract_version": CSP_REPORT_CONTRACT_VERSION,
        "mode": "same_origin_csp_violation_audit_sink",
        "endpoint": "POST /api/v1/security/csp/report",
        "audit_event_type": "security_csp_violation_reported",
        "audit_user_id": "security",
        "evidence_ref": CSP_REPORT_EVIDENCE_REF,
        "audit_evidence_ref": "csp_report_audit_persisted",
        "accepted_shapes": ["report", "csp-report", "csp_report"],
        "sanitized_fields": [
            "document-uri",
            "blocked-uri",
            "violated-directive",
            "effective-directive",
            "source-file",
            "line-number",
            "column-number",
            "status-code",
        ],
        "policy_checks": [
            "Reports are same-origin only through the Agent API surface.",
            "Report payloads are redacted before audit persistence.",
            "The endpoint returns accepted, not completion or incident-resolution.",
            "No external CSP reporting service is configured or claimed.",
        ],
        "non_claims": [
            "No production security incident workflow is claimed.",
            "No third-party report collector is used.",
            "No browser session, cookies, or credentials are persisted by this endpoint.",
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
def csp_report(request_body: CspViolationReportRequest, request: Request) -> dict[str, object]:
    report = request_body.report or {}
    details = {
        "contract_version": CSP_REPORT_CONTRACT_VERSION,
        "evidence_ref": CSP_REPORT_EVIDENCE_REF,
        "audit_evidence_ref": "csp_report_audit_persisted",
        "request_id": request_body.request_id or getattr(request.state, "request_id", None),
        "trace_id": request_body.trace_id or getattr(request.state, "trace_id", None),
        "report": report,
        "user_agent": request_body.user_agent or request.headers.get("user-agent"),
        "live_external_report_forwarding": False,
    }
    audit_event_id = persist_csp_report_audit(details)
    return {
        "status": "accepted",
        "contract_version": CSP_REPORT_CONTRACT_VERSION,
        "evidence_ref": CSP_REPORT_EVIDENCE_REF,
        "audit_evidence_ref": "csp_report_audit_persisted",
        "audit_event_id": audit_event_id,
        "audit_persisted": audit_event_id is not None,
        "live_external_report_forwarding": False,
        "sanitized_summary": "CSP violation report accepted into local audit sink.",
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
            "request_schema": ["tool_request_id:string", "run_id:uuid", "session_id:uuid", "trace_id:string", "request_id?:string", "toolset:string", "capability:string"],
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
                "dispatch_id": "optional autonomous dispatch id",
                "logical_role": "optional supervisor|planner|explorer|coder|tester overlay role",
                "provenance_evidence_ref": "optional evidence ref binding dispatch to queued task",
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
            "dispatch_id": "autonomous dispatch id or null",
            "logical_role": "logical overlay role or null",
            "provenance_evidence_ref": "dispatch-to-task provenance evidence or null",
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
            "autonomous_team_dispatch_task_provenance",
        ],
        "policy_checks": [
            "TaskAssignment validates session_id as UUID before Redis enqueue.",
            "Task policy rejects unknown tools, profile tool drift, missing blocked actions, missing write_scope, and unsafe deployment routing.",
            "Queue depth is visible through public status, recent task feed, and Prometheus metrics.",
            "Priority routing is visible through high/mid/low queue keys and worker consumption order.",
            "Autonomous dispatch provenance is persisted onto each queued task and visible through task status and recent task feeds.",
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


def agent_llm_runtime_guard_parity_payload() -> dict[str, object]:
    gateway_snapshot: dict[str, object] | None = None
    gateway_error: str | None = None
    try:
        with httpx.Client(timeout=5.0) as client:
            response = client.get(f"{llm_gateway_url()}/api/v1/runtime/guard-parity")
            response.raise_for_status()
            gateway_snapshot = response.json()
    except Exception as exc:
        gateway_error = type(exc).__name__

    status = "verified" if gateway_snapshot and gateway_snapshot.get("status") == "verified" else "blocked"
    evidence_refs = [
        LLM_RUNTIME_GUARD_PARITY_EVIDENCE_REF,
        "agent_llm_streaming_contract_visible",
        "llm_gateway_streaming_dry_run",
        "llm_routing_policy_primary_allowed",
    ]
    if isinstance(gateway_snapshot, dict) and isinstance(gateway_snapshot.get("evidence_refs"), list):
        evidence_refs = sorted(set(evidence_refs).union(str(item) for item in gateway_snapshot["evidence_refs"]))

    return {
        "contract_version": LLM_RUNTIME_GUARD_PARITY_CONTRACT_VERSION,
        "mode": "agent_api_to_llm_gateway_runtime_guard_parity",
        "endpoint": "GET /api/v1/agents/llm-runtime-guard-parity",
        "gateway_endpoint": "GET /llm/api/v1/runtime/guard-parity",
        "evidence_ref": LLM_RUNTIME_GUARD_PARITY_EVIDENCE_REF,
        "status": status,
        "covered_boundary": "L3-L4 Agent API / Agent Pool to LLM Gateway",
        "live_provider_calls": False,
        "model_downloads": False,
        "gateway_snapshot": gateway_snapshot,
        "gateway_error": gateway_error,
        "required_agent_executor_fields": [
            "llm_gateway_calls[].routing_policy_checked",
            "llm_gateway_calls[].routing_policy_decision",
            "llm_gateway_calls[].stream_done_seen",
            "llm_gateway_calls[].live_provider_calls_proven_false",
        ],
        "required_gateway_guards": [
            "direct_provider_bypass",
            "unknown_model_id",
            "output_token_budget",
            "streaming_terminal_done",
            "routing_policy_preflight",
        ],
        "evidence_refs": evidence_refs,
        "non_claims": [
            "This Agent API surface mirrors the LLM Gateway guard parity contract; it does not enable live provider generation.",
            "No direct provider URL, provider key, local model download, live MCP write, or production rollout is enabled here.",
        ],
    }


@app.get("/api/v1/agents/llm-runtime-guard-parity")
def agent_llm_runtime_guard_parity() -> dict[str, object]:
    return agent_llm_runtime_guard_parity_payload()


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
        "supported_sources": ["projection", "hetzner_api_readonly"],
        "required_item_fields": ["name", "monthly_cost_cents"],
        "evidence_ref": "infra_budget_contract_runtime_visible",
        "policy_checks": [
            "Infrastructure budget surface remains read-only.",
            "Infra budget source stays visible as projection or readonly Hetzner API evidence.",
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
            "dispatch_id",
            "provenance_evidence_ref",
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
        "ui_evidence_ref": AUTONOMOUS_TASK_DISPATCH_UI_EVIDENCE_REF,
        "status_evidence_ref": AUTONOMOUS_TASK_DISPATCH_STATUS_EVIDENCE_REF,
        "evidence_refs": {
            "dispatch_visible": AUTONOMOUS_TASK_DISPATCH_EVIDENCE_REF,
            "ui_visible": AUTONOMOUS_TASK_DISPATCH_UI_EVIDENCE_REF,
            "status_visible": AUTONOMOUS_TASK_DISPATCH_STATUS_EVIDENCE_REF,
            "provenance": "autonomous_team_dispatch_task_provenance",
            "audit_persisted": "autonomous_team_dispatch_audit_persisted",
        },
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
            "dispatch_id",
            "logical_role",
            "provenance_evidence_ref",
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
            "Dispatch does not authorize production deployment, live provider execution, or live MCP writes.",
            "Dispatch UI sends objectives into the internal queue only; it does not directly edit files or execute cloud mutations.",
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
                "dispatch_id": None,
                "provenance_evidence_ref": None,
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
                "dispatch_id": None,
                "provenance_evidence_ref": None,
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
                "dispatch_id": assignment.dispatch_id,
                "provenance_evidence_ref": assignment.provenance_evidence_ref,
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


@app.get("/api/v1/live-agents/history")
def live_agent_history(
    agent_id: str | None = Query(default=None, min_length=1, max_length=50),
    project_id: str | None = Query(default=None, min_length=1, max_length=255),
    limit: int = Query(default=10, ge=1, le=50),
) -> dict[str, object]:
    return live_agent_history_payload(agent_id=agent_id, project_id=project_id, limit=limit)


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
    safe_metadata = sanitize_live_agent_metadata(request.metadata)
    trace_id = getattr(http_request.state, "trace_id", None) or f"live-agent-{uuid4()}"
    request_id = (
        getattr(http_request.state, "request_id", None)
        or http_request.headers.get("x-request-id")
        or f"req-live-agent-{uuid4()}"
    )
    model = request.model or live_agent_default_model()
    payload = {
        "model": model,
        "instructions": build_live_agent_instructions(agent_id, profile, sanitized_instructions),
        "input": sanitized_message,
        "store": True,
        "text": {
            "format": {"type": "text"},
            "verbosity": "low",
        },
        "reasoning": {"effort": request.reasoning_effort},
        "metadata": {
            **safe_metadata,
            "trace_id": trace_id,
            "agent_type": str(profile["execution_role"]),
            "logical_agent_id": agent_id,
            "project_id": request.project_id,
            "live_provider_calls_allowed": False,
            "runtime_policy": "live_agent_deterministic_gateway_required",
        },
    }
    if previous_response_id:
        payload["previous_response_id"] = previous_response_id

    response_payload = call_llm_gateway_responses(payload)
    response_id = str(response_payload.get("id") or "")
    if response_id:
        set_live_agent_session(
            agent_id,
            response_id=response_id,
            project_id=request.project_id,
            model=str(response_payload.get("model") or model),
            execution_role=str(profile["execution_role"]),
        )

    text = extract_live_agent_text(response_payload)
    audit_persisted = persist_live_agent_steer_audit(
        agent_id=agent_id,
        execution_role=str(profile["execution_role"]),
        project_id=request.project_id,
        response_id=response_id,
        previous_response_id=previous_response_id,
        model=str(response_payload.get("model") or model),
        status=response_payload.get("status", "completed"),
        text=text,
        usage=response_payload.get("usage"),
        trace_id=trace_id,
        request_id=request_id,
        safe_metadata_keys=sorted(safe_metadata.keys()),
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
        "execution_role": profile["execution_role"],
        "project_id": request.project_id,
        "budget": {
            "level": budget_state.level,
            "spent_percentage": budget_state.spent_percentage,
            "total_cost_cents": budget_state.total_cost_cents,
            "budget_limit_cents": budget_state.budget_limit_cents,
        },
        "metadata_policy": {
            "live_provider_calls_allowed": False,
            "user_metadata_fields_forwarded": sorted(safe_metadata.keys()),
            "evidence_ref": "live_agent_metadata_guard_enforced",
        },
        "audit_persisted": audit_persisted,
        "audit_evidence_ref": "live_agent_steering_audit_persisted",
        "trace_id": trace_id,
        "request_id": request_id,
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
    dispatch_id = str(uuid4())
    blueprints = autonomous_assignment_blueprints(
        sanitized_objective,
        write_scope=prepared_write_scope,
        acceptance_criteria=prepared_acceptance_criteria,
    )
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
            dispatch_id=dispatch_id,
            logical_role=str(blueprint["logical_role"]),
            provenance_evidence_ref="autonomous_team_dispatch_task_provenance",
            priority=int(blueprint["priority"]),
            allowed_tools=list(blueprint["allowed_tools"]),
            write_scope=list(blueprint["write_scope"]),
            blocked_actions=list(blueprint["blocked_actions"]),
            acceptance_criteria=list(blueprint["acceptance_criteria"]),
            human_review_required=bool(blueprint["human_review_required"]),
        )
        for blueprint in blueprints
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
    assignment_payloads: list[AutonomousRoleAssignment] = []
    for blueprint, task in zip(blueprints, queued_assignments, strict=True):
        priority = int(blueprint["priority"])
        assignment_payloads.append(
            AutonomousRoleAssignment(
                dispatch_id=dispatch_id,
                logical_role=str(blueprint["logical_role"]),
                provenance_evidence_ref="autonomous_team_dispatch_task_provenance",
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
                        "autonomous_task_ids": [task.task_id for task in queued_assignments],
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
        "evidence_ref": AUTONOMOUS_TASK_DISPATCH_EVIDENCE_REF,
        "ui_evidence_ref": AUTONOMOUS_TASK_DISPATCH_UI_EVIDENCE_REF,
        "status_evidence_ref": AUTONOMOUS_TASK_DISPATCH_STATUS_EVIDENCE_REF,
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
                "details": public_audit_details(row[2] or {}),
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
    request_details = request.model_dump()
    request_details.pop("input_ref", None)
    details = redact_json(
        {
            **request_details,
            "input_ref_stored": False,
            "session_bound": session_id is not None,
            "trace_id": request.trace_id or request.session_id or request.run_id,
            "request_id": request.request_id or request.tool_request_id,
            "evidence_ref": request.evidence_ref,
            "audit_evidence_ref": "mcp_tool_session_bound_audit",
            "redaction_evidence_ref": MCP_AUDIT_REDACTION_EVIDENCE_REF,
            "correlation_evidence_ref": (
                "request_id_audit_correlation"
                if request.request_id or request.trace_id or request.session_id or request.tool_request_id
                else None
            ),
            "audit_feed_evidence_ref": (
                "request_id_audit_feed_visible"
                if request.request_id or request.trace_id or request.session_id or request.tool_request_id
                else None
            ),
            "denied_tool_correlation_evidence_ref": (
                "mcp_denied_tool_audit_correlation" if request.status == "blocked" else None
            ),
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
    session_id = request.session_id
    details = redact_json(request.model_dump())
    details.update(
        {
            "evidence_ref": LLM_AUDIT_FEED_EVIDENCE_REF,
            "audit_feed_evidence_ref": "llm_audit_feed_event_visible",
            "redaction_evidence_ref": LLM_AUDIT_REDACTION_EVIDENCE_REF,
            "correlation_evidence_ref": "request_id_audit_correlation",
            "contract_version": LLM_AUDIT_FEED_CONTRACT_VERSION,
            "read_only_feed": True,
            "prompt_body_stored": False,
        }
    )
    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute(
            """
            INSERT INTO audit_log(event_type, user_id, session_id, details, severity)
            VALUES ('llm_gateway_request', %s, %s, %s::jsonb, %s)
            RETURNING id, created_at
            """,
            (request.agent_type, session_id, Json(details), severity),
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
                    "dispatch_id": assignment.dispatch_id,
                    "logical_role": assignment.logical_role,
                    "provenance_evidence_ref": assignment.provenance_evidence_ref,
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
                            "dispatch_id": task.dispatch_id,
                            "logical_role": task.logical_role,
                            "provenance_evidence_ref": task.provenance_evidence_ref,
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
