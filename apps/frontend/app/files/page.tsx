import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, SpecModeBadge } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchMetrics } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Files & Knowledge — Cloud Superbrain" };

const KB = [
  { name: "Vector store · pgvector", kind: "vector(1536)", count: "memory/search" },
  { name: "Memory consolidation", kind: "job", count: "consolidation/recent" },
  { name: "Relationship graph", kind: "relations", count: "open_nodes" },
  { name: "Purge lifecycle", kind: "gated", count: "purge/jobs" },
];

export default async function FilesPage() {
  const metrics = await fetchMetrics();
  const entries = metrics?.scalars.superbrain_memory_entries_total;
  const live = typeof entries === "number";
  const kb = KB.map((k) =>
    k.name.startsWith("Vector store") && live ? { ...k, count: `${entries.toLocaleString("en-US")} entries` } : k,
  );
  return (
    <AppShell crumb="Files & Knowledge" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Files & Knowledge"
          title="Knowledge bases"
          subtitle="Files, knowledge bases, vectors and a relationship graph — the platform's long-term memory surface."
          actions={
            <>
              {live ? <Badge tone="green">● Live · pgvector</Badge> : <SpecModeBadge mode="local_files" />}
              <Link href="/files/local" className="btn btn-sm">Open Local Files</Link>
            </>
          }
        />

        <div className="chips" style={{ marginBottom: 16 }}>
          <span className="chip active">All Sources</span>
          <span className="chip">Docs</span>
          <span className="chip">Code</span>
          <span className="chip">Datasets</span>
          <span className="chip">Vectors</span>
          <span className="chip">Graph</span>
        </div>

        <div className="grid" style={{ gridTemplateColumns: "1fr 1.3fr 300px" }}>
          <Panel title="Knowledge bases">
            <div className="list">
              {kb.map((k) => (
                <div key={k.name} className="lrow">
                  {Icon.files({ size: 16 })}
                  <span style={{ fontWeight: 500 }}>{k.name}</span>
                  <span className="meta">{k.count}</span>
                </div>
              ))}
            </div>
          </Panel>

          <Panel title="Knowledge graph" pad>
            <svg viewBox="0 0 400 240" width="100%" height="240" role="img" aria-label="Knowledge graph">
              <defs>
                <radialGradient id="kg" cx="50%" cy="50%">
                  <stop offset="0%" stopColor="#00e5ff" />
                  <stop offset="100%" stopColor="#3b82f6" />
                </radialGradient>
              </defs>
              {[[200, 120], [110, 70], [300, 80], [120, 180], [290, 175], [200, 40]].map((p, i) =>
                i === 0 ? null : (
                  <line key={i} x1={200} y1={120} x2={p[0]} y2={p[1]} stroke="rgba(0,229,255,0.25)" strokeWidth="1" />
                ),
              )}
              {[[200, 120, 16], [110, 70, 9], [300, 80, 9], [120, 180, 8], [290, 175, 8], [200, 40, 7]].map((p, i) => (
                <circle key={i} cx={p[0]} cy={p[1]} r={p[2]} fill={i === 0 ? "url(#kg)" : "#8b5cf6"} opacity={i === 0 ? 1 : 0.85} />
              ))}
            </svg>
          </Panel>

          <Panel title="Inspector">
            <div className="wb-pad stack">
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>Embeddings</span>
                <Badge tone="cyan">pgvector</Badge> <Badge tone="mut">1536-dim</Badge>
              </div>
              <p style={{ fontSize: 12.5, color: "var(--text-mut)" }}>
                Source labels and relationships are shown per node. Generation runs only on real
                indexed content — no fake embeddings.
              </p>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}
