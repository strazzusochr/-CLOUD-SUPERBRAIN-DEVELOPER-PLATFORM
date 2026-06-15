import AppShell from "../../components/shell/AppShell";
import Batch1WorkbenchStudio from "../../components/batch1-workbench-studio";
import { LiveConsole } from "../../components/live-console";
import { WorkbenchActionPanel } from "../../components/goal-b-actions";
import { Panel, Badge } from "../../components/ui";
import { paidCapabilityVisible } from "../../lib/paidCapabilities";

export const metadata = { title: "Workbench — Cloud Superbrain" };
export const dynamic = "force-dynamic";

type SearchParams = Record<string, string | string[] | undefined>;
type WorkbenchPageProps = {
  searchParams?: Promise<SearchParams>;
};

async function resolveSearchParams(searchParams: WorkbenchPageProps["searchParams"]): Promise<SearchParams> {
  if (!searchParams) return {};
  return searchParams;
}

export default async function WorkbenchPage({ searchParams }: WorkbenchPageProps) {
  const resolvedSearchParams = await resolveSearchParams(searchParams);
  const showBudget = paidCapabilityVisible(resolvedSearchParams);

  return (
    <AppShell crumb="Main Workbench" runState="idle">
      <div className="stack">
        <Batch1WorkbenchStudio showBudget={showBudget} />
        <div className="page-wide">
          <Panel title="Quick run (dry-run only)" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
            <div className="wb-pad">
              <WorkbenchActionPanel />
            </div>
          </Panel>
          <Panel title="Live workbench surfaces" actions={<Badge tone="cyan">interaktiv · read-only</Badge>}>
            <div className="wb-pad">
              <LiveConsole
                label="Workbench"
                endpoints={[
                  { label: "Health", path: "/api/v1/health" },
                  { label: "Agents status", path: "/api/v1/agents/status" },
                  { label: "Recent tasks", path: "/api/v1/tasks/recent" },
                  { label: "Recent sessions", path: "/api/v1/sessions/recent" },
                ]}
              />
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}
