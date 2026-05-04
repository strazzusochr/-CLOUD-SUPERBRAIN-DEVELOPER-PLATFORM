# ADR-004 MVP Database Strategy

Status: Superseded by ADR-007
Date: 2026-04-23
Superseded: 2026-04-25

## Context

This ADR originally selected Supabase as the MVP start database. The patched master truth now requires one shared PostgreSQL instance with pgvector as the Phase 1-5 source of truth.

## Supersession

`docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md` supersedes this ADR. Do not use this ADR to justify Supabase as active MVP runtime.

## Replacement

See `docs/adr/ADR-007-shared-postgres-pgvector-phase1.md`.

## Historical Decision

Supabase was previously selected to reduce early ops work. That decision is preserved only as historical context.
