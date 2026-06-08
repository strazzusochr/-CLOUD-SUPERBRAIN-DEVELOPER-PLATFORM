"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import CortexLive from "./CortexLive";
import { HUBS, LAYERS, ORGANISM_AGENTS, STATE_LABEL, type RunState } from "./regionMap";
import { CLOSED_GATES } from "../../lib/platform";

const STATES: RunState[] = ["idle", "planning", "executing", "verifying", "blocked"];

const HUB_DESC: Record<string, string> = {
  workbench: "Bauen · Erstellen · Kollaborieren — prompt zu Artefakt, mit ehrlichem Run-State.",
  agents: "4 deterministische Agent-Profile — planner, coder, tester, devops.",
  tools: "MCP-Tools + Provider-Zugriff — Write-Scopes bleiben bis Freigabe gated.",
  models: "LLM-Routing, Fallbacks, Safety und Kostenkontrolle.",
  marketplace: "Skills, Agents, MCP-Tools und Modelle zum Komponieren.",
  observe: "Health, Traces, Metriken, Kosten und Evidence.",
  memory: "PostgreSQL pgvector Long-Term Memory und Wissen.",
  cloud: "Sieben-Layer Multi-Cloud Architektur über mehrere Provider.",
};

function detectCaps() {
  let webgl2 = false;
  let gpu = "WebGL";
  try {
    if (typeof document !== "undefined") {
      const c = document.createElement("canvas");
      const gl = (c.getContext("webgl2") || c.getContext("webgl")) as WebGLRenderingContext | null;
      webgl2 = !!c.getContext("webgl2");
      const dbg = gl?.getExtension("WEBGL_debug_renderer_info");
      if (gl && dbg) gpu = String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) || "WebGL").replace(/^ANGLE \(([^,]+),.*$/, "$1").slice(0, 38);
    }
  } catch {
    webgl2 = false;
  }
  const webgpu = typeof navigator !== "undefined" && "gpu" in navigator;
  return { webgpu, webgl2, gpu };
}

export default function OrganismView({ mode = "live" }: { mode?: "live" | "replay" | "map" }) {
  const [runState, setRunState] = useState<RunState>("planning");
  const [active, setActive] = useState<string>("workbench");
  const [layers, setLayers] = useState<string[]>(LAYERS.map((l) => l.code));
  const [agents, setAgents] = useState<string[]>([...ORGANISM_AGENTS]);
  const [stats, setStats] = useState<{ fps: number; nodes: number; ms: number }>({ fps: 0, nodes: 0, ms: 0 });
  const [feed, setFeed] = useState<{ source: string; live: boolean; hubs: Record<string, string> } | null>(null);
  // Phase-6 (Scale & 3D) frontend controls
  const [autoRotate, setAutoRotate] = useState(true);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [resetSignal, setResetSignal] = useState(0);
  const [renderMode, setRenderMode] = useState<"2d" | "3d">("3d");
  const [caps] = useState(detectCaps);

  // Bind to the organism live-state feed: real when the configured agent-api is
  // reachable (source: "agent-api"), honest deterministic spec-only otherwise.
  useEffect(() => {
    let alive = true;
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 1500);
    fetch("/api/v1/organism/live-state", { cache: "no-store", signal: ctrl.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then((d: { source?: string; live?: boolean; run_state?: string; hubs?: Array<{ id: string; status: string }> } | null) => {
        if (!alive || !d) return;
        const hubs: Record<string, string> = {};
        (d.hubs ?? []).forEach((h) => (hubs[h.id] = h.status));
        setFeed({ source: d.source ?? "spec_only", live: !!d.live, hubs });
        if (d.run_state && STATES.includes(d.run_state as RunState)) setRunState(d.run_state as RunState);
      })
      .catch((err) => {
        if (process.env.NODE_ENV !== "production") console.error("organism live-state fetch failed:", err);
      })
      .finally(() => clearTimeout(timer));
    return () => {
      alive = false;
      ctrl.abort();
    };
  }, []);

  const hub = HUBS.find((h) => h.id === active);
  const onStats = useCallback((fps: number, nodes: number, ms: number) => setStats({ fps, nodes, ms }), []);
  const onMode = useCallback((m: "2d" | "3d") => setRenderMode(m), []);
  const toggleAutoRotate = useCallback(() => setAutoRotate((v) => !v), []);
  const toggleLayer = (c: string) => setLayers((p) => (p.includes(c) ? p.filter((x) => x !== c) : [...p, c]));
  const toggleAgent = (a: string) => setAgents((p) => (p.includes(a) ? p.filter((x) => x !== a) : [...p, a]));

  return (
    <div className="page-wide">
      <div className="page-head" style={{ marginBottom: 14 }}>
        <div>
          <div className="eyebrow">Cortex Canvas{mode !== "live" ? ` · ${mode}` : ""}</div>
          <h1 style={{ fontSize: 22 }}>Kollektiver Organismus</h1>
          <p style={{ fontSize: 13.5, color: "var(--text-mut)", marginTop: 4, maxWidth: "62ch" }}>
            Eine live 3D-Karte des Superbrain: ein glühender Neural-Core mit Capability-Hubs in Umlaufbahnen.
            Filtere nach Architektur-Layer oder Agent; der Inspector öffnet jeden Hub.
          </p>
        </div>
        <div className="chips">
          <Link href="/organism" className={`chip${mode === "live" ? " active" : ""}`}>Live</Link>
          <Link href="/organism/replay" className={`chip${mode === "replay" ? " active" : ""}`}>Replay</Link>
          <Link href="/organism/map" className={`chip${mode === "map" ? " active" : ""}`}>Karte</Link>
        </div>
      </div>

      <div className="grid" style={{ gridTemplateColumns: "1fr 300px" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ height: 600, position: "relative" }}>
            <CortexLive
              runState={runState}
              nodeCount={1600}
              activeRegion={active}
              onSelectRegion={setActive}
              interactive
              visibleLayers={layers}
              visibleAgents={agents}
              onStats={onStats}
              autoRotate={autoRotate}
              paused={reducedMotion}
              resetSignal={resetSignal}
              onToggleAutoRotate={toggleAutoRotate}
              forceReducedMotion={reducedMotion}
              onMode={onMode}
              sourceLabel={feed?.live ? "LIVE · ORGANISM" : "SPEC · ORGANISM"}
            />
            {/* Debug / performance HUD overlay (frame budget = Phase-6 perf slice) */}
            <div className="org-hud" aria-hidden="true">
              <span className="mono">{stats.fps} FPS</span>
              <span className="mono">{stats.ms}ms</span>
              <span className="mono">{stats.nodes} nodes</span>
              <span className="mono">{renderMode === "3d" ? (caps.webgpu ? "WebGPU✓" : "WebGL2") : "2D"}</span>
              {feed ? (
                <span className={`org-feed ${feed.live ? "live" : "spec"}`} title={`live-state source: ${feed.source}`}>
                  {feed.live ? `LIVE · ${feed.source}` : `SPEC · ${feed.source}`}
                </span>
              ) : null}
            </div>
            {/* OPA gate badges overlay */}
            <div className="org-gates">
              {CLOSED_GATES.slice(0, 4).map((g) => (
                <span key={g} className="org-gate" title={`${g} Gate ist geschlossen`}>{g} · GESCHLOSSEN</span>
              ))}
            </div>
          </div>

          <div className="panel panel-pad" style={{ display: "flex", alignItems: "center", gap: 14, flexWrap: "wrap" }}>
            <span className="panel-title">Run-State</span>
            <div className="state-row">
              {STATES.map((s) => (
                <button key={s} className={`state-btn${s === runState ? " active" : ""}`} onClick={() => setRunState(s)}>
                  {STATE_LABEL[s]}
                </button>
              ))}
            </div>
          </div>

          {/* Phase-6 (Scale & 3D Platform) — scene controls + capability + perf budget */}
          <div className="panel panel-pad" style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
            <span className="panel-title">3D-Szene</span>
            <div className="state-row">
              <button className={`state-btn${autoRotate && !reducedMotion ? " active" : ""}`} onClick={toggleAutoRotate} disabled={reducedMotion} title="Space">
                {autoRotate ? "Auto-rotate ⏸" : "Auto-rotate ▶"}
              </button>
              <button className="state-btn" onClick={() => setResetSignal((n) => n + 1)} title="R">Kamera zurücksetzen</button>
              <button className={`state-btn${reducedMotion ? " active" : ""}`} onClick={() => setReducedMotion((v) => !v)} title="Motion-sickness guard">
                {reducedMotion ? "Weniger Bewegung ✓" : "Weniger Bewegung"}
              </button>
            </div>
            <span className="cap-badge" title={`renderer: ${caps.gpu}`}>
              <span className={`cap-dot ${caps.webgpu ? "gpu" : caps.webgl2 ? "ok" : "soft"}`} />
              {renderMode === "2d" ? "2D-Fallback" : caps.webgpu ? "WebGPU verfügbar · WebGL2 aktiv" : "WebGL2"}
            </span>
            <span className="mono" style={{ fontSize: 11, color: "var(--text-dim)", marginLeft: "auto" }}>
              {stats.fps} FPS · {stats.ms}ms/frame
            </span>
            <span className="mono" style={{ fontSize: 10.5, color: "var(--text-dim)", flexBasis: "100%" }}>
              Tastatur: ←→ rotieren · ↑↓ kippen · +/- zoomen · R reset · Space auto-rotate
            </span>
          </div>

          <div className="panel panel-pad">
            <div className="row" style={{ gap: 16, flexWrap: "wrap", alignItems: "flex-start" }}>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 6 }}>Layer-Filter</span>
                <div className="chip-wrap">
                  {LAYERS.map((l) => (
                    <button
                      key={l.code}
                      className={`filter-chip${layers.includes(l.code) ? " on" : ""}`}
                      style={layers.includes(l.code) ? { color: l.color, borderColor: l.color } : undefined}
                      onClick={() => toggleLayer(l.code)}
                    >
                      L{l.no} {l.code}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 6 }}>Agent-Filter</span>
                <div className="chip-wrap">
                  {ORGANISM_AGENTS.map((a) => (
                    <button
                      key={a}
                      className={`filter-chip${agents.includes(a) ? " on" : ""}`}
                      onClick={() => toggleAgent(a)}
                    >
                      {a}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        <aside className="stack">
          <section className="panel">
            <div className="panel-head"><span className="panel-title">Capability-Hubs</span></div>
            <div className="legend" style={{ padding: 6 }}>
              {HUBS.map((h) => (
                <button key={h.id} className={`lg-row${h.id === active ? " active" : ""}`} onClick={() => setActive(h.id)}>
                  <span className="lg-dot" style={{ background: h.color }} />
                  <span>{h.label}</span>
                  {feed?.hubs[h.id] === "active" ? <span className="lg-pip" title="feed: active" style={{ marginLeft: "auto" }} /> : null}
                  <span className="lg-cap" style={feed?.hubs[h.id] === "active" ? { marginLeft: 6 } : { marginLeft: "auto" }}>L{LAYERS.find((l) => l.code === h.layer)?.no}</span>
                </button>
              ))}
            </div>
          </section>

          {hub ? (
            <section className="panel panel-pad">
              <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>Inspector</span>
              <div className="row" style={{ alignItems: "center", gap: 8 }}>
                <span className="lg-dot" style={{ background: hub.color }} />
                <h3 style={{ fontSize: 15 }}>{hub.label}</h3>
              </div>
              <p style={{ fontSize: 13, color: "var(--text-mut)", marginTop: 8 }}>{HUB_DESC[hub.id]}</p>
              <p className="inspect-label">Agenten</p>
              <div className="chip-wrap">
                {hub.agents.map((a) => <span key={a} className="tool-chip mono">{a}</span>)}
              </div>
              <Link href={hub.route} className="btn btn-sm" style={{ marginTop: 12 }}>{hub.label} öffnen →</Link>
            </section>
          ) : null}

          <div className="note">
            Data-driven, niemals fake-live. Der HUD-Badge zeigt die{" "}
            <span className="mono">/api/v1/organism/live-state</span>-Quelle:{" "}
            <span className="mono">LIVE · agent-api</span>, wenn eine konfigurierte Runtime erreichbar ist,{" "}
            <span className="mono">SPEC</span> sonst. Hub-State kommt aus dem agent-api{" "}
            <span className="mono">cloud-layer-readiness</span>-Contract; LLM bleibt Gateway-bound und write-gated.
            Weniger Bewegung zeigt eine statische 2D-Topologie.
          </div>
        </aside>
      </div>
    </div>
  );
}
