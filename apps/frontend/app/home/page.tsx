import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import SevenLayerBar from "../../components/shell/SevenLayerBar";
import { PageHeader, Panel, Metric, Badge, StatusDot } from "../../components/ui";
import { Icon } from "../../lib/nav";
import { fetchCompletionGate, fetchLayers, fetchLiveAgents, fetchMasterPlan, fetchRecentSessions } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Home — Cloud Superbrain" };

export default async function HomePage() {
  const [roster, sessions, layers, master, completion] = await Promise.all([
    fetchLiveAgents(),
    fetchRecentSessions(),
    fetchLayers(),
    fetchMasterPlan(),
    fetchCompletionGate(),
  ]);
  const live = !!master;

  const activeSessions = roster ? roster.agents.filter((a) => a.hasSession).length : 0;
  const agentValue = roster ? `${activeSessions} / ${roster.agents.length}` : "—";
  const projectCount = sessions ? new Set(sessions.map((s) => s.projectId).filter(Boolean)).size : null;
  const layersVerified = layers ? layers.filter((l) => l.verified).length : null;
  const layersTotal = layers ? layers.length : null;
  const gatesValue = completion ? (completion.canSetAllTo100 ? "OPEN" : "CLOSED") : "CLOSED";

  return (
    <AppShell crumb="Home" runState="idle">
      <div className="page">
        <PageHeader
          eyebrow="Overview"
          title="Welcome back"
          subtitle="Continue where you left off. Pick up a recent project or start a new run from the Workbench."
          actions={
            <Link href="/workbench" className="btn btn-primary">
              {Icon.workbench({ size: 16 })} Open Workbench
            </Link>
          }
        />

        <div className="grid cols-4" style={{ marginBottom: 16 }}>
          <Metric
            label="Recent projects"
            value={typeof projectCount === "number" ? String(projectCount) : "—"}
            foot={sessions ? <><StatusDot tone="green" pulse /> live · recent sessions</> : <><StatusDot tone="mut" /> unavailable</>}
          />
          <Metric
            label="Agents active"
            value={agentValue}
            foot={roster ? <><StatusDot tone="green" pulse /> live roster</> : <><StatusDot tone="mut" /> unavailable</>}
          />
          <Metric
            label="Cloud layers"
            value={typeof layersVerified === "number" && typeof layersTotal === "number" ? `${layersVerified}/${layersTotal}` : "—"}
            foot={layers ? <><StatusDot tone="green" pulse /> live · layers</> : <><StatusDot tone="mut" /> unavailable</>}
          />
          <Metric
            label="Gates"
            value={gatesValue}
            foot={completion ? <><StatusDot tone={completion.canSetAllTo100 ? "red" : "green"} pulse={!completion.canSetAllTo100} /> completion gate</> : <><StatusDot tone="green" /> safe by default</>}
          />
        </div>

        <div className="grid cols-2">
          <Panel
            title="Recent projects"
            actions={<Link href="/apps" className="btn btn-sm btn-ghost">All →</Link>}
          >
            <div className="list">
              {sessions?.length ? sessions.slice(0, 6).map((s) => (
                <Link key={s.id} href="/workbench" className="lrow">
                  {Icon.files({ size: 16 })}
                  <span style={{ fontWeight: 500 }}>{s.projectId || "project"}</span>
                  <Badge tone={s.status === "active" ? "green" : "mut"}>{s.status}</Badge>
                  <span className="meta">{s.startedAt ? s.startedAt.slice(0, 19).replace("T", " ") : ""}</span>
                </Link>
              )) : (
                <div className="lrow" style={{ color: "var(--text-mut)" }}>
                  {Icon.files({ size: 16 })}
                  <span style={{ fontWeight: 500 }}>No recent sessions</span>
                  <Badge tone="mut">{live ? "live" : "offline"}</Badge>
                  <span className="meta">Start from Workbench</span>
                </div>
              )}
            </div>
          </Panel>

          <Panel title="Next safe action" pad>
            <div className="stack">
              <div className="note">
                {live ? `Current plan: ${master!.overallPercent}% overall — keep gates closed, run read-only checks first.` : "Runtime unavailable — pages stay read-only and show unavailable instead of fake live claims."}
              </div>
              <div className="row" style={{ gap: 10 }}>
                <Link href="/workbench" className="btn btn-primary">Continue run</Link>
                <Link href="/organism" className="btn">View cortex</Link>
                <Link href="/evidence" className="btn btn-ghost">Open evidence</Link>
              </div>
              <div>
                <span className="panel-title" style={{ display: "block", marginBottom: 8 }}>
                  Output shortcuts
                </span>
                <div className="chips">
                  <Link href="/games" className="chip">Games</Link>
                  <Link href="/apps" className="chip">Apps</Link>
                  <Link href="/media" className="chip">Media</Link>
                  <Link href="/docs-output" className="chip">Documents</Link>
                </div>
              </div>
            </div>
          </Panel>
        </div>

        <div style={{ marginTop: 16 }}>
          <SevenLayerBar />
        </div>
      </div>
    </AppShell>
  );
}
