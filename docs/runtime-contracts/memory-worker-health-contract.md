# Memory Worker Health Contract

Status: DEV-ONLY local contract. Hosted parity is not claimed by this slice.

Endpoint: `GET /api/v1/memory/worker-health/contract`

Contract version: `memory-worker-health-contract-v1`

Evidence ref: `memory_worker_health_contract_visible`

## Purpose

This contract hardens Memory layer readiness by separating the memory worker's real heartbeat freshness from dependency-only PostgreSQL and Redis pings.

## Runtime Rules

- Heartbeat key: `memory-worker:heartbeat`.
- Accepted heartbeat statuses: `running` and `healthy`.
- Default maximum heartbeat age: `450` seconds.
- Default maximum batch runtime: `120` seconds.
- Docker healthcheck command: `python -m app.worker --healthcheck`.
- Docker healthcheck timeout: `15` seconds.
- API health must expose `stale_heartbeat=false` before `memory_worker` can be reported healthy.

## Guard Markers

- `memory-worker-health-contract-v1`
- `memory_worker_health_contract_visible`
- `max_heartbeat_age_seconds`
- `max_batch_runtime_seconds`
- `stale_heartbeat=false`

## Non-Claims

- No live embedding provider call is made by this contract.
- No local model download is made by this contract.
- No live MCP write, production rollout, release promotion, or hosted parity is claimed by this local contract.
