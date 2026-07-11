import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { CreatorStudio } from "../../components/creator-studio";
import { ArtifactLibrary } from "../../components/artifact-library";

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
          subtitle="Echte Generierung direkt im Browser — Audio-Synth und Canvas-Clips, als Datei exportierbar. Dokumente entstehen unter Dokumente."
        />
        <Panel title="Medienstudio" actions={<Badge tone="green">echt · Herunterladen</Badge>}>
          <div className="wb-pad">
            <CreatorStudio tabs={["music", "video"]} />
          </div>
        </Panel>

        <Panel title="Medien-Bibliothek (persistiert)" className="mb-16" actions={<Badge tone="cyan">GitHub-Store · echt</Badge>}>
          <div className="wb-pad">
            <ArtifactLibrary types={["media", "audio", "video", "image"]} emptyText="Noch keine Medien im Store gespeichert — Studio-Exporte laden direkt als Datei herunter." testId="media-library" />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
