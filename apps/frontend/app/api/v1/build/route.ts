// The core of the platform: describe an app/game → the AI builds a real,
// self-contained, runnable web app → returned as HTML for a live preview.
// Generation is allowed only through the configured LLM Gateway. The stateless
// frontend never calls a provider or persistence service directly.

import { boundaryUnavailable, proxyToBoundary } from "../../../../lib/frontendBoundary";

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

type GeneratedBuild = {
  html: string;
  model: unknown;
  liveProviderCalls: boolean;
  gatewayMode: unknown;
  provider: unknown;
};

async function generate(req: Request, prompt: string, baseHtml?: string): Promise<GeneratedBuild | null> {
  const messages = baseHtml
    ? [
        { role: "system", content: MODIFY_SYSTEM },
        { role: "user", content: `Aktuelle App (vollständiges HTML):\n\n${baseHtml.slice(0, 14000)}\n\nÄnderungswunsch: ${prompt}\n\nGib das KOMPLETTE aktualisierte HTML-Dokument zurück.` },
      ]
    : [
        { role: "system", content: SYSTEM },
        { role: "user", content: prompt },
      ];
  // Free-only hosted generation gets one bounded provider attempt per user prompt.
  const models: Array<[string, number]> = [["@cf/qwen/qwen2.5-coder-32b-instruct", 50000]];
  let lastErr: unknown = null;
  let gatewayReached = false;
  for (const [model, timeoutMs] of models) {
    try {
      const gatewayRequest = new Request(req.url, {
        method: "POST",
        headers: { "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({ model, messages, max_tokens: 5200, temperature: 0.3, stream: false }),
      });
      const response = await proxyToBoundary(gatewayRequest, "llm-gateway", "/v1/chat/completions", timeoutMs);
      if (!response) continue;
      gatewayReached = true;
      const out = (await response.json()) as Record<string, unknown>;
      if (!response.ok) throw new Error(String(out.error ?? out.detail ?? `LLM Gateway HTTP ${response.status}`));
      const choices = out.choices as Array<{ message?: { content?: string } }> | undefined;
      const html = extractHtml(choices?.[0]?.message?.content ?? "");
      if (html && /<.*>/.test(html)) {
        return {
          html,
          model: out.model,
          liveProviderCalls: out.live_provider_calls === true,
          gatewayMode: out.gateway_mode,
          provider: out.provider,
        };
      }
    } catch (err) {
      lastErr = err;
    }
  }
  if (!gatewayReached) return null;
  throw new Error(lastErr instanceof Error ? lastErr.message : "generation failed");
}

export async function POST(req: Request): Promise<Response> {
  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const prompt = String(body.prompt ?? "").trim();
  const projectId = String(body.project_id ?? "default");
  const baseHtml = typeof body.base_html === "string" && body.base_html.length < 60000 ? body.base_html : undefined;
  if (!prompt) return Response.json({ status: "bad_request", note: "Beschreibe, was gebaut werden soll." }, { status: 400 });

  try {
    const generated = await generate(req, prompt.slice(0, 2000), baseHtml);
    if (!generated) {
      return boundaryUnavailable(
        "POST /api/v1/build",
        "llm-gateway",
        "App generation requires the configured LLM Gateway; no direct provider call was attempted.",
      );
    }
    const { html, model, liveProviderCalls, gatewayMode, provider } = generated;
    const title = prompt.replace(/�/g, "").slice(0, 70);
    const id = globalThis.crypto.randomUUID();
    void projectId;
    return Response.json(
      {
        id,
        title,
        model,
        html,
        gateway_mode: gatewayMode,
        gateway_provider: provider,
        live_provider_calls: liveProviderCalls,
        persisted: false,
        share_path: null,
        direct_provider_calls: false,
        live_mcp_writes: false,
        note: "Generated through the LLM Gateway; persistence requires the Agent API artifact registry.",
      },
      { headers: { "x-superbrain-source": "llm-gateway-boundary", "cache-control": "no-store" } },
    );
  } catch (err) {
    return Response.json(
      {
        contract_version: "frontend-provider-boundary-v1",
        status: "blocked",
        error: "llm_gateway_generation_unavailable",
        reason: "llm_gateway_did_not_return_complete_html",
        required_boundary: "llm-gateway",
        accepted: false,
        persisted: false,
        live_backend: false,
        direct_provider_calls: false,
        live_provider_calls: false,
        live_mcp_writes: false,
        production_deploy: false,
        secret_output: false,
        note: err instanceof Error ? err.message : String(err),
      },
      { status: 503, headers: { "cache-control": "no-store", "x-superbrain-source": "llm-gateway-boundary-blocked" } },
    );
  }
}
