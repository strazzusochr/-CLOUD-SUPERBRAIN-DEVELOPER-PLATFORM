# Phase 2 Implementation Plan - PATCHED

Stand: 2026-04-25
Status: Prepared, blocked only by Phase 1 runtime proof

## Purpose

Phase 2 implements the controlled multi-agent runtime after Phase 1 foundation scaffolding is verified. This plan supersedes older Phase-1.5-gated language.

## Prerequisites

Phase 2 runtime work may start only after Phase 1 proves:

1. `docker compose config` succeeds.
2. `agent-api`, `mcp-gateway`, `postgres`, `redis`, and `nginx` have health checks.
3. No Qdrant service exists.
4. PostgreSQL with pgvector is initialized.
5. No real secrets are committed.
6. Budget and rate-control contracts are ready for enforcement.

## Goal

A user can submit a prompt and observe a controlled 4-agent run:

1. Planner parses intent.
2. Coder prepares isolated changes.
3. Tester validates with bounded retries.
4. DevOps evaluates runtime and deployment impact without production mutation.

## Implementation Order

1. Budget and rate-control middleware.
2. LangGraph graph with Budget-Guard node.
3. LiteLLM gateway configuration.
4. Four core agent profiles.
5. Memory consolidation job running every 5 minutes.
6. MCP toolsets with timeout and audit envelope.
7. Recovery, retry, and SSE event verification.

## Required LangGraph Nodes

1. Intent Parser.
2. Budget Guard.
3. Task Router.
4. Agent Executor.
5. Result Aggregator.
6. Memory Updater.
7. Error Handler.

## Non-Negotiable Runtime Rules

- No productive LLM call before Budget Guard and rate limits.
- Global retry maximum remains 5.
- Provider switches must be logged with cost/provider event metadata.
- Memory injection cannot exceed 30 percent of target model context window.
- Tool calls require timeout, audit event, trace id, and controlled failure mode.
- PostgreSQL checkpointer must be used for production-like LangGraph state.

## Verification

Phase 2 is not implemented until these proofs exist:

1. Budget alert fires at 80 percent.
2. 100 percent budget triggers hard stop.
3. No graph node can loop without retry counter.
4. Server restart can recover graph state from PostgreSQL checkpoint.
5. Provider fallback emits structured event.
6. Tool timeout becomes controlled error, not hang.
7. SSE stream emits heartbeat, agent status, error, and done events.

## Non-Claims

This document does not claim live LLM calls, production deployment, main-branch writes, secrets activation, or release readiness.
