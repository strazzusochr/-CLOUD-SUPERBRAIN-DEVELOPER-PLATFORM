import AppShell from "../../components/shell/AppShell";
import TechnologyRuntimeView from "../../components/technology/TechnologyRuntimeView";
import { Badge, PageHeader } from "../../components/ui";

export const dynamic = "force-dynamic";
export const metadata = { title: "Technologie — Runtime-Verträge — Cloud Superbrain" };

export default function TechnologyPage() {
  return (
    <AppShell crumb="Technologie" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Architektur"
          title="Cloud-Runtime nach Vertrag"
          subtitle="Provider, Schichten und Deployment-Gates aus drei begrenzten Same-Origin-Verträgen. Repo- und Vertragsreferenzen sind keine Live-, Hosted- oder Produktionsbehauptung."
          actions={<Badge tone="amber">fail-closed · nur lesend</Badge>}
        />
        <TechnologyRuntimeView />
      </div>
    </AppShell>
  );
}
