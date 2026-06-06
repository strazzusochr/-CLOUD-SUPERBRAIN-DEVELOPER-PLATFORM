import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
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

        <SevenLayerBar title="Project plan verified across 7 cloud layers" />

        <Note variant={live ? "info" : "warn"}>
          {live ? (
            <>
              Live project plan from <span className="mono">GET /api/v1/project/progress</span> —{" "}
              binding document <span className="mono">{progress!.binding_document ?? "—"}</span>, last verified{" "}
              <span className="mono">{progress!.last_verified ?? "—"}</span>.{" "}
              {progress!.truth_policy ?? "Evidence-based only — percentages increase only after code + runtime proof + verifier update."}
            </>
          ) : (
            <>
              Manifest snapshot <span className="mono">{MANIFEST.snapshot}</span> — the live 7×7 project
              plan projects from <span className="mono">GET /api/v1/project/progress</span> when the runtime
              is reachable. See <Link href="/evidence" style={{ color: "var(--cyan)" }}>Evidence</Link> for proofs.
            </>
          )}
        </Note>

        <div className="grid cols-3" style={{ margin: "16px 0" }}>
          <Metric label="Overall progress" value={`${overall}%`} foot={<Badge tone={live ? "green" : "amber"}>{live ? "live · evidence-based" : "manifest"}</Badge>} />
          <Metric label="Plan coverage" value={live ? `${progress!.phases.length} × ${progress!.layers.length}` : "7 × 7"} foot={<Badge tone="cyan">phases × layers</Badge>} />
          <Metric label="Production deploy" value="blocked" foot={<Badge tone="red">OPA gate (policy)</Badge>} />
        </div>

        <div className="grid cols-2">
          <Panel title={`Roadmap — ${live ? progress!.phases.length : 7} phases`}>
            <div className="wb-pad stack" style={{ gap: 9 }}>
              {(live ? progress!.phases : MANIFEST.phases.map((p) => ({ id: p.id, label: p.id, status: p.pct >= 100 ? "verified" : "in progress", percent: p.pct }))).map((p) => (
                <div key={p.id} className="svc-row">
                  <span className="mono" style={{ fontSize: 11.5, minWidth: 52, color: "var(--text-dim)" }}>{p.id}</span>
                  <span style={{ fontSize: 12.5, minWidth: 150, flex: 1 }}>{p.label}</span>
                  <Bar pct={p.percent} />
                  <Badge tone={p.percent >= 100 ? "green" : "amber"}>{p.status}</Badge>
                </div>
              ))}
            </div>
          </Panel>

          <Panel title={`Layer readiness — ${live ? progress!.layers.length : 7} layers`}>
            <div className="wb-pad stack" style={{ gap: 9 }}>
              {(live ? progress!.layers : MANIFEST.modules.map((m, i) => ({ id: `layer_${i + 1}`, label: m.name, status: m.pct >= 100 ? "verified" : "in progress", percent: m.pct }))).map((l, i) => {
                const layer = LAYERS[i] ?? LAYERS[0];
                return (
                  <div key={l.id} className="svc-row">
                    <span className="layer-tag" style={{ background: layer.color, padding: "2px 7px", fontSize: 10.5, minWidth: 26 }}>L{i + 1}</span>
                    <span style={{ fontSize: 12.5, minWidth: 150, flex: 1 }}>{l.label}</span>
                    <Bar pct={l.percent} />
                    <Badge tone={l.percent >= 100 ? "green" : "amber"}>{l.status}</Badge>
                  </div>
                );
              })}
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
