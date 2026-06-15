import AppShell from "../../../components/shell/AppShell";
import { PageHeader, SpecModeBadge } from "../../../components/ui";
import { FilesLocalContractProbe, LocalFilesInteractivePanel } from "../../../components/batch5-actions";
import { FILE_ROOTS, PROJECT_TREE } from "../../../lib/platform";

export const metadata = { title: "Local Files (read-only) — Cloud Superbrain" };

export default function LocalFilesPage() {
  return (
    <AppShell crumb="Local Files" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Local Files (spec surface)"
          title="Local files"
          subtitle="This is a safe, read-only intent surface. In this runtime, local file roots are not mounted into the frontend container, so file listing/search stays unavailable instead of fabricating results."
          actions={<SpecModeBadge mode="read_only_redacted" />}
        />

        <div className="mb-16">
          <FilesLocalContractProbe />
        </div>
        <LocalFilesInteractivePanel roots={FILE_ROOTS} tree={PROJECT_TREE} />
      </div>
    </AppShell>
  );
}
