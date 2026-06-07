import type { ReactNode } from "react";

/* ------------------------------------------------------------------
 * Icon set — Lucide-compatible, stroke 1.75, currentColor.
 * ------------------------------------------------------------------ */
type IconProps = { size?: number };

function svg(path: ReactNode, size = 18) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {path}
    </svg>
  );
}

export const Icon: Record<string, (p?: IconProps) => ReactNode> = {
  home: (p) => svg(<><path d="m3 11 9-8 9 8" /><path d="M5 10v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V10" /></>, p?.size),
  workbench: (p) => svg(<><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M9 3v18" /></>, p?.size),
  organism: (p) => svg(<><path d="M12 2a4 4 0 0 0-4 4 4 4 0 0 0-3 6.5A4 4 0 0 0 7 19a4 4 0 0 0 5 2 4 4 0 0 0 5-2 4 4 0 0 0 2-6.5A4 4 0 0 0 16 6a4 4 0 0 0-4-4Z" /><path d="M12 2v19" /></>, p?.size),
  agents: (p) => svg(<><circle cx="9" cy="7" r="3" /><path d="M3 21v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /><path d="M21 21v-2a4 4 0 0 0-3-3.87" /></>, p?.size),
  files: (p) => svg(<><path d="M4 20h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.7-.9l-.8-1.2A2 2 0 0 0 7.9 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" /></>, p?.size),
  filesLocal: (p) => svg(<><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><path d="M14 2v6h6" /><rect x="8" y="13" width="8" height="5" rx="1" /></>, p?.size),
  tools: (p) => svg(<><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" /></>, p?.size),
  marketplace: (p) => svg(<><path d="M3 9h18l-1.5 11a1 1 0 0 1-1 .9H5.5a1 1 0 0 1-1-.9z" /><path d="M16 9a4 4 0 0 0-8 0" /><path d="M3 9 5 4h14l2 5" /></>, p?.size),
  observe: (p) => svg(<><path d="M3 12h4l3 8 4-16 3 8h4" /></>, p?.size),
  evidence: (p) => svg(<><path d="M9 12l2 2 4-4" /><path d="M21 12c-1.5 4-5 7-9 7s-7.5-3-9-7c1.5-4 5-7 9-7s7.5 3 9 7Z" /></>, p?.size),
  settings: (p) => svg(<><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-2.92 1.17V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 7 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 2.6 14H2.5a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 8.4l-.06-.06A2 2 0 1 1 7.37 5.5l.06.06A1.65 1.65 0 0 0 9 5.6h.09A1.65 1.65 0 0 0 11 3.6V3a2 2 0 0 1 4 0v.09A1.65 1.65 0 0 0 17 5.6l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9v.09Z" /></>, p?.size),
  diagnostics: (p) => svg(<><path d="M2 12h4l2-7 4 14 2-7h8" /></>, p?.size),
  design: (p) => svg(<><circle cx="13.5" cy="6.5" r="2.5" /><circle cx="17.5" cy="11.5" r="2.5" /><circle cx="8.5" cy="7.5" r="2.5" /><circle cx="6.5" cy="12.5" r="2.5" /><path d="M12 22a5 5 0 0 1-5-5c0-1.5 1-2 2.5-2s2 .5 2.5 2 1 2 2 2a2 2 0 0 0 0-4" /></>, p?.size),
  stack: (p) => svg(<><path d="m12 2 9 5-9 5-9-5 9-5Z" /><path d="m3 12 9 5 9-5" /><path d="m3 17 9 5 9-5" /></>, p?.size),
  open: (p) => svg(<><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" /><path d="M15 3h6v6" /><path d="m10 14 11-11" /></>, p?.size),
  games: (p) => svg(<><rect x="2" y="6" width="20" height="12" rx="4" /><path d="M7 12h4M9 10v4" /><circle cx="16" cy="11" r="1" /><circle cx="18" cy="14" r="1" /></>, p?.size),
  media: (p) => svg(<><rect x="3" y="3" width="18" height="18" rx="2" /><circle cx="9" cy="9" r="2" /><path d="m21 15-5-5L5 21" /></>, p?.size),
  docs: (p) => svg(<><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><path d="M14 2v6h6" /><path d="M8 13h8M8 17h5" /></>, p?.size),
  apps: (p) => svg(<><rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" /><rect x="3" y="14" width="7" height="7" rx="1.5" /></>, p?.size),
  login: (p) => svg(<><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" /><path d="m10 17 5-5-5-5" /><path d="M15 12H3" /></>, p?.size),
  send: (p) => svg(<><path d="m22 2-7 20-4-9-9-4Z" /><path d="M22 2 11 13" /></>, p?.size),
  play: (p) => svg(<><polygon points="6 3 20 12 6 21 6 3" /></>, p?.size),
  search: (p) => svg(<><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></>, p?.size),
  shield: (p) => svg(<><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" /></>, p?.size),
  bolt: (p) => svg(<><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8Z" /></>, p?.size),
};

/* ------------------------------------------------------------------
 * Route registry — the canonical 22 pages + groups.
 * ------------------------------------------------------------------ */
export type NavItem = {
  id: string;
  no: number;
  label: string;
  route: string;
  icon: keyof typeof Icon;
  layer: "FE" | "ORC" | "AP" | "LLM" | "MCP" | "MEM" | "OBS";
};

/** Primary rail — workbench-first, evidence/diagnostics intentionally low. */
export const railGroups: NavItem[][] = [
  [
    { id: "home", no: 3, label: "Start", route: "/home", icon: "home", layer: "FE" },
    { id: "workbench", no: 4, label: "Werkbank", route: "/workbench", icon: "workbench", layer: "FE" },
    { id: "organism", no: 7, label: "Organismus", route: "/organism", icon: "organism", layer: "FE" },
    { id: "agents", no: 8, label: "Agenten", route: "/agents", icon: "agents", layer: "AP" },
    { id: "files", no: 6, label: "Dateien & Wissen", route: "/files", icon: "files", layer: "MEM" },
    { id: "files-local", no: 5, label: "Lokale Dateien (nur lesen)", route: "/files/local", icon: "filesLocal", layer: "MEM" },
    { id: "tools", no: 9, label: "Tools / Cloud-Hub", route: "/tools", icon: "tools", layer: "MCP" },
    { id: "marketplace", no: 10, label: "Marktplatz", route: "/marketplace", icon: "marketplace", layer: "LLM" },
    { id: "observe", no: 11, label: "Beobachten", route: "/observe", icon: "observe", layer: "OBS" },
  ],
  [
    { id: "games", no: 19, label: "Spiele", route: "/games", icon: "games", layer: "FE" },
    { id: "apps", no: 22, label: "Apps", route: "/apps", icon: "apps", layer: "FE" },
    { id: "media", no: 20, label: "Medien", route: "/media", icon: "media", layer: "FE" },
    { id: "docs-output", no: 21, label: "Dokumente", route: "/docs-output", icon: "docs", layer: "OBS" },
  ],
  [
    { id: "evidence", no: 12, label: "Nachweise", route: "/evidence", icon: "evidence", layer: "OBS" },
    { id: "diagnostics", no: 14, label: "Diagnose / Archiv", route: "/diagnostics", icon: "diagnostics", layer: "OBS" },
    { id: "design-system", no: 15, label: "Design System", route: "/design-system", icon: "design", layer: "FE" },
    { id: "stack", no: 17, label: "Technologie", route: "/technology", icon: "stack", layer: "ORC" },
    { id: "settings", no: 13, label: "Einstellungen", route: "/settings", icon: "settings", layer: "ORC" },
  ],
];

export const WORKSPACE_PAGES: NavItem[] = [
  ...railGroups.flat(),
  { id: "open-source", no: 18, label: "Open Source", route: "/open-source", icon: "open", layer: "FE" },
  { id: "login", no: 16, label: "Login / Onboarding", route: "/login", icon: "login", layer: "FE" },
  { id: "organism-map", no: 1, label: "Organismus · Karte", route: "/organism/map", icon: "organism", layer: "FE" },
  { id: "organism-replay", no: 2, label: "Organismus · Replay", route: "/organism/replay", icon: "evidence", layer: "OBS" },
];

export const SLOGAN = ["Bau alles.", "Automatisiere alles.", "Behalte Kontrolle."];
