import * as gh from "../../../../../lib/ghStore";

export const dynamic = "force-dynamic";

const NON_CLAIMS = [
  "This is a read-only GitHub-store audit projection.",
  "Details, prompts, user IDs, session IDs, provider credentials, and secret values are not returned.",
  "No rotation, store write, live provider call, or production rollout is performed or claimed.",
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
      contract_version: "provider-fallback-event-v1",
      evidence_ref: "github_store_redacted_rotation_audit_projection",
      source,
      live_backend: false,
      live_provider_calls: false,
      read_only: true,
      events: [],
      note,
      non_claims: NON_CLAIMS,
    },
    { status, headers: { "x-superbrain-source": source, "cache-control": "no-store" } },
  );
}

export async function GET(req: Request): Promise<Response> {
  if (!gh.ghConfigured()) return emptyResponse("No GitHub store is configured; no rotation events are claimed.");

  try {
    const events = (await gh.list("audit.json", limitFor(req) * 4))
      .filter((row) => row.event_type === "provider_rotated")
      .map((row) => ({ event_type: "provider_rotated", created_at: createdAt(row), severity: severity(row) }))
      .slice(0, limitFor(req));
    return Response.json(
      {
        contract_version: "provider-fallback-event-v1",
        evidence_ref: "github_store_redacted_rotation_audit_projection",
        source: "github-store",
        live_backend: false,
        live_provider_calls: false,
        read_only: true,
        events,
        non_claims: NON_CLAIMS,
      },
      { headers: { "x-superbrain-source": "github-store", "cache-control": "no-store" } },
    );
  } catch {
    return emptyResponse("GitHub store audit data could not be read; no rotation events are claimed.", 502, "github-store");
  }
}
