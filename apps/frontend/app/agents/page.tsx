import AppShell from "../../components/shell/AppShell";
import { PageHeader, Panel, Badge, Metric, SpecModeBadge, StatusDot } from "../../components/ui";
import { AGENTS } from "../../lib/platform";
import { AgentRun } from "../../components/agent-run";
import { fetchAgentRoster, fetchCodingTeam, fetchMasterPlan } from "../../lib/agentApi";

export const dynamic = "force-dynamic";
export const metadata = { title: "Agenten — Cloud Superbrain" };

type SearchParams = Record<string, string | string[] | undefined>;
type AgentsPageProps = { searchParams?: Promise<SearchParams> };

// Multi-agent research through the Agent API and LLM Gateway boundaries.
export default async function AgentsPage({ searchParams }: AgentsPageProps) {
  const dispatchParam = (searchParams ? await searchParams : {}).dispatch_id;
  const dispatchId = typeof dispatchParam === "string"
    ? dispatchParam
    : dispatchParam === undefined
      ? undefined
      : null;
  const [roster, masterPlan, codingTeam] = await Promise.all([
    fetchAgentRoster(),
    fetchMasterPlan(),
    fetchCodingTeam(dispatchId),
  ]);
  const runtimeVisible = !!(roster && masterPlan && codingTeam);
  const phaseEntries = Object.entries(masterPlan?.phasePercentages ?? {});
  const layerEntries = Object.entries(masterPlan?.layerPercentages ?? {});

  return (
    <AppShell crumb="Agenten" runState="idle">
      <div className="page-wide">
        <PageHeader
          eyebrow="Agenten"
          title="Tiefenrecherche mit mehreren Agenten"
          subtitle="Gib ein Ziel ein. Bei erreichbarer Agent API arbeiten Planner, Researcher und Writer zusammen; ohne Laufzeit bleibt der Auftrag fail-closed."
          actions={<SpecModeBadge mode={runtimeVisible ? "read_only_redacted" : "spec_only"} />}
        />

        <div className="grid cols-3 mb-16">
          <div
            style={{ minWidth: 0 }}
            data-testid="autonomous-agent-roster"
            data-contract-version={roster?.contractVersion ?? "unavailable"}
            data-status={roster?.status ?? "unavailable"}
            data-source-document={roster?.sourceDocument ?? "unavailable"}
            data-role-count={roster?.roles.length ?? 0}
          >
            <Panel
              title="Persisted Agent Roster"
              pad
              actions={<Badge tone={roster ? "green" : "amber"}>{roster?.status ?? "unavailable"}</Badge>}
            >
              <Metric
                label="Persistierte Rollen"
                value={roster ? roster.roleCount : "—"}
                foot={roster?.sourceDocument ?? "Agent API nicht erreichbar"}
              />
              <p className="text-12 text-mut mt-12">
                GET /api/v1/team/roster · Contract {roster?.contractVersion ?? "unavailable"} · Evidence{" "}
                {roster?.evidenceRef ?? "unavailable"}
              </p>
              <p className="text-12 text-mut mt-12">
                Startbar: {roster?.validatedAgentTypes.join(" · ") || "nicht verifiziert"} · LangGraph{" "}
                {roster?.langGraphStatus ?? "unbekannt"} · Metrics {roster?.metricsStatus ?? "unbekannt"}
              </p>
              <div className="chips mt-12" data-testid="persisted-agent-roster-roles">
                {(roster?.roles ?? []).map((role) => (
                  <Badge key={role.id} tone={role.status === "launch-validated" ? "green" : "amber"}>
                    {role.id} · {role.status} · Fallback {role.fallbackAgentTypes.join("/") || "none"}
                  </Badge>
                ))}
              </div>
            </Panel>
          </div>

          <div
            style={{ minWidth: 0 }}
            data-testid="autonomous-master-plan"
            data-contract-version={masterPlan?.contractVersion ?? "unavailable"}
            data-source-document={masterPlan?.sourceDocument ?? "unavailable"}
            data-integrity-status={masterPlan?.integrityStatus ?? "unavailable"}
            data-overall-percent={masterPlan?.overallPercent ?? -1}
            data-logical-role-count={masterPlan?.logicalRoles.length ?? 0}
            data-phase-count={phaseEntries.length}
            data-layer-count={layerEntries.length}
          >
            <Panel
              title="Autonomous Master Plan"
              pad
              actions={<Badge tone={masterPlan?.integrityStatus === "verified" ? "green" : "amber"}>{masterPlan?.integrityStatus ?? "unavailable"}</Badge>}
            >
              <Metric
                label="Kanonischer Fortschritt"
                value={masterPlan ? `${masterPlan.overallPercent}%` : "—"}
                foot={masterPlan?.sourceDocument ?? "Agent API nicht erreichbar"}
              />
              <p className="text-12 text-mut mt-12">
                GET /api/v1/team/master-plan · Contract {masterPlan?.contractVersion ?? "unavailable"} · Manifest{" "}
                {masterPlan?.progressManifest ?? "unavailable"} · Evidence {masterPlan?.evidenceRef ?? "unavailable"}
              </p>
              <p className="text-12 text-mut mt-12">
                {masterPlan
                  ? `${masterPlan.logicalRoles.length} logische Rollen · ${masterPlan.runtimeSource ?? "unknown"}`
                  : "Kein Runtime-Plan geladen."}
              </p>
              <p className="text-12 text-mut mt-12">Phasen</p>
              <div className="chips mt-12" data-testid="autonomous-master-plan-phases">
                {phaseEntries.map(([id, percent]) => <Badge key={id}>{id} · {percent}%</Badge>)}
              </div>
              <p className="text-12 text-mut mt-12">Schichten</p>
              <div className="chips mt-12" data-testid="autonomous-master-plan-layers">
                {layerEntries.map(([id, percent]) => <Badge key={id}>{id} · {percent}%</Badge>)}
              </div>
            </Panel>
          </div>

          <div
            style={{ minWidth: 0 }}
            data-testid="autonomous-coding-team"
            data-contract-version={codingTeam?.contractVersion ?? "unavailable"}
            data-status={codingTeam?.status ?? "unavailable"}
            data-team-mode={codingTeam?.teamMode ?? "unavailable"}
            data-runtime-source={codingTeam?.runtimeSource ?? "unavailable"}
            data-dispatch-id={codingTeam?.dispatchId ?? "none"}
            data-member-count={codingTeam?.members.length ?? 0}
            data-queue-depth={codingTeam?.queueDepth ?? 0}
          >
            <Panel
              title="Autonomous Coding Team"
              pad
              actions={<Badge tone={codingTeam ? "green" : "amber"}>{codingTeam?.status ?? "unavailable"}</Badge>}
            >
              <Metric
                label="Queue"
                value={codingTeam ? codingTeam.queueDepth : "—"}
                foot={codingTeam?.teamMode || "Agent API nicht erreichbar"}
              />
              <p className="text-12 text-mut mt-12">
                GET /api/v1/team/status · Contract {codingTeam?.contractVersion ?? "unavailable"} · Evidence{" "}
                autonomous_team_status_runtime_visible · Source {codingTeam?.runtimeSource ?? "unavailable"} · Dispatch{" "}
                {codingTeam?.dispatchId ?? "none"}
              </p>
              <div className="chips mt-12" data-testid="autonomous-coding-team-priority-queues">
                {(["high", "mid", "low"] as const).map((priority) => (
                  <Badge key={priority}>
                    {priority} · {codingTeam?.queueDepthByPriority[priority] ?? 0}
                  </Badge>
                ))}
              </div>
              <div className="chips mt-12" data-testid="autonomous-coding-team-members">
                {(codingTeam?.members ?? []).map((member) => (
                  <span
                    key={member.logicalRole}
                    data-testid="autonomous-coding-team-member"
                    data-logical-role={member.logicalRole}
                    data-execution-agent-type={member.executionAgentType}
                    data-status={member.status}
                  >
                    <Badge
                      tone={member.status === "failed" || member.status === "unavailable" ? "red" : member.status === "idle" ? "mut" : "cyan"}
                    >
                      <StatusDot tone={member.status === "failed" || member.status === "unavailable" ? "red" : member.status === "idle" ? "mut" : "cyan"} />
                      {member.logicalRole} → {member.executionAgentType} · {member.status} · {member.priorityQueue ?? "keine Queue"}
                    </Badge>
                  </span>
                ))}
              </div>
            </Panel>
          </div>
        </div>

        <div className="note mb-16" data-testid="autonomous-agent-safety-non-claims">
          <p>DEV-ONLY; hosted proof still blocked</p>
          <div className="chips mt-12">
            <Badge tone="green">live_provider_calls=false</Badge>
            <Badge tone="green">live_mcp_writes=false</Badge>
            <Badge tone="green">model_downloads=false</Badge>
            <Badge tone="green">production_deploy=false</Badge>
            <Badge tone="green">production_rollout_claimed=false</Badge>
            <Badge tone="green">secret_output=false</Badge>
          </div>
          <p className="text-12 text-mut mt-12">
            Persistierte Roster-Daten bedeuten nicht, dass Codex-Desktop-Threads einen Neustart überleben.
          </p>
        </div>

        <Panel title="Tiefenrecherche starten" className="mb-16" actions={<Badge tone="cyan">Agent API · gated</Badge>}>
          <div className="wb-pad">
            <AgentRun />
          </div>
        </Panel>

        <Panel title="Das Agenten-Team (Zielarchitektur)" actions={<Badge tone="cyan">{AGENTS.length} Rollen · Plan</Badge>}>
          <div className="grid cols-2">
            {AGENTS.map((a) => (
              <div key={a.type} className="agent-team-card">
                <div className="agent-head">
                  <span className="agent-type">{a.type}</span>
                  <span className="agent-model mono text-12 text-mut" title="Ziel-Modell laut Orchestrator-Plan — nicht der aktuell aktive Provider">Ziel: {a.model}</span>
                </div>
                <p className="agent-role">{a.role}</p>
              </div>
            ))}
          </div>
        </Panel>
      </div>
    </AppShell>
  );
}
