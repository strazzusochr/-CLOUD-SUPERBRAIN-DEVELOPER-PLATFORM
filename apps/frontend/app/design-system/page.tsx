import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, StatusDot, Bar } from "../../components/ui";
import { DesignSystemProbe } from "../../components/batch5-actions";

export const metadata = { title: "Design System — Cloud Superbrain" };

const COLORS = [
  ["Deep", "#05070D"], ["Surface 1", "#0B1020"], ["Surface 2", "#121A32"],
  ["Neuro Cyan", "#00E5FF"], ["Ion Blue", "#3B82F6"], ["Plasma Violet", "#8B5CF6"],
  ["Synapse Magenta", "#EC4899"], ["Memory Gold", "#FBBF24"], ["Success", "#22C55E"],
  ["Warning", "#F59E0B"], ["Danger", "#EF4444"], ["Text Primary", "#EAF2FF"],
];
const TYPE = [
  ["Display", "36 / 44"], ["H1", "28 / 36"], ["H2", "22 / 30"],
  ["H3", "18 / 26"], ["Body", "14 / 22"], ["Mono", "13 / 20"],
];

export default function DesignSystemPage() {
  return (
    <AppShell crumb="Design System" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Design System"
          title="NeuroGlass Enterprise Dark"
          subtitle="Tokens, typography, components and data-viz. WCAG 2.2: 4.5:1 text, 3:1 non-text. Status is never colour-only."
          actions={<Link href="/responsive" className="btn btn-sm btn-ghost">Responsive preview →</Link>}
        />

        <div style={{ marginBottom: 16 }}>
          <DesignSystemProbe />
        </div>

        <div className="grid cols-2">
          <Panel title="Color palette" pad>
            <div className="swatches">
              {COLORS.map(([name, hex]) => (
                <div key={name} className="sw">
                  <div className="chip-color" style={{ background: hex }} />
                  <div className="sw-meta"><b>{name}</b><span>{hex}</span></div>
                </div>
              ))}
            </div>
          </Panel>

          <div className="stack">
            <Panel title="Typography" pad>
              <div className="stack" style={{ gap: 8 }}>
                {TYPE.map(([name, size]) => (
                  <div key={name} style={{ display: "flex", justifyContent: "space-between", fontSize: 13 }}>
                    <span>{name}</span>
                    <span className="mono" style={{ color: "var(--text-mut)" }}>{size}</span>
                  </div>
                ))}
              </div>
            </Panel>
            <Panel title="Components" pad>
              <div className="stack" style={{ gap: 12 }}>
                <div className="chips">
                  <span className="btn btn-primary btn-sm">Primary</span>
                  <span className="btn btn-sm">Secondary</span>
                  <span className="btn btn-ghost btn-sm">Ghost</span>
                  <span className="btn btn-danger btn-sm">Danger</span>
                </div>
                <div className="safety-row">
                  <Badge tone="cyan">live</Badge>
                  <Badge tone="amber">spec-only</Badge>
                  <Badge tone="red">blocked</Badge>
                  <Badge tone="green">verified</Badge>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
                  <span style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12 }}><StatusDot tone="cyan" pulse /> executing</span>
                  <span style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12 }}><StatusDot tone="green" /> done</span>
                  <span style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12 }}><StatusDot tone="red" /> blocked</span>
                </div>
                <Bar pct={64} />
              </div>
            </Panel>
          </div>
        </div>
      </div>
    </AppShell>
  );
}
