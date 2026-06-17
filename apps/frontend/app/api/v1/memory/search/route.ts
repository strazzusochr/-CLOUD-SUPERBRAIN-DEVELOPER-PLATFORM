// Real semantic memory. Prefers Cloudflare Vectorize (free, user's account) with
// free CF Workers AI embeddings; falls back to Neon pgvector; else honest empty 200.
// GET ?q=&project_id= → search. POST {content, project_id} → store memory.

import { dbConfigured, ensureSchema, sql, vectorReady } from "../../../../../lib/neon";
import { cfConfigured, cfEmbed } from "../../../../../lib/cfWorkersAi";
import * as cf from "../../../../../lib/cfBackend";
import * as gh from "../../../../../lib/ghStore";

const BGE_QUERY_PREFIX = "Represent this sentence for searching relevant passages: ";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

function empty(method: string): Response {
  const data = method === "POST" ? { stored: null, persisted: false } : { results: [] };
  return Response.json(
    { ...data, live_backend: false, source: "frontend-projection", note: "Set CF_BACKEND_TOKEN + CF_VECTORIZE_INDEX (free Cloudflare Vectorize) to enable semantic memory." },
    { headers: { "x-superbrain-source": "frontend-projection" } },
  );
}
function vecLiteral(v: number[]): string {
  return `[${v.join(",")}]`;
}

export async function POST(req: Request): Promise<Response> {
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const content = String(body.content ?? "").trim();
  const projectId = String(body.project_id ?? "default");
  if (!content) return Response.json({ status: "bad_request", note: "Feld 'content' erforderlich." }, { status: 400 });

  if (cf.vectorizeConfigured() && cfConfigured()) {
    try {
      const emb = await cfEmbed(content);
      const id = cf.uuid();
      await cf.vectorAdd(id, emb, { project_id: projectId, content });
      return Response.json({ stored: { id }, persisted: true }, { status: 201, headers: { "x-superbrain-source": "cloudflare-vectorize" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }

  if (dbConfigured() && cfConfigured()) {
    try {
      await ensureSchema();
      if (!vectorReady()) return empty("POST");
      const emb = await cfEmbed(content);
      const rows = (await sql()`
        INSERT INTO memory_items (project_id, content, embedding) VALUES (${projectId}, ${content}, ${vecLiteral(emb)}::vector) RETURNING id, created_at
      `) as unknown as Array<{ id: string; created_at: string }>;
      return Response.json({ stored: rows[0], persisted: true }, { status: 201, headers: { "x-superbrain-source": "neon-pgvector" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }

  if (gh.ghConfigured() && cfConfigured()) {
    try {
      const vec = gh.normalize(await cfEmbed(content)); // passage embedding (no query prefix)
      const id = gh.uuid();
      await gh.append("memory.json", { id, project_id: projectId, content, created_at: new Date().toISOString(), vec }, 500);
      return Response.json({ stored: { id }, persisted: true }, { status: 201, headers: { "x-superbrain-source": "github-store" } });
    } catch (err) {
      return Response.json({ status: "store_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  return empty("POST");
}

export async function GET(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const q = (url.searchParams.get("q") ?? url.searchParams.get("query") ?? "").trim();
  const projectId = url.searchParams.get("project_id") ?? "default";
  const limit = Math.min(Math.max(Number(url.searchParams.get("limit") ?? 5) || 5, 1), 20);
  if (!q) return Response.json({ results: [], note: "Query 'q' leer." });

  if (cf.vectorizeConfigured() && cfConfigured()) {
    try {
      const emb = await cfEmbed(q);
      const results = await cf.vectorQuery(emb, limit, projectId);
      return Response.json({ query: q, results }, { headers: { "x-superbrain-source": "cloudflare-vectorize" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }

  if (dbConfigured() && cfConfigured()) {
    try {
      await ensureSchema();
      if (!vectorReady()) return empty("GET");
      const emb = await cfEmbed(q);
      const results = (await sql()`
        SELECT id, content, created_at, 1 - (embedding <=> ${vecLiteral(emb)}::vector) AS score
        FROM memory_items WHERE project_id = ${projectId}
        ORDER BY embedding <=> ${vecLiteral(emb)}::vector LIMIT ${limit}
      `) as unknown as Array<Record<string, unknown>>;
      return Response.json({ query: q, results }, { headers: { "x-superbrain-source": "neon-pgvector" } });
    } catch (err) {
      return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }

  if (gh.ghConfigured() && cfConfigured()) {
    try {
      const qvec = gh.normalize(await cfEmbed(BGE_QUERY_PREFIX + q));
      const rows = await gh.list("memory.json", 1000, (m) => m.project_id === projectId);
      const results = rows
        .map((m) => ({ id: m.id, content: m.content, score: gh.cosine(qvec, (m.vec as number[]) ?? []) }))
        .sort((a, b) => b.score - a.score)
        .slice(0, limit);
      return Response.json({ query: q, results }, { headers: { "x-superbrain-source": "github-store" } });
    } catch (err) {
      return Response.json({ status: "store_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  return empty("GET");
}
