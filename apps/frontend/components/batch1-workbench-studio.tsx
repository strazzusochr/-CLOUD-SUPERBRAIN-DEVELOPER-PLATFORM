"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import CortexCanvas from "./organism/CortexCanvas";
import { Icon, WORKSPACE_PAGES } from "../lib/nav";
import { LAYERS, type RunState } from "./organism/regionMap";
import { Badge, Panel, StatusDot } from "./ui";

const PROJECT_ID = "goal-d2-batch1";

type JsonMap = Record<string, unknown>;
type TerminalRow = { kind: string; label: string; delta: string; time: string };

const FILES: Record<string, string[]> = {
  "artifact.pipeline.ts": [
    "export async function buildArtifact(request: WorkbenchRun) {",
    "  const plan = await orchestrator.route(request.prompt)",
    "  const bundle = await agentPool.execute(plan, request.mode)",
    "  await evidence.write({ runId: bundle.runId, gated: true })",
    "  return previewSurface.render(bundle)",
    "}",
  ],
  "preview.adapter.ts": [
    "export function previewFor(mode: PreviewMode) {",
    "  return tabs.find((tab) => tab.mode === mode && tab.enabled)",
    "}",
  ],
  "agent-run.ts": [
    "export const agentRun = ['planner', 'coder', 'tester', 'devops']",
    "export const liveProviderCalls = false",
  ],
  "verifier.ts": [
    "export const gates = ['dry-run', 'read-only', 'no-secret-output']",
    "export const requiredEvidence = ['screenshot', 'har', 'trace']",
  ],
};

const PREVIEWS = [
  { id: "game", label: "Game View", text: "Third-person prototype preview, dry-run artifact bound." },
  { id: "app", label: "App Preview", text: "Application shell preview with route/state projection." },
  { id: "video", label: "Video Preview", text: "Storyboard timeline preview; generation remains gated." },
  { id: "doc", label: "Doc Preview", text: "Markdown/document output preview, export plan-only." },
  { id: "model", label: "3D Model", text: "GLB/model slot; asset import remains read-only." },
  { id: "assets", label: "Assets", text: "Current artifact assets and generated plan metadata." },
];

const initialTerminal: TerminalRow[] = [
  { kind: "SPEC", label: "workbench studio loaded", delta: "+0", time: "00:00:01" },
  { kind: "LOCK", label: "danger gates closed", delta: "+0", time: "00:00:02" },
  { kind: "LIVE", label: "local llm path armed", delta: "+0", time: "00:00:03" },
];

async function readJson(response: Response): Promise<JsonMap> {
  const text = await response.text();
  try {
    return text ? (JSON.parse(text) as JsonMap) : {};
  } catch {
    return { raw: text };
  }
}

async function postJson(path: string, payload: JsonMap): Promise<JsonMap> {
  const response = await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  const body = await readJson(response);
  if (!response.ok) throw new Error(String(body.detail ?? body.error ?? `${response.status} ${response.statusText}`));
  return body;
}

function line(kind: string, label: string): TerminalRow {
  return { kind, label, delta: "+1", time: new Date().toLocaleTimeString("de-DE", { hour12: false }) };
}

export default function Batch1WorkbenchStudio({ showBudget }: { showBudget: boolean }) {
  const [activeFile, setActiveFile] = useState("artifact.pipeline.ts");
  const [preview, setPreview] = useState(PREVIEWS[0].id);
  const [prompt, setPrompt] = useState("Design a local-only prototype and explain the next implementation step.");
  const [terminal, setTerminal] = useState<TerminalRow[]>(initialTerminal);
  const [runState, setRunState] = useState<RunState>("idle");
  const [fileStatus, setFileStatus] = useState("waiting_for_file_open");
  const [promptStatus, setPromptStatus] = useState("waiting_for_prompt");
  const [previewStatus, setPreviewStatus] = useState("waiting_for_preview_tab");
  const [runResult, setRunResult] = useState("waiting_for_run");
  const [agentResult, setAgentResult] = useState("waiting_for_agent_assist");
  const [busy, setBusy] = useState(false);
  const [steps, setSteps] = useState(["pending", "pending", "pending", "pending"]);
  const selectedPreview = PREVIEWS.find((item) => item.id === preview) ?? PREVIEWS[0];
  const workspacePages = useMemo(() => [...WORKSPACE_PAGES].sort((a, b) => a.no - b.no), []);

  function openFile(file: string) {
    setActiveFile(file);
    setFileStatus(`PASS file_opened\nfile=${file}\neditor=visible`);
    setTerminal((rows) => [line("OPEN", `file opened -> editor: ${file}`), ...rows].slice(0, 7));
  }

  function switchPreview(id: string) {
    setPreview(id);
    const tab = PREVIEWS.find((item) => item.id === id);
    setPreviewStatus(`PASS preview_tab\nmode=${id}\nlabel=${tab?.label ?? id}`);
    setTerminal((rows) => [line("VIEW", `preview tab switched: ${id}`), ...rows].slice(0, 7));
  }

  async function runWorkbench() {
    setBusy(true);
    setRunState("executing");
    setSteps(["done", "active", "pending", "pending"]);
    setTerminal((rows) => [line("RUN", "local llm request started"), ...rows].slice(0, 7));
    try {
      const runtime = await postJson("/llm/v1/chat/completions", {
        model: "gemma-3-1b-it",
        stream: false,
        temperature: 0.2,
        max_tokens: 220,
        metadata: {
          source_page: "workbench",
          trace_id: `batch1-workbench-${Date.now()}`,
          agent_type: "planner",
          live_provider_calls_allowed: false,
        },
        messages: [
          { role: "system", content: "You are a local developer assistant inside Cloud Superbrain. Answer briefly and concretely." },
          { role: "user", content: prompt },
        ],
      });
      const choices = Array.isArray(runtime.choices) ? (runtime.choices as JsonMap[]) : [];
      const message = choices[0]?.message as JsonMap | undefined;
      const content = String(message?.content ?? "").trim();
      if (!content) throw new Error("local llm returned no visible text");
      const artifact = await postJson("/api/v1/workspace/artifacts", {
        project_id: PROJECT_ID,
        source_page: "workbench",
        artifact_type: "batch1_workbench_real_llm",
        title: "Batch 1 workbench local llm run",
        summary: `model=${String(runtime.model ?? "unknown")} output=${content.slice(0, 180)}`,
        status: "ready",
        metadata: {
          goal: "goal-d2-batch1",
          live_provider_calls: runtime.live_provider_calls,
          local_model_calls: runtime.local_model_calls,
          audit_persisted: runtime.audit_persisted,
          completion_tokens: (runtime.usage as JsonMap | undefined)?.completion_tokens ?? 0,
          total_tokens: (runtime.usage as JsonMap | undefined)?.total_tokens ?? 0,
          preview_text: content.slice(0, 500),
        },
      });
      setRunState("verifying");
      setSteps(["done", "done", "done", "active"]);
      setRunResult([
        "PASS batch1_workbench_run",
        `status=${String(runtime.status ?? "unknown")}`,
        `model=${String(runtime.model ?? "unknown")}`,
        `artifact=${String((artifact.artifact as JsonMap | undefined)?.id ?? "created")}`,
        `live_provider_calls=${String(runtime.live_provider_calls ?? false)}`,
        `local_model_calls=${String(runtime.local_model_calls ?? false)}`,
        `tokens=${String((runtime.usage as JsonMap | undefined)?.total_tokens ?? 0)}`,
        `text=${content}`,
      ].join("\n"));
      setTerminal((rows) => [
        line("PASS", "local llm answer rendered"),
        line("DOC", "artifact stored locally"),
        ...rows,
      ].slice(0, 7));
    } catch (error) {
      setRunState("blocked");
      setSteps(["done", "done", "pending", "pending"]);
      setRunResult(`FAIL batch1_workbench_run\n${error instanceof Error ? error.message : String(error)}`);
      setTerminal((rows) => [line("FAIL", "local llm path failed"), ...rows].slice(0, 7));
    } finally {
      setBusy(false);
    }
  }

  async function askAgent() {
    setBusy(true);
    setAgentResult("running_agent_assistance");
    try {
      const body = await postJson("/api/v1/live-agents/steer", {
        agent_id: "planner",
        project_id: PROJECT_ID,
        message: "Batch 1 workbench planner assistance, dry-run only.",
        metadata: { source_page: "workbench", goal: "goal-d2-batch1" },
      });
      setAgentResult([
        "PASS batch1_agent_assistance",
        `agent=${String(body.agent_id ?? "planner")}`,
        `status=${String(body.status ?? "unknown")}`,
        `trace=${String(body.trace_id ?? "none")}`,
        `live_provider_calls=${String(body.live_provider_calls ?? false)}`,
      ].join("\n"));
      setSteps(["done", "done", "active", "pending"]);
      setTerminal((rows) => [line("AGENT", "planner dry-run response visible"), ...rows].slice(0, 7));
    } catch (error) {
      setAgentResult(`FAIL batch1_agent_assistance\n${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page-wide workbench-blueprint batch1-workbench" data-testid="batch1-workbench">
      <h1 className="sr-only">Main Workbench / Central Workspace</h1>

      <section className="industrial-toolbar" aria-label="Workbench toolbar">
        <div className="tool-select">{Icon.workbench({ size: 16 })}<span>Superbrain Developer Engine</span></div>
        <div className="tool-select mono">{Icon.open({ size: 15 })}<span>main</span></div>
        <div className="tool-actions" aria-label="Gated toolbar actions">
          <button type="button" className="icon-btn" title="Cloud write requires owner gate" disabled>{Icon.tools({ size: 15 })}</button>
          <button type="button" className="icon-btn" title="Registry push requires owner gate" disabled>{Icon.apps({ size: 15 })}</button>
          <button type="button" className="icon-btn" title="Production deploy requires owner gate" disabled>{Icon.bolt({ size: 15 })}</button>
        </div>
        <span className="tool-gate-note">local-only runtime · danger gates disabled</span>
        <span className="tool-gate-note">Cloud Staging · blocked external gates</span>
        <span className="tool-gate-note">RUN BINDING · Run Binding · Local llama.cpp live path</span>
        <div className="tool-env">
          <StatusDot tone={runState === "blocked" ? "red" : runState === "idle" ? "amber" : "cyan"} pulse={runState !== "idle"} />
          <span>Dev Runtime</span>
          <small>{runState}</small>
        </div>
        <Link href="/organism" className="btn btn-sm btn-ghost">{Icon.organism({ size: 14 })} Cortex</Link>
      </section>

      <section className="wb-studio">
        <aside className="wb-pane wb-explorer">
          <div className="wb-pane-head"><span>Explorer</span><span className="mono muted-copy">read-only</span></div>
          <div className="wb-tree" data-testid="batch1-file-tree">
            <div className="tree-root">{Icon.files({ size: 14 })} cloud-superbrain-platform</div>
            <div className="tree-group">
              <div className="tree-folder">src</div>
              {Object.keys(FILES).map((file, index) => (
                <button
                  key={file}
                  type="button"
                  className={`tree-file wb-file-button tree-file-indent${activeFile === file ? " selected" : ""}`}
                  onClick={() => openFile(file)}
                  data-testid={`batch1-open-file-${index}`}
                >
                  {Icon.docs({ size: 13 })}{file}
                </button>
              ))}
            </div>
            <div className="tree-group">
              <div className="tree-folder">assets</div>
              {["character.glb", "environment.exr", "ui_hud.png"].map((asset) => (
                <span key={asset} className="tree-file tree-file-indent">{Icon.files({ size: 13 })}{asset}</span>
              ))}
            </div>
          </div>
        </aside>

        <main className="wb-pane wb-editor">
          <div className="wb-pane-head">
            <span data-testid="batch1-editor-title">{Icon.docs({ size: 15 })} {activeFile}</span>
            <span className="mono muted-copy">opened to editor</span>
          </div>
          <pre className="industrial-code" aria-label="Code editor preview" data-testid="batch1-editor-content">
            {(FILES[activeFile] ?? []).map((entry, index) => <span key={`${activeFile}-${index}`}>{entry}{"\n"}</span>)}
          </pre>
          <pre className="goalb-result mono batch1-file-status" data-testid="batch1-file-open-result">{fileStatus}</pre>
        </main>

        <aside className="wb-pane wb-preview">
          <div className="wb-pane-head"><span>Preview / Assets</span><Badge tone="cyan">{selectedPreview.label}</Badge></div>
          <div className="preview-tabs" role="tablist" aria-label="Preview modes" data-testid="batch1-preview-tabs">
            {PREVIEWS.map((tab) => (
              preview === tab.id ? (
                <button
                  key={tab.id}
                  type="button"
                  role="tab"
                  aria-selected="true"
                  className="preview-tab active"
                  onClick={() => switchPreview(tab.id)}
                >
                  {tab.label}
                </button>
              ) : (
                <button
                  key={tab.id}
                  type="button"
                  role="tab"
                  aria-selected="false"
                  className="preview-tab"
                  onClick={() => switchPreview(tab.id)}
                >
                  {tab.label}
                </button>
              )
            ))}
          </div>
          <div className="game-preview batch1-preview" aria-label="Industrial template preview" data-testid="batch1-preview-result">
            <div className="preview-sky" />
            <div className="preview-hud"><span className="mono">{preview.toUpperCase()}</span><i /><i /></div>
            <div className="preview-world">
              <span className="terrain" />
              <span className="avatar-stand" />
              <span className="objective">{selectedPreview.text}</span>
            </div>
          </div>
          <pre className="goalb-result mono batch1-preview-status" data-testid="batch1-preview-status">{previewStatus}</pre>
          <div className="asset-strip">{["character.glb", "weapon.fbx", "scene.exr", "ui_hud.png", "+12"].map((asset) => <span key={asset}>{asset}</span>)}</div>
        </aside>
      </section>

      <section className={`wb-bottom-grid${showBudget ? " with-budget" : ""}`}>
        <Panel title="Prompt Composer">
          <div className="wb-pad stack stack-gap-10">
            <div className="goalb-row">
              <input
                aria-label="Batch 1 workbench prompt"
                value={prompt}
                onChange={(event) => {
                  setPrompt(event.target.value);
                  setPromptStatus(`PASS prompt_updated\nchars=${event.target.value.length}\nready_for_run=true`);
                }}
                data-testid="batch1-workbench-prompt"
              />
              <button className="btn btn-sm btn-primary" type="button" onClick={runWorkbench} disabled={busy} data-testid="batch1-workbench-run">
                {busy ? "Running" : "Run"}
              </button>
            </div>
            <pre className="goalb-result mono" data-testid="batch1-prompt-status">{promptStatus}</pre>
            <pre className="goalb-result mono" data-testid="batch1-workbench-result">{runResult}</pre>
          </div>
        </Panel>

        <Panel title="Agent Assistance" actions={<Badge tone="cyan">dry-run</Badge>}>
          <div className="wb-pad">
            <div className="agent-now"><span className="agent-glyph">{Icon.agents({ size: 16 })}</span><div><strong>Architect Agent</strong><p>Planner/Coder/Tester/DevOps sequence</p></div></div>
            <div className="steps with-top-gap" data-testid="batch1-agent-steps">
              {["Analyze requirements", "Plan architecture", "Generate artifact", "Collect evidence"].map((step, idx) => (
                <div key={step} className={`step${steps[idx] === "done" ? " done" : steps[idx] === "active" ? " active" : ""}`}><StatusDot tone={steps[idx] === "pending" ? "mut" : "cyan"} />{step}</div>
              ))}
            </div>
            <button className="btn btn-sm btn-primary" type="button" onClick={askAgent} disabled={busy} data-testid="batch1-agent-assist">Ask planner</button>
            <pre className="goalb-result mono" data-testid="batch1-agent-result">{agentResult}</pre>
          </div>
        </Panel>

        <Panel title="Output / Terminal">
          <div className="terminal-feed" data-testid="batch1-terminal">
            {terminal.map((row, index) => (
              <div key={`${row.kind}-${row.label}-${index}`} className="terminal-row">
                <span className="mono kind">{row.kind}</span><span>{row.label}</span><span className="mono plus">{row.delta}</span><span className="mono muted-copy">{row.time}</span>
              </div>
            ))}
          </div>
        </Panel>

        <Panel title="Mini Cortex">
          <div className="mini-cortex-panel" data-testid="batch1-mini-cortex">
            <CortexCanvas runState={runState} nodeCount={360} interactive={false} showRegions={false} sourceLabel={`BATCH1 · ${runState.toUpperCase()}`} />
            <div><Badge tone={runState === "idle" ? "amber" : "cyan"}>{runState}</Badge><p>Active region: Prefrontal Cortex / Workbench. DEV-ONLY local evidence.</p></div>
          </div>
        </Panel>

        {showBudget ? (
          <Panel title="Metered Budget" actions={<Badge tone="amber">paid/metered Capability</Badge>}>
            <div className="wb-pad stack stack-gap-8">
              <p className="muted-copy budget-note">
                Budget controls are visible because a paid or metered LLM/tool option is selected.
              </p>
              <pre className="goalb-result mono">
                budget_visible=true{"\n"}
                reason=paid/metered Capability{"\n"}
                live_provider_calls=false{"\n"}
                owner_gate_required_for_live_spend=true
              </pre>
            </div>
          </Panel>
        ) : null}
      </section>

      <section className="wb-layer-board" aria-label="22 pages and 7 layer wiring">
        <div className="wb-board-head"><span className="panel-title">22 Seiten · 7 Layer Verdrahtung</span><Badge tone={workspacePages.length === 22 ? "green" : "amber"}>{workspacePages.length}/22</Badge></div>
        <div className="workspace-mini-grid">
          {workspacePages.map((page) => {
            const layer = LAYERS.find((item) => item.code === page.layer);
            const layerClass = layer ? `workspace-layer-label layer-${layer.code.toLowerCase()}` : "workspace-layer-label";
            return <Link key={page.id} href={page.route} className="workspace-tile"><span className="workspace-no">{page.no}.</span><span>{page.label}</span><small className={layerClass}>{layer ? `L${layer.no} ${layer.code}` : page.layer}</small></Link>;
          })}
        </div>
      </section>
    </div>
  );
}
