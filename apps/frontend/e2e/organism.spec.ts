import { test, expect } from "@playwright/test";
import { mkdirSync, writeFileSync } from "node:fs";
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
    expect(topology.evidence_ref).toBe("organism_topology_visible");
    expect(topology.endpoint).toBe("/api/v1/organism/topology");
    expect(topology.source_kind).toBe("contract");
    expect(topology.live).toBe(false);
    expect(Array.isArray(topology.nodes)).toBeTruthy();
    expect(topology.nodes.length).toBeGreaterThan(0);
    expect(Array.isArray(topology.edges)).toBeTruthy();
    expect(topology.edges.length).toBeGreaterThan(0);
    expect(Array.isArray(topology.non_claims)).toBeTruthy();
    expect(topology.non_claims.length).toBeGreaterThan(0);
    expect(topology.non_claims.every((item: unknown) => typeof item === "string" && item.trim().length > 0)).toBeTruthy();

    const nodes = topology.nodes as Array<{
      id: string;
      kind: string;
      secret_output: boolean;
      writes: boolean;
    }>;
    const nodeIds = new Set(nodes.map((node) => node.id));
    expect(nodeIds.size).toBe(nodes.length);
    for (const node of nodes) {
      expect(node.id.trim(), "node id").not.toBe("");
      expect(node.kind.trim(), `node kind ${node.id}`).not.toBe("");
      expect(node.secret_output, `node secret_output ${node.id}`).toBe(false);
      expect(node.writes, `node writes ${node.id}`).toBe(false);
    }
    expect(nodeIds.has("layer:FE")).toBeTruthy();
    expect(nodeIds.has("agent:planner")).toBeTruthy();
    expect(nodeIds.has("tool:mcp_gateway")).toBeTruthy();
    expect(nodeIds.has("model:deepseek-ai/DeepSeek-V4-Pro")).toBeTruthy();
    expect(nodeIds.has("page:organism-map")).toBeTruthy();
    for (const edge of topology.edges as Array<{ from: string; to: string; kind: string }>) {
      expect(edge.kind.trim(), `edge kind ${edge.from} -> ${edge.to}`).not.toBe("");
      expect(nodeIds.has(edge.from), `edge source ${edge.from}`).toBeTruthy();
      expect(nodeIds.has(edge.to), `edge target ${edge.to}`).toBeTruthy();
    }
    expect(topology.non_claims.join(" ")).toMatch(/no provider write/i);
    expect(topology.non_claims.join(" ")).toMatch(/no secret/i);

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

  test("organism map renders topology counts, filters, selection, and adjacency without the Phase-6 scene", async ({ page, request }) => {
    const topologyResp = await request.get("/api/v1/organism/topology");
    expect(topologyResp.status()).toBe(200);
    const topology = await topologyResp.json() as {
      nodes: Array<{ id: string; kind: string }>;
      edges: Array<{ from: string; to: string; kind: string }>;
    };
    const plannerId = "agent:planner";
    const coderId = "agent:coder";
    const coderIncoming = topology.edges.filter((edge) => edge.to === coderId).length;
    const coderOutgoing = topology.edges.filter((edge) => edge.from === coderId).length;
    const agentNodeCount = topology.nodes.filter((node) => node.kind === "agent_profile").length;
    const adjacentEdge = topology.edges.find((edge) => edge.from === coderId)
      ?? topology.edges.find((edge) => edge.to === coderId);
    if (!adjacentEdge) {
      throw new Error("agent:coder must expose at least one topology adjacency");
    }
    const adjacentNodeId = adjacentEdge.from === coderId ? adjacentEdge.to : adjacentEdge.from;
    const adjacentDirection = adjacentEdge.from === coderId ? "outgoing" : "incoming";

    const topologyUiResponse = page.waitForResponse((response) => {
      const url = new URL(response.url());
      return url.pathname === "/api/v1/organism/topology"
        && response.request().method() === "GET";
    });
    await page.goto("/organism/map", { waitUntil: "networkidle" });
    const fetchedTopology = await topologyUiResponse;
    expect(fetchedTopology.status()).toBe(200);
    expect(new URL(fetchedTopology.url()).origin).toBe(new URL(page.url()).origin);

    const map = page.getByTestId("organism-topology-map");
    await expect(map).toBeVisible();
    await expect(map).toHaveAttribute("data-contract-version", "organism-topology-v1");
    await expect(map).toHaveAttribute("data-evidence-ref", "organism_topology_visible");
    await expect(map).toHaveAttribute("data-endpoint", "/api/v1/organism/topology");
    await expect(map).toHaveAttribute("data-source-kind", "contract");
    await expect(map).toHaveAttribute("data-live", "false");
    await expect(map).toHaveAttribute("data-read-only", "true");
    await expect(map).toHaveAttribute("data-node-count", String(topology.nodes.length));
    await expect(map).toHaveAttribute("data-edge-count", String(topology.edges.length));
    await expect(map).toHaveAttribute("data-selected-node-id", "page:organism-map");
    await expect(page.getByTestId("organism-topology-node")).toHaveCount(topology.nodes.length);

    const agentFilter = page.locator('[data-testid="organism-topology-kind-filter"][data-node-kind="agent_profile"]');
    await agentFilter.click();
    await expect(agentFilter).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByTestId("organism-topology-node")).toHaveCount(agentNodeCount);
    await expect(map).toHaveAttribute("data-selected-node-id", plannerId);

    const planner = page.locator('[data-testid="organism-topology-node"][data-node-id="agent:planner"]');
    await expect(planner).toHaveAttribute("aria-pressed", "true");
    const coder = page.locator('[data-testid="organism-topology-node"][data-node-id="agent:coder"]');
    await coder.click();
    await expect(map).toHaveAttribute("data-selected-node-id", coderId);
    await expect(coder).toHaveAttribute("aria-pressed", "true");
    await expect(planner).toHaveAttribute("aria-pressed", "false");

    const adjacency = page.getByTestId("organism-topology-adjacency");
    await expect(adjacency).toBeVisible();
    await expect(adjacency).toHaveAttribute("data-incoming-count", String(coderIncoming));
    await expect(adjacency).toHaveAttribute("data-outgoing-count", String(coderOutgoing));
    await expect(adjacency).toContainText(coderId);

    const adjacentNode = page.locator(
      `[data-testid="organism-topology-adjacent-node"][data-node-id="${adjacentNodeId}"][data-edge-kind="${adjacentEdge.kind}"][data-direction="${adjacentDirection}"]`,
    ).first();
    await expect(adjacentNode).toBeVisible();
    await adjacentNode.click();
    await expect(map).toHaveAttribute("data-selected-node-id", adjacentNodeId);
    await expect(page.getByTestId("organism-topology-node")).toHaveCount(topology.nodes.length);

    await expect(page.locator("canvas")).toHaveCount(0);
    await expect(page.locator(".cortex-wrap")).toHaveCount(0);
    await expect(page.locator('[data-testid^="phase6-"]')).toHaveCount(0);
  });

  test("organism map rejects an oversized otherwise-valid topology before rendering", async ({ page }) => {
    const oversizedTopology = JSON.stringify({
      contract_version: "organism-topology-v1",
      evidence_ref: "organism_topology_visible",
      endpoint: "/api/v1/organism/topology",
      source_kind: "contract",
      live: false,
      nodes: [
        {
          id: "page:organism-map",
          kind: "workspace_page",
          writes: false,
          secret_output: false,
          ignored: "x".repeat(600_000),
        },
        {
          id: "region:thalamus",
          kind: "brain_region",
          writes: false,
          secret_output: false,
        },
      ],
      edges: [{ from: "page:organism-map", to: "region:thalamus", kind: "page_to_brain_region" }],
      non_claims: ["static topology contract", "no provider write", "no secret values"],
    });
    await page.route("**/api/v1/organism/topology", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: oversizedTopology,
      });
    });

    await page.goto("/organism/map", { waitUntil: "networkidle" });
    const map = page.getByTestId("organism-topology-map");
    await expect(map).toBeVisible();
    await expect(page.getByTestId("organism-topology-error")).toContainText("Größenlimit");
    await expect(map).toHaveAttribute("data-contract-version", "pending");
    await expect(map).toHaveAttribute("data-node-count", "0");
    await expect(page.getByTestId("organism-topology-node")).toHaveCount(0);
  });

  test("organism map retries after a transient topology failure", async ({ page }) => {
    let attempts = 0;
    await page.route("**/api/v1/organism/topology", async (route) => {
      attempts += 1;
      if (attempts === 1) {
        await route.fulfill({
          status: 503,
          contentType: "application/json",
          body: JSON.stringify({ detail: "transient topology failure" }),
        });
        return;
      }
      await route.continue();
    });

    await page.goto("/organism/map", { waitUntil: "networkidle" });
    const map = page.getByTestId("organism-topology-map");
    await expect(page.getByTestId("organism-topology-error")).toContainText("503");
    await expect(map).toHaveAttribute("data-contract-version", "pending");

    await page.getByTestId("organism-topology-retry").click();
    await expect(map).toHaveAttribute("data-contract-version", "organism-topology-v1");
    await expect(map).toHaveAttribute("data-node-count", /^\d+$/);
    await expect(page.getByTestId("organism-topology-error")).toHaveCount(0);
    expect(attempts).toBe(2);
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

    const visualV2 = page.getByTestId("organism-visual-v2");
    await expect(visualV2).toBeVisible();
    await expect(visualV2).toHaveAttribute("data-visual-dot-globe", "fibonacci-360");
    await expect(visualV2).toHaveAttribute("data-visual-matrix-rain", "dom");
    await expect(visualV2).toHaveAttribute("data-visual-scanlines", "hud");
    await expect(visualV2).toHaveAttribute("data-visual-shards", "plane-12-opacity-0.06");
    await expect(visualV2).toHaveAttribute("data-visual-waveform", "runtime-telemetry");
    await expect(visualV2).toHaveAttribute("data-visual-core-edges", "active");
    await expect(visualV2).toHaveAttribute("data-visual-core-transmission", /active|hardware-gated/);
    await expect(page.getByTestId("organism-matrix-rain").locator(".cortex-matrix-column")).toHaveCount(18);
    await expect(page.getByTestId("organism-scanlines")).toBeVisible();
    await expect(page.getByTestId("organism-hud-overlay")).toBeVisible();
    const waveform = page.getByTestId("organism-telemetry-waveform");
    await expect(waveform).toBeVisible();
    await expect(waveform).toHaveAttribute("data-telemetry-source", /^[A-Za-z0-9_.:-]{1,32}$/);
    expect(Number(await waveform.getAttribute("data-sample-count"))).toBeGreaterThanOrEqual(2);

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
    const visualV2 = page.getByTestId("organism-visual-v2");
    await expect(visualV2).toBeVisible();
    await expect(visualV2).toHaveAttribute("data-visual-dot-globe", "fibonacci-360");
    await expect(page.getByTestId("organism-matrix-rain")).toBeVisible();
    await expect(page.getByTestId("organism-scanlines")).toBeVisible();
    await expect(page.getByTestId("organism-hud-overlay")).toBeVisible();
    await expect(page.getByTestId("organism-telemetry-waveform")).toBeVisible();
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
    test.setTimeout(180_000);
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

    const clockStart = new Date("2026-07-31T00:00:00Z");
    await page.clock.install({ time: clockStart });
    await page.goto("/organism?gpu=force", { waitUntil: "domcontentloaded" });
    const controls = page.getByTestId("phase6-camera-lighting-controls");
    const canvasState = page.locator('.cortex-wrap[data-camera-lighting-local-only="true"]').first();
    await expect(controls).toBeVisible();
    await expect(canvasState).toBeVisible({ timeout: 30_000 });
    await expect(canvasState.locator("canvas")).toBeVisible({ timeout: 30_000 });
    const readyTime = await page.evaluate(() => Date.now());
    // Leave enough headroom for a loaded Windows runner between the Date probe
    // and pauseAt; Playwright rejects any target overtaken by the live clock.
    await page.clock.pauseAt(readyTime + 60_000);
    await page.clock.runFor(80);
    await expect(canvasState).toHaveAttribute("data-camera-preset", "wide");
    await expect(canvasState).toHaveAttribute("data-camera-fov", "45");
    await expect(canvasState).toHaveAttribute("data-camera-position", "0.00,0.60,7.00");
    await expect(canvasState).toHaveAttribute("data-lighting-profile", "studio");
    await expect(canvasState).toHaveAttribute("data-tone-exposure", "1.00");
    await expect(canvasState).toHaveAttribute("data-camera-lighting-local-only", "true");

    const autoRotateButton = page.getByRole("button", { name: /Automatisch drehen/ });
    await expect(autoRotateButton).toHaveText("Automatisch drehen ⏸");
    await autoRotateButton.click();
    await expect(autoRotateButton).toHaveText("Automatisch drehen ▶");

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

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.clock.runFor(40);
    const canvasProof = await page.screenshot();
    expect(canvasProof.length, "camera and lighting viewport screenshot bytes").toBeGreaterThan(25_000);
    const artifactPath = phase6ArtifactPath("phase6-camera-lighting.png");
    if (artifactPath) {
      writeFileSync(artifactPath, canvasProof);
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
    const canvasState = page.locator('.cortex-wrap[data-gameplay-local-only="true"]').first();
    await expect(controls).toBeVisible();
    await expect(canvasState).toBeVisible({ timeout: 30_000 });
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
    await expect.poll(async () => canvasState.getAttribute("data-gameplay-ticks"), { timeout: 10_000 }).not.toBe(pausedTicks);

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
    test.setTimeout(300_000);
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
    const canvasState = page.locator('.cortex-wrap[data-asset-policy-local-only="true"]').first();
    await expect(controls).toBeVisible();
    await expect(canvasState).toBeVisible({ timeout: 30_000 });
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
    test.setTimeout(300_000);
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
    const canvasState = page.locator('.cortex-wrap[data-camera-lighting-local-only="true"]').first();
    await expect(page.getByTestId("phase6-save-load-controls")).toBeVisible();
    await expect(canvasState).toBeVisible({ timeout: 30_000 });
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
    await page.reload({ waitUntil: "domcontentloaded" });
    await expect(page.getByTestId("phase6-save-load-controls")).toBeVisible({ timeout: 30_000 });
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
    const coreAssetResponsePromise = page.waitForResponse(
      (response) => new URL(response.url()).pathname === "/organism/core.glb",
      { timeout: 30_000 },
    );
    await page.goto("/organism", { waitUntil: "networkidle" });
    const coreAssetResponse = await coreAssetResponsePromise;
    expect(coreAssetResponse.ok(), "core GLB is loaded before accessibility request capture").toBeTruthy();
    expect(await coreAssetResponse.finished(), "core GLB response finishes before accessibility request capture").toBeNull();
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
    const canvasState = page.locator('.cortex-wrap[data-netcode-transport="loopback"]').first();
    const start = page.getByTestId("phase6-netcode-start");
    const tick = page.getByTestId("phase6-netcode-tick");
    await expect(page.getByTestId("phase6-netcode-controls")).toBeVisible();
    await expect(canvasState).toBeVisible({ timeout: 30_000 });
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

  test("organism Phase-6 local scoreboard and performance sample stay browser-local", async ({ page }) => {
    test.setTimeout(420_000);
    const contractResponse = await page.request.get("/api/v1/phase6/local-scoreboard-performance/contract");
    expect(contractResponse.status()).toBe(200);
    const contract = await contractResponse.json();
    expect(contract.contract_version).toBe("phase6-local-scoreboard-performance-runtime-v1");
    expect(contract.leaderboard_maximum_entries).toBe(3);
    expect(contract.leaderboard_sort_order).toEqual(["score_desc", "completions_desc", "capture_sequence_asc"]);
    expect(contract.score_source).toBe("current_deterministic_gameplay_state");
    expect(contract.performance_sample_source).toBe("existing_threejs_renderer_stats");
    expect(contract.performance_sample_count).toBe(12);
    expect(contract.performance_minimum_fps).toBe(25);
    expect(contract.performance_maximum_frame_ms).toBe(40);
    expect(contract.leaderboard_sync_allowed).toBe(false);
    expect(contract.persistent_storage_allowed).toBe(false);
    expect(contract.telemetry_allowed).toBe(false);
    expect(contract.network_calls_required).toBe(false);
    expect(contract.scale_capacity_claim_allowed).toBe(false);

    const errors: string[] = [];
    const localRequests: string[] = [];
    const webSockets: string[] = [];
    let captureLocalRequests = false;
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
    page.on("request", (request) => {
      if (captureLocalRequests && ["fetch", "xhr"].includes(request.resourceType())) localRequests.push(request.url());
    });
    page.on("websocket", (socket) => {
      if (captureLocalRequests) webSockets.push(socket.url());
    });

    const coreAssetResponsePromise = page.waitForResponse(
      (response) => new URL(response.url()).pathname === "/organism/core.glb",
      { timeout: 30_000 },
    );
    await page.goto("/organism", { waitUntil: "networkidle" });
    const coreAssetResponse = await coreAssetResponsePromise;
    expect(coreAssetResponse.ok(), "core GLB is loaded before scoreboard request capture").toBeTruthy();
    expect(await coreAssetResponse.finished(), "core GLB response finishes before scoreboard request capture").toBeNull();
    const controls = page.getByTestId("phase6-scoreboard-performance-controls");
    const leaderboard = page.getByTestId("phase6-leaderboard-list");
    const leaderboardState = page.getByTestId("phase6-leaderboard-state");
    const capture = page.getByTestId("phase6-leaderboard-capture");
    const performanceState = page.getByTestId("phase6-performance-state");
    const performanceResult = page.getByTestId("phase6-performance-result");
    await expect(controls).toBeVisible();
    await expect(controls).toHaveAttribute("data-sync", "false");
    await expect(controls).toHaveAttribute("data-storage", "false");
    await expect(controls).toHaveAttribute("data-network", "false");
    await expect(capture).toBeDisabled();
    await expect(leaderboard).toContainText("Noch keine Runs erfasst");
    await expect(leaderboardState).toContainText("entries=0/3");
    await expect(leaderboardState).toContainText("sync=false");
    await expect(performanceState).toContainText("status=idle");
    await expect(performanceResult).toHaveAttribute("data-result", "idle");

    const cookieBefore = await page.evaluate(() => document.cookie);
    const persistenceBefore = await page.evaluate(async () => ({
      localStorage: Object.fromEntries(Array.from({ length: window.localStorage.length }, (_, index) => {
        const key = window.localStorage.key(index) ?? "";
        return [key, window.localStorage.getItem(key)];
      })),
      sessionStorage: Object.fromEntries(Array.from({ length: window.sessionStorage.length }, (_, index) => {
        const key = window.sessionStorage.key(index) ?? "";
        return [key, window.sessionStorage.getItem(key)];
      })),
      indexedDbNames: typeof indexedDB.databases === "function"
        ? (await indexedDB.databases()).map((database) => database.name ?? "").sort()
        : [],
    }));
    await page.evaluate(() => {
      const counters = {
        fetch: 0,
        xhr: 0,
        websocket: 0,
        eventsource: 0,
        sendBeacon: 0,
        webrtc: 0,
        storageSetItem: 0,
        storageRemoveItem: 0,
        storageClear: 0,
        indexedDbOpen: 0,
        indexedDbDelete: 0,
        cacheStorage: 0,
        serviceWorkerRegister: 0,
        cookieWrite: 0,
      };
      type CounterKey = keyof typeof counters;
      const guardedWindow = window as Window & { __phase6GuardCalls?: typeof counters };
      guardedWindow.__phase6GuardCalls = counters;
      const record = (key: CounterKey) => { counters[key] += 1; };
      const wrapMethod = (target: object, property: string, key: CounterKey) => {
        const original = Reflect.get(target, property);
        if (typeof original !== "function") return;
        Object.defineProperty(target, property, {
          configurable: true,
          writable: true,
          value: function guardedMethod(this: unknown, ...args: unknown[]) {
            record(key);
            return Reflect.apply(original, this, args);
          },
        });
      };
      const wrapConstructor = (target: object, property: string, key: CounterKey) => {
        const original = Reflect.get(target, property);
        if (typeof original !== "function") return;
        const guarded = new Proxy(original, {
          construct(constructor, args, newTarget) {
            record(key);
            return Reflect.construct(constructor, args, newTarget);
          },
        });
        Reflect.set(target, property, guarded);
      };

      wrapMethod(window, "fetch", "fetch");
      wrapMethod(XMLHttpRequest.prototype, "open", "xhr");
      wrapConstructor(window, "WebSocket", "websocket");
      wrapConstructor(window, "EventSource", "eventsource");
      wrapMethod(navigator, "sendBeacon", "sendBeacon");
      wrapConstructor(window, "RTCPeerConnection", "webrtc");
      wrapConstructor(window, "webkitRTCPeerConnection", "webrtc");
      wrapMethod(Storage.prototype, "setItem", "storageSetItem");
      wrapMethod(Storage.prototype, "removeItem", "storageRemoveItem");
      wrapMethod(Storage.prototype, "clear", "storageClear");
      wrapMethod(IDBFactory.prototype, "open", "indexedDbOpen");
      wrapMethod(IDBFactory.prototype, "deleteDatabase", "indexedDbDelete");
      if ("caches" in window) {
        const cachePrototype = Object.getPrototypeOf(window.caches) as object;
        for (const method of ["open", "delete", "match", "keys"]) wrapMethod(cachePrototype, method, "cacheStorage");
      }
      if (navigator.serviceWorker) wrapMethod(Object.getPrototypeOf(navigator.serviceWorker) as object, "register", "serviceWorkerRegister");
      const cookieDescriptor = Object.getOwnPropertyDescriptor(Document.prototype, "cookie");
      if (cookieDescriptor?.configurable && cookieDescriptor.get && cookieDescriptor.set) {
        Object.defineProperty(Document.prototype, "cookie", {
          configurable: true,
          enumerable: cookieDescriptor.enumerable,
          get: cookieDescriptor.get,
          set(value: string) {
            record("cookieWrite");
            cookieDescriptor.set?.call(this, value);
          },
        });
      }
    });

    captureLocalRequests = true;
    await page.getByTestId("phase6-gameplay-pause").click();
    await expect(page.getByTestId("phase6-gameplay-state")).toContainText("paused=true");

    await page.getByTestId("phase6-gameplay-complete").click();
    await expect(page.getByTestId("phase6-gameplay-state")).toContainText("completions=1");
    await capture.click();

    await page.getByTestId("phase6-gameplay-reset").click();
    await page.getByTestId("phase6-gameplay-complete").click();
    await page.getByTestId("phase6-gameplay-complete").click();
    await expect(page.getByTestId("phase6-gameplay-state")).toContainText("score=10");
    await expect(page.getByTestId("phase6-gameplay-state")).toContainText("completions=2");
    await capture.click();

    await page.getByTestId("phase6-gameplay-reset").click();
    await page.getByTestId("phase6-gameplay-complete").click();
    await page.getByTestId("phase6-gameplay-complete").click();
    await page.getByTestId("phase6-gameplay-complete").click();
    await expect(page.getByTestId("phase6-gameplay-state")).toContainText("score=20");
    await expect(page.getByTestId("phase6-gameplay-state")).toContainText("completions=3");
    await capture.click();
    await capture.click();

    await expect(leaderboard.locator("li")).toHaveCount(3);
    await expect(leaderboardState).toContainText("entries=3/3");
    await expect(leaderboardState).toContainText("sort=score_desc,completions_desc,capture_sequence_asc");
    const rankedRunIds = await leaderboard.locator("li").evaluateAll((entries) => entries.map((entry) => entry.getAttribute("data-run-id")));
    expect(rankedRunIds, "score, completion, then capture-sequence ordering").toEqual(["L003", "L004", "L002"]);
    await expect(leaderboard.locator("li").nth(0)).toContainText("#1");
    await expect(leaderboard.locator("li").nth(0)).toContainText("Score20");
    await expect(leaderboard.locator("li").nth(1)).toContainText("L004");

    const observedTop3 = await leaderboard.locator("li").evaluateAll((entries) => entries.map((entry, index) => ({
      rank: index + 1,
      runId: entry.getAttribute("data-run-id"),
      captureSequence: Number(entry.getAttribute("data-capture-sequence")),
      score: Number(entry.getAttribute("data-score")),
      completions: Number(entry.getAttribute("data-completions")),
    })));
    await page.getByTestId("phase6-gameplay-reset").click();
    await page.getByTestId("phase6-gameplay-complete").click();
    expect(await leaderboard.locator("li").evaluateAll((entries) => entries.map((entry) => entry.getAttribute("data-run-id"))), "captured run snapshots do not follow later gameplay mutations").toEqual(["L003", "L004", "L002"]);
    await expect(leaderboard.locator("li").nth(0)).toHaveAttribute("data-score", "20");

    const performanceStart = page.getByTestId("phase6-performance-start");
    await expect(performanceState).toContainText("renderer_ready=true", { timeout: 30_000 });
    await expect(performanceStart).toBeEnabled();
    await performanceStart.click();
    await expect(performanceState).toContainText("status=sampling");
    await expect(performanceState).toContainText("min_fps=25");
    await expect(performanceState).toContainText("max_ms=40");
    await expect(performanceState).toContainText("capacity_claim=false");
    await expect(performanceState).toContainText("scale_claim=false");
    await expect(performanceState).toContainText("gpu_benchmark=false");
    await expect(performanceState).toContainText("frame_ms=derived_from_fps");
    await expect(performanceState).toContainText("samples=12/12", { timeout: 18_000 });
    await page.getByTestId("phase6-performance-finish").evaluate((button: HTMLButtonElement) => {
      if (!button.disabled) button.click();
    });
    await expect(performanceState).toContainText(/status=(pass|fail)/);
    await expect(performanceResult).toHaveAttribute("data-result", /pass|fail/);
    await expect(performanceResult).toContainText("12 Samples");

    const rawSamples = JSON.parse(await performanceState.getAttribute("data-samples") ?? "[]") as Array<{ fps: number; ms: number }>;
    expect(rawSamples).toHaveLength(12);
    expect(rawSamples.every((sample) => Number.isFinite(sample.fps) && Number.isFinite(sample.ms) && sample.fps > 0 && sample.ms > 0)).toBeTruthy();
    const averageFps = Number(await performanceResult.getAttribute("data-average-fps"));
    const averageMs = Number(await performanceResult.getAttribute("data-average-ms"));
    expect((await performanceResult.getAttribute("data-average-fps")) ?? "").toMatch(/^\d+\.\d$/);
    expect((await performanceResult.getAttribute("data-average-ms")) ?? "").toMatch(/^\d+\.\d$/);
    const expectedAverageFps = Math.round((rawSamples.reduce((sum, sample) => sum + sample.fps, 0) / 12) * 10) / 10;
    const expectedAverageMs = Math.round((rawSamples.reduce((sum, sample) => sum + sample.ms, 0) / 12) * 10) / 10;
    expect(averageFps).toBe(expectedAverageFps);
    expect(averageMs).toBe(expectedAverageMs);
    const expectedClassification = averageFps >= 25 && averageMs <= 40 ? "pass" : "fail";
    expect(await performanceResult.getAttribute("data-result")).toBe(expectedClassification);

    const canvas = page.locator("canvas").first();
    const canvasProof = await canvas.screenshot();
    expect(canvasProof.length, "scoreboard performance canvas screenshot bytes").toBeGreaterThan(25_000);
    const canvasPngDataUrl = `data:image/png;base64,${canvasProof.toString("base64")}`;
    const pixelStats = await page.evaluate(async (pngDataUrl) => {
      const source = new Image();
      source.src = pngDataUrl;
      await source.decode();
      const raster = document.createElement("canvas");
      raster.width = 32;
      raster.height = 32;
      const context = raster.getContext("2d", { willReadFrequently: true });
      if (!context) throw new Error("2D pixel probe unavailable");
      context.drawImage(source, 0, 0, raster.width, raster.height);
      const pixels = context.getImageData(0, 0, raster.width, raster.height).data;
      let nonZeroSamples = 0;
      const buckets = new Set<string>();
      for (let offset = 0; offset < pixels.length; offset += 4) {
        const red = pixels[offset];
        const green = pixels[offset + 1];
        const blue = pixels[offset + 2];
        const alpha = pixels[offset + 3];
        if (alpha > 0 && red + green + blue > 0) nonZeroSamples += 1;
        if (alpha > 0) buckets.add(`${red >> 4}:${green >> 4}:${blue >> 4}:${alpha >> 6}`);
      }
      return { width: raster.width, height: raster.height, nonZeroSamples, uniqueColorBuckets: buckets.size };
    }, canvasPngDataUrl);
    expect(pixelStats.nonZeroSamples, "canvas pixel raster contains visible color samples").toBeGreaterThan(100);
    expect(pixelStats.uniqueColorBuckets, "canvas pixel raster has varied color buckets").toBeGreaterThan(8);

    const artifactPath = phase6ArtifactPath("phase6-local-scoreboard-performance.png");
    if (artifactPath) {
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.screenshot({ path: artifactPath, fullPage: true });
    }

    await page.getByTestId("phase6-performance-reset").click();
    await performanceStart.click();
    await expect(performanceState).toContainText("status=sampling");
    await page.getByTestId("phase6-reduced-motion-toggle").click();
    await expect(performanceState).toContainText("status=fail");
    await expect(performanceState).toContainText("reason=reduced_motion");
    await expect(performanceResult).toHaveAttribute("data-reason", "reduced_motion");
    await page.getByTestId("phase6-reduced-motion-toggle").click();
    await expect(page.locator("canvas").first()).toBeVisible();
    await page.getByTestId("phase6-performance-reset").click();

    await page.getByTestId("phase6-leaderboard-reset").click();
    await expect(leaderboard).toContainText("Noch keine Runs erfasst");
    await expect(leaderboardState).toContainText("entries=0/3");
    await expect(page.getByTestId("phase6-leaderboard-reset")).toBeDisabled();
    await capture.click();
    await expect(leaderboard.locator("li")).toHaveCount(1);
    await expect(leaderboard.locator("li").first()).toHaveAttribute("data-run-id", "L001");

    const cookieAfterControls = await page.evaluate(() => document.cookie);
    expect(cookieAfterControls, "controls do not mutate document.cookie").toBe(cookieBefore);
    const persistenceAfter = await page.evaluate(async () => ({
      localStorage: Object.fromEntries(Array.from({ length: window.localStorage.length }, (_, index) => {
        const key = window.localStorage.key(index) ?? "";
        return [key, window.localStorage.getItem(key)];
      })),
      sessionStorage: Object.fromEntries(Array.from({ length: window.sessionStorage.length }, (_, index) => {
        const key = window.sessionStorage.key(index) ?? "";
        return [key, window.sessionStorage.getItem(key)];
      })),
      indexedDbNames: typeof indexedDB.databases === "function"
        ? (await indexedDB.databases()).map((database) => database.name ?? "").sort()
        : [],
    }));
    expect(persistenceAfter, "controls do not alter LocalStorage, SessionStorage, or IndexedDB names").toEqual(persistenceBefore);
    const guardCounters = await page.evaluate(() => {
      const guardedWindow = window as Window & { __phase6GuardCalls?: Record<string, number> };
      return guardedWindow.__phase6GuardCalls ?? {};
    });
    expect(guardCounters, "network and persistence API guard counters remain zero").toEqual({
      fetch: 0,
      xhr: 0,
      websocket: 0,
      eventsource: 0,
      sendBeacon: 0,
      webrtc: 0,
      storageSetItem: 0,
      storageRemoveItem: 0,
      storageClear: 0,
      indexedDbOpen: 0,
      indexedDbDelete: 0,
      cacheStorage: 0,
      serviceWorkerRegister: 0,
      cookieWrite: 0,
    });

    const observedPath = phase6ArtifactPath("phase6-local-scoreboard-performance-observed.json");
    if (observedPath) {
      writeFileSync(observedPath, JSON.stringify({
        contractVersion: contract.contract_version,
        leaderboard: { maximumEntries: 3, observedTop3 },
        performance: {
          samples: rawSamples,
          averages: { fps: averageFps, frameIntervalMs: averageMs },
          terminalClassification: expectedClassification,
          thresholds: { minimumFps: 25, maximumFrameIntervalMs: 40 },
          frameIntervalSource: "derived_from_fps",
          evidenceScope: "local_interaction",
          gpuBenchmarkClaimed: false,
        },
        guards: { ...guardCounters, playwrightFetchXhr: localRequests.length, playwrightWebsocket: webSockets.length },
        pixelStats,
        viewport: page.viewportSize(),
        nonClaims: { sync: false, storage: false, network: false, capacityClaim: false, scaleClaim: false },
      }, null, 2), "utf8");
    }

    captureLocalRequests = false;
    await page.reload({ waitUntil: "domcontentloaded", timeout: 60_000 });
    await expect(page.getByTestId("phase6-leaderboard-list")).toContainText("Noch keine Runs erfasst", { timeout: 30_000 });
    await expect(page.getByTestId("phase6-leaderboard-state")).toContainText("entries=0/3", { timeout: 30_000 });
    expect(await page.evaluate(() => document.cookie), "reload creates no scoreboard cookie persistence").toBe(cookieBefore);

    expect(localRequests, "scoreboard and performance controls perform no fetch or XHR").toEqual([]);
    expect(webSockets, "scoreboard and performance controls open no WebSocket").toEqual([]);
    expect(errors, "no console/page errors during scoreboard and performance interactions").toEqual([]);
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
    const waveform = page.getByTestId("organism-telemetry-waveform");
    await expect(waveform).toHaveAttribute("data-telemetry-source", "agent_api_redacted");
    await expect(waveform).toHaveAttribute("data-telemetry-live", "true");
    await expect(waveform).toHaveAttribute("data-event-count", "1");
    await expect(waveform).toHaveAttribute("data-frame-count", "1");
    expect(Number(await waveform.getAttribute("data-sample-count"))).toBeGreaterThanOrEqual(2);
    expect(seen.events).toBe(true);
    expect(seen.replay).toBe(true);
  });
});
