// Real recent audit events from Neon. Honest 503 without DATABASE_URL.
import { dbConfigured, ensureSchema, sql } from "../../../../../lib/neon";
import * as cf from "../../../../../lib/cfBackend";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const lim = Math.min(Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 20) || 20, 1), 100);
  if (cf.d1Configured()) {
    try {
      await cf.ensureSchema();
      const events = (await cf.d1(
        `SELECT id, occurred_at, event_type, session_id, detail FROM audit_log ORDER BY occurred_at DESC LIMIT ?`,
        [lim],
      )) as Array<Record<string, unknown>>;
      return Response.json({ events }, { headers: { "x-superbrain-source": "cloudflare-d1" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  if (!dbConfigured()) {
    return Response.json(
      { events: [], live_backend: false, source: "frontend-projection", note: "No persistence configured; set DATABASE_URL (free Neon) for a persisted audit log." },
      { headers: { "x-superbrain-source": "frontend-projection" } },
    );
  }
  const limit = Math.min(Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 20) || 20, 1), 100);
  try {
    await ensureSchema();
    const rows = (await sql()`
      SELECT id, occurred_at, event_type, session_id, detail FROM audit_log ORDER BY occurred_at DESC LIMIT ${limit}
    `) as unknown as Array<Record<string, unknown>>;
    return Response.json({ events: rows }, { headers: { "x-superbrain-source": "neon-postgres" } });
  } catch (err) {
    return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
