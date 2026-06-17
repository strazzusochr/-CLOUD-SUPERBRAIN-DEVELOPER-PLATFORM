// Real recent sessions from Neon. Honest 503 without DATABASE_URL.
import { dbConfigured, ensureSchema, sql } from "../../../../../lib/neon";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  if (!dbConfigured()) {
    return Response.json(
      { status: "no_live_backend", endpoint: "GET /api/v1/sessions/recent", live_backend: false, note: "Set DATABASE_URL (free Neon) to enable persisted sessions." },
      { status: 503, headers: { "x-superbrain-source": "frontend-no-backend" } },
    );
  }
  const limit = Math.min(Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 10) || 10, 1), 50);
  try {
    await ensureSchema();
    const rows = (await sql()`
      SELECT id AS session_id, project_id, started_at, status, prompt, result, model
      FROM agent_sessions ORDER BY started_at DESC LIMIT ${limit}
    `) as unknown as Array<Record<string, unknown>>;
    const sessions = rows.map((r) => ({
      session_id: r.session_id,
      project_id: r.project_id,
      started_at: r.started_at,
      status: r.status,
      latest_task_status: r.status,
      assistant_result: typeof r.result === "string" ? (r.result as string).slice(0, 600) : null,
    }));
    return Response.json({ sessions }, { headers: { "x-superbrain-source": "neon-postgres" } });
  } catch (err) {
    return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
