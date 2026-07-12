import { test, expect } from "@playwright/test";
import { mkdirSync } from "node:fs";
import { resolve } from "node:path";

const phase6ArtifactDir = process.env.PHASE6_ARTIFACT_DIR?.trim();

function phase6ArtifactPath(name: string): string | null {
  if (!phase6ArtifactDir) return null;
  mkdirSync(phase6ArtifactDir, { recursive: true });
  return resolve(phase6ArtifactDir, name);
}

/** The 22 spec page routes + the 3 organism subroutes. */
const PAGE_ROUTES = [
  "/", "/home", "/login", "/workbench", "/files", "/files/local",
  "/organism", "/organism/live", "/organism/replay", "/organism/map",
  "/agents", "/tools", "/marketplace", "/observe", "/evidence", "/settings",
  "/diagnostics", "/design-system", "/responsive", "/technology", "/open-source",
  "/games", "/media", "/docs-output", "/apps",
];

test.describe("Cloud Superbrain platform", () => {
  test.beforeEach(async ({ page }) => {
    await page.emulateMedia({ reducedMotion: "no-preference" });
  });

  test("all page routes return 200", async ({ page }) => {
    for (const route of PAGE_ROUTES) {
      const resp = await page.goto(route, { waitUntil: "domcontentloaded" });
      expect(resp?.status(), `route ${route}`).toBe(200);
    }
  });

  test("organism contract API serves the v1 contract", async ({ request }) => {
    const resp = await request.get("/api/v1/organism/contract");
    expect(resp.status()).toBe(200);
    const json = await resp.json();
    expect(json.contract_version).toBe("organism-surface-v1");
    expect(Array.isArray(json.hubs)).toBeTruthy();
    expect(json.hubs.length).toBe(8);
  });

  test("organism live-state / replay are spec-only when no backend is configured", async ({ request }) => {
    for (const path of ["live-state", "replay"]) {
      const resp = await request.get(`/api/v1/organism/${path}`);
      expect(resp.status(), path).toBe(200);
      const json = await resp.json();
      expect(json.source, path).toBe("spec_only");
      expect(json.live, path).toBe(false);
      expect(json.non_claims.join(" "), path).toMatch(/no secret|no live provider/i);
    }
  });

  test("organism events stay honest: backend/platform-audit when configured, spec-only otherwise", async ({ request }) => {
    const resp = await request.get("/api/v1/organism/events");
    expect(resp.status()).toBe(200);
    const json = await resp.json();
    expect(json.contract_version).toBe("organism-events-v1");
    expect(json.source).toMatch(/agent-api|platform-audit|spec_only/);
    expect(json.source_kind).toMatch(/agent_api_redacted|platform_audit|spec_only/);
    expect(typeof json.live).toBe("boolean");
    expect(json.events.length).toBeGreaterThan(0);
    expect(JSON.stringify(json)).not.toMatch(/session_id|user_id|"details"/);
    expect(json.non_claims.join(" ")).toMatch(/no secret|no live provider/i);
  });

  test("organism topology / regions / safety contracts are wired and read-only", async ({ request }) => {
    const topologyResp = await request.get("/api/v1/organism/topology");
    expect(topologyResp.status()).toBe(200);
    const topology = await topologyResp.json();
    expect(topology.contract_version).toBe("organism-topology-v1");
    const nodeIds = new Set((topology.nodes as Array<{ id: string }>).map((node) => node.id));
    expect(nodeIds.has("layer:FE")).toBeTruthy();
    expect(nodeIds.has("agent:planner")).toBeTruthy();
    expect(nodeIds.has("tool:mcp_gateway")).toBeTruthy();
    expect(nodeIds.has("model:deepseek-ai/DeepSeek-V4-Pro")).toBeTruthy();
    for (const edge of topology.edges as Array<{ from: string; to: string }>) {
      expect(nodeIds.has(edge.from), `edge source ${edge.from}`).toBeTruthy();
      expect(nodeIds.has(edge.to), `edge target ${edge.to}`).toBeTruthy();
    }
    expect((topology.nodes as Array<{ writes: boolean }>).every((node) => node.writes === false)).toBeTruthy();

    const regionsResp = await request.get("/api/v1/organism/regions");
    expect(regionsResp.status()).toBe(200);
    const regions = await regionsResp.json();
    expect(regions.contract_version).toBe("organism-regions-v1");
    expect(regions.regions.length).toBeGreaterThanOrEqual(10);
    expect(regions.regions.every((region: { secret_output: boolean; writes: boolean }) => !region.secret_output && !region.writes)).toBeTruthy();

    const safetyResp = await request.get("/api/v1/organism/safety");
    expect(safetyResp.status()).toBe(200);
    const safety = await safetyResp.json();
    expect(safety.contract_version).toBe("organism-safety-v1");
    expect(safety.data_rules.no_fake_live).toBe(true);
    expect(safety.data_rules.secret_output).toBe(false);
    expect(safety.data_rules.provider_write).toBe(false);
  });

  test("workspace wiring maps all 22 pages to organism regions and verifiers", async ({ request }) => {
    const resp = await request.get("/api/v1/workspace/wiring");
    expect(resp.status()).toBe(200);
    const json = await resp.json();
    expect(json.contract_version).toBe("workspace-surface-wiring-v1");
    expect(json.evidence_ref).toBe("workspace_surface_wiring_visible");
    expect(json.page_count).toBe(22);
    expect(json.surfaces.length).toBe(22);
    const routes = new Set(json.surfaces.map((surface: { route: string }) => surface.route));
    for (const route of ["/home", "/workbench", "/organism", "/agents", "/files", "/tools", "/evidence", "/open-source"]) {
      expect(routes.has(route), route).toBeTruthy();
    }
    for (const surface of json.surfaces as Array<{
      brainRegion: string;
      hub: string;
      dataSources: string[];
      verifierRefs: string[];
      live: boolean;
      writes: boolean;
      secretOutput: boolean;
    }>) {
      expect(surface.brainRegion).toBeTruthy();
      expect(surface.hub).toBeTruthy();
      expect(surface.dataSources.length).toBeGreaterThan(0);
      expect(surface.verifierRefs.length).toBeGreaterThan(0);
      expect(surface.live).toBe(false);
      expect(surface.writes).toBe(false);
      expect(surface.secretOutput).toBe(false);
    }
  });

  test("workbench hides budget until a paid or metered option is selected", async ({ page }) => {
    await page.goto("/workbench", { waitUntil: "networkidle" });
    await expect(page.getByText("Metered Budget")).toHaveCount(0);
    await expect(page.getByText("paid/metered Capability")).toHaveCount(0);
    await expect(page.getByTestId("workbench-studio")).toBeVisible();
    await expect(page.getByText("Dateien", { exact: true })).toBeVisible();
    await expect(page.getByText("Build-Protokoll", { exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Vorschau" })).toBeVisible();

    await page.goto("/workbench?billing=paid", { waitUntil: "networkidle" });
    await expect(page.getByTestId("workbench-studio")).toBeVisible();
    await expect(page.getByText("Metered Budget")).toHaveCount(0);
    await expect(page.getByText("paid/metered Capability")).toHaveCount(0);
  });

  test("consolidated pages render real content (not re-export shortcuts)", async ({ page }) => {
    await page.goto("/technology", { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Fähigkeiten nach Kategorie")).toBeVisible();
    await expect(page.getByText("Cloud-Provider-Inventar")).toBeVisible();

    await page.goto("/responsive", { waitUntil: "domcontentloaded" });
    await expect(page.getByText("Breakpoint-Matrix")).toBeVisible();
    await expect(page.getByText("Accessibility & Reduced Motion")).toBeVisible();

    await page.goto("/open-source", { waitUntil: "domcontentloaded" });
    await expect(page.getByText(/Kernkomponenten und ihre Lizenzen/)).toBeVisible();
    await expect(page.getByText("MIT").first()).toBeVisible();
  });

  test("removed alias/duplicate routes are gone (404)", async ({ page }) => {
    for (const dead of ["/about/stack", "/about/open-source", "/design-system/responsive"]) {
      const resp = await page.goto(dead, { waitUntil: "domcontentloaded" });
      expect(resp?.status(), `dead route ${dead}`).toBe(404);
    }
  });

  test("organism GLB core asset is served and fetched by the canvas", async ({ page, request }) => {
    const glb = await request.get("/organism/core.glb");
    expect(glb.status()).toBe(200);
    const bytes = await glb.body();
    expect(bytes.length, "core.glb byte size").toBeGreaterThan(1000);
    expect(bytes.subarray(0, 4).toString("ascii"), "glTF magic").toBe("glTF");

    const fetched: string[] = [];
    page.on("requestfinished", (r) => {
      if (r.url().includes("core.glb")) fetched.push(r.url());
    });
    await page.goto("/organism", { waitUntil: "networkidle" });
    await page.waitForTimeout(3000);
    expect(fetched.length, "canvas fetched core.glb").toBeGreaterThan(0);
  });

  test("organism 3D renders a WebGL canvas with no console errors (+ screenshot proof)", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
    page.on("console", (m) => {
      if (m.type() === "error") errors.push(`console: ${m.text()}`);
    });

    await page.goto("/organism", { waitUntil: "networkidle" });
    await page.waitForTimeout(6000);

    const info = await page.evaluate(() => {
      const c = document.querySelector("canvas");
      const badge = document.querySelector(".cortex-badge")?.textContent ?? "";
      const gl = c ? !!(c.getContext("webgl2") || c.getContext("webgl")) : false;
      return { hasCanvas: !!c, gl, badge };
    });

    expect(info.hasCanvas, "canvas present").toBeTruthy();
    expect(info.gl, "webgl context").toBeTruthy();
    expect(info.badge).toContain("WEBGL");
    expect(errors, "no console/page errors").toEqual([]);

    const box = await page.locator(".cortex-wrap").first().boundingBox();
    await page.screenshot({ path: "e2e/__artifacts__/organism.png", clip: box ?? undefined });
  });

  test("organism Phase-6 3D controls: capability, frame-budget HUD, keyboard, reduced-motion", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

    await page.goto("/organism", { waitUntil: "networkidle" });
    await page.waitForTimeout(4000);

    // GPU capability badge (WebGPU detection with WebGL fallback)
    await expect(page.locator(".cap-badge")).toBeVisible();
    // frame-budget perf overlay (FPS + ms/frame)
    const hud = await page.locator(".org-hud").innerText();
    expect(hud).toMatch(/FPS/);
    expect(hud).toMatch(/ms/);
    // scene controls present
    await expect(page.getByRole("button", { name: /Kamera zurücksetzen/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /Weniger Bewegung/ })).toBeVisible();
    const canvas = page.locator("canvas").first();
    await expect(canvas).toBeVisible();
    const canvasProof = await canvas.screenshot();
    expect(canvasProof.length, "rendered canvas screenshot bytes").toBeGreaterThan(25_000);
    const beforePath = phase6ArtifactPath("phase6-3d-before.png");
    if (beforePath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: beforePath, fullPage: true });
    }

    // keyboard interaction loop must not error
    for (const k of ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Equal", "Minus", "r"]) {
      await page.keyboard.press(k);
    }
    await page.waitForTimeout(200);

    // reduced-motion (motion-sickness guard) switches to the 2D fallback
    await page.getByRole("button", { name: /Weniger Bewegung/ }).click();
    await expect(page.locator(".org-hud"), "HUD shows 2D after reduced-motion").toContainText("2D", {
      timeout: 5_000,
    });
    const afterPath = phase6ArtifactPath("phase6-2d-after.png");
    if (afterPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: afterPath, fullPage: true });
    }

    expect(errors, "no console/page errors during 3D control interaction").toEqual([]);
  });

  test("organism Phase-6 camera and lighting controls apply bounded runtime state", async ({ page }) => {
    test.setTimeout(150_000);
    const contractResponse = await page.request.get("/api/v1/phase6/3d-camera-lighting/contract");
    expect(contractResponse.status()).toBe(200);
    const contract = await contractResponse.json();
    expect(contract.contract_version).toBe("phase6-3d-camera-lighting-runtime-v1");
    expect(contract.camera_presets).toHaveLength(3);
    expect(contract.lighting_profiles).toHaveLength(3);
    expect(contract.safe_fov_degrees).toEqual([38, 45, 58]);
    expect(contract.safe_exposure_range).toMatchObject({ min: 0.72, max: 1.18, step: 0.02 });

    const errors: string[] = [];
    const controlRequests: string[] = [];
    let captureControlRequests = false;
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
    page.on("request", (request) => {
      if (captureControlRequests && ["fetch", "xhr"].includes(request.resourceType())) {
        controlRequests.push(request.url());
      }
    });

    await page.goto("/organism?gpu=force", { waitUntil: "networkidle" });
    const controls = page.getByTestId("phase6-camera-lighting-controls");
    const canvasState = page.locator(".cortex-wrap").first();
    await expect(controls).toBeVisible();
    await expect(canvasState).toHaveAttribute("data-camera-preset", "wide");
    await expect(canvasState).toHaveAttribute("data-camera-fov", "45");
    await expect(canvasState).toHaveAttribute("data-camera-position", "0.00,0.60,7.00");
    await expect(canvasState).toHaveAttribute("data-lighting-profile", "studio");
    await expect(canvasState).toHaveAttribute("data-tone-exposure", "1.00");
    await expect(canvasState).toHaveAttribute("data-camera-lighting-local-only", "true");

    captureControlRequests = true;
    await page.getByTestId("phase6-camera-preset-close").click();
    await expect(canvasState).toHaveAttribute("data-camera-preset", "close");
    await expect(canvasState).toHaveAttribute("data-camera-position", "0.00,0.35,5.00");
    await page.getByTestId("phase6-camera-preset-top").click();
    await expect(canvasState).toHaveAttribute("data-camera-preset", "top");
    await expect(canvasState).toHaveAttribute("data-camera-position", "0.20,6.80,1.40");

    const fov = page.getByTestId("phase6-camera-fov");
    await fov.selectOption("58");
    await expect(canvasState).toHaveAttribute("data-camera-fov", "58");
    await fov.selectOption("38");
    await expect(canvasState).toHaveAttribute("data-camera-fov", "38");

    await page.getByTestId("phase6-lighting-profile-night").click();
    await expect(canvasState).toHaveAttribute("data-lighting-profile", "night");
    await expect(canvasState).toHaveAttribute("data-tone-exposure", "0.82");
    await page.getByTestId("phase6-lighting-profile-sunrise").click();
    await expect(canvasState).toHaveAttribute("data-lighting-profile", "sunrise");
    await expect(canvasState).toHaveAttribute("data-tone-exposure", "1.12");

    const exposure = page.getByTestId("phase6-lighting-exposure");
    await exposure.focus();
    await exposure.press("Home");
    await expect(canvasState).toHaveAttribute("data-tone-exposure", "0.72");
    await exposure.press("End");
    await expect(canvasState).toHaveAttribute("data-tone-exposure", "1.18");

    await page.getByRole("button", { name: "Kamera zurücksetzen" }).click();
    await expect(canvasState).toHaveAttribute("data-camera-position", "0.20,6.80,1.40");
    await expect(page.getByTestId("phase6-camera-lighting-state")).toContainText("camera_preset=top");
    await expect(page.getByTestId("phase6-camera-lighting-state")).toContainText("fov=38°");
    await expect(page.getByTestId("phase6-camera-lighting-state")).toContainText("lighting_profile=sunrise");
    await expect(page.getByTestId("phase6-camera-lighting-state")).toContainText("exposure=1.18");

    await page.getByRole("button", { name: /Automatisch drehen/ }).click();
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(250);
    const canvas = page.locator("canvas").first();
    const canvasBox = await canvas.boundingBox();
    expect(canvasBox, "camera and lighting canvas bounds").not.toBeNull();
    const canvasProof = await page.screenshot({ clip: canvasBox ?? undefined });
    expect(canvasProof.length, "camera and lighting canvas screenshot bytes").toBeGreaterThan(25_000);
    const artifactPath = phase6ArtifactPath("phase6-camera-lighting.png");
    if (artifactPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: artifactPath, fullPage: true });
    }

    expect(controlRequests, "camera and lighting controls remain browser-local").toEqual([]);
    expect(errors, "no console/page errors during camera and lighting interactions").toEqual([]);
  });

  test("organism Phase-6 gameplay state is deterministic, pause-safe, and browser-local", async ({ page }) => {
    test.setTimeout(150_000);
    const contractResponse = await page.request.get("/api/v1/phase6/3d-gameplay-state/contract");
    expect(contractResponse.status()).toBe(200);
    const contract = await contractResponse.json();
    expect(contract.contract_version).toBe("phase6-3d-gameplay-state-runtime-v1");
    expect(contract.objectives).toEqual(["collect", "checkpoint", "survive"]);
    expect(contract.objective_transitions).toMatchObject({
      collect: { next: "checkpoint", score_delta: 10, checkpoint_delta: 0 },
      checkpoint: { next: "survive", score_delta: 0, checkpoint_delta: 1 },
      survive: { next: "collect", score_delta: 10, checkpoint_delta: 0 },
    });
    expect(contract.multiplayer_netcode_allowed).toBe(false);
    expect(contract.server_authoritative_sync_allowed).toBe(false);
    expect(contract.network_calls_required).toBe(false);

    const errors: string[] = [];
    const gameplayRequests: string[] = [];
    let captureGameplayRequests = false;
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
    page.on("request", (request) => {
      if (captureGameplayRequests && ["fetch", "xhr"].includes(request.resourceType())) {
        gameplayRequests.push(request.url());
      }
    });

    await page.goto("/organism", { waitUntil: "networkidle" });
    const controls = page.getByTestId("phase6-gameplay-state-controls");
    const state = page.getByTestId("phase6-gameplay-state");
    const canvasState = page.locator(".cortex-wrap").first();
    await expect(controls).toBeVisible();
    await expect(state).toContainText("objective=collect");
    await expect(state).toContainText("score=0");
    await expect(state).toContainText("checkpoints=0");
    await expect(state).toContainText("local_state_only=true");
    await expect(canvasState).toHaveAttribute("data-gameplay-objective", "collect");
    await expect(canvasState).toHaveAttribute("data-gameplay-local-only", "true");

    captureGameplayRequests = true;
    await page.getByTestId("phase6-gameplay-complete").click();
    await expect(state).toContainText("objective=checkpoint");
    await expect(state).toContainText("score=10");
    await expect(state).toContainText("checkpoints=0");
    await expect(canvasState).toHaveAttribute("data-gameplay-objective", "checkpoint");
    await expect(canvasState).toHaveAttribute("data-gameplay-score", "10");

    await page.keyboard.press("g");
    await expect(state).toContainText("objective=survive");
    await expect(state).toContainText("score=10");
    await expect(state).toContainText("checkpoints=1");
    await expect(state).toContainText("input_events=2");
    await expect(canvasState).toHaveAttribute("data-gameplay-checkpoints", "1");

    await page.getByTestId("phase6-gameplay-complete").click();
    await expect(state).toContainText("objective=collect");
    await expect(state).toContainText("score=20");
    await expect(state).toContainText("checkpoints=1");
    await expect(state).toContainText("completions=3");

    await page.getByTestId("phase6-gameplay-pause").click();
    await expect(state).toContainText("paused=true");
    await expect(canvasState).toHaveAttribute("data-gameplay-paused", "true");
    const pausedTicks = await canvasState.getAttribute("data-gameplay-ticks");
    await page.waitForTimeout(1_250);
    await expect(canvasState).toHaveAttribute("data-gameplay-ticks", pausedTicks ?? "0");

    await page.getByTestId("phase6-gameplay-pause").click();
    await expect(state).toContainText("paused=false");
    await expect.poll(async () => canvasState.getAttribute("data-gameplay-ticks"), { timeout: 3_000 }).not.toBe(pausedTicks);

    await page.getByTestId("phase6-gameplay-pause").click();
    await expect(state).toContainText("paused=true");
    await page.getByTestId("phase6-gameplay-reset").click();
    await expect(state).toContainText("objective=collect");
    await expect(state).toContainText("score=0");
    await expect(state).toContainText("checkpoints=0");
    await expect(state).toContainText("completions=0");
    await expect(state).toContainText("input_events=0");
    await expect(state).toContainText("loop_ticks=0");
    await expect(state).toContainText("paused=true");

    const canvas = page.locator("canvas").first();
    const canvasProof = await canvas.screenshot();
    expect(canvasProof.length, "gameplay canvas screenshot bytes").toBeGreaterThan(25_000);
    const artifactPath = phase6ArtifactPath("phase6-gameplay-state.png");
    if (artifactPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: artifactPath, fullPage: true });
    }

    expect(gameplayRequests, "gameplay controls remain browser-local").toEqual([]);
    expect(errors, "no console/page errors during gameplay interactions").toEqual([]);
  });

  test("organism Phase-6 asset policy applies procedural profiles without network access", async ({ page }) => {
    test.setTimeout(150_000);
    const contractResponse = await page.request.get("/api/v1/phase6/3d-asset-policy/contract");
    expect(contractResponse.status()).toBe(200);
    const contract = await contractResponse.json();
    expect(contract.contract_version).toBe("phase6-3d-asset-policy-runtime-v1");
    expect(contract.asset_profiles.map((item: { id: string }) => item.id)).toEqual(["cube", "beacon", "ring"]);
    expect(contract.material_variants.map((item: { id: string }) => item.id)).toEqual(["cyan", "amber", "rose"]);
    expect(contract.asset_catalog_count).toBe(3);
    expect(contract.material_variant_count).toBe(3);
    expect(contract.remote_asset_count).toBe(0);
    expect(contract.uploaded_asset_count).toBe(0);
    expect(contract.external_asset_fetch_allowed).toBe(false);
    expect(contract.binary_asset_upload_allowed).toBe(false);
    expect(contract.remote_cdn_allowed).toBe(false);
    expect(contract.asset_pipeline_service_started).toBe(false);
    expect(contract.network_calls_required).toBe(false);

    const errors: string[] = [];
    const assetRequests: string[] = [];
    let captureAssetRequests = false;
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
    page.on("request", (request) => {
      if (captureAssetRequests && ["fetch", "xhr"].includes(request.resourceType())) {
        assetRequests.push(request.url());
      }
    });

    await page.goto("/organism", { waitUntil: "networkidle" });
    const controls = page.getByTestId("phase6-asset-policy-controls");
    const manifest = page.getByTestId("phase6-asset-manifest");
    const canvasState = page.locator(".cortex-wrap").first();
    await expect(controls).toBeVisible();
    await expect(manifest).toContainText("asset_profile=cube");
    await expect(manifest).toContainText("geometry=boxGeometry");
    await expect(manifest).toContainText("material_variant=cyan");
    await expect(manifest).toContainText("remote_assets=0");
    await expect(manifest).toContainText("uploads=0");
    await expect(manifest).toContainText("external_fetch=false");
    await expect(manifest).toContainText("binary_upload=false");
    await expect(manifest).toContainText("local_only=true");
    await expect(canvasState).toHaveAttribute("data-asset-profile", "cube");
    await expect(canvasState).toHaveAttribute("data-material-variant", "cyan");
    await expect(canvasState).toHaveAttribute("data-asset-policy-local-only", "true");

    captureAssetRequests = true;
    await page.getByTestId("phase6-asset-profile-beacon").click();
    await expect(canvasState).toHaveAttribute("data-asset-profile", "beacon");
    await expect(manifest).toContainText("geometry=coneGeometry");
    await page.getByTestId("phase6-material-variant-amber").click();
    await expect(canvasState).toHaveAttribute("data-material-variant", "amber");

    await page.getByTestId("phase6-asset-profile-ring").click();
    await expect(canvasState).toHaveAttribute("data-asset-profile", "ring");
    await expect(manifest).toContainText("geometry=torusGeometry");
    await page.getByTestId("phase6-material-variant-rose").click();
    await expect(canvasState).toHaveAttribute("data-material-variant", "rose");
    await expect(canvasState).toHaveAttribute("data-asset-catalog-count", "3");
    await expect(canvasState).toHaveAttribute("data-material-variant-count", "3");
    await expect(canvasState).toHaveAttribute("data-remote-asset-count", "0");
    await expect(canvasState).toHaveAttribute("data-uploaded-asset-count", "0");
    await expect(canvasState).toHaveAttribute("data-external-asset-fetch", "false");
    await expect(canvasState).toHaveAttribute("data-binary-asset-upload", "false");

    await page.getByTestId("phase6-asset-policy-reset").click();
    await expect(manifest).toContainText("asset_profile=cube");
    await expect(manifest).toContainText("material_variant=cyan");
    await expect(canvasState).toHaveAttribute("data-asset-profile", "cube");
    await expect(canvasState).toHaveAttribute("data-material-variant", "cyan");

    await page.getByRole("button", { name: /Automatisch drehen/ }).click();
    const canvas = page.locator("canvas").first();
    const canvasProof = await canvas.screenshot();
    expect(canvasProof.length, "asset policy canvas screenshot bytes").toBeGreaterThan(25_000);
    const artifactPath = phase6ArtifactPath("phase6-asset-policy.png");
    if (artifactPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: artifactPath, fullPage: true });
    }

    expect(assetRequests, "asset policy controls remain browser-local").toEqual([]);
    expect(errors, "no console/page errors during asset policy interactions").toEqual([]);
  });

  test("organism Phase-6 save and load restores a volatile browser-memory snapshot", async ({ page }) => {
    test.setTimeout(150_000);
    const contractResponse = await page.request.get("/api/v1/phase6/3d-save-load/contract");
    expect(contractResponse.status()).toBe(200);
    const contract = await contractResponse.json();
    expect(contract.contract_version).toBe("phase6-3d-save-load-runtime-v1");
    expect(contract.snapshot_field_count).toBe(15);
    expect(contract.snapshot_slots).toBe(1);
    expect(contract.volatile_browser_memory_only_required).toBe(true);
    expect(contract.snapshot_discarded_on_reload_required).toBe(true);
    expect(contract.local_storage_allowed).toBe(false);
    expect(contract.indexeddb_allowed).toBe(false);
    expect(contract.cookie_persistence_allowed).toBe(false);
    expect(contract.service_worker_cache_allowed).toBe(false);
    expect(contract.cloud_save_sync_allowed).toBe(false);
    expect(contract.binary_snapshot_upload_allowed).toBe(false);
    expect(contract.server_snapshot_write_allowed).toBe(false);
    expect(contract.network_calls_required).toBe(false);

    const errors: string[] = [];
    const snapshotRequests: string[] = [];
    let captureSnapshotRequests = false;
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
    page.on("request", (request) => {
      if (captureSnapshotRequests && ["fetch", "xhr"].includes(request.resourceType())) {
        snapshotRequests.push(request.url());
      }
    });

    await page.goto("/organism", { waitUntil: "networkidle" });
    const state = page.getByTestId("phase6-save-load-state");
    const load = page.getByTestId("phase6-load-snapshot");
    const clear = page.getByTestId("phase6-clear-snapshot");
    const gameplay = page.getByTestId("phase6-gameplay-state");
    const manifest = page.getByTestId("phase6-asset-manifest");
    const canvasState = page.locator(".cortex-wrap").first();
    await expect(page.getByTestId("phase6-save-load-controls")).toBeVisible();
    await expect(state).toContainText("snapshot_status=empty");
    await expect(state).toContainText("slots=0/1");
    await expect(state).toContainText("storage=react_state");
    await expect(state).toContainText("reload_persistence=false");
    await expect(state).toContainText("cloud_sync=false");
    await expect(load).toBeDisabled();
    await expect(clear).toBeDisabled();

    captureSnapshotRequests = true;
    await page.getByTestId("phase6-camera-preset-close").click();
    await page.getByTestId("phase6-camera-fov").selectOption("58");
    await page.getByTestId("phase6-lighting-profile-sunrise").click();
    await page.getByTestId("phase6-gameplay-complete").click();
    await page.getByTestId("phase6-gameplay-pause").click();
    await page.getByTestId("phase6-asset-profile-ring").click();
    await page.getByTestId("phase6-material-variant-rose").click();
    await page.getByTestId("phase6-save-snapshot").click();
    await expect(state).toContainText("snapshot_status=saved");
    await expect(state).toContainText("revision=1");
    await expect(state).toContainText("slots=1/1");
    await expect(load).toBeEnabled();
    await expect(clear).toBeEnabled();

    await page.getByTestId("phase6-camera-preset-top").click();
    await page.getByTestId("phase6-camera-fov").selectOption("38");
    await page.getByTestId("phase6-lighting-profile-night").click();
    await page.getByTestId("phase6-gameplay-reset").click();
    await page.getByTestId("phase6-asset-profile-cube").click();
    await page.getByTestId("phase6-material-variant-cyan").click();
    await expect(gameplay).toContainText("objective=collect");
    await expect(manifest).toContainText("asset_profile=cube");

    await load.click();
    await expect(state).toContainText("snapshot_status=restored");
    await expect(page.getByTestId("phase6-camera-preset-close")).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByTestId("phase6-camera-fov")).toHaveValue("58");
    await expect(page.getByTestId("phase6-lighting-profile-sunrise")).toHaveAttribute("aria-pressed", "true");
    await expect(gameplay).toContainText("objective=checkpoint");
    await expect(gameplay).toContainText("score=10");
    await expect(gameplay).toContainText("paused=true");
    await expect(manifest).toContainText("asset_profile=ring");
    await expect(manifest).toContainText("material_variant=rose");
    await expect(canvasState).toHaveAttribute("data-camera-preset", "close");
    await expect(canvasState).toHaveAttribute("data-camera-fov", "58");
    await expect(canvasState).toHaveAttribute("data-lighting-profile", "sunrise");
    await expect(canvasState).toHaveAttribute("data-gameplay-objective", "checkpoint");
    await expect(canvasState).toHaveAttribute("data-asset-profile", "ring");
    await expect(canvasState).toHaveAttribute("data-material-variant", "rose");

    const canvasProof = await page.locator("canvas").first().screenshot();
    expect(canvasProof.length, "save load canvas screenshot bytes").toBeGreaterThan(25_000);
    const artifactPath = phase6ArtifactPath("phase6-save-load.png");
    if (artifactPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: artifactPath, fullPage: true });
    }

    await clear.click();
    await expect(state).toContainText("snapshot_status=empty");
    await expect(state).toContainText("slots=0/1");
    await expect(load).toBeDisabled();
    captureSnapshotRequests = false;
    await page.reload({ waitUntil: "networkidle" });
    await expect(page.getByTestId("phase6-save-load-state")).toContainText("snapshot_status=empty");
    await expect(page.getByTestId("phase6-load-snapshot")).toBeDisabled();

    expect(snapshotRequests, "save load controls remain browser-local without persistence requests").toEqual([]);
    expect(errors, "no console/page errors during save load interactions").toEqual([]);
  });

  test("organism Phase-6 accessibility honors reduced motion, focus, keyboard, and live status", async ({ page }) => {
    test.setTimeout(150_000);
    const contractResponse = await page.request.get("/api/v1/phase6/3d-accessibility/contract");
    expect(contractResponse.status()).toBe(200);
    const contract = await contractResponse.json();
    expect(contract.contract_version).toBe("phase6-3d-accessibility-runtime-v1");
    expect(contract.system_preference_detection_required).toBe(true);
    expect(contract.static_2d_fallback_required).toBe(true);
    expect(contract.semantic_region_required).toBe(true);
    expect(contract.keyboard_navigation_keys).toEqual(["ArrowDown", "ArrowRight", "ArrowUp", "ArrowLeft", "Home", "End", "Enter", "Space"]);
    expect(contract.programmatic_scene_focus_required).toBe(true);
    expect(contract.global_focus_visible_required).toBe(true);
    expect(contract.live_status_region_required).toBe(true);
    expect(contract.accessible_item_count).toBe(10);
    expect(contract.speech_service_required).toBe(false);
    expect(contract.accessibility_telemetry_export_allowed).toBe(false);
    expect(contract.persistent_preference_write_allowed).toBe(false);
    expect(contract.network_calls_required).toBe(false);

    const errors: string[] = [];
    const accessibilityRequests: string[] = [];
    let captureAccessibilityRequests = false;
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
    page.on("request", (request) => {
      if (captureAccessibilityRequests && ["fetch", "xhr"].includes(request.resourceType())) {
        accessibilityRequests.push(request.url());
      }
    });

    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.goto("/organism", { waitUntil: "networkidle" });
    const controls = page.getByTestId("phase6-accessibility-controls");
    const state = page.getByTestId("phase6-accessibility-state");
    const toggle = page.getByTestId("phase6-reduced-motion-toggle");
    const scene = page.getByTestId("phase6-accessible-scene");
    await expect(controls).toBeVisible();
    await expect(state).toHaveAttribute("role", "status");
    await expect(state).toHaveAttribute("aria-live", "polite");
    await expect(state).toContainText("motion_mode=standard");
    await expect(state).toContainText("system_preference=false");
    await expect(state).toContainText("render_mode=3d");
    await expect(toggle).toHaveAttribute("aria-pressed", "false");
    await expect(toggle).toHaveAttribute("aria-controls", "organism-cortex-surface");
    await expect(scene).toHaveAttribute("role", "region");
    await expect(scene).toHaveAttribute("tabindex", "0");

    captureAccessibilityRequests = true;
    await page.getByTestId("phase6-focus-scene").click();
    await expect(scene).toBeFocused();
    await expect(page.getByTestId("phase6-accessibility-announcement")).toContainText("Organismus-Szene fokussiert");

    await toggle.click();
    await expect(toggle).toHaveAttribute("aria-pressed", "true");
    await expect(state).toContainText("motion_mode=reduced");
    await expect(state).toContainText("user_override=true");
    await expect(state).toContainText("render_mode=2d");
    const fallback = page.getByTestId("phase6-reduced-motion-fallback");
    await expect(fallback).toBeVisible();
    await expect(fallback).toHaveAttribute("role", "region");
    await expect(fallback).toHaveAttribute("aria-label", /Statische 2D-Topologie/);
    const fallbackButtons = fallback.locator("button");
    await expect(fallbackButtons).toHaveCount(10);
    await fallbackButtons.nth(0).focus();
    await page.keyboard.press("ArrowDown");
    await expect(fallbackButtons.nth(1)).toBeFocused();
    await page.keyboard.press("End");
    await expect(fallbackButtons.nth(9)).toBeFocused();
    await page.keyboard.press("Home");
    await expect(fallbackButtons.nth(0)).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page.getByTestId("batch1-organism-action-result")).toContainText("kind=hub");
    await expect(page.getByTestId("batch1-organism-action-result")).toContainText("value=prefrontal");

    const artifactPath = phase6ArtifactPath("phase6-accessibility.png");
    if (artifactPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: artifactPath, fullPage: true });
    }

    await toggle.click();
    await expect(state).toContainText("user_override=false");
    await expect(state).toContainText("motion_mode=standard");
    await expect(state).toContainText("render_mode=3d");
    await page.emulateMedia({ reducedMotion: "reduce" });
    await expect(state).toContainText("system_preference=true");
    await expect(state).toContainText("motion_mode=reduced");
    await expect(state).toContainText("render_mode=2d");
    await expect(page.getByTestId("phase6-reduced-motion-fallback")).toBeVisible();
    await expect(page.getByTestId("phase6-accessibility-announcement")).toContainText("Systempraeferenz fuer reduzierte Bewegung aktiv");
    await page.emulateMedia({ reducedMotion: "no-preference" });
    await expect(state).toContainText("system_preference=false");
    await expect(state).toContainText("motion_mode=standard");

    expect(accessibilityRequests, "accessibility controls remain browser-local").toEqual([]);
    expect(errors, "no console/page errors during accessibility interactions").toEqual([]);
  });

  test("organism Phase-6 netcode loopback enforces two-peer ready and lockstep boundaries", async ({ page }) => {
    test.setTimeout(150_000);
    const contractResponse = await page.request.get("/api/v1/phase6/3d-netcode/contract");
    expect(contractResponse.status()).toBe(200);
    const contract = await contractResponse.json();
    expect(contract.contract_version).toBe("phase6-3d-netcode-loopback-runtime-v1");
    expect(contract.transport).toBe("loopback");
    expect(contract.maximum_peers).toBe(2);
    expect(contract.packets_per_tick).toBe(2);
    expect(contract.ready_barrier_required).toBe(true);
    expect(contract.sequence_monotonic_required).toBe(true);
    expect(contract.disconnect_stops_simulation_required).toBe(true);
    expect(contract.websocket_allowed).toBe(false);
    expect(contract.webrtc_allowed).toBe(false);
    expect(contract.matchmaking_allowed).toBe(false);
    expect(contract.public_lobby_allowed).toBe(false);
    expect(contract.server_authoritative_sync_allowed).toBe(false);
    expect(contract.network_calls_required).toBe(false);

    const errors: string[] = [];
    const netcodeRequests: string[] = [];
    let captureNetcodeRequests = false;
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
    page.on("request", (request) => {
      if (captureNetcodeRequests && ["fetch", "xhr", "websocket"].includes(request.resourceType())) netcodeRequests.push(request.url());
    });

    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.goto("/organism", { waitUntil: "networkidle" });
    const state = page.getByTestId("phase6-netcode-state");
    const canvasState = page.locator(".cortex-wrap").first();
    const start = page.getByTestId("phase6-netcode-start");
    const tick = page.getByTestId("phase6-netcode-tick");
    await expect(page.getByTestId("phase6-netcode-controls")).toBeVisible();
    await expect(page.getByTestId("phase6-netcode-session")).toHaveText("idle");
    await expect(page.getByTestId("phase6-netcode-peers")).toHaveText("0/2");
    await expect(page.getByTestId("phase6-netcode-join")).toBeDisabled();
    await expect(start).toBeDisabled();
    await expect(tick).toBeDisabled();

    captureNetcodeRequests = true;
    await page.getByTestId("phase6-netcode-create").click();
    await expect(page.getByTestId("phase6-netcode-session")).toHaveText("forming");
    await expect(page.getByTestId("phase6-netcode-peers")).toHaveText("1/2");
    await expect(page.getByTestId("phase6-netcode-join")).toBeEnabled();
    await expect(start).toBeDisabled();

    await page.getByTestId("phase6-netcode-join").click();
    await expect(page.getByTestId("phase6-netcode-peers")).toHaveText("2/2");
    await expect(page.getByTestId("phase6-netcode-sequence")).toHaveText("1");
    await expect(canvasState).toHaveAttribute("data-netcode-guest-connected", "true");
    await expect(canvasState).toHaveAttribute("data-netcode-running", "false");
    await expect(start).toBeDisabled();

    await page.getByTestId("phase6-netcode-host-ready").click();
    await expect(start).toBeDisabled();
    await page.getByTestId("phase6-netcode-guest-ready").click();
    await expect(start).toBeEnabled();
    await start.click();
    await expect(page.getByTestId("phase6-netcode-session")).toHaveText("running");
    await expect(canvasState).toHaveAttribute("data-netcode-running", "true");
    await expect(tick).toBeEnabled();

    await tick.click();
    await tick.click();
    await expect(page.getByTestId("phase6-netcode-ticks")).toHaveText("2");
    await expect(page.getByTestId("phase6-netcode-sequence")).toHaveText("5");
    await expect(state).toContainText("packets=5");
    await expect(state).toContainText("sequence=5");
    await expect(state).toContainText("websocket=false");
    await expect(state).toContainText("server_sync=false");
    await expect(canvasState).toHaveAttribute("data-netcode-sequence", "5");

    const artifactPath = phase6ArtifactPath("phase6-netcode-loopback.png");
    if (artifactPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: artifactPath, fullPage: true });
    }

    await page.getByTestId("phase6-netcode-disconnect").click();
    await expect(page.getByTestId("phase6-netcode-session")).toHaveText("forming");
    await expect(page.getByTestId("phase6-netcode-peers")).toHaveText("1/2");
    await expect(tick).toBeDisabled();
    await expect(state).toContainText("running=false");
    await expect(state).toContainText("disconnects=1");
    await expect(canvasState).toHaveAttribute("data-netcode-guest-connected", "false");
    await page.getByTestId("phase6-netcode-close").click();
    await expect(page.getByTestId("phase6-netcode-session")).toHaveText("idle");
    await expect(page.getByTestId("phase6-netcode-peers")).toHaveText("0/2");

    expect(netcodeRequests, "netcode loopback controls perform no network transport").toEqual([]);
    expect(errors, "no console/page errors during netcode loopback interactions").toEqual([]);
  });

  test("organism UI renders redaction-aware runtime feed and replay surface", async ({ page }) => {
    await page.goto("/organism", { waitUntil: "networkidle" });
    const feed = page.getByTestId("organism-runtime-feed");
    await expect(feed).toBeVisible();
    await expect(feed).toHaveAttribute("data-source-kind", /spec_only|agent_api_redacted|platform_audit/);
    await expect(feed).toContainText(/Runtime-Ereignisse/);
    await expect(feed).toContainText(/nur lesende Audit-Projektion/);
    await expect(feed).toContainText(/keine Rohdetails/);
    await expect(feed).not.toContainText(/"details"/);
    await expect(feed).not.toContainText(/user_id/);
    await expect(feed).not.toContainText(/session_id/);

    await page.goto("/organism/replay", { waitUntil: "networkidle" });
    await expect(page.getByTestId("organism-runtime-feed")).toBeVisible();
    await expect(page.getByTestId("organism-replay-frames")).toBeVisible();
  });

  test("organism runtime feed forwards run_id to events and replay APIs", async ({ page }) => {
    const runId = "ui-proof-run-20260610";
    const seen = { events: false, replay: false };

    await page.route("**/api/v1/organism/events?**", async (route) => {
      const url = new URL(route.request().url());
      seen.events = url.searchParams.get("run_id") === runId;
      await route.fulfill({
        contentType: "application/json",
        body: JSON.stringify({
          contract_version: "organism-events-v1",
          source: "agent-api",
          source_kind: "agent_api_redacted",
          live: true,
          run_id: runId,
          note: "redacted ui run proof",
          events: [{
            seq: 1,
            kind: "planning",
            hub: "workbench",
            run_state: "planning",
            severity: "info",
            source_kind: "agent_api_redacted",
            secret_output: false,
            writes: false,
          }],
          non_claims: ["read-only audit projection", "no raw details", "no secret values"],
        }),
      });
    });

    await page.route("**/api/v1/organism/replay?**", async (route) => {
      const url = new URL(route.request().url());
      seen.replay = url.searchParams.get("run_id") === runId;
      await route.fulfill({
        contentType: "application/json",
        body: JSON.stringify({
          contract_version: "organism-replay-v1",
          source: "agent-api",
          source_kind: "agent_api_redacted",
          live: true,
          run_id: runId,
          replay_available: true,
          frames: [{ t: 0, run_state: "planning", active: ["workbench"], regions: ["prefrontal_cortex"], source_kind: "agent_api_redacted" }],
          non_claims: ["read-only audit projection", "no raw details", "no secret values"],
        }),
      });
    });

    await page.goto(`/organism/replay?run_id=${encodeURIComponent(runId)}`, { waitUntil: "networkidle" });
    const feed = page.getByTestId("organism-runtime-feed");
    await expect(feed).toHaveAttribute("data-source-kind", "agent_api_redacted");
    await expect(feed).toHaveAttribute("data-live", "true");
    await expect(feed).toHaveAttribute("data-run-id", runId);
    await expect(feed).toContainText(`run_id=${runId}`);
    await expect(page.getByTestId("organism-replay-frames")).toBeVisible();
    expect(seen.events).toBe(true);
    expect(seen.replay).toBe(true);
  });
});
