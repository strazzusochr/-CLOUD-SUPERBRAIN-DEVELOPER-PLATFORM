import { HUBS, LAYERS } from "../../../../../components/organism/regionMap";

export const dynamic = "force-static";

/** GET /api/v1/organism/contract — the deterministic organism surface contract. */
export function GET() {
  return Response.json({
    contract_version: "organism-surface-v1",
    endpoint: "/api/v1/organism/contract",
    evidence_ref: "organism_canvas_visible",
    source: "static",
    live: false,
    run_states: ["idle", "planning", "executing", "verifying", "blocked"],
    central: { kind: "neural_core", particles_default: 1600, asset_slot: "/public/organism/core.glb (optional)" },
    hubs: HUBS.map((h) => ({ id: h.id, label: h.label, layer: h.layer, agents: h.agents, route: h.route })),
    layers: LAYERS.map((l) => ({ no: l.no, code: l.code, label: l.label, providers: l.providers })),
    related: ["/api/v1/organism/live-state", "/api/v1/organism/events", "/api/v1/organism/replay"],
    policy_checks: [
      "No secret values are returned by this endpoint.",
      "Hubs map onto the seven architecture layers and four agent profiles.",
      "Reduced-motion clients render a static 2D topology with the same contract.",
    ],
    non_claims: [
      "Live state/events/replay are mock-labelled until the hosted backend serves them.",
      "No provider write, deploy, push or live LLM/MCP call is performed.",
    ],
  });
}
