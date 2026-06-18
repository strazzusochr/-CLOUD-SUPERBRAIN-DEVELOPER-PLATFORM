import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import { LiveConsole } from "../../components/live-console";
import { PageHeader, Panel, Badge, EmptyState } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchRecentTasks } from "../../lib/agentApi";
import { WorkspaceModeActionPanel } from "../../components/goal-b-actions";
import { RealGame } from "../../components/real-game";
import { AiBuilder } from "../../components/ai-builder";

export const metadata = { title: "Games Workflow — Cloud Superbrain" };
export const dynamic = "force-dynamic";

const TEMPLATES = ["Top-down", "Platformer", "Third-person", "Puzzle"];

export default async function GamesPage() {
  const tasks = await fetchRecentTasks();
  const live = !!tasks;
  const list = tasks?.tasks ?? [];
  const filtered = list.filter((t) => /(game|r3f|three|webgl|scene|physics)/i.test(`${t.taskType} ${t.description}`));
  return (
    <AppShell crumb="Games" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Spiele"
          title="Spiele-Projekte"
          subtitle="Game-orientierter Arbeitsbereich. Wenn die Runtime erreichbar ist, werden echte game-nahe Tasks angezeigt; sonst bleibt alles offline."
          actions={
            <>
              {live ? <Badge tone="green">● Live</Badge> : <Badge tone="mut">offline</Badge>}
              {tasks ? <Badge tone="mut">queue {tasks.queueDepth}</Badge> : null}
              <Link href="/workbench" className="btn btn-sm">In Werkbank öffnen</Link>
            </>
          }
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
        <Panel title="Live 3D Game · superbrain-arena" className="mb-16" actions={<Badge tone="green">echt spielbar</Badge>}>
          <div className="wb-pad">
            <RealGame />
          </div>
        </Panel>
        <div className="grid grid-games">
          <Panel title="Live console" className="mb-16" actions={<Badge tone="cyan">interaktiv</Badge>}>
            <div className="wb-pad">
              <LiveConsole endpoints={[{ label: "Platform verify", path: "/api/v1/platform/verify" }]} />
            </div>
          </Panel>
          <Panel title="Templates">
            <div className="list">
              {TEMPLATES.map((t) => (
                <div key={t} className="lrow text-13">{t}</div>
              ))}
            </div>
            <div className="wb-pad">
              <WorkspaceModeActionPanel mode="games" label="Game" />
            </div>
          </Panel>
          <Panel title="Scene-Preview · superbrain-game-engine">
            <div className="wb-pad">
              {filtered.length ? (
                <div className="stack gap-10">
                  {filtered.slice(0, 6).map((t) => (
                    <div key={t.id} className="svc-row">
                      <Badge tone={t.status === "completed" ? "green" : t.status === "failed" ? "red" : "mut"}>{t.status}</Badge>
                      <span className="mono text-115 text-dim">{t.taskType}</span>
                      <span className="text-12 text-mut">{t.description}</span>
                    </div>
                  ))}
                  <div className="row gap-8">
                    <Link href="/workbench" className="btn btn-sm btn-primary">{Icon.play({ size: 13 })} Werkbank öffnen</Link>
                    <Link href="/organism" className="btn btn-sm btn-ghost">Cortex</Link>
                  </div>
                </div>
              ) : (
                <EmptyState
                  title="Noch keine Game-Tasks"
                  body="Erstelle einen Game-Task in der Werkbank. Diese Surface bleibt read-only und erfindet keine Previews."
                  action={<Link href="/workbench" className="btn btn-sm btn-primary">Werkbank öffnen</Link>}
                />
              )}
            </div>
          </Panel>
          <Panel title="Assets">
            <div className="wb-pad">
              <EmptyState
                title="Keine Assets indiziert"
                body="Asset-Inventar ist in diesem Build nicht verdrahtet. Nutze Dateien & Wissen für die memory-backed Ansicht."
                action={<Link href="/files" className="btn btn-sm btn-ghost">Dateien öffnen</Link>}
              />
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}
