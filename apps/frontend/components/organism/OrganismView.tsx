"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import CortexLive from "./CortexLive";
import { HUBS, LAYERS, ORGANISM_AGENTS, STATE_LABEL, type RunState } from "./regionMap";
import { CLOSED_GATES } from "../../lib/platform";

const STATES: RunState[] = ["idle", "planning", "executing", "verifying", "blocked"];
const DEFAULT_CAPS = { webgpu: false, webgl2: false, gpu: "WebGL" };
const MODE_LABEL = { live: "Live", replay: "Wiedergabe", map: "Karte" } as const;
type CameraPreset = "wide" | "close" | "top";
type LightingProfile = "studio" | "night" | "sunrise";
type GameplayObjective = "collect" | "checkpoint" | "survive";
type AssetProfile = "cube" | "beacon" | "ring";
type MaterialVariant = "cyan" | "amber" | "rose";
type LocalLeaderboardRun = {
  captureSequence: number;
  score: number;
  completions: number;
};
type PerformanceSample = { fps: number; ms: number };
type PerformanceSampleResult = {
  status: "pass" | "fail";
  reason: "budget" | "timeout" | "reduced_motion" | null;
  sampleCount: number;
  averageFps: number;
  averageMs: number;
};
type Phase6SceneSnapshot = {
  autoRotate: boolean;
  reducedMotion: boolean;
  cameraPreset: CameraPreset;
  fovDegrees: (typeof FOV_STEPS)[number];
  lightingProfile: LightingProfile;
  exposure: number;
  gameplayObjective: GameplayObjective;
  gameplayScore: number;
  gameplayCheckpoints: number;
  gameplayCompletions: number;
  gameplayInputEvents: number;
  gameplayTicks: number;
  gameplayPaused: boolean;
  assetProfile: AssetProfile;
  materialVariant: MaterialVariant;
};
const CAMERA_PRESETS: Array<{ id: CameraPreset; label: string }> = [
  { id: "wide", label: "Weit" },
  { id: "close", label: "Nah" },
  { id: "top", label: "Oben" },
];
const LIGHTING_PROFILES: Array<{ id: LightingProfile; label: string; exposure: number }> = [
  { id: "studio", label: "Studio", exposure: 1 },
  { id: "night", label: "Nacht", exposure: 0.82 },
  { id: "sunrise", label: "Morgen", exposure: 1.12 },
];
const FOV_STEPS = [38, 45, 58] as const;
const GAMEPLAY_OBJECTIVES: Record<GameplayObjective, { label: string; next: GameplayObjective; scoreDelta: number; checkpointDelta: number }> = {
  collect: { label: "Signal sammeln", next: "checkpoint", scoreDelta: 10, checkpointDelta: 0 },
  checkpoint: { label: "Checkpoint sichern", next: "survive", scoreDelta: 0, checkpointDelta: 1 },
  survive: { label: "Stabilitaet halten", next: "collect", scoreDelta: 10, checkpointDelta: 0 },
};
const ASSET_PROFILES: Array<{ id: AssetProfile; label: string; geometry: string }> = [
  { id: "cube", label: "Wuerfel", geometry: "boxGeometry" },
  { id: "beacon", label: "Signal", geometry: "coneGeometry" },
  { id: "ring", label: "Ring", geometry: "torusGeometry" },
];
const MATERIAL_VARIANTS: Array<{ id: MaterialVariant; label: string; color: string }> = [
  { id: "cyan", label: "Cyan", color: "#00e5ff" },
  { id: "amber", label: "Amber", color: "#f59e0b" },
  { id: "rose", label: "Rose", color: "#fb7185" },
];
const LEADERBOARD_MAXIMUM_ENTRIES = 3;
const PERFORMANCE_SAMPLE_COUNT = 12;
const PERFORMANCE_MINIMUM_FPS = 25;
const PERFORMANCE_MAXIMUM_MS = 40;
const PERFORMANCE_SAMPLE_TIMEOUT_MS = 20_000;

function rankLocalRuns(a: LocalLeaderboardRun, b: LocalLeaderboardRun): number {
  return b.score - a.score
    || b.completions - a.completions
    || a.captureSequence - b.captureSequence;
}

function summarizePerformanceSamples(samples: PerformanceSample[]): PerformanceSampleResult {
  const sampleCount = samples.length;
  const averageFps = Math.round((samples.reduce((total, sample) => total + sample.fps, 0) / sampleCount) * 10) / 10;
  const averageMs = Math.round((samples.reduce((total, sample) => total + sample.ms, 0) / sampleCount) * 10) / 10;
  return {
    status: averageFps >= PERFORMANCE_MINIMUM_FPS && averageMs <= PERFORMANCE_MAXIMUM_MS ? "pass" : "fail",
    reason: averageFps >= PERFORMANCE_MINIMUM_FPS && averageMs <= PERFORMANCE_MAXIMUM_MS ? null : "budget",
    sampleCount,
    averageFps,
    averageMs,
  };
}

function failPerformanceSamples(samples: PerformanceSample[], reason: "timeout" | "reduced_motion"): PerformanceSampleResult {
  if (samples.length === 0) return { status: "fail", reason, sampleCount: 0, averageFps: 0, averageMs: 0 };
  return { ...summarizePerformanceSamples(samples), status: "fail", reason };
}

const HUB_LABEL_DE: Record<string, string> = {
  workbench: "WERKBANK",
  agents: "AGENTEN",
  tools: "WERKZEUGE / MCP",
  models: "MODELLE",
  marketplace: "MARKTPLATZ",
  observe: "BEOBACHTUNG",
  memory: "GEDÄCHTNIS",
  cloud: "CLOUD",
};

const HUB_DESC: Record<string, string> = {
  workbench: "Bauen · Erstellen · Zusammenarbeiten — vom Prompt zum Artefakt, mit ehrlichem Ausführungsstatus.",
  agents: "Vier deterministische Agentenprofile — planner, coder, tester, devops.",
  tools: "MCP-Tools und Provider-Zugriff — Schreibbereiche bleiben bis zur Freigabe durch Gates gesperrt.",
  models: "LLM-Routing, Fallbacks, Safety und Kostenkontrolle.",
  marketplace: "Skills, Agenten, MCP-Tools und Modelle zum Zusammenstellen.",
  observe: "Systemzustand, Traces, Metriken, Kosten und Nachweise.",
  memory: "Langzeitgedächtnis und Wissen mit PostgreSQL und pgvector.",
  cloud: "Sieben-Schichten-Multi-Cloud-Architektur über mehrere Provider.",
};

type OrganismRuntimeEvent = {
  seq?: number;
  offset_s?: number;
  kind?: string;
  event_type?: string;
  hub?: string;
  route?: string;
  run_state?: string;
  regions?: string[];
  severity?: string;
  source_kind?: string;
  secret_output?: boolean;
  writes?: boolean;
};

type OrganismReplayFrame = {
  t?: number;
  run_state?: string;
  active?: string[];
  regions?: string[];
  source_kind?: string;
};

type RuntimeProjection = {
  source: string;
  sourceKind: string;
  live: boolean;
  runId: string | null;
  note: string;
  nonClaims: string[];
  events: OrganismRuntimeEvent[];
  frames: OrganismReplayFrame[];
  replayAvailable: boolean;
};

function normalizeRunState(value: unknown, fallback: RunState): RunState {
  return typeof value === "string" && STATES.includes(value as RunState) ? (value as RunState) : fallback;
}

function readRequestedRunId(): string {
  if (typeof window === "undefined") return "";
  const raw = new URLSearchParams(window.location.search).get("run_id") ?? "";
  const trimmed = raw.trim();
  return /^[A-Za-z0-9_.:-]{1,96}$/.test(trimmed) ? trimmed : "";
}

function detectCaps() {
  let webgl2 = false;
  let gpu = "WebGL";
  try {
    if (typeof document !== "undefined") {
      const c = document.createElement("canvas");
      const gl = (c.getContext("webgl2") || c.getContext("webgl")) as WebGLRenderingContext | null;
      webgl2 = !!c.getContext("webgl2");
      const dbg = gl?.getExtension("WEBGL_debug_renderer_info");
      if (gl && dbg) gpu = String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) || "WebGL").replace(/^ANGLE \(([^,]+),.*$/, "$1").slice(0, 38);
    }
  } catch {
    webgl2 = false;
  }
  const webgpu = typeof navigator !== "undefined" && "gpu" in navigator;
  return { webgpu, webgl2, gpu };
}

function isExpectedAbort(error: unknown, ctrl: AbortController) {
  if (ctrl.signal.aborted) return true;
  if (error instanceof DOMException && error.name === "AbortError") return true;
  if (error instanceof Error && error.name === "AbortError") return true;
  return false;
}

function abortQuietly(ctrl: AbortController, reason: string) {
  if (ctrl.signal.aborted) return;
  const abortReason = typeof DOMException !== "undefined" ? new DOMException(reason, "AbortError") : reason;
  ctrl.abort(abortReason);
}

export default function OrganismView({ mode = "live" }: { mode?: "live" | "replay" | "map" }) {
  const [runState, setRunState] = useState<RunState>("planning");
  const [active, setActive] = useState<string>("workbench");
  const [layers, setLayers] = useState<string[]>(LAYERS.map((l) => l.code));
  const [agents, setAgents] = useState<string[]>([...ORGANISM_AGENTS]);
  const [stats, setStats] = useState<{ fps: number; nodes: number; ms: number }>({ fps: 0, nodes: 0, ms: 0 });
  const [feed, setFeed] = useState<{ source: string; live: boolean; hubs: Record<string, string> } | null>(null);
  const [runtimeFeed, setRuntimeFeed] = useState<RuntimeProjection | null>(null);
  // Phase-6 (Scale & 3D) frontend controls
  const [autoRotate, setAutoRotate] = useState(true);
  const [reducedMotion, setReducedMotion] = useState(false);
  const [systemReducedMotion, setSystemReducedMotion] = useState(false);
  const [accessibilityAnnouncement, setAccessibilityAnnouncement] = useState("3D-Szene mit Standardbewegung aktiv");
  const [resetSignal, setResetSignal] = useState(0);
  const [cameraPreset, setCameraPreset] = useState<CameraPreset>("wide");
  const [fovDegrees, setFovDegrees] = useState<(typeof FOV_STEPS)[number]>(45);
  const [lightingProfile, setLightingProfile] = useState<LightingProfile>("studio");
  const [exposure, setExposure] = useState(1);
  const [renderMode, setRenderMode] = useState<"2d" | "3d">("3d");
  const [caps, setCaps] = useState(DEFAULT_CAPS);
  const [interactionStatus, setInteractionStatus] = useState("waiting_for_organism_interaction");
  const [gameplayObjective, setGameplayObjective] = useState<GameplayObjective>("collect");
  const [gameplayScore, setGameplayScore] = useState(0);
  const [gameplayCheckpoints, setGameplayCheckpoints] = useState(0);
  const [gameplayCompletions, setGameplayCompletions] = useState(0);
  const [gameplayInputEvents, setGameplayInputEvents] = useState(0);
  const [gameplayTicks, setGameplayTicks] = useState(0);
  const [gameplayPaused, setGameplayPaused] = useState(false);
  const [assetProfile, setAssetProfile] = useState<AssetProfile>("cube");
  const [materialVariant, setMaterialVariant] = useState<MaterialVariant>("cyan");
  const [savedSnapshot, setSavedSnapshot] = useState<Phase6SceneSnapshot | null>(null);
  const [snapshotRevision, setSnapshotRevision] = useState(0);
  const [snapshotStatus, setSnapshotStatus] = useState<"empty" | "saved" | "restored">("empty");
  const [netcodeSessionActive, setNetcodeSessionActive] = useState(false);
  const [netcodeGuestConnected, setNetcodeGuestConnected] = useState(false);
  const [netcodeHostReady, setNetcodeHostReady] = useState(false);
  const [netcodeGuestReady, setNetcodeGuestReady] = useState(false);
  const [netcodeRunning, setNetcodeRunning] = useState(false);
  const [netcodeTicks, setNetcodeTicks] = useState(0);
  const [netcodePackets, setNetcodePackets] = useState(0);
  const [netcodeSequence, setNetcodeSequence] = useState(0);
  const [netcodeDisconnects, setNetcodeDisconnects] = useState(0);
  const [leaderboardRuns, setLeaderboardRuns] = useState<LocalLeaderboardRun[]>([]);
  const [leaderboardCaptureSequence, setLeaderboardCaptureSequence] = useState(1);
  const [performanceSamples, setPerformanceSamples] = useState<PerformanceSample[]>([]);
  const [performanceSamplingActive, setPerformanceSamplingActive] = useState(false);
  const [performanceResult, setPerformanceResult] = useState<PerformanceSampleResult | null>(null);
  const performanceSamplesRef = useRef<PerformanceSample[]>([]);

  // Bind to the organism live-state feed: real when the configured agent-api is
  // reachable (source: "agent-api"), honest deterministic spec-only otherwise.
  useEffect(() => {
    let alive = true;
    const ctrl = new AbortController();
    const timer = setTimeout(() => abortQuietly(ctrl, "organism live-state timeout"), 1500);
    fetch("/api/v1/organism/live-state", { cache: "no-store", signal: ctrl.signal })
      .then((r) => (r.ok ? r.json() : null))
      .then((d: { source?: string; live?: boolean; run_state?: string; hubs?: Array<{ id: string; status: string }> } | null) => {
        if (!alive || !d) return;
        const hubs: Record<string, string> = {};
        (d.hubs ?? []).forEach((h) => (hubs[h.id] = h.status));
        setFeed({ source: d.source ?? "spec_only", live: !!d.live, hubs });
        if (d.run_state && STATES.includes(d.run_state as RunState)) setRunState(d.run_state as RunState);
      })
      .catch((err) => {
        if (!alive || isExpectedAbort(err, ctrl)) return;
        if (process.env.NODE_ENV !== "production") console.warn("organism live-state unavailable; using spec-only state:", err);
      })
      .finally(() => clearTimeout(timer));
    return () => {
      alive = false;
      clearTimeout(timer);
      abortQuietly(ctrl, "organism live-state effect disposed");
    };
  }, []);

  useEffect(() => {
    let alive = true;
    const ctrl = new AbortController();
    const timer = setTimeout(() => abortQuietly(ctrl, "organism runtime projection timeout"), 2500);
    const requestedRunId = readRequestedRunId();
    const query = requestedRunId ? `?run_id=${encodeURIComponent(requestedRunId)}` : "";
    Promise.all([
      fetch(`/api/v1/organism/events${query}`, { cache: "no-store", signal: ctrl.signal }).then((r) => (r.ok ? r.json() : null)),
      fetch(`/api/v1/organism/replay${query}`, { cache: "no-store", signal: ctrl.signal }).then((r) => (r.ok ? r.json() : null)),
    ])
      .then(([eventsBody, replayBody]: [
        {
          source?: string;
          source_kind?: string;
          live?: boolean;
          run_id?: string | null;
          note?: string;
          non_claims?: string[];
          events?: OrganismRuntimeEvent[];
        } | null,
        {
          source_kind?: string;
          replay_available?: boolean;
          frames?: OrganismReplayFrame[];
          non_claims?: string[];
        } | null,
      ]) => {
        if (!alive || !eventsBody) return;
        const events = Array.isArray(eventsBody.events) ? eventsBody.events : [];
        const frames = Array.isArray(replayBody?.frames) ? replayBody.frames : [];
        const latestEvent = events[events.length - 1];
        const latestFrame = frames[frames.length - 1];
        const nextActive = latestFrame?.active?.[0] ?? latestEvent?.hub;
        const nextState = latestFrame?.run_state ?? latestEvent?.run_state;
        if (nextActive && HUBS.some((h) => h.id === nextActive)) setActive(nextActive);
        if (nextState) setRunState((current) => normalizeRunState(nextState, current));
        setRuntimeFeed({
          source: eventsBody.source ?? "spec_only",
          sourceKind: eventsBody.source_kind ?? replayBody?.source_kind ?? "spec_only",
          live: !!eventsBody.live,
          runId: (eventsBody.run_id ?? requestedRunId) || null,
          note: eventsBody.note ?? "",
          nonClaims: [...(eventsBody.non_claims ?? []), ...(replayBody?.non_claims ?? [])],
          events,
          frames,
          replayAvailable: !!replayBody?.replay_available,
        });
      })
      .catch((err) => {
        if (!alive || isExpectedAbort(err, ctrl)) return;
        if (process.env.NODE_ENV !== "production") console.warn("organism runtime projection unavailable; using spec-only state:", err);
      })
      .finally(() => clearTimeout(timer));
    return () => {
      alive = false;
      clearTimeout(timer);
      abortQuietly(ctrl, "organism runtime projection effect disposed");
    };
  }, []);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      setCaps(detectCaps());
    });
    return () => window.cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const applyPreference = () => {
      setSystemReducedMotion(query.matches);
      setAccessibilityAnnouncement(query.matches
        ? "Systempraeferenz fuer reduzierte Bewegung aktiv, statische 2D-Ansicht wird verwendet"
        : "Systempraeferenz fuer Standardbewegung aktiv");
    };
    applyPreference();
    query.addEventListener("change", applyPreference);
    return () => query.removeEventListener("change", applyPreference);
  }, []);

  const hub = HUBS.find((h) => h.id === active);
  const effectiveReducedMotion = reducedMotion || systemReducedMotion;
  const onMode = useCallback((m: "2d" | "3d") => setRenderMode(m), []);
  const markInteraction = useCallback((kind: string, value: string) => {
    setInteractionStatus([
      "PASS organism_control",
      `kind=${kind}`,
      `value=${value}`,
      "evidence=visible_result_text",
      "live_provider_calls=false",
      "live_mcp_writes=false",
    ].join("\n"));
  }, []);
  const onStats = useCallback((fps: number, nodes: number, ms: number) => {
    if (!Number.isFinite(fps) || !Number.isFinite(ms) || fps <= 0 || ms <= 0) return;
    setStats({ fps, nodes, ms });
    if (!performanceSamplingActive) return;
    setPerformanceSamples((samples) => {
      if (samples.length >= PERFORMANCE_SAMPLE_COUNT) return samples;
      const next = [...samples, { fps, ms }];
      performanceSamplesRef.current = next;
      return next;
    });
  }, [performanceSamplingActive]);
  const selectRunState = useCallback((state: RunState) => {
    setRunState(state);
    markInteraction("run_state", state);
  }, [markInteraction]);
  const selectHub = useCallback((hubId: string) => {
    setActive(hubId);
    setAccessibilityAnnouncement(`Fokuszentrum ${HUB_LABEL_DE[hubId] ?? hubId} ausgewaehlt`);
    markInteraction("hub", hubId);
  }, [markInteraction]);
  const toggleAutoRotate = useCallback(() => {
    setAutoRotate((value) => {
      const next = !value;
      markInteraction("auto_rotate", String(next));
      return next;
    });
  }, [markInteraction]);
  const resetCamera = useCallback(() => {
    setResetSignal((n) => n + 1);
    markInteraction("camera_reset", "requested");
  }, [markInteraction]);
  const selectCameraPreset = useCallback((preset: CameraPreset) => {
    setCameraPreset(preset);
    markInteraction("camera_preset", preset);
  }, [markInteraction]);
  const selectFov = useCallback((value: number) => {
    const safeFov = FOV_STEPS.includes(value as (typeof FOV_STEPS)[number])
      ? value as (typeof FOV_STEPS)[number]
      : 45;
    setFovDegrees(safeFov);
    markInteraction("camera_fov", String(safeFov));
  }, [markInteraction]);
  const selectLightingProfile = useCallback((profile: LightingProfile) => {
    const nextExposure = LIGHTING_PROFILES.find((item) => item.id === profile)?.exposure ?? 1;
    setLightingProfile(profile);
    setExposure(nextExposure);
    markInteraction("lighting_profile", `${profile}:${nextExposure.toFixed(2)}`);
  }, [markInteraction]);
  const selectExposure = useCallback((value: number) => {
    const safeExposure = Math.min(1.18, Math.max(0.72, Math.round(value * 50) / 50));
    setExposure(safeExposure);
    markInteraction("lighting_exposure", safeExposure.toFixed(2));
  }, [markInteraction]);
  const toggleReducedMotion = useCallback(() => {
    setReducedMotion((value) => {
      const next = !value;
      setAccessibilityAnnouncement(next
        ? "Reduzierte Bewegung aktiv, statische 2D-Ansicht wird verwendet"
        : "Manuelle Reduzierung deaktiviert, Systempraeferenz bleibt massgeblich");
      markInteraction("reduced_motion", String(next));
      return next;
    });
  }, [markInteraction]);
  const focusCortexSurface = useCallback(() => {
    document.getElementById("organism-cortex-surface")?.focus();
    setAccessibilityAnnouncement("Organismus-Szene fokussiert");
    markInteraction("accessibility_focus", "organism-cortex-surface");
  }, [markInteraction]);
  const completeGameplayObjective = useCallback((input: "pointer" | "keyboard") => {
    const transition = GAMEPLAY_OBJECTIVES[gameplayObjective];
    setGameplayScore((value) => value + transition.scoreDelta);
    setGameplayCheckpoints((value) => value + transition.checkpointDelta);
    setGameplayCompletions((value) => value + 1);
    setGameplayInputEvents((value) => value + 1);
    setGameplayObjective(transition.next);
    markInteraction("gameplay_objective", `${gameplayObjective}->${transition.next}:${input}`);
  }, [gameplayObjective, markInteraction]);
  const toggleGameplayPause = useCallback(() => {
    setGameplayPaused((value) => {
      const next = !value;
      markInteraction("gameplay_pause", String(next));
      return next;
    });
  }, [markInteraction]);
  const resetGameplay = useCallback(() => {
    setGameplayObjective("collect");
    setGameplayScore(0);
    setGameplayCheckpoints(0);
    setGameplayCompletions(0);
    setGameplayInputEvents(0);
    setGameplayTicks(0);
    markInteraction("gameplay_reset", "collect:0:0");
  }, [markInteraction]);
  const selectAssetProfile = useCallback((profile: AssetProfile) => {
    setAssetProfile(profile);
    markInteraction("asset_profile", profile);
  }, [markInteraction]);
  const selectMaterialVariant = useCallback((variant: MaterialVariant) => {
    setMaterialVariant(variant);
    markInteraction("material_variant", variant);
  }, [markInteraction]);
  const resetAssetPolicy = useCallback(() => {
    setAssetProfile("cube");
    setMaterialVariant("cyan");
    markInteraction("asset_policy_reset", "cube:cyan");
  }, [markInteraction]);
  const saveSceneSnapshot = useCallback(() => {
    const snapshot: Phase6SceneSnapshot = {
      autoRotate,
      reducedMotion,
      cameraPreset,
      fovDegrees,
      lightingProfile,
      exposure,
      gameplayObjective,
      gameplayScore,
      gameplayCheckpoints,
      gameplayCompletions,
      gameplayInputEvents,
      gameplayTicks,
      gameplayPaused,
      assetProfile,
      materialVariant,
    };
    setSavedSnapshot(snapshot);
    setSnapshotRevision((value) => value + 1);
    setSnapshotStatus("saved");
    markInteraction("scene_snapshot_save", "react_memory:15_fields");
  }, [assetProfile, autoRotate, cameraPreset, exposure, fovDegrees, gameplayCheckpoints, gameplayCompletions, gameplayInputEvents, gameplayObjective, gameplayPaused, gameplayScore, gameplayTicks, lightingProfile, markInteraction, materialVariant, reducedMotion]);
  const loadSceneSnapshot = useCallback(() => {
    if (!savedSnapshot) return;
    setAutoRotate(savedSnapshot.autoRotate);
    setReducedMotion(savedSnapshot.reducedMotion);
    setCameraPreset(savedSnapshot.cameraPreset);
    setFovDegrees(savedSnapshot.fovDegrees);
    setLightingProfile(savedSnapshot.lightingProfile);
    setExposure(savedSnapshot.exposure);
    setGameplayObjective(savedSnapshot.gameplayObjective);
    setGameplayScore(savedSnapshot.gameplayScore);
    setGameplayCheckpoints(savedSnapshot.gameplayCheckpoints);
    setGameplayCompletions(savedSnapshot.gameplayCompletions);
    setGameplayInputEvents(savedSnapshot.gameplayInputEvents);
    setGameplayTicks(savedSnapshot.gameplayTicks);
    setGameplayPaused(savedSnapshot.gameplayPaused);
    setAssetProfile(savedSnapshot.assetProfile);
    setMaterialVariant(savedSnapshot.materialVariant);
    setResetSignal((value) => value + 1);
    setSnapshotStatus("restored");
    markInteraction("scene_snapshot_load", "react_memory:15_fields");
  }, [markInteraction, savedSnapshot]);
  const clearSceneSnapshot = useCallback(() => {
    setSavedSnapshot(null);
    setSnapshotStatus("empty");
    markInteraction("scene_snapshot_clear", "react_memory:empty");
  }, [markInteraction]);
  const createLoopbackSession = useCallback(() => {
    setNetcodeSessionActive(true);
    setNetcodeGuestConnected(false);
    setNetcodeHostReady(false);
    setNetcodeGuestReady(false);
    setNetcodeRunning(false);
    setNetcodeTicks(0);
    setNetcodePackets(0);
    setNetcodeSequence(0);
    markInteraction("netcode_session", "created:loopback");
  }, [markInteraction]);
  const joinLoopbackGuest = useCallback(() => {
    if (!netcodeSessionActive || netcodeGuestConnected) return;
    setNetcodeGuestConnected(true);
    setNetcodePackets((value) => value + 1);
    setNetcodeSequence((value) => value + 1);
    markInteraction("netcode_peer", "guest_joined");
  }, [markInteraction, netcodeGuestConnected, netcodeSessionActive]);
  const toggleNetcodeHostReady = useCallback(() => {
    if (!netcodeSessionActive) return;
    setNetcodeHostReady((value) => !value);
    setNetcodeRunning(false);
    markInteraction("netcode_ready", "host");
  }, [markInteraction, netcodeSessionActive]);
  const toggleNetcodeGuestReady = useCallback(() => {
    if (!netcodeGuestConnected) return;
    setNetcodeGuestReady((value) => !value);
    setNetcodeRunning(false);
    markInteraction("netcode_ready", "guest");
  }, [markInteraction, netcodeGuestConnected]);
  const startLoopbackLockstep = useCallback(() => {
    if (!netcodeSessionActive || !netcodeGuestConnected || !netcodeHostReady || !netcodeGuestReady) return;
    setNetcodeRunning(true);
    markInteraction("netcode_lockstep", "running");
  }, [markInteraction, netcodeGuestConnected, netcodeGuestReady, netcodeHostReady, netcodeSessionActive]);
  const advanceLoopbackTick = useCallback(() => {
    if (!netcodeRunning || !netcodeGuestConnected) return;
    setNetcodeTicks((value) => value + 1);
    setNetcodePackets((value) => value + 2);
    setNetcodeSequence((value) => value + 2);
    markInteraction("netcode_tick", "lockstep:+1");
  }, [markInteraction, netcodeGuestConnected, netcodeRunning]);
  const disconnectLoopbackGuest = useCallback(() => {
    if (!netcodeGuestConnected) return;
    setNetcodeGuestConnected(false);
    setNetcodeGuestReady(false);
    setNetcodeRunning(false);
    setNetcodeDisconnects((value) => value + 1);
    markInteraction("netcode_disconnect", "guest:fail_closed");
  }, [markInteraction, netcodeGuestConnected]);
  const closeLoopbackSession = useCallback(() => {
    setNetcodeSessionActive(false);
    setNetcodeGuestConnected(false);
    setNetcodeHostReady(false);
    setNetcodeGuestReady(false);
    setNetcodeRunning(false);
    markInteraction("netcode_session", "closed");
  }, [markInteraction]);
  const captureLeaderboardRun = useCallback(() => {
    if (gameplayCompletions <= 0) return;
    const run: LocalLeaderboardRun = {
      captureSequence: leaderboardCaptureSequence,
      score: gameplayScore,
      completions: gameplayCompletions,
    };
    setLeaderboardRuns((runs) => [...runs, run].sort(rankLocalRuns).slice(0, LEADERBOARD_MAXIMUM_ENTRIES));
    setLeaderboardCaptureSequence((sequence) => sequence + 1);
    markInteraction("local_leaderboard_capture", `L${String(run.captureSequence).padStart(3, "0")}:${run.score}:${run.completions}`);
  }, [gameplayCompletions, gameplayScore, leaderboardCaptureSequence, markInteraction]);
  const resetLeaderboard = useCallback(() => {
    setLeaderboardRuns([]);
    setLeaderboardCaptureSequence(1);
    markInteraction("local_leaderboard_reset", "volatile_top3:empty");
  }, [markInteraction]);
  const startPerformanceSampling = useCallback(() => {
    if (!Number.isFinite(stats.fps) || !Number.isFinite(stats.ms) || stats.fps <= 0 || stats.ms <= 0 || effectiveReducedMotion) return;
    performanceSamplesRef.current = [];
    setPerformanceSamples([]);
    setPerformanceResult(null);
    setPerformanceSamplingActive(true);
    markInteraction("performance_sample", "sampling:0/12");
  }, [effectiveReducedMotion, markInteraction, stats.fps, stats.ms]);
  const finishPerformanceSampling = useCallback(() => {
    if (!performanceSamplingActive || performanceSamples.length !== PERFORMANCE_SAMPLE_COUNT) return;
    const result = summarizePerformanceSamples(performanceSamples);
    setPerformanceResult(result);
    setPerformanceSamplingActive(false);
    markInteraction("performance_sample", `${result.status}:${result.sampleCount}/12`);
  }, [markInteraction, performanceSamples, performanceSamplingActive]);
  const resetPerformanceSampling = useCallback(() => {
    performanceSamplesRef.current = [];
    setPerformanceSamplingActive(false);
    setPerformanceSamples([]);
    setPerformanceResult(null);
    markInteraction("performance_sample", "idle:0/12");
  }, [markInteraction]);
  useEffect(() => {
    if (!performanceSamplingActive) return;
    const failSampling = (reason: "timeout" | "reduced_motion") => {
      const result = failPerformanceSamples(performanceSamplesRef.current, reason);
      setPerformanceResult(result);
      setPerformanceSamplingActive(false);
      markInteraction("performance_sample", `fail:${reason}:${result.sampleCount}/12`);
    };
    if (effectiveReducedMotion) {
      failSampling("reduced_motion");
      return;
    }
    if (performanceSamples.length === PERFORMANCE_SAMPLE_COUNT) return;
    const timeout = window.setTimeout(() => failSampling("timeout"), PERFORMANCE_SAMPLE_TIMEOUT_MS);
    return () => window.clearTimeout(timeout);
  }, [effectiveReducedMotion, markInteraction, performanceSamples.length, performanceSamplingActive]);
  useEffect(() => {
    if (gameplayPaused || effectiveReducedMotion) return;
    const interval = window.setInterval(() => setGameplayTicks((value) => value + 1), 1000);
    return () => window.clearInterval(interval);
  }, [effectiveReducedMotion, gameplayPaused]);
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (target && ["INPUT", "SELECT", "TEXTAREA"].includes(target.tagName)) return;
      if (event.code !== "KeyG" || event.altKey || event.ctrlKey || event.metaKey) return;
      event.preventDefault();
      completeGameplayObjective("keyboard");
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [completeGameplayObjective]);
  const toggleLayer = (c: string) => {
    setLayers((p) => {
      const next = p.includes(c) ? p.filter((x) => x !== c) : [...p, c];
      markInteraction("layer_filter", `${c}:${next.includes(c) ? "on" : "off"}`);
      return next;
    });
  };
  const toggleAgent = (a: string) => {
    setAgents((p) => {
      const next = p.includes(a) ? p.filter((x) => x !== a) : [...p, a];
      markInteraction("agent_filter", `${a}:${next.includes(a) ? "on" : "off"}`);
      return next;
    });
  };
  const visibleEvents = runtimeFeed?.events.slice(-6).reverse() ?? [];
  const visibleFrames = runtimeFeed?.frames.slice(-4).reverse() ?? [];
  const performanceStatus = performanceSamplingActive ? "sampling" : performanceResult?.status ?? "idle";
  const rendererStatsReady = Number.isFinite(stats.fps) && Number.isFinite(stats.ms) && stats.fps > 0 && stats.ms > 0;
  const runtimeSourceLabel = runtimeFeed?.live
    ? `LIVE · ${runtimeFeed.sourceKind}`
    : feed?.live
      ? `LIVE · ${feed.source}`
      : runtimeFeed
        ? `SPEC · ${runtimeFeed.sourceKind}`
        : "SPEC · ORGANISMUS";

  return (
    <div className="page-wide">
      <div className="page-head organism-head">
        <div>
          <div className="eyebrow">Cortex-Ansicht{mode !== "live" ? ` · ${MODE_LABEL[mode]}` : ""}</div>
          <h1 className="organism-title">Kollektiver Organismus</h1>
          <p className="organism-subtitle">
            Eine interaktive 3D-Live-Karte des Superbrain: ein leuchtender neuronaler Kern mit Fähigkeitszentren in Umlaufbahnen.
            Filtere nach Architekturschicht oder Agent; die Detailansicht öffnet jedes Zentrum.
          </p>
        </div>
        <div className="chips">
          <Link href="/organism" className={`chip${mode === "live" ? " active" : ""}`}>Live</Link>
          <Link href="/organism/replay" className={`chip${mode === "replay" ? " active" : ""}`}>Wiedergabe</Link>
          <Link href="/organism/map" className={`chip${mode === "map" ? " active" : ""}`}>Karte</Link>
        </div>
      </div>

      <div className="grid organism-layout-grid">
        <div className="stack stack-gap-12">
          <div
            id="organism-cortex-surface"
            className="organism-canvas-shell"
            role="region"
            aria-label="Interaktive Organismus-Szene"
            aria-describedby="phase6-accessibility-status"
            tabIndex={0}
            data-testid="phase6-accessible-scene"
          >
            <CortexLive
              runState={runState}
              nodeCount={1600}
              activeRegion={active}
              onSelectRegion={selectHub}
              interactive
              visibleLayers={layers}
              visibleAgents={agents}
              onStats={onStats}
              autoRotate={autoRotate}
              paused={effectiveReducedMotion}
              resetSignal={resetSignal}
              cameraPreset={cameraPreset}
              fovDegrees={fovDegrees}
              lightingProfile={lightingProfile}
              exposure={exposure}
              gameplayObjective={gameplayObjective}
              gameplayScore={gameplayScore}
              gameplayCheckpoints={gameplayCheckpoints}
              gameplayPaused={gameplayPaused || effectiveReducedMotion}
              gameplayTicks={gameplayTicks}
              assetProfile={assetProfile}
              materialVariant={materialVariant}
              netcodeGuestConnected={netcodeGuestConnected}
              netcodeRunning={netcodeRunning}
              netcodeSequence={netcodeSequence}
              onToggleAutoRotate={toggleAutoRotate}
              forceReducedMotion={effectiveReducedMotion}
              onMode={onMode}
              sourceLabel={runtimeSourceLabel}
            />
            {/* Debug / performance HUD overlay (frame budget = Phase-6 perf slice) */}
            <div className="org-hud" aria-hidden="true">
              <span className="mono">{stats.fps} FPS</span>
              <span className="mono">{stats.ms}ms</span>
              <span className="mono">{stats.nodes} Knoten</span>
              <span className="mono">{renderMode === "3d" ? (caps.webgpu ? "WebGPU✓" : "WebGL2") : "2D"}</span>
              {feed ? (
                <span className={`org-feed ${feed.live ? "live" : "spec"}`} title={`Datenquelle des Live-Status: ${feed.source}`}>
                  {feed.live ? `LIVE · ${feed.source}` : `SPEC · ${feed.source}`}
                </span>
              ) : null}
              {runtimeFeed ? (
                <span className={`org-feed ${runtimeFeed.live ? "live" : "spec"}`} title={`Runtime-Datenquelle: ${runtimeFeed.sourceKind}`}>
                  {runtimeFeed.live ? "EREIGNISSE · LIVE" : "EREIGNISSE · SPEC"}
                </span>
              ) : null}
            </div>
            {/* OPA gate badges overlay */}
            <div className="org-gates">
              {CLOSED_GATES.slice(0, 4).map((g) => (
                <span key={g} className="org-gate" title={`${g} Gate ist geschlossen`}>{g} · GESCHLOSSEN</span>
              ))}
            </div>
          </div>

          <div className="panel panel-pad organism-mode-bar">
            <span className="panel-title">Ausführungsstatus</span>
            <div className="state-row">
              {STATES.map((s) => (
                <button
                  key={s}
                  type="button"
                  data-testid={`organism-run-state-${s}`}
                  className={`state-btn${s === runState ? " active" : ""}`}
                  onClick={() => selectRunState(s)}
                >
                  {STATE_LABEL[s]}
                </button>
              ))}
            </div>
          </div>

          {/* Phase-6 (Scale & 3D Platform) — scene controls + capability + perf budget */}
          <div className="panel panel-pad organism-scene-bar">
            <span className="panel-title">3D-Szene</span>
            <div className="state-row">
              <button
                className={`state-btn${autoRotate && !effectiveReducedMotion ? " active" : ""}`}
                onClick={toggleAutoRotate}
                disabled={effectiveReducedMotion}
                title={effectiveReducedMotion ? "Deaktiviert, solange der Modus für weniger Bewegung aktiv ist" : "Leertaste"}
              >
                {autoRotate ? "Automatisch drehen ⏸" : "Automatisch drehen ▶"}
              </button>
              <button className="state-btn" onClick={resetCamera} title="R">Kamera zurücksetzen</button>
              <button
                type="button"
                className={`state-btn${effectiveReducedMotion ? " active" : ""}`}
                onClick={toggleReducedMotion}
                title="Schutz bei Bewegungsempfindlichkeit"
                aria-pressed={effectiveReducedMotion}
                aria-controls="organism-cortex-surface"
                data-testid="phase6-reduced-motion-toggle"
              >
                {effectiveReducedMotion ? "Weniger Bewegung ✓" : "Weniger Bewegung"}
              </button>
            </div>
            <div className="organism-camera-lighting" data-testid="phase6-camera-lighting-controls">
              <div className="organism-control-group">
                <span className="organism-control-label">Kamera</span>
                <div className="state-row" role="group" aria-label="Kamerapreset">
                  {CAMERA_PRESETS.map((preset) => (
                    <button
                      key={preset.id}
                      type="button"
                      className={`state-btn${cameraPreset === preset.id ? " active" : ""}`}
                      aria-pressed={cameraPreset === preset.id}
                      data-testid={`phase6-camera-preset-${preset.id}`}
                      onClick={() => selectCameraPreset(preset.id)}
                    >
                      {preset.label}
                    </button>
                  ))}
                </div>
              </div>
              <label className="organism-control-group organism-compact-control">
                <span className="organism-control-label">Sichtfeld</span>
                <select
                  aria-label="Sichtfeld in Grad"
                  value={fovDegrees}
                  data-testid="phase6-camera-fov"
                  onChange={(event) => selectFov(Number(event.target.value))}
                >
                  {FOV_STEPS.map((value) => <option key={value} value={value}>{value}°</option>)}
                </select>
              </label>
              <div className="organism-control-group">
                <span className="organism-control-label">Licht</span>
                <div className="state-row" role="group" aria-label="Lichtprofil">
                  {LIGHTING_PROFILES.map((profile) => (
                    <button
                      key={profile.id}
                      type="button"
                      className={`state-btn${lightingProfile === profile.id ? " active" : ""}`}
                      aria-pressed={lightingProfile === profile.id}
                      data-testid={`phase6-lighting-profile-${profile.id}`}
                      onClick={() => selectLightingProfile(profile.id)}
                    >
                      {profile.label}
                    </button>
                  ))}
                </div>
              </div>
              <label className="organism-control-group organism-exposure-control">
                <span className="organism-control-label">Belichtung</span>
                <span className="organism-range-row">
                  <input
                    id="phase6-lighting-exposure"
                    type="range"
                    aria-label="Belichtung"
                    min="0.72"
                    max="1.18"
                    step="0.02"
                    value={exposure}
                    data-testid="phase6-lighting-exposure"
                    onChange={(event) => selectExposure(Number(event.target.value))}
                  />
                  <output className="mono" htmlFor="phase6-lighting-exposure">{exposure.toFixed(2)}</output>
                </span>
              </label>
              <div
                className="organism-camera-lighting-state mono"
                data-testid="phase6-camera-lighting-state"
                aria-live="polite"
              >
                camera_preset={cameraPreset} · fov={fovDegrees}° · lighting_profile={lightingProfile} · exposure={exposure.toFixed(2)} · reset_signal={resetSignal} · local_state_only=true
              </div>
            </div>
            <div className="organism-gameplay" data-testid="phase6-gameplay-state-controls">
              <div className="organism-gameplay-heading">
                <span className="organism-control-label">Gameplay State</span>
                <span className="mono">browser-local</span>
              </div>
              <div className="organism-gameplay-hud" aria-live="polite">
                <div><span>Ziel</span><strong data-testid="phase6-gameplay-objective">{GAMEPLAY_OBJECTIVES[gameplayObjective].label}</strong></div>
                <div><span>Score</span><strong data-testid="phase6-gameplay-score">{gameplayScore}</strong></div>
                <div><span>Checkpoints</span><strong data-testid="phase6-gameplay-checkpoints">{gameplayCheckpoints}</strong></div>
                <div><span>Abgeschlossen</span><strong data-testid="phase6-gameplay-completions">{gameplayCompletions}</strong></div>
              </div>
              <div className="state-row organism-gameplay-actions">
                <button
                  type="button"
                  className="state-btn active"
                  data-testid="phase6-gameplay-complete"
                  onClick={() => completeGameplayObjective("pointer")}
                  title="Aktuelles Ziel abschliessen (G)"
                >
                  Ziel abschliessen
                </button>
                <button
                  type="button"
                  className={`state-btn${gameplayPaused ? " active" : ""}`}
                  data-testid="phase6-gameplay-pause"
                  aria-pressed={gameplayPaused}
                  onClick={toggleGameplayPause}
                >
                  {gameplayPaused ? "Loop fortsetzen" : "Loop pausieren"}
                </button>
                <button type="button" className="state-btn" data-testid="phase6-gameplay-reset" onClick={resetGameplay}>
                  Gameplay zuruecksetzen
                </button>
              </div>
              <div className="organism-gameplay-state mono" data-testid="phase6-gameplay-state" aria-live="polite">
                objective={gameplayObjective} · score={gameplayScore} · checkpoints={gameplayCheckpoints} · completions={gameplayCompletions} · input_events={gameplayInputEvents} · loop_ticks={gameplayTicks} · paused={String(gameplayPaused || effectiveReducedMotion)} · local_state_only=true
              </div>
            </div>
            <div className="organism-asset-policy" data-testid="phase6-asset-policy-controls">
              <div className="organism-gameplay-heading">
                <span className="organism-control-label">Asset Policy</span>
                <span className="mono">procedural-only</span>
              </div>
              <div className="organism-asset-policy-grid">
                <div className="organism-control-group">
                  <span className="organism-control-label">Primitive</span>
                  <div className="state-row" role="group" aria-label="Prozedurales Asset-Profil">
                    {ASSET_PROFILES.map((profile) => (
                      <button
                        key={profile.id}
                        type="button"
                        className={`state-btn${assetProfile === profile.id ? " active" : ""}`}
                        aria-pressed={assetProfile === profile.id}
                        data-testid={`phase6-asset-profile-${profile.id}`}
                        onClick={() => selectAssetProfile(profile.id)}
                      >
                        {profile.label}
                      </button>
                    ))}
                  </div>
                </div>
                <div className="organism-control-group">
                  <span className="organism-control-label">Material</span>
                  <div className="state-row" role="group" aria-label="Materialvariante">
                    {MATERIAL_VARIANTS.map((variant) => (
                      <button
                        key={variant.id}
                        type="button"
                        className={`state-btn organism-material-button${materialVariant === variant.id ? " active" : ""}`}
                        aria-pressed={materialVariant === variant.id}
                        data-testid={`phase6-material-variant-${variant.id}`}
                        onClick={() => selectMaterialVariant(variant.id)}
                      >
                        <span className="organism-material-swatch" style={{ backgroundColor: variant.color }} aria-hidden="true" />
                        {variant.label}
                      </button>
                    ))}
                  </div>
                </div>
                <button type="button" className="state-btn organism-asset-reset" data-testid="phase6-asset-policy-reset" onClick={resetAssetPolicy}>
                  Asset Policy zuruecksetzen
                </button>
              </div>
              <div className="organism-asset-manifest mono" data-testid="phase6-asset-manifest" aria-live="polite">
                asset_profile={assetProfile} · geometry={ASSET_PROFILES.find((item) => item.id === assetProfile)?.geometry} · material_variant={materialVariant} · primitives=3 · materials=3 · remote_assets=0 · uploads=0 · external_fetch=false · binary_upload=false · local_only=true
              </div>
            </div>
            <div className="organism-save-load" data-testid="phase6-save-load-controls">
              <div className="organism-gameplay-heading">
                <span className="organism-control-label">Szenen-Snapshot</span>
                <span className="mono">volatile browser-memory</span>
              </div>
              <div className="state-row organism-save-load-actions">
                <button type="button" className="state-btn active" data-testid="phase6-save-snapshot" onClick={saveSceneSnapshot}>
                  Snapshot speichern
                </button>
                <button type="button" className="state-btn" data-testid="phase6-load-snapshot" onClick={loadSceneSnapshot} disabled={!savedSnapshot}>
                  Snapshot laden
                </button>
                <button type="button" className="state-btn" data-testid="phase6-clear-snapshot" onClick={clearSceneSnapshot} disabled={!savedSnapshot}>
                  Snapshot verwerfen
                </button>
              </div>
              <div className="organism-save-load-state mono" data-testid="phase6-save-load-state" aria-live="polite">
                snapshot_status={snapshotStatus} · revision={snapshotRevision} · slots={savedSnapshot ? 1 : 0}/1 · fields=15 · storage=react_state · reload_persistence=false · local_storage=false · indexeddb=false · cookies=false · cache=false · cloud_sync=false · upload=false · network=false
              </div>
            </div>
            <div className="organism-accessibility" data-testid="phase6-accessibility-controls">
              <div className="organism-gameplay-heading">
                <span className="organism-control-label">Accessibility</span>
                <span className="mono">system-aware</span>
              </div>
              <div className="state-row organism-accessibility-actions">
                <button type="button" className="state-btn" data-testid="phase6-focus-scene" onClick={focusCortexSurface}>
                  Szene fokussieren
                </button>
              </div>
              <div
                id="phase6-accessibility-status"
                className="organism-accessibility-state mono"
                data-testid="phase6-accessibility-state"
                role="status"
                aria-live="polite"
                aria-atomic="true"
              >
                motion_mode={effectiveReducedMotion ? "reduced" : "standard"} · user_override={String(reducedMotion)} · system_preference={String(systemReducedMotion)} · render_mode={renderMode} · keyboard_navigation=true · focus_visible=true · semantic_region=true · live_region=true · local_state_only=true
              </div>
              <span className="sr-only" data-testid="phase6-accessibility-announcement">{accessibilityAnnouncement}</span>
            </div>
            <div className="organism-netcode" data-testid="phase6-netcode-controls">
              <div className="organism-gameplay-heading">
                <span className="organism-control-label">Multiplayer Loopback</span>
                <span className="mono">2 peers · browser-local</span>
              </div>
              <div className="state-row organism-netcode-actions">
                <button type="button" className="state-btn active" data-testid="phase6-netcode-create" onClick={createLoopbackSession} disabled={netcodeSessionActive}>Session erstellen</button>
                <button type="button" className="state-btn" data-testid="phase6-netcode-join" onClick={joinLoopbackGuest} disabled={!netcodeSessionActive || netcodeGuestConnected}>Guest beitreten</button>
                <button type="button" className={`state-btn${netcodeHostReady ? " active" : ""}`} data-testid="phase6-netcode-host-ready" onClick={toggleNetcodeHostReady} disabled={!netcodeSessionActive} aria-pressed={netcodeHostReady}>Host bereit</button>
                <button type="button" className={`state-btn${netcodeGuestReady ? " active" : ""}`} data-testid="phase6-netcode-guest-ready" onClick={toggleNetcodeGuestReady} disabled={!netcodeGuestConnected} aria-pressed={netcodeGuestReady}>Guest bereit</button>
                <button type="button" className="state-btn" data-testid="phase6-netcode-start" onClick={startLoopbackLockstep} disabled={!netcodeHostReady || !netcodeGuestReady || !netcodeGuestConnected}>Lockstep starten</button>
                <button type="button" className="state-btn" data-testid="phase6-netcode-tick" onClick={advanceLoopbackTick} disabled={!netcodeRunning}>Simulationsschritt</button>
                <button type="button" className="state-btn" data-testid="phase6-netcode-disconnect" onClick={disconnectLoopbackGuest} disabled={!netcodeGuestConnected}>Guest trennen</button>
                <button type="button" className="state-btn" data-testid="phase6-netcode-close" onClick={closeLoopbackSession} disabled={!netcodeSessionActive}>Session schliessen</button>
              </div>
              <div className="organism-gameplay-hud" aria-live="polite">
                <div><span>Session</span><strong data-testid="phase6-netcode-session">{netcodeSessionActive ? (netcodeRunning ? "running" : "forming") : "idle"}</strong></div>
                <div><span>Peers</span><strong data-testid="phase6-netcode-peers">{netcodeGuestConnected ? 2 : netcodeSessionActive ? 1 : 0}/2</strong></div>
                <div><span>Ticks</span><strong data-testid="phase6-netcode-ticks">{netcodeTicks}</strong></div>
                <div><span>Sequenz</span><strong data-testid="phase6-netcode-sequence">{netcodeSequence}</strong></div>
              </div>
              <div className="organism-netcode-state mono" data-testid="phase6-netcode-state" aria-live="polite">
                transport=loopback · session_active={String(netcodeSessionActive)} · guest_connected={String(netcodeGuestConnected)} · host_ready={String(netcodeHostReady)} · guest_ready={String(netcodeGuestReady)} · running={String(netcodeRunning)} · ticks={netcodeTicks} · packets={netcodePackets} · sequence={netcodeSequence} · disconnects={netcodeDisconnects} · websocket=false · server_sync=false · public_lobby=false · local_only=true
              </div>
            </div>
            <div
              className="organism-scoreboard-performance"
              data-testid="phase6-scoreboard-performance-controls"
              data-sync="false"
              data-storage="false"
              data-network="false"
            >
              <section className="organism-local-scoreboard" aria-labelledby="phase6-local-scoreboard-title">
                <div className="organism-gameplay-heading">
                  <span id="phase6-local-scoreboard-title" className="organism-control-label">Lokale Bestenliste</span>
                  <span className="mono">Top 3 · volatile</span>
                </div>
                <div className="state-row organism-scoreboard-actions">
                  <button
                    type="button"
                    className="state-btn active"
                    data-testid="phase6-leaderboard-capture"
                    onClick={captureLeaderboardRun}
                    disabled={gameplayCompletions <= 0}
                  >
                    Run erfassen
                  </button>
                  <button
                    type="button"
                    className="state-btn"
                    data-testid="phase6-leaderboard-reset"
                    onClick={resetLeaderboard}
                    disabled={leaderboardRuns.length === 0}
                  >
                    Bestenliste leeren
                  </button>
                </div>
                <ol
                  className="organism-leaderboard-list"
                  data-testid="phase6-leaderboard-list"
                  aria-label="Top drei lokale Gameplay-Runs"
                  aria-describedby="phase6-leaderboard-order"
                >
                  {leaderboardRuns.length === 0 ? (
                    <li className="organism-leaderboard-empty">Noch keine Runs erfasst</li>
                  ) : leaderboardRuns.map((run, index) => (
                    <li
                      key={run.captureSequence}
                      className="organism-leaderboard-entry"
                      data-run-id={`L${String(run.captureSequence).padStart(3, "0")}`}
                      data-capture-sequence={run.captureSequence}
                      data-score={run.score}
                      data-completions={run.completions}
                    >
                      <strong className="organism-leaderboard-rank">#{index + 1}</strong>
                      <span className="mono organism-leaderboard-id">L{String(run.captureSequence).padStart(3, "0")}</span>
                      <span><small>Score</small><strong>{run.score}</strong></span>
                      <span><small>Ziele</small><strong>{run.completions}</strong></span>
                    </li>
                  ))}
                </ol>
                <span id="phase6-leaderboard-order" className="sr-only">
                  Sortierung nach Score absteigend, abgeschlossenen Zielen absteigend und Erfassungsfolge aufsteigend.
                </span>
                <div className="organism-scoreboard-state mono" data-testid="phase6-leaderboard-state" role="status" aria-live="polite">
                  entries={leaderboardRuns.length}/3 · sort=score_desc,completions_desc,capture_sequence_asc · sync=false · storage=false · network=false · local_only=true
                </div>
              </section>
              <section className="organism-performance-sample" aria-labelledby="phase6-performance-sample-title">
                <div className="organism-gameplay-heading">
                  <span id="phase6-performance-sample-title" className="organism-control-label">Performance-Stichprobe</span>
                  <span className="mono">12 Samples · client-only</span>
                </div>
                <div className="state-row organism-performance-actions">
                  <button
                    type="button"
                    className="state-btn active"
                    data-testid="phase6-performance-start"
                    onClick={startPerformanceSampling}
                    disabled={performanceSamplingActive || !rendererStatsReady || effectiveReducedMotion}
                  >
                    Messung starten
                  </button>
                  <button
                    type="button"
                    className="state-btn"
                    data-testid="phase6-performance-finish"
                    onClick={finishPerformanceSampling}
                    disabled={!performanceSamplingActive || performanceSamples.length !== PERFORMANCE_SAMPLE_COUNT}
                  >
                    Messung abschliessen
                  </button>
                  <button
                    type="button"
                    className="state-btn"
                    data-testid="phase6-performance-reset"
                    onClick={resetPerformanceSampling}
                    disabled={performanceStatus === "idle" && performanceSamples.length === 0}
                  >
                    Messung leeren
                  </button>
                </div>
                <div className="organism-performance-metrics" aria-live="polite">
                  <div><span>Aktuell</span><strong>{stats.fps} FPS</strong></div>
                  <div><span>Frame-Intervall</span><strong>{stats.ms} ms</strong></div>
                  <div><span>Samples</span><strong>{performanceSamples.length}/12</strong></div>
                  <div><span>Budget</span><strong>≥25 FPS · ≤40 ms</strong></div>
                </div>
                <div
                  className="organism-performance-state mono"
                  data-testid="phase6-performance-state"
                  data-samples={JSON.stringify(performanceSamples)}
                  role="status"
                  aria-live="polite"
                >
                  status={performanceStatus} · reason={performanceResult?.reason ?? "none"} · samples={performanceSamples.length}/12 · source=existing_renderer_stats · frame_ms=derived_from_fps · arithmetic_mean=true · rounding=1_decimal · min_fps=25 · max_ms=40 · timeout_ms=20000 · renderer_ready={String(rendererStatsReady)} · gpu_benchmark=false · evidence=local_interaction · capacity_claim=false · scale_claim=false · network=false · local_only=true
                </div>
                <output
                  className={`organism-performance-result ${performanceResult ? performanceResult.status : "idle"}`}
                  data-testid="phase6-performance-result"
                  data-result={performanceStatus}
                  data-reason={performanceResult?.reason ?? "none"}
                  data-sample-count={performanceResult?.sampleCount ?? 0}
                  data-average-fps={performanceResult?.averageFps.toFixed(1) ?? "0.0"}
                  data-average-ms={performanceResult?.averageMs.toFixed(1) ?? "0.0"}
                  aria-live="polite"
                >
                  {performanceResult
                    ? `${performanceResult.status.toUpperCase()} · ${performanceResult.sampleCount} Samples · Ø ${performanceResult.averageFps.toFixed(1)} FPS · Ø ${performanceResult.averageMs.toFixed(1)} ms Frame-Intervall · ${performanceResult.reason ?? "budget_met"} · kein GPU-Benchmark`
                    : performanceSamplingActive
                      ? `SAMPLING · ${performanceSamples.length}/12`
                      : "IDLE · keine abgeschlossene Stichprobe"}
                </output>
              </section>
            </div>
            <span className="cap-badge" title={`Renderer: ${caps.gpu}`}>
              <span className={`cap-dot ${caps.webgpu ? "gpu" : caps.webgl2 ? "ok" : "soft"}`} />
              {renderMode === "2d" ? "2D-Fallback" : caps.webgpu ? "WebGPU verfügbar · WebGL2 aktiv" : "WebGL2"}
            </span>
            <span className="mono organism-fps">
              {stats.fps} FPS · {stats.ms} ms/Frame
            </span>
            <span className="mono organism-hints">
              Tastatur: ←→ rotieren · ↑↓ kippen · +/- zoomen · R zurücksetzen · Leertaste automatisch drehen · G Ziel abschliessen
            </span>
            <span className="mono organism-hints">
              GPU-sicher: 30-FPS-Limit · Energiesparmodus · pausiert automatisch im Hintergrund/außerhalb des Sichtfelds · „Weniger Bewegung“ friert die Szene ein
            </span>
            <pre className="goalb-result mono organism-action-result" data-testid="batch1-organism-action-result" aria-live="polite">
              {interactionStatus}
            </pre>
          </div>

          <div className="panel panel-pad">
            <div className="row organism-filters-row">
              <div>
                <div className="panel-title mb-6">Schichtfilter</div>
                <div className="chip-wrap">
                  {LAYERS.map((l) => (
                    <button
                      key={l.code}
                      className={`filter-chip layer-chip layer-${l.code}${layers.includes(l.code) ? " on" : ""}`}
                      onClick={() => toggleLayer(l.code)}
                    >
                      L{l.no} {l.code}
                    </button>
                  ))}
                </div>
              </div>
              <div>
                <div className="panel-title mb-6">Agentenfilter</div>
                <div className="chip-wrap">
                  {ORGANISM_AGENTS.map((a) => (
                    <button
                      key={a}
                      className={`filter-chip${agents.includes(a) ? " on" : ""}`}
                      onClick={() => toggleAgent(a)}
                    >
                      {a}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        <aside className="stack">
          <section
            className="panel organism-runtime-feed"
            data-testid="organism-runtime-feed"
            data-source-kind={runtimeFeed?.sourceKind ?? "loading"}
            data-live={runtimeFeed?.live ? "true" : "false"}
            data-run-id={runtimeFeed?.runId ?? ""}
          >
            <div className="panel-head">
              <span className="panel-title">Runtime-Ereignisse</span>
              <span className={`org-feed ${runtimeFeed?.live ? "live" : "spec"}`}>
                {runtimeFeed?.sourceKind ?? "loading"}
              </span>
            </div>
            <div className="runtime-meta">
              <span className="mono">{runtimeFeed?.events.length ?? 0} Ereignisse</span>
              <span className="mono">{runtimeFeed?.frames.length ?? 0} Frames</span>
              <span className="mono">{runtimeFeed?.replayAvailable ? "replay_available=true" : "replay_available=false"}</span>
              {runtimeFeed?.runId ? <span className="mono">run_id={runtimeFeed.runId}</span> : null}
            </div>
            <div className="runtime-list">
              {visibleEvents.length ? visibleEvents.map((event, index) => (
                <div key={`${event.seq ?? index}-${event.kind ?? event.event_type ?? "event"}`} className="runtime-event-row">
                  <span className="runtime-event-dot" />
                  <div>
                    <div className="runtime-event-title">
                      <span>{event.kind ?? event.event_type ?? "runtime_event"}</span>
                      <span className="mono">{event.hub ?? "workbench"}</span>
                    </div>
                    <div className="runtime-event-meta">
                      <span className="mono">{event.run_state ?? "executing"}</span>
                      <span className="mono">{event.severity ?? "info"}</span>
                      <span className="mono">{event.source_kind ?? runtimeFeed?.sourceKind ?? "spec_only"}</span>
                    </div>
                  </div>
                </div>
              )) : (
                <div className="runtime-empty">Runtime-Feed wird geladen</div>
              )}
            </div>
            {mode === "replay" ? (
              <div className="runtime-frames" data-testid="organism-replay-frames">
                {visibleFrames.map((frame, index) => (
                  <div
                    key={`${runtimeFeed?.runId ?? "runtime"}-${(runtimeFeed?.frames.length ?? visibleFrames.length) - 1 - index}`}
                    className="runtime-frame-row"
                  >
                    <span className="mono">{Number(frame.t ?? 0).toFixed(1)}s</span>
                    <span>{frame.active?.join(", ") || "idle"}</span>
                    <span className="mono">{frame.run_state ?? "idle"}</span>
                  </div>
                ))}
              </div>
            ) : null}
            <div className="runtime-guard">
              <span>nur lesende Audit-Projektion</span>
              <span>keine Rohdetails</span>
            </div>
          </section>

          <section className="panel">
            <div className="panel-head"><span className="panel-title">Fähigkeitszentren</span></div>
            <div className="legend legend-pad">
              {HUBS.map((h) => (
                <button key={h.id} className={`lg-row${h.id === active ? " active" : ""}`} onClick={() => selectHub(h.id)}>
                  <span className={`lg-dot hub-dot hub-${h.id}`} />
                  <span>{HUB_LABEL_DE[h.id] ?? h.label}</span>
                  {feed?.hubs[h.id] === "active" ? <span className="lg-pip ml-auto" title="Feed: aktiv" /> : null}
                  <span className={`lg-cap ${feed?.hubs[h.id] === "active" ? "ml-6" : "ml-auto"}`}>L{LAYERS.find((l) => l.code === h.layer)?.no}</span>
                </button>
              ))}
            </div>
          </section>

          {hub ? (
            <section className="panel panel-pad">
              <div className="panel-title mb-8">Inspektion</div>
              <div className="row align-center gap-8">
                <span className={`lg-dot hub-dot hub-${hub.id}`} />
                <h3 className="organism-hub-title">{HUB_LABEL_DE[hub.id] ?? hub.label}</h3>
              </div>
              <p className="organism-hub-desc">{HUB_DESC[hub.id]}</p>
              <p className="inspect-label">Agenten</p>
              <div className="chip-wrap">
                {hub.agents.map((a) => <span key={a} className="tool-chip mono">{a}</span>)}
              </div>
              <Link href={hub.route} className="btn btn-sm mt-12">{HUB_LABEL_DE[hub.id] ?? hub.label} öffnen →</Link>
            </section>
          ) : null}

          <div className="note">
            Datengetrieben, niemals vorgetäuscht live. Der Live-Status kommt aus{" "}
            <span className="mono">/api/v1/organism/live-state</span>; Ereignisse und Wiedergaben kommen aus{" "}
            <span className="mono">/api/v1/organism/events</span> und{" "}
            <span className="mono">/api/v1/organism/replay</span>. LLM bleibt an das Gateway gebunden; Schreibzugriffe sind durch Gates geschützt.
          </div>
        </aside>
      </div>
    </div>
  );
}
