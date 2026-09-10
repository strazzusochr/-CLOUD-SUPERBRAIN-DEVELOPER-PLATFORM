# ADR Index

Stand: 2026-07-25
Status: Active

## Zweck

Dieses Dokument ist das Verzeichnis aller Architecture Decision Records im Projekt. Jeder Architekturwechsel muss hier sichtbar werden.

## Aktive ADRs

| ADR | Titel | Status |
| --- | --- | --- |
| `ADR-001` | LangGraph As Main Orchestrator | accepted |
| `ADR-002` | LiteLLM As LLM Gateway | accepted |
| `ADR-003` | No AutoGen Before Phase 6 | accepted |
| `ADR-004` | MVP Database Strategy | accepted |
| `ADR-005` | WebGPU With WebGL Fallback | accepted |
| `ADR-006` | Observability Stack Boundary | proposed |
| `ADR-007` | Shared PostgreSQL and pgvector for Phase 1 | accepted |
| `ADR-008` | Single-Tenant Assumption Through Phase 5 | accepted |
| `ADR-009` | Auth Design For Owner-Gated Runtime | accepted |
| `ADR-010` | Cloudflare-Native Free Runtime | accepted target; DEV-ONLY migration |

## Audit Mapping

The 2026-04-29 audit asked for ADR coverage of the single-tenant assumption and auth design. The existing ADR-006 and ADR-007 numbers were already used for observability and PostgreSQL/pgvector decisions, so the missing subjects are resolved as ADR-008 and ADR-009 without rewriting ADR history.

## Regel

1. Kein stiller Architekturwechsel.
2. Neue Architekturentscheidung bedeutet neuer ADR-Eintrag.
3. Ueberholte Entscheidungen werden nicht geloescht, sondern durch neue ADRs abgeloest.
