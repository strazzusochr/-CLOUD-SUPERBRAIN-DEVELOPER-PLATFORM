// Real persistent workspace artifacts. Prefers Cloudflare D1 (free, user's account),
// falls back to Neon Postgres, else honest empty 200 (genuinely no artifacts yet).
// Used by /games, /apps, /media, /docs-output, /marketplace (goal-b-actions).

import { dbConfigured, ensureSchema as neonEnsure, sql, audit as neonAudit } from "../../../../../lib/neon";
import * as cf from "../../../../../lib/cfBackend";
import * as gh from "../../../../../lib/ghStore";

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

function emptyGet(): Response {
  return Response.json(
    { artifacts: [], count: 0, live_backend: false, source: "frontend-projection", note: "No persistence configured; set CF_BACKEND_TOKEN+CF_D1_DATABASE_ID (free Cloudflare D1) to persist artifacts." },
    { headers: { "x-superbrain-source": "frontend-projection" } },
  );
}

export async function GET(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const projectId = url.searchParams.get("project_id") ?? "default";
  const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 8) || 8, 1), 50);

  if (cf.d1Configured()) {
    try {
      await cf.ensureSchema();
      const rows = (await cf.d1(
        `SELECT id, created_at, source_page, artifact_type, title, summary, run_id, status, evidence_ref
         FROM workspace_artifacts WHERE project_id = ? ORDER BY created_at DESC LIMIT ?`,
        [projectId, limit],
      )) as unknown as ArtifactRow[];
      return Response.json({ artifacts: rows, count: rows.length }, { headers: { "x-superbrain-source": "cloudflare-d1" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }

  if (dbConfigured()) {
    try {
      await neonEnsure();
      const rows = (await sql()`
        SELECT id, created_at, source_page, artifact_type, title, summary, run_id, status, evidence_ref
        FROM workspace_artifacts WHERE project_id = ${projectId} ORDER BY created_at DESC LIMIT ${limit}
      `) as unknown as ArtifactRow[];
      return Response.json({ artifacts: rows, count: rows.length }, { headers: { "x-superbrain-source": "neon-postgres" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  if (gh.ghConfigured()) {
    try {
      const rows = await gh.list("artifacts.json", limit, (a) => a.project_id === projectId);
      return Response.json({ artifacts: rows, count: rows.length }, { headers: { "x-superbrain-source": "github-store" } });
    } catch (err) {
      return Response.json({ status: "store_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  return emptyGet();
}

export async function POST(req: Request): Promise<Response> {
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const a = {
    projectId: String(body.project_id ?? "default"),
    sourcePage: String(body.source_page ?? "unknown"),
    artifactType: String(body.artifact_type ?? "artifact"),
    title: String(body.title ?? "Untitled"),
    summary: String(body.summary ?? ""),
    runId: body.run_id != null ? String(body.run_id) : null,
    status: String(body.status ?? "ready"),
    evidenceRef: String(body.evidence_ref ?? `${String(body.source_page ?? "unknown")}:${String(body.artifact_type ?? "artifact")}`),
    metadata: JSON.stringify(body.metadata ?? {}),
  };

  if (cf.d1Configured()) {
    try {
      await cf.ensureSchema();
      const id = cf.uuid();
      const created_at = new Date().toISOString();
      await cf.d1(
        `INSERT INTO workspace_artifacts (id, project_id, created_at, source_page, artifact_type, title, summary, run_id, status, evidence_ref, metadata)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
        [id, a.projectId, created_at, a.sourcePage, a.artifactType, a.title, a.summary, a.runId, a.status, a.evidenceRef, a.metadata],
      );
      await cf.audit("artifact_created", null, `${a.sourcePage}/${a.artifactType}`);
      return Response.json(
        { artifact: { id, created_at, source_page: a.sourcePage, artifact_type: a.artifactType, title: a.title, summary: a.summary, run_id: a.runId, status: a.status, evidence_ref: a.evidenceRef } },
        { status: 201, headers: { "x-superbrain-source": "cloudflare-d1" } },
      );
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }

  if (dbConfigured()) {
    try {
      await neonEnsure();
      const rows = (await sql()`
        INSERT INTO workspace_artifacts (project_id, source_page, artifact_type, title, summary, run_id, status, evidence_ref, metadata)
        VALUES (${a.projectId}, ${a.sourcePage}, ${a.artifactType}, ${a.title}, ${a.summary}, ${a.runId}, ${a.status}, ${a.evidenceRef}, ${a.metadata}::jsonb)
        RETURNING id, created_at, source_page, artifact_type, title, summary, run_id, status, evidence_ref
      `) as unknown as ArtifactRow[];
      await neonAudit("artifact_created", null, `${a.sourcePage}/${a.artifactType}`);
      return Response.json({ artifact: rows[0] }, { status: 201, headers: { "x-superbrain-source": "neon-postgres" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  if (gh.ghConfigured()) {
    try {
      const row = {
        id: gh.uuid(), project_id: a.projectId, created_at: new Date().toISOString(),
        source_page: a.sourcePage, artifact_type: a.artifactType, title: a.title, summary: a.summary,
        run_id: a.runId, status: a.status, evidence_ref: a.evidenceRef,
      };
      await gh.append("artifacts.json", row, 1000);
      await gh.audit("artifact_created", null, `${a.sourcePage}/${a.artifactType}`);
      return Response.json({ artifact: row }, { status: 201, headers: { "x-superbrain-source": "github-store" } });
    } catch (err) {
      return Response.json({ status: "store_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  return Response.json(
    { artifact: null, persisted: false, live_backend: false, source: "frontend-projection", note: "Accepted but not persisted — no store configured." },
    { headers: { "x-superbrain-source": "frontend-projection" } },
  );
}
