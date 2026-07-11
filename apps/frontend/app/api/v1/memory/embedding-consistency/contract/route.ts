import * as cf from "../../../../../../lib/cfBackend";
import { cfConfigured } from "../../../../../../lib/cfWorkersAi";
import * as gh from "../../../../../../lib/ghStore";
import { dbConfigured, vectorReady } from "../../../../../../lib/neon";

export const dynamic = "force-dynamic";

const MODEL = "@cf/baai/bge-base-en-v1.5";
const DIMENSIONS = 768;

export function GET(): Response {
  const persistence = cf.vectorizeConfigured()
    ? "cloudflare-vectorize"
    : dbConfigured() && vectorReady()
      ? "neon-pgvector"
      : gh.ghConfigured()
        ? "github-store"
        : null;
  const providerConfigured = cfConfigured();
  const semanticReady = providerConfigured && persistence !== null;

  return Response.json(
    {
      contract_version: "memory-embedding-consistency-v1",
      mode: "hosted_cloud_embedding_consistency_contract",
      endpoint: "GET /api/v1/memory/embedding-consistency/contract",
      evidence_ref: "memory_embedding_consistency_contract_visible",
      status: semanticReady ? "verified" : "action_required",
      source: "frontend-cloud-memory-contract",
      source_kind: "cloud_embedding_contract",
      live_backend: false,
      provider_configured: providerConfigured,
      persistence_configured: persistence !== null,
      persistence,
      current_embedding: {
        provider: "cloudflare-workers-ai",
        model_version: MODEL,
        dimensions: DIMENSIONS,
        vector_type: `vector(${DIMENSIONS})`,
        search_mode: semanticReady ? "semantic_cosine" : "disabled_until_provider_and_persistence_configured",
        live_embedding_provider_calls: false,
      },
      consistency: {
        passage_model: MODEL,
        query_model: MODEL,
        normalized_vectors: true,
        expected_dimensions: DIMENSIONS,
        mixed_dimensions_allowed: false,
      },
      policy_checks: [
        "Cloud memory uses the same 768-dimensional BGE model for writes and queries.",
        "The contract endpoint performs no embedding provider call.",
        "A hosted write/search roundtrip is required before semantic memory completion is claimed.",
      ],
      non_claims: [
        "This GET contract does not call Workers AI.",
        "This GET contract does not write memory.",
        "The legacy local PostgreSQL vector(1536) schema is not claimed as the hosted cloud embedding path.",
      ],
    },
    {
      headers: { "x-superbrain-source": "cloud-memory-contract", "cache-control": "no-store" },
    },
  );
}
