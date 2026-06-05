import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader, Badge } from "../../components/ui";

export const metadata = { title: "Apps / Generated Output — Cloud Superbrain" };

type Tone = "green" | "amber" | "violet";
const APPS: { name: string; kind: string; status: string; tone: Tone }[] = [
  { name: "Superbrain Game Engine", kind: "Game", status: "local preview", tone: "green" },
  { name: "Crisis Dashboard", kind: "App", status: "local preview", tone: "green" },
  { name: "Cortex Visualizer", kind: "App", status: "local preview", tone: "green" },
  { name: "Verifier Suite", kind: "Tool", status: "verified", tone: "green" },
  { name: "Media Studio", kind: "App", status: "spec-only", tone: "amber" },
  { name: "Corona Control", kind: "App", status: "planned", tone: "violet" },
];

export default function AppsPage() {
  return (
    <AppShell crumb="Apps" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Apps / Generated Output"
          title="Generated apps"
          subtitle="Generated app cards, preview frame and route inspector. Open in Workbench or send to Review — honest status per card."
          actions={<Link href="/workbench" className="btn btn-sm btn-primary">New from Workbench</Link>}
        />
        <div className="card-grid">
          {APPS.map((a) => (
            <div key={a.name} className="gcard">
              <div className="preview">{a.kind} preview</div>
              <div className="body">
                <h3>{a.name}</h3>
                <div className="sub"><Badge tone={a.tone}>{a.status}</Badge></div>
                <div className="actions">
                  <Link href="/workbench" className="btn btn-sm btn-primary">Open</Link>
                  <Link href="/evidence" className="btn btn-sm btn-ghost">Review</Link>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
