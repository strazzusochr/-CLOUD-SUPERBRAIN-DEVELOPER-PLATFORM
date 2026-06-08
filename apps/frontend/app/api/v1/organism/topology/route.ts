import { HUBS, LAYERS, PROVIDERS, REGIONS } from "../../../../../components/organism/regionMap";
import { WORKSPACE_PAGES } from "../../../../../lib/nav";
import { AGENTS, CLOSED_GATES, MCP_TOOLS, MODELS, SKILLS } from "../../../../../lib/platform";

export const dynamic = "force-static";

export function GET() {
  return Response.json({
    contract_version: "organism-topology-v1",
    endpoint: "/api/v1/organism/topology",
    source: "static_runtime_contract",
    live: false,
    source_kind: "contract",
    nodes: [
      ...REGIONS.map((region) => ({
        id: `region:${region.id}`,
        kind: "brain_region",
        label: region.name,
        layer: region.layer,
        capability: region.cap,
        secret_output: false,
        writes: false,
      })),
      ...LAYERS.map((layer) => ({
        id: `layer:${layer.code}`,
        kind: "architecture_layer",
        no: layer.no,
        code: layer.code,
        label: layer.label,
        providers: layer.providers,
        secret_output: false,
        writes: false,
      })),
      ...HUBS.map((hub) => ({
        id: `hub:${hub.id}`,
        kind: "capability_hub",
        label: hub.label,
        layer: hub.layer,
        route: hub.route,
        agents: hub.agents,
        secret_output: false,
        writes: false,
      })),
      ...AGENTS.map((agent) => ({
        id: `agent:${agent.type}`,
        kind: "agent_profile",
        label: agent.type,
        model: agent.model,
        tools: agent.tools,
        secret_output: false,
        writes: false,
      })),
      ...MCP_TOOLS.map((tool) => ({
        id: `tool:${tool.id}`,
        kind: "mcp_tool",
        label: tool.label,
        layer: tool.layer,
        scope: tool.scope,
        secret_output: false,
        writes: false,
        write_capability: tool.scope !== "read",
        gate_required: tool.scope !== "read",
      })),
      ...MODELS.map((model) => ({
        id: `model:${model.id}`,
        kind: "llm_model",
        label: model.id,
        role: model.role,
        layer: 4,
        secret_output: false,
        writes: false,
        gateway_only: true,
      })),
      ...SKILLS.map((skill) => ({
        id: `skill:${skill.id}`,
        kind: "skill",
        label: skill.id,
        purpose: skill.purpose,
        layer: 5,
        secret_output: false,
        writes: false,
      })),
      ...CLOSED_GATES.map((gate) => ({
        id: `gate:${gate.toLowerCase().replaceAll(" ", "_")}`,
        kind: "safety_gate",
        label: gate,
        status: "closed",
        secret_output: false,
        writes: false,
      })),
      ...WORKSPACE_PAGES.map((page) => ({
        id: `page:${page.id}`,
        kind: "workspace_page",
        no: page.no,
        label: page.label,
        route: page.route,
        layer: page.layer,
        secret_output: false,
        writes: false,
      })),
      ...PROVIDERS.map((provider) => ({
        id: `provider:${provider.id}`,
        kind: "cloud_provider",
        label: provider.label,
        layers: provider.layers,
        optional: provider.optional,
        secret_output: false,
        writes: false,
      })),
    ],
    edges: [
      ...REGIONS.filter((region) => region.id !== "callosum").map((region) => ({
        from: "region:callosum",
        to: `region:${region.id}`,
        kind: "neural_bus",
      })),
      ...HUBS.map((hub) => ({
        from: `hub:${hub.id}`,
        to: `region:${hub.id === "memory" ? "hippocampus" : hub.id === "observe" ? "cerebellum" : hub.id === "tools" ? "basal" : "prefrontal"}`,
        kind: "capability_to_region",
      })),
      ...HUBS.map((hub) => ({
        from: `hub:${hub.id}`,
        to: `layer:${hub.layer}`,
        kind: "hub_to_layer",
      })),
      ...AGENTS.flatMap((agent) => HUBS.filter((hub) => hub.agents.includes(agent.type)).map((hub) => ({
        from: `agent:${agent.type}`,
        to: `hub:${hub.id}`,
        kind: "agent_to_hub",
      }))),
      ...AGENTS.flatMap((agent) => agent.tools.map((toolId) => ({
        from: `agent:${agent.type}`,
        to: `tool:${toolId}`,
        kind: "agent_to_tool",
      }))),
      ...AGENTS.map((agent) => ({
        from: `agent:${agent.type}`,
        to: `model:${agent.model}`,
        kind: "agent_to_model",
      })),
      ...MCP_TOOLS.map((tool) => {
        const layer = LAYERS.find((candidate) => candidate.no === tool.layer);
        return {
          from: `tool:${tool.id}`,
          to: `layer:${layer?.code ?? "MCP"}`,
          kind: "tool_to_layer",
        };
      }),
      ...MODELS.map((model) => ({
        from: `model:${model.id}`,
        to: "layer:LLM",
        kind: "model_to_gateway_layer",
      })),
      ...SKILLS.map((skill) => ({
        from: `skill:${skill.id}`,
        to: "hub:tools",
        kind: "skill_to_tool_hub",
      })),
      ...WORKSPACE_PAGES.map((page) => ({
        from: `page:${page.id}`,
        to: `layer:${page.layer}`,
        kind: "page_to_layer",
      })),
      ...LAYERS.flatMap((layer) => layer.providers.map((providerId) => ({
        from: `layer:${layer.code}`,
        to: `provider:${providerId}`,
        kind: "layer_to_provider",
      }))),
      ...CLOSED_GATES.map((gate) => ({
        from: `gate:${gate.toLowerCase().replaceAll(" ", "_")}`,
        to: "region:amygdala",
        kind: "gate_to_security_region",
      })),
    ],
    non_claims: ["static topology contract", "no provider write", "no secret values"],
  });
}
