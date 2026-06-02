"use client";

import { useState } from "react";
import Link from "next/link";
import CortexLive from "./CortexLive";
import { HUBS, STATE_LABEL, type RunState } from "./regionMap";

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
  const hub = HUBS.find((h) => h.id === active);

  return (
    <div className="page-wide">
      <PageHeaderInline mode={mode} />

      <div className="grid" style={{ gridTemplateColumns: "1fr 300px" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ height: 600 }}>
            <CortexLive
              runState={runState}
              nodeCount={1600}
              activeRegion={active}
              onSelectRegion={setActive}
              interactive
            />
          </div>
          <div className="panel panel-pad" style={{ display: "flex", alignItems: "center", gap: 14, flexWrap: "wrap" }}>
            <span className="panel-title">Run state</span>
            <div className="state-row">
              {STATES.map((s) => (
                <button
                  key={s}
                  className={`state-btn${s === runState ? " active" : ""}`}
                  onClick={() => setRunState(s)}
                >
                  {STATE_LABEL[s]}
                </button>
              ))}
            </div>
            <span style={{ marginLeft: "auto", fontSize: 12, color: "var(--text-dim)" }}>
              {mode === "replay" ? "Timeline-driven from recorded events" : "State drives core / halo / link colour"}
            </span>
          </div>
        </div>

        <aside className="stack">
          <section className="panel">
            <div className="panel-head"><span className="panel-title">Capability hubs</span></div>
            <div className="legend" style={{ padding: 6 }}>
              {HUBS.map((h) => (
                <button
                  key={h.id}
                  className={`lg-row${h.id === active ? " active" : ""}`}
                  onClick={() => setActive(h.id)}
                >
                  <span className="lg-dot" style={{ background: h.color }} />
                  <span>{h.label}</span>
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
              <Link href={hub.route} className="btn btn-sm" style={{ marginTop: 12 }}>
                Open {hub.label} →
              </Link>
            </section>
          ) : null}

          <div className="note">
            The central organism connects to every capability hub. Pulses flow inward along each
            link (data / events) — data-driven, never fake-live. Reduced motion shows a static 2D
            topology with the same contract.
          </div>
        </aside>
      </div>
    </div>
  );
}

function PageHeaderInline({ mode }: { mode: "live" | "replay" | "map" }) {
  return (
    <div className="page-head" style={{ marginBottom: 14 }}>
      <div>
        <div className="eyebrow">Cortex Canvas{mode !== "live" ? ` · ${mode}` : ""}</div>
        <h1 style={{ fontSize: 22 }}>Collective Organism</h1>
        <p style={{ fontSize: 13.5, color: "var(--text-mut)", marginTop: 4, maxWidth: "62ch" }}>
          A live 3D map of the Superbrain: a glowing neural core orbited by its capability hubs —
          workbench, agents, tools, models, marketplace, observability, memory and cloud.
        </p>
      </div>
      <div className="chips">
        <Link href="/organism" className={`chip${mode === "live" ? " active" : ""}`}>Live</Link>
        <Link href="/organism/replay" className={`chip${mode === "replay" ? " active" : ""}`}>Replay</Link>
        <Link href="/organism/map" className={`chip${mode === "map" ? " active" : ""}`}>Map</Link>
      </div>
    </div>
  );
}
