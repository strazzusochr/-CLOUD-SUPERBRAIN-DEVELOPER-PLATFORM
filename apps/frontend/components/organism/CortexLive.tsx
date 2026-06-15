"use client";

/*
 * Cortex surface selector: render the real GPU path (CortexCanvas3D, WebGL2)
 * when the browser supports it and motion is allowed; otherwise fall back to the
 * dependency-free 2D CortexCanvas. A GL error boundary also falls back at runtime
 * so a WebGL failure can never blank the surface.
 */

import dynamic from "next/dynamic";
import { Component, type ReactNode, useEffect, useState } from "react";
import CortexCanvas from "./CortexCanvas";
import type { RunState } from "./regionMap";

const CortexCanvas3D = dynamic(() => import("./CortexCanvas3D"), {
  ssr: false,
  loading: () => <div className="cortex-wrap" />,
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
  onToggleAutoRotate?: () => void;
  forceReducedMotion?: boolean;
  onMode?: (mode: "2d" | "3d") => void;
  sourceLabel?: string;
};

class GLErrorBoundary extends Component<{ fallback: ReactNode; children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
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
  const [mode, setMode] = useState<"2d" | "3d">("2d");

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      setMode(detectMode(forceReducedMotion));
    });
    return () => window.cancelAnimationFrame(frame);
  }, [forceReducedMotion]);

  useEffect(() => {
    onMode?.(mode);
  }, [mode, onMode]);

  if (mode === "3d") {
    return (
      <GLErrorBoundary fallback={<CortexCanvas {...props} />}>
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
          onToggleAutoRotate={props.onToggleAutoRotate}
          sourceLabel={props.sourceLabel}
        />
      </GLErrorBoundary>
    );
  }

  return <CortexCanvas {...props} />;
}
