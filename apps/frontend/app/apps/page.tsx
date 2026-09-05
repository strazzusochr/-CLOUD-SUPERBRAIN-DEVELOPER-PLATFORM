import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { PageHeader } from "../../components/ui";
import { BuildsGallery } from "../../components/builds-gallery";

export const metadata = { title: "Meine Apps — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// Clean app dashboard: just the gallery of everything you've built — open, edit,
// share, delete. Building happens in the Workbench.
export default function AppsPage() {
  return (
    <AppShell crumb="Apps" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Apps"
          title="Meine Apps"
          subtitle="Alles, was du mit KI gebaut hast — öffnen, bearbeiten, teilen oder löschen."
          actions={<Link href="/workbench" className="btn btn-primary">+ Neue App bauen</Link>}
        />
        <BuildsGallery />
      </div>
    </AppShell>
  );
}
