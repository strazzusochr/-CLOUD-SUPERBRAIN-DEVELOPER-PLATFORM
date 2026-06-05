import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import OrganismView from "../../components/organism/OrganismView";

export const dynamic = "force-dynamic";
export const metadata = { title: "Organism / Cortex Canvas — Cloud Superbrain" };

export default function OrganismPage() {
  return (
    <AppShell crumb="Organism" runState="planning">
      <div className="page-wide" style={{ paddingBottom: 0 }}>
        <SevenLayerBar title="Organism state verified across 7 cloud layers" />
      </div>
      <OrganismView mode="live" />
    </AppShell>
  );
}
