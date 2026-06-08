import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import CortexCanvas from "../../components/organism/CortexCanvas";
import { Panel, Badge, StatusDot, Note } from "../../components/ui";
import { Icon, WORKSPACE_PAGES } from "../../lib/nav";
import { LAYERS } from "../../components/organism/regionMap";
import { paidCapabilityVisible } from "../../lib/paidCapabilities";

export const metadata = { title: "Workbench — Cloud Superbrain" };
export const dynamic = "force-dynamic";

type SearchParams = Record<string, string | string[] | undefined>;
type WorkbenchPageProps = {
  searchParams?: Promise<SearchParams>;
};

const previewTabs = ["Game View", "App Preview", "Video Preview", "Doc Preview", "3D Model", "Assets"];
const explorerTree = [
  ["assets", "characters", "environments", "ui", "weapons"],
  ["src", "artifact.pipeline.ts", "preview.adapter.ts", "agent-run.ts", "verifier.ts", "ui.lua"],
  ["docs", "README.md", "design-brief.md", "verifier-notes.md"],
];
const codeLines = [
  ["k", "export async function"], ["fn", " buildArtifact"], ["", "(request: WorkbenchRun) {"],
  ["\n  ", ""], ["k", "const"], ["", " plan = "], ["fn", "orchestrator.route"], ["", "(request.prompt)"],
  ["\n  ", ""], ["k", "const"], ["", " bundle = "], ["fn", "agentPool.execute"], ["", "(plan, request.mode)"],
  ["\n  ", ""], ["k", "return"], ["", " "], ["fn", "previewSurface.render"], ["", "(bundle)"],
  ["\n", ""], ["", "}"],
];
const assistSteps = ["Anforderungen analysieren", "Architektur planen", "Artefakt generieren", "Tests und Evidence sammeln"];
const terminalFallback = [
  ["SPEC", "workbench surface loaded", "+0", "00:00:01"],
  ["SPEC", "preview modes registered", "+0", "00:00:03"],
  ["LOCK", "write actions gated", "+0", "00:00:06"],
  ["WAIT", "runtime run not started", "+0", "00:00:08"],
];
const teamAvatars = ["PL", "CD", "TS"];

async function resolveSearchParams(searchParams: WorkbenchPageProps["searchParams"]): Promise<SearchParams> {
  if (!searchParams) return {};
  return searchParams;
}

function firstParam(value: string | string[] | undefined): string | null {
  if (Array.isArray(value)) return value[0] ?? null;
  return value ?? null;
}

export default async function WorkbenchPage({ searchParams }: WorkbenchPageProps) {
  const resolvedSearchParams = await resolveSearchParams(searchParams);
  const showBudget = paidCapabilityVisible(resolvedSearchParams);
  const selectedRunId = firstParam(resolvedSearchParams.run_id) ?? firstParam(resolvedSearchParams.runId);
  const runSelected = Boolean(selectedRunId);
  const workspacePages = [...WORKSPACE_PAGES].sort((a, b) => a.no - b.no);
  const terminalRows = terminalFallback;

  return (
    <AppShell crumb="Main Workbench" runState={runSelected ? "planning" : "idle"}>
      <div className="page-wide workbench-blueprint">
        <h1 className="sr-only">Main Workbench / Central Workspace</h1>

        <section className="industrial-toolbar" aria-label="Workbench toolbar">
          <div className="tool-select">
            {Icon.workbench({ size: 16 })}
            <span>Superbrain Developer Engine</span>
          </div>
          <div className="tool-select mono">
            {Icon.open({ size: 15 })}
            <span>main</span>
          </div>
          <div className="tool-actions" aria-label="Run and tool actions">
            <button className="icon-btn" title="Run action is gated until a runtime run is selected" disabled>{Icon.play({ size: 15 })}</button>
            <button className="icon-btn" title="Tool writes are gated" disabled>{Icon.tools({ size: 15 })}</button>
            <button className="icon-btn" title="Code generation is gated" disabled>{Icon.apps({ size: 15 })}</button>
            <button className="icon-btn" title="Edit action is gated" disabled>{Icon.design({ size: 15 })}</button>
          </div>
          <div className="tool-env">
            <StatusDot tone={runSelected ? "cyan" : "amber"} pulse={runSelected} />
            <span>Cloud Staging</span>
            <small>{runSelected ? "run selected" : "spec-only feed"}</small>
          </div>
          <Link href="/organism" className="btn btn-sm btn-ghost">
            {Icon.organism({ size: 14 })} Cortex
          </Link>
          <div className="team-stack" aria-label="Agent team">
            {teamAvatars.map((agent) => (
              <span key={agent} className="team-avatar" title={`Platform role ${agent}`}>{agent}</span>
            ))}
            <span className="team-avatar muted">+1</span>
          </div>
        </section>

        <section className="wb-studio">
          <aside className="wb-pane wb-explorer">
            <div className="wb-pane-head">
              <span>Explorer</span>
              <button className="icon-btn flat" title="New file">{Icon.files({ size: 14 })}</button>
            </div>
            <div className="wb-tree">
              <div className="tree-root">{Icon.files({ size: 14 })} cloud-superbrain-platform</div>
              {explorerTree.map((group) => (
                <div key={group[0]} className="tree-group">
                  <div className="tree-folder">{group[0]}</div>
                  {group.slice(1).map((item, idx) => (
                    <div key={item} className={`tree-file${item === "artifact.pipeline.ts" ? " selected" : ""}`} style={{ paddingLeft: 22 }}>
                      {idx < 4 ? Icon.docs({ size: 13 }) : Icon.files({ size: 13 })}
                      {item}
                    </div>
                  ))}
                </div>
              ))}
            </div>
            <div className="session-strip">
              <span className="panel-title">Run Binding</span>
              {selectedRunId ? <span className="mono">{selectedRunId}</span> : <span>none selected</span>}
            </div>
          </aside>

          <main className="wb-pane wb-editor">
            <div className="wb-pane-head">
              <span>{Icon.docs({ size: 15 })} artifact.pipeline.ts</span>
              <span className="mono muted-copy">spec template · runtime gated</span>
            </div>
            <pre className="industrial-code" aria-label="Code editor preview">
              {codeLines.map(([cls, text], idx) => (
                <span key={`${idx}-${text}`} className={cls}>{text}</span>
              ))}
            </pre>
          </main>

          <aside className="wb-pane wb-preview">
            <div className="wb-pane-head">
              <span>Preview / Assets</span>
              <Badge tone={runSelected ? "cyan" : "amber"}>{runSelected ? "selected" : "locked"}</Badge>
            </div>
            <div className="preview-tabs" role="tablist" aria-label="Preview modes">
              {previewTabs.map((tab, idx) => (
                <button
                  key={tab}
                  type="button"
                  role="tab"
                  aria-selected={idx === 0}
                  aria-disabled="true"
                  disabled
                  className={idx === 0 ? "active" : ""}
                  title="Preview switching is gated until a runtime run is selected"
                >
                  {tab}
                </button>
              ))}
            </div>
            <div className="game-preview" aria-label="Industrial template preview">
              <div className="preview-sky" />
              <div className="preview-hud">
                <span className="mono">T0</span>
                <i />
                <i />
              </div>
              <div className="preview-world">
                <span className="terrain" />
                <span className="avatar-stand" />
                <span className="objective">SPEC TEMPLATE / LOCKED</span>
              </div>
            </div>
            <div className="asset-strip">
              {["character.glb", "weapon.fbx", "scene.exr", "ui_hud.png", "+12"].map((asset) => (
                <span key={asset}>{asset}</span>
              ))}
            </div>
          </aside>
        </section>

        <section className={`wb-bottom-grid${showBudget ? " with-budget" : ""}`}>
          <Panel title="Prompt Composer">
            <div className="wb-pad stack" style={{ gap: 10 }}>
              <div className="prompt-box">
                Create a third-person combat system with dash, parry and combo moves.
              </div>
              <div className="prompt-row">
                <span>Add context or notes...</span>
                <button className="icon-btn send" title="Prompt execution is gated until a runtime target is selected" disabled>{Icon.send({ size: 14 })}</button>
              </div>
            </div>
          </Panel>

          <Panel title="Agent Assistance" actions={<Badge tone={runSelected ? "cyan" : "amber"}>{runSelected ? "Run selected" : "Spec-only"}</Badge>}>
            <div className="wb-pad">
              <div className="agent-now">
                <span className="agent-glyph">{Icon.agents({ size: 16 })}</span>
                <div>
                  <strong>Architect Agent</strong>
                  <p>Planner/Coder/Tester/DevOps available</p>
                </div>
              </div>
              <div className="steps" style={{ marginTop: 12 }}>
                {assistSteps.map((step, idx) => (
                  <div key={step} className={`step${runSelected && idx === 0 ? " done" : ""}`}>
                    <StatusDot tone={runSelected && idx === 0 ? "cyan" : "mut"} />
                    {step}
                  </div>
                ))}
              </div>
            </div>
          </Panel>

          <Panel title="Output / Terminal">
            <div className="terminal-feed">
              {terminalRows.map(([kind, label, delta, time]) => (
                <div key={`${kind}-${label}`} className="terminal-row">
                  <span className="mono kind">{kind}</span>
                  <span>{label}</span>
                  <span className="mono plus">{delta}</span>
                  <span className="mono muted-copy">{time}</span>
                </div>
              ))}
            </div>
          </Panel>

          <Panel title="Mini Cortex">
            <div className="mini-cortex-panel">
              <CortexCanvas runState={runSelected ? "planning" : "idle"} nodeCount={360} interactive={false} showRegions={false} sourceLabel={runSelected ? "RUN · SELECTED" : "SPEC · ORGANISM"} />
              <div>
                <Badge tone={runSelected ? "cyan" : "amber"}>{runSelected ? "Run binding" : "Spec-only"}</Badge>
                <p>Aktive Region: Prefrontal Cortex / Workbench. Evidence und Diagnostics sind getrennt verdrahtet.</p>
              </div>
            </div>
          </Panel>

          {showBudget ? (
            <Panel title="Metered Budget">
              <div className="wb-pad">
                <Note>Budget wird nur angezeigt, weil eine paid/metered Capability aktiv oder auswählbar ist.</Note>
                <div className="list" style={{ marginTop: 10 }}>
                  <div className="lrow" style={{ padding: "7px 0" }}>
                    selected capability <span className="meta">metered</span>
                  </div>
                  <div className="lrow" style={{ padding: "7px 0" }}>
                    live provider calls <span className="meta">gated</span>
                  </div>
                </div>
              </div>
            </Panel>
          ) : null}
        </section>

        <section className="wb-layer-board" aria-label="22 pages and 7 layer wiring">
          <div className="wb-board-head">
            <span className="panel-title">22 Seiten · 7 Layer Verdrahtung</span>
            <Badge tone={workspacePages.length === 22 ? "green" : "amber"}>{workspacePages.length}/22</Badge>
          </div>
          <div className="workspace-mini-grid">
            {workspacePages.map((page) => {
              const layer = LAYERS.find((l) => l.code === page.layer);
              return (
                <Link key={page.id} href={page.route} className="workspace-tile">
                  <span className="workspace-no">{page.no}.</span>
                  <span>{page.label}</span>
                  <small style={{ color: layer?.color }}>{layer ? `L${layer.no} ${layer.code}` : page.layer}</small>
                </Link>
              );
            })}
          </div>
        </section>
      </div>
    </AppShell>
  );
}
