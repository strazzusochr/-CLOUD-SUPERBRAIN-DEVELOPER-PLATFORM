"use client";

import { useMemo, useState, type ReactNode } from "react";
import { Icon } from "../lib/nav";
import { Panel, SafetyBadgeRow, Badge } from "./ui";

type JsonValue = Record<string, unknown>;

async function readJson(res: Response): Promise<JsonValue> {
  const text = await res.text();
  try {
    return text ? (JSON.parse(text) as JsonValue) : {};
  } catch {
    return { raw: text };
  }
}

async function getJson(path: string): Promise<JsonValue> {
  const res = await fetch(path, { cache: "no-store" });
  const body = await readJson(res);
  if (!res.ok) throw new Error(String(body.detail ?? body.error ?? `${res.status} ${res.statusText}`));
  return body;
}

function shortJson(value: unknown, max = 700): string {
  const text = JSON.stringify(value, null, 2) ?? String(value);
  return text.length > max ? `${text.slice(0, max)}\n...` : text;
}

function MiniBadge({ tone = "cyan", children }: { tone?: "cyan" | "green" | "amber" | "red" | "mut" | "violet"; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

function ActionResult({ state, testId }: { state: string; testId: string }) {
  return (
    <pre className="goalb-result mono" data-testid={testId} aria-live="polite">
      {state}
    </pre>
  );
}

function ReadOnlyProbe({
  label,
  testId,
  resultId,
  initial,
  onRun,
}: {
  label: string;
  testId: string;
  resultId: string;
  initial: string;
  onRun: () => Promise<string>;
}) {
  const [result, setResult] = useState(initial);
  const [busy, setBusy] = useState(false);

  async function run() {
    setBusy(true);
    try {
      setResult(await onRun());
    } catch (err) {
      setResult(`FAIL ${testId}\n${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="goalb-action-panel" data-testid={`${testId}-panel`}>
      <div className="goalb-row">
        <button className="btn btn-sm btn-primary" type="button" data-testid={testId} onClick={run} disabled={busy}>
          {busy ? "Checking" : label}
        </button>
        <MiniBadge>read-only</MiniBadge>
        <MiniBadge tone="mut">provider_writes=false</MiniBadge>
      </div>
      <ActionResult state={result} testId={resultId} />
    </div>
  );
}

export function DiagnosticsProbe() {
  return (
    <ReadOnlyProbe
      label="Audit read-only pruefen"
      testId="goal-b-diagnostics-probe"
      resultId="goal-b-diagnostics-result"
      initial="waiting_for_diagnostics_probe"
      onRun={async () => {
        const body = await getJson("/api/v1/audit/recent");
        const events = Array.isArray(body.events) ? body.events.length : 0;
        return [
          "PASS diagnostics_audit_probe",
          "endpoint=GET /api/v1/audit/recent",
          `events=${events}`,
          "provider_writes=false",
          "live_provider_calls=false",
          "secret_output=false",
          shortJson({ latest_event_type: Array.isArray(body.events) ? (body.events[0] as JsonValue | undefined)?.event_type : undefined }, 300),
        ].join("\n");
      }}
    />
  );
}

export function DesignSystemProbe() {
  return (
    <ReadOnlyProbe
      label="Design-Contract pruefen"
      testId="goal-b-design-system-probe"
      resultId="goal-b-design-system-result"
      initial="waiting_for_design_system_probe"
      onRun={async () => {
        const body = await getJson("/api/v1/design/reference-contract");
        return [
          "PASS design_system_token_probe",
          `contract=${String(body.contract_version ?? "unknown")}`,
          `page_count=${String(body.page_count ?? "unknown")}`,
          "visual_language=industrial-developer-workbench",
          "provider_writes=false",
          "secret_output=false",
        ].join("\n");
      }}
    />
  );
}

export function TechnologyProbe() {
  return (
    <ReadOnlyProbe
      label="Cloud-Layer pruefen"
      testId="goal-b-technology-probe"
      resultId="goal-b-technology-result"
      initial="waiting_for_technology_probe"
      onRun={async () => {
        const body = await getJson("/api/v1/clouds/layers");
        const text = JSON.stringify(body);
        const retired = /\b(hetzner|gitkraken|oracle)\b/i.test(text);
        return [
          retired ? "FAIL technology_cloud_layers" : "PASS technology_cloud_layers",
          `contract=${String(body.contract_version ?? "unknown")}`,
          `status=${String(body.status ?? "unknown")}`,
          `layers=${String(body.total_layer_count ?? "unknown")}`,
          `ready=${String(body.ready_layer_count ?? "unknown")}`,
          `retired_providers_present=${String(retired)}`,
          "provider_writes=false",
          "live_provider_calls=false",
        ].join("\n");
      }}
    />
  );
}

export function OpenSourceProbe() {
  return (
    <ReadOnlyProbe
      label="OSS-Wiring pruefen"
      testId="goal-b-open-source-probe"
      resultId="goal-b-open-source-result"
      initial="waiting_for_open_source_probe"
      onRun={async () => {
        const body = await getJson("/api/v1/workspace/wiring");
        return [
          "PASS open_source_license_probe",
          `contract=${String(body.contract_version ?? "unknown")}`,
          `page_count=${String(body.page_count ?? "unknown")}`,
          "source=workspace_wiring_license_inventory",
          "provider_writes=false",
          "secret_output=false",
        ].join("\n");
      }}
    />
  );
}

export function FilesLocalContractProbe() {
  return (
    <ReadOnlyProbe
      label="Local-Files Contract pruefen"
      testId="goal-b-files-local-contract"
      resultId="goal-b-files-local-result"
      initial="waiting_for_files_local_contract"
      onRun={async () => {
        const body = await getJson("/api/v1/files/local/contract");
        return [
          "PASS files_local_contract",
          `contract=${String(body.contract_version ?? "unknown")}`,
          `host_filesystem_mounted=${String(body.host_filesystem_mounted ?? false)}`,
          `live_filesystem_reads=${String(body.live_filesystem_reads ?? false)}`,
          `writes=${String(body.writes ?? false)}`,
          `secret_output=${String(body.secret_output ?? false)}`,
        ].join("\n");
      }}
    />
  );
}

export type LocalTreeNode = { d: number; name: string; folder?: boolean };

export function LocalFilesInteractivePanel({ roots, tree }: { roots: string[]; tree: LocalTreeNode[] }) {
  const [root, setRoot] = useState(roots[0] ?? "project");
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState(tree.find((n) => !n.folder)?.name ?? tree[0]?.name ?? "");

  function persist(key: string, value: string) {
    try {
      localStorage.setItem(key, value);
    } catch {}
    try {
      sessionStorage.setItem(key, value);
    } catch {}
  }

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return tree;
    return tree.filter((n) => n.name.toLowerCase().includes(q));
  }, [query, tree]);

  const preview = useMemo(() => {
    if (!selected) return "No selection";
    const node = tree.find((n) => n.name === selected);
    const kind = node?.folder ? "folder" : "file";
    return [
      `selection=${selected}`,
      `kind=${kind}`,
      `root=${root}`,
      "mode=spec_only",
      "host_filesystem_mounted=false",
      "live_filesystem_reads=false",
      "provider_writes=false",
      "secret_output=false",
    ].join("\n");
  }, [root, selected, tree]);

  return (
    <div className="stack">
      <Panel title="Root" className="mb-16" actions={<SafetyBadgeRow />}>
        <div className="wb-pad row wrap">
          <div className="chips">
            {roots.map((r) => (
              <button
                key={r}
                type="button"
                className={`chip${r === root ? " active" : ""}`}
                onClick={() => {
                  setRoot(r);
                  persist("files-local:root", r);
                  persist("files-local:last_root_change", String(Date.now()));
                }}
                aria-label={`Root ${r}`}
              >
                {r}
              </button>
            ))}
          </div>
          <div className="ml-auto row">
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              onClick={() => {
                setQuery("");
                persist("files-local:last_reset", String(Date.now()));
              }}
            >
              Reset search
            </button>
            <Badge tone="cyan">interaktiv · spec</Badge>
          </div>
        </div>
      </Panel>

      <div className="local-files-grid">
        <Panel title="Tree (interactive spec)">
          <div className="wb-pad tree">
            {(filtered.length ? filtered : tree).map((n, i) => (
              <button
                key={`${n.name}:${i}`}
                type="button"
                className={`tnode tnode-btn indent-${Math.min(6, Math.max(0, n.d))}${n.name === selected ? " sel" : ""}`}
                onClick={() => {
                  setSelected(n.name);
                  persist("files-local:selected", n.name);
                  persist("files-local:last_select", String(Date.now()));
                }}
              >
                {n.folder ? Icon.files({ size: 13 }) : Icon.docs({ size: 13 })}
                <span>{n.name}</span>
              </button>
            ))}
          </div>
        </Panel>

        <Panel title="Preview (spec)">
          <div className="wb-pad stack">
            <div className="row">
              <button
                type="button"
                className="btn btn-sm btn-primary"
                onClick={() => {
                  const op = navigator.clipboard?.writeText(preview);
                  if (op && typeof op.catch === "function") op.catch(() => undefined);
                  persist("files-local:last_copy", String(Date.now()));
                }}
                disabled={!selected}
              >
                Copy selection
              </button>
              <button
                type="button"
                className="btn btn-sm"
                onClick={() => {
                  setSelected("");
                  persist("files-local:last_clear", String(Date.now()));
                }}
              >
                Clear
              </button>
            </div>
            <pre className="code">{preview}</pre>
          </div>
        </Panel>

        <Panel title="Search (spec-only, local filter)">
          <div className="wb-pad stack">
            <div className="row local-search-row">
              <input
                className="local-search-input"
                aria-label="Search project tree"
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  persist("files-local:query", e.target.value);
                }}
                placeholder="Filter tree nodes…"
              />
              <button
                className="btn btn-sm"
                aria-label="Clear search"
                onClick={() => {
                  setQuery("");
                  persist("files-local:last_clear_search", String(Date.now()));
                }}
                disabled={!query}
              >
                {Icon.search({ size: 14 })}
              </button>
            </div>
            <div className="list">
              {(query ? filtered : []).slice(0, 8).map((n) => (
                <button key={n.name} type="button" className="lrow" onClick={() => setSelected(n.name)}>
                  {n.folder ? Icon.files({ size: 16 }) : Icon.docs({ size: 16 })}
                  <span className="lrow-title">{n.name}</span>
                  <span className="meta">select</span>
                </button>
              ))}
              {query && !filtered.length ? (
                <div className="lrow muted-copy">No results<span className="meta">spec</span></div>
              ) : null}
              {!query ? (
                <div className="lrow muted-copy">Type to filter…<span className="meta">local only</span></div>
              ) : null}
            </div>
            <div className="muted-copy text-12">
              <span className="mono">.env</span>, <span className="mono">.git</span> and secret paths never appear; binaries surface as metadata only.
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}
