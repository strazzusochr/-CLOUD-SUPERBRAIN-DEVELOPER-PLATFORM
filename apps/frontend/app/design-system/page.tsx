import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, Badge, StatusDot, Bar } from "../../components/ui";

export const metadata = { title: "Designsystem — Cloud Superbrain" };

const COLORS = [
  { name: "Deep", hex: "#05070D", swatchClass: "color-deep" },
  { name: "Surface 1", hex: "#0B1020", swatchClass: "color-surface-1" },
  { name: "Surface 2", hex: "#101A31", swatchClass: "color-surface-2" },
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
  ["H3", "18 / 26"], ["Fließtext", "14 / 22"], ["Mono", "13 / 20"],
];

export default function DesignSystemPage() {
  return (
    <AppShell crumb="Designsystem" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Designsystem"
          title="NeuroGlass Enterprise Dark"
          subtitle="Design-Tokens, Typografie, Komponenten und Datenvisualisierung. WCAG 2.2: 4,5:1 für Text, 3:1 für Nichttext. Ein Status wird nie nur über Farbe vermittelt."
          actions={<Link href="/responsive" className="btn btn-sm btn-ghost">Responsive-Vorschau →</Link>}
        />


        <div className="grid cols-2">
          <Panel title="Live-Daten" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
            <div className="wb-pad">
              <LiveConsole endpoints={[{ label: "Referenzdesign-Vertrag", path: "/api/v1/design/reference-contract" }]} />
            </div>
          </Panel>
          <Panel title="Farbpalette" pad>
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
            <Panel title="Typografie" pad>
              <div className="stack typography-list">
                {TYPE.map(([name, size]) => (
                  <div key={name} className="type-row">
                    <span>{name}</span>
                    <span className="mono type-row-value">{size}</span>
                  </div>
                ))}
              </div>
            </Panel>
            <Panel title="Komponenten" pad>
              <div className="stack stack-gap-12">
                <div className="chips">
                  <span className="btn btn-primary btn-sm">Primär</span>
                  <span className="btn btn-sm">Sekundär</span>
                  <span className="btn btn-ghost btn-sm">Dezent</span>
                  <span className="btn btn-danger btn-sm">Gefahr</span>
                </div>
                <div className="safety-row">
                  <Badge tone="cyan">live</Badge>
                  <Badge tone="amber">nur Spezifikation</Badge>
                  <Badge tone="red">blockiert</Badge>
                  <Badge tone="green">verifiziert</Badge>
                </div>
                <div className="status-inline-row">
                  <span className="status-inline-item"><StatusDot tone="cyan" pulse /> wird ausgeführt</span>
                  <span className="status-inline-item"><StatusDot tone="green" /> fertig</span>
                  <span className="status-inline-item"><StatusDot tone="red" /> blockiert</span>
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
