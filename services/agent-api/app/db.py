from __future__ import annotations

import json
import os
from pathlib import Path
from datetime import datetime, timezone

import httpx
import psycopg
import redis

MIGRATIONS_DIR = Path(__file__).resolve().parent / "migrations"


def database_url() -> str:
    value = os.getenv("DATABASE_URL")
    if not value:
        raise RuntimeError("DATABASE_URL is required")
    return value


def redis_url() -> str:
    return os.getenv("REDIS_URL", "redis://redis:6379/0")


def mcp_gateway_url() -> str:
    return os.getenv("MCP_GATEWAY_URL", "http://mcp-gateway:9000").rstrip("/")


def llm_gateway_url() -> str:
    return os.getenv("LLM_GATEWAY_URL", "http://llm-gateway:4000").rstrip("/")


def run_migrations() -> list[str]:
    applied: list[str] = []
    with psycopg.connect(database_url(), autocommit=True) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS schema_migrations (
              version TEXT PRIMARY KEY,
              applied_at TIMESTAMPTZ DEFAULT NOW()
            )
            """
        )
        for path in sorted(MIGRATIONS_DIR.glob("*.sql")):
            version = path.stem
            exists = conn.execute(
                "SELECT 1 FROM schema_migrations WHERE version = %s",
                (version,),
            ).fetchone()
            if exists:
                continue
            sql = path.read_text(encoding="utf-8")
            with conn.transaction():
                conn.execute(sql)
                conn.execute(
                    "INSERT INTO schema_migrations(version) VALUES (%s)",
                    (version,),
                )
            applied.append(version)
    return applied


def check_postgres() -> dict[str, object]:
    with psycopg.connect(database_url(), autocommit=True) as conn:
        row = conn.execute("SELECT current_database(), version()").fetchone()
        tables = conn.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name IN (
                'projects', 'agent_sessions', 'agent_messages',
                'memory_entries', 'cost_tracking', 'audit_log'
              )
            """
        ).fetchone()
        extensions = conn.execute(
            "SELECT extname FROM pg_extension WHERE extname IN ('vector', 'pgcrypto') ORDER BY extname"
        ).fetchall()
        checkpoint_tables = conn.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name IN (
                'checkpoint_migrations', 'checkpoints',
                'checkpoint_blobs', 'checkpoint_writes'
              )
            """
        ).fetchone()
    return {
        "status": "healthy",
        "database": row[0] if row else None,
        "required_tables": tables[0] if tables else 0,
        "checkpoint_tables": checkpoint_tables[0] if checkpoint_tables else 0,
        "extensions": [item[0] for item in extensions],
    }


def check_redis() -> dict[str, object]:
    client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2)
    pong = client.ping()
    return {"status": "healthy" if pong else "down"}


def check_memory_worker() -> dict[str, object]:
    client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2)
    raw_value = client.get(os.getenv("MEMORY_WORKER_HEARTBEAT_KEY", "memory-worker:heartbeat"))
    if not raw_value:
        return {"status": "down", "reason": "heartbeat_missing"}
    try:
        payload = json.loads(raw_value.decode("utf-8") if isinstance(raw_value, bytes) else str(raw_value))
    except json.JSONDecodeError:
        return {"status": "down", "reason": "heartbeat_invalid"}
    updated_at = str(payload.get("updated_at") or "")
    age_seconds: float | None = None
    if updated_at:
        try:
            updated = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
            age_seconds = (datetime.now(timezone.utc) - updated).total_seconds()
        except ValueError:
            age_seconds = None
    ttl = client.ttl(os.getenv("MEMORY_WORKER_HEARTBEAT_KEY", "memory-worker:heartbeat"))
    status = "healthy" if ttl and ttl > 0 else "down"
    return {
        "status": status,
        "service": payload.get("service", "memory-worker"),
        "heartbeat_ttl_seconds": int(ttl) if ttl is not None else None,
        "heartbeat_age_seconds": round(age_seconds, 3) if age_seconds is not None else None,
        "interval_seconds": payload.get("interval_seconds"),
        "ttl_threshold_seconds": payload.get("ttl_threshold_seconds"),
        "last_run": payload.get("last_run"),
    }


def check_agent_worker() -> dict[str, object]:
    client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2)
    key = os.getenv("AGENT_WORKER_HEARTBEAT_KEY", "agent-worker:heartbeat")
    raw_value = client.get(key)
    if not raw_value:
        return {"status": "down", "reason": "heartbeat_missing"}
    try:
        payload = json.loads(raw_value.decode("utf-8") if isinstance(raw_value, bytes) else str(raw_value))
    except json.JSONDecodeError:
        return {"status": "down", "reason": "heartbeat_invalid"}
    updated_at = str(payload.get("updated_at") or "")
    age_seconds: float | None = None
    if updated_at:
        try:
            updated = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
            age_seconds = (datetime.now(timezone.utc) - updated).total_seconds()
        except ValueError:
            age_seconds = None
    ttl = client.ttl(key)
    status = "healthy" if ttl and ttl > 0 else "down"
    return {
        "status": status,
        "service": payload.get("service", "agent-worker"),
        "worker_status": payload.get("worker_status"),
        "heartbeat_ttl_seconds": int(ttl) if ttl is not None else None,
        "heartbeat_age_seconds": round(age_seconds, 3) if age_seconds is not None else None,
        "queue": payload.get("queue"),
        "current_task_id": payload.get("current_task_id"),
        "last_event": payload.get("last_event"),
    }


def check_mcp() -> dict[str, object]:
    with httpx.Client(timeout=3) as client:
        response = client.get(f"{mcp_gateway_url()}/api/v1/health")
        response.raise_for_status()
        payload = response.json()
    return {"status": payload.get("status", "unknown"), "service": payload.get("service")}


def check_llm_gateway() -> dict[str, object]:
    with httpx.Client(timeout=3) as client:
        response = client.get(f"{llm_gateway_url()}/api/v1/health")
        response.raise_for_status()
        payload = response.json()
    return {
        "status": payload.get("status", "unknown"),
        "service": payload.get("service"),
        "mode": payload.get("mode"),
        "live_provider_calls": payload.get("live_provider_calls"),
        "openai_compatible": payload.get("openai_compatible"),
    }
