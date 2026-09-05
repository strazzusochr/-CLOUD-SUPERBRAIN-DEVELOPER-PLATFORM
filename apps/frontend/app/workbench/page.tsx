import AppShell from "../../components/shell/AppShell";
import { WorkbenchStudio } from "../../components/workbench-studio";

export const metadata = { title: "Bauen — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// IDE-style build studio: composer + Explorer (real generated files) + Editor/
// Live-Preview + real build log. The studio is the whole surface; built apps live
// in /apps. No duplicate gallery or extra chrome.
export default function WorkbenchPage() {
  return (
    <AppShell crumb="Bauen" runState="idle">
      <div className="page-wide">
        <WorkbenchStudio />
      </div>
    </AppShell>
  );
}
