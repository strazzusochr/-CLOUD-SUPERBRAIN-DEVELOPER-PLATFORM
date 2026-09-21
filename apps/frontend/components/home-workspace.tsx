"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { Panel } from "../components/ui";

type WorkspaceBuild = {
  id: string;
  title: string;
  created_at: string | null;
  updated_at: string | null;
  last_used_at?: string | null;
  pinned?: boolean;
};

type WorkspaceState =
  | { kind: "loading" }
  | { kind: "anonymous" }
  | { kind: "unavailable" }
  | { kind: "ready"; builds: WorkspaceBuild[]; pinnedBuilds: WorkspaceBuild[] };

type AllWorkspaceState = { kind: "closed" } | { kind: "loading" } | { kind: "ready"; builds: WorkspaceBuild[]; nextCursor: string | null } | { kind: "error" };
type WorkspaceActionError = { kind: "pin" | "delete"; build: WorkspaceBuild; message: string };

function formatTimestamp(value: string | null): string {
  if (!value) return "Zeitpunkt nicht verfügbar";
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? "Zeitpunkt nicht verfügbar"
    : new Intl.DateTimeFormat("de-DE", { dateStyle: "medium", timeStyle: "short" }).format(date);
}

function buildPath(id: string): string {
  return `/workbench?build=${encodeURIComponent(id)}`;
}

function isWorkspacePayload(value: unknown): value is { builds: WorkspaceBuild[]; pinned_builds: WorkspaceBuild[] } {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const payload = value as Record<string, unknown>;
  return payload.contract_version === "github-workspace-builds-v1"
    && payload.status === "verified"
    && (payload.source === "cloudflare-d1" || payload.source === "postgres")
    && payload.identity_scope === "server_bound_workspace_subject"
    && payload.persisted === true
    && Array.isArray(payload.builds)
    && Array.isArray(payload.pinned_builds);
}

export function HomeWorkspace() {
  const [state, setState] = useState<WorkspaceState>({ kind: "loading" });
  const [confirmingDelete, setConfirmingDelete] = useState<string | null>(null);
  const [allState, setAllState] = useState<AllWorkspaceState>({ kind: "closed" });
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const [actionError, setActionError] = useState<WorkspaceActionError | null>(null);

  const load = useCallback(async () => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 10_000);
    try {
      const response = await fetch("/api/v1/workspace/builds/mine", {
        cache: "no-store",
        signal: controller.signal,
      });
      const payload = await response.json().catch(() => null);
      if (response.status === 401 || response.status === 403) {
        setState({ kind: "anonymous" });
        return;
      }
      if (!response.ok || !isWorkspacePayload(payload)) {
        setState({ kind: "unavailable" });
        return;
      }
      setState({
        kind: "ready",
        builds: payload.builds.slice(0, 4),
        pinnedBuilds: payload.pinned_builds,
      });
    } catch {
      setState({ kind: "unavailable" });
    } finally {
      window.clearTimeout(timeout);
    }
  }, []);

  const loadAll = useCallback(async () => {
    setAllState({ kind: "loading" });
    try {
      const response = await fetch("/api/v1/workspace/builds/mine/all?limit=100", { cache: "no-store" });
      const payload = await response.json().catch(() => null) as { builds?: WorkspaceBuild[]; next_cursor?: string | null } | null;
      if (!response.ok || !Array.isArray(payload?.builds)) {
        setAllState({ kind: "error" });
        return;
      }
      setAllState({ kind: "ready", builds: payload.builds, nextCursor: payload.next_cursor ?? null });
    } catch {
      setAllState({ kind: "error" });
    }
  }, []);

  useEffect(() => {
    // The first render is an honest loading state; defer the server-bound read
    // one turn so React can finish hydration before the state transition.
    const task = window.setTimeout(() => { void load(); }, 0);
    return () => window.clearTimeout(task);
  }, [load]);

  const setPinned = useCallback(async (build: WorkspaceBuild, pinned: boolean) => {
    setBusyAction(`pin:${build.id}`);
    setActionError(null);
    try {
      const response = await fetch(`/api/v1/workspace/builds/${encodeURIComponent(build.id)}/pin`, {
        method: pinned ? "DELETE" : "PUT",
        headers: { accept: "application/json" },
        cache: "no-store",
      });
      if (!response.ok) {
        setActionError({ kind: "pin", build, message: "Die Anheftung konnte nicht gespeichert werden." });
        return;
      }
      await load();
    } catch {
      setActionError({ kind: "pin", build, message: "Die Anheftung ist gerade nicht erreichbar." });
    } finally {
      setBusyAction(null);
    }
  }, [load]);

  const deleteBuild = useCallback(async (build: WorkspaceBuild) => {
    setBusyAction(`delete:${build.id}`);
    setActionError(null);
    try {
      const response = await fetch(`/api/v1/workspace/builds/${encodeURIComponent(build.id)}`, {
        method: "DELETE",
        headers: { accept: "application/json" },
        cache: "no-store",
      });
      if (!response.ok) {
        setActionError({ kind: "delete", build, message: "Der Arbeitsstand konnte nicht gelöscht werden." });
        return;
      }
      setConfirmingDelete(null);
      await load();
    } catch {
      setActionError({ kind: "delete", build, message: "Das Löschen ist gerade nicht erreichbar." });
    } finally {
      setBusyAction(null);
    }
  }, [load]);

  const recentContent = state.kind === "ready" && state.builds.length > 0
    ? (
      <div className="list home-workspace-list" data-testid="home-workspace-builds">
        {state.builds.map((build) => (
          <div className="lrow home-workspace-row" key={build.id}>
            <Link href={buildPath(build.id)} className="lrow-title" data-testid={`home-workspace-continue-${build.id}`}>{build.title}</Link>
            <span className="meta">{formatTimestamp(build.last_used_at ?? build.updated_at ?? build.created_at)}</span>
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              data-testid={`home-workspace-pin-${build.id}`}
              disabled={busyAction === `pin:${build.id}`}
              onClick={() => void setPinned(build, build.pinned === true)}
              aria-label={build.pinned ? `Anheftung von ${build.title} aufheben` : `${build.title} anheften`}
            >
              {build.pinned ? "★ Angeheftet" : "☆ Anheften"}
            </button>
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              data-testid={`home-workspace-delete-${build.id}`}
              disabled={busyAction === `delete:${build.id}`}
              onClick={() => {
                if (confirmingDelete === build.id) void deleteBuild(build);
                else setConfirmingDelete(build.id);
              }}
              aria-label={confirmingDelete === build.id ? `${build.title} wirklich löschen` : `${build.title} löschen`}
            >
              {confirmingDelete === build.id ? "Wirklich löschen" : "Löschen"}
            </button>
            {confirmingDelete === build.id && (
              <button type="button" className="btn btn-sm btn-ghost" data-testid={`home-workspace-cancel-delete-${build.id}`} onClick={() => setConfirmingDelete(null)}>
                Abbrechen
              </button>
            )}
          </div>
        ))}
      </div>
    )
    : state.kind === "ready"
      ? <div className="home-workspace-empty"><p>Noch keine eigenen Arbeitsstände — in der Workbench starten.</p></div>
      : state.kind === "anonymous"
        ? <div className="home-workspace-empty"><p>Mit GitHub anmelden, um eigene Arbeitsstände sicher fortzusetzen.</p></div>
        : state.kind === "loading"
          ? <div className="home-workspace-empty"><p>Eigene Arbeitsstände werden geladen.</p></div>
          : <div className="home-workspace-empty"><p>Eigene Arbeitsstände sind gerade nicht erreichbar.</p></div>;

  const pinsContent = state.kind === "ready" && state.pinnedBuilds.length > 0
    ? (
      <div className="list home-workspace-list" data-testid="home-workspace-pins">
        {state.pinnedBuilds.map((build) => (
          <div className="lrow home-workspace-row" key={build.id}>
            <Link href={buildPath(build.id)} className="lrow-title" data-testid={`home-workspace-continue-${build.id}`}>{build.title}</Link>
            <span className="meta">{formatTimestamp(build.last_used_at ?? build.updated_at ?? build.created_at)}</span>
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              data-testid={`home-workspace-pin-${build.id}`}
              onClick={() => void setPinned(build, true)}
              aria-label={`Anheftung von ${build.title} aufheben`}
            >
              ★ Aufheben
            </button>
          </div>
        ))}
      </div>
    )
    : state.kind === "ready"
      ? <div className="home-workspace-empty"><p>Keine angehefteten Arbeitsstände.</p></div>
      : state.kind === "anonymous"
        ? <div className="home-workspace-empty"><p>Mit GitHub anmelden, um eigene Anheftungen sicher zu sehen.</p></div>
        : state.kind === "loading"
          ? <div className="home-workspace-empty"><p>Angeheftete Arbeitsstände werden geladen.</p></div>
          : <div className="home-workspace-empty"><p>Angeheftete Arbeitsstände sind gerade nicht erreichbar.</p></div>;

  return (
    <>
      <Panel title="Eigene Arbeitsstände" className="home-workspace-panel" actions={<span className="home-workspace-actions"><button type="button" className="btn btn-sm btn-ghost" data-testid="home-workspace-all" onClick={() => void loadAll()}>{allState.kind === "closed" ? "Alle anzeigen" : "Gesamtansicht aktualisieren"}</button><Link href="/workbench" className="btn btn-sm btn-ghost">Workbench öffnen →</Link></span>}>
        {recentContent}
        {allState.kind === "loading" ? <p className="home-workspace-empty">Alle eigenen Arbeitsstände werden geladen.</p> : null}
        {allState.kind === "error" ? <p className="home-workspace-empty">Die Gesamtansicht ist gerade nicht erreichbar.</p> : null}
        {actionError ? (
          <div className="home-workspace-action-error" role="alert">
            <p>{actionError.message}</p>
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              onClick={() => actionError.kind === "pin"
                ? void setPinned(actionError.build, actionError.build.pinned === true)
                : void deleteBuild(actionError.build)}
            >
              Wiederholen
            </button>
          </div>
        ) : null}
        {busyAction ? (
          <p className="home-workspace-action-pending" role="status" data-testid="home-workspace-pending">
            Änderung wird gespeichert …
          </p>
        ) : null}
        {allState.kind === "ready" ? (
          <div className="list home-workspace-all-list" data-testid="home-workspace-all-builds">
            {allState.builds.map((build) => <Link href={buildPath(build.id)} className="lrow-title" key={`all-${build.id}`}>{build.title}</Link>)}
            {allState.builds.length === 0 ? <p className="home-workspace-empty">Keine eigenen Arbeitsstände.</p> : null}
            {allState.nextCursor ? <span className="meta">Weitere eigene Arbeitsstände sind verfügbar.</span> : null}
          </div>
        ) : null}
      </Panel>
      <Panel title="Angeheftete Arbeitsstände" className="home-workspace-panel">
        {pinsContent}
      </Panel>
    </>
  );
}
