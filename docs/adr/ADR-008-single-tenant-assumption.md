# ADR-008 Single-Tenant Assumption Through Phase 5

Status: Accepted
Date: 2026-04-29

## Context

The patched master document requires a budget-compliant start on one small Hetzner-class runtime and one shared PostgreSQL instance. The audit report flagged the implicit single-tenant assumption as a governance gap because tenant isolation, billing, and permission boundaries were not named as an explicit architecture decision.

## Decision

The platform is single-tenant through Phase 5.

One owner operates one platform instance, one primary application database, one Redis working-memory tier, one LLM gateway policy surface, and one MCP gateway policy surface. Project-level separation exists inside the app schema, but it is not a multi-tenant security boundary.

Multi-tenant operation is not allowed before a later ADR defines isolation for identity, database row access, memory retrieval, audit visibility, budget attribution, secret scope, and MCP authorization.

## Rationale

This keeps the MVP inside the 20 EUR/month infrastructure cap and matches the current trusted-owner workflow. It also prevents a false security claim: project IDs, traces, and memory scopes are useful operational partitions, but they are not tenant isolation.

## Consequences

1. Release notes and handoff docs must not claim SaaS-style multi-tenancy.
2. Auth and audit features protect the owner-facing platform, not separate customer tenants.
3. Any public multi-user launch requires a new multi-tenant ADR and runtime proof.
4. Phase 6 scale work may revisit this assumption only after concrete load and isolation evidence exists.

