import { HUBS, LAYERS } from "../../../../../components/organism/regionMap";
import { workspaceWiringSurfaces } from "../../../../../lib/workspaceWiring";
import { AGENTS, CLOSED_GATES, MCP_TOOLS, MODELS, SKILLS } from "../../../../../lib/platform";

export const dynamic = "force-static";

/** GET /api/v1/organism/contract — the deterministic organism surface contract. */
export function GET() {
  const workspacePages = workspaceWiringSurfaces();

  return Response.json({
    contract_version: "organism-surface-v1",
    endpoint: "/api/v1/organism/contract",
    evidence_ref: "organism_canvas_visible",
    source: "static",
    live: false,
    run_states: ["idle", "planning", "executing", "verifying", "blocked"],
    event_kinds: ["planning", "executing", "tool_call", "llm_call", "memory_read", "memory_write", "verifying", "blocked"],
    central: { kind: "neural_core", particles_default: 1600, asset_slot: "/public/organism/core.glb (optional)" },
    hubs: HUBS.map((h) => ({ id: h.id, label: h.label, layer: h.layer, agents: h.agents, route: h.route })),
    layers: LAYERS.map((l) => ({ no: l.no, code: l.code, label: l.label, providers: l.providers })),
    workspace_pages: workspacePages.map((page) => ({
      id: page.pageId,
      no: page.no,
      route: page.route,
      layer: page.layer,
      brain_region: page.brainRegion,
      hub: page.hub,
      data_sources: page.dataSources,
      verifier_refs: page.verifierRefs,
      live: page.live,
      writes: page.writes,
      secret_output: page.secretOutput,
    })),
    workspace_page_count: workspacePages.length,
    agents: AGENTS.map((agent) => ({ type: agent.type, tools: agent.tools, model: agent.model })),
    tools: MCP_TOOLS.map((tool) => ({ id: tool.id, layer: tool.layer, scope: tool.scope })),
    models: MODELS.map((model) => ({ id: model.id, role: model.role })),
    skills: SKILLS.map((skill) => ({ id: skill.id })),
    gates_closed: CLOSED_GATES,
    related: [
      "/api/v1/organism/topology",
      "/api/v1/organism/live-state",
      "/api/v1/organism/events",
      "/api/v1/organism/replay",
      "/api/v1/organism/regions",
      "/api/v1/organism/safety",
      "/api/v1/workspace/wiring",
      "/api/v1/workspace/vertical-stack",
    ],
    policy_checks: [
      "No secret values are returned by this endpoint.",
      "Hubs map onto the seven architecture layers and four agent profiles.",
      "All 22 workspace pages map onto layer, brain-region, hub, data-source, and verifier references.",
      "Topology edges must reference existing layer, region, hub, agent, tool, model, skill, provider, and gate nodes.",
      "Reduced-motion clients render a static 2D topology with the same contract.",
    ],
    non_claims: [
      "Live state/events/replay are spec-only or locked until a configured backend serves redacted runtime state.",
      "No provider write, deploy, push or live LLM/MCP call is performed.",
    ],
  });
}
