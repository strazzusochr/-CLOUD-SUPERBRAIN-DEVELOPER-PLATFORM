import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { FilesSearchPanel } from "../../components/goal-b-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Wissen & Gedächtnis — Cloud Superbrain" };

// The platform's long-term memory: store facts and find them again semantically
// (real vector search with free embeddings).
export default function FilesPage() {
  return (
    <AppShell crumb="Wissen & Gedächtnis" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Wissen & Gedächtnis"
          title="Semantisches Gedächtnis"
          subtitle="Speichere Wissen und finde es per Bedeutung wieder — echte Vektorsuche mit kostenlosen Embeddings."
        />
        <Panel title="Gedächtnis durchsuchen" actions={<Badge tone="green">echt · Vektorsuche</Badge>}>
          <div className="wb-pad">
            <FilesSearchPanel />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
