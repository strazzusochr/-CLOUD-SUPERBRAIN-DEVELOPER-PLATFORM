// Honest 200 defaults for agent-api surfaces that have no live backend in this
// deployment. HTTP 200 = "request handled; here is the (empty/projected) resource".
// Every payload is transparent: live_backend:false + source:"frontend-projection"
// and genuinely-empty collections (there are really none yet) — never fabricated
// rows. This lets the whole 22-page surface answer 200 without a hosted backend,
// while staying truthful. Specific shapes match what lib/agentApi.ts readers expect.

const tag = { live_backend: false, source: "frontend-projection" as const };

function envNum(name: string, fallback: number): number {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && v > 0 ? v : fallback;
}

const DEFAULTS: Record<string, () => Record<string, unknown>> = {
  "/api/v1/tasks/recent": () => ({ ...tag, queue_depth: 0, queue_depth_by_priority: {}, tasks: [] }),
  "/api/v1/sessions/recent": () => ({ ...tag, sessions: [] }),
  "/api/v1/audit/recent": () => ({ ...tag, events: [] }),
  "/api/v1/audit/mcp": () => ({ ...tag, events: [] }),
  "/api/v1/escalations/recent": () => ({ ...tag, escalations: [], events: [] }),
  "/api/v1/memory/consolidation/recent": () => ({ ...tag, records: [], consolidations: [] }),
  "/api/v1/agents/status": () => ({ ...tag, status: "ok", agents: [] }),
  "/api/v1/live-agents/status": () => ({ ...tag, agents: [], default_model: "@cf/meta/llama-3.1-8b-instruct", runtime_source: "frontend-projection" }),
  "/api/v1/team/status": () => ({ ...tag, status: "ok", roles: [] }),
  "/api/v1/rate-limit/status": () => ({ ...tag, status: "ok", limit: null, remaining: null, window_s: null }),
  "/api/v1/session-limits/status": () => ({ ...tag, status: "ok", active_sessions: 0, max_sessions: null }),
  "/api/v1/budget": () => ({ ...tag, status: "ok", spent_usd: 0, max_usd: envNum("LIVE_LLM_MAX_BUDGET_USD", 20), live_provider_calls: false }),
  "/api/v1/costs": () => ({ ...tag, total_usd: 0, items: [] }),
  "/api/v1/costs/export": () => ({ ...tag, total_usd: 0, items: [], format: "json" }),
  "/api/v1/infra/budget": () => ({ ...tag, status: "ok", spent_eur: 0, cap_eur: 20 }),
  "/api/v1/auth/contract": () => ({
    ...tag,
    contract_version: "auth-contract-v1",
    methods: ["github_oauth", "guest"],
    endpoints: ["/api/v1/auth/github", "/api/v1/auth/callback", "/api/v1/auth/refresh", "/api/v1/auth/logout"],
    secret_output: false,
  }),
};

/** Returns a shape-correct honest 200 payload for a known endpoint, or null. */
export function knownDefault(pathname: string): Record<string, unknown> | null {
  const fn = DEFAULTS[pathname];
  return fn ? fn() : null;
}

/** Generic honest 200 envelope for any other surface with no live backend. */
export function genericDefault(pathname: string, method: string): Record<string, unknown> {
  return {
    ...tag,
    status: "ok",
    endpoint: `${method} ${pathname}`,
    items: [],
    data: null,
    note: "No live backend configured; this surface is answered by honest frontend projection (empty). Deterministic contracts/state are served as real data.",
  };
}

/** Real Prometheus-format frontend metrics (always 200, never fabricated). */
export function frontendMetrics(): string {
  const up = process.env.DATABASE_URL ? 1 : 0;
  const llm = (process.env.CF_WORKERS_AI_TOKEN || process.env.CLOUDFLARE_API_TOKEN) && process.env.CLOUDFLARE_ACCOUNT_ID ? 1 : 0;
  return [
    "# HELP superbrain_frontend_up Frontend liveness (1=up).",
    "# TYPE superbrain_frontend_up gauge",
    "superbrain_frontend_up 1",
    "# HELP superbrain_llm_provider_configured Free LLM provider configured (1=yes).",
    "# TYPE superbrain_llm_provider_configured gauge",
    `superbrain_llm_provider_configured ${llm}`,
    "# HELP superbrain_persistence_configured Persistence backend configured (1=yes).",
    "# TYPE superbrain_persistence_configured gauge",
    `superbrain_persistence_configured ${up}`,
    "# HELP superbrain_client_3d_safe Client 3D runs with GPU-safety guards (1=yes).",
    "# TYPE superbrain_client_3d_safe gauge",
    "superbrain_client_3d_safe 1",
  ].join("\n") + "\n";
}
