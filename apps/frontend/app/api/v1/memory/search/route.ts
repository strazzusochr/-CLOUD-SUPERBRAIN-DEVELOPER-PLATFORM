// Real pgvector memory search on free Neon, embeddings via free CF Workers AI.
// GET ?q=&project_id= → semantic search. POST {content, project_id} → store memory.
// Honest 503 without DATABASE_URL; honest note if pgvector/embeddings unavailable.

import { dbConfigured, ensureSchema, sql, vectorReady } from "../../../../../lib/neon";
import { cfConfigured, cfEmbed } from "../../../../../lib/cfWorkersAi";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

function noDb(method: string): Response {
  return Response.json(
    { status: "no_live_backend", endpoint: `${method} /api/v1/memory/search`, live_backend: false, note: "Set DATABASE_URL (free Neon) + CF_WORKERS_AI_TOKEN to enable pgvector memory." },
    { status: 503, headers: { "x-superbrain-source": "frontend-no-backend" } },
  );
}

function vecLiteral(v: number[]): string {
  return `[${v.join(",")}]`;
}

export async function POST(req: Request): Promise<Response> {
  if (!dbConfigured() || !cfConfigured()) return noDb("POST");
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const content = String(body.content ?? "").trim();
  const projectId = String(body.project_id ?? "default");
  if (!content) return Response.json({ status: "bad_request", note: "Feld 'content' erforderlich." }, { status: 400 });
  try {
    await ensureSchema();
    if (!vectorReady()) return Response.json({ status: "vector_unavailable", note: "pgvector extension not available on this database." }, { status: 503 });
    const emb = await cfEmbed(content);
    const rows = (await sql()`
      INSERT INTO memory_items (project_id, content, embedding)
      VALUES (${projectId}, ${content}, ${vecLiteral(emb)}::vector) RETURNING id, created_at
    `) as unknown as Array<{ id: string; created_at: string }>;
    return Response.json({ stored: rows[0] }, { status: 201, headers: { "x-superbrain-source": "neon-pgvector+cloudflare-workers-ai" } });
  } catch (err) {
    return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}

export async function GET(req: Request): Promise<Response> {
  if (!dbConfigured() || !cfConfigured()) return noDb("GET");
  const url = new URL(req.url);
  const q = (url.searchParams.get("q") ?? url.searchParams.get("query") ?? "").trim();
  const projectId = url.searchParams.get("project_id") ?? "default";
  const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 5) || 5, 1), 20);
  if (!q) return Response.json({ status: "bad_request", note: "Query 'q' erforderlich." }, { status: 400 });
  try {
    await ensureSchema();
    if (!vectorReady()) return Response.json({ status: "vector_unavailable", note: "pgvector extension not available." }, { status: 503 });
    const emb = await cfEmbed(q);
    const rows = (await sql()`
      SELECT id, content, created_at, 1 - (embedding <=> ${vecLiteral(emb)}::vector) AS score
      FROM memory_items WHERE project_id = ${projectId}
      ORDER BY embedding <=> ${vecLiteral(emb)}::vector LIMIT ${limit}
    `) as unknown as Array<Record<string, unknown>>;
    return Response.json({ query: q, results: rows }, { headers: { "x-superbrain-source": "neon-pgvector+cloudflare-workers-ai" } });
  } catch (err) {
    return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
