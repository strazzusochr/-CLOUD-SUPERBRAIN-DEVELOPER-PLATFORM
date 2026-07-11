import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";

const NON_CLAIMS = [
  "This is a read-only GitHub-store audit projection.",
  "Details, prompts, user IDs, session IDs, trace IDs, and secret values are not returned.",
  "No store write, live provider call, or production rollout is performed or claimed.",
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

function activityType(row: Record<string, unknown>): string | null {
  switch (row.event_type) {
    case "agent_started":
    case "agent_completed":
    case "agent_failed":
    case "task_assigned":
    case "task_completed":
    case "task_escalated":
      return String(row.event_type);
    case "prompt_completed":
      return "agent_prompt_completed";
    default:
      return null;
  }
}

function emptyResponse(note: string, status = 200, source = "frontend-projection"): Response {
  return Response.json(
    {
      contract_version: "agent-activity-github-audit-projection-v1",
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
  if (!gh.ghConfigured()) return emptyResponse("No GitHub store is configured; no agent activity is claimed.");

  try {
    const events = (await gh.list("audit.json", limitFor(req) * 4))
      .map((row) => ({ event_type: activityType(row), created_at: createdAt(row), severity: severity(row) }))
      .filter((row): row is { event_type: string; created_at: string | null; severity: "info" | "warning" | "critical" } => row.event_type !== null)
      .slice(0, limitFor(req));
    return Response.json(
      {
        contract_version: "agent-activity-github-audit-projection-v1",
        source: "github-store",
        live_backend: false,
        read_only: true,
        events,
        non_claims: NON_CLAIMS,
      },
      { headers: { "x-superbrain-source": "github-store", "cache-control": "no-store" } },
    );
  } catch {
    return emptyResponse("GitHub store audit data could not be read; no agent activity is claimed.", 502, "github-store");
  }
}
