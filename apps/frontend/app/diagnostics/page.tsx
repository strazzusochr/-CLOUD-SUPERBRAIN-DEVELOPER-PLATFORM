import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { VERIFIERS } from "../../lib/platform";

export const dynamic = "force-dynamic";
export const metadata = { title: "Diagnose / Archiv — Cloud Superbrain" };

const ARCHIVE = [
  { name: "Owner Approval Storage Dry-Run", date: "2026-05-27", kind: "Run" },
  { name: "File Apply Preflight Dry-Run", date: "2026-05-27", kind: "Run" },
  { name: "Historical progress 82 / 95 / 97", date: "legacy", kind: "Snapshot" },
  { name: "Recovery bundle 2026-05-27-1700", date: "2026-05-27", kind: "Recovery" },
];

export default async function DiagnosticsPage() {
  return (
    <AppShell crumb="Diagnostics" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Diagnose / Archiv"
          title="Recovery, Archiv & Verifier-Rohdaten"
          subtitle="Saubere Entwicklerplattform: Projektplan läuft separat im Hintergrund. Diese UI zeigt keine Plan-/Progress-Prozente, nur Archive/Verifier."
          actions={<Badge tone="mut">read-only</Badge>}
        />

        <div className="grid cols-2 block-gap-16">
          <Panel title="Live-Daten" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
            <div className="wb-pad">
              <LiveConsole endpoints={[{ label: "Audit recent", path: "/api/v1/audit/recent" }, { label: "Escalations recent", path: "/api/v1/escalations/recent" }, { label: "Platform inventory", path: "/api/v1/platform/inventory" }]} />
            </div>
          </Panel>
          <Panel title="Verifier (Rohliste)">
            <table className="tbl">
              <thead><tr><th>Skript</th><th className="tbl-actions-col">Aktion</th></tr></thead>
              <tbody>
                {VERIFIERS.map((v) => (
                  <tr key={v}>
                    <td className="mono tbl-mono-sm">{v}</td>
                    <td className="tbl-cell-right">
                      <Link href="/evidence" className="btn btn-sm btn-ghost">Nachweise</Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>

          <Panel title="Archiv & Recovery">
            <table className="tbl">
              <thead><tr><th>Item</th><th>Typ</th><th>Datum</th><th className="tbl-actions-col">Aktion</th></tr></thead>
              <tbody>
                {ARCHIVE.map((a) => (
                  <tr key={a.name}>
                    <td>{a.name}</td>
                    <td><Badge tone="mut">{a.kind}</Badge></td>
                    <td className="mono muted-copy tbl-mono-sm">{a.date}</td>
                    <td className="tbl-cell-right">
                      <Link href={`/evidence?archive=${encodeURIComponent(a.name)}`} className="btn btn-sm btn-ghost">
                        Öffnen
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}
