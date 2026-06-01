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

/** 7-layer cloud stack — secrets/tokens live under .codex secrets (status only). */
export const LAYERS: { id: string; role: string; color: string }[] = [
  { id: "FE", role: "Frontend · Workbench · Cortex Canvas", color: C.cyan },
  { id: "ORC", role: "Orchestrator · Planning · Routing · LangGraph", color: C.blue },
  { id: "AP", role: "Agent Pool · Roles · Watchdog · Collect", color: C.violet },
  { id: "LLM", role: "LLM Gateway · Model Routing · Safety · Cost", color: C.magenta },
  { id: "MCP", role: "MCP Gateway · Tools · Provider Access", color: C.amber },
  { id: "MEM", role: "Memory · Checkpoints · Resume · Knowledge", color: C.green },
  { id: "OBS", role: "Observability · Traces · Evidence · Release Guard", color: "#fbbf24" },
];
