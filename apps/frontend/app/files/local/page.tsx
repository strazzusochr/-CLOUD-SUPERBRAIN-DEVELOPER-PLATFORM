import AppShell from "../../../components/shell/AppShell";
import { PageHeader, Panel, SafetyBadgeRow, SpecModeBadge } from "../../../components/ui";
import { FilesLocalContractProbe } from "../../../components/batch5-actions";
import { Icon } from "../../../lib/nav";
import { FILE_ROOTS, PROJECT_TREE } from "../../../lib/platform";

export const metadata = { title: "Local Files (read-only) — Cloud Superbrain" };

export default function LocalFilesPage() {
  return (
    <AppShell crumb="Local Files" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Local Files (spec surface)"
          title="Local files"
          subtitle="This is a safe, read-only intent surface. In this runtime, local file roots are not mounted into the frontend container, so file listing/search stays unavailable instead of fabricating results."
          actions={<SpecModeBadge mode="read_only_redacted" />}
        />

        <div style={{ marginBottom: 16 }}>
          <FilesLocalContractProbe />
        </div>

        <div className="panel panel-pad" style={{ marginBottom: 16, display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
          <span className="panel-title">Root</span>
          <div className="chips">
            {FILE_ROOTS.map((r, i) => (
              <span key={r} className={`chip${i === 0 ? " active" : ""}`}>{r}</span>
            ))}
          </div>
          <div style={{ marginLeft: "auto" }}>
            <SafetyBadgeRow />
          </div>
        </div>

        <div className="grid" style={{ gridTemplateColumns: "300px 1fr 320px" }}>
          <Panel title="Tree (spec)">
            <div className="wb-pad tree">
              {PROJECT_TREE.map((n, i) => (
                <div key={i} className={`tnode${n.name === "AGENTS.md" ? " sel" : ""}`} style={{ paddingLeft: 8 + n.d * 14 }}>
                  {n.folder ? Icon.files({ size: 13 }) : Icon.docs({ size: 13 })}
                  <span>{n.name}</span>
                </div>
              ))}
            </div>
          </Panel>

          <Panel title="Preview (spec) · AGENTS.md">
            <div className="wb-pad">
              <pre className="code">{`# Cloud Superbrain — Agents
Workbench-first AI Developer Organism.
7-layer cloud stack backed by 8 providers:
  L1 Frontend  → Vercel
  L2 Orchestr. → Fly.io (LangGraph)
  L4 LLM GW    → Cloudflare · Hugging Face
  L5 MCP/Tools → GitHub · GHCR · GitLab
Provider writes, deploy, push remain CLOSED gates.`}</pre>
            </div>
          </Panel>

          <Panel title="Search (unavailable)">
            <div className="wb-pad stack">
              <div className="row local-search-row">
                <div
                  className="local-search-input"
                  aria-label="Search project files"
                  aria-disabled="true"
                  role="searchbox"
                >
                  Search is not wired in this runtime
                </div>
                <button
                  className="btn btn-sm"
                  aria-label="Search disabled read-only no live filesystem reads"
                  title="Search disabled: read-only contract, no live filesystem reads in this runtime"
                  disabled
                >
                  {Icon.search({ size: 14 })}
                </button>
              </div>
              <div className="list" style={{ border: "1px solid var(--border)", borderRadius: 10 }}>
                <div className="lrow" style={{ fontSize: 12.5, color: "var(--text-mut)" }}>No results<span className="meta">unavailable</span></div>
              </div>
              <p style={{ fontSize: 12, color: "var(--text-dim)" }}>
                <span className="mono">.env</span>, <span className="mono">.git</span> and secret paths
                never appear; binaries surface as metadata only.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}
