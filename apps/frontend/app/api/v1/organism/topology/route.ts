import { HUBS, LAYERS, PROVIDERS, REGIONS } from "../../../../../components/organism/regionMap";
import { AGENTS, CLOSED_GATES, MCP_TOOLS, MODELS, SKILLS } from "../../../../../lib/platform";
import { workspaceWiringSurfaces } from "../../../../../lib/workspaceWiring";

export const dynamic = "force-static";

const nodeSlug = (value: string) => {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "") || "ref";
};

const uniqueStrings = (items: string[]) => Array.from(new Set(items)).sort((a, b) => a.localeCompare(b));

export function GET() {
  const workspacePages = workspaceWiringSurfaces();
  const workspaceDataSources = uniqueStrings(workspacePages.flatMap((page) => page.dataSources));
  const workspaceVerifierRefs = uniqueStrings(workspacePages.flatMap((page) => page.verifierRefs));
  const activeProviderIds = uniqueStrings(LAYERS.flatMap((layer) => layer.providers));
  const directCapabilityEdges = workspacePages.flatMap((page) => {
    const edges: Array<{ from: string; to: string; kind: string }> = [];
    const from = `page:${page.pageId}`;
    if (page.hub === "models") {
      edges.push(...MODELS.map((model) => ({ from, to: `model:${model.id}`, kind: "page_to_llm_model" })));
    }
    if (page.hub === "tools") {
      edges.push(...MCP_TOOLS.map((tool) => ({ from, to: `tool:${tool.id}`, kind: "page_to_mcp_tool" })));
      edges.push(...SKILLS.map((skill) => ({ from, to: `skill:${skill.id}`, kind: "page_to_skill" })));
    }
    if (page.hub === "agents") {
      edges.push(...AGENTS.map((agent) => ({ from, to: `agent:${agent.type}`, kind: "page_to_agent_profile" })));
    }
    if (page.hub === "cloud") {
      edges.push(...activeProviderIds.map((providerId) => ({ from, to: `provider:${providerId}`, kind: "page_to_cloud_provider" })));
    }
    if (page.brainRegion === "amygdala") {
      edges.push(...CLOSED_GATES.map((gate) => ({
        from,
        to: `gate:${gate.toLowerCase().replaceAll(" ", "_")}`,
        kind: "page_to_safety_gate",
      })));
    }
    return edges;
  });

  return Response.json({
    contract_version: "organism-topology-v1",
    evidence_ref: "organism_topology_visible",
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
        region: hub.region,
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
      ...workspacePages.map((page) => ({
        id: `page:${page.pageId}`,
        kind: "workspace_page",
        no: page.no,
        label: page.label,
        route: page.route,
        layer: page.layer,
        brain_region: page.brainRegion,
        hub: page.hub,
        data_sources: page.dataSources,
        verifier_refs: page.verifierRefs,
        event_kinds: page.eventKinds,
        secret_output: false,
        writes: false,
      })),
      ...workspaceDataSources.map((source) => ({
        id: `source:${nodeSlug(source)}`,
        kind: "workspace_data_source",
        label: source,
        secret_output: false,
        writes: false,
      })),
      ...workspaceVerifierRefs.map((verifier) => ({
        id: `verifier:${nodeSlug(verifier)}`,
        kind: "workspace_verifier",
        label: verifier,
        secret_output: false,
        writes: false,
        executes: false,
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
        to: `region:${hub.region}`,
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
      ...workspacePages.map((page) => ({
        from: `page:${page.pageId}`,
        to: `layer:${page.layer}`,
        kind: "page_to_layer",
      })),
      ...workspacePages.map((page) => ({
        from: `page:${page.pageId}`,
        to: `region:${page.brainRegion}`,
        kind: "page_to_brain_region",
      })),
      ...workspacePages.map((page) => ({
        from: `page:${page.pageId}`,
        to: `hub:${page.hub}`,
        kind: "page_to_capability_hub",
      })),
      ...workspacePages.flatMap((page) => page.dataSources.map((source) => ({
        from: `page:${page.pageId}`,
        to: `source:${nodeSlug(source)}`,
        kind: "page_to_data_source",
      }))),
      ...workspacePages.flatMap((page) => page.verifierRefs.map((verifier) => ({
        from: `page:${page.pageId}`,
        to: `verifier:${nodeSlug(verifier)}`,
        kind: "page_to_verifier",
      }))),
      ...directCapabilityEdges,
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
