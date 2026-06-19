// Real, read-only, handshake-testable tool execution. No hardcoded PASS, no
// projection: each tool does genuine work and returns its real output.
//   web_fetch   — real HTTP GET of a public URL → status, title, snippet
//   task_router — real deterministic model routing decision over the catalog
//   memory_read — real semantic memory search (free CF embeddings + store)
//   echo/time   — trivial but real
import { MODELS } from "../../../../../../lib/platform";
import * as gh from "../../../../../../lib/ghStore";
import { cfConfigured, cfEmbed } from "../../../../../../lib/cfWorkersAi";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

function routeModel(query: string): { chosen: string; reason: string } {
  const q = query.toLowerCase();
  const want =
    /(3d|game|render|shader|webgl|three)/.test(q) ? "code" :
    /(code|app|component|function|bug|refactor)/.test(q) ? "code" :
    /(image|photo|picture|vision)/.test(q) ? "vision" :
    /(translate|summar|write|text|draft)/.test(q) ? "chat" : "chat";
  const m = MODELS.find((x) => `${x.id} ${x.role}`.toLowerCase().includes(want)) ?? MODELS[0];
  return { chosen: m?.id ?? "@cf/meta/llama-3.1-8b-instruct", reason: `matched intent "${want}"` };
}

export async function POST(req: Request): Promise<Response> {
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const tool = String(body.tool ?? "echo").toLowerCase();
  const input = String(body.query ?? body.input ?? body.url ?? "").trim();
  const started = Date.now();

  let result: unknown;
  try {
    if (tool === "web_fetch" || tool === "fetch") {
      if (!/^https?:\/\//i.test(input)) return Response.json({ status: "bad_request", note: "tool web_fetch braucht ein 'url'." }, { status: 400 });
      const r = await fetch(input, { signal: AbortSignal.timeout(8000), headers: { "user-agent": "cloud-superbrain/1.0" } });
      const text = await r.text();
      const title = (text.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? "").trim().slice(0, 160);
      const snippet = text.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim().slice(0, 400);
      result = { http_status: r.status, title, bytes: text.length, snippet };
    } else if (tool === "task_router" || tool === "route") {
      result = routeModel(input || "general task");
    } else if (tool === "memory_read" || tool === "memory_search") {
      if (gh.ghConfigured() && cfConfigured() && input) {
        const v = gh.normalize(await cfEmbed("Represent this sentence for searching relevant passages: " + input));
        const rows = (await gh.list("memory.json", 1000, () => true)) as Array<Record<string, unknown>>;
        result = rows
          .map((m) => ({ content: m.content, score: gh.cosine(v, (m.vec as number[]) ?? []) }))
          .sort((a, b) => b.score - a.score).slice(0, 5);
      } else {
        result = { results: [], note: "memory store not configured" };
      }
    } else if (tool === "time") {
      result = { now: new Date().toISOString() };
    } else {
      result = { echo: input };
    }
  } catch (err) {
    return Response.json({ status: "tool_error", tool, note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }

  const ms = Date.now() - started;
  try { if (gh.ghConfigured()) await gh.audit("tool_executed", null, `${tool} · ${ms}ms`); } catch { /* best-effort */ }
  return Response.json(
    { status: "ok", executed: true, tool, ms, result, read_only: true, source: "tool-runtime" },
    { headers: { "x-superbrain-source": "tool-runtime" } },
  );
}
