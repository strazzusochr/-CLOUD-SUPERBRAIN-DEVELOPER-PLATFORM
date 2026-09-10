import { workspaceWiringSurfaces } from "./workspaceWiring";

export const WORKSPACE_VERTICAL_STACK_CONTRACT_VERSION = "workspace-vertical-stack-v1";
export const WORKSPACE_VERTICAL_STACK_EVIDENCE_REF = "workspace_vertical_stack_visible";

const apiLikeRef = (value: string) => value.startsWith("/api/") || value.startsWith("/mcp/") || value.startsWith("/llm/");

const routeToComponentPath = (route: string) => {
  if (route === "/") return "apps/frontend/app/page.tsx";
  return `apps/frontend/app/${route.replace(/^\//, "").replaceAll("/", "/")}/page.tsx`;
};

const dataPlaneForLayer = (layer: string, hub: string) => {
  if (hub === "memory" || layer === "MEM") return "postgres-pgvector-and-redis-memory";
  if (hub === "observe" || layer === "OBS") return "audit-log-metrics-evidence-artifacts";
  if (hub === "tools" || layer === "MCP") return "mcp-gateway-safe-envelope";
  if (hub === "models" || layer === "LLM") return "llm-gateway-contract";
  if (hub === "agents" || layer === "AP") return "agent-pool-task-queue";
  if (hub === "cloud" || layer === "ORC") return "cloud-readiness-and-deployment-preflight";
  return "frontend-static-contract-and-runtime-fetches";
};

export function workspaceVerticalStackContract() {
  const surfaces = workspaceWiringSurfaces();
  const stacks = surfaces.map((surface) => {
    const apiContracts = surface.dataSources.filter(apiLikeRef);
    const staticDataRefs = surface.dataSources.filter((source) => !apiLikeRef(source));
    const verifierRefs = Array.from(new Set([
      ...surface.verifierRefs,
      "scripts/verify-workspace-vertical-stack.ps1",
      "scripts/verify-workspace-pages-browser.ps1",
    ]));

    return {
      pageId: surface.pageId,
      no: surface.no,
      label: surface.label,
      route: surface.route,
      layer: surface.layer,
      brainRegion: surface.brainRegion,
      hub: surface.hub,
      primaryMode: surface.primaryMode,
      ui: {
        route: surface.route,
        componentPath: routeToComponentPath(surface.route),
        shellRequired: true,
        activeRailRequired: true,
      },
      api: {
        contracts: apiContracts,
        staticRefs: staticDataRefs,
        gatewayBound: true,
        directProviderCalls: false,
      },
      data: {
        plane: dataPlaneForLayer(surface.layer, surface.hub),
        sources: surface.dataSources,
        writesAllowedByDefault: false,
        secretOutputAllowed: false,
      },
      verification: {
        refs: verifierRefs,
        browserProofRequired: true,
        phase1GuardRequired: true,
        hostedProofRequiredForRelease: true,
      },
      deploy: {
        frontendTarget: "vercel",
        backendTargets: [
          "cloudflare-stateful-runtime",
          "cloudflare-llm-gateway",
          "vercel-hosted-backend-origin-contracts",
        ],
        backendTargetMode: "contract_targets_only",
        registry: "ghcr",
        hostedProofStatus: "blocked_external_gates",
      },
      safety: {
        live: surface.live,
        writes: surface.writes,
        secretOutput: surface.secretOutput,
        productionDeployClaimAllowed: false,
        localProofOnly: true,
      },
      eventKinds: surface.eventKinds,
    };
  });

  return {
    contract_version: WORKSPACE_VERTICAL_STACK_CONTRACT_VERSION,
    endpoint: "/api/v1/workspace/vertical-stack",
    evidence_ref: WORKSPACE_VERTICAL_STACK_EVIDENCE_REF,
    source: "static_runtime_contract",
    page_count: stacks.length,
    expected_page_count: 22,
    layers_required: 7,
    stacks,
    required_stage_keys: ["ui", "api", "data", "verification", "deploy", "safety"],
    policy_checks: [
      "Every canonical page must expose UI, API, data, verification, deploy, and safety stages.",
      "Every page remains local-proof-only until hosted Vercel/Cloudflare-native/GHCR/Grafana gates pass.",
      "No stack entry may enable provider bypass, secret output, production deploy, or live MCP writes.",
      "Budget UI remains hidden unless a paid/metered capability is selected or explicitly available.",
    ],
    non_claims: [
      "This contract does not execute deploys, provider calls, MCP writes, or verifier commands.",
      "This contract is not hosted staging proof and cannot close external gates by itself.",
      "Localhost evidence remains DEV-ONLY.",
    ],
  };
}
