// Free persistent backend on the user's own Cloudflare account, reachable from
// Vercel functions over HTTPS — no credit card, no separate host:
//   • Cloudflare D1     → serverless SQLite (sessions, artifacts, audit)
//   • Cloudflare Vectorize → vector index (pgvector-equivalent long-term memory)
//   • Cloudflare Workers AI → embeddings (bge-base-en-v1.5) + LLM
// Activates when CF_BACKEND_TOKEN + CLOUDFLARE_ACCOUNT_ID + CF_D1_DATABASE_ID are
// set. Every row/vector is really written/read — no fabrication.

const CF_API = "https://api.cloudflare.com/client/v4";

function cfToken(): string | undefined {
  return process.env.CF_BACKEND_TOKEN || process.env.CLOUDFLARE_API_TOKEN;
}
function acct(): string | undefined {
  return process.env.CLOUDFLARE_ACCOUNT_ID?.replace(/^["']|["']$/g, "");
}

export function d1Configured(): boolean {
  return !!(cfToken() && acct() && process.env.CF_D1_DATABASE_ID);
}
export function vectorizeConfigured(): boolean {
  return !!(cfToken() && acct() && process.env.CF_VECTORIZE_INDEX);
}

type D1Row = Record<string, unknown>;

/** Run a parameterized SQL statement against the D1 database. */
export async function d1(sql: string, params: unknown[] = []): Promise<D1Row[]> {
  const db = process.env.CF_D1_DATABASE_ID;
  const res = await fetch(`${CF_API}/accounts/${acct()}/d1/database/${db}/query`, {
    method: "POST",
    headers: { Authorization: `Bearer ${cfToken()}`, "content-type": "application/json" },
    body: JSON.stringify({ sql, params }),
    signal: AbortSignal.timeout(15000),
  });
  const body = (await res.json()) as { success?: boolean; result?: Array<{ results?: D1Row[] }>; errors?: Array<{ message?: string }> };
  if (!res.ok || !body.success) throw new Error(`D1 error: ${body.errors?.map((e) => e.message).join("; ") || res.status}`);
  return body.result?.[0]?.results ?? [];
}

let _schemaReady = false;
export async function ensureSchema(): Promise<void> {
  if (_schemaReady) return;
  await d1(
    `CREATE TABLE IF NOT EXISTS workspace_artifacts (
       id TEXT PRIMARY KEY, project_id TEXT NOT NULL, created_at TEXT NOT NULL,
       source_page TEXT, artifact_type TEXT, title TEXT, summary TEXT,
       run_id TEXT, status TEXT, evidence_ref TEXT, metadata TEXT)`,
  );
  await d1(
    `CREATE TABLE IF NOT EXISTS agent_sessions (
       id TEXT PRIMARY KEY, project_id TEXT NOT NULL, started_at TEXT NOT NULL,
       status TEXT, prompt TEXT, result TEXT, model TEXT)`,
  );
  await d1(
    `CREATE TABLE IF NOT EXISTS audit_log (
       id TEXT PRIMARY KEY, occurred_at TEXT NOT NULL, event_type TEXT NOT NULL,
       session_id TEXT, detail TEXT)`,
  );
  _schemaReady = true;
}

function uuid(): string {
  return (globalThis.crypto?.randomUUID?.() ?? `id-${Date.now()}-${Math.random().toString(16).slice(2)}`);
}

export async function audit(eventType: string, sessionId: string | null, detail = ""): Promise<void> {
  try {
    await d1(`INSERT INTO audit_log (id, occurred_at, event_type, session_id, detail) VALUES (?,?,?,?,?)`, [
      uuid(), new Date().toISOString(), eventType, sessionId, detail,
    ]);
  } catch {
    /* best-effort */
  }
}

// ---- Vectorize (long-term memory) -------------------------------------------

export async function vectorAdd(id: string, values: number[], metadata: Record<string, unknown>): Promise<void> {
  const idx = process.env.CF_VECTORIZE_INDEX;
  const ndjson = JSON.stringify({ id, values, metadata }) + "\n";
  const res = await fetch(`${CF_API}/accounts/${acct()}/vectorize/v2/indexes/${idx}/upsert`, {
    method: "POST",
    headers: { Authorization: `Bearer ${cfToken()}`, "content-type": "application/x-ndjson" },
    body: ndjson,
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error(`Vectorize upsert error: ${res.status}`);
}

export async function vectorQuery(values: number[], topK: number, projectId: string): Promise<Array<{ id: string; score: number; content: string }>> {
  const idx = process.env.CF_VECTORIZE_INDEX;
  const res = await fetch(`${CF_API}/accounts/${acct()}/vectorize/v2/indexes/${idx}/query`, {
    method: "POST",
    headers: { Authorization: `Bearer ${cfToken()}`, "content-type": "application/json" },
    body: JSON.stringify({ vector: values, topK, returnMetadata: "all", filter: { project_id: projectId } }),
    signal: AbortSignal.timeout(15000),
  });
  const body = (await res.json()) as { success?: boolean; result?: { matches?: Array<{ id: string; score: number; metadata?: { content?: string } }> }; errors?: Array<{ message?: string }> };
  if (!res.ok || !body.success) throw new Error(`Vectorize query error: ${body.errors?.map((e) => e.message).join("; ") || res.status}`);
  return (body.result?.matches ?? []).map((m) => ({ id: m.id, score: m.score, content: m.metadata?.content ?? "" }));
}

export { uuid };
