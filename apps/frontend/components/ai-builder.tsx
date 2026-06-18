"use client";

import { useRef, useState } from "react";

// The platform's core experience: describe an app or game → the AI builds it →
// it runs LIVE in a sandboxed preview. No code to read, no setup — you get a
// working thing. (v0/Bolt/Lovable-style, on the free Cloudflare Workers AI stack.)

const EXAMPLES = [
  "Ein 3D-Weltraum-Shooter mit Sternenfeld und Maus-Steuerung",
  "Ein Pong-Spiel für zwei Spieler mit Punktestand",
  "Eine Todo-App mit Dark Mode und LocalStorage",
  "Eine bunte Partikel-Animation, die der Maus folgt",
  "Ein Memory-Kartenspiel mit Emojis",
  "Ein wissenschaftlicher Taschenrechner",
];

type Build = { id: string; title: string; model: string; html: string; share_path?: string | null };

export function AiBuilder() {
  const [prompt, setPrompt] = useState("");
  const [busy, setBusy] = useState(false);
  const [build, setBuild] = useState<Build | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [showCode, setShowCode] = useState(false);
  const [copied, setCopied] = useState(false);
  const startedRef = useRef(0);
  const [elapsed, setElapsed] = useState(0);

  async function run(p: string) {
    const text = p.trim();
    if (!text || busy) return;
    setBusy(true); setErr(null); setBuild(null); setShowCode(false);
    startedRef.current = Date.now();
    setElapsed(0);
    const tick = setInterval(() => setElapsed(Math.round((Date.now() - startedRef.current) / 1000)), 1000);
    try {
      const res = await fetch("/api/v1/build", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ prompt: text }),
      });
      const body = await res.json();
      if (!res.ok || !body.html) setErr(String(body.note ?? `Fehler ${res.status}`));
      else setBuild(body as Build);
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      clearInterval(tick);
      setBusy(false);
    }
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
      <div className="ab-prompt">
        <textarea
          className="ab-input"
          placeholder="Beschreibe, was du bauen willst — z. B. „ein 3D-Weltraum-Shooter mit Maus-Steuerung“"
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) run(prompt); }}
          rows={2}
          disabled={busy}
          aria-label="Build-Beschreibung"
        />
        <button type="button" className="btn btn-primary ab-go" onClick={() => run(prompt)} disabled={busy} data-testid="ab-build">
          {busy ? `Baut… ${elapsed}s` : "✨ Bauen"}
        </button>
      </div>

      {!build && !busy ? (
        <div className="ab-examples">
          <span className="text-12 text-mut">Beispiele:</span>
          {EXAMPLES.map((ex) => (
            <button key={ex} type="button" className="ab-chip" onClick={() => { setPrompt(ex); run(ex); }}>{ex}</button>
          ))}
        </div>
      ) : null}

      {busy ? (
        <div className="ab-loading">
          <div className="ab-spinner" />
          <div>Die Agenten bauen deine App… <b>{elapsed}s</b><div className="text-12 text-mut">echtes Code-Modell (Qwen2.5-Coder) · läuft gleich live</div></div>
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
              <button type="button" className="btn btn-sm" onClick={download}>↓ Download</button>
              <button type="button" className="btn btn-sm" onClick={() => setShowCode((v) => !v)}>{showCode ? "Vorschau" : "Code"}</button>
              <span className="mono text-12 text-mut">{String(build.model).replace("@cf/", "")}</span>
            </span>
          </div>
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
              placeholder="Ändern/erweitern — z. B. „mache es schneller und füge Highscore hinzu“"
              onKeyDown={(e) => { if (e.key === "Enter") { const v = (e.target as HTMLInputElement).value; if (v.trim()) run(`${prompt}\n\nÄnderung: ${v}`); } }}
              disabled={busy}
              aria-label="Iterieren"
            />
          </div>
        </div>
      ) : null}
    </div>
  );
}
