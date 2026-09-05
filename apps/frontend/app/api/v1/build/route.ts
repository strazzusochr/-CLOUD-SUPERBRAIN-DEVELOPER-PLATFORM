// The core of the platform: describe an app/game → the AI builds a real,
// self-contained, runnable web app → returned as HTML for a live preview.
// Generation is allowed only through the configured LLM Gateway. The stateless
// frontend never calls a provider or persistence service directly.

import { authorizeBoundaryWrite, boundaryUnavailable, proxyToBoundary } from "../../../../lib/frontendBoundary";
import {
  ensureGeneratedHtmlBoundingSpheres,
  ensureGeneratedHtmlDependencies,
  ensureGeneratedHtmlRuntimeOrder,
  findUnrunnableReferences,
  isRunnableGeneratedHtml,
} from "../../../../lib/generatedHtml";

export const dynamic = "force-dynamic";
export const maxDuration = 115;

const SYSTEM = `You are a senior frontend engineer for an AI developer platform.
Build exactly what the user asks for as a SINGLE, COMPLETE, self-contained HTML document.
HARD RULES:
- Output ONLY the HTML document. Start with <!doctype html>. No markdown fences, no prose, no explanation.
- Inline ALL CSS in a <style> tag and ALL JavaScript in <script> tags. No build step.
- Allowed external resources: CDN scripts only (e.g. https://unpkg.com/three@0.160.0/build/three.min.js for 3D, using the global THREE). If any code references THREE, that core script MUST be present before the first use. No other network calls, no API keys, no backend.
- Never use three.js examples/js paths (removed in r150). Load addons only from examples/jsm inside type="module", or stay with core THREE globals.
- It MUST run immediately when opened in a browser. Make it actually work and look polished (dark, modern UI).
- For games/animations: use requestAnimationFrame, keep it performant, and stop the loop when document.hidden.
- Build the whole thing. Aim for 300-700 lines; ALWAYS finish the document with </body></html>. Never cut off mid-tag, and never stop early with a placeholder comment or an unfinished-work marker.
- When the request is 3D, render real WebGL through three.js - never a 2D canvas imitation. A 3D scene is only finished when it has all of:
  * a PerspectiveCamera that follows or frames the subject, and a resize handler,
  * lighting with at least one directional light plus ambient/hemisphere fill, and shadows enabled on renderer, light and meshes,
  * MeshStandardMaterial (not MeshBasicMaterial) so lighting is visible, with distinct colours per object type,
  * more than a bare box: ground, several distinct objects, and visible depth,
  * renderer.setPixelRatio(Math.min(devicePixelRatio, 2)) and an animation loop driven by a clock delta.
- A 3D scene must never be a black void, and must never be an empty sky. Give it a finished look:
  * a coloured sky via scene.background, plus scene.fog whose colour EXACTLY matches that sky,
  * a large ground that fills the lower half of the view: PlaneGeometry at least 200x200, rotated -Math.PI/2, receiveShadow, in a clearly visible colour,
  * BRIGHT lighting - three.js r155+ uses physical light units, so a scene lit only by defaults renders almost black. Use DirectionalLight intensity 2.5-3.5 plus AmbientLight or HemisphereLight intensity 1.5-2.5, and verify every object reads as its own colour rather than as a dark silhouette,
  * renderer.shadowMap.type = THREE.PCFSoftShadowMap,
  * a considered palette of at least five distinct colours, with emissive on pickups so they glow,
  * varied geometry - not every object a box; use spheres, cylinders, cones where they suit.
- Do not enable tone mapping unless you also raise light intensities to match; a dark render is a failed render.
- For a playable game also implement: keyboard state via keydown/keyup (never a single keypress branch), initialize every keyboard-state binding before starting the animation loop, gravity and ground collision, collision or pickup detection, a visible score/HUD in the DOM, and a lose/win or reset path.
- If collision code reads geometry.boundingSphere.radius, call geometry.computeBoundingSphere() first (or use THREE.Box3); boundingSphere starts as null.
- THREE.Box3 has no computeBoundingSphere() method. To obtain a sphere from a Box3, call box.getBoundingSphere(new THREE.Sphere()).`;

const GPU_GUARD = `<script>(function(){var _r=window.requestAnimationFrame.bind(window),last=0;window.requestAnimationFrame=function(cb){return _r(function(t){if(document.hidden){window.requestAnimationFrame(cb);return;}if(t-last<15){window.requestAnimationFrame(cb);return;}last=t;cb(t);});};})();</script>`;
const MAX_PROMPT_CHARS = 2_000;
const MAX_BASE_HTML_CHARS = 60_000;
const MAX_PERSISTED_HTML_BYTES = 160 * 1024;
const WORKBENCH_LLM_MODEL = process.env.WORKBENCH_LLM_MODEL?.trim()
  || "@cf/qwen/qwen2.5-coder-32b-instruct";
const LIVE_PROVIDER_APPROVED = /^(1|true|yes|on)$/i.test(
  process.env.PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED?.trim() || "",
);
const SECRET_PATTERNS = [
  /\bsk-[A-Za-z0-9_-]{16,}\b/,
  /\bghp_[A-Za-z0-9_]{16,}\b/,
  /\bgithub_pat_[A-Za-z0-9_]{16,}\b/,
  /\b(?:E2B|cfat|vck|hf)_[A-Za-z0-9_-]{16,}\b/,
  /\bglpat-[A-Za-z0-9_.-]{20,}\b/,
  /\b(?:api[_-]?key|secret|token|password)\s*[:=]\s*(?:"[^"\r\n]{8,}"|'[^'\r\n]{8,}'|[A-Za-z0-9_+=/-]{24,})/i,
];

function containsSecretMaterial(value: string): boolean {
  return SECRET_PATTERNS.some((pattern) => pattern.test(value));
}

function structurallyCompletePersistableHtml(value: string): boolean {
  return new TextEncoder().encode(value).byteLength <= MAX_PERSISTED_HTML_BYTES
    && /^\s*<!doctype html/i.test(value)
    && /<\/html>\s*$/i.test(value);
}

function completePersistableHtml(value: string): boolean {
  return structurallyCompletePersistableHtml(value) && isRunnableGeneratedHtml(value);
}

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
- Same constraints: inline CSS/JS, CDN scripts only (e.g. three.min.js global THREE); if any code references THREE, load that core before the first use; no backend, must run immediately, dark modern UI.
- Never use three.js examples/js paths (removed in r150). Load addons only from examples/jsm inside type="module", or stay with core THREE globals.`;

type GeneratedBuild = {
  html: string;
  model: unknown;
  liveProviderCalls: boolean;
  gatewayMode: unknown;
  provider: unknown;
};

type BuildRecord = {
  id: string;
  project_id: string;
  title: string;
  prompt: string;
  model: string;
  html: string;
  gateway_mode: string;
  gateway_provider: string;
  live_provider_calls: boolean;
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
  // Must exceed CF_WORKERS_AI_TIMEOUT_SECONDS (90s) so the gateway's own verdict is
  // observed instead of this hop aborting first and reporting a false outage.
  const models: Array<[string, number]> = [[WORKBENCH_LLM_MODEL, 100000]];
  let lastErr: unknown = null;
  let lastRejection: string | null = null;
  let gatewayReached = false;
  for (const [model, timeoutMs] of models) {
    try {
      const gatewayRequest = new Request(req.url, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          accept: "application/json",
          ...(req.headers.get("x-request-id") ? { "x-request-id": req.headers.get("x-request-id") as string } : {}),
          ...(req.headers.get("traceparent") ? { traceparent: req.headers.get("traceparent") as string } : {}),
        },
        body: JSON.stringify({
          model,
          messages,
          max_tokens: 5200,
          temperature: 0.3,
          stream: false,
          metadata: {
            workload: "workbench_product_build",
            live_provider_calls_allowed: LIVE_PROVIDER_APPROVED,
          },
        }),
      });
      const response = await proxyToBoundary(gatewayRequest, "llm-gateway", "/v1/chat/completions", timeoutMs);
      if (!response) continue;
      gatewayReached = true;
      const out = (await response.json()) as Record<string, unknown>;
      if (!response.ok) throw new Error(String(out.error ?? out.detail ?? `LLM Gateway HTTP ${response.status}`));
      const choices = out.choices as Array<{ message?: { content?: string } }> | undefined;
      const rawContent = choices?.[0]?.message?.content ?? "";
      const html = ensureGeneratedHtmlBoundingSpheres(
        ensureGeneratedHtmlRuntimeOrder(
          ensureGeneratedHtmlDependencies(extractHtml(rawContent)),
        ),
      );
      const unrunnableReferences = findUnrunnableReferences(html);
      // A 200 whose body fails these two gates used to fall straight through to the next
      // attempt without recording anything, so lastErr stayed undefined and the caller saw the
      // bare "generation failed" with no way to tell an incomplete document from a rejected one.
      // Only the verdict and the sizes are captured — never the document, which is exactly the
      // material containsSecretMaterial exists to guard.
      if (!structurallyCompletePersistableHtml(html)) {
        lastRejection = `incomplete_html (raw ${rawContent.length} chars, extracted ${html.length} chars)`;
      } else if (unrunnableReferences.length > 0) {
        lastRejection = `unrunnable_html (${unrunnableReferences.join("; ")})`;
      } else if (containsSecretMaterial(html)) {
        lastRejection = `secret_material_in_generated_html (${html.length} chars)`;
      }
      if (completePersistableHtml(html) && !containsSecretMaterial(html)) {
        return {
          html,
          model: out.model,
          liveProviderCalls: out.live_provider_calls === true,
          gatewayMode: out.gateway_mode,
          provider: out.provider ?? out.provider_name,
        };
      }
    } catch (err) {
      lastErr = err;
    }
  }
  if (!gatewayReached) return null;
  if (lastErr instanceof Error) throw lastErr;
  throw new Error(lastRejection ? `generation rejected: ${lastRejection}` : "generation failed");
}

async function persistBuild(req: Request, build: BuildRecord): Promise<Record<string, unknown> | null> {
  const persistenceRequest = new Request(req.url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      accept: "application/json",
      ...(req.headers.get("x-request-id") ? { "x-request-id": req.headers.get("x-request-id") as string } : {}),
    },
    body: JSON.stringify(build),
  });
  const response = await proxyToBoundary(
    persistenceRequest,
    "agent-api",
    "/api/v1/builds",
    10_000,
    { serviceAuth: true },
  );
  if (!response?.ok) return null;
  let payload: Record<string, unknown>;
  try {
    payload = (await response.json()) as Record<string, unknown>;
  } catch {
    return null;
  }
  return payload.persisted === true
    && payload.audit_persisted === true
    && payload.id === build.id
    && payload.html === build.html
    && payload.direct_provider_calls === false
    && payload.live_mcp_writes === false
    && payload.secret_output === false
    ? payload
    : null;
}

export async function POST(req: Request): Promise<Response> {
  const writeBlock = await authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;

  let body: Record<string, unknown> = {};
  try { body = (await req.json()) as Record<string, unknown>; } catch { /* empty */ }
  const prompt = String(body.prompt ?? "").trim();
  const projectId = String(body.project_id ?? "default");
  const baseHtml = typeof body.base_html === "string" ? body.base_html : undefined;
  if (!prompt) return Response.json({ status: "bad_request", note: "Beschreibe, was gebaut werden soll." }, { status: 400 });
  if (prompt.length > MAX_PROMPT_CHARS || containsSecretMaterial(prompt)) {
    return Response.json(
      { status: "bad_request", error: "prompt_rejected", accepted: false, persisted: false, secret_output: false },
      { status: 400, headers: { "cache-control": "no-store" } },
    );
  }
  if (!/^[A-Za-z0-9_.-]{1,80}$/.test(projectId)) {
    return Response.json(
      { status: "bad_request", error: "invalid_project_id", accepted: false, persisted: false, secret_output: false },
      { status: 400, headers: { "cache-control": "no-store" } },
    );
  }
  // A previously persisted broken build must remain repairable. Only the newly generated output
  // is subject to the runnability guard; the repair input is bounded, structural, and secret-safe.
  if (baseHtml !== undefined && (baseHtml.length > MAX_BASE_HTML_CHARS || !structurallyCompletePersistableHtml(baseHtml) || containsSecretMaterial(baseHtml))) {
    return Response.json(
      { status: "bad_request", error: "base_html_rejected", accepted: false, persisted: false, secret_output: false },
      { status: 400, headers: { "cache-control": "no-store" } },
    );
  }

  try {
    const generated = await generate(req, prompt, baseHtml);
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
    const buildRecord: BuildRecord = {
      id,
      project_id: projectId,
      title,
      prompt: prompt.slice(0, 2000),
      model: String(model ?? "unknown"),
      html,
      gateway_mode: String(gatewayMode ?? "unknown"),
      gateway_provider: String(provider ?? "unknown"),
      live_provider_calls: liveProviderCalls,
    };
    const persistedBuild = await persistBuild(req, buildRecord);
    const persisted = persistedBuild !== null;
    if (!persistedBuild) {
      return Response.json(
        {
          contract_version: "stateful-build-persistence-v1",
          status: "blocked",
          error: "build_persistence_unavailable",
          accepted: false,
          generated: true,
          persisted: false,
          share_path: null,
          live_provider_calls: liveProviderCalls,
          direct_provider_calls: false,
          live_mcp_writes: false,
          production_deploy: false,
          secret_output: false,
          note: "Generation completed, but audited build persistence was unavailable. No build output was returned.",
        },
        { status: 503, headers: { "x-superbrain-source": "agent-api-boundary-blocked", "cache-control": "no-store" } },
      );
    }
    return Response.json(
      {
        contract_version: persistedBuild.contract_version,
        status: persistedBuild.status,
        source: persistedBuild.source,
        id: persistedBuild.id,
        project_id: persistedBuild.project_id,
        title: persistedBuild.title,
        prompt_sha256: persistedBuild.prompt_sha256,
        model: persistedBuild.model,
        html: persistedBuild.html,
        gateway_mode: persistedBuild.gateway_mode,
        gateway_provider: persistedBuild.gateway_provider,
        live_provider_calls: persistedBuild.live_provider_calls === true,
        created_at: persistedBuild.created_at,
        updated_at: persistedBuild.updated_at,
        audit_persisted: true,
        persisted,
        share_path: persisted ? `/run/${id}` : null,
        direct_provider_calls: false,
        live_mcp_writes: false,
        secret_output: false,
        note: "Generated through the LLM Gateway and audit-persisted through the Agent API D1 registry.",
      },
      { headers: { "x-superbrain-source": "llm-gateway-boundary", "cache-control": "no-store" } },
    );
  } catch (error) {
    // This catch used to be unbound, which discarded the only evidence of why the primary
    // product path failed and left "llm_gateway_generation_unavailable" as the sole signal for
    // every possible cause. The reason is logged server-side only; the response body is
    // unchanged so no internal detail reaches the client. Any long token-shaped run is redacted
    // before logging so a provider error string can never carry a credential into the logs.
    const reason = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
    console.error(
      "[build] generation boundary threw:",
      reason.replace(/[A-Za-z0-9_\-]{24,}/g, "[redacted]").slice(0, 500),
    );
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
        note: "The LLM Gateway did not return a complete, secret-safe HTML document.",
      },
      { status: 503, headers: { "cache-control": "no-store", "x-superbrain-source": "llm-gateway-boundary-blocked" } },
    );
  }
}
