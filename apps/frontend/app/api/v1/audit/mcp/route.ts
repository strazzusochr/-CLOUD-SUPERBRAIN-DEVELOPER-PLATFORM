import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";

const NON_CLAIMS = [
  "This is a read-only GitHub-store audit projection.",
  "Details, prompts, user IDs, session IDs, trace IDs, tool inputs, and secret values are not returned.",
  "No tool execution, store write, live provider call, or production rollout is performed or claimed.",
];

function limitFor(req: Request): number {
  return Math.min(Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 20) || 20, 1), 100);
}

function createdAt(row: Record<string, unknown>): string | null {
  const value = row.occurred_at ?? row.created_at;
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) return null;
  return new Date(value).toISOString();
}

function severity(row: Record<string, unknown>): "info" | "warning" | "critical" {
  return row.severity === "critical" || row.severity === "warning" ? row.severity : "info";
}

function emptyResponse(note: string, status = 200, source = "frontend-projection"): Response {
  return Response.json(
    {
      contract_version: "mcp-audit-github-audit-projection-v1",
      source,
      live_backend: false,
      read_only: true,
      events: [],
      note,
      non_claims: NON_CLAIMS,
    },
    { status, headers: { "x-superbrain-source": source, "cache-control": "no-store" } },
  );
}

export async function GET(req: Request): Promise<Response> {
  if (!gh.ghConfigured()) return emptyResponse("No GitHub store is configured; no MCP audit events are claimed.");

  try {
    const events = (await gh.list("audit.json", limitFor(req) * 4))
      .filter((row) => row.event_type === "mcp_tool_executed" || row.event_type === "tool_executed")
      .map((row) => ({ event_type: "mcp_tool_executed", created_at: createdAt(row), severity: severity(row) }))
      .slice(0, limitFor(req));
    return Response.json(
      {
        contract_version: "mcp-audit-github-audit-projection-v1",
        source: "github-store",
        live_backend: false,
        read_only: true,
        events,
        non_claims: NON_CLAIMS,
      },
      { headers: { "x-superbrain-source": "github-store", "cache-control": "no-store" } },
    );
  } catch {
    return emptyResponse("GitHub store audit data could not be read; no MCP audit events are claimed.", 502, "github-store");
  }
}
