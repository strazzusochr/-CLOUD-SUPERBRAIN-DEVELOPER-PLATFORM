/* ------------------------------------------------------------------
 * Brain-region ↔ platform-capability mapping (10 regions).
 * Colors use NeuroGlass functional palette. pos = unit-sphere coords.
 * Data contract is shared by the 3D canvas and the 2D fallback.
 * ------------------------------------------------------------------ */

export type RunState = "idle" | "planning" | "executing" | "verifying" | "blocked";

export interface Region {
  id: string;
  name: string;
  cap: string;
  layer: string;
  color: string;
  pos: [number, number, number];
}

export const C = {
  cyan: "#00e5ff",
  blue: "#3b82f6",
  violet: "#8b5cf6",
  magenta: "#ec4899",
  green: "#22c55e",
  amber: "#f59e0b",
  red: "#ef4444",
} as const;

export const REGIONS: Region[] = [
  { id: "prefrontal", name: "Prefrontal Cortex", cap: "Planning / Goals / Architecture", layer: "ORC", color: C.blue, pos: [0.0, 0.9, 0.7] },
  { id: "thalamus", name: "Thalamus", cap: "Routing / Context / Approvals", layer: "ORC", color: C.cyan, pos: [0.0, 0.1, 0.0] },
  { id: "hippocampus", name: "Hippocampus", cap: "Memory / Resume / Knowledge", layer: "MEM", color: C.violet, pos: [-0.5, -0.2, 0.2] },
  { id: "amygdala", name: "Amygdala", cap: "Security / Risk / Secret protection", layer: "OBS", color: C.red, pos: [0.4, -0.3, 0.3] },
  { id: "basal", name: "Basal Ganglia", cap: "Tool / Skill / Model selection", layer: "MCP", color: C.amber, pos: [-0.3, 0.0, -0.2] },
  { id: "cerebellum", name: "Cerebellum", cap: "Tests / Verifier / Self-correction", layer: "OBS", color: C.green, pos: [0.0, -0.8, -0.7] },
  { id: "motor", name: "Motor Cortex", cap: "CLI / Browser / Git / Cloud actions", layer: "AP", color: C.magenta, pos: [-0.6, 0.6, 0.0] },
  { id: "sensory", name: "Sensory Cortex", cap: "Files / Logs / Providers / MCP", layer: "MCP", color: C.cyan, pos: [0.6, 0.6, 0.0] },
  { id: "autonomic", name: "Autonomic NS", cap: "Watchdog / Health / Retries", layer: "AP", color: C.amber, pos: [0.0, -0.5, 0.5] },
  { id: "callosum", name: "Corpus Callosum", cap: "Event Bus / Cross-agent sync", layer: "ORC", color: C.violet, pos: [0.0, 0.3, -0.5] },
];

export const STATE_COLOR: Record<RunState, string> = {
  idle: C.blue,
  planning: C.cyan,
  executing: C.blue,
  verifying: C.green,
  blocked: C.red,
};

export const STATE_LABEL: Record<RunState, string> = {
  idle: "IDLE",
  planning: "PLANNING",
  executing: "EXECUTING",
  verifying: "VERIFYING",
  blocked: "BLOCKED",
};

export interface Hub {
  id: string;
  label: string;
  color: string;
  route: string;
  /** Orbit position around the central organism. */
  pos: [number, number, number];
}

/**
 * The 8 capability hubs that orbit the central Superbrain organism
 * (collective-organism view — central brain + radial data/control links).
 */
export const HUBS: Hub[] = [
  { id: "workbench", label: "WORKBENCH", color: C.cyan, route: "/workbench", pos: [0, 2.35, 0.35] },
  { id: "agents", label: "AGENTS", color: C.violet, route: "/agents", pos: [1.66, 1.66, -0.35] },
  { id: "tools", label: "TOOLS / MCP", color: C.amber, route: "/tools", pos: [2.35, 0, 0.35] },
  { id: "models", label: "MODELS", color: C.green, route: "/marketplace", pos: [1.66, -1.66, -0.35] },
  { id: "marketplace", label: "MARKETPLACE", color: C.magenta, route: "/marketplace", pos: [0, -2.35, 0.35] },
  { id: "observe", label: "OBSERVABILITY", color: "#fbbf24", route: "/observe", pos: [-1.66, -1.66, -0.35] },
  { id: "memory", label: "MEMORY", color: C.blue, route: "/files", pos: [-2.35, 0, 0.35] },
  { id: "cloud", label: "CLOUD", color: C.cyan, route: "/about/stack", pos: [-1.66, 1.66, -0.35] },
];

/* ------------------------------------------------------------------
 * 7-layer cloud architecture × cloud providers.
 * Source of truth: services/agent-api/app/clouds.py
 *   - cloud_provider_state().seven_layer_mapping  (layer → providers)
 *   - vercel/hetzner/cloudflare/github/ghcr/huggingface/gitlab/gitkraken provider()
 * Tokens for every provider live under .codex/secrets — status only, never shown.
 * ------------------------------------------------------------------ */

export type ProviderStatus =
  | "live_verified"
  | "configured"
  | "metadata_only"
  | "action_required";

export interface CloudProvider {
  id: string;
  label: string;
  role: string;
  layers: number[];
  color: string;
  optional: boolean;
  /** API base the backend reads (read-only, token-gated). */
  api: string;
}

/** The 8 non-secret cloud-provider surfaces (clouds.py provider IDs). */
export const PROVIDERS: CloudProvider[] = [
  { id: "vercel", label: "Vercel", role: "Hosted frontend · staging proof origin", layers: [1, 7], color: C.cyan, optional: false, api: "api.vercel.com" },
  { id: "hetzner", label: "Hetzner Cloud", role: "Runtime host · PostgreSQL pgvector · live infra budget", layers: [2, 3, 6, 7], color: C.red, optional: false, api: "api.hetzner.cloud" },
  { id: "cloudflare", label: "Cloudflare", role: "Edge · DNS · AI gateway · provider cache", layers: [4, 7], color: C.amber, optional: false, api: "api.cloudflare.com" },
  { id: "github", label: "GitHub Actions", role: "CI/CD · branch protection · deploy gate", layers: [5, 7], color: C.blue, optional: false, api: "api.github.com" },
  { id: "ghcr", label: "GHCR", role: "Container artifact registry (pull-based deploy)", layers: [5], color: C.violet, optional: false, api: "ghcr.io" },
  { id: "huggingface", label: "Hugging Face", role: "Model / provider identity check (not prod runtime)", layers: [4, 7], color: "#fbbf24", optional: true, api: "huggingface.co" },
  { id: "gitlab", label: "GitLab", role: "External identity / mirror proof", layers: [5, 7], color: C.magenta, optional: true, api: "gitlab.com" },
  { id: "gitkraken", label: "GitKraken", role: "Dev-workspace / organization identity", layers: [5, 7], color: C.green, optional: true, api: "gitkraken.gitclear.com" },
];

export interface CloudLayer {
  no: number;
  /** Short code shared with Region.layer. */
  code: string;
  label: string;
  /** Provider IDs that back this layer (clouds.py seven_layer_mapping). */
  providers: string[];
  color: string;
}

/** The seven architecture layers, each backed by real cloud providers. */
export const LAYERS: CloudLayer[] = [
  { no: 1, code: "FE", label: "Frontend / Next.js", providers: ["vercel"], color: C.cyan },
  { no: 2, code: "ORC", label: "Orchestrator / LangGraph", providers: ["hetzner"], color: C.blue },
  { no: 3, code: "AP", label: "Agent Pool", providers: ["hetzner"], color: C.violet },
  { no: 4, code: "LLM", label: "LLM Gateway", providers: ["cloudflare", "huggingface"], color: C.magenta },
  { no: 5, code: "MCP", label: "MCP Gateway / Tools", providers: ["github", "ghcr", "gitlab", "gitkraken"], color: C.amber },
  { no: 6, code: "MEM", label: "Memory / PostgreSQL pgvector", providers: ["hetzner"], color: C.green },
  { no: 7, code: "OBS", label: "Observability / Evidence", providers: ["vercel", "hetzner", "cloudflare", "github", "gitkraken"], color: "#fbbf24" },
];

/** Lookup helper: provider objects backing a given layer number. */
export function providersForLayer(no: number): CloudProvider[] {
  return PROVIDERS.filter((p) => p.layers.includes(no));
}
