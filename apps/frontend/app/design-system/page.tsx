import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, StatusDot, Bar } from "../../components/ui";
import { DesignSystemProbe } from "../../components/batch5-actions";

export const metadata = { title: "Design System — Cloud Superbrain" };

const COLORS = [
  { name: "Deep", hex: "#05070D", swatchClass: "color-deep" },
  { name: "Surface 1", hex: "#0B1020", swatchClass: "color-surface-1" },
  { name: "Surface 2", hex: "#121A32", swatchClass: "color-surface-2" },
  { name: "Neuro Cyan", hex: "#00E5FF", swatchClass: "color-neuro-cyan" },
  { name: "Ion Blue", hex: "#3B82F6", swatchClass: "color-ion-blue" },
  { name: "Plasma Violet", hex: "#8B5CF6", swatchClass: "color-plasma-violet" },
  { name: "Synapse Magenta", hex: "#EC4899", swatchClass: "color-synapse-magenta" },
  { name: "Memory Gold", hex: "#FBBF24", swatchClass: "color-memory-gold" },
  { name: "Success", hex: "#22C55E", swatchClass: "color-success" },
  { name: "Warning", hex: "#F59E0B", swatchClass: "color-warning" },
  { name: "Danger", hex: "#EF4444", swatchClass: "color-danger" },
  { name: "Text Primary", hex: "#EAF2FF", swatchClass: "color-text-primary" },
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

        <div className="block-gap-16">
          <DesignSystemProbe />
        </div>

        <div className="grid cols-2">
          <Panel title="Color palette" pad>
            <div className="swatches">
              {COLORS.map(({ name, hex, swatchClass }) => (
                <div key={name} className="sw">
                  <div className={`chip-color ${swatchClass}`} />
                  <div className="sw-meta"><b>{name}</b><span>{hex}</span></div>
                </div>
              ))}
            </div>
          </Panel>

          <div className="stack">
            <Panel title="Typography" pad>
              <div className="stack typography-list">
                {TYPE.map(([name, size]) => (
                  <div key={name} className="type-row">
                    <span>{name}</span>
                    <span className="mono type-row-value">{size}</span>
                  </div>
                ))}
              </div>
            </Panel>
            <Panel title="Components" pad>
              <div className="stack stack-gap-12">
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
                <div className="status-inline-row">
                  <span className="status-inline-item"><StatusDot tone="cyan" pulse /> executing</span>
                  <span className="status-inline-item"><StatusDot tone="green" /> done</span>
                  <span className="status-inline-item"><StatusDot tone="red" /> blocked</span>
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
