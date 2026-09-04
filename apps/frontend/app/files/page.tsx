import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { FilesSearchPanel } from "../../components/goal-b-actions";

export const dynamic = "force-dynamic";
export const metadata = { title: "Wissen & Gedächtnis — Cloud Superbrain" };

// Long-term memory stays behind the Agent API. The current safe fallback is
// lexical search until the embedding-provider and budget gates are open.
export default function FilesPage() {
  return (
    <AppShell crumb="Wissen & Gedächtnis" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Wissen & Gedächtnis"
          title="Gedächtnis durchsuchen"
          subtitle="Durchsuche freigegebene Laufzeitdaten über die Agent API. Bis zum Embedding-Gate bleibt die Suche im sicheren lexikalischen Fallback."
        />
        <Panel title="Gedächtnis durchsuchen" actions={<Badge tone="cyan">Agent API · lexical fallback</Badge>}>
          <div className="wb-pad">
            <FilesSearchPanel />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
