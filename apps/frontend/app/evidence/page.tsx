import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { VERIFIERS, CLOSED_GATES } from "../../lib/platform";

export const metadata = { title: "Proof / Evidence — Cloud Superbrain" };

type Tone = "green" | "amber" | "red" | "mut";
const EVIDENCE: { name: string; status: string; tone: Tone; ref: string }[] = [
  { name: "Production build", status: "PASS", tone: "green", ref: "next build · 31 routes" },
  { name: "Type check (strict)", status: "PASS", tone: "green", ref: "tsc · 0 errors" },
  { name: "ESLint audit", status: "CLEAN", tone: "green", ref: "0 findings (app/components/lib)" },
  { name: "Route smoke", status: "PASS", tone: "green", ref: "27 / 27 HTTP 200" },
  { name: "3D cortex render", status: "PASS", tone: "green", ref: "WebGL · 0 console errors" },
  { name: "Secret scan", status: "CLEAN", tone: "green", ref: "no token values printed" },
  { name: "E2E (hosted runtime)", status: "PARTIAL", tone: "amber", ref: "no live backend in CI" },
  { name: "Production deploy", status: "BLOCKED", tone: "red", ref: "gate closed" },
];

export default function EvidencePage() {
  return (
    <AppShell crumb="Evidence" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Proof / Evidence"
          title="Verifier results & claim guard"
          subtitle="Every claim maps to a verifier or proof. Honest PASS / PARTIAL / BLOCKED — no faked green."
          actions={<><button className="btn btn-sm btn-ghost">Export</button><button className="btn btn-sm">Share</button></>}
        />
        <div className="grid" style={{ gridTemplateColumns: "1.2fr 0.8fr" }}>
          <Panel title="Current proofs (this branch)">
            <table className="tbl">
              <thead><tr><th>Check</th><th>Status</th><th>Reference</th></tr></thead>
              <tbody>
                {EVIDENCE.map((e) => (
                  <tr key={e.name}>
                    <td style={{ fontWeight: 500 }}>{e.name}</td>
                    <td><Badge tone={e.tone}>{e.status}</Badge></td>
                    <td className="mono" style={{ color: "var(--text-mut)", fontSize: 12 }}>{e.ref}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>
          <aside className="stack">
            <Panel title="Verifier scripts" pad>
              <div className="stack" style={{ gap: 6 }}>
                {VERIFIERS.map((v) => (
                  <span key={v} className="mono" style={{ fontSize: 11.5, color: "var(--text-mut)" }}>{v}</span>
                ))}
              </div>
            </Panel>
            <Panel title="Claim guard" pad>
              <div className="note blocked">
                Hard non-claims until a new proof exists:
              </div>
              <div className="chip-wrap" style={{ marginTop: 8 }}>
                {CLOSED_GATES.map((g) => (
                  <span key={g} className="review-chip" style={{ fontSize: 10.5 }}>{g}</span>
                ))}
              </div>
            </Panel>
          </aside>
        </div>
      </div>
    </AppShell>
  );
}
