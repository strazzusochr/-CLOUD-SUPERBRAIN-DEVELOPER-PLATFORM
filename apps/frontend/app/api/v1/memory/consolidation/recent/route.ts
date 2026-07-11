import * as gh from "../../../../../../lib/ghStore";

export const dynamic = "force-dynamic";

const NON_CLAIMS = [
  "This is a read-only GitHub-store audit projection.",
  "Details, prompts, user IDs, session IDs, memory content, vector data, and secret values are not returned.",
  "No memory write, embedding call, live provider call, or production rollout is performed or claimed.",
];

type ConsolidationEventType = "memory_consolidated" | "memory_consolidation_skipped" | "memory_consolidation_blocked";

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

function consolidationType(row: Record<string, unknown>): ConsolidationEventType | null {
  return row.event_type === "memory_consolidated" || row.event_type === "memory_consolidation_skipped" || row.event_type === "memory_consolidation_blocked"
    ? row.event_type
    : null;
}

function summary(events: Array<{ event_type: string; severity: string }>): Array<{ event_type: string; severity: string; count: number }> {
  const counts = new Map<string, number>();
  for (const event of events) counts.set(`${event.event_type}:${event.severity}`, (counts.get(`${event.event_type}:${event.severity}`) ?? 0) + 1);
  return [...counts.entries()].map(([key, count]) => {
    const [event_type, severity] = key.split(":");
    return { event_type, severity, count };
  });
}

function emptyResponse(note: string, status = 200, source = "frontend-projection"): Response {
  return Response.json(
    {
      contract_version: "memory-consolidation-github-audit-projection-v1",
      source,
      live_backend: false,
      read_only: true,
      events: [],
      summary: [],
      note,
      non_claims: NON_CLAIMS,
    },
    { status, headers: { "x-superbrain-source": source, "cache-control": "no-store" } },
  );
}

export async function GET(req: Request): Promise<Response> {
  if (!gh.ghConfigured()) return emptyResponse("No GitHub store is configured; no memory consolidations are claimed.");

  try {
    const events = (await gh.list("audit.json", limitFor(req) * 4))
      .map((row) => ({ event_type: consolidationType(row), created_at: createdAt(row), severity: severity(row) }))
      .filter((row): row is { event_type: ConsolidationEventType; created_at: string | null; severity: "info" | "warning" | "critical" } => row.event_type !== null)
      .slice(0, limitFor(req));
    return Response.json(
      {
        contract_version: "memory-consolidation-github-audit-projection-v1",
        source: "github-store",
        live_backend: false,
        read_only: true,
        events,
        summary: summary(events),
        non_claims: NON_CLAIMS,
      },
      { headers: { "x-superbrain-source": "github-store", "cache-control": "no-store" } },
    );
  } catch {
    return emptyResponse("GitHub store audit data could not be read; no memory consolidations are claimed.", 502, "github-store");
  }
}
