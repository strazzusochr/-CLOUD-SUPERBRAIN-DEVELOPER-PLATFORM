# Local backend runtime evidence (2026-06-05) — docker-compose.dev (dry-run, no secrets)

## /api/v1/health
{
    "status": "healthy",
    "service": "agent-api",
    "time": "2026-06-05T12:20:46.592635+00:00",
    "applied_migrations": [],
    "services": {
        "postgres": {
            "status": "healthy",
            "database": "superbrain_prod",
            "required_tables": 6,
            "checkpoint_tables": 4,
            "extensions": [
                "pgcrypto",
                "vector"
            ]
        },
        "redis": {
            "status": "healthy"
        },
        "agent_worker": {
            "status": "healthy",
            "reason": null,
            "service": "agent-worker",
            "worker_status": "idle",
            "heartbeat_key": "agent-worker:heartbeat",
            "heartbeat_ttl_seconds": 29,
            "heartbeat_age_seconds": 1.123,
            "max_heartbeat_age_seconds": 30,
            "stale_heartbeat": false,
            "queue": "tasks:agent:queue",
            "current_task_id": null,
            "last_event": "idle"
        },
        "memory_worker": {
            "status": "down",
            "reason": "heartbeat_missing",
            "heartbeat_key": "memory-worker:heartbeat"
        },
        "mcp_gateway": {
            "status": "healthy",

## /api/v1/clouds/layers (cloud-layer-readiness-v1)
- layer_1: Frontend / Next.js -> live_verified
- layer_2: Orchestrator / LangGraph -> live_verified
- layer_3: Agent Pool -> live_verified
- layer_4: LLM Gateway -> live_verified
- layer_5: MCP Gateway / Tools -> live_verified
- layer_6: Memory / PostgreSQL pgvector -> live_verified
- layer_7: Observability / Evidence -> live_verified
