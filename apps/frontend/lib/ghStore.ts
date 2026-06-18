// Free zero-setup persistence on the user's own GitHub: a PRIVATE data repo used
// as a JSON store via the Contents API (SHA-based optimistic locking + retry).
// Activates when GITHUB_TOKEN (or GH_STORE_TOKEN) + GH_STORE_REPO are set. A
// separate repo (not the app repo) so data writes never trigger Vercel builds.
// Reviewed approach: append-merge logs, conditional writes, capped collections.

const API = "https://api.github.com";

function token(): string | undefined {
  return process.env.GH_STORE_TOKEN || process.env.GITHUB_TOKEN;
}
function repo(): string | undefined {
  return process.env.GH_STORE_REPO; // e.g. "owner/cloud-superbrain-data"
}
function branch(): string {
  return process.env.GH_STORE_BRANCH || "main";
}

export function ghConfigured(): boolean {
  return !!(token() && repo());
}

function headers(): Record<string, string> {
  return { Authorization: `Bearer ${token()}`, Accept: "application/vnd.github+json", "content-type": "application/json" };
}

type FileState = { data: unknown[]; sha: string | null };

async function readFile(file: string): Promise<FileState> {
  const res = await fetch(`${API}/repos/${repo()}/contents/${file}?ref=${branch()}`, {
    headers: headers(),
    cache: "no-store",
    signal: AbortSignal.timeout(12000),
  });
  if (res.status === 404) return { data: [], sha: null };
  if (!res.ok) throw new Error(`gh read ${file}: ${res.status}`);
  const body = (await res.json()) as { content?: string; sha?: string };
  let data: unknown[] = [];
  try {
    const json = Buffer.from(body.content ?? "", "base64").toString("utf-8");
    const parsed = JSON.parse(json || "[]");
    data = Array.isArray(parsed) ? parsed : [];
  } catch {
    data = [];
  }
  return { data, sha: body.sha ?? null };
}

async function putFile(file: string, data: unknown[], sha: string | null): Promise<boolean> {
  const content = Buffer.from(JSON.stringify(data)).toString("base64");
  const res = await fetch(`${API}/repos/${repo()}/contents/${file}`, {
    method: "PUT",
    headers: headers(),
    body: JSON.stringify({ message: `data: update ${file}`, content, sha: sha ?? undefined, branch: branch() }),
    signal: AbortSignal.timeout(12000),
  });
  if (res.status === 409 || res.status === 422) return false; // sha conflict → retry
  if (!res.ok) throw new Error(`gh write ${file}: ${res.status}`);
  return true;
}

/** Read → mutate → write with optimistic-lock retry on conflict. Returns final data. */
export async function mutate(file: string, fn: (data: unknown[]) => unknown[]): Promise<unknown[]> {
  for (let attempt = 0; attempt < 4; attempt++) {
    const { data, sha } = await readFile(file);
    const next = fn([...data]);
    if (await putFile(file, next, sha)) return next;
    await new Promise((r) => setTimeout(r, 120 * (attempt + 1)));
  }
  throw new Error(`gh write ${file}: conflict after retries`);
}

/** Prepend an item to a log file, optionally capping the collection size. */
export async function append(file: string, item: Record<string, unknown>, cap = 0): Promise<void> {
  await mutate(file, (data) => {
    const arr = [item, ...data];
    return cap > 0 ? arr.slice(0, cap) : arr;
  });
}

/** Read a collection (newest-first as stored), optionally filtered + limited. */
export async function list(file: string, limit = 20, filter?: (x: Record<string, unknown>) => boolean): Promise<Record<string, unknown>[]> {
  const { data } = await readFile(file);
  let rows = data as Record<string, unknown>[];
  if (filter) rows = rows.filter(filter);
  return rows.slice(0, limit);
}

/** Write a raw (non-JSON) file, e.g. a built app's HTML. Optimistic-lock retry. */
export async function putRaw(path: string, content: string): Promise<void> {
  for (let attempt = 0; attempt < 4; attempt++) {
    const cur = await fetch(`${API}/repos/${repo()}/contents/${path}?ref=${branch()}`, { headers: headers(), cache: "no-store", signal: AbortSignal.timeout(12000) });
    const sha = cur.ok ? ((await cur.json()) as { sha?: string }).sha : undefined;
    const res = await fetch(`${API}/repos/${repo()}/contents/${path}`, {
      method: "PUT",
      headers: headers(),
      body: JSON.stringify({ message: `app: ${path}`, content: Buffer.from(content).toString("base64"), sha, branch: branch() }),
      signal: AbortSignal.timeout(12000),
    });
    if (res.ok) return;
    if (res.status !== 409 && res.status !== 422) throw new Error(`gh putRaw ${path}: ${res.status}`);
    await new Promise((r) => setTimeout(r, 120 * (attempt + 1)));
  }
  throw new Error(`gh putRaw ${path}: conflict`);
}

/** Delete a stored file (best-effort; ignores missing). */
export async function deleteRaw(path: string): Promise<void> {
  const cur = await fetch(`${API}/repos/${repo()}/contents/${path}?ref=${branch()}`, { headers: headers(), cache: "no-store", signal: AbortSignal.timeout(12000) });
  if (cur.status === 404) return;
  if (!cur.ok) throw new Error(`gh delete stat ${path}: ${cur.status}`);
  const sha = ((await cur.json()) as { sha?: string }).sha;
  const res = await fetch(`${API}/repos/${repo()}/contents/${path}`, {
    method: "DELETE",
    headers: headers(),
    body: JSON.stringify({ message: `app: delete ${path}`, sha, branch: branch() }),
    signal: AbortSignal.timeout(12000),
  });
  if (!res.ok && res.status !== 404) throw new Error(`gh delete ${path}: ${res.status}`);
}

/** Read a raw file's text content, or null if missing. */
export async function getRaw(path: string): Promise<string | null> {
  const res = await fetch(`${API}/repos/${repo()}/contents/${path}?ref=${branch()}`, { headers: headers(), cache: "no-store", signal: AbortSignal.timeout(12000) });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`gh getRaw ${path}: ${res.status}`);
  const body = (await res.json()) as { content?: string };
  return Buffer.from(body.content ?? "", "base64").toString("utf-8");
}

export async function audit(eventType: string, sessionId: string | null, detail = ""): Promise<void> {
  try {
    await append("audit.json", { id: uuid(), occurred_at: new Date().toISOString(), event_type: eventType, session_id: sessionId, detail }, 500);
  } catch {
    /* best-effort */
  }
}

export function uuid(): string {
  return globalThis.crypto?.randomUUID?.() ?? `id-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

// ---- vector memory helpers (cosine over normalized vectors) ------------------

export function normalize(v: number[]): number[] {
  let n = 0;
  for (const x of v) n += x * x;
  n = Math.sqrt(n) || 1;
  return v.map((x) => x / n);
}

export function cosine(a: number[], b: number[]): number {
  // assumes both normalized → dot product
  let s = 0;
  const len = Math.min(a.length, b.length);
  for (let i = 0; i < len; i++) s += a[i] * b[i];
  return s;
}
