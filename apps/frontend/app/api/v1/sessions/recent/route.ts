// Real recent sessions from Neon. Honest 503 without DATABASE_URL.
import { dbConfigured, ensureSchema, sql } from "../../../../../lib/neon";
import * as cf from "../../../../../lib/cfBackend";

export const dynamic = "force-dynamic";

export async function GET(req: Request): Promise<Response> {
  const lim = Math.min(Math.max(Number(new URL(req.url).searchParams.get("limit") ?? 10) || 10, 1), 50);
  if (cf.d1Configured()) {
    try {
      await cf.ensureSchema();
      const rows = (await cf.d1(
        `SELECT id AS session_id, project_id, started_at, status, result FROM agent_sessions ORDER BY started_at DESC LIMIT ?`,
        [lim],
      )) as Array<Record<string, unknown>>;
      const sessions = rows.map((r) => ({
        session_id: r.session_id, project_id: r.project_id, started_at: r.started_at,
        status: r.status, latest_task_status: r.status,
        assistant_result: typeof r.result === "string" ? (r.result as string).slice(0, 600) : null,
      }));
      return Response.json({ sessions }, { headers: { "x-superbrain-source": "cloudflare-d1" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  if (!dbConfigured()) {
    // Honest 200: no persistence yet → genuinely no sessions.
    return Response.json(
      { sessions: [], live_backend: false, source: "frontend-projection", note: "No persistence configured; set DATABASE_URL (free Neon) to persist sessions." },
      { headers: { "x-superbrain-source": "frontend-projection" } },
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
