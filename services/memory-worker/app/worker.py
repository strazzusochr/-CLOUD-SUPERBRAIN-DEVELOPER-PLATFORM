from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import uuid4

import psycopg
import redis
from psycopg.types.json import Json


SECRET_PATTERNS = [
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|secret|token)\s*[:=]\s*['\"][^'\"]{8,}['\"]"),
]


@dataclass(frozen=True)
class WorkingMemory:
    redis_key: str
    project_id: str
    session_id: str | None
    content_text: str
    metadata: dict[str, object]
    idempotency_key: str


def database_url() -> str:
    value = os.getenv("DATABASE_URL")
    if not value:
        raise RuntimeError("DATABASE_URL is required")
    return value


def redis_url() -> str:
    return os.getenv("REDIS_URL", "redis://redis:6379/0")


def interval_seconds() -> int:
    return int(os.getenv("MEMORY_CONSOLIDATION_INTERVAL_SECONDS", "300"))


def ttl_threshold_seconds() -> int:
    return int(os.getenv("MEMORY_CONSOLIDATION_TTL_THRESHOLD_SECONDS", "480"))


def working_memory_pattern() -> str:
    return os.getenv("WORKING_MEMORY_PATTERN", "memory:working:*")


def heartbeat_key() -> str:
    return os.getenv("MEMORY_WORKER_HEARTBEAT_KEY", "memory-worker:heartbeat")


def heartbeat_ttl_seconds() -> int:
    return max(interval_seconds() * 3, 30)


def write_heartbeat(redis_client: redis.Redis, status: str, stats: dict[str, int] | None = None) -> None:
    payload: dict[str, object] = {
        "service": "memory-worker",
        "status": status,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "interval_seconds": interval_seconds(),
        "ttl_threshold_seconds": ttl_threshold_seconds(),
        "working_memory_pattern": working_memory_pattern(),
    }
    if stats is not None:
        payload["last_run"] = stats
    redis_client.set(heartbeat_key(), json.dumps(payload, sort_keys=True), ex=heartbeat_ttl_seconds())


def contains_secret(text: str) -> bool:
    return any(pattern.search(text) for pattern in SECRET_PATTERNS)


def parse_working_memory(redis_key: str, raw_value: bytes) -> WorkingMemory | None:
    try:
        payload = json.loads(raw_value.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None

    project_id = str(payload.get("project_id") or "").strip()
    content_text = str(payload.get("content_text") or "").strip()
    if not project_id or not content_text:
        return None

    session_id_value = payload.get("session_id")
    session_id = str(session_id_value) if session_id_value else None
    metadata = payload.get("metadata") if isinstance(payload.get("metadata"), dict) else {}
    digest_source = json.dumps(
        {
            "project_id": project_id,
            "session_id": session_id,
            "content_text": content_text,
            "metadata": metadata,
        },
        sort_keys=True,
    )
    idempotency_key = str(payload.get("idempotency_key") or hashlib.sha256(digest_source.encode("utf-8")).hexdigest())
    return WorkingMemory(
        redis_key=redis_key,
        project_id=project_id,
        session_id=session_id,
        content_text=content_text,
        metadata=metadata,
        idempotency_key=idempotency_key,
    )


def find_or_create_project(conn: psycopg.Connection, project_id: str) -> str:
    row = conn.execute(
        "SELECT id FROM projects WHERE metadata->>'external_id' = %s LIMIT 1",
        (project_id,),
    ).fetchone()
    if row:
        return str(row[0])
    created = conn.execute(
        """
        INSERT INTO projects(name, owner_id, metadata)
        VALUES (%s, 'memory-worker', %s::jsonb)
        RETURNING id
        """,
        (project_id, Json({"external_id": project_id, "source": "memory_worker"})),
    ).fetchone()
    if not created:
        raise RuntimeError("project insert did not return id")
    return str(created[0])


def already_consolidated(conn: psycopg.Connection, idempotency_key: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM memory_entries WHERE metadata->>'idempotency_key' = %s LIMIT 1",
        (idempotency_key,),
    ).fetchone()
    return bool(row)


def audit_event(
    conn: psycopg.Connection,
    event_type: str,
    memory: WorkingMemory,
    severity: str,
    details: dict[str, object],
) -> None:
    conn.execute(
        """
        INSERT INTO audit_log(event_type, user_id, session_id, details, severity)
        VALUES (%s, 'memory-worker', %s, %s::jsonb, %s)
        """,
        (event_type, memory.session_id, Json(details), severity),
    )


def consolidate_one(conn: psycopg.Connection, memory: WorkingMemory, ttl: int) -> str:
    transaction_id = f"memory-tx:{uuid4()}"
    if contains_secret(memory.content_text):
        audit_event(
            conn,
            "memory_consolidation_blocked",
            memory,
            "critical",
            {
                "redis_key": memory.redis_key,
                "idempotency_key": memory.idempotency_key,
                "reason": "secret_pattern_detected",
                "ttl_seconds": ttl,
                "memory_transaction_id": transaction_id,
            },
        )
        return "blocked"

    if already_consolidated(conn, memory.idempotency_key):
        audit_event(
            conn,
            "memory_consolidation_skipped",
            memory,
            "info",
            {
                "redis_key": memory.redis_key,
                "idempotency_key": memory.idempotency_key,
                "reason": "duplicate_idempotency_key",
                "ttl_seconds": ttl,
                "memory_transaction_id": transaction_id,
            },
        )
        return "skipped"

    project_uuid = find_or_create_project(conn, memory.project_id)
    metadata = {
        **memory.metadata,
        "source": "redis_working_memory",
        "redis_key": memory.redis_key,
        "ttl_seconds_at_consolidation": ttl,
        "idempotency_key": memory.idempotency_key,
        "memory_transaction_id": transaction_id,
        "search_mode": "lexical_fallback",
    }
    row = conn.execute(
        """
        INSERT INTO memory_entries(
          project_id, session_id, content_text, relevance_score,
          consolidation_status, metadata
        )
        VALUES (%s, %s, %s, 1.0, 'consolidated', %s::jsonb)
        RETURNING id
        """,
        (project_uuid, memory.session_id, memory.content_text, Json(metadata)),
    ).fetchone()
    memory_id = str(row[0]) if row else "unknown"
    audit_event(
        conn,
        "memory_consolidated",
        memory,
        "info",
        {
            "memory_id": memory_id,
            "redis_key": memory.redis_key,
            "project_id": memory.project_id,
            "idempotency_key": memory.idempotency_key,
            "ttl_seconds": ttl,
            "memory_transaction_id": transaction_id,
        },
    )
    return "consolidated"


def run_once(force: bool = False) -> dict[str, int]:
    stats = {"scanned": 0, "eligible": 0, "consolidated": 0, "skipped": 0, "blocked": 0, "invalid": 0}
    redis_client = redis.Redis.from_url(redis_url(), socket_timeout=5, socket_connect_timeout=5)
    write_heartbeat(redis_client, "running")
    threshold = ttl_threshold_seconds()
    with psycopg.connect(database_url(), autocommit=True) as conn:
        for key in redis_client.scan_iter(match=working_memory_pattern(), count=100):
            redis_key = key.decode("utf-8") if isinstance(key, bytes) else str(key)
            stats["scanned"] += 1
            ttl = int(redis_client.ttl(key))
            if ttl < 0:
                continue
            if not force and ttl > threshold:
                continue
            raw_value = redis_client.get(key)
            if not raw_value:
                continue
            memory = parse_working_memory(redis_key, raw_value)
            if not memory:
                stats["invalid"] += 1
                continue
            stats["eligible"] += 1
            result = consolidate_one(conn, memory, ttl)
            stats[result] = stats.get(result, 0) + 1
            if result in {"consolidated", "skipped", "blocked"}:
                redis_client.delete(key)
    write_heartbeat(redis_client, "healthy", stats)
    return stats


def healthcheck() -> None:
    import sys
    try:
        r = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2)
        r.ping()
        psycopg.connect(database_url()).close()
        sys.exit(0)
    except Exception as exc:  # noqa: BLE001
        print(f"healthcheck failed: {exc}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Cloud Superbrain memory consolidation worker")
    parser.add_argument("--once", action="store_true", help="Run one consolidation pass then exit.")
    parser.add_argument("--force", action="store_true", help="Consolidate matching keys regardless of TTL.")
    parser.add_argument("--healthcheck", action="store_true", help="Probe Redis+PostgreSQL connectivity and exit 0/1.")
    args = parser.parse_args()

    if args.healthcheck:
        healthcheck()
        return

    if args.once:
        print(json.dumps(run_once(force=args.force), sort_keys=True))
        return

    while True:
        stats = run_once(force=False)
        print(json.dumps({"event": "memory_consolidation_tick", **stats}, sort_keys=True))
        time.sleep(interval_seconds())


if __name__ == "__main__":
    main()
