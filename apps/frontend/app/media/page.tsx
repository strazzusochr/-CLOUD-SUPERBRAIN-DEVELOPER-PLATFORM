import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { CreatorStudio } from "../../components/creator-studio";

export const metadata = { title: "Medien — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// Real client-side media generation: documents, music, video — all downloadable.
export default function MediaPage() {
  return (
    <AppShell crumb="Medien" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Medien"
          title="Dokumente · Musik · Video"
          subtitle="Echte Generierung direkt im Browser — erzeugen und als Datei herunterladen."
        />
        <Panel title="Creator Studio" actions={<Badge tone="green">echt · Download</Badge>}>
          <div className="wb-pad">
            <CreatorStudio />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
