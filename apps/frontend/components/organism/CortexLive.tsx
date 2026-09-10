"use client";

/*
 * Cortex surface selector: render the real GPU path (CortexCanvas3D, WebGL2)
 * when the browser supports it and motion is allowed; otherwise fall back to the
 * dependency-free 2D CortexCanvas. A GL error boundary also falls back at runtime
 * so a WebGL failure can never blank the surface.
 */

import dynamic from "next/dynamic";
import { Component, type ReactNode, useCallback, useEffect, useRef, useState } from "react";
import CortexCanvas from "./CortexCanvas";
import type { RunState } from "./regionMap";

function CortexLoadingSurface() {
  return (
    <div
      className="cortex-wrap"
      data-testid="organism-renderer-pending"
      data-renderer-state="loading"
      data-renderer-loading-fallback="neutral"
      aria-hidden="true"
    />
  );
}

export type OrganismVisualTelemetry = {
  sourceKind: string;
  live: boolean;
  eventCount: number;
  frameCount: number;
  renderFps: number;
  renderMs: number;
  samples: number[];
};

const CortexCanvas3D = dynamic(() => import("./CortexCanvas3D"), {
  ssr: false,
  loading: CortexLoadingSurface,
});

type Props = {
  runState?: RunState;
  nodeCount?: number;
  activeRegion?: string;
  onSelectRegion?: (id: string) => void;
  interactive?: boolean;
  showRegions?: boolean;
  className?: string;
  visibleLayers?: string[];
  visibleAgents?: string[];
  onStats?: (fps: number, nodes: number, ms: number) => void;
  autoRotate?: boolean;
  paused?: boolean;
  resetSignal?: number;
  cameraPreset?: "wide" | "close" | "top";
  fovDegrees?: number;
  lightingProfile?: "studio" | "night" | "sunrise";
  exposure?: number;
  gameplayObjective?: "collect" | "checkpoint" | "survive";
  gameplayScore?: number;
  gameplayCheckpoints?: number;
  gameplayPaused?: boolean;
  gameplayTicks?: number;
  assetProfile?: "cube" | "beacon" | "ring";
  materialVariant?: "cyan" | "amber" | "rose";
  netcodeGuestConnected?: boolean;
  netcodeRunning?: boolean;
  netcodeSequence?: number;
  onToggleAutoRotate?: () => void;
  forceReducedMotion?: boolean;
  onMode?: (mode: "2d" | "3d") => void;
  sourceLabel?: string;
  visualTelemetry?: OrganismVisualTelemetry;
};

class GLErrorBoundary extends Component<{
  fallback: ReactNode;
  children: ReactNode;
  onFallback: () => void;
}, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  componentDidCatch() {
    this.props.onFallback();
  }
  render() {
    return this.state.failed ? this.props.fallback : this.props.children;
  }
}

function detectMode(forceReducedMotion?: boolean): "2d" | "3d" {
  if (forceReducedMotion) return "2d";
  if (typeof window === "undefined" || typeof document === "undefined") return "2d";
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduced) return "2d";
  try {
    return document.createElement("canvas").getContext("webgl2") ? "3d" : "2d";
  } catch {
    return "2d";
  }
}

export default function CortexLive(props: Props) {
  const { forceReducedMotion, onMode } = props;
  const [mode, setMode] = useState<"pending" | "2d" | "3d">("pending");
  const modeRef = useRef(mode);
  const readyFrameRef = useRef<number | null>(null);

  useEffect(() => {
    modeRef.current = mode;
  }, [mode]);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => setMode(detectMode(forceReducedMotion)));
    return () => window.cancelAnimationFrame(frame);
  }, [forceReducedMotion]);

  useEffect(() => {
    if (mode === "2d") onMode?.("2d");
    if (mode !== "3d" && readyFrameRef.current !== null) {
      window.cancelAnimationFrame(readyFrameRef.current);
      readyFrameRef.current = null;
    }
  }, [mode, onMode]);

  useEffect(() => () => {
    if (readyFrameRef.current !== null) window.cancelAnimationFrame(readyFrameRef.current);
  }, []);

  const handle3dReady = useCallback(() => {
    if (readyFrameRef.current !== null) window.cancelAnimationFrame(readyFrameRef.current);
    readyFrameRef.current = window.requestAnimationFrame(() => {
      readyFrameRef.current = null;
      if (modeRef.current === "3d") onMode?.("3d");
    });
  }, [onMode]);

  if (mode === "pending") {
    return <CortexLoadingSurface />;
  }

  if (mode === "3d") {
    return (
      <GLErrorBoundary fallback={<CortexCanvas {...props} />} onFallback={() => setMode("2d")}>
        <CortexCanvas3D
          runState={props.runState}
          nodeCount={props.nodeCount}
          activeRegion={props.activeRegion}
          onSelectRegion={props.onSelectRegion}
          interactive={props.interactive}
          showRegions={props.showRegions}
          visibleLayers={props.visibleLayers}
          visibleAgents={props.visibleAgents}
          onStats={props.onStats}
          autoRotate={props.autoRotate}
          paused={props.paused}
          resetSignal={props.resetSignal}
          cameraPreset={props.cameraPreset}
          fovDegrees={props.fovDegrees}
          lightingProfile={props.lightingProfile}
          exposure={props.exposure}
          gameplayObjective={props.gameplayObjective}
          gameplayScore={props.gameplayScore}
          gameplayCheckpoints={props.gameplayCheckpoints}
          gameplayPaused={props.gameplayPaused}
          gameplayTicks={props.gameplayTicks}
          assetProfile={props.assetProfile}
          materialVariant={props.materialVariant}
          netcodeGuestConnected={props.netcodeGuestConnected}
          netcodeRunning={props.netcodeRunning}
          netcodeSequence={props.netcodeSequence}
          onToggleAutoRotate={props.onToggleAutoRotate}
          sourceLabel={props.sourceLabel}
          visualTelemetry={props.visualTelemetry}
          onReady={handle3dReady}
        />
      </GLErrorBoundary>
    );
  }

  return <CortexCanvas {...props} />;
}
