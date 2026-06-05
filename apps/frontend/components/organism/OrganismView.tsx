"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import CortexLive from "./CortexLive";
import { HUBS, LAYERS, ORGANISM_AGENTS, STATE_LABEL, type RunState } from "./regionMap";
import { CLOSED_GATES } from "../../lib/platform";

const STATES: RunState[] = ["idle", "planning", "executing", "verifying", "blocked"];

const HUB_DESC: Record<string, string> = {
  workbench: "Build · Create · Collaborate — prompt to artifact, with honest run state.",
  agents: "4 deterministic agent profiles — planner, coder, tester, devops.",
  tools: "MCP tools + provider access — write scopes gated until approved.",
  models: "LLM routing, fallbacks, safety and cost control.",
  marketplace: "Skills, agents, MCP tools and models to compose.",
  observe: "Health, traces, metrics, costs and evidence.",
  memory: "PostgreSQL pgvector long-term memory and knowledge.",
  cloud: "Seven-layer multi-cloud architecture across eight providers.",
};

export default function OrganismView({ mode = "live" }: { mode?: "live" | "replay" | "map" }) {
  const [runState, setRunState] = useState<RunState>("planning");
  const [active, setActive] = useState<string>("workbench");
  const [layers, setLayers] = useState<string[]>(LAYERS.map((l) => l.code));
  const [agents, setAgents] = useState<string[]>([...ORGANISM_AGENTS]);
  const [stats, setStats] = useState<{ fps: number; nodes: number }>({ fps: 0, nodes: 0 });
  const [feed, setFeed] = useState<{ source: string; live: boolean; hubs: Record<string, string> } | null>(null);

  // Bind to the organism live-state feed: real when the local agent-api is
  // reachable (source: "agent-api"), honest deterministic mock otherwise.
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
        setFeed({ source: d.source ?? "mock", live: !!d.live, hubs });
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
  const onStats = useCallback((fps: number, nodes: number) => setStats({ fps, nodes }), []);
  const toggleLayer = (c: string) => setLayers((p) => (p.includes(c) ? p.filter((x) => x !== c) : [...p, c]));
  const toggleAgent = (a: string) => setAgents((p) => (p.includes(a) ? p.filter((x) => x !== a) : [...p, a]));

  return (
    <div className="page-wide">
      <div className="page-head" style={{ marginBottom: 14 }}>
        <div>
          <div className="eyebrow">Cortex Canvas{mode !== "live" ? ` · ${mode}` : ""}</div>
          <h1 style={{ fontSize: 22 }}>Collective Organism</h1>
          <p style={{ fontSize: 13.5, color: "var(--text-mut)", marginTop: 4, maxWidth: "62ch" }}>
            A live 3D map of the Superbrain: a glowing neural core orbited by its capability hubs.
            Filter by architecture layer or agent; the inspector opens each hub.
          </p>
        </div>
        <div className="chips">
          <Link href="/organism" className={`chip${mode === "live" ? " active" : ""}`}>Live</Link>
          <Link href="/organism/replay" className={`chip${mode === "replay" ? " active" : ""}`}>Replay</Link>
          <Link href="/organism/map" className={`chip${mode === "map" ? " active" : ""}`}>Map</Link>
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
            />
            {/* Debug / performance HUD overlay */}
            <div className="org-hud" aria-hidden="true">
              <span className="mono">{stats.fps} FPS</span>
              <span className="mono">{stats.nodes} nodes</span>
              <span className="mono">hub:{active}</span>
              {feed ? (
                <span className={`org-feed ${feed.live ? "live" : "mock"}`} title={`live-state source: ${feed.source}`}>
                  {feed.live ? `LIVE · ${feed.source}` : `MOCK · ${feed.source}`}
                </span>
              ) : null}
            </div>
            {/* OPA gate badges overlay */}
            <div className="org-gates">
              {CLOSED_GATES.slice(0, 4).map((g) => (
                <span key={g} className="org-gate" title={`${g} gate is closed`}>{g} · CLOSED</span>
              ))}
            </div>
          </div>

          <div className="panel panel-pad" style={{ display: "flex", alignItems: "center", gap: 14, flexWrap: "wrap" }}>
            <span className="panel-title">Run state</span>
            <div className="state-row">
              {STATES.map((s) => (
                <button key={s} className={`state-btn${s === runState ? " active" : ""}`} onClick={() => setRunState(s)}>
                  {STATE_LABEL[s]}
                </button>
              ))}
            </div>
          </div>

          <div className="panel panel-pad">
            <div className="row" style={{ gap: 16, flexWrap: "wrap", alignItems: "flex-start" }}>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 6 }}>Layer filter</span>
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
                <span className="panel-title" style={{ display: "block", marginBottom: 6 }}>Agent filter</span>
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
            <div className="panel-head"><span className="panel-title">Capability hubs</span></div>
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
              <p className="inspect-label">Agents</p>
              <div className="chip-wrap">
                {hub.agents.map((a) => <span key={a} className="tool-chip mono">{a}</span>)}
              </div>
              <Link href={hub.route} className="btn btn-sm" style={{ marginTop: 12 }}>Open {hub.label} →</Link>
            </section>
          ) : null}

          <div className="note">
            Data-driven, never fake-live. The HUD badge shows the{" "}
            <span className="mono">/api/v1/organism/live-state</span> source:{" "}
            <span className="mono">LIVE · agent-api</span> when the local cloud-layer runtime is reachable,{" "}
            <span className="mono">MOCK</span> otherwise (e.g. on Vercel). Hub state is derived from the agent-api{" "}
            <span className="mono">cloud-layer-readiness</span> contract; LLM stays in deterministic dry-run.
            Reduced motion shows a static 2D topology.
          </div>
        </aside>
      </div>
    </div>
  );
}
