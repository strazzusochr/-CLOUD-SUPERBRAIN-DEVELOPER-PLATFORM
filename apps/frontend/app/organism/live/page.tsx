import AppShell from "../../../components/shell/AppShell";
import SevenLayerBar from "../../../components/shell/SevenLayerBar";
import OrganismView from "../../../components/organism/OrganismView";

export const dynamic = "force-dynamic";
export const metadata = { title: "Organism · Live — Cloud Superbrain" };

export default function OrganismLivePage() {
  return (
    <AppShell crumb="Organism · Live" runState="planning">
      <div className="page-wide pb-0">
        <SevenLayerBar title="Organism state verified across 7 cloud layers" />
      </div>
      <OrganismView mode="live" />
    </AppShell>
  );
}
