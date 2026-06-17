// Real persisted prompt run: creates a session, calls the free CF Workers AI LLM,
// stores the result, writes an audit row. Honest 503 without DATABASE_URL.

import { dbConfigured, ensureSchema, sql, audit } from "../../../../lib/neon";
import { cfConfigured, cfChatCompletion } from "../../../../lib/cfWorkersAi";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

export async function POST(req: Request): Promise<Response> {
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const prompt = String(body.prompt ?? body.text ?? "").trim();
  const projectId = String(body.project_id ?? "default");
  if (!prompt) return Response.json({ status: "bad_request", note: "Feld 'prompt' erforderlich." }, { status: 400 });

  // No persistence configured: still execute the prompt for real via the free LLM,
  // just without storing the session. Honest 200 (persisted:false), never a 5xx.
  if (!dbConfigured()) {
    if (!cfConfigured()) {
      return Response.json(
        { status: "ok", session_id: null, persisted: false, result: "", live_backend: false, source: "frontend-projection", note: "No LLM/persistence configured." },
        { headers: { "x-superbrain-source": "frontend-projection" } },
      );
    }
    try {
      const out = await cfChatCompletion({ model: "default", messages: [{ role: "user", content: prompt }], max_tokens: 512 });
      const choices = out.choices as Array<{ message?: { content?: string } }> | undefined;
      return Response.json(
        { status: "completed", session_id: null, persisted: false, model: out.model, provider: out.provider, result: choices?.[0]?.message?.content ?? "" },
        { headers: { "x-superbrain-source": "cloudflare-workers-ai" } },
      );
    } catch (err) {
      return Response.json({ status: "llm_provider_error", persisted: false, note: err instanceof Error ? err.message : String(err) }, { status: 502 });
    }
  }
  try {
    await ensureSchema();
    const created = (await sql()`
      INSERT INTO agent_sessions (project_id, status, prompt) VALUES (${projectId}, 'running', ${prompt}) RETURNING id
    `) as unknown as Array<{ id: string }>;
    const sessionId = created[0].id;
    if (!cfConfigured()) {
      await sql()`UPDATE agent_sessions SET status='failed', result=${"LLM not configured"} WHERE id=${sessionId}`;
      await audit("prompt_failed", sessionId, "llm_not_configured");
      return Response.json({ status: "no_live_backend", session_id: sessionId, note: "LLM provider not configured (CF_WORKERS_AI_TOKEN)." }, { status: 503 });
    }
    const out = await cfChatCompletion({ model: "default", messages: [{ role: "user", content: prompt }], max_tokens: 512 });
    const choices = out.choices as Array<{ message?: { content?: string } }> | undefined;
    const result = choices?.[0]?.message?.content ?? "";
    await sql()`UPDATE agent_sessions SET status='completed', result=${result}, model=${String(out.model ?? "")} WHERE id=${sessionId}`;
    await audit("prompt_completed", sessionId, `${result.length} chars`);
    return Response.json(
      { session_id: sessionId, status: "completed", model: out.model, result, provider: out.provider },
      { headers: { "x-superbrain-source": "neon-postgres+cloudflare-workers-ai" } },
    );
  } catch (err) {
    return Response.json({ status: "db_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
