"use client";

import Link from "next/link";
import CortexLive from "../components/organism/CortexLive";
import { LAYERS, PROVIDERS, providersForLayer } from "../components/organism/regionMap";
import { Icon, SLOGAN } from "../lib/nav";

const FEATURES = [
  { icon: "open" as const, title: "Open Source First", body: "Transparent, auditable, community-driven. No vendor lock-in — use it and self-host freely." },
  { icon: "tools" as const, title: "Multi-Cloud Native", body: "Run anywhere, connect everything, deploy everywhere across a 7-layer architecture." },
  { icon: "organism" as const, title: "AI Developer Organism", body: "Agents, memory, tools and models that evolve with your work — a living cortex, not a wrapper." },
  { icon: "workbench" as const, title: "Workbench First", body: "Build · Create · Collaborate. Prompt to artifact, with honest run state and evidence." },
];

export default function Landing() {
  return (
    <div className="app-shell marketing">
      <header className="topbar marketing-topbar">
        <Link href="/" className="brandmark">
          <span className="glyph" />
          Cloud Superbrain
        </Link>
        <nav className="marketing-nav">
          <Link href="/workbench">Workbench</Link>
          <Link href="/organism">Organism</Link>
          <Link href="/tools">Tools</Link>
          <Link href="/marketplace">Marketplace</Link>
          <Link href="/about/open-source">Open Source</Link>
        </nav>
        <div className="grow" />
        <Link href="/login" className="btn btn-ghost btn-sm">
          Sign in
        </Link>
        <Link href="/workbench" className="btn btn-primary btn-sm">
          Open Workbench
        </Link>
      </header>

      <main className="main">
        <div className="page">
          <section className="hero">
            <div>
              <div className="chips" style={{ marginBottom: 16 }}>
                <span className="badge badge-cyan">Open Source</span>
                <span className="badge badge-violet">Independent</span>
                <span className="badge badge-green">Free</span>
                <span className="badge badge-mut">Multi-Cloud</span>
              </div>
              <h1>The Living Cloud Developer Organism</h1>
              <p>
                Build the world&apos;s first living, autonomous, multi-cloud developer platform.
                Think. Code. Orchestrate. Evolve — with a workbench-first surface and a real-time
                3D cortex that maps your runs.
              </p>
              <div className="hero-cta">
                <Link href="/login" className="btn btn-primary">
                  {Icon.bolt({ size: 16 })} Get Started Free
                </Link>
                <Link href="/home" className="btn">
                  Explore Platform
                </Link>
                <Link href="/docs-output" className="btn btn-ghost">
                  Docs
                </Link>
              </div>
            </div>
            <div className="hero-canvas">
              <CortexLive runState="planning" nodeCount={520} interactive={false} />
            </div>
          </section>

          <div className="hero-stats">
            <div className="stat"><div className="v">22</div><div className="l">Canonical pages</div></div>
            <div className="stat"><div className="v">7</div><div className="l">Cloud layers</div></div>
            <div className="stat"><div className="v">10</div><div className="l">Cortex regions</div></div>
            <div className="stat"><div className="v">100%</div><div className="l">Open source</div></div>
          </div>

          <div className="feature-grid">
            {FEATURES.map((f) => (
              <div key={f.title} className="feature">
                <div className="ico">{Icon[f.icon]({ size: 18 })}</div>
                <h3>{f.title}</h3>
                <p>{f.body}</p>
              </div>
            ))}
          </div>

          <section style={{ marginTop: 32 }}>
            <div className="page-head" style={{ marginBottom: 12 }}>
              <div>
                <div className="eyebrow">Architecture</div>
                <h2 style={{ fontSize: 20 }}>7 Layers · {PROVIDERS.length} Cloud Providers</h2>
              </div>
              <Link href="/about/stack" className="btn btn-sm btn-ghost">
                Technology stack →
              </Link>
            </div>
            <div className="layer-strip">
              {LAYERS.map((l) => (
                <div key={l.code} className="layer-row">
                  <span className="layer-tag" style={{ background: l.color }}>L{l.no}</span>
                  <span className="layer-name">{l.label}</span>
                  <span className="layer-providers">
                    {providersForLayer(l.no).map((p) => (
                      <span
                        key={p.id}
                        className="layer-chip"
                        style={{ color: p.color, borderColor: p.color }}
                        title={p.role}
                      >
                        {p.label}
                      </span>
                    ))}
                  </span>
                </div>
              ))}
            </div>
            <p style={{ fontSize: 12, color: "var(--text-dim)", marginTop: 10 }}>
              Each layer is backed by real cloud providers (Vercel · Hetzner · Cloudflare · GitHub ·
              GHCR · Hugging Face · GitLab · GitKraken). Tokens live under{" "}
              <span className="mono">.codex/secrets</span> — surfaced only as status
              (configured / verified / blocked), never printed.
            </p>
          </section>

          <footer className="footer-slogan">
            {SLOGAN.map((s) => (
              <span key={s}>{s}</span>
            ))}
            <span style={{ marginLeft: "auto", color: "var(--text-dim)" }}>
              Open · Independent · Free · Forever
            </span>
          </footer>
        </div>
      </main>
    </div>
  );
}
