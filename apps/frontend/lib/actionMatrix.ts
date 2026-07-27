/**
 * Canonical page-local action inventory for the 22 workspace routes.
 *
 * This is an evidence registry, not an optimistic feature list:
 * - PASS means a named current browser evidence source exists, but the
 *   22-page acceptance still has to exercise every enabled action directly.
 * - GAP means the control is mounted, but its effect is not covered by one of
 *   those sources yet.
 * - disabled owner/provider gates are excluded from page-local actions and
 *   listed separately in `excludedGates`.
 * - AppShell navigation is inventoried separately from page-local actions.
 */

export const ACTION_MATRIX_CONTRACT_VERSION = "workspace-action-matrix-v2" as const;

export type ActionEvidenceSource = "product-acceptance" | "organism" | "goal-b" | "browser spec" | "22-page-actions";
export type ActionStatus = "PASS" | "GAP";
export type ActionAvailability = "enabled" | "spec_only" | "contract_only" | "provider_gated" | "conditional";
export type ActionVerificationMode = "interactive" | "preverified_exact_control" | "provider_gated" | "conditional";

export type ActionEvidence = {
  source: ActionEvidenceSource;
  anchor: string;
};

export type ActionMember = {
  id: string;
  label: string;
  locator: string;
  precondition: string;
  expectedEffect: string;
  effectLocator: string;
  requireEffectDelta?: true;
  availability: ActionAvailability;
  enabled: boolean;
  verificationMode: ActionVerificationMode;
  evidence: readonly ActionEvidence[];
  status: ActionStatus;
  gapReason?: string;
};

export type ActionFamily = {
  id: string;
  label: string;
  locator: string;
  precondition: string;
  expectedEffect: string;
  evidence: readonly ActionEvidence[];
  status: ActionStatus;
  memberActions: readonly ActionMember[];
};

export type ExcludedGate = {
  id: string;
  label: string;
  locator: string;
  reason: string;
};

export type CanonicalActionRoute =
  | "/home"
  | "/login"
  | "/workbench"
  | "/organism"
  | "/organism/replay"
  | "/organism/map"
  | "/agents"
  | "/files"
  | "/files/local"
  | "/tools"
  | "/marketplace"
  | "/observe"
  | "/games"
  | "/apps"
  | "/media"
  | "/docs-output"
  | "/evidence"
  | "/diagnostics"
  | "/design-system"
  | "/technology"
  | "/settings"
  | "/open-source";

export type PageActionEntry = {
  route: CanonicalActionRoute;
  title: string;
  families: readonly ActionFamily[];
  excludedGates: readonly ExcludedGate[];
  zeroPageLocalReason?: string;
};

const NO_CURRENT_EVIDENCE =
  "No named current product-acceptance, organism, goal-b, or browser-spec assertion proves this effect.";

function evidence(source: ActionEvidenceSource, anchor: string): ActionEvidence {
  return { source, anchor };
}

function member(
  id: string,
  label: string,
  locator: string,
  precondition: string,
  expectedEffect: string,
  effectLocator: string,
  availability: ActionAvailability = "enabled",
  proof: readonly ActionEvidence[] = [],
  verificationMode?: ActionVerificationMode,
): ActionMember {
  return {
    id,
    label,
    locator,
    precondition,
    expectedEffect,
    effectLocator,
    availability,
    enabled: availability === "enabled",
    verificationMode: verificationMode ??
      (availability === "provider_gated"
        ? "provider_gated"
        : availability === "conditional" || availability === "spec_only" || availability === "contract_only"
          ? "conditional"
          : "interactive"),
    evidence: proof,
    status: proof.length ? "PASS" : "GAP",
    ...(proof.length ? {} : { gapReason: NO_CURRENT_EVIDENCE }),
  };
}

function family(
  id: string,
  label: string,
  precondition: string,
  expectedEffect: string,
  memberActions: readonly ActionMember[],
): ActionFamily {
  const proof = memberActions.flatMap((action) => action.evidence);
  const allPass = memberActions.length > 0 && memberActions.every((action) => action.status === "PASS");
  return {
    id,
    label,
    locator: memberActions.map((action) => action.locator).join(", "),
    precondition,
    expectedEffect,
    evidence: proof.filter(
      (candidate, index) =>
        proof.findIndex((item) => item.source === candidate.source && item.anchor === candidate.anchor) === index,
    ),
    status: allPass ? "PASS" : "GAP",
    memberActions,
  };
}

const PRODUCT_LOGIN = evidence(
  "product-acceptance",
  "apps/frontend/e2e/product-acceptance.spec.ts::real prompt builds, runs, interacts, and reloads the persisted 3D game (guest sign-in)",
);
const PRODUCT_WORKBENCH = evidence(
  "product-acceptance",
  "apps/frontend/e2e/product-acceptance.spec.ts::real prompt builds, runs, interacts, and reloads the persisted 3D game (workbench build/result)",
);
const GOAL_WORKBENCH = evidence(
  "goal-b",
  "apps/frontend/e2e/goal-b-action-to-result.spec.ts::workbench run creates visible runtime result and artifact",
);
const GOAL_AGENTS = evidence(
  "goal-b",
  "apps/frontend/e2e/goal-b-action-to-result.spec.ts::agents produce a visible real multi-agent result",
);
const GOAL_FILES = evidence(
  "goal-b",
  "apps/frontend/e2e/goal-b-action-to-result.spec.ts::files search returns real memory hits created by artifact registry",
);
const GOAL_TOOLS = evidence(
  "goal-b",
  "apps/frontend/e2e/goal-b-action-to-result.spec.ts::tools execute only read-only tool envelope with audit id",
);
const GOAL_MARKET_DETAILS = evidence(
  "goal-b",
  "apps/frontend/e2e/goal-b-action-to-result.spec.ts::marketplace details and install dry-run create visible artifact plan (details)",
);
const GOAL_MARKET_INSTALL = evidence(
  "goal-b",
  "apps/frontend/e2e/goal-b-action-to-result.spec.ts::marketplace details and install dry-run create visible artifact plan (install dry-run)",
);
const GOAL_DOCS = evidence(
  "goal-b",
  "apps/frontend/e2e/goal-b-action-to-result.spec.ts::docs studio creates a real Markdown download",
);
const ORGANISM_CONTROLS = evidence(
  "organism",
  "apps/frontend/e2e/organism.spec.ts::organism Phase-6 3D controls/camera/lighting and bounded local state",
);
const ORGANISM_GAMEPLAY = evidence(
  "organism",
  "apps/frontend/e2e/organism.spec.ts::organism Phase-6 gameplay/save-load/accessibility local contracts",
);
const ORGANISM_NETCODE = evidence(
  "organism",
  "apps/frontend/e2e/organism.spec.ts::organism Phase-6 loopback netcode and local scoreboard/performance",
);
const ORGANISM_REPLAY = evidence(
  "organism",
  "apps/frontend/e2e/organism.spec.ts::organism UI renders redaction-aware runtime feed and replay surface",
);
const ORGANISM_RUN_ID = evidence(
  "organism",
  "apps/frontend/e2e/organism.spec.ts::organism runtime feed forwards run_id to events and replay APIs",
);
const ORGANISM_TOPOLOGY = evidence(
  "organism",
  "scripts/verify-organism-topology.ps1::organism_topology_visible",
);
const BROWSER_COMMAND_PALETTE = evidence(
  "browser spec",
  "scripts/verify-workspace-responsive-browser.cjs::22 routes x desktop/mobile command-palette navigation",
);

const liveConsoleMembers = (prefix: string): readonly ActionMember[] => {
  return [
    member(`${prefix}-endpoint`, "Select endpoint", `.live-console select`, "More than one endpoint is configured.", "Selected read-only endpoint changes.", ".live-console select"),
    member(`${prefix}-load`, "Load endpoint", `[data-testid="live-console-load"]`, "The selected endpoint is reachable or fails honestly.", "Visible status, response metadata and response body update.", ".lc-status, .lc-meta, .lc-out"),
    member(`${prefix}-copy`, "Copy console output", `.live-console button:has-text("Kopieren")`, "Console output exists and Clipboard API is available.", "Current output is written to the clipboard.", ".lc-out"),
  ] as const;
};

const organismControlMembers: readonly ActionMember[] = [
  member("organism-run-filter", "Filter run state", `[data-testid^="organism-run-state-"]`, "Organism contract is loaded.", "Visible nodes are filtered by the selected run state.", `[data-testid="batch1-organism-action-result"]`),
  member("organism-auto-rotate", "Toggle automatic rotation", `.organism-scene-bar button:has-text("Automatisch drehen")`, "3D canvas is available.", "Canvas auto-rotation toggles without a network request.", `[data-testid="phase6-camera-lighting-state"]`, "enabled", [ORGANISM_CONTROLS]),
  member("organism-camera-reset", "Reset camera", `button[title="R"]`, "3D or accessible scene is mounted.", "Camera returns to the bounded selected preset.", `[data-testid="phase6-camera-lighting-state"]`, "enabled", [ORGANISM_CONTROLS]),
  member("organism-reduced-motion", "Toggle reduced motion", `[data-testid="phase6-reduced-motion-toggle"]`, "Organism surface is mounted.", "3D/2D presentation changes and state remains browser-local.", ".org-hud", "enabled", [ORGANISM_CONTROLS]),
  member("organism-camera-preset", "Select camera preset", `[data-testid^="phase6-camera-preset-"]`, "3D canvas is available.", "Camera preset and position attributes change within contract bounds.", `[data-testid="phase6-camera-lighting-state"]`, "enabled", [ORGANISM_CONTROLS]),
  member("organism-camera-fov", "Select field of view", `[data-testid="phase6-camera-fov"]`, "3D canvas is available.", "Canvas FOV changes to a safe contract value.", `.cortex-wrap`, "enabled", [ORGANISM_CONTROLS]),
  member("organism-light-profile", "Select lighting profile", `[data-testid^="phase6-lighting-profile-"]`, "3D canvas is available.", "Lighting profile and exposure update locally.", `[data-testid="phase6-camera-lighting-state"]`, "enabled", [ORGANISM_CONTROLS]),
  member("organism-light-exposure", "Adjust exposure", `[data-testid="phase6-lighting-exposure"]`, "3D canvas is available.", "Exposure stays within the safe contract range.", `[data-testid="phase6-camera-lighting-state"]`, "enabled", [ORGANISM_CONTROLS]),
  member("organism-layer-filter", "Toggle architecture layer", `.layer-chip`, "Organism contract has layers.", "Layer visibility/filter state changes.", `[data-testid="batch1-organism-action-result"]`),
  member("organism-agent-filter", "Toggle agent", `.organism-filters-row .filter-chip:not(.layer-chip)`, "Organism contract has agents.", "Agent visibility/filter state changes.", `[data-testid="batch1-organism-action-result"]`),
  member("organism-hub-select", "Select hub", `.lg-row`, "Organism contract has hubs.", "Selected hub details and route link update.", ".organism-hub-title"),
  member("organism-hub-open", "Open selected hub", `.stack section.panel.panel-pad a.btn.mt-12`, "A hub with a route is selected.", "Browser navigates to the selected workspace hub.", "main"),
];

const organismGameplayMembers: readonly ActionMember[] = [
  member("organism-gameplay-complete", "Complete objective", `[data-testid="phase6-gameplay-complete"]`, "Gameplay is not paused.", "Objective, score, checkpoint and completion state advance deterministically.", `[data-testid="phase6-gameplay-state"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-gameplay-pause", "Pause or resume gameplay", `[data-testid="phase6-gameplay-pause"]`, "Gameplay controls are mounted.", "Paused state toggles and blocks objective completion.", `[data-testid="phase6-gameplay-state"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-gameplay-reset", "Reset gameplay", `[data-testid="phase6-gameplay-reset"]`, "Gameplay state exists.", "Gameplay returns to its deterministic initial state.", `[data-testid="phase6-gameplay-state"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-asset-profile", "Select asset profile", `[data-testid^="phase6-asset-profile-"]`, "Asset policy controls are mounted.", "Asset manifest switches to the selected local policy.", `[data-testid="phase6-asset-manifest"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-material-variant", "Select material variant", `[data-testid^="phase6-material-variant-"]`, "Asset policy controls are mounted.", "Material variant changes without external asset writes.", `[data-testid="phase6-asset-manifest"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-asset-reset", "Reset asset policy", `[data-testid="phase6-asset-policy-reset"]`, "Asset policy differs from default or reset remains idempotent.", "Asset policy returns to the default manifest.", `[data-testid="phase6-asset-manifest"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-save-snapshot", "Save scene snapshot", `[data-testid="phase6-save-snapshot"]`, "Scene state is available.", "A browser-memory scene snapshot becomes loadable.", `[data-testid="phase6-save-load-state"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-load-snapshot", "Load scene snapshot", `[data-testid="phase6-load-snapshot"]`, "A snapshot was saved.", "Saved scene state is restored.", `[data-testid="phase6-save-load-state"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-clear-snapshot", "Clear scene snapshot", `[data-testid="phase6-clear-snapshot"]`, "A snapshot was saved.", "Snapshot is removed and load/clear disable.", `[data-testid="phase6-save-load-state"]`, "enabled", [ORGANISM_GAMEPLAY]),
  member("organism-focus-scene", "Move focus to scene", `[data-testid="phase6-focus-scene"]`, "Accessible scene target is mounted.", "Keyboard focus moves to the interactive scene and announcement updates.", `[data-testid="phase6-accessibility-state"]`, "enabled", [ORGANISM_GAMEPLAY]),
];

const organismNetcodeMembers: readonly ActionMember[] = [
  member("organism-netcode-session", "Run loopback session controls", `[data-testid^="phase6-netcode-"]`, "Follow the create, join, ready, start, tick, disconnect, close precondition sequence.", "Two-peer deterministic lockstep state changes with network transport disabled.", `[data-testid="phase6-netcode-state"]`, "enabled", [ORGANISM_NETCODE]),
  member("organism-leaderboard-capture", "Capture local run", `[data-testid="phase6-leaderboard-capture"]`, "Gameplay has a completed objective.", "Immutable run snapshot is ranked in the three-entry local leaderboard.", `[data-testid="phase6-leaderboard-list"]`, "enabled", [ORGANISM_NETCODE]),
  member("organism-leaderboard-reset", "Reset local leaderboard", `[data-testid="phase6-leaderboard-reset"]`, "Leaderboard has at least one entry.", "Local leaderboard becomes empty.", `[data-testid="phase6-leaderboard-state"]`, "enabled", [ORGANISM_NETCODE]),
  member("organism-performance-sample", "Run performance sample", `[data-testid="phase6-performance-start"]`, "Renderer is ready and reduced motion is off.", "Twelve renderer samples produce an honest pass/fail classification.", `[data-testid="phase6-performance-result"]`, "enabled", [ORGANISM_NETCODE]),
  member("organism-performance-finish", "Finish performance sample", `[data-testid="phase6-performance-finish"]`, "Sampling is active.", "Sampling completes early with the collected local samples.", `[data-testid="phase6-performance-result"]`, "enabled", [ORGANISM_NETCODE]),
  member("organism-performance-reset", "Reset performance sample", `[data-testid="phase6-performance-reset"]`, "A sample result or active run exists.", "Performance sampling returns to idle.", `[data-testid="phase6-performance-state"]`, "enabled", [ORGANISM_NETCODE]),
];

function scopedMembers(scope: string, actions: readonly ActionMember[]): readonly ActionMember[] {
  return actions.map((action) => ({
    ...action,
    id: `${scope}-${action.id}`,
    gapReason: action.status === "GAP"
      ? `${NO_CURRENT_EVIDENCE} The same OrganismView control is mounted on this route.`
      : undefined,
  }));
}

export const ACTION_MATRIX: readonly PageActionEntry[] = [
  {
    route: "/home",
    title: "Start",
    families: [
      family("home-build-examples", "Build and examples", "Gateway runtime readiness is true.", "Prompt or example starts one build and renders an honest result or error.", [
        member("home-prompt", "Enter build prompt", `.ai-builder textarea`, "Home builder is mounted.", "Prompt state changes.", `.ai-builder textarea`),
        member("home-build", "Build prompt", `[data-testid="ab-build"]`, "Prompt is non-empty and the separately approved live-provider gate is open.", "Build result, preview, files and audit facts become visible.", `[data-testid="ab-result"]`),
        member("home-iteration-input", "Enter build iteration", `.ab-iter-input`, "A successful build exists.", "Iteration input state changes without starting a provider request.", `.ab-iter-input`),
        member("home-example", "Select example prompt", `.ab-chip`, "Home builder is mounted.", "Selected example is copied into the prompt without starting a provider request.", `.ai-builder textarea`),
        member("home-cancel", "Cancel in-flight build", `.ai-builder button:has-text("Abbrechen")`, "A separately approved build request is in flight.", "Request is aborted and busy state clears.", `.ab-loading`, "conditional"),
      ]),
      family("home-result-actions", "Result share and download", "A successful build with HTML exists.", "Result can be inspected, shared and downloaded.", [
        member("home-result-fullscreen", "Open result fullscreen", `[data-testid="ab-result"] button:has-text("Vollbild")`, "A successful build exists.", "Generated HTML opens in a new browser window.", `[data-testid="ab-frame"]`),
        member("home-result-share", "Copy result share URL", `[data-testid="ab-result"] button:has-text("Teilen")`, "Build has a share_path and Clipboard API is available.", "Absolute share URL is copied.", `[data-testid="ab-result"]`),
        member("home-result-download", "Download result HTML", `[data-testid="ab-result"] button:has-text("Herunterladen")`, "A successful build exists.", "Generated HTML downloads as a file.", `[data-testid="ab-result"]`),
        member("home-result-code-toggle", "Toggle preview/code", `[data-testid="ab-result"] button:has-text("Code"), [data-testid="ab-result"] button:has-text("Vorschau")`, "A successful build exists.", "Visible result switches between iframe and source code.", `[data-testid="ab-frame"], .ab-code`),
      ]),
      family("home-links-live-console", "Product links and live console", "Home page is mounted.", "Page-local links navigate and read-only console controls update output.", [
        member("home-link-workbench", "Open workbench", `a[href="/workbench"]`, "Home page is mounted.", "Browser navigates to /workbench.", "main"),
        member("home-link-organism", "Open organism", `a[href="/organism"]`, "Home page is mounted.", "Browser navigates to /organism.", "main"),
        member("home-link-evidence", "Open evidence", `a[href="/evidence"]`, "Home page is mounted.", "Browser navigates to /evidence.", "main"),
        member("home-link-games", "Open games", `a[href="/games"]`, "Home page is mounted.", "Browser navigates to /games.", "main"),
        member("home-link-apps", "Open apps", `a[href="/apps"]`, "Home page is mounted.", "Browser navigates to /apps.", "main"),
        member("home-link-media", "Open media", `a[href="/media"]`, "Home page is mounted.", "Browser navigates to /media.", "main"),
        member("home-link-docs", "Open documents", `a[href="/docs-output"]`, "Home page is mounted.", "Browser navigates to /docs-output.", "main"),
        ...liveConsoleMembers("home-live"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/login",
    title: "Login",
    families: [
      family("login-session-navigation", "Name, login, logout and navigation", "Authentication API is reachable for session mutations.", "Session UI and navigation reflect confirmed API outcomes.", [
        member("login-name", "Enter optional name", `input[aria-label="Name"]`, "No user session is active.", "Name input state changes.", `input[aria-label="Name"]`),
        member("login-signin", "Sign in", `[data-testid="rl-signin"]`, "No user session is active.", "Signed HttpOnly session is created and signed-in UI appears.", `[data-testid="real-login"]`, "enabled", [PRODUCT_LOGIN]),
        member("login-signout", "Sign out", `[data-testid="rl-signout"]`, "A user session is active.", "Session deletion succeeds before signed-out UI appears.", `[data-testid="rl-signin"]`),
        member("login-workbench", "Open workbench after sign-in", `[data-testid="real-login"] a[href="/workbench"]`, "A user session is active.", "Browser navigates to /workbench.", `[data-testid="workbench-studio"]`, "enabled", [PRODUCT_LOGIN]),
        member("login-home", "Open workspace home", `a[href="/home"]`, "Login page is mounted.", "Browser navigates to /home.", "main"),
        member("login-marketing", "Open marketing root", `a[href="/"]`, "Login page is mounted.", "Browser navigates to /.", "main"),
      ]),
    ],
    excludedGates: [
      { id: "external-oauth", label: "External OAuth provider activation", locator: "not mounted", reason: "Separate auth-scope Owner gate is closed." },
    ],
  },
  {
    route: "/workbench",
    title: "Workbench",
    families: [
      family("workbench-build-iteration", "Build and iteration", "Gateway runtime readiness is true.", "Prompt produces a persisted build, preview, files and visible audit facts.", [
        member("workbench-prompt", "Edit prompt", `textarea[aria-label="Beschreibung für die App-Erstellung"]`, "Workbench is mounted.", "Prompt value changes.", `textarea[aria-label="Beschreibung für die App-Erstellung"]`, "enabled", [PRODUCT_WORKBENCH]),
        member("workbench-build", "Build prompt", `[data-testid="ws-build"]`, "Prompt is non-empty and the separately approved live-provider gate is open.", "One build POST produces visible persisted result and preview.", `[data-testid="ws-log"]`, "enabled", [PRODUCT_WORKBENCH, GOAL_WORKBENCH], "preverified_exact_control"),
        member("workbench-iteration-input", "Enter build iteration", `.ws-iterate`, "A successful persisted build is loaded.", "Iteration input state changes without starting a provider request.", `.ws-iterate`),
        member("workbench-example", "Select example prompt", `.workbench-studio .ab-chip`, "Workbench is mounted.", "Example is copied into the prompt without starting a provider request.", `textarea[aria-label="Beschreibung für die App-Erstellung"]`),
      ]),
      family("workbench-preview-code-file", "Preview, code and file selection", "A successful build exists.", "Generated artifacts can be inspected without mutating them.", [
        member("workbench-preview", "Show preview", `.workbench-studio button:has-text("Vorschau")`, "A successful build exists.", "Generated iframe becomes visible.", `[data-testid="ws-frame"]`),
        member("workbench-code", "Show code", `.workbench-studio button:has-text("Code")`, "A successful build exists.", "Selected generated file source becomes visible.", ".ws-code"),
        member("workbench-file", "Select generated file", `.ws-file`, "A successful build has generated files.", "Selected file becomes active and code tab opens.", ".ws-code"),
        member("workbench-fullscreen", "Open preview fullscreen", `.workbench-studio button:has-text("Vollbild")`, "A successful build exists.", "Generated HTML opens in a new browser window.", `[data-testid="ws-frame"]`),
      ]),
      family("workbench-share-download", "Share and download", "A successful build exists.", "Build URL or HTML leaves the page through an explicit user action.", [
        member("workbench-share", "Copy share URL", `.workbench-studio button:has-text("Teilen")`, "Build has a share_path and Clipboard API is available.", "Absolute share URL is copied.", ".wb-artifacts"),
        member("workbench-download", "Download HTML", `.workbench-studio button:has-text("Herunterladen")`, "A successful build exists.", "Generated HTML downloads as a file.", ".wb-artifacts"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/organism",
    title: "Organism",
    families: [
      family("organism-3d-camera-filter", "3D, camera and filters", "Organism contracts and local canvas are mounted.", "Visual and filter state changes remain bounded and local.", organismControlMembers),
      family("organism-gameplay-snapshot", "Gameplay and snapshots", "Organism local gameplay controls are mounted.", "Deterministic gameplay, policy, snapshot and accessibility state changes locally.", organismGameplayMembers),
      family("organism-netcode-performance", "Loopback netcode and performance", "Organism local simulation controls are mounted.", "Loopback, leaderboard and renderer sampling produce honest local state.", organismNetcodeMembers),
      family("organism-navigation", "Organism navigation", "Organism route is mounted.", "Page-local links navigate to replay and map.", [
        member("organism-nav-replay", "Open organism replay", `.page-head a[href="/organism/replay"]`, "Organism route is mounted.", "Browser navigates to /organism/replay.", "main"),
        member("organism-nav-map", "Open organism map", `.page-head a[href="/organism/map"]`, "Organism route is mounted.", "Browser navigates to /organism/map.", "main"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/organism/replay",
    title: "Organism Replay",
    families: [
      family("organism-replay-controls", "Organism controls, replay, console and navigation", "Replay route and read-only organism contracts are mounted.", "Local controls work; replay/run-id and console/navigation remain read-only.", [
        ...scopedMembers("replay", organismControlMembers),
        ...scopedMembers("replay", organismGameplayMembers),
        ...scopedMembers("replay", organismNetcodeMembers),
        member("replay-frames", "Inspect replay frames", `[data-testid="organism-replay-frames"]`, "Replay API returns frames or honest spec-only data.", "Redacted replay frames are visible.", `[data-testid="organism-replay-frames"]`, "contract_only", [ORGANISM_REPLAY, ORGANISM_RUN_ID]),
        ...liveConsoleMembers("replay-live"),
        member("replay-nav-live", "Open live organism", `.page-head a[href="/organism"]`, "Replay route is mounted.", "Browser navigates to /organism.", "main"),
        member("replay-nav-map", "Open organism map", `.page-head a[href="/organism/map"]`, "Replay route is mounted.", "Browser navigates to /organism/map.", "main"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/organism/map",
    title: "Organism Map",
    families: [
      family("organism-map-controls", "Topology, console and navigation", "Map route and read-only topology contract are mounted.", "Topology filters, adjacency inspection, console and navigation update without writes.", [
        {
          ...member("map-topology-kind-filter", "Filter topology kind", `[data-testid="organism-topology-kind-filter"]`, "The fail-closed topology contract is valid and contains multiple node kinds.", "The visible node list is filtered to the selected contract kind.", `[data-testid="organism-topology-node-list"]`, "enabled", [ORGANISM_TOPOLOGY]),
          requireEffectDelta: true,
        },
        member("map-topology-node-select", "Inspect topology node", `[data-testid="organism-topology-node"]`, "At least one validated topology node is visible.", "The selected node and its inbound/outbound adjacency update.", `[data-testid="organism-topology-adjacency"]`, "enabled", [ORGANISM_TOPOLOGY]),
        ...liveConsoleMembers("map-live"),
        member("map-nav-live", "Open live organism", `.page-head a[href="/organism"]`, "Map route is mounted.", "Browser navigates to /organism.", "main"),
        member("map-nav-replay", "Open organism replay", `.page-head a[href="/organism/replay"]`, "Map route is mounted.", "Browser navigates to /organism/replay.", "main"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/agents",
    title: "Agents",
    families: [
      family("agents-research-results", "Research run and source details", "Agent API and gated gateway are reachable.", "Research request renders four analysis-only roles, a DevOps synthesis, and hash-bound source details.", [
        member("agents-goal", "Enter research goal", `input[aria-label="Forschungsziel"]`, "Agent run panel is mounted.", "Research goal state changes.", `input[aria-label="Forschungsziel"]`, "enabled", [GOAL_AGENTS]),
        member("agents-run", "Run research", `[data-testid="ar-run"]`, "Research goal is non-empty and Agent API is reachable.", "Planner, Coder, Tester, DevOps, and a non-empty synthesis become visible.", `[data-testid="ar-result"]`, "enabled", [GOAL_AGENTS]),
        member("agents-source-detail", "Open source detail", `[data-testid^="ar-source-detail-"] > summary`, "A separately verified successful result includes bound sources.", "Selected inline source detail opens and exposes its exact sanitized extract.", `[data-testid^="ar-source-detail-"][open] .ar-source-extract`, "conditional", [GOAL_AGENTS]),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/files",
    title: "Files",
    families: [
      family("files-memory-search", "Memory search", "Agent API memory search is reachable.", "Query returns real lexical memory hits or a visible error.", [
        member("files-query", "Enter memory query", `input[aria-label="Suchbegriff für das Gedächtnis"]`, "Files search panel is mounted.", "Search query state changes.", `input[aria-label="Suchbegriff für das Gedächtnis"]`, "enabled", [GOAL_FILES]),
        member("files-search", "Search memory", `[data-testid="goal-b-files-search"]`, "Query is non-empty and memory API is reachable.", "Visible result reports real hit count.", `[data-testid="goal-b-files-result"]`, "enabled", [GOAL_FILES]),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/files/local",
    title: "Local Files",
    families: [
      family("files-local-spec-controls", "Root, tree, filter, copy and clear", "Static redacted project-tree specification is mounted.", "Only local spec state changes; no host filesystem is mounted or read.", [
        member("files-local-root", "Select root", `button[aria-label^="Stammverzeichnis "]`, "Spec roots are available.", "Selected spec root and local state update.", ".local-files-grid", "spec_only"),
        member("files-local-tree", "Select tree node", `.tnode-btn`, "Static redacted tree has nodes.", "Selected spec node and preview update.", ".local-files-grid pre", "spec_only"),
        member("files-local-filter", "Filter tree", `input[aria-label="Projektbaum durchsuchen"]`, "Static redacted tree is mounted.", "Visible static nodes filter locally.", ".local-files-grid .tree", "spec_only"),
        member("files-local-copy", "Copy selection", `button:has-text("Auswahl kopieren")`, "A static node is selected and Clipboard API is available.", "Redacted spec preview is copied.", ".local-files-grid pre", "spec_only"),
        member("files-local-clear", "Clear/reset local selection or filter", `button:has-text("Leeren"), button:has-text("Suche zurücksetzen"), button[aria-label="Suche leeren"]`, "Selection or filter state exists.", "Corresponding local spec state clears.", ".local-files-grid", "spec_only"),
      ]),
    ],
    excludedGates: [
      { id: "host-filesystem", label: "Live host filesystem read/write", locator: "not mounted", reason: "Contract is spec_only: host_filesystem_mounted=false and writes=false." },
    ],
  },
  {
    route: "/tools",
    title: "Tools",
    families: [
      family("tools-read-only-execute", "Select, query and read-only execute", "Agent API read-only tool envelope is reachable.", "Selected allowlisted tool returns a visible audited result without writes.", [
        member("tools-select", "Select tool", `[data-testid="goal-b-tools-panel"] select`, "Read-only tools are available.", "Selected allowlisted tool changes.", `[data-testid="goal-b-tools-panel"] select`),
        member("tools-query", "Enter tool query", `[data-testid="goal-b-tools-panel"] input`, "Tool panel is mounted.", "Tool query state changes.", `[data-testid="goal-b-tools-panel"] input`),
        member("tools-execute", "Execute read-only tool", `[data-testid="goal-b-tool-execute"]`, "Selected tool is allowlisted and API is reachable.", "Visible result contains tool name and audit identifier.", `[data-testid="goal-b-tool-result"]`, "enabled", [GOAL_TOOLS]),
        member("tools-marketplace-link", "Open marketplace", `a[href="/marketplace"]`, "Tools page is mounted.", "Browser navigates to /marketplace.", "main"),
      ]),
    ],
    excludedGates: [
      { id: "tools-write", label: "Write-capable MCP execution", locator: "not mounted", reason: "Live MCP write gate is closed." },
    ],
  },
  {
    route: "/marketplace",
    title: "Marketplace",
    families: [
      family("marketplace-selection-details-install", "Selection, details and install-plan dry-run", "Catalog is mounted; Agent API is required for install-plan persistence.", "Selection and details update locally; install registers only a dry-run plan.", [
        member("marketplace-select", "Select catalog item", `[data-testid="goal-b-marketplace-panel"] select`, "Catalog has items.", "Selected catalog item changes.", `[data-testid="goal-b-marketplace-panel"] select`),
        member("marketplace-details", "Show details", `[data-testid="goal-b-marketplace-details"]`, "A catalog item is selected.", "Visible result reports item details.", `[data-testid="goal-b-marketplace-result"]`, "enabled", [GOAL_MARKET_DETAILS]),
        member("marketplace-install-plan", "Create install plan", `[data-testid="goal-b-marketplace-install"]`, "A catalog item is selected and artifact registry is reachable.", "Dry-run artifact plan is registered with provider_writes=false.", `[data-testid="goal-b-marketplace-result"]`, "enabled", [GOAL_MARKET_INSTALL]),
      ]),
    ],
    excludedGates: [
      { id: "marketplace-provider-install", label: "Live provider installation", locator: "not mounted", reason: "Provider writes remain gated; only an install plan is allowed." },
    ],
  },
  {
    route: "/observe",
    title: "Observe",
    families: [
      family("observe-console-metrics-diagnose", "Live console, metrics and evidence link", "Read-only observability endpoints may be reachable.", "Console/diagnostic output updates honestly and evidence navigation works.", [
        ...liveConsoleMembers("observe-live"),
        member("observe-diagnose", "Run read-only runtime diagnosis", `[data-testid="goal-b-observe-refresh"]`, "Metrics and health endpoints are reachable or fail honestly.", "Visible diagnosis summarizes real read-only endpoint results.", `[data-testid="goal-b-observe-result"]`),
        member("observe-evidence-link", "Open evidence", `a[href="/evidence"]`, "Observe page is mounted.", "Browser navigates to /evidence.", "main"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/games",
    title: "Games",
    families: [
      family("games-build", "Game build", "Gateway runtime readiness is true.", "Game prompt produces generated files and preview.", [
        member("games-prompt", "Enter game prompt", `.workbench-studio textarea`, "Game workbench is mounted.", "Prompt state changes.", `.workbench-studio textarea`),
        member("games-build-run", "Build game", `[data-testid="ws-build"]`, "Prompt is non-empty and the separately approved live-provider gate is open.", "Visible build log, files and preview update.", `[data-testid="ws-log"]`),
        member("games-example", "Select game example", `.workbench-studio .ab-chip`, "Game workbench is mounted.", "Example is copied into the prompt without starting a provider request.", `.workbench-studio textarea`),
      ]),
      family("games-generated-result", "Generated game inspection and export", "A successful persisted game build exists.", "Generated game files, preview, sharing and download remain directly usable.", [
        member("games-iteration-input", "Enter game iteration", `.ws-iterate`, "A successful persisted game build is loaded.", "Iteration input state changes without starting a provider request.", `.ws-iterate`),
        member("games-preview", "Show game preview", `.workbench-studio button:has-text("Vorschau")`, "A successful persisted game build exists.", "Generated game iframe becomes visible.", `[data-testid="ws-frame"]`),
        member("games-code", "Show game code", `.workbench-studio button:has-text("Code")`, "A successful persisted game build exists.", "Selected generated game source becomes visible.", ".ws-code"),
        member("games-file", "Select generated game file", `.ws-file`, "A successful persisted game build has generated files.", "Selected file becomes active and code tab opens.", ".ws-code"),
        member("games-fullscreen", "Open game fullscreen", `.workbench-studio button:has-text("Vollbild")`, "A successful persisted game build exists.", "Generated game opens in a new browser window.", `[data-testid="ws-frame"]`),
        member("games-share", "Copy game share URL", `.workbench-studio button:has-text("Teilen")`, "Build has a share_path and Clipboard API is available.", "Absolute game share URL is copied.", ".wb-artifacts"),
        member("games-download", "Download game HTML", `.workbench-studio button:has-text("Herunterladen")`, "A successful persisted game build exists.", "Generated game HTML downloads as a file.", ".wb-artifacts"),
      ]),
      family("games-local-game", "Local game controls", "Browser supports canvas/WebGL.", "Demo starts/stops and optional full-power mode changes locally.", [
        member("games-local-start", "Start local game", `[data-testid="rg-start"]`, "Demo is stopped and canvas is available.", "Local game loop starts and score can change.", `[data-testid="rg-score"]`),
        member("games-local-fullpower", "Toggle full-power mode", `[data-testid="rg-fullpower"]`, "GPU guard warning is active.", "Local GPU guard mode toggles.", `[data-testid="rg-gpuwarn"]`, "conditional"),
        member("games-local-stop", "Stop local game", `[data-testid="rg-gpustop"]`, "GPU guard warning is active.", "Local game loop stops.", `[data-testid="rg-start"]`, "conditional"),
      ]),
      family("games-build-history", "Build history", "Build registry has at least one game/app.", "Persisted build can open/edit; deletion changes cards only after confirmed success.", [
        member("games-history-open", "Open persisted build", `.builds-gallery .bg-open`, "Build registry has a card.", "Persisted run opens in a new tab.", `[data-testid="persisted-build-frame"]`),
        member("games-history-edit", "Edit persisted build", `.builds-gallery .bg-edit`, "Build registry has a card.", "Browser navigates to workbench with build query.", `[data-testid="workbench-studio"]`),
        member("games-history-delete", "Delete persisted build", `.builds-gallery [data-testid^="build-delete-"]`, "Build registry has a card and user confirms.", "Card disappears only after 2xx DELETE; 403/network errors remain visible and keep the card.", `[data-testid="build-delete-error"], .builds-gallery .bg-card`),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/apps",
    title: "Apps",
    families: [
      family("apps-open-edit-delete-workbench", "Open, edit, delete and workbench", "Build registry is reachable; card actions require at least one build.", "Navigation works; deletion is server-confirmed and failure-preserving.", [
        member("apps-open", "Open persisted app", `.builds-gallery .bg-open`, "Build registry has a card.", "Persisted run opens in a new tab.", `[data-testid="persisted-build-frame"]`),
        member("apps-edit", "Edit persisted app", `.builds-gallery .bg-edit`, "Build registry has a card.", "Browser navigates to workbench with build query.", `[data-testid="workbench-studio"]`),
        member("apps-delete", "Delete persisted app", `.builds-gallery [data-testid^="build-delete-"]`, "Build registry has a card and user confirms.", "Card disappears only after 2xx DELETE; 403/network errors keep it and show an alert.", `[data-testid="build-delete-error"], .builds-gallery .bg-card`),
        member("apps-workbench", "Build a new app", `a[href="/workbench"]`, "Apps page is mounted.", "Browser navigates to /workbench.", `[data-testid="workbench-studio"]`),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/media",
    title: "Media",
    families: [
      family("media-tabs-play-record-download", "Music/video tabs, play, record and download", "Browser media APIs are feature-detected.", "Local audio/video state changes and explicit recordings download.", [
        member("media-tab", "Switch media tab", `[data-testid^="cs-tab-"]`, "Media studio is mounted.", "Selected music/video tool becomes visible.", `[data-testid="cs-music"], [data-testid="cs-video"]`),
        member("media-play", "Play or stop generated audio", `[data-testid="cs-music-play"]`, "Web Audio API is supported and music tab is active.", "Local synth audio starts or stops.", `[data-testid="cs-music"]`),
        member("media-music-record", "Record music", `[data-testid="cs-music-rec"]`, "Web Audio and MediaRecorder are supported.", "Six-second local audio recording downloads.", `[data-testid="cs-music"]`),
        member("media-video-record", "Record video", `[data-testid="cs-video-rec"]`, "MediaRecorder and canvas captureStream are supported.", "Five-second local WebM clip downloads.", `[data-testid="cs-video"]`),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/docs-output",
    title: "Documents",
    families: [
      family("docs-title-markdown-download", "Title, Markdown and download", "Document studio is mounted; downloads require browser Blob support.", "Editor updates preview and explicit Markdown/HTML downloads are created.", [
        member("docs-title", "Edit document title", `input[aria-label="Titel"]`, "Document studio is mounted.", "Title and download slug update.", `.cs-preview`, "enabled", [GOAL_DOCS]),
        member("docs-markdown", "Edit Markdown", `textarea[aria-label="Markdown"]`, "Document studio is mounted.", "Rendered preview updates.", ".cs-preview", "enabled", [GOAL_DOCS]),
        member("docs-download-md", "Download Markdown", `[data-testid="cs-doc-md"]`, "Document text exists.", "Markdown file downloads with slugged title.", ".cs-preview", "enabled", [GOAL_DOCS]),
        member("docs-download-html", "Download HTML", `[data-testid="cs-doc-html"]`, "Document text exists.", "Standalone HTML file downloads.", ".cs-preview"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/evidence",
    title: "Evidence",
    families: [
      family("evidence-console-verifier", "Live console and verifier probe", "Read-only evidence endpoints may be reachable.", "Visible console/verifier result reflects real GET responses.", [
        ...liveConsoleMembers("evidence-live"),
        member("evidence-verifier", "Run verifier probe", `[data-testid="goal-b-evidence-verify"]`, "Progress-integrity and external-gate endpoints are reachable or fail honestly.", "Visible result summarizes read-only verifier state.", `[data-testid="goal-b-evidence-result"]`),
      ]),
    ],
    excludedGates: [
      { id: "evidence-run-scripts", label: "Execute verifier scripts from UI", locator: "not mounted", reason: "The UI explicitly lists scripts but does not execute them." },
    ],
  },
  {
    route: "/diagnostics",
    title: "Diagnostics",
    families: [
      family("diagnostics-contract-copy-evidence", "Contract selection/load/copy and evidence links", "Read-only diagnostic endpoints and archive inventory are mounted.", "Selected contract output loads/copies and links navigate to evidence.", [
        ...liveConsoleMembers("diagnostics-live"),
        member("diagnostics-evidence", "Open evidence", `a[href="/evidence"]`, "Diagnostics page is mounted.", "Browser navigates to /evidence.", "main"),
        member("diagnostics-archive-evidence", "Open archived evidence", `a[href^="/evidence?archive="]`, "Archive inventory contains an item.", "Browser navigates to evidence with archive query.", "main"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/design-system",
    title: "Design System",
    families: [
      family("design-contract-copy-responsive", "Design contract load/copy and responsive link", "Design-system page and read-only reference contract are mounted.", "Reference contract output loads/copies and responsive link navigates.", [
        ...liveConsoleMembers("design-live").filter((action) => !action.id.endsWith("-endpoint")),
        member("design-responsive", "Open responsive reference", `a[href="/responsive"]`, "Design-system page is mounted.", "Browser navigates to /responsive.", "main"),
      ]),
    ],
    excludedGates: [],
  },
  {
    route: "/technology",
    title: "Technology",
    families: [],
    excludedGates: [],
    zeroPageLocalReason: "Static technology inventory: no mounted page-local action control.",
  },
  {
    route: "/settings",
    title: "Settings",
    families: [
      family("settings-plan-only", "Plan-only gate check", "Governance contract endpoint is reachable.", "Visible plan reports closed gates without applying any change.", [
        member("settings-plan-only", "Check plan-only gates", `[data-testid="goal-b-settings-planonly"]`, "Settings gate panel is mounted.", "Visible result reports planned/closed gates with no writes.", `[data-testid="goal-b-settings-result"]`, "contract_only"),
      ]),
    ],
    excludedGates: [
      { id: "settings-apply", label: "Apply governance changes", locator: `button:has-text("Anwenden gesperrt")`, reason: "Disabled stop-gate control; no page-local action is executable." },
    ],
  },
  {
    route: "/open-source",
    title: "Open Source",
    families: [],
    excludedGates: [],
    zeroPageLocalReason: "Static license inventory: no mounted page-local action control.",
  },
] as const;

export const GLOBAL_NAVIGATION_FAMILY: ActionFamily = family(
  "global-appshell-navigation",
  "Global AppShell navigation",
  "AppShell is mounted (login is the documented exception).",
  "Rail/mobile/command-palette navigation changes route without being counted as page-local action coverage.",
  [
    member("global-rail-nav", "Desktop navigation rail", `.rail-nav a[href]`, "Desktop AppShell is visible.", "Browser navigates to selected canonical route.", "main"),
    member("global-mobile-nav", "Mobile bottom navigation", `.bottom-nav a[href]`, "Mobile AppShell is visible.", "Browser navigates to selected canonical route.", "main"),
    member("global-command-open", "Open command palette", `button[aria-label*="Befehlspalette"]`, "AppShell is mounted.", "Command palette becomes visible.", `[data-testid="cmdk-proof"]`, "enabled", [BROWSER_COMMAND_PALETTE]),
    member("global-command-navigate", "Navigate from command palette", `.cmdk-item`, "Command palette is open.", "Browser navigates to selected canonical route.", "main", "enabled", [BROWSER_COMMAND_PALETTE]),
  ],
);

export const ACTION_MATRIX_SUMMARY = {
  routeCount: ACTION_MATRIX.length,
  familyCount: ACTION_MATRIX.reduce((total, page) => total + page.families.length, 0),
  memberActionCount: ACTION_MATRIX.reduce(
    (total, page) => total + page.families.reduce((pageTotal, item) => pageTotal + item.memberActions.length, 0),
    0,
  ),
  zeroActionRoutes: ACTION_MATRIX.filter((page) => page.families.length === 0).map((page) => page.route),
  passMembers: ACTION_MATRIX.flatMap((page) => page.families)
    .flatMap((item) => item.memberActions)
    .filter((item) => item.status === "PASS").length,
  gapMembers: ACTION_MATRIX.flatMap((page) => page.families)
    .flatMap((item) => item.memberActions)
    .filter((item) => item.status === "GAP").length,
} as const;

export function validateActionMatrix(): true {
  const expectedRoutes: readonly CanonicalActionRoute[] = [
    "/home", "/login", "/workbench", "/organism", "/organism/replay", "/organism/map",
    "/agents", "/files", "/files/local", "/tools", "/marketplace", "/observe", "/games",
    "/apps", "/media", "/docs-output", "/evidence", "/diagnostics", "/design-system",
    "/technology", "/settings", "/open-source",
  ];
  const routes = ACTION_MATRIX.map((page) => page.route);
  if (routes.length !== 22 || new Set(routes).size !== 22 || routes.some((route, index) => route !== expectedRoutes[index])) {
    throw new Error("action matrix must contain the 22 canonical routes in navigation order");
  }
  const zeroRoutes = ACTION_MATRIX.filter((page) => page.families.length === 0).map((page) => page.route);
  if (zeroRoutes.join("|") !== "/technology|/open-source") {
    throw new Error("only /technology and /open-source may have zero page-local action families");
  }
  const memberIds = ACTION_MATRIX.flatMap((page) => page.families).flatMap((item) => item.memberActions.map((action) => action.id));
  if (new Set(memberIds).size !== memberIds.length) throw new Error("page-local member action ids must be unique");
  for (const page of ACTION_MATRIX) {
    for (const item of page.families) {
      if (!item.memberActions.length) throw new Error(`${page.route}/${item.id} has no member actions`);
      for (const action of item.memberActions) {
        if (!action.locator || !action.precondition || !action.expectedEffect || !action.effectLocator) {
          throw new Error(`${page.route}/${action.id} has an incomplete effect contract`);
        }
        if (action.status === "PASS" && !action.evidence.length) {
          throw new Error(`${page.route}/${action.id} claims PASS without named current evidence`);
        }
        if (action.status === "GAP" && !action.gapReason) {
          throw new Error(`${page.route}/${action.id} has a GAP without a reason`);
        }
        if (action.enabled !== (action.availability === "enabled")) {
          throw new Error(`${page.route}/${action.id} has inconsistent enabled/availability state`);
        }
        if (action.availability === "enabled"
          && action.verificationMode !== "interactive"
          && action.verificationMode !== "preverified_exact_control") {
          throw new Error(`${page.route}/${action.id} is enabled without a direct or exact-control proof mode`);
        }
      }
    }
  }
  const preverified = ACTION_MATRIX.flatMap((page) => page.families)
    .flatMap((item) => item.memberActions)
    .filter((action) => action.verificationMode === "preverified_exact_control");
  if (preverified.length !== 1
    || preverified[0].id !== "workbench-build"
    || preverified[0].locator !== `[data-testid="ws-build"]`) {
    throw new Error("only the exact P0 workbench build control may use preverified evidence");
  }
  for (const id of ["home-build", "games-build-run"]) {
    const action = ACTION_MATRIX.flatMap((page) => page.families)
      .flatMap((item) => item.memberActions)
      .find((candidate) => candidate.id === id);
    if (!action || action.availability !== "enabled" || action.verificationMode !== "interactive") {
      throw new Error(`${id} must remain enabled and directly verified on its own route`);
    }
    if (action.evidence.some((item) => item.source === "product-acceptance")) {
      throw new Error(`${id} must not inherit workbench product-acceptance evidence`);
    }
  }
  return true;
}

validateActionMatrix();
