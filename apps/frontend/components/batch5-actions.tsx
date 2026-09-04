"use client";

import { useMemo, useState } from "react";
import { Icon } from "../lib/nav";
import { Panel, SafetyBadgeRow, Badge } from "./ui";

export type LocalTreeNode = { d: number; name: string; folder?: boolean };

export function LocalFilesInteractivePanel({ roots, tree }: { roots: string[]; tree: LocalTreeNode[] }) {
  const [root, setRoot] = useState(roots[0] ?? "project");
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState(tree.find((n) => !n.folder)?.name ?? tree[0]?.name ?? "");

  function persist(key: string, value: string) {
    try {
      localStorage.setItem(key, value);
    } catch {}
    try {
      sessionStorage.setItem(key, value);
    } catch {}
  }

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return tree;
    return tree.filter((n) => n.name.toLowerCase().includes(q));
  }, [query, tree]);

  const preview = useMemo(() => {
    if (!selected) return "No selection";
    const node = tree.find((n) => n.name === selected);
    const kind = node?.folder ? "folder" : "file";
    return [
      `selection=${selected}`,
      `kind=${kind}`,
      `root=${root}`,
      "mode=spec_only",
      "host_filesystem_mounted=false",
      "live_filesystem_reads=false",
      "provider_writes=false",
      "secret_output=false",
    ].join("\n");
  }, [root, selected, tree]);

  return (
    <div className="stack">
      <Panel title="Stammverzeichnis" className="mb-16" actions={<SafetyBadgeRow />}>
        <div className="wb-pad row wrap">
          <div className="chips">
            {roots.map((r) => (
              <button
                key={r}
                type="button"
                className={`chip${r === root ? " active" : ""}`}
                onClick={() => {
                  setRoot(r);
                  persist("files-local:root", r);
                  persist("files-local:last_root_change", String(Date.now()));
                }}
                aria-label={`Stammverzeichnis ${r}`}
              >
                {r}
              </button>
            ))}
          </div>
          <div className="ml-auto row">
            <button
              type="button"
              className="btn btn-sm btn-ghost"
              onClick={() => {
                setQuery("");
                persist("files-local:last_reset", String(Date.now()));
              }}
            >
              Suche zurücksetzen
            </button>
            <Badge tone="cyan">interaktiv · Spezifikation</Badge>
          </div>
        </div>
      </Panel>

      <div className="local-files-grid">
        <Panel title="Dateibaum (interaktive Spezifikation)">
          <div className="wb-pad tree">
            {(filtered.length ? filtered : tree).map((n, i) => (
              <button
                key={`${n.name}:${i}`}
                type="button"
                className={`tnode tnode-btn indent-${Math.min(6, Math.max(0, n.d))}${n.name === selected ? " sel" : ""}`}
                onClick={() => {
                  setSelected(n.name);
                  persist("files-local:selected", n.name);
                  persist("files-local:last_select", String(Date.now()));
                }}
              >
                {n.folder ? Icon.files({ size: 13 }) : Icon.docs({ size: 13 })}
                <span>{n.name}</span>
              </button>
            ))}
          </div>
        </Panel>

        <Panel title="Vorschau (Spezifikation)">
          <div className="wb-pad stack">
            <div className="row">
              <button
                type="button"
                className="btn btn-sm btn-primary"
                onClick={() => {
                  const op = navigator.clipboard?.writeText(preview);
                  if (op && typeof op.catch === "function") op.catch(() => undefined);
                  persist("files-local:last_copy", String(Date.now()));
                }}
                disabled={!selected}
              >
                Auswahl kopieren
              </button>
              <button
                type="button"
                className="btn btn-sm"
                onClick={() => {
                  setSelected("");
                  persist("files-local:last_clear", String(Date.now()));
                }}
              >
                Leeren
              </button>
            </div>
            <pre className="code">{preview}</pre>
          </div>
        </Panel>

        <Panel title="Suche (nur Spezifikation, lokaler Filter)">
          <div className="wb-pad stack">
            <div className="row local-search-row">
              <input
                className="local-search-input"
                aria-label="Projektbaum durchsuchen"
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  persist("files-local:query", e.target.value);
                }}
                placeholder="Baumknoten filtern…"
              />
              <button
                className="btn btn-sm"
                aria-label="Suche leeren"
                onClick={() => {
                  setQuery("");
                  persist("files-local:last_clear_search", String(Date.now()));
                }}
                disabled={!query}
              >
                {Icon.search({ size: 14 })}
              </button>
            </div>
            <div className="list">
              {(query ? filtered : []).slice(0, 8).map((n) => (
                <button key={n.name} type="button" className="lrow" onClick={() => setSelected(n.name)}>
                  {n.folder ? Icon.files({ size: 16 }) : Icon.docs({ size: 16 })}
                  <span className="lrow-title">{n.name}</span>
                  <span className="meta">auswählen</span>
                </button>
              ))}
              {query && !filtered.length ? (
                <div className="lrow muted-copy">Keine Ergebnisse<span className="meta">Spezifikation</span></div>
              ) : null}
              {!query ? (
                <div className="lrow muted-copy">Zum Filtern tippen…<span className="meta">nur lokal</span></div>
              ) : null}
            </div>
            <div className="muted-copy text-12">
              <span className="mono">.env</span>, <span className="mono">.git</span> und geheime Pfade werden nie angezeigt; Binärdateien erscheinen nur als Metadaten.
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}
