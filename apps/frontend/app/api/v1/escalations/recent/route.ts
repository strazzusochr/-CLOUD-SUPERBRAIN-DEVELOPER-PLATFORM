import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";

const NON_CLAIMS = [
  "This is a read-only GitHub-store audit projection.",
  "Details, prompts, user IDs, session IDs, request IDs, trace IDs, and secret values are not returned.",
  "No escalation action, store write, live provider call, or production rollout is performed or claimed.",
];

function limitFor(req: Request): number {
  return Math.min(Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 20) || 20, 1), 100);
}

function createdAt(row: Record<string, unknown>): string | null {
  const value = row.occurred_at ?? row.created_at;
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) return null;
  return new Date(value).toISOString();
}

function escalation(row: Record<string, unknown>): { event_type: string; created_at: string | null; severity: "critical" } | null {
  if (row.event_type === "task_escalated") return { event_type: "task_escalated", created_at: createdAt(row), severity: "critical" };
  if (row.severity === "critical") return { event_type: "critical_audit_event", created_at: createdAt(row), severity: "critical" };
  return null;
}

function emptyResponse(note: string, status = 200, source = "frontend-projection"): Response {
  return Response.json(
    {
      contract_version: "escalation-github-audit-projection-v1",
      source,
      live_backend: false,
      read_only: true,
      events: [],
      escalations: [],
      note,
      non_claims: NON_CLAIMS,
    },
    { status, headers: { "x-superbrain-source": source, "cache-control": "no-store" } },
  );
}

export async function GET(req: Request): Promise<Response> {
  if (!gh.ghConfigured()) return emptyResponse("No GitHub store is configured; no escalations are claimed.");

  try {
    const events = (await gh.list("audit.json", limitFor(req) * 4))
      .map(escalation)
      .filter((row): row is { event_type: string; created_at: string | null; severity: "critical" } => row !== null)
      .slice(0, limitFor(req));
    return Response.json(
      {
        contract_version: "escalation-github-audit-projection-v1",
        source: "github-store",
        live_backend: false,
        read_only: true,
        events,
        escalations: events,
        non_claims: NON_CLAIMS,
      },
      { headers: { "x-superbrain-source": "github-store", "cache-control": "no-store" } },
    );
  } catch {
    return emptyResponse("GitHub store audit data could not be read; no escalations are claimed.", 502, "github-store");
  }
}
