import { fetchLayers } from "../../../../../lib/agentApi";

// Browser-reachable proxy for the 7-layer readiness, so the shell can show a global
// "N/7 verified" pill on every page. Live from the runtime when reachable, else spec.
export const dynamic = "force-dynamic";
export const revalidate = 0;

const SPEC_LAYERS = [
  { id: "layer_1", label: "Frontend / Next.js" },
  { id: "layer_2", label: "Orchestrator / LangGraph" },
  { id: "layer_3", label: "Agent Pool" },
  { id: "layer_4", label: "LLM Gateway" },
  { id: "layer_5", label: "MCP Gateway / Tools" },
  { id: "layer_6", label: "Memory / pgvector" },
  { id: "layer_7", label: "Observability" },
];

export async function GET() {
  const live = await fetchLayers();
  if (live && live.length) {
    return Response.json({
      source: "agent-api",
      live: true,
      verified: live.filter((l) => l.verified).length,
      total: live.length,
      layers: live.map((l) => ({ id: l.id, label: l.label, status: l.status, verified: l.verified })),
    });
  }
  return Response.json({
    source: "spec",
    live: false,
    verified: 0,
    total: SPEC_LAYERS.length,
    layers: SPEC_LAYERS.map((l) => ({ ...l, status: "spec", verified: false })),
  });
}
