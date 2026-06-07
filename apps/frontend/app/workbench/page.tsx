import Link from "next/link";
import AppShell from "../../components/shell/AppShell";
import CortexCanvas from "../../components/organism/CortexCanvas";
import { Panel, Badge, StatusDot, Note } from "../../components/ui";
import { Icon, WORKSPACE_PAGES } from "../../lib/nav";
import { LAYERS } from "../../components/organism/regionMap";
import { fetchAuditRecent, fetchCompletionGate, fetchLiveAgents, fetchRecentSessions, fetchRecentTasks } from "../../lib/agentApi";

export const metadata = { title: "Workbench — Cloud Superbrain" };
export const dynamic = "force-dynamic";

function shortId(id: string) {
  if (!id) return "";
  return id.length > 12 ? `${id.slice(0, 8)}…${id.slice(-4)}` : id;
}

function shortTime(ts: string | null) {
  if (!ts) return "";
  return ts.replace("T", " ").replace(/\.\d+.*$/, "Z").replace("+00:00", "Z");
}

export default async function WorkbenchPage() {
  const [tasks, sessions, audit, roster, completion] = await Promise.all([
    fetchRecentTasks(),
    fetchRecentSessions(),
    fetchAuditRecent(),
    fetchLiveAgents(),
    fetchCompletionGate(),
  ]);
  const live = !!tasks || !!sessions || !!audit || !!roster;
  const topSession = sessions && sessions.length ? sessions[0] : null;
  const topTask = tasks?.tasks?.length ? tasks.tasks[0] : null;
  const layerMeta = Object.fromEntries(LAYERS.map((l) => [l.code, l])) as Record<string, (typeof LAYERS)[number]>;
  const pagesByLayer = WORKSPACE_PAGES.reduce(
    (acc, p) => {
      (acc[p.layer] ||= []).push(p);
      return acc;
    },
    {} as Record<string, typeof WORKSPACE_PAGES>,
  );

  return (
    <AppShell crumb="Workbench" runState="planning">
      <div className="page-wide">
        <h1 className="sr-only">Workbench — runtime workbench</h1>
        <div className="panel panel-head" style={{ marginBottom: 16, borderRadius: 14 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <Badge tone="cyan">{Icon.workbench({ size: 13 })} superbrain-game-engine</Badge>
            {live ? <Badge tone="green">● Live</Badge> : <Badge tone="mut">offline</Badge>}
            {tasks ? <Badge tone="mut">queue {tasks.queueDepth}</Badge> : null}
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <Link href="/organism?run_id=active" className="btn btn-sm btn-ghost">
              {Icon.organism({ size: 14 })} Cortex öffnen
            </Link>
            {roster ? <Badge tone="violet">{roster.agents.filter((a) => a.hasSession).length} active</Badge> : <Badge tone="mut">roster</Badge>}
          </div>
        </div>

        <div className="wb">
          <aside className="panel" style={{ overflow: "hidden" }}>
            <div className="panel-head">
              <span className="panel-title">Sessions</span>
              {topSession ? <Badge tone="mut">{shortId(topSession.id)}</Badge> : null}
            </div>
            <div className="wb-pad tree">
              {!sessions ? (
                <div className="note">Runtime nicht erreichbar. Dev-Stack starten und neu laden.</div>
              ) : sessions.length ? (
                sessions.slice(0, 10).map((s) => (
                  <div key={s.id} className="tnode" style={{ paddingLeft: 8 }}>
                    <StatusDot tone={s.status === "active" ? "green" : "mut"} pulse={s.status === "active"} />
                    <span style={{ fontWeight: 500 }}>{s.projectId || "project"}</span>
                    <span className="meta mono">{shortTime(s.startedAt)}</span>
                    <span className="meta">{s.latestTaskStatus ?? s.status}</span>
                  </div>
                ))
              ) : (
                <div className="note">Noch keine Sessions.</div>
              )}
            </div>
          </aside>

          <main className="panel" style={{ overflow: "hidden", display: "flex", flexDirection: "column" }}>
            <div className="panel-head">
              <span className="panel-title">Tasks</span>
              {topTask ? <Badge tone="mut">{topTask.agentType}</Badge> : null}
            </div>
            <div className="wb-pad" style={{ flex: 1 }}>
              {!tasks ? (
                <div className="note">Task-Feed nicht verfügbar.</div>
              ) : tasks.tasks.length ? (
                <div className="list">
                  {tasks.tasks.slice(0, 12).map((t) => (
                    <div key={t.id} className="lrow" style={{ padding: "7px 0" }}>
                      <StatusDot tone={t.status === "completed" ? "green" : t.status === "failed" ? "red" : "cyan"} pulse={t.status === "active"} />
                      <span style={{ fontWeight: 500 }}>{t.taskType || t.agentType}</span>
                      <span className="meta">{t.status}</span>
                      <span className="meta mono">{shortId(t.id)}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="note">Noch keine Tasks.</div>
              )}
            </div>
          </main>

          <aside className="inspector panel" style={{ overflow: "hidden", display: "flex", flexDirection: "column" }}>
            <div className="panel-head">
              <span className="panel-title">Audit · Mini-Cortex</span>
            </div>
            <div className="wb-pad" style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <div style={{ aspectRatio: "16 / 11" }}>
                <CortexCanvas runState="planning" nodeCount={420} interactive={false} showRegions={false} />
              </div>
              {!audit ? (
                <div className="note">Audit-Feed nicht verfügbar.</div>
              ) : audit.length ? (
                <div className="list">
                  {audit.slice(0, 6).map((e) => (
                    <div key={e.id} className="lrow" style={{ padding: "7px 0" }}>
                      {Icon.evidence({ size: 14 })}
                      <span style={{ fontWeight: 500 }}>{e.type}</span>
                      <span className="meta mono">{e.sessionId ? shortId(e.sessionId) : ""}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="note">Noch keine Audit-Events.</div>
              )}
            </div>
          </aside>
        </div>

        <div className="wb-dock">
          <Panel title="Completion-Gate">
            <div className="wb-pad">
              {!completion ? (
                <Note>Nicht verfügbar.</Note>
              ) : (
                <>
                  <Note>Fail-closed by design.</Note>
                  <div className="list" style={{ marginTop: 10 }}>
                    <div className="lrow" style={{ padding: "7px 0" }}>
                      can_set_all_to_100 <span className="meta"><Badge tone={completion.canSetAllTo100 ? "green" : "red"}>{String(completion.canSetAllTo100)}</Badge></span>
                    </div>
                    {completion.reason ? (
                      <div className="lrow" style={{ padding: "7px 0" }}>
                        reason <span className="meta">{completion.reason}</span>
                      </div>
                    ) : null}
                  </div>
                </>
              )}
            </div>
          </Panel>

          <Panel
            title="Workspace-Surfaces (22)"
            actions={
              <Badge tone={WORKSPACE_PAGES.length === 22 ? "green" : "amber"}>
                {WORKSPACE_PAGES.length}/22
              </Badge>
            }
          >
            <div className="wb-pad stack" style={{ gap: 14 }}>
              {Object.entries(pagesByLayer).map(([layer, pages]) => {
                const meta = layerMeta[layer];
                const layerNo = meta ? meta.no : 0;
                const layerColor = meta ? meta.color : "var(--text-mut)";
                return (
                  <div key={layer} className="panel" style={{ padding: 12, borderRadius: 12 }}>
                    <div className="lrow" style={{ padding: "2px 0", gap: 10 }}>
                      <span className="layer-tag" style={{ background: layerColor }}>
                        L{layerNo || "?"}
                      </span>
                      <span style={{ fontWeight: 600 }}>
                        {meta ? meta.label : layer}
                      </span>
                      <span className="meta mono">{layer}</span>
                      <span className="meta" style={{ marginLeft: "auto" }}>{pages?.length ?? 0}</span>
                    </div>
                    <div className="chips" style={{ marginTop: 10 }}>
                      {(pages ?? []).map((p) => (
                        <Link key={p.id} href={p.route} className="chip active">
                          {p.label}
                        </Link>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </Panel>
        </div>
      </div>
    </AppShell>
  );
}
