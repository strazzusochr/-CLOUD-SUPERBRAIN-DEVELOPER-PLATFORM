#!/usr/bin/env node
/*
 * verify-phase6-frontend.mjs — local or hosted verifier for the Phase-6
 * (Scale & 3D Platform) frontend client-runtime slices delivered on this branch.
 * Truth-policy: this proves only the slices and interactions listed below. It does not
 * claim complete Phase-6 scale capability, a deployment, or production readiness.
 *
 *   node scripts/verify-phase6-frontend.mjs
 *
 * Checks the source markers for each delivered Phase-6 frontend slice, then runs the
 * Playwright Phase-6 control test (capability badge, frame-budget HUD, keyboard loop,
 * reduced-motion guard) which renders a real WebGL canvas with zero console errors.
 */
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const fe = resolve(root, "apps/frontend");
const read = (p) => readFileSync(resolve(fe, p), "utf8");

function parseArgs(argv) {
  const args = { baseUrl: "", outDir: "", sourceOnly: false };
  for (let index = 2; index < argv.length; index += 1) {
    if (argv[index] === "--base-url") args.baseUrl = String(argv[++index] ?? "").replace(/\/+$/, "");
    else if (argv[index] === "--out") args.outDir = resolve(root, String(argv[++index] ?? ""));
    else if (argv[index] === "--source-only") args.sourceOnly = true;
  }
  if (args.baseUrl && !/^https?:\/\//i.test(args.baseUrl)) throw new Error("--base-url must be an HTTP(S) URL");
  return args;
}

const args = parseArgs(process.argv);
if (args.outDir) mkdirSync(args.outDir, { recursive: true });
const localBaseUrl = !args.baseUrl || /^http:\/\/(?:localhost|127\.0\.0\.1|\[::1\])(?::|\/|$)/i.test(args.baseUrl);
if (args.baseUrl && !localBaseUrl && !args.baseUrl.startsWith("https://")) {
  throw new Error("A non-local Phase-6 browser proof requires HTTPS");
}

const SLICES = [
  { id: "webgpu_detection_with_webgl_fallback", file: "components/organism/OrganismView.tsx", needle: '"gpu" in navigator' },
  { id: "phase6_3d_performance_budget / frame_budget_overlay", file: "components/organism/CortexCanvas3D.tsx", needle: "1000 / fps" },
  { id: "pointer_keyboard_loop (interaction)", file: "components/organism/CortexCanvas3D.tsx", needle: "function CameraRig" },
  { id: "phase6_3d_camera_lighting_runtime_visible (full controls)", file: "components/organism/OrganismView.tsx", needle: "phase6-camera-lighting-controls" },
  { id: "phase6_3d_accessibility_runtime_visible (full keyboard/focus controls)", file: "components/organism/OrganismView.tsx", needle: "phase6-accessibility-controls" },
  { id: "phase6_3d_scene_state (auto-rotate toggle)", file: "components/organism/CortexCanvas3D.tsx", needle: "onToggleAutoRotate" },
  { id: "organism_visual_v2_dot_globe", file: "components/organism/CortexCanvas3D.tsx", needle: "function DotGlobe" },
  { id: "organism_visual_v2_matrix_rain", file: "components/organism/CortexCanvas3D.tsx", needle: 'data-testid="organism-matrix-rain"' },
  { id: "organism_visual_v2_scanlines_hud", file: "components/organism/CortexCanvas3D.tsx", needle: 'data-testid="organism-scanlines"' },
  { id: "organism_visual_v2_shards", file: "components/organism/CortexCanvas3D.tsx", needle: "function Shards" },
  { id: "organism_visual_v2_runtime_telemetry_waveform", file: "components/organism/OrganismView.tsx", needle: "buildVisualTelemetry" },
  { id: "organism_visual_v2_core_edges", file: "components/organism/CortexCanvas3D.tsx", needle: "<Edges threshold={16}" },
  { id: "organism_visual_v2_core_transmission", file: "components/organism/CortexCanvas3D.tsx", needle: "<MeshTransmissionMaterial" },
  { id: "threejs_webgl_smoke + nonblank_canvas (e2e)", file: "e2e/organism.spec.ts", needle: "Phase-6 3D controls" },
];

let ok = 0;
console.log("Phase-6 frontend slice markers:");
for (const s of SLICES) {
  const present = read(s.file).includes(s.needle);
  console.log(`  ${present ? "✓" : "✗"} ${s.id}  (${s.file})`);
  if (present) ok++;
}
if (ok !== SLICES.length) {
  console.error(`\nFAIL: ${ok}/${SLICES.length} slice markers present.`);
  process.exit(1);
}

if (args.sourceOnly) {
  console.log(`\nPASS — all ${ok} Phase-6 frontend source markers are present.`);
  process.exit(0);
}

const proofMode = localBaseUrl ? "LOCAL DEV-ONLY" : "HOSTED HTTPS";
console.log(`\nAll ${ok} slice markers present. Running the Playwright Phase-6 control proof (${proofMode})…`);
const r = spawnSync(
  process.execPath,
  ["node_modules/@playwright/test/cli.js", "test", "-g", "Phase-6 3D controls", "--reporter=line"],
  {
    cwd: fe,
    stdio: "inherit",
    env: {
      ...process.env,
      NODE_PATH: process.env.NODE_PATH,
      PHASE6_BASE_URL: args.baseUrl,
      PHASE6_ARTIFACT_DIR: args.outDir,
    },
  },
);
if (r.status !== 0) {
  console.error("\nFAIL: Phase-6 control e2e proof did not pass.");
  process.exit(r.status ?? 1);
}

const screenshots = ["phase6-3d-before.png", "phase6-2d-after.png"].map((name) => ({
  name,
  path: args.outDir ? resolve(args.outDir, name) : "",
}));
if (args.outDir) {
  for (const screenshot of screenshots) {
    if (!existsSync(screenshot.path) || statSync(screenshot.path).size < 25_000) {
      console.error(`\nFAIL: missing or undersized screenshot ${screenshot.path}`);
      process.exit(1);
    }
  }
  const report = {
    contract: "phase6-frontend-client-runtime-proof-v1",
    status: "pass",
    mode: localBaseUrl ? "local_dev_only" : "hosted_https",
    base_url: args.baseUrl || "http://localhost:4040",
    slice_count: SLICES.length,
    passed_slice_count: ok,
    source_markers: SLICES.map(({ id, file }) => ({ id, file, passed: true })),
    interactions: ["camera_reset", "keyboard_camera_loop", "organism_visual_v2_visible", "reduced_motion_to_2d"],
    assertions: {
      webgl_canvas_visible: true,
      canvas_screenshot_min_bytes: 25_000,
      frame_budget_hud_visible: true,
      organism_visual_v2_visible: true,
      runtime_telemetry_waveform_visible: true,
      console_errors: 0,
      reduced_motion_fallback_visible: true,
    },
    screenshots: screenshots.map((entry) => ({ name: entry.name, bytes: statSync(entry.path).size })),
    non_claims: [
      "This proof covers the Phase-6 frontend client runtime, not every Phase-6 scale capability.",
      "The dedicated accessibility verifier closes the keyboard, focus, live-status, system-preference, and semantic 2D-fallback slice.",
      "No provider write, deployment, release promotion, or secret use was performed.",
      ...(localBaseUrl ? ["DEV-ONLY; hosted proof still blocked."] : []),
    ],
    generated_at: new Date().toISOString(),
  };
  writeFileSync(resolve(args.outDir, "report.json"), `${JSON.stringify(report, null, 2)}\n`);
  writeFileSync(
    resolve(args.outDir, "report.md"),
    `# Phase 6 Frontend Client Runtime Proof\n\nStatus: PASS\n\n- Mode: ${report.mode}\n- Base URL: ${report.base_url}\n- Slices: ${ok}/${SLICES.length}\n- Real interactions: camera reset, keyboard camera loop, organism visual v2, reduced motion to 2D\n- Console errors: 0\n- Screenshots: ${screenshots.map((entry) => entry.name).join(", ")}\n\nThis is a frontend client-runtime slice proof, not a claim that all Phase 6 scale work is complete.\n`,
  );
}

console.log(`\nPASS — Phase-6 frontend client-runtime slices verified (${proofMode}).`);
