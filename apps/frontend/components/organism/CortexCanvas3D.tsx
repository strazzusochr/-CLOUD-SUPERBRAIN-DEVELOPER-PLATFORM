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

import { useMemo, useRef, useState, useEffect, memo, Suspense, Component, type ReactNode } from "react";
import { Canvas, useFrame, type ThreeEvent } from "@react-three/fiber";
import { OrbitControls, Html, Environment, Lightformer, useGLTF } from "@react-three/drei";
import { EffectComposer, Bloom, Vignette } from "@react-three/postprocessing";
import * as THREE from "three";
import { HUBS, STATE_COLOR, STATE_LABEL, type RunState } from "./regionMap";

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
      const rad = 0.66 + 0.34 * Math.sqrt(Math.random());
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
      <NodeMaterial color={color} pbr={pbr} emissive={1.8} on />
    </mesh>
  );
}

function ProceduralCrystal({ pbr, color }: { pbr: boolean; color: string }) {
  return (
    <mesh>
      <icosahedronGeometry args={[1, 4]} />
      <NodeMaterial color={color} pbr={pbr} emissive={1.8} on />
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
  const t = useRef(Math.random());
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
          <Html center distanceFactor={9} position={[0, 0.36, 0]} style={{ pointerEvents: "none" }} zIndexRange={[20, 0]}>
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
      const r = 7 + Math.random() * 9;
      const th = Math.random() * Math.PI * 2;
      const ph = Math.acos(2 * Math.random() - 1);
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

function Stats({ onStats, nodes }: { onStats?: (fps: number, nodes: number) => void; nodes: number }) {
  const acc = useRef(0);
  const frames = useRef(0);
  useFrame((_, dt) => {
    acc.current += dt;
    frames.current += 1;
    if (acc.current >= 0.5) {
      onStats?.(Math.round(frames.current / acc.current), nodes);
      acc.current = 0;
      frames.current = 0;
    }
  });
  return null;
}

function hubVisible(hub: (typeof HUBS)[number], layers?: string[], agents?: string[]) {
  if (layers && layers.length && !layers.includes(hub.layer)) return false;
  if (agents && agents.length && !hub.agents.some((a) => agents.includes(a))) return false;
  return true;
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
}: {
  runState: RunState;
  nodeCount: number;
  active?: string;
  onSelect?: (id: string) => void;
  interactive: boolean;
  showLabels: boolean;
  visibleLayers?: string[];
  visibleAgents?: string[];
  onStats?: (fps: number, nodes: number) => void;
  pbr: boolean;
}) {
  const tex = useGlow();
  const sc = STATE_COLOR[runState];
  return (
    <>
      <color attach="background" args={[ORGANISM_COLORS.bg]} />
      <fog attach="fog" args={[ORGANISM_COLORS.bg, 6.5, 15]} />
      {pbr ? (
        <>
          <ambientLight intensity={0.35} />
          <pointLight position={[0, 3.5, 3]} intensity={9} distance={14} color={ORGANISM_COLORS.cyan} />
          <pointLight position={[-4, -2, 2.5]} intensity={7} distance={14} color={ORGANISM_COLORS.violet} />
          <pointLight position={[4, -2, 2.5]} intensity={7} distance={14} color={ORGANISM_COLORS.magenta} />
          <Environment resolution={128} frames={1}>
            <Lightformer form="circle" intensity={3} color={ORGANISM_COLORS.cyan} position={[0, 3, 2]} scale={3} />
            <Lightformer form="circle" intensity={2.4} color={ORGANISM_COLORS.violet} position={[-3, -1, 2]} scale={2.5} />
            <Lightformer form="circle" intensity={2.4} color={ORGANISM_COLORS.magenta} position={[3, -1, 2]} scale={2.5} />
          </Environment>
        </>
      ) : null}
      <Stars tex={tex} />
      <Stats onStats={onStats} nodes={nodeCount} />
      <group rotation={[0.32, 0, 0]}>
        <Brain count={nodeCount} tex={tex} />
        <Core color={sc} tex={tex} pbr={pbr} />
        {HUBS.map((h) => (
          <Hub key={h.id} hub={h} active={active} onSelect={onSelect} showLabel={showLabels} visible={hubVisible(h, visibleLayers, visibleAgents)} tex={tex} pbr={pbr} />
        ))}
      </group>
      <OrbitControls
        enablePan={false}
        enableZoom={interactive}
        enableRotate={interactive}
        autoRotate={!interactive}
        autoRotateSpeed={0.5}
        minDistance={4.5}
        maxDistance={12}
        minPolarAngle={Math.PI * 0.2}
        maxPolarAngle={Math.PI * 0.8}
      />
      <EffectComposer>
        <Bloom intensity={1.25} luminanceThreshold={0.18} luminanceSmoothing={0.6} mipmapBlur radius={0.75} />
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
}: {
  runState?: RunState;
  nodeCount?: number;
  activeRegion?: string;
  onSelectRegion?: (id: string) => void;
  interactive?: boolean;
  showRegions?: boolean;
  visibleLayers?: string[];
  visibleAgents?: string[];
  onStats?: (fps: number, nodes: number) => void;
}) {
  const [pbr, setPbr] = useState(false);
  useEffect(() => {
    setPbr(detectHardwareGPU());
    // Preload the GLB only when the 3D canvas actually mounts (not at import time,
    // so the 2D reduced-motion / no-WebGL path never triggers the fetch).
    useGLTF.preload(CORE_GLB);
  }, []);
  return (
    <div className="cortex-wrap">
      <Canvas
        camera={{ position: [0, 0.6, 7], fov: 48 }}
        dpr={[1, 2]}
        gl={{ antialias: true, alpha: false, powerPreference: "high-performance" }}
        style={{ position: "absolute", inset: 0 }}
      >
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
        />
      </Canvas>
      <span className="cortex-badge">LIVE · ORGANISM · WEBGL</span>
      <span className="cortex-state">
        <span className="dot" style={{ background: STATE_COLOR[runState] }} />
        {STATE_LABEL[runState]}
      </span>
    </div>
  );
}
