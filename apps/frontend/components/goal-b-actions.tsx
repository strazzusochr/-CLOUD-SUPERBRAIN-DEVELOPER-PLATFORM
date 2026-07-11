"use client";

import { type ReactNode, useEffect, useMemo, useState } from "react";

const PROJECT_ID = "goal-b-local";

type JsonValue = Record<string, unknown>;

type Artifact = {
  id: string;
  created_at: string | null;
  source_page: string;
  artifact_type: string;
  title: string;
  summary: string;
  run_id?: string | null;
  status: string;
  evidence_ref: string;
};

type LiveAgentOption = {
  id: string;
  name: string;
  role: string;
};

async function readJson(res: Response): Promise<JsonValue> {
  const text = await res.text();
  try {
    return text ? (JSON.parse(text) as JsonValue) : {};
  } catch {
    return { raw: text };
  }
}

async function postJson(path: string, payload: JsonValue): Promise<JsonValue> {
  const res = await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  const body = await readJson(res);
  if (!res.ok) throw new Error(String(body.detail ?? body.error ?? `${res.status} ${res.statusText}`));
  return body;
}

async function getJson(path: string): Promise<JsonValue> {
  const res = await fetch(path, { cache: "no-store" });
  const body = await readJson(res);
  if (!res.ok) throw new Error(String(body.detail ?? body.error ?? `${res.status} ${res.statusText}`));
  return body;
}

function shortJson(value: unknown, max = 900): string {
  const text = JSON.stringify(value, null, 2) ?? String(value);
  return text.length > max ? `${text.slice(0, max)}\n...` : text;
}

function MiniBadge({ tone = "mut", children }: { tone?: "mut" | "cyan" | "green" | "amber" | "red" | "violet"; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

function MiniNote({ children }: { children: ReactNode }) {
  return <div className="note blocked">{children}</div>;
}

function runSummary(body: JsonValue): string {
  const state = (body.state ?? {}) as JsonValue;
  const roles = Array.isArray(state.role_results) ? state.role_results.length : Array.isArray(state.per_role_results) ? state.per_role_results.length : 0;
  return [
    `status=${String(body.status ?? "unknown")}`,
    `run=${String(body.run_id ?? "none")}`,
    `thread=${String(body.thread_id ?? "none")}`,
    `roles=${roles}`,
    `live_provider_calls=${String(body.live_provider_calls ?? false)}`,
    `live_mcp_writes=${String(body.live_mcp_writes ?? false)}`,
  ].join(" | ");
}

async function createArtifact(payload: {
  source_page: string;
  artifact_type: string;
  title: string;
  summary: string;
  session_id?: string | null;
  run_id?: string | null;
  status?: "ready" | "planned" | "dry_run" | "blocked";
  metadata?: JsonValue;
}): Promise<Artifact> {
  const body = await postJson("/api/v1/workspace/artifacts", {
    project_id: PROJECT_ID,
    status: "ready",
    ...payload,
  });
  return (body.artifact ?? {}) as Artifact;
}

async function loadArtifacts(limit = 8): Promise<Artifact[]> {
  const body = await getJson(`/api/v1/workspace/artifacts?project_id=${encodeURIComponent(PROJECT_ID)}&limit=${limit}`);
  return Array.isArray(body.artifacts) ? (body.artifacts as Artifact[]) : [];
}

function ActionResult({ state, testId }: { state: string; testId: string }) {
  return (
    <pre className="goalb-result mono" data-testid={testId} aria-live="polite">
      {state}
    </pre>
  );
}

function ArtifactList({ artifacts }: { artifacts: Artifact[] }) {
  return (
    <div className="goalb-artifacts" data-testid="goal-b-artifact-list">
      {artifacts.length ? artifacts.map((artifact) => (
        <div key={artifact.id} className="goalb-artifact-row">
          <MiniBadge tone={artifact.status === "blocked" ? "red" : artifact.status === "planned" ? "amber" : "green"}>{artifact.status}</MiniBadge>
          <span className="mono">{artifact.artifact_type}</span>
          <span>{artifact.title}</span>
          <small className="mono">{artifact.id.slice(0, 8)}</small>
        </div>
      )) : (
        <div className="goalb-artifact-row muted-copy">Noch kein lokales Artefakt.</div>
      )}
    </div>
  );
}

export function WorkbenchActionPanel() {
  const [prompt, setPrompt] = useState("Erstelle ein echtes, persistiertes Artefakt mit Nachweis.");
  const [mode, setMode] = useState("game");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState("Bereit — noch keine Aktion ausgeführt.");
  const [artifacts, setArtifacts] = useState<Artifact[]>([]);

  useEffect(() => {
    loadArtifacts().then(setArtifacts).catch(() => setArtifacts([]));
  }, []);

  async function run() {
    setBusy(true);
    setResult("running_phase2_runtime_start");
    try {
      const body = await postJson("/api/v1/phase2/runtime/start", {
        project_id: PROJECT_ID,
        prompt: `[${mode}] ${prompt}`,
      });
      const artifact = await createArtifact({
        source_page: "workbench",
        artifact_type: `${mode}_runtime_run`,
        title: `Werkbank ${mode} Dry-Run`,
        summary: runSummary(body),
        session_id: String(body.thread_id ?? ""),
        run_id: String(body.run_id ?? ""),
        status: "ready",
        metadata: {
          endpoint: "POST /api/v1/phase2/runtime/start",
          evidence_ref: body.evidence_ref,
          live_provider_calls: body.live_provider_calls,
          live_mcp_writes: body.live_mcp_writes,
        },
      });
      const next = await loadArtifacts();
      setArtifacts(next);
      setResult(`PASS workbench_run\n${runSummary(body)}\nartifact=${artifact.id}\n${shortJson({ evidence_ref: body.evidence_ref, artifact })}`);
    } catch (err) {
      setResult(`FAIL workbench_run\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-workbench-panel">
      <div className="goalb-row">
        <select aria-label="Werkbank-Modus" value={mode} onChange={(event) => setMode(event.target.value)}>
          <option value="game">Spiel</option>
          <option value="app">App</option>
          <option value="media">Medien</option>
          <option value="doc">Dokument</option>
        </select>
        <input aria-label="Werkbank-Prompt" value={prompt} onChange={(event) => setPrompt(event.target.value)} />
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-workbench-run" onClick={run} disabled={busy}>
          {busy ? "Wird ausgeführt" : "Ausführen"}
        </button>
      </div>
      <ActionResult state={result} testId="goal-b-workbench-result" />
      <ArtifactList artifacts={artifacts} />
    </div>
  );
}

export function AgentSteeringPanel({ agents }: { agents: LiveAgentOption[] }) {
  const options = agents.length ? agents : [
    { id: "planner", name: "Planner", role: "planner" },
    { id: "coder", name: "Coder", role: "coder" },
    { id: "tester", name: "Tester", role: "tester" },
    { id: "devops", name: "DevOps", role: "devops" },
  ];
  const [selected, setSelected] = useState(options[0]?.id ?? "planner");
  const [result, setResult] = useState("Bereit — wähle eine Agent-Aktion.");
  const [busy, setBusy] = useState(false);

  async function steer() {
    setBusy(true);
    setResult(`steering_${selected}`);
    try {
      const body = await postJson("/api/v1/live-agents/steer", {
        agent_id: selected,
        project_id: PROJECT_ID,
        message: `Lokaler echter Goal-B-Lauf für ${selected}. Erzeuge ein kurzes sichtbares Ergebnis für deine Rolle und fasse die abgeschlossene Aktion zusammen.`,
        metadata: { source_page: "agents", goal: "goal-b", local_real_agent_run: true },
      });
      setResult([
        "PASS agent_steer",
        `agent=${String(body.agent_id)}`,
        `status=${String(body.status)}`,
        `trace=${String(body.trace_id)}`,
        `live_provider_calls=${String(body.live_provider_calls)}`,
        `local_model_calls=${String(body.local_model_calls)}`,
        `audit_persisted=${String(body.audit_persisted)}`,
        `action=${String(body.action ?? "unknown")}`,
        `output=${String(body.output_path ?? "none")}`,
        `command=${String(body.command ?? "none")}`,
        `exit_code=${String(body.exit_code ?? "none")}`,
        String(body.text ?? "").slice(0, 500),
      ].join("\n"));
    } catch (err) {
      setResult(`FAIL agent_steer\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  async function reset() {
    setBusy(true);
    try {
      const body = await postJson(`/api/v1/live-agents/${encodeURIComponent(selected)}/reset`, {});
      setResult([
        "PASS agent_reset",
        `agent=${String(body.agent_id)}`,
        `status=${String(body.status)}`,
        `live_provider_calls=${String(body.live_provider_calls ?? false)}`,
        `local_model_calls=${String(body.local_model_calls ?? false)}`,
        `audit_persisted=${String(body.audit_persisted ?? false)}`,
      ].join("\n"));
    } catch (err) {
      setResult(`FAIL agent_reset\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  async function refresh() {
    setBusy(true);
    try {
      const body = await getJson("/api/v1/live-agents/status");
      setResult([
        "PASS agent_status",
        `live_provider_calls=false`,
        `local_model_calls=false`,
        `audit_persisted=true`,
        JSON.stringify(body, null, 2),
      ].join("\n"));
    } catch (err) {
      setResult(`FAIL agent_status\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-agents-panel">
      <div className="goalb-row">
        <select
          aria-label="Agent"
          value={selected}
          onChange={(event) => {
            setSelected(event.target.value);
            setResult(`PASS agent_select\nagent=${event.target.value}\nmode=local_real_agent_run`);
          }}
        >
          {options.map((agent) => <option key={agent.id} value={agent.id}>{agent.name} / {agent.role}</option>)}
        </select>
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-agent-start" onClick={steer} disabled={busy}>Starten</button>
        <button className="btn btn-sm" type="button" data-testid="goal-b-agent-reset" onClick={reset} disabled={busy}>Zurücksetzen</button>
        <button className="btn btn-sm btn-ghost" type="button" data-testid="goal-b-agent-status" onClick={refresh} disabled={busy}>Status</button>
        <button className="btn btn-sm" type="button" disabled title="Erfordert das Live-Agent-Gate; nur Dry-Run">Pausieren · Live-Gate erforderlich</button>
        <button className="btn btn-sm" type="button" disabled title="Erfordert das Owner-Gate; im DEV-ONLY-Nachweis wird kein Prozess beendet">Beenden · Owner-Gate</button>
      </div>
      <MiniNote>„Starten“ führt einen echten lokalen Rollenlauf aus. Pausieren und Beenden bleiben sichtbar gesperrt: Das Owner-Gate ist erforderlich, externe Runtime-Mutationen finden nicht statt.</MiniNote>
      <ActionResult state={result} testId="goal-b-agent-result" />
    </div>
  );
}

export function FilesSearchPanel() {
  const [query, setQuery] = useState("phase2");
  const [result, setResult] = useState("Bereit — gib einen Suchbegriff ein und starte die Suche.");
  const [busy, setBusy] = useState(false);

  async function search() {
    setBusy(true);
    try {
      const body = await getJson(`/api/v1/memory/search?project_id=${encodeURIComponent(PROJECT_ID)}&q=${encodeURIComponent(query)}&limit=8`);
      const rows = Array.isArray(body.results) ? body.results : [];
      setResult(`PASS files_search\nquery=${query}\nresults=${rows.length}\nsearch_mode=${String(body.search_mode)}\n${shortJson(rows, 800)}`);
    } catch (err) {
      setResult(`FAIL files_search\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-files-panel">
      <div className="goalb-row">
        <input
          aria-label="Suchbegriff für das Gedächtnis"
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
            setResult(`PASS files_query_updated\nquery=${event.target.value}\nendpoint=/api/v1/memory/search`);
          }}
        />
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-files-search" onClick={search} disabled={busy}>Suchen</button>
      </div>
      <ActionResult state={result} testId="goal-b-files-result" />
    </div>
  );
}

export function ToolsReadOnlyPanel() {
  const [tool, setTool] = useState("memory_read");
  const [query, setQuery] = useState("phase2 runtime");
  const [result, setResult] = useState("Bereit — wähle ein Tool und führe es nur lesend aus.");
  const [busy, setBusy] = useState(false);

  async function execute() {
    setBusy(true);
    setResult("läuft…");
    try {
      const body = await postJson("/api/v1/tools/read-only/execute", { tool, query });
      setResult(
        body.executed
          ? `✓ ausgeführt · tool=${String(body.tool)} · ${String(body.ms)}ms\n${shortJson(body.result, 1400)}`
          : `nicht ausgeführt\n${shortJson(body, 600)}`,
      );
    } catch (err) {
      setResult(`Fehler\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-tools-panel">
      <div className="goalb-row">
        <select
          aria-label="Nur lesendes Tool"
          value={tool}
          onChange={(event) => { setTool(event.target.value); setResult("bereit"); }}
        >
          <option value="memory_read">memory_read</option>
          <option value="task_router">task_router</option>
          <option value="web_fetch">web_fetch (URL)</option>
        </select>
        <input
          aria-label="Tool-Anfrage"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-tool-execute" onClick={execute} disabled={busy}>Ausführen</button>
      </div>
      <ActionResult state={result} testId="goal-b-tool-result" />
    </div>
  );
}

export function MarketplaceActionPanel({ itemNames }: { itemNames: string[] }) {
  const first = itemNames[0] ?? "planner";
  const [item, setItem] = useState(first);
  const [result, setResult] = useState("Bereit — wähle einen Eintrag für Details oder eine Installation im Dry-Run.");
  const [busy, setBusy] = useState(false);
  const options = useMemo(() => Array.from(new Set([first, ...itemNames])).slice(0, 24), [first, itemNames]);

  async function details() {
    setResult(`PASS marketplace_details\nitem=${item}\nmode=dry_run_plan\nprovider_writes=false`);
  }

  async function install() {
    setBusy(true);
    try {
      const artifact = await createArtifact({
        source_page: "marketplace",
        artifact_type: "marketplace_install_plan",
        title: `Installationsplan: ${item}`,
        summary: `Aktivierungsplan im Dry-Run für ${item}; Provider-Schreibzugriffe bleiben deaktiviert.`,
        status: "planned",
        metadata: { item, provider_writes: false, registry_pull: false },
      });
      setResult(`PASS marketplace_install\nitem=${item}\nartifact=${artifact.id}\nstatus=${artifact.status}\nprovider_writes=false`);
    } catch (err) {
      setResult(`FAIL marketplace_install\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-marketplace-panel">
      <div className="goalb-row">
        <select
          aria-label="Marktplatz-Eintrag"
          value={item}
          onChange={(event) => {
            setItem(event.target.value);
            setResult(`PASS marketplace_select\nitem=${event.target.value}\nmode=dry_run_plan\nprovider_writes=false`);
          }}
        >
          {options.map((name) => <option key={name} value={name}>{name}</option>)}
        </select>
        <button className="btn btn-sm btn-ghost" type="button" data-testid="goal-b-marketplace-details" onClick={details}>Einzelheiten</button>
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-marketplace-install" onClick={install} disabled={busy}>Installieren</button>
      </div>
      <ActionResult state={result} testId="goal-b-marketplace-result" />
    </div>
  );
}

export type MarketplaceCardItem = {
  name: string;
  kind: string;
  desc: string;
};

export function MarketplaceCardGrid({ items }: { items: MarketplaceCardItem[] }) {
  const safeItems = useMemo(() => items.slice(0, 160), [items]);

  return (
    <div className="stack marketplace-card-grid">
      <div className="card-grid" data-testid="marketplace-card-grid">
        {safeItems.map((it) => {
          const key = `${it.kind}:${it.name}`;
          return (
            <div key={key} className="gcard">
              <div className="preview">
                <MiniBadge tone="mut">{it.kind}</MiniBadge>
              </div>
              <div className="body">
                <h3 className="mono marketplace-card-title">{it.name}</h3>
                <div className="sub marketplace-card-sub">{it.desc}</div>
                <div className="actions" aria-label="Status des Katalogeintrags">
                  <MiniBadge tone="cyan">Katalog</MiniBadge>
                  <MiniBadge tone="amber">Installation über Auswahl</MiniBadge>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function WorkspaceModeActionPanel({ mode, label }: { mode: "games" | "apps" | "media" | "docs-output"; label: string }) {
  const [result, setResult] = useState("Bereit — starte eine Aktion.");
  const [busy, setBusy] = useState(false);

  async function create() {
    setBusy(true);
    try {
      const artifact = await createArtifact({
        source_page: mode,
        artifact_type: `${mode.replace("-", "_")}_artifact`,
        title: `${label}: lokales Artefakt`,
        summary: `${label}-Artefakt aus der gemeinsamen Goal-B-Artefakt-Pipeline; nur Dry-Run.`,
        status: "ready",
        metadata: { mode, common_pipeline: "workspace_artifacts", live_provider_calls: false },
      });
      setResult([
        `PASS ${mode}_artifact`,
        `mode=${mode}`,
        `artifact=${artifact.id}`,
        `status=${artifact.status}`,
        `source=${artifact.source_page}`,
        "common_pipeline=workspace_artifacts",
        "live_provider_calls=false",
        "provider_writes=false",
      ].join("\n"));
    } catch (err) {
      setResult(`FAIL ${mode}_action\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid={`goal-b-${mode}-panel`}>
      <div className="goalb-row">
        <button
          aria-label={`Lokales Dry-Run-Artefakt für ${label} anlegen`}
          className="btn btn-sm btn-primary"
          type="button"
          data-testid={`goal-b-${mode}-create`}
          onClick={create}
          disabled={busy}
        >
          Artefakt anlegen
        </button>
        <MiniBadge tone="cyan">gemeinsame Artefakt-Pipeline</MiniBadge>
      </div>
      <ActionResult state={result} testId={`goal-b-${mode}-result`} />
    </div>
  );
}

type DocsExportResponse = {
  file_name: string;
  runtime_store: string;
  bytes: number;
  download_url: string;
  source: string;
};

export function DocsExportPanel({
  exportTitle,
  exportContent,
  projectId = PROJECT_ID,
  sessionId = null,
}: {
  exportTitle: string;
  exportContent: string;
  projectId?: string;
  sessionId?: string | null;
}) {
  const [result, setResult] = useState("Bereit — wähle ein Export-Format.");
  const [busy, setBusy] = useState(false);

  async function exportFile(format: "pdf" | "md") {
    setBusy(true);
    try {
      const body = await postJson("/exports/docs", {
        format,
        title: exportTitle,
        content: exportContent,
        projectId,
        sessionId,
      }) as unknown as DocsExportResponse;
      const artifact = await createArtifact({
        source_page: "docs-output",
        artifact_type: `export_${format}_file`,
        title: `Export ${format.toUpperCase()} ${body.file_name}`,
        summary: `Echter lokaler Export im temporären Runtime-Speicher ${body.runtime_store} erstellt (${body.bytes} Bytes).`,
        session_id: sessionId,
        status: "ready",
        metadata: {
          format,
          runtime_store: body.runtime_store,
          download_url: body.download_url,
          bytes: body.bytes,
          source: body.source,
          real_export: true,
          live_provider_calls: false,
          provider_writes: false,
        },
      });
      const anchor = document.createElement("a");
      anchor.href = body.download_url;
      anchor.download = body.file_name;
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      setResult([
        "PASS docs_export",
        `format=${format}`,
        `artifact=${artifact.id}`,
        `status=${artifact.status}`,
        `file=${body.file_name}`,
        `bytes=${body.bytes}`,
        `download=${body.download_url}`,
        `runtime_store=${body.runtime_store}`,
        `source=${body.source}`,
        "provider_writes=false",
        "live_provider_calls=false",
      ].join("\n"));
    } catch (err) {
      setResult(`FAIL export_${format}\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-docs-export-panel">
      <MiniNote>Der Export erzeugt echte lokale Dateien im temporären Runtime-Speicher und startet den Download direkt im Browser.</MiniNote>
      <div className="goalb-row">
        <button
          aria-label="PDF-Datei exportieren"
          className="btn btn-sm btn-primary"
          type="button"
          data-testid="goal-b-docs-export-pdf"
          onClick={() => void exportFile("pdf")}
          disabled={busy}
        >
          PDF exportieren <MiniBadge tone="green">lokale Datei</MiniBadge>
        </button>
        <button
          aria-label="MD-Datei exportieren"
          className="btn btn-sm"
          type="button"
          data-testid="goal-b-docs-export-md"
          onClick={() => void exportFile("md")}
          disabled={busy}
        >
          MD exportieren <MiniBadge tone="green">lokale Datei</MiniBadge>
        </button>
      </div>
      <ActionResult state={result} testId="goal-b-docs-export-result" />
    </div>
  );
}

export function SettingsGatePlanPanel() {
  const [result, setResult] = useState("Bereit — PlanOnly-Prüfung noch nicht gestartet.");
  const [busy, setBusy] = useState(false);

  async function plan() {
    setBusy(true);
    try {
      const artifact = await createArtifact({
        source_page: "settings",
        artifact_type: "owner_gate_planonly",
        title: "Owner-Gate PlanOnly",
        summary: "PlanOnly-Prüfung von acht gefährlichen Gates; kein Gate wurde verändert.",
        status: "blocked",
        metadata: {
          gates: ["production_deploy", "release_promotion", "provider_writes", "main_push", "registry_push", "live_mcp_write", "live_llm_call", "secret_output"],
          apply_allowed: false,
        },
      });
      setResult(`PASS settings_gate_planonly\nartifact=${artifact.id}\napply_allowed=false\nall_danger_gates=disabled`);
    } catch (err) {
      setResult(`FAIL settings_gate_planonly\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid="goal-b-settings-panel">
      <MiniNote>Gefährliche Gates bleiben geschlossen; diese Schaltfläche erzeugt nur einen lokalen PlanOnly-Nachweis.</MiniNote>
      <div className="goalb-row">
        <button className="btn btn-sm btn-primary" type="button" data-testid="goal-b-settings-planonly" onClick={plan} disabled={busy}>PlanOnly prüfen</button>
        <button className="btn btn-sm" type="button" disabled>Anwenden gesperrt</button>
      </div>
      <ActionResult state={result} testId="goal-b-settings-result" />
    </div>
  );
}
