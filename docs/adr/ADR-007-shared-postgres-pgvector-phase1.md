# ADR-007 Shared PostgreSQL and pgvector for Phase 1

Status: Accepted
Date: 2026-04-25

## Context

The patched master document requires a budget-compliant Phase 1 runtime with one PostgreSQL instance, separated logical databases, and pgvector as the only vector solution through Phase 5.

## Decision

Use one self-hosted PostgreSQL instance in Phase 1. Inside it, keep separate databases:

- `superbrain_prod` for application state, sessions, memory metadata, costs, and LangGraph checkpoint data.
- `langfuse` for observability state if Langfuse is activated.

Enable `pgvector` for long-term semantic memory. Exclude Qdrant from Phase 1-5.

## Rationale

- Aligns with PATCHED master truth.
- Keeps infra inside the 20 EUR/month target.
- Avoids running two vector systems.
- Keeps migration and backup scope understandable.

## Alternatives Considered

- Supabase MVP runtime: superseded by PATCHED.
- Qdrant for semantic memory: rejected until Phase 6.
- Separate PostgreSQL instances: rejected until resource or isolation evidence exists.

## Consequences

- Compose and schema docs must remove Qdrant and active Supabase assumptions.
- Runtime code must be PostgreSQL/pgvector portable from the start.
- Any future Supabase or Qdrant reintroduction requires a new ADR.
