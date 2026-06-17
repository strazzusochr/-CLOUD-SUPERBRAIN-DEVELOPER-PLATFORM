"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import CortexLive from "./CortexLive";
import { HUBS, LAYERS, ORGANISM_AGENTS, STATE_LABEL, type RunState } from "./regionMap";
import { CLOSED_GATES } from "../../lib/platform";

const STATES: RunState[] = ["idle", "planning", "executing", "verifying", "blocked"];
const DEFAULT_CAPS = { webgpu: false, webgl2: false, gpu: "WebGL" };

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

type OrganismRuntimeEvent = {
  seq?: number;
  offset_s?: number;
  kind?: string;
  event_type?: string;
  hub?: string;
  route?: string;
  run_state?: string;
  regions?: string[];
  severity?: string;
  source_kind?: string;
  secret_output?: boolean;
  writes?: boolean;
};

type OrganismReplayFrame = {
  t?: number;
  run_state?: string;
  active?: string[];
  regions?: string[];
  source_kind?: string;
};

type RuntimeProjection = {
  source: string;
  sourceKind: string;
  live: boolean;
  runId: string | null;
  note: string;
  nonClaims: string[];
  events: OrganismRuntimeEvent[];
  frames: OrganismReplayFrame[];
  replayAvailable: boolean;
};

function normalizeRunState(value: unknown, fallback: RunState): RunState {
  return typeof value === "string" && STATES.includes(value as RunState) ? (value as RunState) : fallback;
}

function readRequestedRunId(): string {
  if (typeof window === "undefined") return "";
  const raw = new URLSearchParams(window.location.search).get("run_id") ?? "";
  const trimmed = raw.trim();
  return /^[A-Za-z0-9_.:-]{1,96}$/.test(trimmed) ? trimmed : "";
}

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

function isExpectedAbort(error: unknown, ctrl: AbortController) {
  if (ctrl.signal.aborted) return true;
  if (error instanceof DOMException && error.name === "AbortError") return true;
  if (error instanceof Error && error.name === "AbortError") return true;
  return false;
}

function abortQuietly(ctrl: AbortController, reason: string) {
  if (ctrl.signal.aborted) return;
  const abortReason = typeof DOMException !== "undefined" ? new DOMException(reason, "AbortError") : reason;
  ctrl.abort(abortReason);
}

export default function OrganismView({ mode = "live" }: { mode?: "live" | "replay" | "map" }) {
  const [runState, setRunState] = useState<RunState>("planning");
  const [active, setActive] = useState<string>("workbench");
  const [layers, setLayers] = useState<string[]>(LAYERS.map((l) => l.code));
  const [agents, setAgents] = useState<string[]>([...ORGANISM_AGENTS]);
  const [stats, setStats] = useState<{ fps: number; nodes: number; ms: number }>({ fps: 0, nodes: 0, ms: 0 });
  const [feed, setFeed] = useState<{ source: string; live: boolean; hubs: Record<string, string> } | null>(null);
  const [runtimeFeed, setRuntimeFeed] = useState<RuntimeProjection | null>(null);
  // Phase-6 (Scale & 3D) frontend controls
  const [autoRotate, setAutoRotate] = useState(true);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [resetSignal, setResetSignal] = useState(0);
  const [renderMode, setRenderMode] = useState<"2d" | "3d">("3d");
  const [caps, setCaps] = useState(DEFAULT_CAPS);
  const [interactionStatus, setInteractionStatus] = useState("waiting_for_organism_interaction");

  // Bind to the organism live-state feed: real when the configured agent-api is
  // reachable (source: "agent-api"), honest deterministic spec-only otherwise.
  useEffect(() => {
    let alive = true;
    const ctrl = new AbortController();
    const timer = setTimeout(() => abortQuietly(ctrl, "organism live-state timeout"), 1500);
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
        if (!alive || isExpectedAbort(err, ctrl)) return;
        if (process.env.NODE_ENV !== "production") console.error("organism live-state fetch failed:", err);
      })
      .finally(() => clearTimeout(timer));
    return () => {
      alive = false;
      clearTimeout(timer);
      abortQuietly(ctrl, "organism live-state effect disposed");
    };
  }, []);

  useEffect(() => {
    let alive = true;
    const ctrl = new AbortController();
    const timer = setTimeout(() => abortQuietly(ctrl, "organism runtime projection timeout"), 2500);
    const requestedRunId = readRequestedRunId();
    const query = requestedRunId ? `?run_id=${encodeURIComponent(requestedRunId)}` : "";
    Promise.all([
      fetch(`/api/v1/organism/events${query}`, { cache: "no-store", signal: ctrl.signal }).then((r) => (r.ok ? r.json() : null)),
      fetch(`/api/v1/organism/replay${query}`, { cache: "no-store", signal: ctrl.signal }).then((r) => (r.ok ? r.json() : null)),
    ])
      .then(([eventsBody, replayBody]: [
        {
          source?: string;
          source_kind?: string;
          live?: boolean;
          run_id?: string | null;
          note?: string;
          non_claims?: string[];
          events?: OrganismRuntimeEvent[];
        } | null,
        {
          source_kind?: string;
          replay_available?: boolean;
          frames?: OrganismReplayFrame[];
          non_claims?: string[];
        } | null,
      ]) => {
        if (!alive || !eventsBody) return;
        const events = Array.isArray(eventsBody.events) ? eventsBody.events : [];
        const frames = Array.isArray(replayBody?.frames) ? replayBody.frames : [];
        const latestEvent = events[events.length - 1];
        const latestFrame = frames[frames.length - 1];
        const nextActive = latestFrame?.active?.[0] ?? latestEvent?.hub;
        const nextState = latestFrame?.run_state ?? latestEvent?.run_state;
        if (nextActive && HUBS.some((h) => h.id === nextActive)) setActive(nextActive);
        if (nextState) setRunState((current) => normalizeRunState(nextState, current));
        setRuntimeFeed({
          source: eventsBody.source ?? "spec_only",
          sourceKind: eventsBody.source_kind ?? replayBody?.source_kind ?? "spec_only",
          live: !!eventsBody.live,
          runId: (eventsBody.run_id ?? requestedRunId) || null,
          note: eventsBody.note ?? "",
          nonClaims: [...(eventsBody.non_claims ?? []), ...(replayBody?.non_claims ?? [])],
          events,
          frames,
          replayAvailable: !!replayBody?.replay_available,
        });
      })
      .catch((err) => {
        if (!alive || isExpectedAbort(err, ctrl)) return;
        if (process.env.NODE_ENV !== "production") console.error("organism runtime projection fetch failed:", err);
      })
      .finally(() => clearTimeout(timer));
    return () => {
      alive = false;
      clearTimeout(timer);
      abortQuietly(ctrl, "organism runtime projection effect disposed");
    };
  }, []);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      setCaps(detectCaps());
    });
    return () => window.cancelAnimationFrame(frame);
  }, []);

  const hub = HUBS.find((h) => h.id === active);
  const onStats = useCallback((fps: number, nodes: number, ms: number) => setStats({ fps, nodes, ms }), []);
  const onMode = useCallback((m: "2d" | "3d") => setRenderMode(m), []);
  const markInteraction = useCallback((kind: string, value: string) => {
    setInteractionStatus([
      "PASS organism_control",
      `kind=${kind}`,
      `value=${value}`,
      "evidence=visible_result_text",
      "live_provider_calls=false",
      "live_mcp_writes=false",
    ].join("\n"));
  }, []);
  const selectRunState = useCallback((state: RunState) => {
    setRunState(state);
    markInteraction("run_state", state);
  }, [markInteraction]);
  const selectHub = useCallback((hubId: string) => {
    setActive(hubId);
    markInteraction("hub", hubId);
  }, [markInteraction]);
  const toggleAutoRotate = useCallback(() => {
    setAutoRotate((value) => {
      const next = !value;
      markInteraction("auto_rotate", String(next));
      return next;
    });
  }, [markInteraction]);
  const resetCamera = useCallback(() => {
    setResetSignal((n) => n + 1);
    markInteraction("camera_reset", "requested");
  }, [markInteraction]);
  const toggleReducedMotion = useCallback(() => {
    setReducedMotion((value) => {
      const next = !value;
      markInteraction("reduced_motion", String(next));
      return next;
    });
  }, [markInteraction]);
  const toggleLayer = (c: string) => {
    setLayers((p) => {
      const next = p.includes(c) ? p.filter((x) => x !== c) : [...p, c];
      markInteraction("layer_filter", `${c}:${next.includes(c) ? "on" : "off"}`);
      return next;
    });
  };
  const toggleAgent = (a: string) => {
    setAgents((p) => {
      const next = p.includes(a) ? p.filter((x) => x !== a) : [...p, a];
      markInteraction("agent_filter", `${a}:${next.includes(a) ? "on" : "off"}`);
      return next;
    });
  };
  const visibleEvents = runtimeFeed?.events.slice(-6).reverse() ?? [];
  const visibleFrames = runtimeFeed?.frames.slice(-4).reverse() ?? [];
  const runtimeSourceLabel = runtimeFeed?.live
    ? `LIVE · ${runtimeFeed.sourceKind}`
    : feed?.live
      ? `LIVE · ${feed.source}`
      : runtimeFeed
        ? `SPEC · ${runtimeFeed.sourceKind}`
        : "SPEC · ORGANISM";

  return (
    <div className="page-wide">
      <div className="page-head organism-head">
        <div>
          <div className="eyebrow">Cortex Canvas{mode !== "live" ? ` · ${mode}` : ""}</div>
          <h1 className="organism-title">Kollektiver Organismus</h1>
          <p className="organism-subtitle">
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

      <div className="grid organism-layout-grid">
        <div className="stack stack-gap-12">
          <div className="organism-canvas-shell">
            <CortexLive
              runState={runState}
              nodeCount={1600}
              activeRegion={active}
              onSelectRegion={selectHub}
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
              sourceLabel={runtimeSourceLabel}
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
              {runtimeFeed ? (
                <span className={`org-feed ${runtimeFeed.live ? "live" : "spec"}`} title={`runtime source: ${runtimeFeed.sourceKind}`}>
                  {runtimeFeed.live ? "EVENTS · LIVE" : "EVENTS · SPEC"}
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

          <div className="panel panel-pad organism-mode-bar">
            <span className="panel-title">Run-State</span>
            <div className="state-row">
              {STATES.map((s) => (
                <button key={s} className={`state-btn${s === runState ? " active" : ""}`} onClick={() => selectRunState(s)}>
                  {STATE_LABEL[s]}
                </button>
              ))}
            </div>
          </div>

          {/* Phase-6 (Scale & 3D Platform) — scene controls + capability + perf budget */}
          <div className="panel panel-pad organism-scene-bar">
            <span className="panel-title">3D-Szene</span>
            <div className="state-row">
              <button
                className={`state-btn${autoRotate && !reducedMotion ? " active" : ""}`}
                onClick={toggleAutoRotate}
                disabled={reducedMotion}
                title={reducedMotion ? "Disabled while reduced-motion mode is active" : "Space"}
              >
                {autoRotate ? "Auto-rotate ⏸" : "Auto-rotate ▶"}
              </button>
              <button className="state-btn" onClick={resetCamera} title="R">Kamera zurücksetzen</button>
              <button className={`state-btn${reducedMotion ? " active" : ""}`} onClick={toggleReducedMotion} title="Motion-sickness guard">
                {reducedMotion ? "Weniger Bewegung ✓" : "Weniger Bewegung"}
              </button>
            </div>
            <span className="cap-badge" title={`renderer: ${caps.gpu}`}>
              <span className={`cap-dot ${caps.webgpu ? "gpu" : caps.webgl2 ? "ok" : "soft"}`} />
              {renderMode === "2d" ? "2D-Fallback" : caps.webgpu ? "WebGPU verfügbar · WebGL2 aktiv" : "WebGL2"}
            </span>
            <span className="mono organism-fps">
              {stats.fps} FPS · {stats.ms}ms/frame
            </span>
            <span className="mono organism-hints">
              Tastatur: ←→ rotieren · ↑↓ kippen · +/- zoomen · R reset · Space auto-rotate
            </span>
            <span className="mono organism-hints">
              GPU-sicher: 30 FPS-Limit · low-power · pausiert automatisch im Hintergrund/außerhalb des Sichtfelds · «Weniger Bewegung» friert die Szene ein
            </span>
            <pre className="goalb-result mono organism-action-result" data-testid="batch1-organism-action-result" aria-live="polite">
              {interactionStatus}
            </pre>
          </div>

          <div className="panel panel-pad">
            <div className="row organism-filters-row">
              <div>
                <div className="panel-title mb-6">Layer-Filter</div>
                <div className="chip-wrap">
                  {LAYERS.map((l) => (
                    <button
                      key={l.code}
                      className={`filter-chip layer-chip layer-${l.code}${layers.includes(l.code) ? " on" : ""}`}
                      onClick={() => toggleLayer(l.code)}
                    >
                      L{l.no} {l.code}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <div className="panel-title mb-6">Agent-Filter</div>
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
          <section
            className="panel organism-runtime-feed"
            data-testid="organism-runtime-feed"
            data-source-kind={runtimeFeed?.sourceKind ?? "loading"}
            data-live={runtimeFeed?.live ? "true" : "false"}
            data-run-id={runtimeFeed?.runId ?? ""}
          >
            <div className="panel-head">
              <span className="panel-title">Runtime Events</span>
              <span className={`org-feed ${runtimeFeed?.live ? "live" : "spec"}`}>
                {runtimeFeed?.live ? "agent_api_redacted" : runtimeFeed?.sourceKind ?? "loading"}
              </span>
            </div>
            <div className="runtime-meta">
              <span className="mono">{runtimeFeed?.events.length ?? 0} events</span>
              <span className="mono">{runtimeFeed?.frames.length ?? 0} frames</span>
              <span className="mono">{runtimeFeed?.replayAvailable ? "replay_available=true" : "replay_available=false"}</span>
              {runtimeFeed?.runId ? <span className="mono">run_id={runtimeFeed.runId}</span> : null}
            </div>
            <div className="runtime-list">
              {visibleEvents.length ? visibleEvents.map((event, index) => (
                <div key={`${event.seq ?? index}-${event.kind ?? event.event_type ?? "event"}`} className="runtime-event-row">
                  <span className="runtime-event-dot" />
                  <div>
                    <div className="runtime-event-title">
                      <span>{event.kind ?? event.event_type ?? "runtime_event"}</span>
                      <span className="mono">{event.hub ?? "workbench"}</span>
                    </div>
                    <div className="runtime-event-meta">
                      <span className="mono">{event.run_state ?? "executing"}</span>
                      <span className="mono">{event.severity ?? "info"}</span>
                      <span className="mono">{event.source_kind ?? runtimeFeed?.sourceKind ?? "spec_only"}</span>
                    </div>
                  </div>
                </div>
              )) : (
                <div className="runtime-empty">runtime feed pending</div>
              )}
            </div>
            {mode === "replay" ? (
              <div className="runtime-frames" data-testid="organism-replay-frames">
                {visibleFrames.map((frame, index) => (
                  <div key={`${frame.t ?? index}-${frame.active?.join("-") ?? "frame"}`} className="runtime-frame-row">
                    <span className="mono">{Number(frame.t ?? 0).toFixed(1)}s</span>
                    <span>{frame.active?.join(", ") || "idle"}</span>
                    <span className="mono">{frame.run_state ?? "idle"}</span>
                  </div>
                ))}
              </div>
            ) : null}
            <div className="runtime-guard">
              <span>read-only audit projection</span>
              <span>no raw details</span>
            </div>
          </section>

          <section className="panel">
            <div className="panel-head"><span className="panel-title">Capability-Hubs</span></div>
            <div className="legend legend-pad">
              {HUBS.map((h) => (
                <button key={h.id} className={`lg-row${h.id === active ? " active" : ""}`} onClick={() => selectHub(h.id)}>
                  <span className={`lg-dot hub-dot hub-${h.id}`} />
                  <span>{h.label}</span>
                  {feed?.hubs[h.id] === "active" ? <span className="lg-pip ml-auto" title="feed: active" /> : null}
                  <span className={`lg-cap ${feed?.hubs[h.id] === "active" ? "ml-6" : "ml-auto"}`}>L{LAYERS.find((l) => l.code === h.layer)?.no}</span>
                </button>
              ))}
            </div>
          </section>

          {hub ? (
            <section className="panel panel-pad">
              <div className="panel-title mb-8">Inspector</div>
              <div className="row align-center gap-8">
                <span className={`lg-dot hub-dot hub-${hub.id}`} />
                <h3 className="organism-hub-title">{hub.label}</h3>
              </div>
              <p className="organism-hub-desc">{HUB_DESC[hub.id]}</p>
              <p className="inspect-label">Agenten</p>
              <div className="chip-wrap">
                {hub.agents.map((a) => <span key={a} className="tool-chip mono">{a}</span>)}
              </div>
              <Link href={hub.route} className="btn btn-sm mt-12">{hub.label} öffnen →</Link>
            </section>
          ) : null}

          <div className="note">
            Data-driven, niemals fake-live. Live-State kommt aus{" "}
            <span className="mono">/api/v1/organism/live-state</span>; Events und Replay kommen aus{" "}
            <span className="mono">/api/v1/organism/events</span> und{" "}
            <span className="mono">/api/v1/organism/replay</span>. LLM bleibt Gateway-bound und write-gated.
          </div>
        </aside>
      </div>
    </div>
  );
}
