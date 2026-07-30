# ADR-010 Cloudflare-Native Free Runtime

Status: Accepted target; zero-card D1 artifact adapter implemented DEV-ONLY

Date: 2026-07-25; amended 2026-07-30

## Context

The RC10 runtime target still names Fly.io, PostgreSQL, Redis and pgvector. Session 9 removes
Fly.io and all paid/card-dependent providers from the target. The repository contains a
Cloudflare Worker that runs LangGraph.js and persists read, audit and runtime state in D1.

The original ADR selected R2 as the artifact adapter. The exact Owner account cannot activate
R2 without entering a subscription/checkout path, so R2 violates the binding zero-card rule.
The Owner rejected that path. R2 is therefore permanently outside the active target and must
not remain a Worker binding, resource-creation step, verifier requirement or fallback.

The target must preserve the seven logical layers, fail closed when a free quota is exhausted,
and make no hosted or production claim from local evidence.

## Decision

Choose Architecture A: a Cloudflare-native adapter migration.

1. LangGraph.js remains the primary orchestration state machine.
2. D1 is the project-specific read, audit and persistence store. It is not claimed as an
   official LangGraph checkpointer.
3. SQLite-backed Durable Objects serialize and deduplicate coordination state.
4. Cloudflare Queues carry bounded, versioned, ID/hash-only task envelopes. Raw prompts,
   credentials and provider output are forbidden.
5. D1 is also the zero-card artifact adapter for bounded UTF-8 text:
   - generated HTML remains in the existing `builds.html` column and is limited to 160 KiB;
   - native adapter artifacts use `native_artifacts`, are content-addressed, limited to
     32 KiB, and store content, SHA-256, byte length and content type;
   - raw artifact content is never placed in Queue envelopes, coordinator state, public
     probe responses or audit details;
   - create and audit, and delete and audit, are each executed as a D1 batch.
6. Vectorize and Workers AI remain owner-gated and inactive until their dedicated hosted
   verifiers pass.
7. Fly.io is not a Session-9 deployment target.
8. R2 is `historical_only`: inactive, unbound, not provisioned and not part of O2Core.

The first slice is a local candidate only:

```text
contract=cloudflare-native-runtime-candidate-v2
engine=langgraph-js
coordination=durable-object-sqlite
dispatch=cloudflare-queues
checkpointing=cloudflare-d1-custom
official_langgraph_checkpointer=false
artifact_store=cloudflare-d1-bounded-text
r2=historical_only
dev_only=true
hosted_proof=false
```

## Zero-Cost Boundary

Workers, D1, SQLite Durable Objects, Queues, Vectorize and Workers AI publish free-plan
allowances. Free-plan limit exhaustion must fail instead of silently activating paid usage.
O2Core covers Workers, D1, Durable Objects and Queues only.

The D1 adapter deliberately does not claim object-store parity:

- UTF-8 text only; no binary, multipart, streaming or range-read contract.
- 32 KiB per native adapter artifact and 160 KiB per generated HTML build.
- No public raw-content endpoint for native artifacts.
- No automatic spillover to R2, KV, paid D1, another provider or local disk.
- D1 quota, size, migration or write failures return a fail-closed error.
- Hosted write/read/delete, source parity and capacity remain unproven until the exact
  owner-authorized verifier passes.

Official references:

- https://developers.cloudflare.com/workers/platform/pricing/
- https://developers.cloudflare.com/d1/platform/pricing/
- https://developers.cloudflare.com/durable-objects/platform/pricing/
- https://developers.cloudflare.com/queues/platform/pricing/
- https://developers.cloudflare.com/r2/get-started/ (historical rejection evidence only)
- https://developers.cloudflare.com/vectorize/platform/pricing/
- https://developers.cloudflare.com/workers-ai/platform/pricing/

## Security Invariants

- Mutations require the existing server token and constant-time comparison.
- Queue envelopes stay below 64 KB and contain only generated IDs, hashes and versioned
  routing metadata.
- Duplicate deliveries cannot create duplicate terminal effects or audit events.
- Terminal states cannot transition back to active states.
- D1 artifacts have bounded byte length and content type and are removed by explicit cleanup.
- Native artifact content is secret-scanned before persistence and is not returned by the
  native create/read/delete contract.
- Raw exceptions, prompts, tokens and provider responses never enter HTTP, Queue,
  Durable Object state, audit details or evidence output.
- R2 must not appear in active Wrangler bindings or hosted resource creation.
- Live provider calls, live MCP writes, deployment, Vectorize and Workers AI remain closed.

## Migration And Claims

Migration `0003_zero_card_d1_artifacts.sql` adds the bounded `native_artifacts` table.
`wrangler.jsonc` contains no R2 binding in production or preview. Contract v1 and its local
R2 proof remain historical evidence only; they cannot satisfy the current v2 verifier.

The legacy RC10 architecture remains historical provenance until the Cloudflare candidate has
both local proof and owner-authorized hosted parity. Local proof earns no percentage credit
and must be labelled:

`DEV-ONLY; hosted proof still blocked`.

Only the real hosted v2 write/read/delete and source-parity verifier may open O2Core. It must
prove D1 artifact persistence, Queue delivery, Durable Object idempotency, cleanup and the
absence of an R2 binding. Documentation changes alone do not open a gate.

## Rejected Alternative

Architecture B (Hugging Face Spaces plus Supabase and Upstash) is rejected. It reintroduces
providers excluded by the current project locks, adds another runtime split, and does not
provide a stronger zero-card hosted guarantee.

Active R2 is also rejected. Its account activation path violates the Owner's zero-card rule,
and its object-store capabilities are not needed for the bounded text artifacts in this phase.
