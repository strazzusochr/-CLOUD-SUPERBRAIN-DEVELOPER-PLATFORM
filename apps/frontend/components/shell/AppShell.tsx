"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { Icon, railGroups } from "../../lib/nav";
import LayerVerifyPill from "./LayerVerifyPill";

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

  const runColor: Record<string, string> = {
    idle: "var(--blue)",
    planning: "var(--cyan)",
    executing: "var(--blue)",
    verifying: "var(--green)",
    blocked: "var(--red)",
  };

  const runLabel: Record<string, string> = {
    idle: "RUHE",
    planning: "PLANUNG",
    executing: "AUSFÜHRUNG",
    verifying: "PRÜFUNG",
    blocked: "BLOCKIERT",
  };

  return (
    <div className="app-shell">
      <nav className="rail" aria-label="Primär">
        <Link href="/home" className="rail-logo" aria-label="Cloud Superbrain Start" />
        {railGroups.map((group, gi) => (
          <div key={gi} style={{ display: "contents" }}>
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
          aria-label="Login / Onboarding"
          aria-current={railActive(pathname, "/login") ? "page" : undefined}
        >
          {Icon.login()}
          <span className="rail-tip">Login</span>
        </Link>
      </nav>

      <header className="topbar">
        <div className="crumb">
          Cloud Superbrain&nbsp;/&nbsp;<b>{crumb}</b>
        </div>
        <span className="topbar-chip" title="Projektkontext">
          {Icon.workbench({ size: 14 })} Superbrain Platform
        </span>
        <span className="topbar-chip" title="Cloud-only Zielumgebung">
          {Icon.stack({ size: 14 })} Vercel/Fly
        </span>
        <div className="cmdk" role="search">
          {Icon.search({ size: 15 })}
          <span>Suchen oder Kommando ausführen</span>
          <kbd>⌘K</kbd>
        </div>
        <div className="grow" />
        <LayerVerifyPill />
        <span className="runpill" title="Aktueller Run-Status">
          <span className="dot pulse" style={{ background: runColor[runState] }} />
          {runLabel[runState]}
        </span>
        <span className="topbar-chip safe" title="Keine Provider-Writes, keine Secrets, kein Production Deploy">
          {Icon.shield({ size: 13 })} Read-only safe
        </span>
        <div className="avatar" aria-hidden="true">
          AI
        </div>
      </header>

      <main className="main">{children}</main>
    </div>
  );
}
