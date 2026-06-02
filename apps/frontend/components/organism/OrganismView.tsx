"use client";

import { useState } from "react";
import Link from "next/link";
import CortexLive from "./CortexLive";
import { REGIONS, STATE_LABEL, LAYERS, providersForLayer, type RunState } from "./regionMap";
import { PageHeader, Note } from "../ui";

const STATES: RunState[] = ["idle", "planning", "executing", "verifying", "blocked"];

export default function OrganismView({ mode = "live" }: { mode?: "live" | "replay" | "map" }) {
  const [runState, setRunState] = useState<RunState>("planning");
  const [active, setActive] = useState<string>("prefrontal");
  const region = REGIONS.find((r) => r.id === active);

  return (
    <div className="page-wide">
      <PageHeader
        eyebrow={`Cortex Canvas${mode !== "live" ? ` · ${mode}` : ""}`}
        title="Living Cortex"
        subtitle="3D runtime map of the Superbrain. Regions = platform capabilities. Synapses = data flows, tool calls, agent comms. Pulses = events."
        actions={
          <div className="chips">
            <Link href="/organism" className={`chip${mode === "live" ? " active" : ""}`}>Live</Link>
            <Link href="/organism/replay" className={`chip${mode === "replay" ? " active" : ""}`}>Replay</Link>
            <Link href="/organism/map" className={`chip${mode === "map" ? " active" : ""}`}>Map</Link>
          </div>
        }
      />

      <div className="grid" style={{ gridTemplateColumns: "1fr 300px" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ height: 560 }}>
            <CortexLive
              runState={runState}
              nodeCount={620}
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
              {mode === "replay" ? "Timeline-driven from recorded events" : "State drives core / halo / synapse colour"}
            </span>
          </div>
        </div>

        <aside className="stack">
          <section className="panel">
            <div className="panel-head"><span className="panel-title">Regions → Capability</span></div>
            <div className="legend" style={{ padding: 6 }}>
              {REGIONS.map((rg) => (
                <button
                  key={rg.id}
                  className={`lg-row${rg.id === active ? " active" : ""}`}
                  onClick={() => setActive(rg.id)}
                >
                  <span className="lg-dot" style={{ background: rg.color }} />
                  <span>{rg.name}</span>
                  <span className="lg-cap" style={{ marginLeft: "auto" }}>{rg.layer}</span>
                </button>
              ))}
            </div>
          </section>

          {region ? (() => {
            const layer = LAYERS.find((l) => l.code === region.layer);
            const provs = layer ? providersForLayer(layer.no) : [];
            return (
              <section className="panel panel-pad">
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>Inspector</span>
                <h3 style={{ fontSize: 15 }}>{region.name}</h3>
                <p style={{ fontSize: 13, color: "var(--text-mut)", marginTop: 6 }}>{region.cap}</p>
                {layer ? (
                  <>
                    <p className="inspect-label">Architecture layer</p>
                    <div className="row" style={{ alignItems: "center", gap: 8, marginTop: 4 }}>
                      <span className="layer-tag" style={{ background: layer.color, padding: "3px 8px", fontSize: 11 }}>L{layer.no}</span>
                      <span style={{ fontSize: 13, color: "var(--text-pri)" }}>{layer.label}</span>
                    </div>
                    <p className="inspect-label">Cloud providers</p>
                    <div className="layer-providers" style={{ justifyContent: "flex-start", marginTop: 4 }}>
                      {provs.map((p) => (
                        <span key={p.id} className="layer-chip" style={{ color: p.color, borderColor: p.color }} title={p.role}>
                          {p.label}
                        </span>
                      ))}
                    </div>
                  </>
                ) : null}
              </section>
            );
          })() : null}

          <Note>
            Animation is data-driven, never fake-live. Live binding targets the backend run
            surfaces — <span className="mono">GET /api/v1/agents/status</span>,{" "}
            <span className="mono">/tasks/recent</span>,{" "}
            <span className="mono">/session/{"{id}"}/stream</span>. Reduced-motion replaces the
            canvas with a static 2D topology list.
          </Note>
        </aside>
      </div>
    </div>
  );
}
