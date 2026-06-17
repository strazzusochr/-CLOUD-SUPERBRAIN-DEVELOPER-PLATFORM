// Real persistent workspace artifacts on the free Neon Postgres backend.
// Used by /games, /apps, /media, /docs-output, /marketplace (goal-b-actions).
// POST creates, GET lists — genuinely persisted. Honest 503 when DATABASE_URL unset.

import { dbConfigured, ensureSchema, sql, audit } from "../../../../../lib/neon";

export const dynamic = "force-dynamic";

type ArtifactRow = {
  id: string;
  created_at: string;
  source_page: string;
  artifact_type: string;
  title: string;
  summary: string;
  run_id: string | null;
  status: string;
  evidence_ref: string;
};

function noDb(method: string): Response {
  return Response.json(
    {
      status: "no_live_backend",
      endpoint: `${method} /api/v1/workspace/artifacts`,
      live_backend: false,
      note: "Persistent artifacts need a database. Set DATABASE_URL (free Neon Postgres) to enable real persistence.",
    },
    { status: 503, headers: { "x-superbrain-source": "frontend-no-backend" } },
  );
}

export async function GET(req: Request): Promise<Response> {
  if (!dbConfigured()) return noDb("GET");
  const url = new URL(req.url);
  const projectId = url.searchParams.get("project_id") ?? "default";
  const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 8) || 8, 1), 50);
  try {
    await ensureSchema();
    const rows = (await sql()`
      SELECT id, created_at, source_page, artifact_type, title, summary, run_id, status, evidence_ref
      FROM workspace_artifacts WHERE project_id = ${projectId}
      ORDER BY created_at DESC LIMIT ${limit}
    `) as unknown as ArtifactRow[];
    return Response.json({ artifacts: rows, count: rows.length }, { headers: { "x-superbrain-source": "neon-postgres" } });
  } catch (err) {
    return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}

export async function POST(req: Request): Promise<Response> {
  if (!dbConfigured()) return noDb("POST");
  let body: Record<string, unknown> = {};
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    /* empty */
  }
  const projectId = String(body.project_id ?? "default");
  const sourcePage = String(body.source_page ?? "unknown");
  const artifactType = String(body.artifact_type ?? "artifact");
  const title = String(body.title ?? "Untitled");
  const summary = String(body.summary ?? "");
  const runId = body.run_id != null ? String(body.run_id) : null;
  const status = String(body.status ?? "ready");
  const evidenceRef = String(body.evidence_ref ?? `${sourcePage}:${artifactType}`);
  const metadata = JSON.stringify(body.metadata ?? {});
  try {
    await ensureSchema();
    const rows = (await sql()`
      INSERT INTO workspace_artifacts (project_id, source_page, artifact_type, title, summary, run_id, status, evidence_ref, metadata)
      VALUES (${projectId}, ${sourcePage}, ${artifactType}, ${title}, ${summary}, ${runId}, ${status}, ${evidenceRef}, ${metadata}::jsonb)
      RETURNING id, created_at, source_page, artifact_type, title, summary, run_id, status, evidence_ref
    `) as unknown as ArtifactRow[];
    await audit("artifact_created", null, `${sourcePage}/${artifactType}`);
    return Response.json({ artifact: rows[0] }, { status: 201, headers: { "x-superbrain-source": "neon-postgres" } });
  } catch (err) {
    return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
