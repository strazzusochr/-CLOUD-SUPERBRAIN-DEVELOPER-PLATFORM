import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";

export const metadata = { title: "Proof / Evidence — Cloud Superbrain" };

type Tone = "green" | "amber" | "red" | "mut";
const EVIDENCE: { name: string; status: string; tone: Tone; ref: string }[] = [
  { name: "Build", status: "PASS", tone: "green", ref: "npm run build" },
  { name: "Lint", status: "PASS", tone: "green", ref: "next lint" },
  { name: "Organism contract", status: "PASS", tone: "green", ref: "secret_output=false" },
  { name: "Browser contract", status: "PASS", tone: "green", ref: "localhost:8081" },
  { name: "Secret scan", status: "CLEAN", tone: "green", ref: "gitleaks=0" },
  { name: "E2E", status: "PARTIAL", tone: "amber", ref: "no runtime source" },
  { name: "Production deploy", status: "BLOCKED", tone: "red", ref: "gate closed" },
];

export default function EvidencePage() {
  return (
    <AppShell crumb="Evidence" runState="verifying">
      <div className="page-wide">
        <PageHeader
          eyebrow="Proof / Evidence"
          title="Verifier results & claim guard"
          subtitle="Every claim maps to a verifier or proof file. Honest PASS / PARTIAL / BLOCKED — no faked green."
          actions={<><button className="btn btn-sm btn-ghost">Export</button><button className="btn btn-sm">Share</button></>}
        />
        <div className="grid" style={{ gridTemplateColumns: "1.2fr 0.8fr" }}>
          <Panel title="All evidence">
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
          <Panel title="Claim guard" pad>
            <div className="stack">
              <div className="note blocked">
                These remain hard non-claims until a new proof exists: production deploy, release
                promotion, provider writes, push, live MCP/LLM call, secret output.
              </div>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>Last commit</span>
                <span className="mono" style={{ fontSize: 12, color: "var(--text-mut)" }}>feature/22-page-platform</span>
              </div>
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}
