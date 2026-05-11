from __future__ import annotations

import json
import os
import signal
import sys
import time
from datetime import datetime, timezone
from typing import Any
from uuid import UUID

import psycopg
from psycopg.types.json import Json
import redis
from redis.exceptions import ConnectionError as RedisConnectionError
from redis.exceptions import TimeoutError as RedisTimeoutError
from pydantic import BaseModel, Field, ValidationError, field_validator

TASK_QUEUE_KEY = "tasks:agent:queue"
TASK_PRIORITY_QUEUES = {
    "high": "tasks:agent:queue:high",
    "mid": TASK_QUEUE_KEY,
    "low": "tasks:agent:queue:low",
}
TASK_QUEUE_KEYS_IN_PRIORITY_ORDER = tuple(TASK_PRIORITY_QUEUES[level] for level in ("high", "mid", "low"))
TASK_STATUS_PREFIX = "task:status:"
TASK_TTL_SECONDS = 60 * 60 * 24
STALE_QUEUED_RESCUE_AGE_SECONDS = int(os.getenv("STALE_QUEUED_RESCUE_AGE_SECONDS", "30"))

RUNNING = True


class TaskRecord(BaseModel):
    project_id: str = Field(..., min_length=1)
    session_id: str = Field(..., min_length=1)
    agent_type: str = Field(..., pattern="^(planner|coder|tester|devops)$")
    task_type: str = Field(..., min_length=1, max_length=120)
    task_description: str = Field(..., min_length=1, max_length=10_000)
    task_id: str
    status: str = "queued"
    created_at: str
    trace_id: str | None = None
    priority: int = Field(default=5, ge=1, le=10)
    max_retries: int = Field(default=5, ge=1, le=5)
    allowed_tools: list[str] = Field(default_factory=lambda: ["memory_read", "task_router"])
    write_scope: list[str] = Field(default_factory=list)
    blocked_actions: list[str] = Field(default_factory=list)
    acceptance_criteria: list[str] = Field(default_factory=lambda: ["result_envelope", "done_validation", "audit_log"])
    human_review_required: bool = True
    policy_version: str = "task-policy-v1"
    retry_count: int = Field(default=0, ge=0, le=5)
    updated_at: str | None = None
    result: str | None = None
    error: str | None = None
    result_envelope: dict[str, Any] | None = None
    done_validation: dict[str, bool] | None = None

    @field_validator("session_id")
    @classmethod
    def validate_session_uuid(cls, value: str) -> str:
        try:
            return str(UUID(value))
        except (TypeError, ValueError) as exc:
            raise ValueError("session_id must be a valid UUID") from exc


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def database_url() -> str:
    return os.environ["DATABASE_URL"]


def redis_url() -> str:
    return os.environ["REDIS_URL"]


def heartbeat_key() -> str:
    return os.getenv("AGENT_WORKER_HEARTBEAT_KEY", "agent-worker:heartbeat")


def heartbeat_ttl_seconds() -> int:
    return int(os.getenv("AGENT_WORKER_HEARTBEAT_TTL_SECONDS", "30"))


def redis_client() -> redis.Redis:
    return redis.Redis.from_url(redis_url(), socket_timeout=15, socket_connect_timeout=5, decode_responses=True)


def write_heartbeat(
    client: redis.Redis,
    worker_status: str,
    current_task_id: str | None = None,
    last_event: str | None = None,
) -> None:
    payload = {
        "service": "agent-worker",
        "worker_status": worker_status,
        "updated_at": utc_now(),
        "queue": TASK_QUEUE_KEY,
        "priority_queues": TASK_PRIORITY_QUEUES,
        "priority_order": list(TASK_PRIORITY_QUEUES.keys()),
        "current_task_id": current_task_id,
        "last_event": last_event,
        "ttl_seconds": heartbeat_ttl_seconds(),
    }
    client.set(heartbeat_key(), json.dumps(payload, separators=(",", ":")), ex=heartbeat_ttl_seconds())


def status_payload(
    task: TaskRecord,
    status: str,
    result: str | None = None,
    error: str | None = None,
    result_envelope: dict[str, Any] | None = None,
    done_validation: dict[str, bool] | None = None,
) -> str:
    payload: dict[str, Any] = task.model_dump()
    payload["status"] = status
    payload["updated_at"] = utc_now()
    if result is not None:
        payload["result"] = result
    if error is not None:
        payload["error"] = error
    if result_envelope is not None:
        payload["result_envelope"] = result_envelope
    if done_validation is not None:
        payload["done_validation"] = done_validation
    return json.dumps(payload, separators=(",", ":"))


def set_status(
    client: redis.Redis,
    task: TaskRecord,
    status: str,
    result: str | None = None,
    error: str | None = None,
    result_envelope: dict[str, Any] | None = None,
    done_validation: dict[str, bool] | None = None,
) -> None:
    client.set(
        TASK_STATUS_PREFIX + task.task_id,
        status_payload(task, status, result, error, result_envelope, done_validation),
        ex=TASK_TTL_SECONDS,
    )


def deterministic_agent_result(task: TaskRecord) -> str:
    return (
        f"{task.agent_type.title()} accepted task '{task.task_type}' for project "
        f"'{task.project_id}'. Phase-1 worker completed deterministic execution without LLM calls."
    )


def build_result_envelope(task: TaskRecord, result: str) -> dict[str, Any]:
    return {
        "agent_id": task.agent_type,
        "role": task.agent_type,
        "task_id": task.task_id,
        "status": "completed",
        "summary": result,
        "artifacts": [
            {
                "type": "runtime-record",
                "path": "postgres://agent_messages",
                "description": "Deterministic Phase-1 worker persisted assistant result.",
            },
            {
                "type": "audit-log",
                "path": "postgres://audit_log",
                "description": "Completion event persisted with task metadata.",
            },
        ],
        "evidence_refs": ["agent-worker:deterministic-completion", "audit_log:task_completed"],
        "memory_write": {
            "allowed": True,
            "classification": "test_artifact",
            "content_summary": "Phase-1 deterministic worker result without secrets or live LLM calls.",
        },
        "task_policy": {
            "policy_version": task.policy_version,
            "allowed_tools": task.allowed_tools,
            "write_scope": task.write_scope,
            "blocked_actions": task.blocked_actions,
            "acceptance_criteria": task.acceptance_criteria,
            "human_review_required": task.human_review_required,
        },
        "cost_event_ref": None,
        "uncertainties": ["Live LLM execution is not active in Phase 1."],
        "blocked_by": [],
        "next_safe_action": "Route through LangGraph Agent-Executor once live provider gates are configured.",
        "rollback_note": "Delete the task Redis status and associated audit/message rows for this task_id.",
    }


def done_validation_for_envelope(envelope: dict[str, Any]) -> dict[str, bool]:
    return {
        "implemented": bool(envelope.get("summary")),
        "tested": "agent-worker:deterministic-completion" in envelope.get("evidence_refs", []),
        "integrated": bool(envelope.get("artifacts")),
        "reported": envelope.get("status") == "completed",
        "logged": "audit_log:task_completed" in envelope.get("evidence_refs", []),
    }


def validated_session_id(task: TaskRecord) -> str:
    return str(UUID(task.session_id))


def persist_completion(task: TaskRecord, result: str, result_envelope: dict[str, Any], done_validation: dict[str, bool]) -> None:
    session_id = validated_session_id(task)
    trace_id = task.trace_id or session_id
    metadata = {
        "task_id": task.task_id,
        "task_type": task.task_type,
        "worker": "agent-worker",
        "trace_id": trace_id,
        "llm_calls": 0,
        "result_envelope": result_envelope,
        "done_validation": done_validation,
    }
    with psycopg.connect(database_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO agent_messages (
                  session_id, agent_type, role, content_short, token_count, trace_id, metadata
                )
                VALUES (%s, %s, 'assistant', %s, 0, %s, %s)
                """,
                (session_id, task.agent_type, result, trace_id, Json(metadata)),
            )
            cur.execute(
                """
                INSERT INTO audit_log (event_type, user_id, session_id, details, severity)
                VALUES ('task_completed', NULL, %s, %s, 'info')
                """,
                (session_id, Json(metadata | {"agent_type": task.agent_type})),
            )
            cur.execute(
                """
                UPDATE agent_sessions
                SET metadata = metadata || %s::jsonb
                WHERE id = %s
                """,
                (Json({"latest_worker_task_id": task.task_id, "latest_worker_result": result}), session_id),
            )
        conn.commit()


def persist_failure(task: TaskRecord, error: str) -> None:
    try:
        session_id: str | None = str(UUID(task.session_id))
    except ValueError:
        session_id = None
    trace_id = task.trace_id or session_id
    details = {
        "task_id": task.task_id,
        "task_type": task.task_type,
        "agent_type": task.agent_type,
        "worker": "agent-worker",
        "trace_id": trace_id,
        "error": error,
    }
    with psycopg.connect(database_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO audit_log (event_type, user_id, session_id, details, severity)
                VALUES ('task_failed', NULL, %s, %s, 'warning')
                """,
                (session_id, Json(details)),
            )
        conn.commit()


def persist_retry(task: TaskRecord, error: str, next_retry_count: int) -> None:
    try:
        session_id: str | None = str(UUID(task.session_id))
    except ValueError:
        session_id = None
    details = {
        "task_id": task.task_id,
        "task_type": task.task_type,
        "agent_type": task.agent_type,
        "worker": "agent-worker",
        "error": error,
        "retry_count": next_retry_count,
        "max_retries": task.max_retries,
    }
    with psycopg.connect(database_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO audit_log (event_type, user_id, session_id, details, severity)
                VALUES ('task_retry', NULL, %s, %s, 'warning')
                """,
                (session_id, Json(details)),
            )
        conn.commit()


def persist_escalation(task: TaskRecord, error: str) -> None:
    try:
        session_id: str | None = str(UUID(task.session_id))
    except ValueError:
        session_id = None
    details = {
        "task_id": task.task_id,
        "task_type": task.task_type,
        "agent_type": task.agent_type,
        "worker": "agent-worker",
        "error": error,
        "retry_count": task.retry_count,
        "max_retries": task.max_retries,
        "status": "escalated",
    }
    with psycopg.connect(database_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO audit_log (event_type, user_id, session_id, details, severity)
                VALUES ('task_escalated', NULL, %s, %s, 'critical')
                """,
                (session_id, Json(details)),
            )
        conn.commit()


def persist_abandoned_after_queue_drain(task: TaskRecord, error: str) -> None:
    try:
        session_id: str | None = str(UUID(task.session_id))
    except ValueError:
        session_id = None
    details = {
        "task_id": task.task_id,
        "task_type": task.task_type,
        "agent_type": task.agent_type,
        "worker": "agent-worker",
        "status": "abandoned_after_queue_drain",
        "error": error,
        "rescue_age_seconds": STALE_QUEUED_RESCUE_AGE_SECONDS,
        "evidence_ref": "worker_stale_queued_finalized",
    }
    with psycopg.connect(database_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO audit_log (event_type, user_id, session_id, details, severity)
                VALUES ('task_abandoned_after_queue_drain', NULL, %s, %s, 'warning')
                """,
                (session_id, Json(details)),
            )
        conn.commit()


def completed_task_audit(task: TaskRecord) -> tuple[str, dict[str, Any], dict[str, bool]] | None:
    try:
        session_id = validated_session_id(task)
    except ValueError:
        return None
    with psycopg.connect(database_url()) as conn:
        row = conn.execute(
            """
            SELECT details
            FROM audit_log
            WHERE event_type = 'task_completed'
              AND session_id = %s
              AND details->>'task_id' = %s
            ORDER BY created_at DESC
            LIMIT 1
            """,
            (session_id, task.task_id),
        ).fetchone()
    if not row:
        return None
    details = dict(row[0] or {})
    result_envelope = details.get("result_envelope")
    done_validation = details.get("done_validation")
    if not isinstance(result_envelope, dict) or not isinstance(done_validation, dict):
        return None
    result = str(result_envelope.get("summary") or task.result or deterministic_agent_result(task))
    return result, result_envelope, {key: bool(value) for key, value in done_validation.items()}


def persist_status_rehydrated_from_audit(task: TaskRecord) -> None:
    session_id = validated_session_id(task)
    details = {
        "task_id": task.task_id,
        "task_type": task.task_type,
        "agent_type": task.agent_type,
        "worker": "agent-worker",
        "status": "completed",
        "evidence_ref": "worker_status_rehydrated_from_completed_audit",
    }
    with psycopg.connect(database_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO audit_log (event_type, user_id, session_id, details, severity)
                VALUES ('task_status_rehydrated_from_audit', NULL, %s, %s, 'info')
                """,
                (session_id, Json(details)),
            )
        conn.commit()


def queued_task_ids(client: redis.Redis) -> set[str]:
    task_ids: set[str] = set()
    for queue_key in TASK_QUEUE_KEYS_IN_PRIORITY_ORDER:
        for raw_payload in client.lrange(queue_key, 0, -1):
            try:
                task_ids.add(TaskRecord.model_validate_json(raw_payload).task_id)
            except ValueError:
                continue
    return task_ids


def is_stale_queued_task(task: TaskRecord) -> bool:
    if task.status != "queued":
        return False
    created_at = parse_datetime(task.updated_at or task.created_at)
    if created_at is None:
        return False
    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    age_seconds = (datetime.now(timezone.utc) - created_at).total_seconds()
    return age_seconds >= STALE_QUEUED_RESCUE_AGE_SECONDS


def finalize_stale_queued_tasks(client: redis.Redis) -> int:
    queued_ids = queued_task_ids(client)
    finalized_count = 0
    for key in client.scan_iter(match=f"{TASK_STATUS_PREFIX}*", count=1000):
        payload = client.get(key)
        if not payload:
            continue
        try:
            task = TaskRecord.model_validate_json(payload)
        except ValueError:
            continue
        if task.task_id in queued_ids or not is_stale_queued_task(task):
            continue
        completed_audit = completed_task_audit(task)
        if completed_audit is not None:
            result, result_envelope, done_validation = completed_audit
            set_status(
                client,
                task,
                "completed",
                result=result,
                result_envelope=result_envelope,
                done_validation=done_validation,
            )
            try:
                persist_status_rehydrated_from_audit(task)
            except Exception as exc:  # pragma: no cover - defensive audit path
                print(
                    json.dumps(
                        {
                            "event": "task_status_rehydrate_audit_failed",
                            "task_id": task.task_id,
                            "error": f"{type(exc).__name__}: {exc}",
                        }
                    ),
                    flush=True,
                )
            finalized_count += 1
            print(
                json.dumps(
                    {
                        "event": "task_status_rehydrated_from_audit",
                        "task_id": task.task_id,
                        "agent_type": task.agent_type,
                    }
                ),
                flush=True,
            )
            continue
        error = "abandoned_after_queue_drain: queued status had no matching queue item after bounded rescue window"
        abandoned_task = task.model_copy(update={"status": "abandoned_after_queue_drain", "updated_at": utc_now(), "error": error})
        client.set(TASK_STATUS_PREFIX + abandoned_task.task_id, abandoned_task.model_dump_json(), ex=TASK_TTL_SECONDS)
        try:
            persist_abandoned_after_queue_drain(abandoned_task, error)
        except Exception as exc:  # pragma: no cover - defensive audit path
            print(
                json.dumps(
                    {
                        "event": "task_abandoned_audit_failed",
                        "task_id": abandoned_task.task_id,
                        "error": f"{type(exc).__name__}: {exc}",
                    }
                ),
                flush=True,
            )
        finalized_count += 1
        print(
            json.dumps(
                {
                    "event": "task_abandoned_after_queue_drain",
                    "task_id": abandoned_task.task_id,
                    "agent_type": abandoned_task.agent_type,
                }
            ),
            flush=True,
        )
    if finalized_count:
        write_heartbeat(client, "idle", None, "stale_queued_finalized")
    return finalized_count


def requeue_for_retry(client: redis.Redis, task: TaskRecord, error: str) -> None:
    next_retry_count = task.retry_count + 1
    retry_task = task.model_copy(update={"retry_count": next_retry_count, "status": "queued", "updated_at": utc_now(), "error": error})
    payload = retry_task.model_dump_json()
    client.set(TASK_STATUS_PREFIX + retry_task.task_id, payload, ex=TASK_TTL_SECONDS)
    client.rpush(priority_queue_key_for_task(retry_task), payload)
    persist_retry(retry_task, error, next_retry_count)
    write_heartbeat(client, "idle", retry_task.task_id, "task_retry")
    print(
        json.dumps(
            {
                "event": "task_retry",
                "task_id": retry_task.task_id,
                "retry_count": next_retry_count,
                "max_retries": retry_task.max_retries,
                "error": error,
            }
        ),
        flush=True,
    )


def priority_queue_key_for_task(task: TaskRecord) -> str:
    if task.priority >= 8:
        return TASK_PRIORITY_QUEUES["high"]
    if task.priority <= 3:
        return TASK_PRIORITY_QUEUES["low"]
    return TASK_PRIORITY_QUEUES["mid"]


def process_task(client: redis.Redis, raw_payload: str) -> None:
    try:
        task = TaskRecord.model_validate_json(raw_payload)
    except ValidationError as exc:
        write_heartbeat(client, "idle", None, "task_payload_rejected")
        print(
            json.dumps(
                {
                    "event": "task_payload_rejected",
                    "error": str(exc),
                }
            ),
            flush=True,
        )
        return
    write_heartbeat(client, "running", task.task_id, "task_started")
    set_status(client, task, "running")
    try:
        result = deterministic_agent_result(task)
        result_envelope = build_result_envelope(task, result)
        done_validation = done_validation_for_envelope(result_envelope)
        if not all(done_validation.values()):
            raise RuntimeError(f"done validation failed: {done_validation}")
        persist_completion(task, result, result_envelope, done_validation)
        set_status(client, task, "completed", result=result, result_envelope=result_envelope, done_validation=done_validation)
        write_heartbeat(client, "idle", task.task_id, "task_completed")
        print(json.dumps({"event": "task_completed", "task_id": task.task_id, "agent_type": task.agent_type}), flush=True)
    except Exception as exc:  # pragma: no cover - defensive runtime path
        error = f"{type(exc).__name__}: {exc}"
        if task.retry_count < task.max_retries:
            requeue_for_retry(client, task, error)
            return
        set_status(client, task, "escalated", error=error)
        try:
            persist_failure(task, error)
            persist_escalation(task, error)
        finally:
            write_heartbeat(client, "idle", task.task_id, "task_escalated")
            print(
                json.dumps(
                    {
                        "event": "task_escalated",
                        "task_id": task.task_id,
                        "retry_count": task.retry_count,
                        "max_retries": task.max_retries,
                        "error": error,
                    }
                ),
                flush=True,
            )


def handle_signal(_signum: int, _frame: object) -> None:
    global RUNNING
    RUNNING = False


def main() -> int:
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)
    client = redis_client()
    finalized_count = finalize_stale_queued_tasks(client)
    write_heartbeat(client, "idle", None, "worker_started")
    print(
        json.dumps(
            {
                "event": "worker_started",
                "queue": TASK_QUEUE_KEY,
                "priority_queues": TASK_PRIORITY_QUEUES,
                "priority_order": list(TASK_PRIORITY_QUEUES.keys()),
                "stale_queued_finalized": finalized_count,
            }
        ),
        flush=True,
    )
    while RUNNING:
        try:
            item = client.blpop(TASK_QUEUE_KEYS_IN_PRIORITY_ORDER, timeout=5)
        except RedisTimeoutError:
            write_heartbeat(client, "idle", None, "redis_timeout")
            continue
        except RedisConnectionError as exc:
            print(json.dumps({"event": "redis_reconnect", "error": str(exc)}), flush=True)
            time.sleep(1)
            client = redis_client()
            try:
                write_heartbeat(client, "idle", None, "redis_reconnected")
            except RedisConnectionError:
                time.sleep(1)
            continue
        if not item:
            finalize_stale_queued_tasks(client)
            write_heartbeat(client, "idle", None, "idle")
            continue
        source_queue, raw_payload = item
        print(json.dumps({"event": "task_dequeued", "queue": source_queue}), flush=True)
        process_task(client, raw_payload)
        write_heartbeat(client, "idle", None, "ready")
    write_heartbeat(client, "stopped", None, "worker_stopped")
    print(json.dumps({"event": "worker_stopped"}), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
