"use client";

/*
 * Cloud Superbrain — Collective Organism (industrial GPU path, R3F + three.js).
 *
 * Glowing neural brain at the centre (multi-layer additive particle cloud) with
 * a PBR core mesh (GLB asset slot, procedural fallback) and 8 capability hubs
 * orbiting it. Hubs are PBR nodes (emissive + metalness) lit by a procedural
 * HDR-style environment (Lightformers, no external file), connected by glowing
 * tubes with data pulses. Post: Bloom + Vignette + Depth-of-Field. Layer/agent
 * filters hide hubs; an FPS/particle HUD reports via onStats. Data-driven by
 * runState / activeRegion. CortexCanvas (2D) is the reduced-motion fallback.
 */

import { useMemo, useRef, useState, useEffect, useCallback, memo, Suspense, Component, type CSSProperties, type ReactNode } from "react";
import { Canvas, useFrame, useThree, type ThreeEvent } from "@react-three/fiber";
import { Edges, Environment, Html, Lightformer, MeshTransmissionMaterial, OrbitControls, PerspectiveCamera, useGLTF } from "@react-three/drei";
import { EffectComposer, Bloom, Vignette } from "@react-three/postprocessing";
import * as THREE from "three";
import { HUBS, STATE_COLOR, STATE_LABEL, type RunState } from "./regionMap";
import { useRenderActive } from "../../lib/useRenderActive";

// GPU-safety: caps the render loop to ~30 FPS via R3F demand mode + throttled
// invalidate, and only runs while `active` (visible tab + on-screen + not paused).
// OrbitControls still invalidates on user interaction. This stops the GPU from
// being pinned at full framerate (or running at all in a background tab).
const SAFE_FPS = 30;
function FrameThrottle({ active }: { active: boolean }) {
  const invalidate = useThree((s) => s.invalidate);
  useEffect(() => {
    if (!active) return;
    const interval = setInterval(() => invalidate(), 1000 / SAFE_FPS);
    return () => clearInterval(interval);
  }, [active, invalidate]);
  return null;
}

/** Single source of truth for the 3D palette — mirrors the CSS design tokens
 *  (--cyan/--violet/--magenta/--blue/--bg) so the cortex never drifts from the UI. */
const ORGANISM_COLORS = {
  cyan: "#00e5ff",
  violet: "#8b5cf6",
  magenta: "#ec4899",
  blue: "#3b82f6",
  ice: "#36d3ff",
  coreGlow: "#eafbff",
  bg: "#04060d",
} as const;

type CameraPreset = "wide" | "close" | "top";
type LightingProfile = "studio" | "night" | "sunrise";
type GameplayObjective = "collect" | "checkpoint" | "survive";
type AssetProfile = "cube" | "beacon" | "ring";
type MaterialVariant = "cyan" | "amber" | "rose";

type VisualTelemetry = {
  sourceKind: string;
  live: boolean;
  eventCount: number;
  frameCount: number;
  renderFps: number;
  renderMs: number;
  samples: number[];
};

const EMPTY_VISUAL_TELEMETRY: VisualTelemetry = {
  sourceKind: "loading",
  live: false,
  eventCount: 0,
  frameCount: 0,
  renderFps: 0,
  renderMs: 0,
  samples: [0],
};

const CAMERA_PRESETS: Record<CameraPreset, { position: [number, number, number]; target: [number, number, number] }> = {
  wide: { position: [0, 0.6, 7], target: [0, 0, 0] },
  close: { position: [0, 0.35, 5], target: [0, 0, 0] },
  top: { position: [0.2, 6.8, 1.4], target: [0, 0, 0] },
};

const LIGHTING_PROFILES: Record<LightingProfile, {
  ambient: number;
  key: number;
  fill: number;
  bloom: number;
  keyColor: string;
  leftColor: string;
  rightColor: string;
}> = {
  studio: {
    ambient: 0.35,
    key: 9,
    fill: 7,
    bloom: 1.25,
    keyColor: ORGANISM_COLORS.cyan,
    leftColor: ORGANISM_COLORS.violet,
    rightColor: ORGANISM_COLORS.magenta,
  },
  night: {
    ambient: 0.2,
    key: 6.4,
    fill: 5.2,
    bloom: 1.05,
    keyColor: ORGANISM_COLORS.ice,
    leftColor: ORGANISM_COLORS.blue,
    rightColor: ORGANISM_COLORS.violet,
  },
  sunrise: {
    ambient: 0.42,
    key: 8.2,
    fill: 6.2,
    bloom: 1.38,
    keyColor: "#f59e0b",
    leftColor: "#fb7185",
    rightColor: "#a78bfa",
  },
};

const GAMEPLAY_BEACONS: Record<GameplayObjective, { color: string; position: [number, number, number] }> = {
  collect: { color: ORGANISM_COLORS.cyan, position: [-2.4, 0.4, 0.8] },
  checkpoint: { color: "#f59e0b", position: [0, 2.15, 0.35] },
  survive: { color: ORGANISM_COLORS.magenta, position: [2.4, 0.4, 0.8] },
};
const ASSET_MATERIALS: Record<MaterialVariant, string> = {
  cyan: ORGANISM_COLORS.cyan,
  amber: "#f59e0b",
  rose: "#fb7185",
};

type CameraAppliedState = {
  preset: CameraPreset;
  fov: number;
  position: string;
  framingScale: number;
};

type LightingAppliedState = {
  profile: LightingProfile;
  exposure: number;
};

function seededUnit(seed: number) {
  const value = Math.sin(seed * 12.9898) * 43758.5453;
  return value - Math.floor(value);
}

function stringSeed(value: string) {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

const MATRIX_COLUMNS = Array.from({ length: 18 }, (_, index) => {
  const alphabet = "01A7C9EF";
  let glyphs = "";
  for (let glyphIndex = 0; glyphIndex < 14; glyphIndex += 1) {
    const pick = Math.floor(seededUnit(index * 37 + glyphIndex + 1) * alphabet.length);
    glyphs += alphabet[pick];
  }
  return {
    glyphs: glyphs.split("").join("\n"),
    left: 2 + index * (96 / 17),
    delay: seededUnit(index + 101) * 5.5,
    duration: 4.8 + seededUnit(index + 211) * 4.2,
    opacity: 0.18 + seededUnit(index + 307) * 0.34,
  };
});

function useGlow() {
  return useMemo(() => {
    const s = 128;
    const c = document.createElement("canvas");
    c.width = c.height = s;
    const ctx = c.getContext("2d");
    if (ctx) {
      const g = ctx.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
      g.addColorStop(0, "rgba(255,255,255,1)");
      g.addColorStop(0.25, "rgba(255,255,255,0.55)");
      g.addColorStop(0.55, "rgba(255,255,255,0.14)");
      g.addColorStop(1, "rgba(255,255,255,0)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, s, s);
    }
    const t = new THREE.CanvasTexture(c);
    t.needsUpdate = true;
    return t;
  }, []);
}

/** True only on a real hardware GPU — software GL (SwiftShader/llvmpipe) can't
 *  afford PBR + IBL in real time, so we fall back to the verifiable basic path. */
function detectHardwareGPU(): boolean {
  try {
    // Explicit override (?gpu=force|on enables PBR, ?gpu=off|basic forces basic).
    // Lets power users force the premium path and lets tests prove both paths.
    if (typeof window !== "undefined") {
      const q = new URLSearchParams(window.location.search).get("gpu");
      if (q === "force" || q === "on") return true;
      if (q === "off" || q === "basic") return false;
    }
    // Automation/headless (Playwright/CI sets navigator.webdriver) → basic path,
    // which renders verifiably under software GL. Real browsers get PBR + IBL.
    if (typeof navigator !== "undefined" && navigator.webdriver) return false;
    const c = document.createElement("canvas");
    const gl = (c.getContext("webgl2") || c.getContext("webgl")) as WebGLRenderingContext | null;
    if (!gl) return false;
    const dbg = gl.getExtension("WEBGL_debug_renderer_info");
    if (!dbg) return false;
    const r = String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) || "").toLowerCase();
    if (/swiftshader|software|llvmpipe|basic render|microsoft|google/.test(r)) return false;
    // Enable PBR only on a recognised hardware GPU vendor.
    return /nvidia|geforce|rtx|gtx|radeon|amd|intel|iris|uhd|apple|m1|m2|m3|adreno|mali|powervr|metal/.test(r);
  } catch {
    return false;
  }
}

/** PBR node on hardware GPUs (reflective, env-lit) · emissive basic in software.
 *  `on` sharpens the highlight (lower roughness) when a node is active. */
const NodeMaterial = memo(function NodeMaterial({
  color,
  pbr,
  emissive = 1.4,
  on = false,
}: {
  color: string;
  pbr: boolean;
  emissive?: number;
  on?: boolean;
}) {
  if (pbr) {
    return <meshStandardMaterial color={color} emissive={color} emissiveIntensity={emissive} metalness={0.75} roughness={on ? 0.15 : 0.24} />;
  }
  return <meshBasicMaterial color={color} toneMapped={false} />;
});

function useBrain(count: number) {
  return useMemo(() => {
    const pos = new Float32Array(count * 3);
    const col = new Float32Array(count * 3);
    const cyan = new THREE.Color(ORGANISM_COLORS.cyan);
    const violet = new THREE.Color(ORGANISM_COLORS.violet);
    const magenta = new THREE.Color(ORGANISM_COLORS.magenta);
    const tmp = new THREE.Color();
    const golden = Math.PI * (3 - Math.sqrt(5));
    for (let i = 0; i < count; i++) {
      const y = 1 - (i / (count - 1)) * 2;
      const r = Math.sqrt(Math.max(0, 1 - y * y));
      const th = golden * i;
      const rad = 0.66 + 0.34 * Math.sqrt(seededUnit(i + 1));
      let x = Math.cos(th) * r * rad * 1.28;
      const z = Math.sin(th) * r * rad * 0.96;
      const yy = y * rad * 0.96;
      x += x > 0 ? 0.08 : -0.08;
      const n = (Math.sin(x * 5) + Math.cos(z * 4) + Math.sin(yy * 6)) * 0.03;
      pos[i * 3] = x * (1 + n);
      pos[i * 3 + 1] = yy * (1 + n);
      pos[i * 3 + 2] = z * (1 + n);
      const cc = (yy + 1) / 2;
      if (cc < 0.5) tmp.copy(cyan).lerp(violet, cc * 2);
      else tmp.copy(violet).lerp(magenta, (cc - 0.5) * 2);
      col[i * 3] = tmp.r;
      col[i * 3 + 1] = tmp.g;
      col[i * 3 + 2] = tmp.b;
    }
    const line: number[] = [];
    for (let i = 0; i < count; i++) {
      let conn = 0;
      for (let j = i + 1; j < count && conn < 2; j++) {
        const dx = pos[i * 3] - pos[j * 3];
        const dy = pos[i * 3 + 1] - pos[j * 3 + 1];
        const dz = pos[i * 3 + 2] - pos[j * 3 + 2];
        if (dx * dx + dy * dy + dz * dz < 0.035) {
          line.push(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2], pos[j * 3], pos[j * 3 + 1], pos[j * 3 + 2]);
          conn++;
        }
      }
    }
    return { pos, col, line: new Float32Array(line) };
  }, [count]);
}

function Brain({ count, tex }: { count: number; tex: THREE.Texture }) {
  const { pos, col, line } = useBrain(count);
  const g = useRef<THREE.Group>(null);
  useFrame((s, dt) => {
    if (g.current) {
      g.current.rotation.y += dt * 0.12;
      g.current.scale.setScalar(1.34 * (1 + Math.sin(s.clock.elapsedTime * 0.8) * 0.018));
    }
  });
  return (
    <group ref={g}>
      <points>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[pos, 3]} />
          <bufferAttribute attach="attributes-color" args={[col, 3]} />
        </bufferGeometry>
        <pointsMaterial map={tex} size={0.085} vertexColors transparent opacity={0.95} sizeAttenuation depthWrite={false} blending={THREE.AdditiveBlending} />
      </points>
      <lineSegments>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[line, 3]} />
        </bufferGeometry>
        <lineBasicMaterial color={ORGANISM_COLORS.ice} transparent opacity={0.09} blending={THREE.AdditiveBlending} depthWrite={false} />
      </lineSegments>
    </group>
  );
}

/** Real GLB core asset at /organism/core.glb (faceted crystalline icosphere).
 *  Rendered with NodeMaterial so software GL gets the verifiable basic path and
 *  hardware GPUs get full PBR. Falls back to procedural geometry on load failure. */
const CORE_GLB = "/organism/core.glb";

function CoreCrystalMaterial({ pbr, color }: { pbr: boolean; color: string }) {
  if (!pbr) {
    return <meshBasicMaterial color={color} transparent opacity={0.82} toneMapped={false} />;
  }
  return (
    <MeshTransmissionMaterial
      color={color}
      emissive={color}
      emissiveIntensity={0.48}
      transmission={0.78}
      thickness={0.58}
      roughness={0.18}
      chromaticAberration={0.018}
      anisotropy={0.08}
      distortion={0.08}
      distortionScale={0.16}
      temporalDistortion={0.015}
      samples={3}
      resolution={128}
      transparent
      opacity={0.92}
    />
  );
}

function CrystalGLB({ pbr, color }: { pbr: boolean; color: string }) {
  const gltf = useGLTF(CORE_GLB);
  const geometry = useMemo(() => {
    let g: THREE.BufferGeometry | null = null;
    gltf.scene.traverse((o) => {
      const m = o as THREE.Mesh;
      if (m.isMesh && m.geometry && !g) g = m.geometry as THREE.BufferGeometry;
    });
    return g;
  }, [gltf]);
  if (!geometry) return <ProceduralCrystal pbr={pbr} color={color} />;
  return (
    <mesh geometry={geometry}>
      <CoreCrystalMaterial color={color} pbr={pbr} />
      <Edges threshold={16} color={ORGANISM_COLORS.coreGlow} lineWidth={0.7} transparent opacity={0.5} />
    </mesh>
  );
}

function ProceduralCrystal({ pbr, color }: { pbr: boolean; color: string }) {
  return (
    <mesh>
      <icosahedronGeometry args={[1, 4]} />
      <CoreCrystalMaterial color={color} pbr={pbr} />
      <Edges threshold={16} color={ORGANISM_COLORS.coreGlow} lineWidth={0.7} transparent opacity={0.5} />
    </mesh>
  );
}

/** Render-error boundary: if the GLB fails to load/parse, show procedural geometry. */
class CrystalBoundary extends Component<{ fallback: ReactNode; children: ReactNode }, { failed: boolean }> {
  constructor(props: { fallback: ReactNode; children: ReactNode }) {
    super(props);
    this.state = { failed: false };
  }
  static getDerivedStateFromError() {
    return { failed: true };
  }
  render() {
    return this.state.failed ? this.props.fallback : this.props.children;
  }
}

/** Central core: real GLB crystal + reactor rings + multi-layer additive glow. */
function Core({ color, tex, pbr }: { color: string; tex: THREE.Texture; pbr: boolean }) {
  const halo = useRef<THREE.Sprite>(null);
  const shell = useRef<THREE.Mesh>(null);
  const core = useRef<THREE.Group>(null);
  const ringA = useRef<THREE.Mesh>(null);
  const ringB = useRef<THREE.Mesh>(null);
  useFrame((s, dt) => {
    const p = 1 + Math.sin(s.clock.elapsedTime * 1.7) * 0.13;
    if (core.current) {
      core.current.scale.setScalar(0.3 * p);
      core.current.rotation.y += dt * 0.18;
    }
    if (halo.current) halo.current.scale.setScalar(3.1 * p);
    if (shell.current) shell.current.rotation.y -= dt * 0.25;
    if (ringA.current) ringA.current.rotation.z += dt * 0.6;
    if (ringB.current) {
      ringB.current.rotation.x += dt * 0.5;
      ringB.current.rotation.y += dt * 0.3;
    }
  });
  // Core glows ice-white but tints toward the run-state colour (state-coherent).
  const coreColor = useMemo(
    () => new THREE.Color(color).lerp(new THREE.Color(ORGANISM_COLORS.coreGlow), 0.55).getStyle(),
    [color],
  );
  const procedural = <ProceduralCrystal pbr={pbr} color={coreColor} />;
  return (
    <group>
      <sprite scale={5.4}>
        <spriteMaterial map={tex} color={color} transparent opacity={0.16} blending={THREE.AdditiveBlending} depthWrite={false} />
      </sprite>
      <sprite ref={halo}>
        <spriteMaterial map={tex} color={color} transparent opacity={0.5} blending={THREE.AdditiveBlending} depthWrite={false} />
      </sprite>
      {/* Faceted wireframe shell around the asset */}
      <mesh ref={shell} scale={0.62}>
        <icosahedronGeometry args={[1, 1]} />
        <meshBasicMaterial color={color} wireframe transparent opacity={0.5} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
      {/* Reactor energy rings */}
      <mesh ref={ringA} rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[0.72, 0.01, 8, 96]} />
        <meshBasicMaterial color={color} transparent opacity={0.55} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
      <mesh ref={ringB}>
        <torusGeometry args={[0.88, 0.008, 8, 96]} />
        <meshBasicMaterial color={ORGANISM_COLORS.ice} transparent opacity={0.4} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
      {/* Real GLB crystal core (procedural fallback on load failure) */}
      <group ref={core}>
        <CrystalBoundary fallback={procedural}>
          <Suspense fallback={procedural}>
            <CrystalGLB pbr={pbr} color={coreColor} />
          </Suspense>
        </CrystalBoundary>
      </group>
    </group>
  );
}

function Hub({
  hub,
  active,
  onSelect,
  showLabel,
  visible,
  tex,
  pbr,
}: {
  hub: (typeof HUBS)[number];
  active?: string;
  onSelect?: (id: string) => void;
  showLabel: boolean;
  visible: boolean;
  tex: THREE.Texture;
  pbr: boolean;
}) {
  const end = useMemo(() => new THREE.Vector3(hub.pos[0], hub.pos[1], hub.pos[2]), [hub.pos]);
  const curve = useMemo(() => {
    const mid = end.clone().multiplyScalar(0.55);
    mid.z += end.z >= 0 ? -0.55 : 0.55;
    return new THREE.QuadraticBezierCurve3(new THREE.Vector3(0, 0, 0), mid, end);
  }, [end]);
  const pulse = useRef<THREE.Sprite>(null);
  const pulse2 = useRef<THREE.Sprite>(null);
  const node = useRef<THREE.Mesh>(null);
  const ring = useRef<THREE.Mesh>(null);
  const t = useRef(seededUnit(stringSeed(hub.id)));
  const [hover, setHover] = useState(false);
  const on = active === hub.id || hover;

  useEffect(() => {
    document.body.style.cursor = hover ? "pointer" : "auto";
    return () => {
      document.body.style.cursor = "auto";
    };
  }, [hover]);

  useFrame((s, dt) => {
    t.current = (t.current + dt * 0.3) % 1;
    if (pulse.current) {
      const p = curve.getPoint(1 - t.current);
      pulse.current.position.set(p.x, p.y, p.z);
      (pulse.current.material as THREE.SpriteMaterial).opacity = 0.5 + Math.sin(t.current * Math.PI) * 0.5;
    }
    if (pulse2.current) {
      const p = curve.getPoint(t.current);
      pulse2.current.position.set(p.x, p.y, p.z);
      (pulse2.current.material as THREE.SpriteMaterial).opacity = 0.3 + Math.sin(t.current * Math.PI) * 0.3;
    }
    if (ring.current) ring.current.rotation.z += dt * 1.3;
    if (node.current) {
      node.current.rotation.y += dt * 0.5;
      node.current.scale.setScalar((on ? 1.25 : 1) * (1 + Math.sin(s.clock.elapsedTime * 2.4 + end.x * 2) * 0.05));
    }
  });

  if (!visible) return null;

  return (
    <group>
      <mesh>
        <tubeGeometry args={[curve, 48, 0.013, 8, false]} />
        <meshBasicMaterial color={hub.color} transparent opacity={on ? 0.75 : 0.32} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
      <sprite ref={pulse} scale={0.32}>
        <spriteMaterial map={tex} color={hub.color} transparent opacity={0.9} blending={THREE.AdditiveBlending} depthWrite={false} />
      </sprite>
      <sprite ref={pulse2} scale={0.2}>
        <spriteMaterial map={tex} color={ORGANISM_COLORS.coreGlow} transparent opacity={0.5} blending={THREE.AdditiveBlending} depthWrite={false} />
      </sprite>
      <group position={[end.x, end.y, end.z]}>
        <sprite scale={on ? 0.95 : 0.7}>
          <spriteMaterial map={tex} color={hub.color} transparent opacity={0.85} blending={THREE.AdditiveBlending} depthWrite={false} />
        </sprite>
        {/* PBR hub node */}
        <mesh
          ref={node}
          onClick={(e: ThreeEvent<MouseEvent>) => {
            e.stopPropagation();
            onSelect?.(hub.id);
          }}
          onPointerOver={(e: ThreeEvent<PointerEvent>) => {
            e.stopPropagation();
            setHover(true);
          }}
          onPointerOut={() => setHover(false)}
        >
          <icosahedronGeometry args={[0.15, 0]} />
          <NodeMaterial color={hub.color} pbr={pbr} emissive={on ? 2.0 : 1.4} on={on} />
        </mesh>
        <mesh ref={ring} rotation={[Math.PI / 2, 0, 0]}>
          <torusGeometry args={[0.24, 0.007, 6, 40]} />
          <meshBasicMaterial color={hub.color} transparent opacity={on ? 0.7 : 0.4} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
        </mesh>
        {showLabel ? (
          <Html center distanceFactor={9} position={[0, 0.36, 0]} className="cortex3d-html" zIndexRange={[20, 0]}>
            <div className={`hub3d-label${on ? " active" : ""}`}>{hub.label}</div>
          </Html>
        ) : null}
      </group>
    </group>
  );
}

function Stars({ tex }: { tex: THREE.Texture }) {
  const pos = useMemo(() => {
    const n = 420;
    const p = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      const r = 7 + seededUnit(i + 1) * 9;
      const th = seededUnit(i + 421) * Math.PI * 2;
      const ph = Math.acos(2 * seededUnit(i + 841) - 1);
      p[i * 3] = r * Math.sin(ph) * Math.cos(th);
      p[i * 3 + 1] = r * Math.sin(ph) * Math.sin(th);
      p[i * 3 + 2] = r * Math.cos(ph);
    }
    return p;
  }, []);
  return (
    <points>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[pos, 3]} />
      </bufferGeometry>
      <pointsMaterial map={tex} color="#3b82f6" size={0.07} transparent opacity={0.5} sizeAttenuation depthWrite={false} blending={THREE.AdditiveBlending} />
    </points>
  );
}

/** Fibonacci-sphere dot globe: a cheap geometry-only orbit marker that keeps the
 *  reference-video silhouette without introducing another texture or shader. */
function DotGlobe({ color, paused }: { color: string; paused: boolean }) {
  const globe = useRef<THREE.Group>(null);
  const positions = useMemo(() => {
    const count = 360;
    const points = new Float32Array(count * 3);
    const golden = Math.PI * (3 - Math.sqrt(5));
    for (let index = 0; index < count; index += 1) {
      const y = 1 - (index / (count - 1)) * 2;
      const radius = Math.sqrt(Math.max(0, 1 - y * y));
      const theta = golden * index;
      points[index * 3] = Math.cos(theta) * radius;
      points[index * 3 + 1] = y;
      points[index * 3 + 2] = Math.sin(theta) * radius;
    }
    return points;
  }, []);
  useFrame((_, delta) => {
    if (!globe.current || paused) return;
    globe.current.rotation.y += delta * 0.16;
    globe.current.rotation.x += delta * 0.025;
  });
  return (
    <group ref={globe} name="organism-visual-dot-globe" position={[2.75, -1.28, -0.75]} scale={0.72} rotation={[0.22, 0, -0.18]}>
      <points>
        <bufferGeometry>
          <bufferAttribute attach="attributes-position" args={[positions, 3]} />
        </bufferGeometry>
        <pointsMaterial color={color} size={0.035} transparent opacity={0.72} sizeAttenuation depthWrite={false} blending={THREE.AdditiveBlending} />
      </points>
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[1.02, 0.008, 6, 96]} />
        <meshBasicMaterial color={ORGANISM_COLORS.ice} transparent opacity={0.16} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
      <mesh rotation={[0, Math.PI / 2, 0]}>
        <torusGeometry args={[1.02, 0.008, 6, 96]} />
        <meshBasicMaterial color={color} transparent opacity={0.12} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>
    </group>
  );
}

/** Low-opacity glass shards frame the core. They are deterministic, non-
 *  interactive planes and stay below the particle/label interaction layer. */
function Shards({ color, paused }: { color: string; paused: boolean }) {
  const group = useRef<THREE.Group>(null);
  const transforms = useMemo(() => Array.from({ length: 12 }, (_, index) => {
    const side = index % 2 === 0 ? -1 : 1;
    return {
      position: [
        side * (1.65 + seededUnit(index + 701) * 2.1),
        -2.25 + seededUnit(index + 733) * 4.5,
        -1.8 + seededUnit(index + 769) * 2.4,
      ] as [number, number, number],
      rotation: [
        seededUnit(index + 797) * Math.PI,
        seededUnit(index + 823) * Math.PI,
        seededUnit(index + 859) * Math.PI,
      ] as [number, number, number],
      scale: 0.45 + seededUnit(index + 887) * 0.9,
    };
  }), []);
  useFrame((state, delta) => {
    if (!group.current || paused) return;
    group.current.rotation.y += delta * 0.018;
    group.current.position.y = Math.sin(state.clock.elapsedTime * 0.22) * 0.08;
  });
  return (
    <group ref={group} name="organism-visual-shards">
      {transforms.map((transform, index) => (
        <mesh key={index} position={transform.position} rotation={transform.rotation} scale={transform.scale}>
          <planeGeometry args={[0.58, 1.55]} />
          <meshBasicMaterial
            color={index % 3 === 0 ? ORGANISM_COLORS.violet : color}
            transparent
            opacity={0.06}
            side={THREE.DoubleSide}
            toneMapped={false}
            blending={THREE.AdditiveBlending}
            depthWrite={false}
          />
        </mesh>
      ))}
    </group>
  );
}

function Stats({ onStats, nodes }: { onStats?: (fps: number, nodes: number, ms: number) => void; nodes: number }) {
  const acc = useRef(0);
  const frames = useRef(0);
  useFrame((_, dt) => {
    acc.current += dt;
    frames.current += 1;
    if (acc.current >= 0.5) {
      const fps = Math.round(frames.current / acc.current);
      onStats?.(fps, nodes, fps > 0 ? Math.round((1000 / fps) * 10) / 10 : 0);
      acc.current = 0;
      frames.current = 0;
    }
  });
  return null;
}

/** Phase-6 camera rig: preset/FOV application plus the bounded keyboard loop. */
function CameraRig({
  interactive,
  autoRotate,
  resetSignal,
  cameraPreset,
  fovDegrees,
  onToggleAutoRotate,
  onApplied,
}: {
  interactive: boolean;
  autoRotate: boolean;
  resetSignal: number;
  cameraPreset: CameraPreset;
  fovDegrees: number;
  onToggleAutoRotate?: () => void;
  onApplied?: (state: CameraAppliedState) => void;
}) {
  const controls = useRef<React.ComponentRef<typeof OrbitControls>>(null);
  const { camera } = useThree();
  const size = useThree((state) => state.size);
  const preset = CAMERA_PRESETS[cameraPreset];
  const aspect = size.width / Math.max(1, size.height);
  const framingScale = aspect < 0.8 ? Math.min(2, 1.1 / Math.max(0.55, aspect)) : 1;
  const framedPosition = useMemo(
    () => preset.position.map((value) => value * framingScale) as [number, number, number],
    [framingScale, preset.position],
  );

  useEffect(() => {
    onApplied?.({
      preset: cameraPreset,
      fov: fovDegrees,
      position: framedPosition.map((value) => value.toFixed(2)).join(","),
      framingScale,
    });
  }, [cameraPreset, fovDegrees, framedPosition, framingScale, onApplied]);

  useEffect(() => {
    if (!interactive) return;
    const onKey = (e: KeyboardEvent) => {
      const c = controls.current;
      if (!c) return;
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA") return;
      const dolly = (factor: number) => {
        const t = c.target;
        const d = Math.min(12, Math.max(4.5, camera.position.distanceTo(t) * factor));
        camera.position.sub(t).setLength(d).add(t);
        c.update();
      };
      switch (e.key) {
        case "ArrowLeft": c.setAzimuthalAngle(c.getAzimuthalAngle() - 0.12); c.update(); break;
        case "ArrowRight": c.setAzimuthalAngle(c.getAzimuthalAngle() + 0.12); c.update(); break;
        case "ArrowUp": c.setPolarAngle(Math.max(Math.PI * 0.2, c.getPolarAngle() - 0.1)); c.update(); break;
        case "ArrowDown": c.setPolarAngle(Math.min(Math.PI * 0.8, c.getPolarAngle() + 0.1)); c.update(); break;
        case "+": case "=": dolly(0.88); break;
        case "-": case "_": dolly(1.14); break;
        case "r": case "R": c.reset(); break;
        case " ": onToggleAutoRotate?.(); break;
        default: return;
      }
      e.preventDefault();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [interactive, camera, onToggleAutoRotate]);

  return (
    <>
      <PerspectiveCamera
        key={`camera-${cameraPreset}-${fovDegrees}-${framingScale.toFixed(3)}-${resetSignal}`}
        makeDefault
        position={framedPosition}
        fov={fovDegrees}
        near={0.1}
        far={100}
      />
      <OrbitControls
        key={`controls-${cameraPreset}-${resetSignal}`}
        ref={controls}
        target={preset.target}
        enablePan={false}
        enableZoom={interactive}
        enableRotate={interactive}
        autoRotate={autoRotate}
        autoRotateSpeed={0.5}
        minDistance={4.5}
        maxDistance={14}
        minPolarAngle={cameraPreset === "top" ? Math.PI * 0.05 : Math.PI * 0.2}
        maxPolarAngle={Math.PI * 0.8}
      />
    </>
  );
}

function LightingRig({
  profile,
  exposure,
  onApplied,
}: {
  profile: LightingProfile;
  exposure: number;
  onApplied?: (state: LightingAppliedState) => void;
}) {
  const renderer = useThree((state) => state.gl);
  const invalidate = useThree((state) => state.invalidate);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  useEffect(() => {
    rendererRef.current = renderer;
  }, [renderer]);
  useEffect(() => {
    const current = rendererRef.current;
    if (!current) return;
    current.toneMapping = THREE.ACESFilmicToneMapping;
    current.toneMappingExposure = exposure;
    invalidate();
    onApplied?.({ profile, exposure });
  }, [exposure, invalidate, onApplied, profile]);
  return null;
}

function hubVisible(hub: (typeof HUBS)[number], layers?: string[], agents?: string[]) {
  if (layers && layers.length && !layers.includes(hub.layer)) return false;
  if (agents && agents.length && !hub.agents.some((a) => agents.includes(a))) return false;
  return true;
}

function GameplayBeacon({ objective, paused }: { objective: GameplayObjective; paused: boolean }) {
  const group = useRef<THREE.Group>(null);
  const beacon = GAMEPLAY_BEACONS[objective];
  useFrame((state, delta) => {
    if (!group.current || paused) return;
    group.current.rotation.y += delta * 0.8;
    group.current.position.y = beacon.position[1] + Math.sin(state.clock.elapsedTime * 1.8) * 0.08;
  });
  return (
    <group ref={group} position={beacon.position}>
      <mesh>
        <octahedronGeometry args={[0.16, 0]} />
        <meshBasicMaterial color={beacon.color} toneMapped={false} />
      </mesh>
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[0.28, 0.025, 8, 32]} />
        <meshBasicMaterial color={beacon.color} transparent opacity={0.7} toneMapped={false} />
      </mesh>
    </group>
  );
}

function AssetPolicyPreview({
  profile,
  variant,
  paused,
  pbr,
}: {
  profile: AssetProfile;
  variant: MaterialVariant;
  paused: boolean;
  pbr: boolean;
}) {
  const preview = useRef<THREE.Group>(null);
  const color = ASSET_MATERIALS[variant];
  useFrame((state, delta) => {
    if (!preview.current || paused) return;
    preview.current.rotation.y += delta * 0.55;
    preview.current.rotation.x = Math.sin(state.clock.elapsedTime * 0.55) * 0.12;
  });
  return (
    <group ref={preview} position={[0, -1.65, 0.55]}>
      <mesh>
        {profile === "cube" ? <boxGeometry args={[0.34, 0.34, 0.34]} /> : null}
        {profile === "beacon" ? <coneGeometry args={[0.25, 0.52, 6]} /> : null}
        {profile === "ring" ? <torusGeometry args={[0.25, 0.07, 12, 36]} /> : null}
        <NodeMaterial color={color} pbr={pbr} emissive={1.65} on />
      </mesh>
      <mesh rotation={[Math.PI / 2, 0, 0]} position={[0, -0.31, 0]}>
        <ringGeometry args={[0.23, 0.33, 40]} />
        <meshBasicMaterial color={color} transparent opacity={0.24} side={THREE.DoubleSide} toneMapped={false} />
      </mesh>
    </group>
  );
}

function LoopbackPeer({ connected, running, sequence, paused }: { connected: boolean; running: boolean; sequence: number; paused: boolean }) {
  const peer = useRef<THREE.Group>(null);
  useFrame((state, delta) => {
    if (!peer.current || paused || !connected) return;
    peer.current.rotation.y += delta * (running ? 1.1 : 0.35);
    peer.current.position.y = -1.15 + Math.sin(state.clock.elapsedTime * 1.4 + sequence * 0.1) * 0.06;
  });
  if (!connected) return null;
  const color = running ? "#22c55e" : "#8b5cf6";
  return (
    <group ref={peer} position={[1.15, -1.15, 0.65]}>
      <mesh>
        <icosahedronGeometry args={[0.2, 1]} />
        <meshBasicMaterial color={color} toneMapped={false} />
      </mesh>
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[0.32, 0.025, 8, 32]} />
        <meshBasicMaterial color={color} transparent opacity={0.65} toneMapped={false} />
      </mesh>
    </group>
  );
}

function MatrixRain({ paused }: { paused: boolean }) {
  return (
    <div
      className={`cortex-matrix-rain${paused ? " is-paused" : ""}`}
      data-testid="organism-matrix-rain"
      aria-hidden="true"
    >
      {MATRIX_COLUMNS.map((column, index) => (
        <span
          key={index}
          className="cortex-matrix-column"
          style={{
            left: `${column.left}%`,
            animationDelay: `-${column.delay.toFixed(2)}s`,
            animationDuration: `${column.duration.toFixed(2)}s`,
            opacity: column.opacity,
          } as CSSProperties}
        >
          {column.glyphs}
        </span>
      ))}
    </div>
  );
}

function TelemetryWaveform({ telemetry }: { telemetry: VisualTelemetry }) {
  const samples = telemetry.samples
    .filter((sample) => Number.isFinite(sample))
    .slice(-24)
    .map((sample) => Math.min(1, Math.max(0, sample)));
  const bounded = samples.length === 0 ? [0, 0] : samples.length === 1 ? [samples[0], samples[0]] : samples;
  const points = bounded.map((sample, index) => {
    const x = (index / (bounded.length - 1)) * 100;
    const y = 34 - sample * 28;
    return `${x.toFixed(2)},${y.toFixed(2)}`;
  }).join(" ");
  const source = telemetry.sourceKind.replace(/[^A-Za-z0-9_.:-]/g, "_").slice(0, 32) || "unknown";
  return (
    <div
      className={`cortex-telemetry-waveform${telemetry.live ? " is-live" : ""}`}
      data-testid="organism-telemetry-waveform"
      data-telemetry-source={source}
      data-telemetry-live={String(telemetry.live)}
      data-event-count={telemetry.eventCount}
      data-frame-count={telemetry.frameCount}
      data-render-fps={telemetry.renderFps.toFixed(1)}
      data-render-ms={telemetry.renderMs.toFixed(1)}
      data-sample-count={bounded.length}
      role="img"
      aria-label={`${telemetry.live ? "Live" : "Spec-only"} telemetry waveform: ${telemetry.eventCount} events, ${telemetry.frameCount} replay frames, ${telemetry.renderFps.toFixed(0)} FPS`}
    >
      <div className="cortex-waveform-label">
        <span>{telemetry.live ? "LIVE SIGNAL" : "SPEC SIGNAL"}</span>
        <span>{telemetry.eventCount}E · {telemetry.frameCount}F</span>
      </div>
      <svg viewBox="0 0 100 40" preserveAspectRatio="none" aria-hidden="true">
        <line x1="0" y1="34" x2="100" y2="34" className="cortex-waveform-baseline" />
        <polyline points={points} className="cortex-waveform-signal" />
      </svg>
    </div>
  );
}

function VisualOverlay({
  telemetry,
  paused,
  runState,
  pbr,
}: {
  telemetry: VisualTelemetry;
  paused: boolean;
  runState: RunState;
  pbr: boolean;
}) {
  return (
    <div
      className={`cortex-visual-v2${paused ? " is-paused" : ""}`}
      data-testid="organism-visual-v2"
      data-visual-dot-globe="fibonacci-360"
      data-visual-matrix-rain="dom"
      data-visual-scanlines="hud"
      data-visual-shards="plane-12-opacity-0.06"
      data-visual-waveform="runtime-telemetry"
      data-visual-core-edges="active"
      data-visual-core-transmission={pbr ? "active" : "hardware-gated"}
    >
      <MatrixRain paused={paused} />
      <div className="cortex-scanlines" data-testid="organism-scanlines" aria-hidden="true" />
      <div className="cortex-visual-hud" data-testid="organism-hud-overlay" aria-hidden="true">
        <span className="cortex-hud-corner cortex-hud-corner-nw" />
        <span className="cortex-hud-corner cortex-hud-corner-ne" />
        <span className="cortex-hud-corner cortex-hud-corner-sw" />
        <span className="cortex-hud-corner cortex-hud-corner-se" />
        <span className="cortex-hud-axis cortex-hud-axis-x" />
        <span className="cortex-hud-axis cortex-hud-axis-y" />
        <span className="cortex-hud-readout">CORTEX // {STATE_LABEL[runState].toUpperCase()}</span>
      </div>
      <TelemetryWaveform telemetry={telemetry} />
    </div>
  );
}

function Scene({
  runState,
  nodeCount,
  active,
  onSelect,
  interactive,
  showLabels,
  visibleLayers,
  visibleAgents,
  onStats,
  pbr,
  autoRotate,
  paused,
  resetSignal,
  cameraPreset,
  fovDegrees,
  lightingProfile,
  exposure,
  gameplayObjective,
  gameplayPaused,
  assetProfile,
  materialVariant,
  netcodeGuestConnected,
  netcodeRunning,
  netcodeSequence,
  onToggleAutoRotate,
  onCameraApplied,
  onLightingApplied,
}: {
  runState: RunState;
  nodeCount: number;
  active?: string;
  onSelect?: (id: string) => void;
  interactive: boolean;
  showLabels: boolean;
  visibleLayers?: string[];
  visibleAgents?: string[];
  onStats?: (fps: number, nodes: number, ms: number) => void;
  pbr: boolean;
  autoRotate: boolean;
  paused: boolean;
  resetSignal: number;
  cameraPreset: CameraPreset;
  fovDegrees: number;
  lightingProfile: LightingProfile;
  exposure: number;
  gameplayObjective: GameplayObjective;
  gameplayPaused: boolean;
  assetProfile: AssetProfile;
  materialVariant: MaterialVariant;
  netcodeGuestConnected: boolean;
  netcodeRunning: boolean;
  netcodeSequence: number;
  onToggleAutoRotate?: () => void;
  onCameraApplied?: (state: CameraAppliedState) => void;
  onLightingApplied?: (state: LightingAppliedState) => void;
}) {
  const tex = useGlow();
  const sc = STATE_COLOR[runState];
  const lighting = LIGHTING_PROFILES[lightingProfile];
  return (
    <>
      <color attach="background" args={[ORGANISM_COLORS.bg]} />
      <fog attach="fog" args={[ORGANISM_COLORS.bg, 6.5, 15]} />
      <LightingRig profile={lightingProfile} exposure={exposure} onApplied={onLightingApplied} />
      {pbr ? (
        <>
          <ambientLight intensity={lighting.ambient * exposure} />
          <pointLight position={[0, 3.5, 3]} intensity={lighting.key * exposure} distance={14} color={lighting.keyColor} />
          <pointLight position={[-4, -2, 2.5]} intensity={lighting.fill * exposure} distance={14} color={lighting.leftColor} />
          <pointLight position={[4, -2, 2.5]} intensity={lighting.fill * exposure} distance={14} color={lighting.rightColor} />
          <Environment resolution={128} frames={1}>
            <Lightformer form="circle" intensity={3 * exposure} color={lighting.keyColor} position={[0, 3, 2]} scale={3} />
            <Lightformer form="circle" intensity={2.4 * exposure} color={lighting.leftColor} position={[-3, -1, 2]} scale={2.5} />
            <Lightformer form="circle" intensity={2.4 * exposure} color={lighting.rightColor} position={[3, -1, 2]} scale={2.5} />
          </Environment>
        </>
      ) : null}
      <Stars tex={tex} />
      <Shards color={sc} paused={paused} />
      <DotGlobe color={sc} paused={paused} />
      <Stats onStats={onStats} nodes={nodeCount} />
      <group rotation={[0.32, 0, 0]}>
        <Brain count={nodeCount} tex={tex} />
        <Core color={sc} tex={tex} pbr={pbr} />
        {HUBS.map((h) => (
          <Hub key={h.id} hub={h} active={active} onSelect={onSelect} showLabel={showLabels} visible={hubVisible(h, visibleLayers, visibleAgents)} tex={tex} pbr={pbr} />
        ))}
      </group>
      <GameplayBeacon objective={gameplayObjective} paused={gameplayPaused} />
      <AssetPolicyPreview profile={assetProfile} variant={materialVariant} paused={paused} pbr={pbr} />
      <LoopbackPeer connected={netcodeGuestConnected} running={netcodeRunning} sequence={netcodeSequence} paused={paused} />
      <CameraRig
        interactive={interactive}
        autoRotate={autoRotate && !paused}
        resetSignal={resetSignal}
        cameraPreset={cameraPreset}
        fovDegrees={fovDegrees}
        onToggleAutoRotate={onToggleAutoRotate}
        onApplied={onCameraApplied}
      />
      <EffectComposer>
        <Bloom intensity={lighting.bloom * exposure} luminanceThreshold={0.18} luminanceSmoothing={0.6} mipmapBlur radius={0.75} />
        <Vignette eskil={false} offset={0.25} darkness={0.85} />
      </EffectComposer>
    </>
  );
}

export default function CortexCanvas3D({
  runState = "planning",
  nodeCount = 1500,
  activeRegion,
  onSelectRegion,
  interactive = true,
  showRegions = true,
  visibleLayers,
  visibleAgents,
  onStats,
  autoRotate = false,
  paused = false,
  resetSignal = 0,
  cameraPreset = "wide",
  fovDegrees = 45,
  lightingProfile = "studio",
  exposure = 1,
  gameplayObjective = "collect",
  gameplayScore = 0,
  gameplayCheckpoints = 0,
  gameplayPaused = false,
  gameplayTicks = 0,
  assetProfile = "cube",
  materialVariant = "cyan",
  netcodeGuestConnected = false,
  netcodeRunning = false,
  netcodeSequence = 0,
  onToggleAutoRotate,
  sourceLabel = "SPEC · ORGANISM",
  visualTelemetry = EMPTY_VISUAL_TELEMETRY,
  onReady,
}: {
  runState?: RunState;
  nodeCount?: number;
  activeRegion?: string;
  onSelectRegion?: (id: string) => void;
  interactive?: boolean;
  showRegions?: boolean;
  visibleLayers?: string[];
  visibleAgents?: string[];
  onStats?: (fps: number, nodes: number, ms: number) => void;
  autoRotate?: boolean;
  paused?: boolean;
  resetSignal?: number;
  cameraPreset?: CameraPreset;
  fovDegrees?: number;
  lightingProfile?: LightingProfile;
  exposure?: number;
  gameplayObjective?: GameplayObjective;
  gameplayScore?: number;
  gameplayCheckpoints?: number;
  gameplayPaused?: boolean;
  gameplayTicks?: number;
  assetProfile?: AssetProfile;
  materialVariant?: MaterialVariant;
  netcodeGuestConnected?: boolean;
  netcodeRunning?: boolean;
  netcodeSequence?: number;
  onToggleAutoRotate?: () => void;
  sourceLabel?: string;
  visualTelemetry?: VisualTelemetry;
  onReady?: () => void;
}) {
  const boundedFov = [38, 45, 58].includes(fovDegrees) ? fovDegrees : 45;
  const boundedExposure = Math.min(1.18, Math.max(0.72, exposure));
  const [pbr] = useState(() => detectHardwareGPU());
  const [cameraApplied, setCameraApplied] = useState<CameraAppliedState>({ preset: cameraPreset, fov: boundedFov, position: "pending", framingScale: 1 });
  const [lightingApplied, setLightingApplied] = useState<LightingAppliedState>({ profile: lightingProfile, exposure: boundedExposure });
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const onScreen = useRenderActive(wrapRef);
  const renderActive = onScreen && !paused;
  const onCameraApplied = useCallback((state: CameraAppliedState) => setCameraApplied(state), []);
  const onLightingApplied = useCallback((state: LightingAppliedState) => setLightingApplied(state), []);
  useEffect(() => {
    // Preload the GLB only when the 3D canvas actually mounts (not at import time,
    // so the 2D reduced-motion / no-WebGL path never triggers the fetch).
    useGLTF.preload(CORE_GLB);
  }, []);
  return (
    <div
      className="cortex-wrap"
      ref={wrapRef}
      data-camera-preset={cameraApplied.preset}
      data-camera-fov={cameraApplied.fov}
      data-camera-position={cameraApplied.position}
      data-camera-framing-scale={cameraApplied.framingScale.toFixed(3)}
      data-lighting-profile={lightingApplied.profile}
      data-tone-exposure={lightingApplied.exposure.toFixed(2)}
      data-camera-lighting-local-only="true"
      data-gameplay-objective={gameplayObjective}
      data-gameplay-score={gameplayScore}
      data-gameplay-checkpoints={gameplayCheckpoints}
      data-gameplay-paused={String(gameplayPaused)}
      data-gameplay-ticks={gameplayTicks}
      data-gameplay-local-only="true"
      data-asset-profile={assetProfile}
      data-material-variant={materialVariant}
      data-asset-catalog-count="3"
      data-material-variant-count="3"
      data-remote-asset-count="0"
      data-uploaded-asset-count="0"
      data-external-asset-fetch="false"
      data-binary-asset-upload="false"
      data-asset-policy-local-only="true"
      data-netcode-transport="loopback"
      data-netcode-guest-connected={String(netcodeGuestConnected)}
      data-netcode-running={String(netcodeRunning)}
      data-netcode-sequence={netcodeSequence}
      data-netcode-websocket="false"
      data-netcode-server-sync="false"
      data-organism-visual-version="v2"
      data-visual-telemetry-source={visualTelemetry.sourceKind}
    >
      <Canvas
        camera={{ position: CAMERA_PRESETS[cameraPreset].position, fov: boundedFov }}
        dpr={[1, 1.5]}
        frameloop="demand"
        gl={{ antialias: true, alpha: false, powerPreference: "low-power" }}
        className="cortex3d-canvas"
        onCreated={onReady}
      >
        <FrameThrottle active={renderActive} />
        <Scene
          runState={runState}
          nodeCount={nodeCount}
          active={activeRegion}
          onSelect={onSelectRegion}
          interactive={interactive}
          showLabels={showRegions}
          visibleLayers={visibleLayers}
          visibleAgents={visibleAgents}
          onStats={onStats}
          pbr={pbr}
          autoRotate={autoRotate}
          paused={paused}
          resetSignal={resetSignal}
          cameraPreset={cameraPreset}
          fovDegrees={boundedFov}
          lightingProfile={lightingProfile}
          exposure={boundedExposure}
          gameplayObjective={gameplayObjective}
          gameplayPaused={gameplayPaused}
          assetProfile={assetProfile}
          materialVariant={materialVariant}
          netcodeGuestConnected={netcodeGuestConnected}
          netcodeRunning={netcodeRunning}
          netcodeSequence={netcodeSequence}
          onToggleAutoRotate={onToggleAutoRotate}
          onCameraApplied={onCameraApplied}
          onLightingApplied={onLightingApplied}
        />
      </Canvas>
      <VisualOverlay telemetry={visualTelemetry} paused={paused} runState={runState} pbr={pbr} />
      <span className="cortex-badge">{sourceLabel} · {pbr ? "PBR/WEBGL" : "WEBGL"}</span>
      <span className="cortex-state">
        <span className={`dot dot-state-${runState}`} />
        {STATE_LABEL[runState]}
      </span>
    </div>
  );
}
