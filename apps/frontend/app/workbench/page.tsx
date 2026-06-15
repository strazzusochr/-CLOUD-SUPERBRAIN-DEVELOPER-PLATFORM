import AppShell from "../../components/shell/AppShell";
import Batch1WorkbenchStudio from "../../components/batch1-workbench-studio";
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
      <Batch1WorkbenchStudio showBudget={showBudget} />
    </AppShell>
  );
}
