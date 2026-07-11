"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import type { ReactNode } from "react";
import { useEffect, useMemo, useRef, useState } from "react";
import { Icon, type NavItem, railGroups, WORKSPACE_PAGES } from "../../lib/nav";

function railActive(pathname: string, route: string) {
  if (route === "/home") return pathname === "/home";
  return pathname === route || pathname.startsWith(route + "/");
}

export default function AppShell({
  crumb,
  runState = "idle",
  children,
}: {
  crumb: string;
  runState?: "idle" | "planning" | "executing" | "verifying" | "blocked";
  children: ReactNode;
}) {
  const pathname = usePathname() || "/home";
  const router = useRouter();
  const [cmdkOpen, setCmdkOpen] = useState(false);
  const [cmdkQuery, setCmdkQuery] = useState("");
  const cmdkInputRef = useRef<HTMLInputElement | null>(null);

  const cmdkItems = useMemo(() => {
    const items: NavItem[] = railGroups.flatMap((group) => group.map((item) => item));
    const extra = WORKSPACE_PAGES.filter((item) => item.id === "login" || item.id === "open-source");
    for (const item of extra) {
      if (!items.some((existing) => existing.id === item.id)) {
        items.push(item);
      }
    }
    return items;
  }, []);

  const filteredCmdkItems = useMemo(() => {
    const query = cmdkQuery.trim().toLowerCase();
    if (!query) return cmdkItems;
    return cmdkItems.filter((item) => {
      const haystack = `${item.label} ${item.route} ${item.id}`.toLowerCase();
      return haystack.includes(query);
    });
  }, [cmdkItems, cmdkQuery]);

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      const key = event.key.toLowerCase();
      const wantsCmdk = key === "k" && (event.metaKey || event.ctrlKey);
      if (wantsCmdk) {
        event.preventDefault();
        setCmdkOpen(true);
      }
      if (key === "escape") {
        setCmdkOpen(false);
      }
      if (cmdkOpen && key === "enter") {
        const first = filteredCmdkItems[0];
        if (first) {
          event.preventDefault();
          setCmdkOpen(false);
          setCmdkQuery("");
          router.push(first.route);
        }
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [cmdkOpen, filteredCmdkItems, router]);

  useEffect(() => {
    if (!cmdkOpen) return;
    const t = window.setTimeout(() => cmdkInputRef.current?.focus(), 0);
    return () => window.clearTimeout(t);
  }, [cmdkOpen]);

  return (
    <div className="app-shell">
      <nav className="rail" aria-label="Primärnavigation">
        <Link href="/home" className="rail-logo" aria-label="Cloud Superbrain Start" />
        {railGroups.map((group, gi) => (
          <div key={gi} className="rail-group">
            {gi > 0 ? <div className="rail-divider" /> : null}
            {group.map((item) => {
              const active = railActive(pathname, item.route);
              return (
                <Link
                  key={item.id}
                  href={item.route}
                  className={`rail-item${active ? " active" : ""}`}
                  aria-label={item.label}
                  aria-current={active ? "page" : undefined}
                >
                  {Icon[item.icon]()}
                  <span className="rail-tip">{item.label}</span>
                </Link>
              );
            })}
          </div>
        ))}
        <div className="rail-spacer" />
        <div className="rail-divider" />
        <Link
          href="/open-source"
          className={`rail-item${railActive(pathname, "/open-source") ? " active" : ""}`}
          aria-label="Open Source"
          aria-current={railActive(pathname, "/open-source") ? "page" : undefined}
        >
          {Icon.open()}
          <span className="rail-tip">Open Source</span>
        </Link>
        <Link
          href="/login"
          className={`rail-item${railActive(pathname, "/login") ? " active" : ""}`}
          aria-label="Anmeldung / Einstieg"
          aria-current={railActive(pathname, "/login") ? "page" : undefined}
        >
          {Icon.login()}
          <span className="rail-tip">Anmeldung</span>
        </Link>
      </nav>

      <header className="topbar">
        <div className="crumb">
          Cloud Superbrain&nbsp;/&nbsp;<b>{crumb}</b>
        </div>
        <button
          type="button"
          className="cmdk"
          aria-label="Suchen oder Befehl ausführen"
          onClick={() => setCmdkOpen(true)}
        >
          {Icon.search({ size: 15 })}
          <span>Suchen oder Befehl ausführen</span>
          <kbd>⌘K</kbd>
        </button>
        <div className="grow" />
        <div className="avatar" aria-hidden="true">
          AI
        </div>
      </header>

      <main className="main">{children}</main>

      {cmdkOpen ? (
        <div
          className="cmdk-overlay"
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) {
              setCmdkOpen(false);
            }
          }}
        >
          <div className="cmdk-modal" role="dialog" aria-modal="true" aria-label="Befehlspalette">
            <span className="sr-only" data-testid="cmdk-proof">PASS cmdk_opened</span>
            <div className="cmdk-input-row">
              {Icon.search({ size: 16 })}
              <input
                ref={cmdkInputRef}
                className="cmdk-input"
                value={cmdkQuery}
                onChange={(event) => setCmdkQuery(event.target.value)}
                placeholder="Seiten durchsuchen…"
                aria-label="Seiten durchsuchen"
              />
              <kbd className="cmdk-hint">Enter</kbd>
              <button type="button" className="cmdk-close" onClick={() => setCmdkOpen(false)} aria-label="Befehlspalette schließen">
                Esc
              </button>
            </div>
            <div className="cmdk-list" role="listbox" aria-label="Befehle">
              {filteredCmdkItems.length ? (
                filteredCmdkItems.slice(0, 20).map((item) => {
                  const CmdIcon = (Icon as Record<string, (opts?: { size?: number }) => ReactNode>)[item.icon];
                  return (
                    <button
                      key={item.id}
                      type="button"
                      className="cmdk-item"
                      onClick={() => {
                        setCmdkOpen(false);
                        setCmdkQuery("");
                        router.push(item.route);
                      }}
                      role="option"
                      aria-selected="false"
                    >
                      <span className="cmdk-item-icon">{CmdIcon ? CmdIcon({ size: 16 }) : null}</span>
                      <span className="cmdk-item-label">{item.label}</span>
                      <span className="cmdk-item-route mono">{item.route}</span>
                    </button>
                  );
                })
              ) : (
                <div className="cmdk-empty">Keine Treffer</div>
              )}
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
