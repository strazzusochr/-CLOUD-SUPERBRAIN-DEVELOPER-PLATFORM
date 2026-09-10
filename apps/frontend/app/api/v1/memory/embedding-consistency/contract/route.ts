import { projectionResponse, proxyReadToBoundary } from "../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/memory/embedding-consistency/contract");
  return response ?? projectionResponse({
    contract_version: "memory-embedding-consistency-v1",
    mode: "stateless_frontend_memory_contract",
    endpoint: "GET /api/v1/memory/embedding-consistency/contract",
    evidence_ref: "memory_embedding_consistency_contract_visible",
    status: "action_required",
    audit_gap: "L-09",
    persistence_configured: false,
    current_embedding: {
      model_version: "text-embedding-3-small",
      dimensions: 1536,
      vector_type: "vector(1536)",
      search_mode: "lexical_fallback",
      live_embedding_provider_calls: false,
    },
    schema: {
      expected_columns: {
        embedding_model_version: "character varying(100)",
        content_embedding: "vector(1536)",
      },
    },
    consistency: {
      expected_dimensions: 1536,
      mixed_dimensions_allowed: false,
      frontend_schema_creation_allowed: false,
    },
    policy_checks: [
      "The canonical PostgreSQL/pgvector schema remains 1536-dimensional.",
      "The stateless frontend does not create tables, embeddings, or alternate vector stores.",
      "A stateful Agent API roundtrip is required before semantic memory completion is claimed.",
    ],
    non_claims: [
      "No live embedding provider call is performed.",
      "No memory row or vector is written.",
      "No alternate D1, Vectorize, GitHub-store, or frontend Neon path is claimed.",
    ],
  });
}
