import AppShell from "../../../components/shell/AppShell";
import { PageHeader, Panel, SafetyBadgeRow, SpecModeBadge } from "../../../components/ui";
import { Icon } from "../../../lib/nav";
import { FILE_ROOTS, PROJECT_TREE } from "../../../lib/platform";

export const metadata = { title: "Local Files (read-only) — Cloud Superbrain" };

export default function LocalFilesPage() {
  return (
    <AppShell crumb="Local Files" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Local Files Read-only API"
          title="Local files"
          subtitle="Secure, read-only access to scoped roots. Path traversal, .git, .env, secrets and tokens are blocked."
          actions={<SpecModeBadge mode="read_only_redacted" />}
        />

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
          <Panel title="Tree">
            <div className="wb-pad tree">
              {PROJECT_TREE.map((n, i) => (
                <div key={i} className={`tnode${n.name === "AGENTS.md" ? " sel" : ""}`} style={{ paddingLeft: 8 + n.d * 14 }}>
                  {n.folder ? Icon.files({ size: 13 }) : Icon.docs({ size: 13 })}
                  <span>{n.name}</span>
                </div>
              ))}
            </div>
          </Panel>

          <Panel title="Preview · AGENTS.md">
            <div className="wb-pad">
              <pre className="code">{`# Cloud Superbrain — Agents
Workbench-first AI Developer Organism.
7-layer cloud stack backed by 8 providers:
  L1 Frontend  → Vercel
  L2 Orchestr. → Hetzner (LangGraph)
  L4 LLM GW    → Cloudflare · Hugging Face
  L5 MCP/Tools → GitHub · GHCR · GitLab · GitKraken
Provider writes, deploy, push remain CLOSED gates.`}</pre>
            </div>
          </Panel>

          <Panel title="Search · Metadata">
            <div className="wb-pad stack">
              <div className="row" style={{ gap: 8 }}>
                <input
                  placeholder="Search in project…"
                  style={{ flex: 1, background: "var(--surface-2)", border: "1px solid var(--border)", borderRadius: 9, padding: "8px 12px", fontSize: 13 }}
                />
                <button className="btn btn-sm" aria-label="Search">{Icon.search({ size: 14 })}</button>
              </div>
              <div className="list" style={{ border: "1px solid var(--border)", borderRadius: 10 }}>
                <div className="lrow" style={{ fontSize: 12.5 }}>AGENTS.md<span className="meta">read-only</span></div>
                <div className="lrow" style={{ fontSize: 12.5 }}>PROJECT_STATE.md<span className="meta">read-only</span></div>
                <div className="lrow" style={{ fontSize: 12.5 }}>services/agent-api<span className="meta">folder</span></div>
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
