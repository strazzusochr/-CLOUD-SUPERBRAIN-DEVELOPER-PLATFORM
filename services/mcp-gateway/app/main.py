from __future__ import annotations

import asyncio
import json
import os
import posixpath
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from uuid import UUID, uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, field_validator

MCP_GATEWAY_VERSION = "0.1.0"
MCP_VERSION_PINNING_CONTRACT_VERSION = "mcp-version-pinning-v1"
MCP_VERSION_PINNING_EVIDENCE_REF = "mcp_version_pinning_contract_visible"
MCP_REDACTION_EVIDENCE_REF = "mcp_secret_redaction_guard"
MCP_UNSUPPORTED_TOOLSET_EVIDENCE_REF = "mcp_unsupported_toolset_guard"
MCP_UNSUPPORTED_CAPABILITY_EVIDENCE_REF = "mcp_unsupported_capability_guard"
MCP_DENIED_AUDIT_CORRELATION_EVIDENCE_REF = "mcp_denied_tool_audit_correlation"

app = FastAPI(title="Cloud Superbrain MCP Gateway", version=MCP_GATEWAY_VERSION)


class ToolRequest(BaseModel):
    tool_request_id: str = Field(..., min_length=1, max_length=120)
    run_id: str = Field(..., min_length=1, max_length=120)
    session_id: str | None = Field(default=None, max_length=120)
    trace_id: str | None = Field(default=None, max_length=255)
    request_id: str | None = Field(default=None, max_length=255)
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

PLAYWRIGHT_ALLOWED_ACTIONS = ("navigate_to_url", "take_screenshot", "extract_text", "close_browser")
PLAYWRIGHT_FORBIDDEN_SCHEMES = ("file", "ftp", "data", "javascript")
PLAYWRIGHT_FORBIDDEN_HOSTS = ("169.254.169.254", "metadata.google.internal", "metadata.azure.internal")
PLAYWRIGHT_ALLOWED_LOCAL_TARGETS = ("localhost:8081", "127.0.0.1:8081")

E2B_ALLOWED_ACTIONS = ("create_sandbox", "execute_code", "read_output", "close_sandbox")
E2B_ALLOWED_SCOPES = ("sandbox:test", "sandbox:ephemeral")
E2B_FORBIDDEN_TOKENS = ("production", "secret", "private_key", "sudo", "privileged", "crypto_mining", "network_scan")
E2B_MAX_SESSION_TIMEOUT_MS = 1_800_000
SUPPORTED_CAPABILITIES = {
    "github": {"plan_branch_pr"},
    "postgresql": {"query_readonly"},
    "filesystem": {"plan_workspace_access"},
    "playwright": {"plan_browser_proof"},
    "e2b": {"plan_sandbox_lifecycle", "simulate_timeout"},
    "puppeteer": set(),
}
SECRET_REDACTION_PATTERNS = (
    (re.compile(r"\bsk-[A-Za-z0-9_-]{12,}\b"), "[REDACTED_OPENAI_KEY]"),
    (re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"), "[REDACTED_GITHUB_TOKEN]"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{12,}\b"), "[REDACTED_GITHUB_TOKEN]"),
    (re.compile(r"\bvck_[A-Za-z0-9_-]{12,}\b"), "[REDACTED_VERCEL_TOKEN]"),
    (re.compile(r"\b(cf|hcloud)_[A-Za-z0-9_-]{12,}\b", re.IGNORECASE), "[REDACTED_CLOUD_TOKEN]"),
    (re.compile(r"(?i)\b(bearer|token|secret|password|api[_-]?key)\s*[:=]\s*['\"]?[^'\"\s]{8,}"), r"\1=[REDACTED_SECRET]"),
)


def redact_sensitive_text(value: str) -> str:
    redacted = value
    for pattern, replacement in SECRET_REDACTION_PATTERNS:
        redacted = pattern.sub(replacement, redacted)
    return redacted


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
            "runtime": "python:3.12-slim",
            "requirements_file": "services/mcp-gateway/requirements.txt",
            "dependency_pin_policy": "exact_version_required",
        },
        "pinned_dependencies": [
            {"name": "fastapi", "version": "0.115.8", "pin": "fastapi==0.115.8"},
            {"name": "uvicorn[standard]", "version": "0.34.0", "pin": "uvicorn[standard]==0.34.0"},
            {"name": "pydantic", "version": "2.10.6", "pin": "pydantic==2.10.6"},
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
            "unsupported_toolsets_blocked": ["puppeteer"],
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
            "Placeholder toolsets without a concrete contract, such as puppeteer, return a blocked envelope.",
            "Live mutations remain disabled until a separate external gate and human review are configured.",
        ],
        "evidence_refs": [
            MCP_VERSION_PINNING_EVIDENCE_REF,
            "mcp_safe_envelope",
            "mcp_scope_guard",
            "mcp_timeout_guard",
            "mcp_tool_session_bound_audit",
            MCP_DENIED_AUDIT_CORRELATION_EVIDENCE_REF,
            MCP_UNSUPPORTED_TOOLSET_EVIDENCE_REF,
            MCP_UNSUPPORTED_CAPABILITY_EVIDENCE_REF,
            MCP_REDACTION_EVIDENCE_REF,
        ],
        "capability_guard": {
            "mode": "fail_closed_unknown_capability",
            "supported_capabilities": {key: sorted(value) for key, value in SUPPORTED_CAPABILITIES.items()},
            "evidence_ref": MCP_UNSUPPORTED_CAPABILITY_EVIDENCE_REF,
        },
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
    raw_title = str(payload.get("title") or "Agent generated change proposal").strip()
    base = str(payload.get("base") or "main").strip()
    raw_body = str(payload.get("body") or "Dry-run PR plan generated by MCP gateway.").strip()
    title = redact_sensitive_text(raw_title)
    body = redact_sensitive_text(raw_body)
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
        "redaction": {
            "required": request.redaction_required,
            "applied": title != raw_title or body != raw_body,
            "evidence_ref": MCP_REDACTION_EVIDENCE_REF,
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
            "secret-like values in generated branch/PR payloads are redacted before output.",
        ],
        "forbidden_capabilities": ["merge_pull_request", "force_push", "delete_branch", "admin_operations"],
        "evidence_refs": {
            "accepted": "github_branch_pr_plan",
            "blocked": "github_branch_pr_policy",
            "redaction": MCP_REDACTION_EVIDENCE_REF,
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
    payload = {
        "tool_request_id": request.tool_request_id,
        "run_id": request.run_id,
        "session_id": request.session_id,
        "trace_id": request.trace_id,
        "request_id": request.request_id,
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
    http_request = urllib.request.Request(
        f"{base_url}/internal/audit/mcp-tool-events",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
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


def unsupported_capability(request: ToolRequest) -> bool:
    return request.capability not in SUPPORTED_CAPABILITIES.get(request.toolset, set())


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
    if request.toolset == "puppeteer":
        return await audited_result(
            request,
            envelope_result(
                request,
                status="blocked",
                sanitized_summary="Puppeteer toolset is not wired to a contract and remains blocked.",
                error_class="unsupported_toolset",
                evidence_ref=MCP_UNSUPPORTED_TOOLSET_EVIDENCE_REF,
                started=started,
            ),
        )
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

    if unsupported_capability(request):
        return await audited_result(
            request,
            envelope_result(
                request,
                status="blocked",
                sanitized_summary=(
                    f"MCP capability '{request.capability}' is not wired to a contract for toolset '{request.toolset}'."
                ),
                error_class="unsupported_capability",
                evidence_ref=MCP_UNSUPPORTED_CAPABILITY_EVIDENCE_REF,
                started=started,
            ),
        )

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
