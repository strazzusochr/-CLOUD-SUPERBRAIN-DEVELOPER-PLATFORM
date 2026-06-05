import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Metric, Bar, Note } from "../../components/ui";
import { MANIFEST } from "../../lib/platform";
import { LAYERS } from "../../components/organism/regionMap";
import { fetchProgress } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Diagnostics / Archive — Cloud Superbrain" };

const ARCHIVE = [
  { name: "Owner Approval Storage Dry-Run", date: "2026-05-27", kind: "Run" },
  { name: "File Apply Preflight Dry-Run", date: "2026-05-27", kind: "Run" },
  { name: "Historical progress 82 / 95 / 97", date: "legacy", kind: "Snapshot" },
  { name: "Recovery bundle 2026-05-27-1700", date: "2026-05-27", kind: "Recovery" },
];

export default async function DiagnosticsPage() {
  const progress = await fetchProgress();
  const live = typeof progress?.overall_percent === "number";
  const overall = live ? progress!.overall_percent! : MANIFEST.overall;
  return (
    <AppShell crumb="Diagnostics" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Diagnostics / Archive"
          title="Project progress, recovery & raw verifiers"
          subtitle="This — and only this — is where project-status percentages and recovery bundles live. Kept off Home and Workbench by design."
          actions={live ? <Badge tone="green">● Live · /api/v1/project/progress</Badge> : <Badge tone="amber">manifest snapshot</Badge>}
        />

        <Note variant={live ? "info" : "warn"}>
          {live ? (
            <>
              Live projection from <span className="mono">GET /api/v1/project/progress</span> —{" "}
              source <span className="mono">{progress!.progress_source ?? "manifest"}</span>, last verified{" "}
              <span className="mono">{progress!.last_verified ?? "—"}</span>. Evidence-based, never fabricated.
            </>
          ) : (
            <>
              Manifest snapshot <span className="mono">{MANIFEST.snapshot}</span> — live values project
              from <span className="mono">GET /api/v1/project/progress</span> and{" "}
              <span className="mono">/project/progress/layers</span> when the runtime is reachable. Legacy
              values (82 / 95 / 97) are historical; see{" "}
              <Link href="/evidence" style={{ color: "var(--cyan)" }}>Evidence</Link> for current proofs.
            </>
          )}
        </Note>

        <div className="grid cols-3" style={{ margin: "16px 0" }}>
          <Metric label="Overall progress" value={`${overall}%`} foot={<Badge tone={live ? "green" : "amber"}>{live ? "live" : "manifest"}</Badge>} />
          <Metric label="Progress integrity" value="verified" foot={<Badge tone="green">contract</Badge>} />
          <Metric label="Production deploy" value="blocked" foot={<Badge tone="red">gate closed</Badge>} />
        </div>

        <div className="grid cols-2">
          <Panel title="Module readiness (7 layers)">
            <div className="wb-pad stack" style={{ gap: 10 }}>
              {MANIFEST.modules.map((m) => {
                const layer = LAYERS[m.layer - 1];
                return (
                  <div key={m.name} className="svc-row">
                    <span className="layer-tag" style={{ background: layer.color, padding: "2px 7px", fontSize: 10.5, minWidth: 26 }}>L{m.layer}</span>
                    <span style={{ fontSize: 13, minWidth: 110 }}>{m.name}</span>
                    <Bar pct={m.pct} />
                    <span style={{ fontSize: 11, color: "var(--text-mut)", minWidth: 34, textAlign: "right" }}>{m.pct}%</span>
                  </div>
                );
              })}
            </div>
          </Panel>

          <Panel title="Phase progress">
            <div className="wb-pad stack" style={{ gap: 10 }}>
              {MANIFEST.phases.map((p) => (
                <div key={p.id} className="svc-row">
                  <span className="mono" style={{ fontSize: 12, minWidth: 26 }}>{p.id}</span>
                  <Bar pct={p.pct} />
                  <span style={{ fontSize: 11, color: "var(--text-mut)", minWidth: 34, textAlign: "right" }}>{p.pct}%</span>
                </div>
              ))}
            </div>
          </Panel>
        </div>

        <Panel title="Archive & recovery" style={{ marginTop: 16 }}>
          <table className="tbl">
            <thead><tr><th>Item</th><th>Kind</th><th>Date</th><th /></tr></thead>
            <tbody>
              {ARCHIVE.map((a) => (
                <tr key={a.name}>
                  <td>{a.name}</td>
                  <td><Badge tone="mut">{a.kind}</Badge></td>
                  <td className="mono" style={{ color: "var(--text-mut)", fontSize: 12 }}>{a.date}</td>
                  <td style={{ textAlign: "right" }}><button className="btn btn-sm btn-ghost">Open</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>
      </div>
    </AppShell>
  );
}
