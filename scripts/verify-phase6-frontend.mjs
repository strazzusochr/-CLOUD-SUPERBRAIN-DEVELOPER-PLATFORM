#!/usr/bin/env node
/*
 * verify-phase6-frontend.mjs — LOCAL verifier for the Phase-6 (Scale & 3D Platform)
 * FRONTEND client-runtime slices delivered on this branch. Truth-policy: this proves
 * the slices exist and pass locally; it does NOT credit the committed manifest
 * percentage (that increases only after the owner's HOSTED verifier run against the
 * real Hetzner stack — the project's established evidence standard). It is honest
 * local evidence, not a hosted/production claim.
 *
 *   node scripts/verify-phase6-frontend.mjs
 *
 * Checks the source markers for each delivered Phase-6 frontend slice, then runs the
 * Playwright Phase-6 control test (capability badge, frame-budget HUD, keyboard loop,
 * reduced-motion guard) which renders a real WebGL canvas with zero console errors.
 */
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const fe = resolve(root, "apps/frontend");
const read = (p) => readFileSync(resolve(fe, p), "utf8");

const SLICES = [
  { id: "webgpu_detection_with_webgl_fallback", file: "components/organism/OrganismView.tsx", needle: '"gpu" in navigator' },
  { id: "phase6_3d_performance_budget / frame_budget_overlay", file: "components/organism/CortexCanvas3D.tsx", needle: "1000 / fps" },
  { id: "pointer_keyboard_loop (interaction)", file: "components/organism/CortexCanvas3D.tsx", needle: "function CameraRig" },
  { id: "phase6_3d_camera_lighting_controls (reset)", file: "components/organism/OrganismView.tsx", needle: "Reset camera" },
  { id: "phase6_3d_accessibility / motion_sickness_guard", file: "components/organism/OrganismView.tsx", needle: "Reduced motion" },
  { id: "phase6_3d_scene_state (auto-rotate toggle)", file: "components/organism/CortexCanvas3D.tsx", needle: "onToggleAutoRotate" },
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

console.log(`\nAll ${ok} slice markers present. Running the Playwright Phase-6 control proof…`);
const r = spawnSync(
  process.execPath,
  ["node_modules/@playwright/test/cli.js", "test", "-g", "Phase-6 3D controls", "--reporter=line"],
  { cwd: fe, stdio: "inherit", env: { ...process.env, NODE_PATH: process.env.NODE_PATH } },
);
if (r.status !== 0) {
  console.error("\nFAIL: Phase-6 control e2e proof did not pass.");
  process.exit(r.status ?? 1);
}
console.log("\nPASS — Phase-6 frontend slices verified LOCALLY (hosted manifest credit pending owner's hosted verifier run).");
