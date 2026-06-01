import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Metric, Note } from "../../components/ui";

export const metadata = { title: "Diagnostics / Archive — Cloud Superbrain" };

const ARCHIVE = [
  { name: "Owner Approval Storage Dry-Run", date: "2026-05-27", kind: "Run" },
  { name: "File Apply Preflight Dry-Run", date: "2026-05-27", kind: "Run" },
  { name: "Historical progress 82 / 95 / 97", date: "legacy", kind: "Snapshot" },
  { name: "GitKraken / GitClear", date: "legacy", kind: "Archive" },
  { name: "Recovery bundle 2026-05-27-1700", date: "2026-05-27", kind: "Recovery" },
];

export default function DiagnosticsPage() {
  return (
    <AppShell crumb="Diagnostics" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Diagnostics / Archive"
          title="Historical progress, recovery & raw verifiers"
          subtitle="This — and only this — is where project-status percentages, recovery bundles and raw verifier history live. Kept out of Home and Workbench by design."
        />

        <Note variant="warn">
          Legacy progress values (82 / 95 / 97, 7-of-8) are historical snapshots. They do not
          represent active readiness — see <Link href="/evidence" style={{ color: "var(--cyan)" }}>Evidence</Link> for current proofs.
        </Note>

        <div className="grid cols-3" style={{ margin: "16px 0" }}>
          <Metric label="System health" value="99.8%" foot={<Badge tone="green">overall</Badge>} />
          <Metric label="Archived runs" value="12" foot={<>q-archive</>} />
          <Metric label="Recovery bundles" value="4" foot={<>retained 30d</>} />
        </div>

        <Panel title="Archive & backups">
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
