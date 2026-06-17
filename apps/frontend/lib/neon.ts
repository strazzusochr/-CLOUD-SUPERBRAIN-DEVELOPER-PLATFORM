// Free persistent backend via Neon Postgres (serverless driver), reachable from
// Vercel functions. Activates when DATABASE_URL is set; otherwise callers return
// an honest 503. pgvector-backed memory uses Cloudflare Workers AI embeddings.
// No fabricated data: every row is really written/read.

import { neon, type NeonQueryFunction } from "@neondatabase/serverless";

let _sql: NeonQueryFunction<false, false> | null = null;
let _schemaReady = false;
let _vectorReady = false;

export function vectorReady(): boolean {
  return _vectorReady;
}

export function dbConfigured(): boolean {
  return !!process.env.DATABASE_URL;
}

export function sql(): NeonQueryFunction<false, false> {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL not configured");
  if (!_sql) _sql = neon(process.env.DATABASE_URL);
  return _sql;
}

/** Lazily create the minimal schema this free Vercel backend needs (idempotent). */
export async function ensureSchema(): Promise<void> {
  if (_schemaReady) return;
  const db = sql();
  await db`CREATE EXTENSION IF NOT EXISTS pgcrypto`;
  await db`
    CREATE TABLE IF NOT EXISTS workspace_artifacts (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      project_id TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      source_page TEXT NOT NULL,
      artifact_type TEXT NOT NULL,
      title TEXT NOT NULL,
      summary TEXT NOT NULL DEFAULT '',
      run_id TEXT,
      status TEXT NOT NULL DEFAULT 'ready',
      evidence_ref TEXT NOT NULL DEFAULT '',
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb
    )`;
  await db`
    CREATE TABLE IF NOT EXISTS agent_sessions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      project_id TEXT NOT NULL,
      started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      status TEXT NOT NULL DEFAULT 'completed',
      prompt TEXT NOT NULL DEFAULT '',
      result TEXT NOT NULL DEFAULT '',
      model TEXT
    )`;
  await db`
    CREATE TABLE IF NOT EXISTS audit_log (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      event_type TEXT NOT NULL,
      session_id UUID,
      detail TEXT NOT NULL DEFAULT ''
    )`;
  // pgvector-backed long-term memory. Embeddings are 768-dim (CF bge-base-en-v1.5).
  try {
    await db`CREATE EXTENSION IF NOT EXISTS vector`;
    await db`
      CREATE TABLE IF NOT EXISTS memory_items (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        project_id TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        content TEXT NOT NULL,
        embedding vector(768)
      )`;
    _vectorReady = true;
  } catch {
    _vectorReady = false; // pgvector unavailable → memory-search degrades honestly
  }
  _schemaReady = true;
}

export async function audit(eventType: string, sessionId: string | null, detail = ""): Promise<void> {
  try {
    const db = sql();
    await db`INSERT INTO audit_log (event_type, session_id, detail) VALUES (${eventType}, ${sessionId}, ${detail})`;
  } catch {
    /* audit is best-effort */
  }
}
