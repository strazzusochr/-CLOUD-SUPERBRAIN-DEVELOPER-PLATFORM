from __future__ import annotations

from datetime import datetime, timezone
import re
from uuid import UUID, uuid4

import redis
from pydantic import BaseModel, Field, field_validator

from app.db import redis_url
from app.models import AGENT_PROFILES, REQUIRED_BLOCKED_ACTIONS as PROFILE_REQUIRED_BLOCKED_ACTIONS
from app.security import redact_text

TASK_QUEUE_KEY = "tasks:agent:queue"
TASK_PRIORITY_QUEUES = {
    "high": "tasks:agent:queue:high",
    "mid": TASK_QUEUE_KEY,
    "low": "tasks:agent:queue:low",
}
TASK_PRIORITY_ORDER = ("high", "mid", "low")
TASK_STATUS_PREFIX = "task:status:"
TASK_TTL_SECONDS = 60 * 60 * 24
AUTONOMOUS_TEAM_DISPATCH_PREFIX = "team:autonomous:dispatch:"
AUTONOMOUS_TEAM_DISPATCH_INDEX_KEY = "team:autonomous:dispatch:index"
AUTONOMOUS_TEAM_TTL_SECONDS = TASK_TTL_SECONDS
AUTONOMOUS_TEAM_MODE = "logical_five_role_overlay_on_runtime_pool"
AUTONOMOUS_LOGICAL_ROLES = ("supervisor", "planner", "explorer", "coder", "tester")
PROFILE_BY_AGENT = {profile.agent_type: profile for profile in AGENT_PROFILES}
REQUIRED_BLOCKED_ACTIONS = set(PROFILE_REQUIRED_BLOCKED_ACTIONS)
ALLOWED_TOOL_NAMES = {
    tool
    for profile in AGENT_PROFILES
    for tool in profile.allowed_tools
}
WRITE_TOOL_NAMES = {"github_mcp", "filesystem_mcp"}
WRITE_KEYWORDS = {
    "code",
    "coder",
    "edit",
    "file",
    "fix",
    "implement",
    "implementation",
    "patch",
    "write",
}
DEPLOY_KEYWORDS = {"deploy", "deployment", "production", "prod"}


class TaskPolicyViolation(RuntimeError):
    def __init__(self, code: str, violations: list[str]):
        self.code = code
        self.violations = violations
        super().__init__("; ".join(violations))


class TaskAssignment(BaseModel):
    project_id: str = Field(..., min_length=1)
    session_id: str = Field(..., min_length=1)
    agent_type: str = Field(..., pattern="^(planner|coder|tester|devops)$")
    task_type: str = Field(..., min_length=1, max_length=120)
    task_description: str = Field(..., min_length=1, max_length=10_000)
    trace_id: str | None = None
    request_id: str | None = Field(default=None, max_length=255)
    dispatch_id: str | None = Field(default=None, max_length=120)
    logical_role: str | None = Field(default=None, pattern="^(supervisor|planner|explorer|coder|tester)$")
    provenance_evidence_ref: str | None = Field(default=None, max_length=160)
    priority: int = Field(default=5, ge=1, le=10)
    max_retries: int = Field(default=5, ge=1, le=5)
    allowed_tools: list[str] = Field(default_factory=lambda: ["memory_read", "task_router"])
    write_scope: list[str] = Field(default_factory=list)
    blocked_actions: list[str] = Field(default_factory=lambda: sorted(REQUIRED_BLOCKED_ACTIONS))
    acceptance_criteria: list[str] = Field(default_factory=lambda: ["result_envelope", "done_validation", "audit_log"])
    human_review_required: bool = True
    policy_version: str = "task-policy-v1"

    @field_validator("session_id")
    @classmethod
    def validate_session_uuid(cls, value: str) -> str:
        try:
            return str(UUID(value))
        except (TypeError, ValueError) as exc:
            raise ValueError("session_id must be a valid UUID") from exc


class TaskRecord(TaskAssignment):
    task_id: str
    status: str = "queued"
    created_at: str
    updated_at: str | None = None
    result: str | None = None
    error: str | None = None
    retry_count: int = 0
    result_envelope: dict | None = None
    done_validation: dict[str, bool] | None = None


class AutonomousRoleAssignment(BaseModel):
    dispatch_id: str | None = Field(default=None, max_length=120)
    logical_role: str = Field(..., pattern="^(supervisor|planner|explorer|coder|tester)$")
    execution_agent_type: str = Field(..., pattern="^(planner|coder|tester|devops)$")
    task_id: str
    task_type: str = Field(..., min_length=1, max_length=120)
    status: str = Field(
        default="queued",
        pattern="^(queued|running|completed|failed|escalated|abandoned_after_queue_drain)$",
    )
    priority: int = Field(default=5, ge=1, le=10)
    priority_level: str = Field(..., pattern="^(high|mid|low)$")
    priority_queue: str = Field(..., min_length=1)
    allowed_tools: list[str] = Field(default_factory=list)
    planned_capabilities: list[str] = Field(default_factory=list)
    write_scope: list[str] = Field(default_factory=list)
    acceptance_criteria: list[str] = Field(default_factory=list)
    human_review_required: bool = True
    blocked_actions: list[str] = Field(default_factory=list)
    evidence_ref: str = "autonomous_team_dispatch_visible"
    provenance_evidence_ref: str = "autonomous_team_dispatch_task_provenance"
    current_status_source: str = "task_queue"


class AutonomousDispatchRecord(BaseModel):
    dispatch_id: str
    project_id: str = Field(..., min_length=1)
    session_id: str = Field(..., min_length=1)
    objective: str = Field(..., min_length=1, max_length=10_000)
    trace_id: str | None = None
    request_id: str | None = None
    status: str = Field(
        default="queued",
        pattern="^(queued|active|completed|attention|failed)$",
    )
    created_at: str
    updated_at: str | None = None
    team_mode: str = AUTONOMOUS_TEAM_MODE
    dispatch_contract_version: str = "autonomous-task-dispatch-v1"
    team_contract_version: str = "autonomous-coding-team-v1"
    write_scope: list[str] = Field(default_factory=list)
    acceptance_criteria: list[str] = Field(default_factory=list)
    constraints: list[str] = Field(default_factory=list)
    assignments: list[AutonomousRoleAssignment] = Field(default_factory=list)
    non_claims: list[str] = Field(default_factory=list)

    @field_validator("session_id")
    @classmethod
    def validate_dispatch_session_uuid(cls, value: str) -> str:
        try:
            return str(UUID(value))
        except (TypeError, ValueError) as exc:
            raise ValueError("session_id must be a valid UUID") from exc


def task_policy_manifest() -> dict[str, object]:
    return {
        "policy_version": "task-policy-v1",
        "profile_contract_version": "agent-profiles-v1",
        "mode": "fail_closed_before_enqueue",
        "required_blocked_actions": sorted(REQUIRED_BLOCKED_ACTIONS),
        "allowed_tools": sorted(ALLOWED_TOOL_NAMES),
        "write_tools": sorted(WRITE_TOOL_NAMES),
        "profile_gates": [
            {
                "agent_type": profile.agent_type,
                "max_retries": profile.max_retries,
                "max_execution_seconds": profile.max_execution_seconds,
                "allowed_tools": list(profile.allowed_tools),
                "blocked_actions": list(profile.blocked_actions),
                "human_review_required_actions": list(profile.human_review_required_actions),
            }
            for profile in AGENT_PROFILES
        ],
        "write_scope_required_for": {
            "agent_type": "coder",
            "tools": sorted(WRITE_TOOL_NAMES),
            "keywords": sorted(WRITE_KEYWORDS),
        },
        "devops_human_gate": "required for deployment-like tasks",
    }


def text_contains_policy_keyword(text: str, keyword: str) -> bool:
    return re.search(rf"(?<![a-z0-9_]){re.escape(keyword)}(?![a-z0-9_])", text) is not None


def validate_task_policy(assignment: TaskAssignment) -> None:
    violations: list[str] = []
    profile = PROFILE_BY_AGENT.get(assignment.agent_type)
    if profile is None:
        violations.append(f"unknown agent profile: {assignment.agent_type}")
        raise TaskPolicyViolation("task_policy_violation", violations)

    unknown_tools = sorted(set(assignment.allowed_tools) - ALLOWED_TOOL_NAMES)
    if unknown_tools:
        violations.append(f"unknown tools are not allowed: {', '.join(unknown_tools)}")

    profile_tool_violations = sorted(set(assignment.allowed_tools) - set(profile.allowed_tools))
    if profile_tool_violations:
        violations.append(
            f"{assignment.agent_type} profile does not allow tools: {', '.join(profile_tool_violations)}"
        )

    if assignment.max_retries > profile.max_retries:
        violations.append(
            f"{assignment.agent_type} max_retries exceeds profile limit {profile.max_retries}"
        )

    missing_blocked_actions = sorted(REQUIRED_BLOCKED_ACTIONS - set(assignment.blocked_actions))
    if missing_blocked_actions:
        violations.append(f"missing required blocked actions: {', '.join(missing_blocked_actions)}")

    missing_profile_blocks = sorted(set(profile.blocked_actions) - set(assignment.blocked_actions))
    if missing_profile_blocks:
        violations.append(
            f"missing {assignment.agent_type} profile blocked actions: {', '.join(missing_profile_blocks)}"
        )

    text = f"{assignment.task_type} {assignment.task_description}".lower()
    has_write_tool = bool(set(assignment.allowed_tools) & WRITE_TOOL_NAMES)
    looks_like_write_task = any(text_contains_policy_keyword(text, keyword) for keyword in WRITE_KEYWORDS)
    if assignment.agent_type == "coder" and (has_write_tool or looks_like_write_task) and not assignment.write_scope:
        violations.append("coder write-like tasks require an explicit non-empty write_scope")

    looks_like_deploy_task = any(text_contains_policy_keyword(text, keyword) for keyword in DEPLOY_KEYWORDS)
    if assignment.agent_type == "devops" and looks_like_deploy_task and not assignment.human_review_required:
        violations.append("devops deployment-like tasks require human_review_required=true")

    if looks_like_deploy_task and assignment.agent_type != "devops":
        violations.append("deployment-like tasks must be routed to devops profile")

    if looks_like_deploy_task and not set(profile.human_review_required_actions):
        violations.append(f"{assignment.agent_type} profile has no human-review actions for deployment-like task")

    if "audit_log" not in assignment.acceptance_criteria:
        violations.append("acceptance_criteria must include audit_log")
    if "result_envelope" not in assignment.acceptance_criteria:
        violations.append("acceptance_criteria must include result_envelope")
    if "done_validation" not in assignment.acceptance_criteria:
        violations.append("acceptance_criteria must include done_validation")

    if violations:
        raise TaskPolicyViolation("task_policy_violation", violations)


def redis_client() -> redis.Redis:
    return redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2, decode_responses=True)


def priority_level_for_value(priority: int) -> str:
    if priority >= 8:
        return "high"
    if priority <= 3:
        return "low"
    return "mid"


def priority_queue_key_for_value(priority: int) -> str:
    return TASK_PRIORITY_QUEUES[priority_level_for_value(priority)]


def enqueue_task(assignment: TaskAssignment) -> TaskRecord:
    assignment = assignment.model_copy(update={"task_description": redact_text(assignment.task_description)})
    validate_task_policy(assignment)
    record = TaskRecord(
        **assignment.model_dump(),
        task_id=str(uuid4()),
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    client = redis_client()
    payload = record.model_dump_json()
    status_key = TASK_STATUS_PREFIX + record.task_id
    client.set(status_key, payload, ex=TASK_TTL_SECONDS)
    client.rpush(priority_queue_key_for_value(record.priority), payload)
    
    return record


def get_task(task_id: str) -> TaskRecord | None:
    payload = redis_client().get(TASK_STATUS_PREFIX + task_id)
    if not payload:
        return None
    return TaskRecord.model_validate_json(payload)


def list_recent_tasks(limit: int = 100) -> list[TaskRecord]:
    client = redis_client()
    keys = list(client.scan_iter(match=f"{TASK_STATUS_PREFIX}*", count=1000))
    if not keys:
        return []

    records: list[TaskRecord] = []
    for index in range(0, len(keys), 1000):
        for payload in client.mget(keys[index : index + 1000]):
            if not payload:
                continue
            try:
                records.append(TaskRecord.model_validate_json(payload))
            except ValueError:
                continue
    sorted_records = sorted(records, key=lambda item: item.updated_at or item.created_at, reverse=True)
    return sorted_records[:limit]


def queue_depth() -> int:
    client = redis_client()
    return sum(int(client.llen(queue_key)) for queue_key in set(TASK_PRIORITY_QUEUES.values()))


def queue_depth_by_priority() -> dict[str, int]:
    client = redis_client()
    return {
        priority_level: int(client.llen(queue_key))
        for priority_level, queue_key in TASK_PRIORITY_QUEUES.items()
    }


def autonomous_dispatch_key(dispatch_id: str) -> str:
    return AUTONOMOUS_TEAM_DISPATCH_PREFIX + dispatch_id


def autonomous_dispatch_status(assignments: list[AutonomousRoleAssignment]) -> str:
    statuses = {assignment.status for assignment in assignments}
    if statuses & {"failed"}:
        return "failed"
    if statuses & {"escalated", "abandoned_after_queue_drain"}:
        return "attention"
    if statuses and statuses <= {"completed"}:
        return "completed"
    if statuses & {"running"}:
        return "active"
    return "queued"


def store_autonomous_dispatch(record: AutonomousDispatchRecord) -> AutonomousDispatchRecord:
    client = redis_client()
    payload = record.model_dump_json()
    client.set(autonomous_dispatch_key(record.dispatch_id), payload, ex=AUTONOMOUS_TEAM_TTL_SECONDS)
    client.lpush(AUTONOMOUS_TEAM_DISPATCH_INDEX_KEY, record.dispatch_id)
    client.ltrim(AUTONOMOUS_TEAM_DISPATCH_INDEX_KEY, 0, 199)
    return record


def get_autonomous_dispatch(dispatch_id: str) -> AutonomousDispatchRecord | None:
    payload = redis_client().get(autonomous_dispatch_key(dispatch_id))
    if not payload:
        return None
    return AutonomousDispatchRecord.model_validate_json(payload)


def list_recent_autonomous_dispatches(limit: int = 20) -> list[AutonomousDispatchRecord]:
    client = redis_client()
    dispatch_ids = client.lrange(AUTONOMOUS_TEAM_DISPATCH_INDEX_KEY, 0, max(limit * 5, limit) - 1)
    records: list[AutonomousDispatchRecord] = []
    for dispatch_id in dispatch_ids:
        payload = client.get(autonomous_dispatch_key(dispatch_id))
        if not payload:
            continue
        try:
            records.append(AutonomousDispatchRecord.model_validate_json(payload))
        except ValueError:
            continue
    return records[:limit]
