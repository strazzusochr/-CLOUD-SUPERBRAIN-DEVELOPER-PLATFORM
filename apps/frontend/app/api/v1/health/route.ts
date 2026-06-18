// Real liveness/health for the deployed frontend. Always 200 (the frontend IS up
// if this responds). Honestly reports which optional backends are wired, without
// ever exposing secret values — just booleans. Overrides the catch-all 503.

export const dynamic = "force-dynamic";

export function GET(): Response {
  const llm = !!((process.env.CF_WORKERS_AI_TOKEN || process.env.CF_BACKEND_TOKEN || process.env.CLOUDFLARE_API_TOKEN) && process.env.CLOUDFLARE_ACCOUNT_ID);
  const d1 = !!(process.env.CF_BACKEND_TOKEN && process.env.CF_D1_DATABASE_ID && process.env.CLOUDFLARE_ACCOUNT_ID);
  const ghStore = !!((process.env.GH_STORE_TOKEN || process.env.GITHUB_TOKEN) && process.env.GH_STORE_REPO);
  const agentApi = !!(process.env.AGENT_API_BASE_URL || process.env.AGENT_API_INTERNAL_URL);
  return Response.json(
    {
      status: "ok",
      service: "cloud-superbrain-frontend",
      mode: "frontend-projection",
      time: new Date().toISOString(),
      capabilities: {
        llm_provider: llm ? "cloudflare_workers_ai" : null,
        persistence: d1 ? "cloudflare_d1" : process.env.DATABASE_URL ? "neon_postgres" : ghStore ? "github_store" : null,
        live_agent_api: agentApi,
        client_3d: true,
      },
      note: "Frontend is live. Deterministic surfaces are served by projection; DB/LLM-backed surfaces activate when their env is configured.",
    },
    { headers: { "x-superbrain-source": "frontend-health" } },
  );
}
