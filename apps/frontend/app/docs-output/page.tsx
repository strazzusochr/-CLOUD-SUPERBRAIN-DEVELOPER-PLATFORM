import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { CreatorStudio } from "../../components/creator-studio";
import { ArtifactLibrary } from "../../components/artifact-library";

export const metadata = { title: "Dokumente — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// Real document generation: write Markdown → live HTML preview → download .md/.html.
export default function DocsOutputPage() {
  return (
    <AppShell crumb="Dokumente" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Dokumente"
          title="Dokumente erstellen"
          subtitle="Schreibe Markdown, sieh die Live-Vorschau und lade als .md oder .html herunter."
        />
        <Panel title="Dokumentenstudio" actions={<Badge tone="green">echt · Herunterladen</Badge>}>
          <div className="wb-pad">
            <CreatorStudio only="doc" />
          </div>
        </Panel>

        <Panel title="Dokument-Bibliothek (persistiert)" className="mb-16" actions={<Badge tone="cyan">GitHub-Store · echt</Badge>}>
          <div className="wb-pad">
            <ArtifactLibrary types={["document", "doc", "markdown", "pdf_plan", "md_export"]} emptyText="Noch keine Dokumente im Store gespeichert — Editor-Exporte laden direkt als Datei herunter." testId="docs-library" />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
