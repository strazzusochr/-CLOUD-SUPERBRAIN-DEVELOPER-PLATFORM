"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { Icon, railGroups } from "../../lib/nav";

function railActive(pathname: string, route: string) {
  if (route === "/home") return pathname === "/home";
  if (route === "/files") return pathname === "/files";
  if (route === "/files/local") return pathname.startsWith("/files/local");
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

  return (
    <div className="app-shell">
      <nav className="rail" aria-label="Primary">
        <Link href="/" className="rail-logo" aria-label="Cloud Superbrain home" />
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
        <Link href="/about/open-source" className="rail-item" aria-label="Open by Design">
          {Icon.open()}
          <span className="rail-tip">Open by Design</span>
        </Link>
        <Link href="/login" className="rail-item" aria-label="Login / Onboarding">
          {Icon.login()}
          <span className="rail-tip">Login</span>
        </Link>
      </nav>

      <header className="topbar">
        <div className="crumb">
          Cloud Superbrain&nbsp;/&nbsp;<b>{crumb}</b>
        </div>
        <div className="cmdk" role="search">
          {Icon.search({ size: 15 })}
          <span>Search or run a command</span>
          <kbd>⌘K</kbd>
        </div>
        <div className="grow" />
        <span className="runpill" title="Active run state">
          <span className="dot pulse" style={{ background: runColor[runState] }} />
          {runState.toUpperCase()}
        </span>
        <span className="badge badge-mut" title="All write/deploy gates closed">
          {Icon.shield({ size: 13 })} Gates: CLOSED
        </span>
        <div className="avatar" aria-hidden="true">
          AI
        </div>
      </header>

      <main className="main">{children}</main>
    </div>
  );
}
