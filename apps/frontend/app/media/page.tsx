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
          title="Musik · Video"
          subtitle="Echte Generierung direkt im Browser — Audio-Synth und Canvas-Clips, als Datei exportierbar. Dokumente entstehen unter Documents."
        />
        <Panel title="Creator Studio" actions={<Badge tone="green">echt · Download</Badge>}>
          <div className="wb-pad">
            <CreatorStudio tabs={["music", "video"]} />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
