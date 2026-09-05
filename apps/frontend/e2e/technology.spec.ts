import { expect, test, type APIRequestContext, type Page, type Route } from "@playwright/test";

type JsonRecord = Record<string, unknown>;
type ContractBodies = {
  inventory: JsonRecord;
  layers: JsonRecord;
  preflight: JsonRecord;
};

const ENDPOINTS = {
  inventory: "/api/v1/clouds",
  layers: "/api/v1/clouds/layers",
  preflight: "/api/v1/clouds/deployment-preflight",
} as const;

const CONTRACTS = {
  inventory: {
    contract: "cloud-provider-inventory-v1",
    evidence: "cloud_provider_inventory_visible",
    endpoint: "GET /api/v1/clouds",
  },
  layers: {
    contract: "cloud-layer-readiness-v1",
    evidence: "cloud_layer_readiness_visible",
    endpoint: "GET /api/v1/clouds/layers",
  },
  preflight: {
    contract: "cloud-deployment-preflight-v1",
    evidence: "cloud_deployment_preflight_visible",
    endpoint: "GET /api/v1/clouds/deployment-preflight",
  },
} as const;

const ALLOWED_SOURCES = new Set([
  "agent-api-boundary",
  "project-state-projection",
  "frontend-projection",
]);

const keyByPath = new Map<string, keyof ContractBodies>([
  [ENDPOINTS.inventory, "inventory"],
  [ENDPOINTS.layers, "layers"],
  [ENDPOINTS.preflight, "preflight"],
]);

function asRecords(value: unknown): JsonRecord[] {
  return Array.isArray(value) ? value.filter((item): item is JsonRecord =>
    typeof item === "object" && item !== null && !Array.isArray(item)) : [];
}

function cloneRecord(value: JsonRecord): JsonRecord {
  return structuredClone(value);
}

async function readContracts(request: APIRequestContext): Promise<ContractBodies> {
  const keys = Object.keys(ENDPOINTS) as Array<keyof ContractBodies>;
  const entries = await Promise.all(keys.map(async (key) => {
    const response = await request.get(ENDPOINTS[key]);
    expect(response.status(), ENDPOINTS[key]).toBe(200);
    const source = response.headers()["x-superbrain-source"];
    expect(ALLOWED_SOURCES.has(source), `${ENDPOINTS[key]} source=${source}`).toBeTruthy();
    return [key, await response.json() as JsonRecord] as const;
  }));
  return Object.fromEntries(entries) as ContractBodies;
}

async function installContractMocks(
  page: Page,
  bodies: ContractBodies,
  mutate?: (key: keyof ContractBodies, attempt: number, body: JsonRecord, route: Route) => Promise<boolean> | boolean,
  source: "agent-api-boundary" | "project-state-projection" | "frontend-projection" = "project-state-projection",
) {
  const attempts: Record<keyof ContractBodies, number> = { inventory: 0, layers: 0, preflight: 0 };
  await page.route("**/api/v1/clouds**", async (route) => {
    const path = new URL(route.request().url()).pathname;
    const key = keyByPath.get(path);
    if (!key) {
      await route.continue();
      return;
    }
    attempts[key] += 1;
    const body = cloneRecord(bodies[key]);
    if (mutate && await mutate(key, attempts[key], body, route)) return;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      headers: { "x-superbrain-source": source },
      body: JSON.stringify(body),
    });
  });
  return attempts;
}

async function expectFailClosed(page: Page) {
  const root = page.getByTestId("technology-runtime-view");
  await expect(root).toBeVisible();
  await expect(root).toHaveAttribute("data-state", "error");
  await expect(page.getByTestId("technology-runtime-error")).toBeVisible();
  await expect(page.getByTestId("technology-runtime-retry")).toBeVisible();
  await expect(page.getByTestId("technology-provider-card")).toHaveCount(0);
  await expect(page.getByTestId("technology-layer-detail")).toHaveCount(0);
}

test("technology runtime contracts expose working filters layer selection and refresh", async ({ page, request }) => {
  const bodies = await readContracts(request);
  const providers = asRecords(bodies.inventory.providers);
  const layerMappings = asRecords(bodies.inventory.seven_layer_mapping);
  const layers = asRecords(bodies.layers.layers);
  const missingGates = Array.isArray(bodies.preflight.missing_or_blocked_gates)
    ? bodies.preflight.missing_or_blocked_gates
    : [];

  expect(bodies.inventory).toMatchObject({
    contract_version: CONTRACTS.inventory.contract,
    evidence_ref: CONTRACTS.inventory.evidence,
    endpoint: CONTRACTS.inventory.endpoint,
    total_count: 8,
  });
  expect(providers).toHaveLength(8);
  expect(layerMappings).toHaveLength(7);
  expect(bodies.layers).toMatchObject({
    contract_version: CONTRACTS.layers.contract,
    evidence_ref: CONTRACTS.layers.evidence,
    endpoint: CONTRACTS.layers.endpoint,
    total_layer_count: 7,
  });
  expect(layers).toHaveLength(7);
  expect(bodies.preflight).toMatchObject({
    contract_version: CONTRACTS.preflight.contract,
    evidence_ref: CONTRACTS.preflight.evidence,
    endpoint: CONTRACTS.preflight.endpoint,
    production_deploy_claim_allowed: false,
  });
  const flyProviders = providers.filter((provider) => provider.id === "fly_io");
  expect(flyProviders).toHaveLength(1);
  expect(["historical_only", "historical_read_verified"]).toContain(flyProviders[0].status);
  expect(flyProviders[0].historical_only).toBe(true);
  expect(flyProviders[0].layers).toEqual([]);
  for (const mapping of layerMappings) {
    expect(Array.isArray(mapping.providers) ? mapping.providers : []).not.toContain("fly_io");
  }

  const observed = new Map<string, number>(Object.values(ENDPOINTS).map((path) => [path, 0]));
  const observedOrigins = new Map<string, Set<string>>(
    Object.values(ENDPOINTS).map((path) => [path, new Set<string>()]),
  );
  page.on("request", (requestEvent) => {
    const url = new URL(requestEvent.url());
    if (!observed.has(url.pathname)) return;
    expect(requestEvent.method(), url.pathname).toBe("GET");
    observed.set(url.pathname, (observed.get(url.pathname) ?? 0) + 1);
    observedOrigins.get(url.pathname)?.add(url.origin);
  });

  await page.goto("/technology", { waitUntil: "networkidle" });
  const root = page.getByTestId("technology-runtime-view");
  await expect(root).toBeVisible();
  await expect(root).toHaveAttribute("data-state", "ready");
  await expect(root).toHaveAttribute("data-provider-count", String(providers.length));
  await expect(root).toHaveAttribute("data-layer-count", String(layers.length));
  await expect(root).toHaveAttribute("data-visible-provider-count", String(providers.length));
  await expect(root).toHaveAttribute("data-selected-layer-id", "layer_1");
  await expect(root).toHaveAttribute("data-provider-filter", "all");
  await expect(root).toHaveAttribute("data-preflight-missing-count", String(missingGates.length));
  await expect(root).toHaveAttribute("data-refresh-count", "1");
  await expect(page.getByTestId("technology-provider-card")).toHaveCount(providers.length);
  await expect(page.getByTestId("technology-preflight-missing-gate")).toHaveCount(missingGates.length);
  await expect(page.getByTestId("technology-declared-runtime")).toContainText("contract_declared");
  await expect(page.getByTestId("technology-declared-toolstack")).toContainText("repo_declared");
  await expect(page.locator("body")).not.toContainText(/Hetzner|GitKraken|Oracle/i);

  const sourceCards = page.getByTestId("technology-runtime-source");
  await expect(sourceCards).toHaveCount(3);
  let sourceIndex = 0;
  for (const [key, path] of Object.entries(ENDPOINTS) as Array<[keyof ContractBodies, string]>) {
    expect(observed.get(path), `${path} initial request count`).toBe(1);
    expect(Array.from(observedOrigins.get(path) ?? [])).toEqual([new URL(page.url()).origin]);
    const source = sourceCards.nth(sourceIndex);
    await expect(source).toHaveAttribute("data-endpoint", CONTRACTS[key].endpoint);
    await expect(source).toHaveAttribute("data-contract-version", CONTRACTS[key].contract);
    await expect(source).toHaveAttribute("data-evidence-ref", CONTRACTS[key].evidence);
    await expect(source).toContainText(CONTRACTS[key].contract);
    await expect(source).toContainText(CONTRACTS[key].evidence);
    await expect(source).toContainText(CONTRACTS[key].endpoint);
    await expect(source).toHaveAttribute("data-response-source", /^(agent-api-boundary|project-state-projection|frontend-projection)$/);
    sourceIndex += 1;
  }

  const fly = page.getByTestId("technology-provider-card").filter({ hasText: /Fly\.io/i });
  await expect(fly).toHaveCount(1);
  await expect(fly).toHaveAttribute("data-provider-id", "fly_io");
  await expect(fly).toHaveAttribute("data-provider-status", /^(historical_only|historical_read_verified)$/);
  await expect(fly).toHaveAttribute("data-historical-only", "true");
  await expect(fly).toContainText(/read_status=(historical_only|historical_read_verified)/i);
  await expect(fly).toContainText(/keine aktive Schicht/i);
  const cloudflare = page.getByTestId("technology-provider-card").filter({ hasText: /Cloudflare-native/i });
  await expect(cloudflare).toHaveCount(1);
  await expect(cloudflare).toHaveAttribute("data-provider-id", "cloudflare_edge");
  for (const layerNo of [2, 3, 4, 6, 7]) {
    await expect(cloudflare).toContainText(new RegExp(`(?:layer[ _]?${layerNo}|L${layerNo})`, "i"));
  }

  await page.locator('[data-testid="technology-provider-filter"][data-filter="historical_only"]').click();
  await expect(root).toHaveAttribute("data-provider-filter", "historical_only");
  await expect(root).toHaveAttribute("data-visible-provider-count", "1");
  await expect(page.getByTestId("technology-provider-card")).toHaveCount(1);
  await expect(fly).toBeVisible();

  await page.locator('[data-testid="technology-provider-filter"][data-filter="all"]').click();
  await expect(root).toHaveAttribute("data-visible-provider-count", String(providers.length));

  await page.locator('[data-testid="technology-layer-select"][data-layer-id="layer_4"]').click();
  await expect(root).toHaveAttribute("data-selected-layer-id", "layer_4");
  const layerDetail = page.getByTestId("technology-layer-detail");
  await expect(layerDetail).toBeVisible();
  await expect(layerDetail).toContainText(/Layer 4|layer_4|LLM Gateway/i);
  await expect(layerDetail).toContainText(/Cloudflare/i);

  await page.getByTestId("technology-runtime-refresh").click();
  await expect(root).toHaveAttribute("data-state", "ready");
  await expect(root).toHaveAttribute("data-refresh-count", "2");
  for (const path of Object.values(ENDPOINTS)) {
    await expect.poll(() => observed.get(path) ?? 0, { message: `${path} refresh request` }).toBe(2);
  }
});

test("technology runtime fails closed on invalid schema", async ({ page, request }) => {
  const bodies = await readContracts(request);
  bodies.inventory.contract_version = "invalid-contract";
  await installContractMocks(page, bodies);
  await page.goto("/technology", { waitUntil: "domcontentloaded" });
  await expectFailClosed(page);
});

test("technology runtime fails closed on cross-contract parity mismatch", async ({ page, request }) => {
  const bodies = await readContracts(request);
  const readinessLayers = asRecords(bodies.layers.layers);
  expect(readinessLayers.length).toBeGreaterThan(0);
  readinessLayers[0].required_providers = ["cloudflare_edge"];
  bodies.layers.layers = readinessLayers;
  await installContractMocks(page, bodies);
  await page.goto("/technology", { waitUntil: "domcontentloaded" });
  await expectFailClosed(page);
});

test("technology runtime fails closed on oversize provider payload", async ({ page, request }) => {
  const bodies = await readContracts(request);
  const providers = asRecords(bodies.inventory.providers);
  const seed = providers[0] ?? { id: "provider", label: "Provider", status: "action_required" };
  bodies.inventory.providers = Array.from({ length: 257 }, (_, index) => ({
    ...seed,
    id: `oversize_provider_${index}`,
    role: `oversize-${index}-`.padEnd(5_000, "x"),
  }));
  bodies.inventory.total_count = 257;
  await installContractMocks(page, bodies);
  await page.goto("/technology", { waitUntil: "domcontentloaded" });
  await expectFailClosed(page);
});

test("technology runtime retries all three GETs after a 503", async ({ page, request }) => {
  const bodies = await readContracts(request);
  const providers = asRecords(bodies.inventory.providers);
  const fly = providers.find((provider) => provider.id === "fly_io");
  expect(fly, "Fly.io provider fixture").toBeDefined();
  if (!fly) throw new Error("Fly.io provider fixture missing");
  fly.configured = true;
  fly.live_verified = true;
  fly.status = "historical_read_verified";
  fly.historical_only = true;
  fly.layers = [];
  bodies.inventory.providers = providers;
  const configuredCount = providers.filter((provider) => provider.configured === true).length;
  bodies.inventory.configured_count = configuredCount;
  bodies.inventory.live_verified_count = providers.filter((provider) => provider.live_verified === true).length;
  bodies.inventory.status = configuredCount === providers.length
    ? "complete"
    : configuredCount > 0
      ? "partial"
      : "action_required";
  const capturedLayers = asRecords(bodies.layers.layers);
  for (const layer of capturedLayers) {
    const requiredProviders = Array.isArray(layer.required_providers) ? [...layer.required_providers] : [];
    layer.configured_providers = requiredProviders;
    layer.live_verified_providers = requiredProviders;
    layer.blockers = [];
    layer.status = "live_verified";
  }
  bodies.layers.layers = capturedLayers;
  bodies.layers.ready_layer_count = capturedLayers.length;
  bodies.layers.partial_layer_count = 0;
  bodies.layers.status = "verified";

  const attempts = await installContractMocks(page, bodies, async (key, attempt, _body, route) => {
    if (key !== "inventory" || attempt !== 1) return false;
    await route.fulfill({
      status: 503,
      contentType: "application/json",
      headers: { "x-superbrain-source": "frontend-projection" },
      body: JSON.stringify({ detail: "temporary technology runtime failure" }),
    });
    return true;
  });

  await page.goto("/technology", { waitUntil: "domcontentloaded" });
  await expectFailClosed(page);
  expect(attempts).toEqual({ inventory: 1, layers: 1, preflight: 1 });

  await page.getByTestId("technology-runtime-retry").click();
  const root = page.getByTestId("technology-runtime-view");
  await expect(root).toHaveAttribute("data-state", "ready");
  await expect(root).toHaveAttribute("data-current-live-proof", "false");
  await expect(root).toContainText("projection_not_current");
  await expect(root).toHaveAttribute("data-provider-count", "8");
  await expect(page.getByTestId("technology-provider-card")).toHaveCount(8);
  expect(attempts).toEqual({ inventory: 2, layers: 2, preflight: 2 });
  const layerDetail = page.getByTestId("technology-layer-detail");
  await expect(layerDetail).toContainText(/captured_contract_value=\d+/);
  await expect(layerDetail).toContainText(/kein aktueller Beweis/i);
  await expect(page.getByTestId("technology-provider-card").first()).toHaveAttribute(
    "data-live-value-kind",
    "captured_contract",
  );

  const flyCard = page.locator('[data-testid="technology-provider-card"][data-provider-id="fly_io"]');
  await expect(flyCard).toHaveAttribute("data-provider-status", "historical_read_verified");
  await expect(flyCard).toHaveAttribute("data-configured", "true");
  await expect(flyCard).toHaveAttribute("data-live-verified", "true");
  await expect(flyCard).toHaveAttribute("data-historical-only", "true");
  await expect(flyCard).toContainText("read_status=historical_read_verified");
  await expect(flyCard).toContainText(/keine aktive Schicht/i);
  await expect(page.getByTestId("technology-declared-runtime")).not.toContainText(/Fly\.io/i);

  await page.locator('[data-testid="technology-provider-filter"][data-filter="live_verified"]').click();
  await expect(flyCard).toHaveCount(0);
  await page.locator('[data-testid="technology-provider-filter"][data-filter="historical_only"]').click();
  await expect(flyCard).toBeVisible();
});

test("technology runtime fails closed on impossible current agent boundary live claims", async ({ page, request }) => {
  const bodies = await readContracts(request);
  const providers = asRecords(bodies.inventory.providers);
  for (const provider of providers) {
    provider.configured = false;
    provider.live_verified = false;
    if (provider.id !== "fly_io") provider.status = "action_required";
  }
  bodies.inventory.providers = providers;
  bodies.inventory.configured_count = 0;
  bodies.inventory.live_verified_count = 0;
  bodies.inventory.status = "action_required";

  const layers = asRecords(bodies.layers.layers);
  for (const layer of layers) {
    layer.configured_providers = [];
    layer.live_verified_providers = [];
    layer.status = "live_verified";
  }
  bodies.layers.layers = layers;
  bodies.layers.ready_layer_count = layers.length;
  bodies.layers.partial_layer_count = 0;
  bodies.layers.status = "verified";

  await installContractMocks(page, bodies, undefined, "agent-api-boundary");
  await page.goto("/technology", { waitUntil: "domcontentloaded" });
  await expectFailClosed(page);
});
