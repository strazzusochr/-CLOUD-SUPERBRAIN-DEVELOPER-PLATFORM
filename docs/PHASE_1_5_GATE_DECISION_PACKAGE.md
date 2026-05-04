# Phase 1.5 Gate Decision Package - OBSOLETE

Stand: 2026-04-25
Status: Superseded by PATCHED

This document is retained for history only. Its previous gates were based on pre-PATCHED assumptions:

- Supabase as active MVP database.
- Qdrant as retrieval accelerator.
- CPX51-oriented service sizing.
- Runtime blocked until Phase 1.5 owner decisions.

`docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` supersedes those assumptions.

## Current Rule

Phase 1 execution is allowed for local foundation scaffolding that follows PATCHED:

- one PostgreSQL instance with pgvector,
- no Qdrant,
- small CX21-class budget target,
- no production deployment,
- no secrets,
- no release-ready claim.

Observability remains separated conceptually. Langfuse must not be silently added to the main app stack without budget proof and explicit implementation scope.
