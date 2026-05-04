# Memory Embedding Consistency Contract

Status: implemented-local
Phase: Phase 4 / Audit L-09
Contract version: `memory-embedding-consistency-v1`
Evidence: `memory_embedding_consistency_contract_visible`

## Purpose

Audit L-09 flagged that memory embeddings had no explicit compatibility strategy for an embedding model change. This contract makes the active memory embedding version, vector dimension, schema guard, and re-embedding policy visible at runtime.

## Runtime Endpoint

| Capability | Method | Path | Evidence |
| --- | --- | --- | --- |
| Embedding consistency proof | `GET` | `/api/v1/memory/embedding-consistency/contract` | `memory_embedding_consistency_contract_visible` |

## Required Fields

- `contract_version`: `memory-embedding-consistency-v1`
- `audit_gap`: `L-09`
- `status`: `verified` when the required memory schema columns match the contract
- `schema.expected_columns.content_embedding`: `vector(1536)`
- `schema.expected_columns.embedding_model_version`: `character varying(100)`
- `current_embedding.model_version`: current deterministic model version
- `current_embedding.dimensions`: current vector dimension
- `current_embedding.search_mode`: `lexical_fallback`
- `current_embedding.live_embedding_provider_calls`: `false`

## Re-Embedding Policy

1. Every new memory write persists `memory_entries.embedding_model_version`.
2. The same model version is mirrored into `memory_entries.metadata.embedding_model_version` for audit/debug visibility.
3. Vector search remains disabled while embedding generation is behind the live provider gate.
4. A model or dimension change requires a bounded re-embedding plan before vector search can be enabled.
5. Future vector reads must filter by `embedding_model_version` and must not mix old and new vectors.
6. Stale rows stay available through `lexical_fallback` or are marked `deprecated` until re-embedded.

## Verifier Coverage

- `scripts/verify-browser-contract.ps1` asserts the UI marker and runtime contract endpoint.
- `scripts/verify-hosted-staging.ps1` asserts the same endpoint through the hosted-staging/local-mirror path.
- `scripts/verify-phase1-runtime.ps1` asserts the endpoint in the full local runtime harness.
- `scripts/verify-phase1.ps1` statically guards API, migration, UI, docs, and verifier markers.

## Non-Claims

- No live embedding provider call is made by this proof.
- No production vector-search readiness is claimed.
- No production deployment is claimed.
