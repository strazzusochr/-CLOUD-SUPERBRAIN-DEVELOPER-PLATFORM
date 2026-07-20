import { proxyToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/health");
  if (response) return response;
  return Response.json(
    {
      status: "ok",
      service: "cloud-superbrain-frontend",
      mode: "frontend-projection",
      time: new Date().toISOString(),
      boundary_mode: "stateless_contract_origin",
      capabilities: { agent_api: null, llm_gateway: null, mcp_gateway: null, persistence: null, client_3d: true },
      direct_provider_calls: false,
      live_provider_calls: false,
      live_mcp_writes: false,
      production_deploy: false,
      note: "Frontend liveness only. Stateful capabilities require their configured service boundaries.",
    },
    { headers: { "x-superbrain-source": "frontend-health" } },
  );
}
