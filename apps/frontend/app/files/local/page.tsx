import AppShell from "../../../components/shell/AppShell";
import { PageHeader, SpecModeBadge } from "../../../components/ui";
import { LocalFilesInteractivePanel } from "../../../components/batch5-actions";
import { FILE_ROOTS, PROJECT_TREE } from "../../../lib/platform";

export const metadata = { title: "Lokale Dateien (nur lesend) — Cloud Superbrain" };

export default function LocalFilesPage() {
  return (
    <AppShell crumb="Lokale Dateien" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Lokale Dateien (Spezifikationsoberfläche)"
          title="Lokale Dateien"
          subtitle="Dies ist eine sichere, nur lesende Absichtsoberfläche. In dieser Runtime sind lokale Stammverzeichnisse nicht in den Frontend-Container eingebunden. Dateiliste und Suche bleiben daher nicht verfügbar, statt Ergebnisse vorzutäuschen."
          actions={<SpecModeBadge mode="read_only_redacted" />}
        />

        <LocalFilesInteractivePanel roots={FILE_ROOTS} tree={PROJECT_TREE} />
      </div>
    </AppShell>
  );
}
