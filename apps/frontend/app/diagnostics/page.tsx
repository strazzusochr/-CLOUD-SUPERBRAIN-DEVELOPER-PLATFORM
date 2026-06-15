import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { DiagnosticsProbe } from "../../components/batch5-actions";
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

        <SevenLayerBar title="7 Layer Architektur (UI-Surfaces, read-only)" />
        <div style={{ marginTop: 16 }}>
          <DiagnosticsProbe />
        </div>

        <div className="grid cols-2" style={{ marginTop: 16 }}>
          <Panel title="Verifier (Rohliste)">
            <table className="tbl">
              <thead><tr><th>Skript</th><th /></tr></thead>
              <tbody>
                {VERIFIERS.map((v) => (
                  <tr key={v}>
                    <td className="mono" style={{ fontSize: 12 }}>{v}</td>
                    <td style={{ textAlign: "right" }}>
                      <Link href="/evidence" className="btn btn-sm btn-ghost">Nachweise</Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>

          <Panel title="Archiv & Recovery">
            <table className="tbl">
              <thead><tr><th>Item</th><th>Typ</th><th>Datum</th><th /></tr></thead>
              <tbody>
                {ARCHIVE.map((a) => (
                  <tr key={a.name}>
                    <td>{a.name}</td>
                    <td><Badge tone="mut">{a.kind}</Badge></td>
                    <td className="mono" style={{ color: "var(--text-mut)", fontSize: 12 }}>{a.date}</td>
                    <td style={{ textAlign: "right" }}>
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
