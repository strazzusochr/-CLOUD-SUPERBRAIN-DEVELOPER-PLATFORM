import AppShell from "../../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../../components/ui";

export const metadata = { title: "Technology Stack — Cloud Superbrain" };

const STACK: { group: string; items: [string, "verified" | "planned"][] }[] = [
  { group: "Frontend", items: [["Next.js", "verified"], ["React 19", "verified"], ["Canvas Cortex", "verified"], ["R3F (optional)", "planned"]] },
  { group: "Backend", items: [["FastAPI", "verified"], ["Uvicorn", "verified"], ["Pydantic", "verified"]] },
  { group: "AI / ML", items: [["LLM Gateway", "verified"], ["LangGraph", "planned"], ["HF Router", "planned"]] },
  { group: "Infrastructure", items: [["Docker", "verified"], ["Kubernetes", "planned"], ["Multi-cloud", "planned"]] },
  { group: "Data", items: [["PostgreSQL", "verified"], ["pgvector", "verified"], ["Redis", "verified"]] },
  { group: "Observability", items: [["OpenTelemetry", "planned"], ["Prometheus", "planned"], ["OPA gates", "verified"]] },
];

export default function StackPage() {
  return (
    <AppShell crumb="Technology Stack" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Technology Stack"
          title="Verified & planned technologies"
          subtitle="Each block is labelled honestly — verified means it runs in this repo today; planned means specced but not yet wired."
        />
        <div className="grid cols-3">
          {STACK.map((g) => (
            <Panel key={g.group} title={g.group}>
              <div className="list">
                {g.items.map(([name, status]) => (
                  <div key={name} className="lrow">
                    <span>{name}</span>
                    <span className="meta">
                      <Badge tone={status === "verified" ? "green" : "violet"}>{status}</Badge>
                    </span>
                  </div>
                ))}
              </div>
            </Panel>
          ))}
        </div>
      </div>
    </AppShell>
  );
}
