import { HUBS } from "../../../../../components/organism/regionMap";

export const dynamic = "force-static";

/** GET /api/v1/organism/live-state — MOCK snapshot (no hosted backend here). */
export function GET() {
  const active = new Set(["workbench", "agents", "memory"]);
  return Response.json({
    contract_version: "organism-live-state-v1",
    source: "mock",
    live: false,
    note: "Deterministic mock until the hosted agent-api serves /api/v1/organism/live-state.",
    run_state: "planning",
    core: { pulse_hz: 1.7, intensity: 0.86 },
    hubs: HUBS.map((h, i) => ({
      id: h.id,
      layer: h.layer,
      status: active.has(h.id) ? "active" : "idle",
      throughput_pct: 18 + ((i * 11) % 70),
    })),
    gates_closed: ["production_deploy", "provider_writes", "secret_output", "main_push"],
    non_claims: ["mock data, never a live provider call", "no secret values"],
  });
}
