"use client";

import { useEffect, useRef, useState } from "react";

// IDE-style build studio backed exclusively by /api/v1/build. That route reaches
// models through the LLM Gateway and fails closed when no gateway is configured.

type Build = {
  id: string;
  title: string;
  model: string;
  html: string;
  live_provider_calls?: boolean;
  share_path?: string | null;
};
type VFile = { name: string; lang: string; content: string };
type LogRow = { kind: "run" | "ok" | "info" | "err"; text: string };

const DEFAULT_EXAMPLES = [
  "Ein 3D-Weltraum-Shooter mit Sternenfeld und Maus-Steuerung",
  "Eine Todo-App mit Dark Mode und LocalStorage",
  "Eine Partikel-Animation, die der Maus folgt",
  "Ein Memory-Kartenspiel mit Emojis",
];

function parseFiles(html: string): VFile[] {
  const files: VFile[] = [{ name: "index.html", lang: "html", content: html }];
  const style = html.match(/<style[^>]*>([\s\S]*?)<\/style>/i);
  if (style && style[1].trim()) files.push({ name: "styles.css", lang: "css", content: style[1].trim() });
  const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)].map((m) => m[1].trim()).filter(Boolean);
  if (scripts.length) files.push({ name: "script.js", lang: "js", content: scripts.join("\n\n") });
  return files;
}

export function WorkbenchStudio({ examples = DEFAULT_EXAMPLES, placeholder }: { examples?: string[]; placeholder?: string } = {}) {
  const EXAMPLES = examples;
  const [prompt, setPrompt] = useState("");
  const [busy, setBusy] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [build, setBuild] = useState<Build | null>(null);
  const [files, setFiles] = useState<VFile[]>([]);
  const [active, setActive] = useState(0);
  const [tab, setTab] = useState<"preview" | "code">("preview");
  const [log, setLog] = useState<LogRow[]>([]);
  const startRef = useRef(0);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get("build");
    if (!id) return;
    (async () => {
      try {
        const r = await fetch(`/api/v1/build/${id}`, { cache: "no-store" });
        const b = await r.json();
        if (r.ok && b.html) { setBuild(b); setFiles(parseFiles(b.html)); setLog([{ kind: "ok", text: `✓ „${b.title}" geladen` }]); }
      } catch { /* ignore */ }
    })();
  }, []);

  function addLog(kind: LogRow["kind"], text: string) {
    setLog((l) => [...l, { kind, text }]);
  }

  async function run(text: string, baseHtml?: string) {
    const p = text.trim();
    if (!p || busy) return;
    setBusy(true); setTab("preview");
    setLog(baseHtml ? [{ kind: "run", text: `▸ Ändere bestehende App…` }] : [{ kind: "run", text: `▸ Anfrage an das LLM-Gateway…` }]);
    startRef.current = Date.now(); setElapsed(0);
    const tick = setInterval(() => setElapsed(Math.round((Date.now() - startRef.current) / 1000)), 1000);
    const ctrl = new AbortController(); abortRef.current = ctrl;
    try {
      const res = await fetch("/api/v1/build", {
        method: "POST", headers: { "content-type": "application/json" }, signal: ctrl.signal,
        body: JSON.stringify(baseHtml ? { prompt: p, base_html: baseHtml } : { prompt: p }),
      });
      const b = await res.json();
      const secs = Math.round((Date.now() - startRef.current) / 1000);
      if (!res.ok || !b.html) { addLog("err", `✗ ${b.note ?? b.reason ?? b.error ?? res.status}`); }
      else {
        const f = parseFiles(b.html);
        setBuild(b); setFiles(f); setActive(0);
        addLog("ok", `✓ ${b.html.length.toLocaleString("de-DE")} Bytes in ${secs}s generiert`);
        addLog("ok", `✓ ${f.length} Datei(en) · GPU-Schutz injiziert`);
        addLog("ok", `✓ Live-Vorschau bereit`);
        if (b.share_path) addLog("ok", `✓ Persistiert · ${b.share_path}`);
      }
    } catch (e) {
      if (!(e instanceof DOMException && e.name === "AbortError")) addLog("err", `✗ ${e instanceof Error ? e.message : String(e)}`);
    } finally { clearInterval(tick); abortRef.current = null; setBusy(false); }
  }

  function download() {
    if (!build) return;
    const url = URL.createObjectURL(new Blob([build.html], { type: "text/html" }));
    const a = document.createElement("a");
    a.href = url; a.download = (build.title || "app").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40) + ".html";
    document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 2000);
  }

  return (
    <div className="workbench-studio" data-testid="workbench-studio">
      <div className="wb-composer">
        <textarea
          className="wb-composer-input"
          placeholder={placeholder ?? "Beschreibe, was du bauen willst — z. B. „ein 3D-Weltraum-Shooter mit Maus-Steuerung“"}
          aria-label="Beschreibung für die App-Erstellung"
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) run(prompt); }}
          rows={2}
          disabled={busy}
        />
        <button type="button" className="btn btn-primary wb-composer-go" onClick={() => run(prompt)} disabled={busy} data-testid="ws-build">
          {busy ? `Baut… ${elapsed}s` : "✨ Bauen"}
        </button>
      </div>
      {!build && !busy ? (
        <div className="wb-examples">
          {EXAMPLES.map((ex) => <button key={ex} type="button" className="ab-chip" onClick={() => { setPrompt(ex); run(ex); }}>{ex}</button>)}
        </div>
      ) : null}

      <section className="wb-studio">
        {/* Explorer — the real generated files */}
        <aside className="wb-pane wb-explorer">
          <div className="wb-pane-head"><span>Dateien</span>{files.length ? <span className="mono muted-copy">{files.length}</span> : null}</div>
          <div className="wb-tree">
            {files.length ? (
              <>
                <div className="tree-root">▾ {(build?.title || "app").slice(0, 22)}</div>
                {files.map((f, i) => (
                  <button key={f.name} type="button" className={`tree-file ws-file${i === active && tab === "code" ? " sel" : ""}`} onClick={() => { setActive(i); setTab("code"); }}>
                    <span className="mono">{f.name}</span>
                    <span className="ws-file-bytes mono">{f.content.length}</span>
                  </button>
                ))}
              </>
            ) : (
              <div className="ws-empty text-12 text-mut">Beschreibe oben deine Idee und wähle „Bauen“ — die generierten Dateien erscheinen hier.</div>
            )}
          </div>
        </aside>

        {/* Editor / Live preview */}
        <main className="wb-pane wb-editor">
          <div className="wb-pane-head">
            <div className="preview-tabs ws-tabs" role="tablist">
              <button type="button" className={tab === "preview" ? "active" : ""} onClick={() => setTab("preview")}>Vorschau</button>
              <button type="button" className={tab === "code" ? "active" : ""} onClick={() => setTab("code")}>Code{files[active] ? ` · ${files[active].name}` : ""}</button>
            </div>
          </div>
          {tab === "preview" ? (
            build ? (
              <iframe className="ws-frame" title="Vorschau" srcDoc={build.html} sandbox="allow-scripts allow-pointer-lock allow-popups allow-modals" data-testid="ws-frame" />
            ) : (
              <div className="ws-stage-empty">
                {busy ? <><div className="ab-spinner" /><div>Baut deine App… <b>{elapsed}s</b></div></> : <div className="text-mut">Hier läuft gleich deine gebaute App.</div>}
              </div>
            )
          ) : (
            <pre className="ws-code mono">{files[active]?.content ?? "// noch kein Code"}</pre>
          )}
        </main>

        {/* Build log + actions */}
        <aside className="wb-pane wb-preview">
          <div className="wb-pane-head"><span>Build-Protokoll</span>{build ? <span className="mono muted-copy">{String(build.model).replace("@cf/", "")}</span> : null}</div>
          <div className="terminal-feed ws-log" data-testid="ws-log">
            {busy ? <div className="terminal-row"><span className="run">▸ Generiere… {elapsed}s</span></div> : null}
            {log.map((r, i) => <div key={i} className="terminal-row"><span className={r.kind}>{r.text}</span></div>)}
            {!busy && !log.length ? <div className="terminal-row"><span className="info">Bereit. Beschreibe oben deine App.</span></div> : null}
          </div>
          {build ? (
            <div className="ws-actions wb-pad">
              <div className="row gap-8 wrap">
                <button type="button" className="btn btn-sm" onClick={() => { const w = window.open(); if (w) { w.document.write(build.html); w.document.close(); } }}>⤢ Vollbild</button>
                {build.share_path ? <button type="button" className="btn btn-sm" onClick={() => navigator.clipboard?.writeText(`${location.origin}${build.share_path}`)}>🔗 Teilen</button> : null}
                <button type="button" className="btn btn-sm" onClick={download}>↓ Herunterladen</button>
              </div>
              <input
                className="wb-composer-input ws-iterate"
                placeholder="Ändern/erweitern — z. B. „füge Highscore hinzu“"
                aria-label="App ändern oder erweitern"
                onKeyDown={(e) => { if (e.key === "Enter") { const v = (e.target as HTMLInputElement).value.trim(); if (v && build) { run(v, build.html); (e.target as HTMLInputElement).value = ""; } } }}
                disabled={busy}
              />
            </div>
          ) : null}
        </aside>
      </section>
      <section className="wb-studio wb-studio-secondary" aria-label="Workbench-Laufzeitbereiche">
        <aside className="wb-pane wb-agent">
          <div className="wb-pane-head"><span>Agentenhilfe</span><span className="mono muted-copy">{busy ? "läuft" : "bereit"}</span></div>
          <div className="wb-tree">
            <div className="terminal-row"><span className={busy ? "run" : "info"}>{busy ? "Planung und Code-Erzeugung aktiv" : "Bereit für Prompt-zu-Code"}</span></div>
            <div className="terminal-row">
              <span className="ok">{build?.live_provider_calls === true ? "live_provider_calls=true" : "live_provider_calls=false"}</span>
            </div>
          </div>
        </aside>
        <aside className="wb-pane wb-cortex">
          <div className="wb-pane-head"><span>Mini-Cortex</span><span className="mono muted-copy">L1-L7</span></div>
          <div className="wb-tree">
            <div className="terminal-row"><span className="info">Werkbank → Agentenpool → LLM/MCP → Nachweise</span></div>
            <div className="terminal-row"><span className="ok">writes=false · secret_output=false</span></div>
          </div>
        </aside>
        <aside className="wb-pane wb-artifacts">
          <div className="wb-pane-head"><span>Artefakte</span><span className="mono muted-copy">{build ? "bereit" : "leer"}</span></div>
          <div className="wb-tree">
            <div className="terminal-row"><span className="info">{build?.share_path ?? "Noch kein Build-Artefakt"}</span></div>
          </div>
        </aside>
      </section>
    </div>
  );
}
