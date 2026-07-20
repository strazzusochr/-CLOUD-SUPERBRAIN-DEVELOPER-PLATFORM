import { boundaryUnavailable, projectionResponse, proxyReadToBoundary, proxyToBoundary } from "../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

export async function GET(req: Request): Promise<Response> {
  const response = await proxyReadToBoundary(req, "agent-api", "/api/v1/memory/search", 30_000);
  return response ?? projectionResponse({
    contract_version: "memory-search-v1",
    status: "degraded",
    results: [],
    search_mode: "unavailable_without_agent_api",
    persisted: false,
    note: "Memory search requires the Agent API PostgreSQL/pgvector boundary; no result rows are claimed.",
  });
}

export async function POST(req: Request): Promise<Response> {
  const response = await proxyToBoundary(req, "agent-api", "/api/v1/memory/search", 30_000);
  return response ?? boundaryUnavailable(
    "POST /api/v1/memory/search",
    "agent-api",
    "Frontend memory writes are disabled; memory persistence belongs to the Agent API.",
  );
}
