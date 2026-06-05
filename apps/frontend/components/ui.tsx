import type { ReactNode } from "react";

/* ------------------------------------------------------------------
 * Atoms & molecules — server-safe (no client hooks).
 * NeuroGlass tokens only. No color-only status (icon/text always).
 * ------------------------------------------------------------------ */

type Tone = "mut" | "cyan" | "green" | "amber" | "red" | "violet";

export function Badge({ tone = "mut", children }: { tone?: Tone; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

/** Honest source/state badge — mandatory when data is not live. */
export function SpecModeBadge({
  mode,
}: {
  mode: "live" | "read_only_redacted" | "spec_only" | "demo" | "blocked" | "planned" | "local_files";
}) {
  const map: Record<string, { tone: Tone; label: string }> = {
    live: { tone: "green", label: "● Live" },
    read_only_redacted: { tone: "cyan", label: "◆ Read-only (redacted)" },
    local_files: { tone: "cyan", label: "◆ Local files" },
    spec_only: { tone: "amber", label: "◇ Spec-only" },
    planned: { tone: "violet", label: "◇ Planned" },
    demo: { tone: "violet", label: "◇ Demo" },
    blocked: { tone: "red", label: "▣ Blocked" },
  };
  const m = map[mode] ?? map.spec_only;
  return <Badge tone={m.tone}>{m.label}</Badge>;
}

export function SafetyBadgeRow() {
  return (
    <div className="safety-row">
      <Badge tone="cyan">read_only_redacted</Badge>
      <Badge tone="green">secret_output = false</Badge>
      <Badge tone="green">writes = false</Badge>
      <Badge tone="mut">path_traversal_blocked</Badge>
    </div>
  );
}

export function StatusDot({ tone = "mut", pulse = false, label }: { tone?: Tone; pulse?: boolean; label?: string }) {
  const colors: Record<Tone, string> = {
    mut: "var(--text-mut)",
    cyan: "var(--cyan)",
    green: "var(--green)",
    amber: "var(--amber)",
    red: "var(--red)",
    violet: "var(--violet)",
  };
  return (
    <span
      className={`dot${pulse ? " pulse" : ""}`}
      style={{ background: colors[tone] }}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    />
  );
}

export function PageHeader({
  eyebrow,
  title,
  subtitle,
  actions,
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <header className="page-head">
      <div>
        {eyebrow ? <div className="eyebrow">{eyebrow}</div> : null}
        <h1>{title}</h1>
        {subtitle ? <p>{subtitle}</p> : null}
      </div>
      {actions ? <div className="head-actions">{actions}</div> : null}
    </header>
  );
}

export function Panel({
  title,
  actions,
  children,
  pad = false,
  className = "",
  style,
}: {
  title?: string;
  actions?: ReactNode;
  children: ReactNode;
  pad?: boolean;
  className?: string;
  style?: React.CSSProperties;
}) {
  return (
    <section className={`panel ${className}`} style={style}>
      {title ? (
        <div className="panel-head">
          <span className="panel-title">{title}</span>
          {actions}
        </div>
      ) : null}
      <div className={pad ? "panel-pad" : ""}>{children}</div>
    </section>
  );
}

export function Metric({
  label,
  value,
  foot,
}: {
  label: string;
  value: ReactNode;
  foot?: ReactNode;
}) {
  return (
    <div className="metric">
      <span className="label">{label}</span>
      <span className="value">{value}</span>
      {foot ? <span className="foot">{foot}</span> : null}
    </div>
  );
}

export function EmptyState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty">
      <h3>{title}</h3>
      <p>{body}</p>
      {action}
    </div>
  );
}

export function Note({
  variant = "info",
  children,
}: {
  variant?: "info" | "warn" | "blocked";
  children: ReactNode;
}) {
  const cls = variant === "info" ? "note" : `note ${variant}`;
  return <div className={cls}>{children}</div>;
}

export function Bar({ pct }: { pct: number }) {
  return (
    <div className="bar">
      <span style={{ width: `${Math.max(0, Math.min(100, pct))}%` }} />
    </div>
  );
}
