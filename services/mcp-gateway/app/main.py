from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import os
import posixpath
import re
import stat
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field, field_validator

MCP_GATEWAY_VERSION = "0.1.0"
MCP_VERSION_PINNING_CONTRACT_VERSION = "mcp-version-pinning-v1"
MCP_VERSION_PINNING_EVIDENCE_REF = "mcp_version_pinning_contract_visible"
FILESYSTEM_PROJECT_PROGRESS_CONTRACT_VERSION = "filesystem-project-progress-read-v1"
FILESYSTEM_PROJECT_PROGRESS_EVIDENCE_REF = "filesystem_project_progress_read_verified"
FILESYSTEM_PROJECT_PROGRESS_PATH = "/app/readonly/project-progress.manifest.json"
FILESYSTEM_PROJECT_PROGRESS_MAX_BYTES = 65_536
FILESYSTEM_PROJECT_PROGRESS_PHASE_IDS = tuple(f"phase_{index}" for index in range(7))
FILESYSTEM_PROJECT_PROGRESS_LAYER_IDS = tuple(f"layer_{index}" for index in range(1, 8))

app = FastAPI(title="Cloud Superbrain MCP Gateway", version=MCP_GATEWAY_VERSION)


class ToolRequest(BaseModel):
    tool_request_id: str = Field(..., min_length=1, max_length=120)
    run_id: str = Field(..., min_length=1, max_length=120)
    session_id: str | None = Field(default=None, max_length=120)
    trace_id: str | None = Field(default=None, max_length=255)
    agent_role: str = Field(..., pattern="^(planner|coder|tester|devops)$")
    toolset: str = Field(..., pattern="^(github|e2b|playwright|filesystem|postgresql|puppeteer)$")
    capability: str = Field(..., min_length=1, max_length=120)
    intent_summary: str = Field(..., min_length=1, max_length=500)
    input_ref: str = Field(..., min_length=1, max_length=500)
    allowed_scope: str = Field(..., min_length=1, max_length=500)
    timeout_ms: int = Field(..., ge=1, le=1_800_000)
    retry_budget: int = Field(..., ge=0, le=2)
    idempotency_key: str | None = Field(default=None, max_length=120)
    audit_tags: list[str] = Field(default_factory=list)
    redaction_required: bool = True
    expected_output_type: str = Field(..., min_length=1, max_length=120)

    @field_validator("session_id")
    @classmethod
    def validate_session_uuid(cls, value: str | None) -> str | None:
        if value is None:
            return None
        try:
            return str(UUID(value))
        except (TypeError, ValueError) as exc:
            raise ValueError("session_id must be a valid UUID") from exc


class LiveWorkspaceWriteProbeRequest(BaseModel):
    tool_request_id: str = Field(..., pattern=r"^o4-(runtime|browser|rollback)-[a-f0-9]{32}$")
    run_id: str = Field(..., pattern=r"^o4-(runtime|browser|rollback)-run-[a-f0-9]{32}$")
    session_id: str
    agent_role: str = Field(default="coder", pattern="^coder$")
    repository: str = Field(..., min_length=1, max_length=160)
    branch: str = Field(..., min_length=1, max_length=160, pattern=r"^[A-Za-z0-9._/-]+$")
    channel: str = Field(..., pattern="^(runtime|browser|rollback)$")
    idempotency_key: str = Field(..., pattern=r"^o4-(runtime|browser|rollback)-[a-f0-9]{32}$")
    simulate_commit_audit_failure: bool = False

    model_config = {"extra": "forbid"}

    @field_validator("session_id")
    @classmethod
    def validate_session_uuid(cls, value: str) -> str:
        try:
            return str(UUID(value))
        except (TypeError, ValueError) as exc:
            raise ValueError("session_id must be a valid UUID") from exc


def parse_input_ref(input_ref: str) -> dict[str, object]:
    try:
        value = json.loads(input_ref)
        if isinstance(value, dict):
            return value
    except json.JSONDecodeError:
        return {}
    return {}


POSTGRESQL_FORBIDDEN_SQL = (
    "insert",
    "update",
    "delete",
    "drop",
    "alter",
    "truncate",
    "create",
    "grant",
    "revoke",
    "merge",
    "copy",
    "execute",
    "call",
    "migrate",
)

FILESYSTEM_WORKSPACE_ROOT = "/tmp/agent-workspace"
FILESYSTEM_ALLOWED_OPERATIONS = ("read_file", "write_file", "list_directory")
FILESYSTEM_FORBIDDEN_OPERATIONS = (
    "delete",
    "remove",
    "move",
    "rename",
    "chmod",
    "chown",
    "symlink",
    "exec",
    "shell",
    "read_secret",
    "write_secret",
)
O4_LIVE_WRITE_CONTRACT_VERSION = "o4-live-agent-mcp-write-v1"
O4_LIVE_WRITE_EVIDENCE_REF = "o4_live_agent_mcp_write_audit_verified"
O4_ALLOWED_REPOSITORY = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
O4_OWNER_MANIFEST_PATH = "/app/progress/owner-input-manifest.json"
O4_GIT_HEAD_PATH = "/app/o4-git/HEAD"
O4_PROBE_DIRECTORY = "o4-live-write"
O4_MAX_PRIOR_BYTES = 32_768

PLAYWRIGHT_ALLOWED_ACTIONS = ("navigate_to_url", "take_screenshot", "extract_text", "close_browser")
PLAYWRIGHT_FORBIDDEN_SCHEMES = ("file", "ftp", "data", "javascript")
PLAYWRIGHT_FORBIDDEN_HOSTS = ("169.254.169.254", "metadata.google.internal", "metadata.azure.internal")
PLAYWRIGHT_ALLOWED_LOCAL_TARGETS = ("localhost:8081", "127.0.0.1:8081")

E2B_ALLOWED_ACTIONS = ("create_sandbox", "execute_code", "read_output", "close_sandbox")
E2B_ALLOWED_SCOPES = ("sandbox:test", "sandbox:ephemeral")
E2B_FORBIDDEN_TOKENS = ("production", "secret", "private_key", "sudo", "privileged", "crypto_mining", "network_scan")
E2B_MAX_SESSION_TIMEOUT_MS = 1_800_000


def normalize_sql(sql: str) -> str:
    return re.sub(r"\s+", " ", sql.strip()).lower()


def normalize_workspace_path(path: str) -> str:
    if not path.startswith("/"):
        path = f"{FILESYSTEM_WORKSPACE_ROOT}/{path}"
    return posixpath.normpath(path)


def filesystem_workspace_scope_plan(request: ToolRequest, started: float) -> dict[str, object]:
    payload = parse_input_ref(request.input_ref)
    operation = str(payload.get("operation") or request.capability).strip()
    raw_path = str(payload.get("path") or request.allowed_scope).strip()
    normalized_path = normalize_workspace_path(raw_path)
    lowered = f"{operation} {request.capability} {request.allowed_scope} {raw_path}".lower()
    violations: list[str] = []

    if operation not in FILESYSTEM_ALLOWED_OPERATIONS:
        violations.append("operation must be read_file, write_file, or list_directory")
    if any(token in lowered for token in FILESYSTEM_FORBIDDEN_OPERATIONS):
        violations.append("delete/move/admin/secret filesystem operations are forbidden")
    if ".." in raw_path.replace("\\", "/").split("/"):
        violations.append("path traversal is forbidden")
    if not (normalized_path == FILESYSTEM_WORKSPACE_ROOT or normalized_path.startswith(f"{FILESYSTEM_WORKSPACE_ROOT}/")):
        violations.append("path must stay inside /tmp/agent-workspace")
    if not (request.allowed_scope == FILESYSTEM_WORKSPACE_ROOT or request.allowed_scope.startswith(f"{FILESYSTEM_WORKSPACE_ROOT}/")):
        violations.append("allowed_scope must stay inside /tmp/agent-workspace")

    if violations:
        return envelope_result(
            request,
            status="blocked",
            sanitized_summary=f"Filesystem workspace access plan blocked: {'; '.join(violations)}",
            error_class="filesystem_scope_policy_violation",
            evidence_ref="filesystem_scope_policy",
            started=started,
        )

    result = envelope_result(
        request,
        status="success",
        sanitized_summary=f"Dry-run filesystem workspace access plan accepted for {operation}; no filesystem call performed.",
        evidence_ref="filesystem_workspace_access_plan",
        started=started,
    )
    result["filesystem_plan"] = {
        "contract_version": "filesystem-workspace-scope-v1",
        "live_filesystem_call": False,
        "workspace_root": FILESYSTEM_WORKSPACE_ROOT,
        "operation": operation,
        "path": normalized_path,
        "allowed_scope": request.allowed_scope,
        "readonly_required_for_external_paths": True,
        "non_claims": [
            "No filesystem read or write was executed by this dry-run plan.",
            "No path outside /tmp/agent-workspace is permitted by this contract.",
        ],
    }
    return result


def filesystem_workspace_scope_contract() -> dict[str, object]:
    return {
        "contract_version": "filesystem-workspace-scope-v1",
        "mode": "dry_run_contract_only",
        "toolset": "filesystem",
        "capability": "plan_workspace_access",
        "live_filesystem_call": False,
        "workspace_root": FILESYSTEM_WORKSPACE_ROOT,
        "allowed_operations": list(FILESYSTEM_ALLOWED_OPERATIONS),
        "forbidden_operations": list(FILESYSTEM_FORBIDDEN_OPERATIONS),
        "default_payload": {
            "operation": "read_file",
            "path": "/tmp/agent-workspace/context/task.md",
        },
        "policy_checks": [
            "path must stay inside /tmp/agent-workspace",
            "path traversal is forbidden",
            "operation must be read_file, write_file, or list_directory",
            "delete/move/admin/secret filesystem operations are forbidden",
            "no live filesystem call is made by the contract endpoint",
        ],
        "evidence_refs": {
            "accepted": "filesystem_workspace_access_plan",
            "blocked": "filesystem_scope_policy",
        },
        "non_claims": [
            "No filesystem read or write is executed by this contract endpoint.",
            "No host filesystem access outside /tmp/agent-workspace is claimed or allowed.",
        ],
    }


def filesystem_project_progress_contract() -> dict[str, object]:
    return {
        "contract_version": FILESYSTEM_PROJECT_PROGRESS_CONTRACT_VERSION,
        "public_contract_endpoint": "GET /api/v1/filesystem/project-progress/contract",
        "internal_execute_endpoint": "GET /internal/v1/filesystem/project-progress",
        "source": "image_baked_project_progress_manifest",
        "capability": "read_project_progress",
        "canonical_query": "canonical-project-progress",
        "max_source_bytes": FILESYSTEM_PROJECT_PROGRESS_MAX_BYTES,
        "caller_path_allowed": False,
        "caller_filename_allowed": False,
        "caller_operation_allowed": False,
        "regular_file_required": True,
        "symlink_allowed": False,
        "writable_source_allowed": False,
        "strict_utf8_json_required": True,
        "required_phase_ids": list(FILESYSTEM_PROJECT_PROGRESS_PHASE_IDS),
        "required_layer_ids": list(FILESYSTEM_PROJECT_PROGRESS_LAYER_IDS),
        "audit_before_read_required": True,
        "audit_after_read_required": True,
        "timeout_seconds": 3,
        "retry_budget": 0,
        "hosted_enabled": False,
        "live_mcp_writes": False,
        "live_provider_calls": False,
        "direct_provider_calls": False,
        "production_deploy": False,
        "secret_output": False,
        "evidence_ref": FILESYSTEM_PROJECT_PROGRESS_EVIDENCE_REF,
        "non_claims": [
            "This adapter reads only the fixed image-baked project progress manifest in exact DEV-ONLY mode.",
            "No caller path, filename, operation, provider call, MCP write, secret output, hosted use, or production deployment is enabled.",
        ],
    }


def _strict_json_object(raw: bytes) -> dict[str, object]:
    try:
        text = raw.decode("utf-8", errors="strict")

        def reject_duplicate_pairs(pairs: list[tuple[str, object]]) -> dict[str, object]:
            result: dict[str, object] = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError("duplicate JSON key")
                result[key] = value
            return result

        payload = json.loads(
            text,
            object_pairs_hook=reject_duplicate_pairs,
            parse_constant=lambda _value: (_ for _ in ()).throw(ValueError("invalid JSON constant")),
        )
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise ValueError("project progress source is not strict UTF-8 JSON") from exc
    if not isinstance(payload, dict):
        raise ValueError("project progress source must be an object")
    return payload


def _bounded_progress_items(
    container: object,
    expected_ids: tuple[str, ...],
    label: str,
) -> list[dict[str, object]]:
    if not isinstance(container, dict) or set(container) != {"label", "items"}:
        raise ValueError(f"{label} container schema mismatch")
    if (
        not isinstance(container["label"], str)
        or not container["label"].strip()
        or len(container["label"]) > 160
    ):
        raise ValueError(f"{label} label is invalid")
    items = container.get("items")
    if not isinstance(items, list) or len(items) != len(expected_ids):
        raise ValueError(f"{label} must contain exactly seven items")

    projection: list[dict[str, object]] = []
    for expected_id, item in zip(expected_ids, items, strict=True):
        if not isinstance(item, dict) or set(item) != {"id", "label", "percent", "status"}:
            raise ValueError(f"{label} item schema mismatch")
        item_id = item.get("id")
        percent = item.get("percent")
        if item_id != expected_id or isinstance(percent, bool) or not isinstance(percent, int):
            raise ValueError(f"{label} item identity or percent is invalid")
        if not 0 <= percent <= 100:
            raise ValueError(f"{label} percent is out of range")
        projected: dict[str, object] = {"id": item_id, "percent": percent}
        for field, maximum in (("label", 160), ("status", 16_384)):
            value = item.get(field)
            if not isinstance(value, str) or not value.strip() or len(value) > maximum:
                raise ValueError(f"{label} {field} is invalid")
        projection.append(projected)
    return projection


def _read_filesystem_project_progress_source() -> tuple[dict[str, object], str, int]:
    configured_path = os.getenv("FILESYSTEM_PROJECT_PROGRESS_PATH", FILESYSTEM_PROJECT_PROGRESS_PATH)
    source_path = Path(configured_path)
    try:
        path_stat = source_path.lstat()
    except OSError as exc:
        raise ValueError("project progress source is unavailable") from exc
    if stat.S_ISLNK(path_stat.st_mode) or not stat.S_ISREG(path_stat.st_mode):
        raise ValueError("project progress source must be a regular non-symlink file")
    flags = os.O_RDONLY
    flags |= getattr(os, "O_BINARY", 0)
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(source_path, flags)
    except OSError as exc:
        raise ValueError("project progress source read failed") from exc
    try:
        source_stat = os.fstat(descriptor)
        if not stat.S_ISREG(source_stat.st_mode):
            raise ValueError("project progress source must be a regular file")
        if (source_stat.st_dev, source_stat.st_ino) != (path_stat.st_dev, path_stat.st_ino):
            raise ValueError("project progress source changed before the bounded read")
        if source_stat.st_mode & (stat.S_IWUSR | stat.S_IWGRP | stat.S_IWOTH):
            raise ValueError("project progress source must not be writable")
        if source_stat.st_size <= 0 or source_stat.st_size > FILESYSTEM_PROJECT_PROGRESS_MAX_BYTES:
            raise ValueError("project progress source size is outside the fixed bound")
        chunks: list[bytes] = []
        remaining = FILESYSTEM_PROJECT_PROGRESS_MAX_BYTES + 1
        while remaining > 0:
            chunk = os.read(descriptor, min(8192, remaining))
            if not chunk:
                break
            chunks.append(chunk)
            remaining -= len(chunk)
        raw = b"".join(chunks)
        completed_stat = os.fstat(descriptor)
        if (
            len(raw) != source_stat.st_size
            or len(raw) > FILESYSTEM_PROJECT_PROGRESS_MAX_BYTES
            or completed_stat.st_size != source_stat.st_size
            or completed_stat.st_mtime_ns != source_stat.st_mtime_ns
        ):
            raise ValueError("project progress source changed during the bounded read")
    finally:
        os.close(descriptor)

    payload = _strict_json_object(raw)
    known_top_level = {
        "overall_percent",
        "progress_source",
        "horizontal",
        "vertical",
        "truth_policy",
        "binding_document",
        "last_verified",
        "non_claims",
    }
    required_top_level = {"overall_percent", "progress_source", "horizontal", "vertical", "last_verified"}
    if not required_top_level.issubset(payload) or set(payload).difference(known_top_level):
        raise ValueError("project progress top-level schema mismatch")
    if payload.get("progress_source") != "docs/project-progress.manifest.json":
        raise ValueError("project progress source identity mismatch")
    overall_percent = payload.get("overall_percent")
    last_verified = payload.get("last_verified")
    if isinstance(overall_percent, bool) or not isinstance(overall_percent, int) or not 0 <= overall_percent <= 100:
        raise ValueError("overall_percent is invalid")
    if not isinstance(last_verified, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", last_verified):
        raise ValueError("last_verified is invalid")
    horizontal = _bounded_progress_items(payload.get("horizontal"), FILESYSTEM_PROJECT_PROGRESS_PHASE_IDS, "horizontal")
    vertical = _bounded_progress_items(payload.get("vertical"), FILESYSTEM_PROJECT_PROGRESS_LAYER_IDS, "vertical")
    projection = {
        "overall_percent": overall_percent,
        "horizontal": horizontal,
        "vertical": vertical,
        "last_verified": last_verified,
    }
    return projection, hashlib.sha256(raw).hexdigest(), len(raw)


def _filesystem_project_progress_tool_request(trace_id: str) -> ToolRequest:
    request_id = uuid4().hex
    return ToolRequest(
        tool_request_id=f"filesystem-progress-{request_id}",
        run_id=f"filesystem-progress-run-{request_id}",
        session_id=str(uuid4()),
        trace_id=trace_id,
        agent_role="planner",
        toolset="filesystem",
        capability="read_project_progress",
        intent_summary="Read the fixed image-baked project progress manifest.",
        input_ref="fixed:image-baked-project-progress",
        allowed_scope="fixed:image-baked-project-progress",
        timeout_ms=3_000,
        retry_budget=0,
        idempotency_key=None,
        audit_tags=["read_phase:authorized"],
        redaction_required=True,
        expected_output_type="filesystem_project_progress_projection",
    )


def _valid_audit_event_id(event: object) -> str | None:
    if not isinstance(event, dict):
        return None
    event_id = event.get("event_id")
    try:
        return str(UUID(str(event_id)))
    except (TypeError, ValueError):
        return None


def execute_filesystem_project_progress_read(
    supplied_token: str | None,
    trace_id: str | None = None,
) -> dict[str, object]:
    if os.getenv("SUPERBRAIN_RUNTIME_MODE", "") != "dev-only":
        raise HTTPException(status_code=403, detail="filesystem project progress adapter is DEV-ONLY")
    if not o4_internal_auth_valid(supplied_token):
        raise HTTPException(status_code=401, detail="filesystem project progress service authentication required")

    bounded_trace_id = str(trace_id or f"filesystem-progress-{uuid4()}")
    if not re.fullmatch(r"[A-Za-z0-9._:-]{1,255}", bounded_trace_id):
        raise HTTPException(status_code=400, detail="filesystem project progress trace id is invalid")
    authorization_request = _filesystem_project_progress_tool_request(bounded_trace_id)
    authorization_result = envelope_result(
        authorization_request,
        status="success",
        sanitized_summary="Authorized the fixed DEV-ONLY project progress read.",
        evidence_ref=FILESYSTEM_PROJECT_PROGRESS_EVIDENCE_REF,
    )
    authorization_event = post_audit_event(authorization_request, authorization_result)
    authorization_event_id = _valid_audit_event_id(authorization_event)
    if not authorization_event_id:
        raise HTTPException(status_code=503, detail="filesystem project progress authorization audit unavailable")

    try:
        projection, content_sha256, bytes_read = _read_filesystem_project_progress_source()
    except ValueError:
        blocked_request = authorization_request.model_copy(update={"audit_tags": ["read_phase:completed"]})
        blocked_result = envelope_result(
            blocked_request,
            status="blocked",
            sanitized_summary="The fixed project progress source failed bounded validation; no result returned.",
            error_class="filesystem_project_progress_validation_failed",
            evidence_ref=FILESYSTEM_PROJECT_PROGRESS_EVIDENCE_REF,
        )
        post_audit_event(blocked_request, blocked_result)
        raise HTTPException(status_code=503, detail="filesystem project progress source validation failed") from None

    completion_request = authorization_request.model_copy(update={"audit_tags": ["read_phase:completed"]})
    completion_result = envelope_result(
        completion_request,
        status="success",
        sanitized_summary="Completed and validated the fixed DEV-ONLY project progress read.",
        evidence_ref=FILESYSTEM_PROJECT_PROGRESS_EVIDENCE_REF,
    )
    completion_result.update(
        {
            "content_sha256": content_sha256,
            "filesystem_read_performed": True,
        }
    )
    completion_event = post_audit_event(completion_request, completion_result)
    completion_event_id = _valid_audit_event_id(completion_event)
    if not completion_event_id:
        raise HTTPException(status_code=503, detail="filesystem project progress completion audit unavailable")

    return {
        "contract_version": FILESYSTEM_PROJECT_PROGRESS_CONTRACT_VERSION,
        "status": "success",
        "evidence_ref": FILESYSTEM_PROJECT_PROGRESS_EVIDENCE_REF,
        "trace_id": bounded_trace_id,
        **projection,
        "source_sha256": content_sha256,
        "bytes_read": bytes_read,
        "filesystem_read_performed": True,
        "audit_before_read": True,
        "audit_after_read": True,
        "authorization_audit_event_id": authorization_event_id,
        "completion_audit_event_id": completion_event_id,
        "live_mcp_writes": False,
        "live_provider_calls": False,
        "direct_provider_calls": False,
        "production_deploy": False,
        "secret_output": False,
        "DEV_ONLY": True,
    }


def o4_internal_auth_valid(supplied_token: str | None) -> bool:
    expected_token = os.getenv("AGENT_API_AUTH_TOKEN", "")
    return bool(
        expected_token
        and isinstance(supplied_token, str)
        and supplied_token
        and hmac.compare_digest(supplied_token, expected_token)
    )


def o4_active_branch() -> str:
    head_path = Path(os.getenv("O4_GIT_HEAD_PATH", O4_GIT_HEAD_PATH))
    try:
        head = head_path.read_text(encoding="utf-8-sig").strip()
    except OSError:
        return ""
    prefix = "ref: refs/heads/"
    return head[len(prefix):] if head.startswith(prefix) else ""


def o4_owner_scope_authorized(repository: str, branch: str) -> bool:
    manifest_path = Path(os.getenv("O4_OWNER_MANIFEST_PATH", O4_OWNER_MANIFEST_PATH))
    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return False
    actions = payload.get("actions")
    if not isinstance(actions, list):
        return False
    action = next(
        (item for item in actions if isinstance(item, dict) and item.get("id") == "O4"),
        None,
    )
    decision = action.get("owner_scope_decision") if isinstance(action, dict) else None
    if not isinstance(decision, dict):
        return False
    audit = decision.get("audit_retention")
    write_allowlist = decision.get("mcp_write_allowlist")
    exclusions = decision.get("mcp_write_explicitly_excluded")
    actual_branch = o4_active_branch()
    return bool(
        decision.get("decision") == "approved_as_proposed"
        and decision.get("gate_state_unchanged") is True
        and decision.get("repositories_allowed") == [O4_ALLOWED_REPOSITORY]
        and repository == O4_ALLOWED_REPOSITORY
        and actual_branch
        and actual_branch == branch
        and branch != "main"
        and ".." not in branch.split("/")
        and isinstance(decision.get("branches_forbidden"), str)
        and "main" in decision["branches_forbidden"]
        and isinstance(write_allowlist, list)
        and any(str(item).startswith("filesystem:") for item in write_allowlist)
        and any(str(item).startswith("git:") for item in write_allowlist)
        and isinstance(exclusions, list)
        and any(r"C:\Users\immer\.codex" in str(item) for item in exclusions)
        and any("<SECRETS_DIR>" in str(item) for item in exclusions)
        and isinstance(audit, dict)
        and audit.get("persist_every_write") is True
        and audit.get("secret_values_recorded") is False
        and audit.get("retention") == "unlimited"
        and "rolled back" in str(audit.get("fail_closed_rule", "")).lower()
    )


def o4_live_write_contract() -> dict[str, object]:
    workspace_root = os.getenv("FILESYSTEM_ROOT", FILESYSTEM_WORKSPACE_ROOT)
    return {
        "contract_version": O4_LIVE_WRITE_CONTRACT_VERSION,
        "endpoint": "POST /api/v1/tools/live-write/probe",
        "mode": "DEV-ONLY bounded verifier probe",
        "enabled": os.getenv("O4_LIVE_WRITE_PROBE_ENABLED", "").lower() == "true",
        "toolset": "filesystem",
        "agent_role": "coder",
        "repository": O4_ALLOWED_REPOSITORY,
        "active_branch": o4_active_branch(),
        "workspace_root": workspace_root,
        "fixed_probe_directory": O4_PROBE_DIRECTORY,
        "arbitrary_paths_allowed": False,
        "main_write_allowed": False,
        "force_push_allowed": False,
        "audit_before_write_required": True,
        "audit_after_write_required": True,
        "rollback_on_commit_audit_failure": True,
        "audit_retention": "unlimited",
        "secret_output": False,
        "production_deploy": False,
        "evidence_ref": O4_LIVE_WRITE_EVIDENCE_REF,
        "non_claims": [
            "This contract authorizes only the fixed DEV-ONLY O4 verifier probe.",
            "It does not authorize arbitrary paths, main writes, force pushes, provider writes, releases, or production deployment.",
            "The internal service token is required and is never returned.",
        ],
    }


def o4_tool_request(request: LiveWorkspaceWriteProbeRequest) -> ToolRequest:
    return ToolRequest(
        tool_request_id=request.tool_request_id,
        run_id=request.run_id,
        session_id=request.session_id,
        trace_id=request.run_id,
        agent_role="coder",
        toolset="filesystem",
        capability="write_workspace_probe",
        intent_summary="Execute the fixed bounded O4 live-write verifier probe.",
        input_ref=json.dumps(
            {
                "channel": request.channel,
                "repository": request.repository,
                "branch": request.branch,
            },
            separators=(",", ":"),
        ),
        allowed_scope=FILESYSTEM_WORKSPACE_ROOT,
        timeout_ms=10_000,
        retry_budget=0,
        idempotency_key=request.idempotency_key,
        audit_tags=["o4", "live-write", request.channel, "fail-closed"],
        redaction_required=True,
        expected_output_type="o4_live_write_proof",
    )


def o4_audit_result(
    tool_request: ToolRequest,
    *,
    status: str,
    summary: str,
    phase: str,
    write_path: str,
    branch: str,
    write_result: str,
    content_sha256: str = "",
    live_write: bool = False,
    rollback_performed: bool = False,
) -> dict[str, object]:
    result = envelope_result(
        tool_request,
        status=status,
        sanitized_summary=summary,
        error_class="none" if status == "success" else write_result,
        evidence_ref=O4_LIVE_WRITE_EVIDENCE_REF,
    )
    result.update(
        {
            "write_phase": phase,
            "write_path": write_path,
            "branch_ref": branch,
            "write_result": write_result,
            "content_sha256": content_sha256,
            "live_mcp_write": live_write,
            "rollback_performed": rollback_performed,
            "secret_output": False,
        }
    )
    return result


def o4_atomic_write(target: Path, content: bytes) -> None:
    temporary = target.parent / f".{target.name}.{uuid4().hex}.tmp"
    try:
        temporary.write_bytes(content)
        os.replace(temporary, target)
    finally:
        if temporary.exists():
            temporary.unlink()


def execute_o4_live_write(
    request: LiveWorkspaceWriteProbeRequest,
    supplied_token: str | None,
) -> dict[str, object]:
    if os.getenv("O4_LIVE_WRITE_PROBE_ENABLED", "").lower() != "true":
        raise HTTPException(status_code=403, detail="O4 live-write verifier is disabled")
    if not o4_internal_auth_valid(supplied_token):
        raise HTTPException(status_code=401, detail="O4 internal service authentication required")
    if request.tool_request_id != request.idempotency_key:
        raise HTTPException(status_code=400, detail="O4 idempotency binding mismatch")
    if not request.idempotency_key.startswith(f"o4-{request.channel}-"):
        raise HTTPException(status_code=400, detail="O4 channel binding mismatch")
    if request.simulate_commit_audit_failure and (
        os.getenv("O4_LIVE_WRITE_NEGATIVE_TEST_ENABLED", "").lower() != "true"
        or request.channel != "rollback"
    ):
        raise HTTPException(status_code=403, detail="O4 negative probe is disabled")
    if not o4_owner_scope_authorized(request.repository, request.branch):
        raise HTTPException(status_code=403, detail="O4 owner scope or branch policy rejected")

    configured_root = os.getenv("FILESYSTEM_ROOT", FILESYSTEM_WORKSPACE_ROOT)
    if configured_root != FILESYSTEM_WORKSPACE_ROOT:
        raise HTTPException(status_code=503, detail="O4 workspace root contract mismatch")
    workspace_root = Path(configured_root).resolve()
    target_parent = workspace_root / O4_PROBE_DIRECTORY
    target = target_parent / f"{request.channel}.json"
    logical_path = f"{FILESYSTEM_WORKSPACE_ROOT}/{O4_PROBE_DIRECTORY}/{request.channel}.json"
    tool_request = o4_tool_request(request)

    authorization_audit = post_audit_event(
        tool_request,
        o4_audit_result(
            tool_request,
            status="success",
            summary=f"Authorized bounded O4 write to {logical_path}.",
            phase="authorized",
            write_path=logical_path,
            branch=request.branch,
            write_result="authorized",
        ),
    )
    if not authorization_audit:
        raise HTTPException(status_code=503, detail="O4 pre-write audit unavailable")

    parent_existed = target_parent.exists()
    prior_content: bytes | None = None
    if target.exists():
        if target.is_symlink() or target.stat().st_size > O4_MAX_PRIOR_BYTES:
            raise HTTPException(status_code=409, detail="O4 existing probe target is unsafe")
        prior_content = target.read_bytes()

    content = (
        json.dumps(
            {
                "contract_version": O4_LIVE_WRITE_CONTRACT_VERSION,
                "evidence_ref": O4_LIVE_WRITE_EVIDENCE_REF,
                "repository": request.repository,
                "branch": request.branch,
                "channel": request.channel,
                "idempotency_key": request.idempotency_key,
                "agent_role": "coder",
                "toolset": "filesystem",
                "live_agent_tool_writes": True,
                "live_mcp_writes": True,
                "production_deploy": False,
                "secret_output": False,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    ).encode("utf-8")
    content_sha256 = hashlib.sha256(content).hexdigest()

    try:
        target_parent.mkdir(parents=True, exist_ok=True)
        if target_parent.resolve().parent != workspace_root or target.is_symlink():
            raise RuntimeError("O4 target escaped the fixed workspace")
        o4_atomic_write(target, content)
        if hashlib.sha256(target.read_bytes()).hexdigest() != content_sha256:
            raise RuntimeError("O4 write readback mismatch")
        commit_audit = None if request.simulate_commit_audit_failure else post_audit_event(
            tool_request,
            o4_audit_result(
                tool_request,
                status="success",
                summary=f"Committed and read back bounded O4 write at {logical_path}.",
                phase="committed",
                write_path=logical_path,
                branch=request.branch,
                write_result="committed",
                content_sha256=content_sha256,
                live_write=True,
            ),
        )
        if not commit_audit:
            raise RuntimeError("O4 commit audit unavailable")
    except Exception:
        try:
            if prior_content is None:
                if target.exists() and not target.is_symlink():
                    target.unlink()
            else:
                o4_atomic_write(target, prior_content)
            if not parent_existed and target_parent.exists() and not any(target_parent.iterdir()):
                target_parent.rmdir()
            rollback_ok = post_audit_event(
                tool_request,
                o4_audit_result(
                    tool_request,
                    status="degraded",
                    summary=f"Rolled back bounded O4 write at {logical_path}.",
                    phase="rolled_back",
                    write_path=logical_path,
                    branch=request.branch,
                    write_result="audit_commit_failed_rolled_back",
                    rollback_performed=True,
                ),
            )
        except Exception:
            rollback_ok = None
        raise HTTPException(
            status_code=503,
            detail={
                "error": "O4 live-write commit failed",
                "rollback_performed": True,
                "rollback_audit_persisted": bool(rollback_ok),
                "secret_output": False,
            },
        ) from None

    return {
        "contract_version": O4_LIVE_WRITE_CONTRACT_VERSION,
        "status": "verified",
        "evidence_ref": O4_LIVE_WRITE_EVIDENCE_REF,
        "repository": request.repository,
        "branch": request.branch,
        "channel": request.channel,
        "agent_role": "coder",
        "toolset": "filesystem",
        "write_path": logical_path,
        "write_performed": True,
        "readback_verified": True,
        "content_sha256": content_sha256,
        "prewrite_audit_event_id": authorization_audit["event_id"],
        "mcp_audit_event_id": commit_audit["event_id"],
        "audit_persisted": True,
        "audit_fail_closed": True,
        "rollback_on_audit_failure": True,
        "live_mcp_writes": True,
        "live_provider_calls": False,
        "direct_provider_calls": False,
        "production_deploy": False,
        "secret_output": False,
    }


def playwright_browser_proof_plan(request: ToolRequest, started: float) -> dict[str, object]:
    payload = parse_input_ref(request.input_ref)
    action = str(payload.get("action") or request.capability).strip()
    target_url = str(payload.get("target_url") or "").strip()
    parsed = urllib.parse.urlparse(target_url)
    host_port = parsed.netloc.lower()
    host = parsed.hostname.lower() if parsed.hostname else ""
    violations: list[str] = []

    if action not in PLAYWRIGHT_ALLOWED_ACTIONS:
        violations.append("action must be navigate_to_url, take_screenshot, extract_text, or close_browser")
    if request.timeout_ms > 120_000:
        violations.append("timeout_ms must be <= 120000")
    if not target_url and action != "close_browser":
        violations.append("target_url is required unless action is close_browser")
    if parsed.scheme.lower() in PLAYWRIGHT_FORBIDDEN_SCHEMES:
        violations.append("file/data/javascript browser targets are forbidden")
    if host in PLAYWRIGHT_FORBIDDEN_HOSTS:
        violations.append("cloud metadata browser targets are forbidden")
    if target_url and request.allowed_scope == "browser-proof-localhost" and host_port not in PLAYWRIGHT_ALLOWED_LOCAL_TARGETS:
        violations.append("browser-proof-localhost scope only allows localhost:8081 or 127.0.0.1:8081")
    if target_url and request.allowed_scope == "browser-proof-public-staging" and not host.endswith(".vercel.app"):
        violations.append("browser-proof-public-staging scope only allows *.vercel.app")
    if request.allowed_scope not in {"browser-proof-localhost", "browser-proof-public-staging"}:
        violations.append("allowed_scope must be browser-proof-localhost or browser-proof-public-staging")

    if violations:
        return envelope_result(
            request,
            status="blocked",
            sanitized_summary=f"Playwright browser proof plan blocked: {'; '.join(violations)}",
            error_class="playwright_browser_policy_violation",
            evidence_ref="playwright_browser_policy",
            started=started,
        )

    result = envelope_result(
        request,
        status="success",
        sanitized_summary=f"Dry-run Playwright browser proof plan accepted for {action}; no browser call performed.",
        evidence_ref="playwright_browser_proof_plan",
        started=started,
    )
    result["playwright_plan"] = {
        "contract_version": "playwright-browser-proof-v1",
        "live_browser_call": False,
        "action": action,
        "target_url": target_url,
        "allowed_scope": request.allowed_scope,
        "timeout_ms_cap": 120_000,
        "evidence_required": ["screenshot_ref", "text_extract_ref", "close_browser"],
        "non_claims": [
            "No browser session was opened by this dry-run plan.",
            "No screenshot or page text was captured by this dry-run plan.",
        ],
    }
    return result


def playwright_browser_proof_contract() -> dict[str, object]:
    return {
        "contract_version": "playwright-browser-proof-v1",
        "mode": "dry_run_contract_only",
        "toolset": "playwright",
        "capability": "plan_browser_proof",
        "live_browser_call": False,
        "allowed_actions": list(PLAYWRIGHT_ALLOWED_ACTIONS),
        "allowed_scopes": ["browser-proof-localhost", "browser-proof-public-staging"],
        "allowed_targets": ["http://localhost:8081", "http://127.0.0.1:8081", "https://*.vercel.app"],
        "forbidden_targets": ["file://*", "data:*", "javascript:*", "cloud metadata IPs"],
        "timeout_ms_cap": 120_000,
        "default_payload": {
            "action": "take_screenshot",
            "target_url": "http://localhost:8081",
        },
        "policy_checks": [
            "file/data/javascript browser targets are forbidden",
            "cloud metadata browser targets are forbidden",
            "browser-proof-localhost scope only allows localhost:8081 or 127.0.0.1:8081",
            "browser-proof-public-staging scope only allows *.vercel.app",
            "no live browser call is made by the contract endpoint",
        ],
        "evidence_refs": {
            "accepted": "playwright_browser_proof_plan",
            "blocked": "playwright_browser_policy",
        },
        "non_claims": [
            "No browser session is opened by this contract endpoint.",
            "No screenshot or page text is captured by this contract endpoint.",
        ],
    }


def e2b_sandbox_lifecycle_plan(request: ToolRequest, started: float) -> dict[str, object]:
    payload = parse_input_ref(request.input_ref)
    action = str(payload.get("action") or request.capability).strip()
    code = str(payload.get("code") or "").strip()
    close_sandbox_finally = bool(payload.get("close_sandbox_finally", False))
    lowered = f"{action} {request.capability} {request.allowed_scope} {code}".lower()
    violations: list[str] = []

    if action not in E2B_ALLOWED_ACTIONS:
        violations.append("action must be create_sandbox, execute_code, read_output, or close_sandbox")
    if request.allowed_scope not in E2B_ALLOWED_SCOPES:
        violations.append("allowed_scope must be sandbox:test or sandbox:ephemeral")
    if request.timeout_ms > E2B_MAX_SESSION_TIMEOUT_MS:
        violations.append("timeout_ms must be <= 1800000")
    if action in {"create_sandbox", "execute_code"} and not close_sandbox_finally:
        violations.append("close_sandbox_finally=true is required for create_sandbox and execute_code")
    if any(token in lowered for token in E2B_FORBIDDEN_TOKENS):
        violations.append("production/secret/privileged/network-scan sandbox intents are forbidden")

    if violations:
        return envelope_result(
            request,
            status="blocked",
            sanitized_summary=f"E2B sandbox lifecycle plan blocked: {'; '.join(violations)}",
            error_class="e2b_sandbox_policy_violation",
            evidence_ref="e2b_sandbox_policy",
            started=started,
        )

    result = envelope_result(
        request,
        status="success",
        sanitized_summary=f"Dry-run E2B sandbox lifecycle plan accepted for {action}; no sandbox call performed.",
        evidence_ref="e2b_sandbox_lifecycle_plan",
        started=started,
    )
    result["e2b_plan"] = {
        "contract_version": "e2b-sandbox-lifecycle-v1",
        "live_e2b_call": False,
        "api_key_configured": bool(os.getenv("E2B_API_KEY")),
        "action": action,
        "allowed_scope": request.allowed_scope,
        "max_session_timeout_ms": E2B_MAX_SESSION_TIMEOUT_MS,
        "close_sandbox_finally": close_sandbox_finally,
        "non_claims": [
            "No E2B sandbox was created by this dry-run plan.",
            "No code was executed in E2B by this dry-run plan.",
        ],
    }
    return result


def e2b_sandbox_lifecycle_contract() -> dict[str, object]:
    return {
        "contract_version": "e2b-sandbox-lifecycle-v1",
        "mode": "dry_run_contract_only",
        "toolset": "e2b",
        "capability": "plan_sandbox_lifecycle",
        "live_e2b_call": False,
        "api_key_configured": bool(os.getenv("E2B_API_KEY")),
        "allowed_actions": list(E2B_ALLOWED_ACTIONS),
        "allowed_scopes": list(E2B_ALLOWED_SCOPES),
        "max_session_timeout_ms": E2B_MAX_SESSION_TIMEOUT_MS,
        "close_required": True,
        "default_payload": {
            "action": "execute_code",
            "code": "pytest -q",
            "close_sandbox_finally": True,
        },
        "policy_checks": [
            "close_sandbox_finally=true is required for create_sandbox and execute_code",
            "timeout_ms must be <= 1800000",
            "allowed_scope must be sandbox:test or sandbox:ephemeral",
            "production/secret/privileged/network-scan sandbox intents are forbidden",
            "no live E2B call is made by the contract endpoint",
        ],
        "evidence_refs": {
            "accepted": "e2b_sandbox_lifecycle_plan",
            "blocked": "e2b_sandbox_policy",
            "degraded": "mcp_degraded_missing_e2b_credentials",
        },
        "non_claims": [
            "No E2B sandbox is created by this contract endpoint.",
            "No code is executed in E2B by this contract endpoint.",
        ],
    }


def mcp_version_pinning_contract() -> dict[str, object]:
    return {
        "contract_version": MCP_VERSION_PINNING_CONTRACT_VERSION,
        "mode": "deterministic_local_mcp_version_pinning_contract",
        "audit_gap": "L-08",
        "endpoint": "GET /mcp/api/v1/version-pinning/contract",
        "evidence_ref": MCP_VERSION_PINNING_EVIDENCE_REF,
        "gateway": {
            "service": "mcp-gateway",
            "app_version": MCP_GATEWAY_VERSION,
            "runtime": "python:3.14-slim",
            "requirements_file": "services/mcp-gateway/requirements.txt",
            "dependency_pin_policy": "exact_version_required",
        },
        "pinned_dependencies": [
            {"name": "fastapi", "version": "0.136.3", "pin": "fastapi==0.136.3"},
            {"name": "uvicorn[standard]", "version": "0.49.0", "pin": "uvicorn[standard]==0.49.0"},
            {"name": "pydantic", "version": "2.13.4", "pin": "pydantic==2.13.4"},
        ],
        "pinned_tool_contracts": [
            {
                "toolset": "github",
                "capability": "plan_branch_pr",
                "contract_version": "github-branch-pr-plan-v1",
                "endpoint": "GET /mcp/api/v1/github/branch-pr/contract",
                "live_mutation": False,
            },
            {
                "toolset": "postgresql",
                "capability": "query_readonly",
                "contract_version": "postgresql-readonly-query-v1",
                "endpoint": "GET /mcp/api/v1/postgresql/readonly-query/contract",
                "live_mutation": False,
            },
            {
                "toolset": "filesystem",
                "capability": "plan_workspace_access",
                "contract_version": "filesystem-workspace-scope-v1",
                "endpoint": "GET /mcp/api/v1/filesystem/workspace-scope/contract",
                "live_mutation": False,
            },
            {
                "toolset": "filesystem",
                "capability": "read_project_progress",
                "contract_version": FILESYSTEM_PROJECT_PROGRESS_CONTRACT_VERSION,
                "endpoint": "GET /mcp/api/v1/filesystem/project-progress/contract",
                "internal_execute_endpoint": "GET /internal/v1/filesystem/project-progress",
                "dev_only": True,
                "caller_path_allowed": False,
                "live_mutation": False,
            },
            {
                "toolset": "playwright",
                "capability": "plan_browser_proof",
                "contract_version": "playwright-browser-proof-v1",
                "endpoint": "GET /mcp/api/v1/playwright/browser-proof/contract",
                "live_mutation": False,
            },
            {
                "toolset": "e2b",
                "capability": "plan_sandbox_lifecycle",
                "contract_version": "e2b-sandbox-lifecycle-v1",
                "endpoint": "GET /mcp/api/v1/e2b/sandbox-lifecycle/contract",
                "live_mutation": False,
            },
        ],
        "request_contract": {
            "model": "ToolRequest",
            "toolset_pattern": "^(github|e2b|playwright|filesystem|postgresql|puppeteer)$",
            "session_id": "uuid-or-null",
            "timeout_ms": "1..1800000",
            "retry_budget": "0..2",
            "redaction_required_default": True,
        },
        "drift_policy": [
            "Every runtime dependency in services/mcp-gateway/requirements.txt must use exact == pinning.",
            "Every exposed MCP tool contract must publish a stable contract_version.",
            "Adding or changing a tool capability requires updating this endpoint, docs, UI, and verifiers in the same change.",
            "Unknown toolsets or scope-violating capabilities fail closed before live execution.",
            "Live mutations remain disabled until a separate external gate and human review are configured.",
        ],
        "evidence_refs": [
            MCP_VERSION_PINNING_EVIDENCE_REF,
            "mcp_safe_envelope",
            "mcp_scope_guard",
            "mcp_timeout_guard",
            "mcp_tool_session_bound_audit",
        ],
        "non_claims": [
            "No live MCP write is enabled by this version-pinning contract.",
            "No external MCP server version is claimed beyond the local gateway and its pinned Python dependencies.",
            "No production deployment or hosted staging success is claimed by this local contract.",
        ],
    }


def postgresql_readonly_query_plan(request: ToolRequest, started: float) -> dict[str, object]:
    payload = parse_input_ref(request.input_ref)
    sql = str(payload.get("sql") or "").strip()
    parameters = payload.get("parameters")
    if not isinstance(parameters, list):
        parameters = []

    normalized = normalize_sql(sql)
    violations: list[str] = []
    if not (normalized.startswith("select ") or normalized.startswith("with ")):
        violations.append("SQL must be SELECT or WITH ... SELECT only")
    if ";" in normalized.rstrip(";"):
        violations.append("multiple SQL statements are forbidden")
    if any(re.search(rf"\b{token}\b", normalized) for token in POSTGRESQL_FORBIDDEN_SQL):
        violations.append("write/admin SQL tokens are forbidden")
    if request.allowed_scope != "project-context-readonly":
        violations.append("allowed_scope must be project-context-readonly")

    if violations:
        return envelope_result(
            request,
            status="blocked",
            sanitized_summary=f"PostgreSQL readonly query plan blocked: {'; '.join(violations)}",
            error_class="postgresql_write_policy_violation",
            evidence_ref="postgresql_write_policy",
            started=started,
        )

    result = envelope_result(
        request,
        status="success",
        sanitized_summary="Dry-run PostgreSQL readonly query plan accepted; no database call performed.",
        evidence_ref="postgresql_readonly_query_plan",
        started=started,
    )
    result["postgresql_plan"] = {
        "contract_version": "postgresql-readonly-query-v1",
        "live_database_call": False,
        "readonly": True,
        "allowed_scope": request.allowed_scope,
        "sql": sql,
        "parameters": parameters,
        "non_claims": [
            "No PostgreSQL query was executed by this dry-run plan.",
            "No production database mutation is possible through query_readonly dry-run planning.",
        ],
    }
    return result


def postgresql_readonly_query_contract() -> dict[str, object]:
    return {
        "contract_version": "postgresql-readonly-query-v1",
        "mode": "dry_run_contract_only",
        "toolset": "postgresql",
        "capability": "query_readonly",
        "live_database_call": False,
        "allowed_scope": "project-context-readonly",
        "allowed_sql": ["SELECT only", "WITH ... SELECT only"],
        "forbidden_sql": [token.upper() for token in POSTGRESQL_FORBIDDEN_SQL],
        "default_payload": {
            "sql": "SELECT id, name FROM projects LIMIT 5",
            "parameters": [],
        },
        "policy_checks": [
            "SQL must be SELECT or WITH ... SELECT only",
            "multiple SQL statements are forbidden",
            "write/admin SQL tokens are forbidden",
            "allowed_scope must be project-context-readonly",
        ],
        "evidence_refs": {
            "accepted": "postgresql_readonly_query_plan",
            "blocked": "postgresql_write_policy",
        },
        "non_claims": [
            "No SQL query is executed by this contract endpoint.",
            "No production database mutation is possible through query_readonly dry-run planning.",
        ],
    }


def github_branch_pr_plan(request: ToolRequest, started: float) -> dict[str, object]:
    payload = parse_input_ref(request.input_ref)
    branch = str(payload.get("branch") or request.allowed_scope).strip()
    title = str(payload.get("title") or "Agent generated change proposal").strip()
    base = str(payload.get("base") or "main").strip()
    body = str(payload.get("body") or "Dry-run PR plan generated by MCP gateway.").strip()
    violations: list[str] = []
    if not re.fullmatch(r"feature/agent-[a-z0-9][a-z0-9._-]{6,120}", branch):
        violations.append("branch must match feature/agent-*")
    if base != "main":
        violations.append("pull request base must be main")
    lowered = f"{branch} {request.allowed_scope} {request.capability}".lower()
    if "force" in lowered or "merge" in lowered:
        violations.append("force-push and merge capabilities are forbidden")
    if branch == "main" or branch.startswith("refs/heads/main") or request.allowed_scope.lower() in {"main", "refs/heads/main"}:
        violations.append("direct main branch writes are forbidden")

    if violations:
        return envelope_result(
            request,
            status="blocked",
            sanitized_summary=f"GitHub branch/PR plan blocked: {'; '.join(violations)}",
            error_class="github_branch_policy_violation",
            evidence_ref="github_branch_pr_policy",
            started=started,
        )

    result = envelope_result(
        request,
        status="success",
        sanitized_summary=f"Dry-run GitHub branch/PR plan accepted for {branch}; no mutation performed.",
        evidence_ref="github_branch_pr_plan",
        started=started,
    )
    result["github_plan"] = {
        "contract_version": "github-branch-pr-plan-v1",
        "live_github_call": False,
        "allowed_branch": branch,
        "branch_payload": {
            "ref": f"refs/heads/{branch}",
            "source": "HEAD",
        },
        "pull_request_payload": {
            "title": title,
            "head": branch,
            "base": base,
            "body": body,
            "draft": True,
        },
        "forbidden_capabilities": ["merge_pull_request", "force_push", "delete_branch", "admin_operations"],
        "non_claims": [
            "No GitHub branch was created by this dry-run plan.",
            "No pull request was opened by this dry-run plan.",
        ],
    }
    return result


def github_branch_pr_contract() -> dict[str, object]:
    return {
        "contract_version": "github-branch-pr-plan-v1",
        "mode": "dry_run_contract_only",
        "capability": "plan_branch_pr",
        "toolset": "github",
        "live_github_call": False,
        "allowed_branch_pattern": "feature/agent-*",
        "branch_regex": r"feature/agent-[a-z0-9][a-z0-9._-]{6,120}",
        "default_base": "main",
        "default_payload": {
            "branch": "feature/agent-coder-example-task",
            "title": "Agent generated change proposal",
            "base": "main",
            "body": "Dry-run PR plan generated by MCP gateway.",
        },
        "generated_payloads": {
            "branch_payload": {
                "ref": "refs/heads/{branch}",
                "source": "HEAD",
            },
            "pull_request_payload": {
                "title": "{title}",
                "head": "{branch}",
                "base": "main",
                "body": "{body}",
                "draft": True,
            },
        },
        "policy_checks": [
            "branch must match feature/agent-*",
            "pull request base must be main",
            "direct main branch writes are forbidden",
            "force-push and merge capabilities are forbidden",
        ],
        "forbidden_capabilities": ["merge_pull_request", "force_push", "delete_branch", "admin_operations"],
        "evidence_refs": {
            "accepted": "github_branch_pr_plan",
            "blocked": "github_branch_pr_policy",
        },
        "non_claims": [
            "No GitHub branch is created by this contract endpoint.",
            "No pull request is opened by this contract endpoint.",
            "Live GitHub mutation remains blocked until a separate human-reviewed gate exists.",
        ],
    }


def envelope_result(
    request: ToolRequest,
    status: str,
    sanitized_summary: str,
    error_class: str = "none",
    retry_after_ms: int = 0,
    evidence_ref: str = "none",
    started: float | None = None,
) -> dict[str, object]:
    duration_ms = int((time.perf_counter() - started) * 1000) if started else 0
    return {
        "status": status,
        "result_ref": f"mcp-result:{request.tool_request_id}:{status}",
        "audit_event_id": str(uuid4()),
        "duration_ms": duration_ms,
        "cost_event_ref": "none",
        "sanitized_summary": sanitized_summary,
        "error_class": error_class,
        "retry_after_ms": retry_after_ms,
        "rollback_note": "No mutation performed by phase1 gateway.",
        "evidence_ref": evidence_ref,
    }


def post_audit_event(request: ToolRequest, result: dict[str, object]) -> dict[str, object] | None:
    base_url = os.getenv("AGENT_API_INTERNAL_URL", "http://agent-api:8000").rstrip("/")
    service_token = os.getenv("AGENT_API_AUTH_TOKEN", "")
    payload = {
        "tool_request_id": request.tool_request_id,
        "run_id": request.run_id,
        "session_id": request.session_id,
        "trace_id": request.trace_id,
        "agent_role": request.agent_role,
        "toolset": request.toolset,
        "capability": request.capability,
        "status": result["status"],
        "error_class": result["error_class"],
        "sanitized_summary": result["sanitized_summary"],
        "evidence_ref": result["evidence_ref"],
        "result_ref": result["result_ref"],
        "duration_ms": result["duration_ms"],
        "retry_after_ms": result["retry_after_ms"],
        "audit_tags": request.audit_tags,
    }
    for field in (
        "write_phase",
        "write_path",
        "branch_ref",
        "write_result",
        "content_sha256",
        "live_mcp_write",
        "rollback_performed",
        "secret_output",
    ):
        if field in result:
            payload[field] = result[field]
    http_request = urllib.request.Request(
        f"{base_url}/internal/audit/mcp-tool-events",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-Superbrain-Agent-Token": service_token,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(http_request, timeout=2) as response:
            return json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None


async def audited_result(request: ToolRequest, result: dict[str, object]) -> dict[str, object]:
    audit_event = await asyncio.to_thread(post_audit_event, request, result)
    if not audit_event:
        return {**result, "audit_persisted": False}
    return {
        **result,
        "audit_event_id": audit_event["event_id"],
        "audit_event_severity": audit_event["severity"],
        "audit_persisted": True,
    }


def forbidden_scope(request: ToolRequest) -> str | None:
    scope = request.allowed_scope.lower()
    capability = request.capability.lower()
    if request.toolset == "github" and ("main" in scope or "merge" in capability or "force" in capability):
        return "github_scope_violation"
    if request.toolset == "filesystem" and not scope.startswith("/tmp/agent-workspace"):
        return "filesystem_scope_violation"
    if request.toolset == "postgresql" and any(token in capability for token in ["insert", "update", "delete", "migrate", "write"]):
        return "postgres_write_violation"
    if request.toolset == "playwright" and ("file://" in scope or "169.254.169.254" in scope):
        return "playwright_browser_scope_violation"
    return None


@app.get("/api/v1/health")
def health() -> dict[str, object]:
    return {
        "status": "healthy",
        "service": "mcp-gateway",
        "time": datetime.now(timezone.utc).isoformat(),
        "toolsets": {
            "github": bool(os.getenv("GITHUB_TOKEN")),
            "e2b": bool(os.getenv("E2B_API_KEY")),
            "filesystem_root": os.getenv("FILESYSTEM_ROOT", "/tmp/agent-workspace"),
            "postgres_readonly": False,
            "playwright": True,
        },
    }


@app.get("/api/v1/github/branch-pr/contract")
def github_branch_pr_contract_endpoint() -> dict[str, object]:
    return github_branch_pr_contract()


@app.get("/api/v1/postgresql/readonly-query/contract")
def postgresql_readonly_query_contract_endpoint() -> dict[str, object]:
    return postgresql_readonly_query_contract()


@app.get("/api/v1/filesystem/workspace-scope/contract")
def filesystem_workspace_scope_contract_endpoint() -> dict[str, object]:
    return filesystem_workspace_scope_contract()


@app.get("/api/v1/filesystem/project-progress/contract")
def filesystem_project_progress_contract_endpoint() -> dict[str, object]:
    return filesystem_project_progress_contract()


@app.get("/internal/v1/filesystem/project-progress")
def filesystem_project_progress_read_endpoint(
    x_superbrain_agent_token: str | None = Header(default=None),
    x_trace_id: str | None = Header(default=None),
) -> dict[str, object]:
    return execute_filesystem_project_progress_read(x_superbrain_agent_token, x_trace_id)


@app.get("/api/v1/tools/live-write/probe/contract")
def o4_live_write_contract_endpoint() -> dict[str, object]:
    return o4_live_write_contract()


@app.post("/api/v1/tools/live-write/probe")
def o4_live_write_probe_endpoint(
    request: LiveWorkspaceWriteProbeRequest,
    x_superbrain_agent_token: str | None = Header(default=None),
) -> dict[str, object]:
    return execute_o4_live_write(request, x_superbrain_agent_token)


@app.get("/api/v1/playwright/browser-proof/contract")
def playwright_browser_proof_contract_endpoint() -> dict[str, object]:
    return playwright_browser_proof_contract()


@app.get("/api/v1/e2b/sandbox-lifecycle/contract")
def e2b_sandbox_lifecycle_contract_endpoint() -> dict[str, object]:
    return e2b_sandbox_lifecycle_contract()


@app.get("/api/v1/version-pinning/contract")
def mcp_version_pinning_contract_endpoint() -> dict[str, object]:
    return mcp_version_pinning_contract()


@app.post("/api/v1/tools/execute")
async def execute_tool(request: ToolRequest) -> dict[str, object]:
    started = time.perf_counter()
    if request.toolset == "github" and request.capability == "plan_branch_pr":
        return await audited_result(request, github_branch_pr_plan(request, started))
    if request.toolset == "postgresql" and request.capability == "query_readonly":
        return await audited_result(request, postgresql_readonly_query_plan(request, started))
    if request.toolset == "filesystem" and request.capability == "plan_workspace_access":
        return await audited_result(request, filesystem_workspace_scope_plan(request, started))
    if request.toolset == "playwright" and request.capability == "plan_browser_proof":
        return await audited_result(request, playwright_browser_proof_plan(request, started))
    if request.toolset == "e2b" and request.capability == "plan_sandbox_lifecycle":
        return await audited_result(request, e2b_sandbox_lifecycle_plan(request, started))

    violation = forbidden_scope(request)
    if violation:
        return await audited_result(
            request,
            envelope_result(
                request,
                status="blocked",
                sanitized_summary=f"Tool request blocked by scope guard: {violation}",
                error_class=violation,
                evidence_ref="mcp_scope_guard",
                started=started,
            ),
        )

    if request.capability == "simulate_timeout":
        sleep_seconds = (request.timeout_ms + 50) / 1000
        try:
            await asyncio.wait_for(asyncio.sleep(sleep_seconds), timeout=request.timeout_ms / 1000)
        except TimeoutError:
            return await audited_result(
                request,
                envelope_result(
                    request,
                    status="timeout",
                    sanitized_summary="Tool request exceeded timeout_ms and was aborted.",
                    error_class="timeout",
                    retry_after_ms=min(request.timeout_ms, 5_000),
                    evidence_ref="mcp_timeout_guard",
                    started=started,
                ),
            )
        raise HTTPException(status_code=500, detail="timeout simulation unexpectedly completed")

    if request.toolset == "e2b" and not os.getenv("E2B_API_KEY"):
        return await audited_result(
            request,
            envelope_result(
                request,
                status="degraded",
                sanitized_summary="E2B API key is not configured; sandbox execution remains disabled.",
                error_class="missing_credentials",
                retry_after_ms=0,
                evidence_ref="mcp_degraded_missing_e2b_credentials",
                started=started,
            ),
        )

    if request.toolset == "github" and request.capability.startswith("write") and not os.getenv("GITHUB_TOKEN"):
        return await audited_result(
            request,
            envelope_result(
                request,
                status="degraded",
                sanitized_summary="GitHub token is not configured; write capability remains disabled.",
                error_class="missing_credentials",
                retry_after_ms=0,
                evidence_ref="mcp_degraded_missing_github_credentials",
                started=started,
            ),
        )

    return await audited_result(
        request,
        envelope_result(
            request,
            status="success",
            sanitized_summary="Phase-1 safe read-only tool envelope accepted; no mutation performed.",
            evidence_ref="mcp_safe_envelope",
            started=started,
        ),
    )
