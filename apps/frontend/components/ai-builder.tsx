"use client";

import { useEffect, useRef, useState } from "react";

// Prompt-to-code experience through the LLM Gateway. Generated HTML is rendered
// only after a successful gateway response and remains downloadable in-browser.

const DEFAULT_EXAMPLES = [
  "Ein 3D-Weltraum-Shooter mit Sternenfeld und Maus-Steuerung",
  "Ein Pong-Spiel für zwei Spieler mit Punktestand",
  "Eine Todo-App mit Dark Mode und LocalStorage",
  "Eine bunte Partikel-Animation, die der Maus folgt",
  "Ein Memory-Kartenspiel mit Emojis",
  "Ein wissenschaftlicher Taschenrechner",
];

type Build = { id: string; title: string; model: string; html: string; share_path?: string | null };

function readableBuildError(payload: Record<string, unknown>, status: number): string {
  const error = String(payload.error ?? "");
  if (error === "write_session_required") return "Für den Build konnte keine sichere Sitzung gestartet werden.";
  if (error === "configured_boundary_unavailable") {
    return "Build benötigt eine laufende Runtime mit LLM-Gateway und Backend. Dieses Frontend ist nur lesbar.";
  }
  if (error === "llm_gateway_generation_unavailable") return "Das LLM-Gateway hat kein vollständiges Build-Artefakt geliefert.";
  if (error === "build_persistence_unavailable") return "Der Build wurde erzeugt, aber das Backend konnte ihn nicht sicher speichern.";
  return String(payload.note ?? payload.reason ?? (error || `Build fehlgeschlagen (HTTP ${status}).`));
}

async function ensureSignedGuestSession(): Promise<void> {
  const current = await fetch("/api/v1/auth/session", { cache: "no-store" });
  const currentPayload = (await current.json()) as Record<string, unknown>;
  if (current.ok && currentPayload.status === "signed_in") return;
  const created = await fetch("/api/v1/auth/session", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ provider: "guest" }),
  });
  const createdPayload = (await created.json()) as Record<string, unknown>;
  if (!created.ok || createdPayload.status !== "signed_in") throw new Error("Sichere Gast-Sitzung nicht verfügbar.");
}

export function AiBuilder({ examples = DEFAULT_EXAMPLES, placeholder }: { examples?: string[]; placeholder?: string } = {}) {
  const EXAMPLES = examples;
  const [prompt, setPrompt] = useState("");
  const [busy, setBusy] = useState(false);
  const [build, setBuild] = useState<Build | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [showCode, setShowCode] = useState(false);
  const [copied, setCopied] = useState(false);
  const [runtimeReady, setRuntimeReady] = useState<boolean | null>(null);
  const startedRef = useRef(0);
  const [elapsed, setElapsed] = useState(0);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const response = await fetch("/api/v1/builds?limit=1", { cache: "no-store" });
        const payload = (await response.json()) as Record<string, unknown>;
        if (alive) setRuntimeReady(response.ok && payload.persisted === true && payload.live_backend !== false);
      } catch {
        if (alive) setRuntimeReady(false);
      }
    })();
    return () => { alive = false; };
  }, []);

  // Load an existing build into the builder (?build=<id>) to keep iterating on it.
  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get("build");
    if (!id) return;
    let alive = true;
    (async () => {
      try {
        const res = await fetch(`/api/v1/build/${id}`, { cache: "no-store" });
        const body = await res.json();
        if (alive && res.ok && body.html) setBuild(body as Build);
      } catch { /* ignore */ }
    })();
    return () => { alive = false; };
  }, []);

  async function run(p: string, baseHtml?: string) {
    const text = p.trim();
    if (!text || busy) return;
    if (runtimeReady === false) {
      setErr("Build benötigt eine laufende Runtime mit LLM-Gateway und Backend. Dieses Frontend ist nur lesbar.");
      return;
    }
    setBusy(true); setErr(null); if (!baseHtml) setBuild(null); setShowCode(false);
    startedRef.current = Date.now();
    setElapsed(0);
    const tick = setInterval(() => setElapsed(Math.round((Date.now() - startedRef.current) / 1000)), 1000);
    const ctrl = new AbortController();
    abortRef.current = ctrl;
    try {
      await ensureSignedGuestSession();
      const res = await fetch("/api/v1/build", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(baseHtml ? { prompt: text, base_html: baseHtml } : { prompt: text }),
        signal: ctrl.signal,
      });
      const body = (await res.json()) as Build & Record<string, unknown>;
      if (!res.ok || !body.html) setErr(readableBuildError(body, res.status));
      else setBuild(body as Build);
    } catch (e) {
      if (!(e instanceof DOMException && e.name === "AbortError")) setErr(e instanceof Error ? e.message : String(e));
    } finally {
      clearInterval(tick);
      abortRef.current = null;
      setBusy(false);
    }
  }

  function cancel() {
    abortRef.current?.abort();
  }

  function download() {
    if (!build) return;
    const blob = new Blob([build.html], { type: "text/html" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = (build.title || "app").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40) + ".html";
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  }

  function openFull() {
    if (!build) return;
    const w = window.open();
    if (w) { w.document.open(); w.document.write(build.html); w.document.close(); }
  }

  return (
    <div className="ai-builder" data-testid="ai-builder">
      {runtimeReady === false ? (
        <div className="note blocked" role="status" data-testid="ai-builder-runtime-notice">
          Build benötigt eine laufende Runtime mit LLM-Gateway und Backend. Dieses Frontend ist nur lesbar.
        </div>
      ) : null}
      <div className="ab-prompt">
        <textarea
          className="ab-input"
          placeholder={placeholder ?? "Beschreibe, was du bauen willst — z. B. „ein 3D-Weltraum-Shooter mit Maus-Steuerung“"}
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) run(prompt); }}
          rows={2}
          disabled={busy}
          aria-label="Beschreibung für den Build"
        />
        <button type="button" className="btn btn-primary ab-go" onClick={() => run(prompt)} disabled={busy || runtimeReady === false} data-testid="ab-build">
          {busy ? `Baut… ${elapsed}s` : "✨ Bauen"}
        </button>
      </div>

      {!build && !busy ? (
        <div className="ab-examples">
          <span className="text-12 text-mut">Beispiele:</span>
          {EXAMPLES.map((ex) => (
            <button
              key={ex}
              type="button"
              className="ab-chip"
              disabled={busy}
              onClick={() => setPrompt(ex)}
              title="Beispiel in das Eingabefeld übernehmen"
            >
              {ex}
            </button>
          ))}
        </div>
      ) : null}

      {busy ? (
        <div className="ab-loading">
          <div className="ab-spinner" />
          <div>
            <b>{elapsed < 3 ? "Anfrage analysieren…" : elapsed < 9 ? "Code über das LLM-Gateway erzeugen…" : elapsed < 16 ? "App zusammenbauen & GPU-absichern…" : "Vorschau rendern…"}</b>{" "}
            <span className="text-12 text-mut">{elapsed}s</span>
            <div className="text-12 text-mut">Gateway-gebunden · Vorschau erst nach erfolgreicher Modellantwort</div>
          </div>
          <button type="button" className="btn btn-sm" onClick={cancel} style={{ marginLeft: "auto" }}>Abbrechen</button>
        </div>
      ) : null}

      {err ? <div className="note blocked" data-testid="ab-error">⚠ {err}</div> : null}

      {build ? (
        <div className="ab-result" data-testid="ab-result">
          <div className="ab-bar">
            <span className="ab-title">▶ {build.title}</span>
            <span className="ab-actions">
              <button type="button" className="btn btn-sm" onClick={openFull}>⤢ Vollbild</button>
              {build.share_path ? (
                <button type="button" className="btn btn-sm" onClick={() => {
                  const link = `${location.origin}${build.share_path}`;
                  navigator.clipboard?.writeText(link).then(() => { setCopied(true); setTimeout(() => setCopied(false), 1800); }).catch(() => {});
                }}>{copied ? "✓ Link kopiert" : "🔗 Teilen"}</button>
              ) : null}
              <button type="button" className="btn btn-sm" onClick={download}>↓ Herunterladen</button>
              <button type="button" className="btn btn-sm" onClick={() => setShowCode((v) => !v)}>{showCode ? "Vorschau" : "Code"}</button>
              <span className="mono text-12 text-mut">{String(build.model).replace("@cf/", "")}</span>
            </span>
          </div>
          {!/<\/html>/i.test(build.html) ? (
            <div className="ab-trunc text-12">Hinweis: Die App ist evtl. unvollständig generiert. Tippe unten eine kleine Änderung und drücke Enter — sie wird vervollständigt.</div>
          ) : null}
          {showCode ? (
            <pre className="ab-code mono">{build.html}</pre>
          ) : (
            <iframe
              className="ab-frame"
              title={build.title}
              srcDoc={build.html}
              sandbox="allow-scripts allow-pointer-lock allow-popups allow-modals"
              data-testid="ab-frame"
            />
          )}
          <div className="ab-iterate">
            <input
              className="ab-input ab-iter-input"
              placeholder="Ändern/erweitern — z. B. „mache es schneller und füge Highscore hinzu“ (ändert die bestehende App)"
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  const el = e.target as HTMLInputElement;
                  const v = el.value.trim();
                  if (v && build) { run(v, build.html); el.value = ""; }
                }
              }}
              disabled={busy}
              aria-label="Iterieren"
            />
          </div>
        </div>
      ) : null}
    </div>
  );
}
