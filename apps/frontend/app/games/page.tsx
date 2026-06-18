import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge } from "../../components/ui";
import { RealGame } from "../../components/real-game";
import { AiBuilder } from "../../components/ai-builder";
import { BuildsGallery } from "../../components/builds-gallery";

export const metadata = { title: "Spiele — Cloud Superbrain" };
export const dynamic = "force-dynamic";

// Build a game by describing it → it runs live. Plus a built-in playable demo.
export default function GamesPage() {
  return (
    <AppShell crumb="Spiele" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Spiele"
          title="Spiele bauen"
          subtitle="Beschreibe ein Spiel — ein echtes Code-Modell baut es und es läuft sofort spielbar."
        />
        <Panel title="Spiel bauen mit KI · beschreibe es, spiel es sofort" className="mb-16" actions={<Badge tone="green">echt · live</Badge>}>
          <div className="wb-pad">
            <AiBuilder
              placeholder="Beschreibe dein Spiel — z. B. „ein 3D-Asteroiden-Spiel mit Maus-Steuerung und Punktestand“"
              examples={[
                "Ein 3D-Asteroiden-Spiel mit Maus-Steuerung und Punktestand",
                "Ein Snake-Spiel mit Neon-Design und steigender Geschwindigkeit",
                "Ein Plattformer mit springender Figur und Hindernissen",
                "Ein Tower-Defense-Mini-Spiel auf Canvas",
                "Ein Flappy-Bird-Klon mit Highscore",
              ]}
            />
          </div>
        </Panel>

        <Panel title="Meine Spiele · gebaut & teilbar" className="mb-16" actions={<Badge tone="cyan">persistiert</Badge>}>
          <BuildsGallery />
        </Panel>

        <Panel title="Demo · spielbares 3D-Arena-Game" actions={<Badge tone="green">sofort spielbar</Badge>}>
          <div className="wb-pad">
            <RealGame />
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
