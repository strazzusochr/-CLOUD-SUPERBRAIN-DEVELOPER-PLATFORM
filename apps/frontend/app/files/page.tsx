import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, Badge, SpecModeBadge } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchMetrics } from "../../lib/agentApi";
import { FilesSearchPanel } from "../../components/goal-b-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Files & Knowledge — Cloud Superbrain" };

type SearchParams = Record<string, string | string[] | undefined>;
type FilesPageProps = {
  searchParams?: Promise<SearchParams>;
};
async function resolveSearchParams(searchParams: FilesPageProps["searchParams"]): Promise<SearchParams> {
  if (!searchParams) return {};
  return searchParams;
}

const KB = [
  { name: "Vector store · pgvector", kind: "vector(1536)", count: "memory/search" },
  { name: "Memory consolidation", kind: "job", count: "consolidation/recent" },
  { name: "Relationship graph", kind: "relations", count: "open_nodes" },
  { name: "Purge lifecycle", kind: "gated", count: "purge/jobs" },
];

export default async function FilesPage({ searchParams }: FilesPageProps) {
  const resolvedSearchParams = await resolveSearchParams(searchParams);
  const metrics = await fetchMetrics();
  const entries = metrics?.scalars.superbrain_memory_entries_total;
  const live = typeof entries === "number";
  const kb = KB.map((k) =>
    k.name.startsWith("Vector store") && live ? { ...k, count: `${entries.toLocaleString("en-US")} entries` } : k,
  );
  const srcRaw = resolvedSearchParams.src;
  const src = (Array.isArray(srcRaw) ? srcRaw[0] : srcRaw) ?? "all";
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

        <div className="chips mb-16">
          <Link href="/files?src=all" className={`chip${src === "all" ? " active" : ""}`}>All Sources</Link>
          <Link href="/files?src=docs" className={`chip${src === "docs" ? " active" : ""}`}>Docs</Link>
          <Link href="/files?src=code" className={`chip${src === "code" ? " active" : ""}`}>Code</Link>
          <Link href="/files?src=datasets" className={`chip${src === "datasets" ? " active" : ""}`}>Datasets</Link>
          <Link href="/files?src=vectors" className={`chip${src === "vectors" ? " active" : ""}`}>Vectors</Link>
          <Link href="/files?src=graph" className={`chip${src === "graph" ? " active" : ""}`}>Graph</Link>
        </div>
        <Panel title="Live console" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
          <div className="wb-pad">
            <LiveConsole endpoints={[{ label: "Memory consolidation", path: "/api/v1/memory/consolidation/recent" }, { label: "Embedding consistency", path: "/api/v1/memory/embedding-consistency/contract" }]} />
          </div>
        </Panel>

        <Panel title="Goal B memory search (pgvector lexical fallback)" actions={<Badge tone="cyan">read-only</Badge>} className="mb-16">
          <div className="wb-pad">
            <FilesSearchPanel />
          </div>
        </Panel>

        <div className="grid grid-files">
          <Panel title="Knowledge bases">
            <div className="list">
              {kb.map((k) => (
                <div key={k.name} className="lrow">
                  {Icon.files({ size: 16 })}
                  <span className="lrow-title">{k.name}</span>
                  <span className="meta">{k.count}</span>
                </div>
              ))}
            </div>
          </Panel>

          <Panel title="Knowledge graph" pad>
            <svg viewBox="0 0 400 240" width="100%" height="240" role="img" aria-label="Knowledge graph">
              <defs>
                <radialGradient id="kg" cx="50%" cy="50%">
                  <stop offset="0%" stopColor="var(--cyan)" />
                  <stop offset="100%" stopColor="var(--blue)" />
                </radialGradient>
              </defs>
              {[[200, 120], [110, 70], [300, 80], [120, 180], [290, 175], [200, 40]].map((p, i) =>
                i === 0 ? null : (
                  <line key={i} x1={200} y1={120} x2={p[0]} y2={p[1]} stroke="rgba(0,229,255,0.25)" strokeWidth="1" />
                ),
              )}
              {[[200, 120, 16], [110, 70, 9], [300, 80, 9], [120, 180, 8], [290, 175, 8], [200, 40, 7]].map((p, i) => (
                <circle key={i} cx={p[0]} cy={p[1]} r={p[2]} fill={i === 0 ? "url(#kg)" : "var(--violet)"} opacity={i === 0 ? 1 : 0.85} />
              ))}
            </svg>
          </Panel>

          <Panel title="Inspector">
            <div className="wb-pad stack">
              <div>
                <div className="panel-title mb-8">Embeddings</div>
                <Badge tone="cyan">pgvector</Badge> <Badge tone="mut">1536-dim</Badge>
              </div>
              <p className="agent-role">
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
