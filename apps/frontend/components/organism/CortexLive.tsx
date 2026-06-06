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

export default function CortexLive(props: Props) {
  const [mode, setMode] = useState<"pending" | "2d" | "3d">("pending");
  const { forceReducedMotion, onMode } = props;

  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches || !!forceReducedMotion;
    let webgl2 = false;
    try {
      webgl2 = !!document.createElement("canvas").getContext("webgl2");
    } catch {
      webgl2 = false;
    }
    const next = webgl2 && !reduced ? "3d" : "2d";
    setMode(next);
    onMode?.(next);
  }, [forceReducedMotion, onMode]);

  if (mode === "pending") return <div className={`cortex-wrap ${props.className ?? ""}`} />;

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
        />
      </GLErrorBoundary>
    );
  }

  return <CortexCanvas {...props} />;
}
