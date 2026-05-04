# Memory and Session Schema - PATCHED

Stand: 2026-04-25
Status: Binding Phase 1 schema direction

## Architecture Rule

PostgreSQL with pgvector is the only Phase 1-5 memory database. Qdrant and Supabase MVP-runtime assumptions are superseded by `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` and ADR-007.

## Required Tables

### `projects`

Stores project metadata, owner context, status, and budget configuration.

Required fields: `id`, `slug`, `name`, `status`, `owner_user_id`, `monthly_budget_limit_eur`, `created_at`, `updated_at`.

### `agent_sessions`

Stores prompt runs and graph sessions.

Required fields: `id`, `project_id`, `status`, `trace_id`, `started_at`, `ended_at`, `created_at`, `metadata`.

### `agent_messages`

Stores user, assistant, system, and tool events.

Required fields: `id`, `session_id`, `agent_role`, `message_type`, `sequence_no`, `content`, `tool_name`, `tool_status`, `token_input`, `token_output`, `cost_eur`, `trace_id`, `created_at`.

### `memory_entries`

Stores long-term memory and retrieval metadata.

Required fields: `id`, `project_id`, `session_id`, `entry_type`, `title`, `content`, `summary`, `embedding_model_version`, `content_embedding vector`, `source_uri`, `importance_score`, `consolidation_status`, `expires_at`, `created_at`, `updated_at`.

### `cost_tracking`

Stores cost records per project, session, provider, model, and operation.

Required fields: `id`, `project_id`, `session_id`, `provider`, `model`, `operation_type`, `token_input`, `token_output`, `cost_eur`, `from_cache`, `trace_id`, `recorded_at`.

### `audit_log`

Stores security, purge, budget, branch-protection, and policy events.

Required fields: `id`, `event_type`, `user_id`, `session_id`, `details`, `severity`, `created_at`.

## Retrieval Rule

- Canonical text lives in PostgreSQL.
- Semantic search uses pgvector in PostgreSQL.
- `embedding_model_version` is mandatory for every vectorized entry.
- Memory injection may use at most 30 percent of the target model context window.

## Consolidation Rule

- Working memory is consolidated every 5 minutes.
- Entries use `pending`, `consolidating`, `consolidated`, or `failed` status.
- Failed consolidation extends TTL and emits an alert after repeated failures.
