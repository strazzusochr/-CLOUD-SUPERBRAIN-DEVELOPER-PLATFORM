# ADR-010 Cloudflare-Native Free Runtime

Status: Accepted target; DEV-ONLY adapter migration active

Date: 2026-07-25

## Context

The RC10 runtime target still names Fly.io, PostgreSQL, Redis and pgvector. Session 9 removes
Fly.io and all paid/card-dependent providers from the target. The repository already contains
a Cloudflare Worker that runs LangGraph.js and persists its read, audit and runtime state in
D1, with a green local Wrangler proof.

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
5. Private R2 is the artifact adapter. Keys are generated server-side and content-addressed;
   no public bucket or unchecked client key is allowed.
6. Vectorize and Workers AI remain owner-gated and inactive until their dedicated hosted
   verifiers pass.
7. Fly.io is not a Session-9 deployment target.

The first slice is a local candidate only:

```text
contract=cloudflare-native-runtime-candidate-v1
engine=langgraph-js
coordination=durable-object-sqlite
dispatch=cloudflare-queues
checkpointing=cloudflare-d1-custom
official_langgraph_checkpointer=false
artifact_store=cloudflare-r2
dev_only=true
hosted_proof=false
```

## Zero-Cost Boundary

Workers, D1, SQLite Durable Objects, Queues, Vectorize and Workers AI publish free-plan
allowances. Free-plan limit exhaustion must fail instead of silently activating paid usage.

R2 publishes a free usage tier, but its current setup documentation requires an R2
subscription completed through a checkout flow. Therefore this ADR does not claim that hosted
R2 is available without a payment method. O2' must prove the exact account can activate every
required resource with no card and no charge. If it cannot, R2 stays disabled and an amended
ADR must select a genuinely zero-card artifact store before hosted cutover.

Official references:

- https://developers.cloudflare.com/workers/platform/pricing/
- https://developers.cloudflare.com/d1/platform/pricing/
- https://developers.cloudflare.com/durable-objects/platform/pricing/
- https://developers.cloudflare.com/queues/platform/pricing/
- https://developers.cloudflare.com/r2/get-started/
- https://developers.cloudflare.com/r2/pricing/
- https://developers.cloudflare.com/vectorize/platform/pricing/
- https://developers.cloudflare.com/workers-ai/platform/pricing/

## Security Invariants

- Mutations require the existing server token and constant-time comparison.
- Queue envelopes stay below 64 KB and contain only generated IDs, hashes and versioned
  routing metadata.
- Duplicate deliveries cannot create duplicate terminal effects or audit events.
- Terminal states cannot transition back to active states.
- R2 objects have bounded size and content type and are removed by explicit cleanup.
- Raw exceptions, prompts, tokens and provider responses never enter HTTP, Queue, R2 or
  evidence output.
- Live provider calls, live MCP writes, deployment, Vectorize and Workers AI remain closed.

## Migration And Claims

The legacy RC10 architecture remains the historical verified source until the Cloudflare
candidate has both local proof and owner-authorized hosted parity. Local proof earns no
percentage credit and must be labelled:

`DEV-ONLY; hosted proof still blocked`.

Only after O2' and hosted parity may the owner-input manifest, external-gate summary,
system-architecture locks and broad verifiers be rebased from Fly/PostgreSQL/Redis to the
Cloudflare-native target.

## Rejected Alternative

Architecture B (Hugging Face Spaces plus Supabase and Upstash) is rejected. It reintroduces
providers excluded by the current project locks, adds another runtime split, and does not
provide a stronger zero-card hosted guarantee.
