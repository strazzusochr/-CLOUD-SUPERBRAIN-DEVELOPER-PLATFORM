// The core of the platform: describe an app/game → the AI builds a real,
// self-contained, runnable web app → returned as HTML for a live preview.
// Uses the best free code model on Cloudflare Workers AI (Qwen2.5-Coder-32B),
// falling back to Llama 3.1. The build is persisted as an artifact when a store
// is configured. No fabrication — this is a genuine generation + real preview.

import { cfConfigured, cfChatCompletion } from "../../../../lib/cfWorkersAi";
import * as cf from "../../../../lib/cfBackend";
import * as gh from "../../../../lib/ghStore";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const SYSTEM = `You are a senior frontend engineer for an AI developer platform.
Build exactly what the user asks for as a SINGLE, COMPLETE, self-contained HTML document.
HARD RULES:
- Output ONLY the HTML document. Start with <!doctype html>. No markdown fences, no prose, no explanation.
- Inline ALL CSS in a <style> tag and ALL JavaScript in <script> tags. No build step.
- Allowed external resources: CDN scripts only (e.g. https://unpkg.com/three@0.160.0/build/three.min.js for 3D, using the global THREE). No other network calls, no API keys, no backend.
- It MUST run immediately when opened in a browser. Make it actually work and look polished (dark, modern UI).
- For games/animations: use requestAnimationFrame, keep it performant, and stop the loop when document.hidden.
- Keep it focused and COMPLETE within ~300 lines, and ALWAYS finish the document with </body></html>. Never cut off mid-tag.`;

const GPU_GUARD = `<script>(function(){var _r=window.requestAnimationFrame.bind(window),last=0;window.requestAnimationFrame=function(cb){return _r(function(t){if(document.hidden){window.requestAnimationFrame(cb);return;}if(t-last<15){window.requestAnimationFrame(cb);return;}last=t;cb(t);});};})();</script>`;

function extractHtml(raw: string): string {
  let s = raw.trim();
  const fence = s.match(/```(?:html)?\s*([\s\S]*?)```/i);
  if (fence) s = fence[1].trim();
  const di = s.search(/<!doctype html|<html[\s>]/i);
  if (di > 0) s = s.slice(di);
  // Inject a GPU-safety guard right after <head> (or <html>) so generated games
  // can never pin the visitor's GPU at full framerate.
  if (/<head[\s>]/i.test(s)) s = s.replace(/<head[^>]*>/i, (m) => m + GPU_GUARD);
  else if (/<html[\s>]/i.test(s)) s = s.replace(/<html[^>]*>/i, (m) => m + "<head>" + GPU_GUARD + "</head>");
  return s;
}

const MODIFY_SYSTEM = `You are modifying an existing self-contained HTML web app.
Apply ONLY the requested change and return the COMPLETE updated HTML document.
HARD RULES:
- Output ONLY the full HTML document. Start with <!doctype html>, finish with </body></html>. No markdown, no prose.
- Keep everything that already works; change only what the request asks for.
- Same constraints: inline CSS/JS, CDN scripts only (e.g. three.min.js global THREE), no backend, must run immediately, dark modern UI.`;

async function generate(prompt: string, baseHtml?: string): Promise<{ html: string; model: unknown }> {
  const messages = baseHtml
    ? [
        { role: "system", content: MODIFY_SYSTEM },
        { role: "user", content: `Aktuelle App (vollständiges HTML):\n\n${baseHtml.slice(0, 14000)}\n\nÄnderungswunsch: ${prompt}\n\nGib das KOMPLETTE aktualisierte HTML-Dokument zurück.` },
      ]
    : [
        { role: "system", content: SYSTEM },
        { role: "user", content: prompt },
      ];
  // Give the strong code model (Qwen Coder) a long budget so it isn't cut off;
  // the fast Llama fallback gets the remaining time if Qwen errors.
  const models: Array<[string, number]> = [["@cf/qwen/qwen2.5-coder-32b-instruct", 45000], ["@cf/meta/llama-3.1-8b-instruct", 12000]];
  let lastErr: unknown = null;
  for (const [model, timeoutMs] of models) {
    try {
      const out = await cfChatCompletion({ model, messages, max_tokens: 5200, temperature: 0.3, timeoutMs });
      const choices = out.choices as Array<{ message?: { content?: string } }> | undefined;
      const html = extractHtml(choices?.[0]?.message?.content ?? "");
      if (html && /<.*>/.test(html)) return { html, model: out.model };
    } catch (err) {
      lastErr = err;
    }
  }
  throw new Error(lastErr instanceof Error ? lastErr.message : "generation failed");
}

export async function POST(req: Request): Promise<Response> {
  if (!cfConfigured()) {
    return Response.json({ status: "no_llm", note: "LLM provider not configured." }, { status: 503 });
  }
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const prompt = String(body.prompt ?? "").trim();
  const projectId = String(body.project_id ?? "default");
  const baseHtml = typeof body.base_html === "string" && body.base_html.length < 60000 ? body.base_html : undefined;
  if (!prompt) return Response.json({ status: "bad_request", note: "Beschreibe, was gebaut werden soll." }, { status: 400 });

  try {
    const { html, model } = await generate(prompt.slice(0, 2000), baseHtml);
    const title = prompt.replace(/�/g, "").slice(0, 70);
    const id = (cf.d1Configured() ? cf.uuid : gh.uuid)();
    // Persist the runnable app + its metadata so it gets a shareable link and
    // shows in the gallery (best-effort, never blocks the response).
    let shared = false;
    try {
      if (gh.ghConfigured()) {
        await gh.putRaw(`builds/${id}.html`, html);
        await gh.append("builds.json", { id, project_id: projectId, created_at: new Date().toISOString(), title, prompt: prompt.slice(0, 300), model: String(model), bytes: html.length }, 200);
        await gh.audit("app_built", id, title);
        shared = true;
      }
    } catch { /* best-effort */ }
    return Response.json({ id, title, model, html, persisted: shared, share_path: shared ? `/run/${id}` : null }, { headers: { "x-superbrain-source": "ai-builder" } });
  } catch (err) {
    return Response.json({ status: "build_error", note: err instanceof Error ? err.message : String(err) }, { status: 502 });
  }
}
