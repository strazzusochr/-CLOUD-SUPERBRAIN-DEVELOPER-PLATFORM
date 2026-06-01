import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";

export const metadata = { title: "MCP / Tools / Cloud Hub — Cloud Superbrain" };

type Tone = "green" | "amber" | "red" | "mut" | "cyan";
const PROVIDERS: { name: string; status: string; tone: Tone }[] = [
  { name: "GitHub", status: "configured", tone: "green" },
  { name: "AWS", status: "spec-only", tone: "amber" },
  { name: "GCP", status: "spec-only", tone: "amber" },
  { name: "Azure", status: "spec-only", tone: "amber" },
  { name: "Docker", status: "configured", tone: "green" },
  { name: "Kubernetes", status: "spec-only", tone: "amber" },
  { name: "PostgreSQL", status: "configured", tone: "green" },
  { name: "Redis", status: "configured", tone: "green" },
  { name: "Hetzner", status: "blocked", tone: "red" },
  { name: "Cloudflare", status: "spec-only", tone: "amber" },
  { name: "Vercel", status: "spec-only", tone: "amber" },
  { name: "HuggingFace", status: "configured", tone: "green" },
];

const MCP = [
  { name: "filesystem", mode: "read-only", status: "verified" },
  { name: "git", mode: "read-only", status: "verified" },
  { name: "memory", mode: "read/write (local)", status: "verified" },
  { name: "context7", mode: "read-only", status: "configured" },
  { name: "playwright", mode: "browser proof", status: "configured" },
  { name: "fetch", mode: "read-only", status: "configured" },
];

export default function ToolsPage() {
  return (
    <AppShell crumb="Tools" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="MCP / Tools / Cloud Hub"
          title="Providers, MCP servers & capabilities"
          subtitle="Auth state, read/write scope and health per integration. Write capabilities stay gated until explicitly approved."
          actions={<Link href="/marketplace" className="btn btn-sm btn-ghost">More in Marketplace →</Link>}
        />

        <Panel title="Cloud providers" className="" style={{ marginBottom: 16 }}>
          <div className="wb-pad">
            <div className="card-grid">
              {PROVIDERS.map((p) => (
                <div key={p.name} className="panel panel-pad" style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  <strong style={{ fontSize: 13.5 }}>{p.name}</strong>
                  <Badge tone={p.tone}>{p.status}</Badge>
                </div>
              ))}
            </div>
          </div>
        </Panel>

        <Panel title="MCP servers">
          <table className="tbl">
            <thead>
              <tr><th>Server</th><th>Mode</th><th>Status</th><th>Risk</th></tr>
            </thead>
            <tbody>
              {MCP.map((m) => (
                <tr key={m.name}>
                  <td className="mono">{m.name}</td>
                  <td>{m.mode}</td>
                  <td><Badge tone={m.status === "verified" ? "green" : "cyan"}>{m.status}</Badge></td>
                  <td><Badge tone="mut">low · read-only</Badge></td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>
      </div>
    </AppShell>
  );
}
