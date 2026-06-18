// Lists previously built apps (newest first) for the "Meine Apps" gallery.
// Honest empty 200 when no store is configured.
import * as gh from "../../../../lib/ghStore";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const limit = Math.min(Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 24) || 24, 1), 100);
  if (!gh.ghConfigured()) {
    return Response.json({ builds: [], live_backend: false, source: "frontend-projection", note: "No store configured." }, { headers: { "x-superbrain-source": "frontend-projection" } });
  }
  try {
    const builds = await gh.list("builds.json", limit);
    return Response.json({ builds }, { headers: { "x-superbrain-source": "github-store" } });
  } catch (err) {
    return Response.json({ status: "store_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
