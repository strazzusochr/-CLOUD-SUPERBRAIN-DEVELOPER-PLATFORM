"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { Panel } from "../components/ui";

type WorkspaceBuild = {
  id: string;
  title: string;
  created_at: string | null;
  updated_at: string | null;
  pinned?: boolean;
};

type WorkspaceState =
  | { kind: "loading" }
  | { kind: "anonymous" }
  | { kind: "unavailable" }
  | { kind: "ready"; builds: WorkspaceBuild[]; pinnedBuilds: WorkspaceBuild[] };

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

  useEffect(() => {
    // Defer the network state transition until after hydration. This avoids a
    // synchronous state transition during the effect commit while preserving
    // an actual request rather than a hard-coded empty state.
    const task = window.setTimeout(() => { void load(); }, 0);
    return () => window.clearTimeout(task);
  }, [load]);

  const setPinned = useCallback(async (build: WorkspaceBuild, pinned: boolean) => {
    const response = await fetch(`/api/v1/workspace/builds/${encodeURIComponent(build.id)}/pin`, {
      method: pinned ? "DELETE" : "PUT",
      headers: { accept: "application/json" },
      cache: "no-store",
    });
    if (response.ok) await load();
  }, [load]);

  const deleteBuild = useCallback(async (build: WorkspaceBuild) => {
    const response = await fetch(`/api/v1/workspace/builds/${encodeURIComponent(build.id)}`, {
      method: "DELETE",
      headers: { accept: "application/json" },
      cache: "no-store",
    });
    if (response.ok) {
      setConfirmingDelete(null);
      await load();
    }
  }, [load]);

  const recentContent = state.kind === "ready" && state.builds.length > 0
    ? (
      <div className="list home-workspace-list" data-testid="home-workspace-builds">
        {state.builds.map((build) => (
          <div className="lrow home-workspace-row" key={build.id}>
            <Link href={buildPath(build.id)} className="lrow-title" data-testid={`home-workspace-continue-${build.id}`}>{build.title}</Link>
            <span className="meta">{formatTimestamp(build.updated_at ?? build.created_at)}</span>
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              data-testid={`home-workspace-pin-${build.id}`}
              onClick={() => void setPinned(build, build.pinned === true)}
              aria-label={build.pinned ? `Anheftung von ${build.title} aufheben` : `${build.title} anheften`}
            >
              {build.pinned ? "★ Angeheftet" : "☆ Anheften"}
            </button>
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              data-testid={`home-workspace-delete-${build.id}`}
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
            <span className="meta">{formatTimestamp(build.updated_at ?? build.created_at)}</span>
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
      <Panel title="Eigene Arbeitsstände" className="home-workspace-panel" actions={<Link href="/workbench" className="btn btn-sm btn-ghost">Workbench öffnen →</Link>}>
        {recentContent}
      </Panel>
      <Panel title="Angeheftete Arbeitsstände" className="home-workspace-panel">
        {pinsContent}
      </Panel>
    </>
  );
}
