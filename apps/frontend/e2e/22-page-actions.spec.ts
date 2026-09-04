import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { expect, test, type BrowserContext, type Locator, type Page } from "@playwright/test";
import {
  ACTION_MATRIX,
  ACTION_MATRIX_CONTRACT_VERSION,
  ACTION_MATRIX_SUMMARY,
  validateActionMatrix,
  type ActionFamily,
  type ActionMember,
  type PageActionEntry,
} from "../lib/actionMatrix";
import { WORKSPACE_PAGES } from "../lib/nav";

const baseUrl = (process.env.PAGE_ACTIONS_BASE_URL ?? "http://localhost:8081").trim().replace(/\/+$/, "");
const proofScope = (process.env.PAGE_ACTIONS_PROOF_SCOPE ?? "dev_only_localhost").trim();
const expectedSourceCommitSha = (process.env.PAGE_ACTIONS_SOURCE_COMMIT_SHA ?? "").trim();
const expectedSourceArchiveSha256 = (process.env.PAGE_ACTIONS_SOURCE_ARCHIVE_SHA256 ?? "").trim();
const expectedDeploymentId = (process.env.PAGE_ACTIONS_DEPLOYMENT_ID ?? "").trim();
const EXAMPLE_SELECTION_ACTIONS = new Set(["home-example", "workbench-example", "games-example"]);
const PERSISTED_BUILD_ACTIONS = new Set([
  "home-iteration-input",
  "home-result-fullscreen",
  "home-result-share",
  "home-result-download",
  "home-result-code-toggle",
  "workbench-iteration-input",
  "workbench-preview",
  "workbench-code",
  "workbench-file",
  "workbench-fullscreen",
  "workbench-share",
  "workbench-download",
  "games-iteration-input",
  "games-preview",
  "games-code",
  "games-file",
  "games-fullscreen",
  "games-share",
  "games-download",
]);
const BLOCKED_ERROR_PATTERN = /\b(?:blocked|error|fail|failed|forbidden|unavailable|action_required)\b|(?:gesperrt|fehler|fehlgeschlagen|nicht erlaubt|nicht möglich|nicht erreichbar|bleibt erhalten|erfordert)/i;

type JsonRecord = Record<string, unknown>;

type PersistedBuild = {
  id: string;
  html: string;
  persisted: true;
  direct_provider_calls: false;
  secret_output: false;
};

type ElementSnapshot = {
  count: number;
  visibleCount: number;
  digest: string;
  text: string;
};

type ActionAudit = {
  route: string;
  family_id: string;
  action_id: string;
  availability: ActionMember["availability"];
  registry_status: ActionMember["status"];
  expected_effect: string;
  effect_type: "state" | "data" | "navigation" | "download" | "blocked_error";
  control_count: number;
  audited_control_count: number;
  effect_observed: boolean;
  click_only: false;
  proof_kind: "direct_effect" | "preverified_exact_control";
  trigger: string;
  details: JsonRecord;
  passed: boolean;
  failure?: string;
};

function asRecord(value: unknown): JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function safeMessage(value: unknown): string {
  return String(value ?? "unknown")
    .replace(/\b(?:sk-|ghp_|github_pat_|glpat-|cfat|hf_)[A-Za-z0-9_.-]{8,}\b/gi, "[REDACTED]")
    .replace(/\b(token|secret|password|api[_-]?key)\s*[:=]\s*\S+/gi, "$1=[REDACTED]")
    .slice(0, 500);
}

function sha256(value: string | Buffer): string {
  return createHash("sha256").update(value).digest("hex");
}

function classifyEffect(action: ActionMember): ActionAudit["effect_type"] {
  const expected = action.expectedEffect;
  if (/download/i.test(expected)) return "download";
  if (/navigate|new (?:tab|window)|opens in/i.test(expected)) return "navigation";
  if (/\b(?:blocked|error|forbidden|unavailable)\b|(?:gesperrt|fehler|nicht erlaubt|nicht möglich|nicht erreichbar)/i.test(expected)) return "blocked_error";
  if (/result|response|audit|hit count|frames|manifest|summary|registered|classification|preview|files/i.test(expected)) return "data";
  return "state";
}

function normalizedOrganismActionId(actionId: string): string {
  return actionId.replace(/^(?:replay|map)-(?=organism-)/, "");
}

function isExplicitClipboardAction(action: ActionMember): boolean {
  return action.id.endsWith("-copy")
    || /\bclipboard\b/i.test(`${action.precondition} ${action.expectedEffect}`);
}

function isProviderRequest(urlValue: string, method: string): boolean {
  try {
    const url = new URL(urlValue);
    if (method === "POST" && url.pathname === "/api/v1/build") return true;
    if (/\/(?:llm|v1\/chat\/completions|v1\/responses)(?:\/|$)/i.test(url.pathname)) return true;
    return /(?:api\.cloudflare\.com|workers\.ai|huggingface\.co|router\.huggingface\.co)$/i.test(url.hostname);
  } catch {
    return false;
  }
}

async function snapshot(locator: Locator): Promise<ElementSnapshot> {
  const items = await locator.evaluateAll((elements) => elements.map((element) => {
    const html = element as HTMLElement;
    const control = element as HTMLInputElement;
    const style = window.getComputedStyle(element);
    const visible = style.display !== "none"
      && style.visibility !== "hidden"
      && style.opacity !== "0"
      && html.getBoundingClientRect().width > 0
      && html.getBoundingClientRect().height > 0;
    return {
      visible,
      tag: element.tagName,
      text: (element.textContent || "").replace(/\s+/g, " ").trim().slice(0, 1_000),
      value: "value" in control ? String(control.value ?? "") : "",
      checked: "checked" in control ? Boolean(control.checked) : null,
      disabled: "disabled" in control ? Boolean(control.disabled) : null,
      className: typeof html.className === "string" ? html.className : "",
      ariaPressed: element.getAttribute("aria-pressed"),
      ariaSelected: element.getAttribute("aria-selected"),
      href: element.getAttribute("href"),
      download: element.getAttribute("download"),
    };
  }));
  const visibleItems = items.filter((item) => item.visible);
  return {
    count: items.length,
    visibleCount: visibleItems.length,
    digest: JSON.stringify(visibleItems),
    text: visibleItems.map((item) => item.text).join(" ").slice(0, 2_000),
  };
}

async function waitForSnapshotChange(locator: Locator, before: ElementSnapshot, timeout = 5_000): Promise<ElementSnapshot> {
  let after = await snapshot(locator);
  await expect.poll(async () => {
    after = await snapshot(locator);
    return after.digest !== before.digest || (before.visibleCount === 0 && after.visibleCount > 0);
  }, {
    message: "control must produce a concrete visible/state/data/error delta",
    timeout,
    intervals: [100, 250, 500, 1_000],
  }).toBe(true);
  return after;
}

async function gotoRoute(page: Page, route: string, buildId?: string): Promise<void> {
  const needsBuildQuery = buildId && ["/home", "/workbench", "/games"].includes(route);
  const query = needsBuildQuery ? `${route.includes("?") ? "&" : "?"}build=${encodeURIComponent(buildId)}` : "";
  const response = await page.goto(`${baseUrl}${route}${query}`, { waitUntil: "domcontentloaded", timeout: 60_000 });
  expect(response?.status(), `GET ${route}`).toBe(200);
  await expect(page.locator("body")).toBeVisible();
  const hydrationProof = route === "/login"
    ? page.getByTestId("real-login")
    : page.locator(".app-shell");
  await expect(hydrationProof).toHaveAttribute("data-hydrated", "true", { timeout: 30_000 });
  if (route === "/agents") {
    await expect(page.locator('input[aria-label="Forschungsziel"]')).toBeVisible({ timeout: 30_000 });
  }
  if (needsBuildQuery) {
    const proof = route === "/home"
      ? page.getByTestId("ab-result")
      : page.getByTestId("ws-log").filter({ hasText: "geladen" });
    await expect(proof).toBeVisible({ timeout: 30_000 });
  }
}

async function waitForTopologyMap(page: Page): Promise<void> {
  const map = page.getByTestId("organism-topology-map");
  await expect(map).toHaveAttribute("data-contract-version", "organism-topology-v1", { timeout: 60_000 });
  await expect(page.getByTestId("organism-topology-kind-filter").first()).toBeVisible({ timeout: 60_000 });
}

async function setSession(page: Page, context: BrowserContext, signedIn: boolean): Promise<void> {
  const loginResponse = await page.goto(`${baseUrl}/login?sessionreset=${Date.now()}`, {
    waitUntil: "domcontentloaded",
    timeout: 60_000,
  });
  expect(loginResponse?.status()).toBe(200);
  if (!signedIn) await context.clearCookies();
  const result = await page.evaluate(async (wantSignedIn) => {
    if (!wantSignedIn) {
      const response = await fetch("/api/v1/auth/session", { method: "DELETE" });
      return { status: response.status, payload: await response.json() };
    }
    const current = await fetch("/api/v1/auth/session", { cache: "no-store" });
    const currentPayload = await current.json();
    if (current.ok && currentPayload.status === "signed_in") return { status: current.status, payload: currentPayload };
    const response = await fetch("/api/v1/auth/session", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ provider: "guest" }),
    });
    return { status: response.status, payload: await response.json() };
  }, signedIn);
  expect(result.status).toBe(200);
  expect(result.payload.status).toBe(signedIn ? "signed_in" : "signed_out");

  const authProofUrl = `${baseUrl}/login?authproof=${Date.now()}`;
  const response = await page.goto(authProofUrl, { waitUntil: "domcontentloaded", timeout: 60_000 });
  expect(response?.status(), `GET /login after ${signedIn ? "sign-in" : "sign-out"}`).toBe(200);
  await expect(page.getByTestId("real-login")).toHaveAttribute("data-hydrated", "true", { timeout: 30_000 });
  const expectedControl = page.getByTestId(signedIn ? "rl-signout" : "rl-signin");
  await expect(expectedControl).toBeVisible({ timeout: 15_000 });
  const confirmed = await page.evaluate(async () => {
    const current = await fetch("/api/v1/auth/session", { cache: "no-store" });
    return { status: current.status, payload: await current.json() };
  });
  expect(confirmed.status).toBe(200);
  expect(confirmed.payload.status).toBe(signedIn ? "signed_in" : "anonymous");
}

async function loadPersistedBuild(context: BrowserContext): Promise<PersistedBuild> {
  const id = String(process.env.PAGE_ACTIONS_BUILD_ID ?? "");
  expect(id, "P2 requires the exact green product-acceptance build id; it must never select or create another build").toMatch(/^[A-Za-z0-9_-]{1,64}$/);
  const readResponse = await context.request.get(`${baseUrl}/api/v1/build/${encodeURIComponent(id)}`);
  expect(readResponse.status()).toBe(200);
  const build = asRecord(await readResponse.json());
  expect(build.id).toBe(id);
  expect(build.persisted).toBe(true);
  expect(build.direct_provider_calls).toBe(false);
  expect(build.secret_output).toBe(false);
  expect(String(build.html)).toMatch(/^\s*<!doctype html/i);
  return build as PersistedBuild;
}

async function prepareMember(page: Page, context: BrowserContext, action: ActionMember): Promise<void> {
  const normalizedId = normalizedOrganismActionId(action.id);
  if (normalizedId.startsWith("organism-")) {
    await expect(page.getByTestId("organism-view")).toHaveAttribute("data-hydrated", "true", { timeout: 30_000 });
  }
  if (action.id.startsWith("technology-")) {
    // The technology surface removes its contract-backed controls while all three
    // runtime sources reload. A preceding refresh may legitimately take longer
    // than the default action timeout, so bind every follow-up action to the
    // explicit ready state instead of racing the transient loading tree.
    await expect(page.getByTestId("technology-runtime-view"))
      .toHaveAttribute("data-state", "ready", { timeout: 60_000 });
  }
  if (action.id === "login-name" || action.id === "login-signin") {
    await setSession(page, context, false);
  } else if (action.id === "login-signout" || action.id === "login-workbench") {
    await setSession(page, context, true);
  }
  if (action.id.startsWith("map-topology-")) {
    await waitForTopologyMap(page);
  }

  const fillValues: Record<string, [string, string]> = {
    "home-build": [".ai-builder textarea", "P2 Home: baue eine kleine interaktive 3D-Szene mit Würfel und Punktestand."],
    "games-build-run": [".workbench-studio textarea", "P2 Games: baue ein kleines interaktives 3D-Spiel mit Würfel und Punktestand."],
    "agents-run": ['input[aria-label="Forschungsziel"]', "P2 providerfreier Aktionsnachweis für semantische Suche"],
    "agents-source-detail": ['input[aria-label="Forschungsziel"]', "P2 providerfreier Quellen-Nachweis"],
    "files-search": ['input[aria-label="Suchbegriff für das Gedächtnis"]', "phase2"],
    "tools-execute": ['[data-testid="goal-b-tools-panel"] input', "phase2"],
    "docs-download-md": ['input[aria-label="Titel"]', "P2 Aktionsnachweis"],
    "docs-download-html": ['input[aria-label="Titel"]', "P2 Aktionsnachweis"],
  };
  const fill = fillValues[action.id];
  if (fill) await page.locator(fill[0]).fill(fill[1]);

  if (action.id === "agents-source-detail") {
    await page.getByTestId("ar-run").click();
    await expect(page.getByTestId("ar-result")).toBeVisible({ timeout: 180_000 });
  }
  if (action.id.endsWith("-copy")) {
    const output = page.locator(".lc-out");
    if ((await output.count()) && !(await output.textContent())?.trim()) {
      await page.getByTestId("live-console-load").click();
      await expect(output).not.toBeEmpty({ timeout: 30_000 });
    }
  }
  if (action.id === "games-local-stop") {
    await page.getByTestId("rg-start").click();
    await expect(page.getByTestId("rg-gpustop")).toBeVisible();
  }
  if (action.id === "workbench-preview" || action.id === "games-preview") {
    await page.locator('.workbench-studio button:has-text("Code")').click();
    await expect(page.locator(".ws-code")).toBeVisible();
  }
  if (["workbench-code", "workbench-file", "games-code", "games-file"].includes(action.id)) {
    await page.locator('.workbench-studio button:has-text("Vorschau")').click();
    await expect(page.getByTestId("ws-frame")).toBeVisible();
  }
  if (normalizedId === "organism-camera-reset") {
    await page.locator('[data-testid^="phase6-camera-preset-"]').nth(1).click();
  }
  if (normalizedId === "organism-hub-open") {
    const rows = page.locator(".lg-row");
    for (let index = 0; index < await rows.count(); index += 1) {
      await rows.nth(index).click();
      const href = await page.locator(".stack section.panel.panel-pad a.btn.mt-12").getAttribute("href");
      if (href && new URL(href, page.url()).pathname !== new URL(page.url()).pathname) break;
    }
  }
  if (normalizedId === "organism-gameplay-reset") {
    await page.getByTestId("phase6-gameplay-complete").click();
  }
  if (normalizedId === "organism-asset-reset") {
    await page.locator('[data-testid^="phase6-asset-profile-"]').nth(1).click();
  }
  if (normalizedId === "organism-load-snapshot" || normalizedId === "organism-clear-snapshot") {
    await page.getByTestId("phase6-save-snapshot").click();
    await expect(page.getByTestId("phase6-save-load-state")).toContainText("snapshot_status=saved", { timeout: 15_000 });
    await expect(page.getByTestId(normalizedId === "organism-load-snapshot" ? "phase6-load-snapshot" : "phase6-clear-snapshot"))
      .toBeEnabled({ timeout: 15_000 });
  }
  if (normalizedId === "organism-leaderboard-capture" || normalizedId === "organism-leaderboard-reset") {
    await page.getByTestId("phase6-gameplay-complete").click();
    if (normalizedId === "organism-leaderboard-reset") await page.getByTestId("phase6-leaderboard-capture").click();
  }
  if (normalizedId === "organism-performance-finish" || normalizedId === "organism-performance-reset") {
    const start = page.getByTestId("phase6-performance-start");
    const finish = page.getByTestId("phase6-performance-finish");
    const reset = page.getByTestId("phase6-performance-reset");
    if (normalizedId === "organism-performance-finish") {
      if (!(await finish.isEnabled())) {
        if (!(await start.isEnabled()) && !(await finish.isEnabled()) && await reset.isEnabled()) {
          await reset.click();
          await expect(start).toBeEnabled();
        }
        if (await start.isEnabled()) await start.click();
        await expect(finish).toBeEnabled({ timeout: 20_000 });
      }
    } else if (!(await reset.isEnabled()) && await start.isEnabled()) {
      await start.click();
      await expect(reset).toBeEnabled();
    }
  }
  if (action.id === "replay-live-load" || action.id === "map-live-load") {
    // Jede Seite reicht der Live-Konsole ihre eigene Endpoint-Liste. `/organism/map`
    // bietet seit der Topologie-Bindung Regionen/Sicherheit/Topologie an und kein
    // `/api/v1/health` mehr; ein fest verdrahteter Pfad waere hier eine Testluege.
    const expectedEndpoint = action.id === "map-live-load"
      ? "/api/v1/organism/topology"
      : "/api/v1/health";
    const endpoint = page.getByTestId("live-console").getByLabel(/Endpoint$/);
    await expect(endpoint.locator(`option[value="${expectedEndpoint}"]`)).toHaveCount(1);
    await endpoint.selectOption(expectedEndpoint);
    await expect(endpoint).toHaveValue(expectedEndpoint);
  }
  if (action.id === "media-play" || action.id === "media-music-record") {
    await page.getByTestId("cs-tab-music").click();
    await expect(page.getByTestId("cs-music")).toBeVisible();
  }
  if (action.id === "media-video-record") {
    await page.getByTestId("cs-tab-video").click();
    await expect(page.getByTestId("cs-video")).toBeVisible();
  }
}

async function auditDirectBuild(
  page: Page,
  context: BrowserContext,
  route: string,
  family: ActionFamily,
  action: ActionMember,
): Promise<ActionAudit> {
  const controls = page.locator(action.locator);
  try {
    expect(["home-build", "games-build-run"]).toContain(action.id);
    await gotoRoute(page, route);
    await prepareMember(page, context, action);
    await controls.first().waitFor({ state: "visible", timeout: 30_000 });
    await expect(controls.first()).toBeEnabled();
    const promptLocator = action.id === "home-build"
      ? page.locator(".ai-builder textarea")
      : page.locator(".workbench-studio textarea");
    await expect(promptLocator).not.toHaveValue("");
    const responsePromise = page.waitForResponse((response) => {
      const url = new URL(response.url());
      return response.request().method() === "POST" && url.pathname === "/api/v1/build";
    }, { timeout: 300_000 });
    await controls.first().click();
    const response = await responsePromise;
    expect(response.status()).toBe(200);
    const payload = asRecord(await response.json());
    const buildId = String(payload.id ?? "");
    expect(buildId).toMatch(/^[A-Za-z0-9_-]{1,64}$/);
    expect(payload.persisted).toBe(true);
    expect(payload.audit_persisted).toBe(true);
    expect(payload.live_provider_calls).toBe(true);
    expect(payload.gateway_provider).toBe("cloudflare-workers-ai");
    expect(payload.direct_provider_calls).toBe(false);
    expect(payload.secret_output).toBe(false);
    const readbackResponse = await context.request.get(`${baseUrl}/api/v1/build/${encodeURIComponent(buildId)}`);
    expect(readbackResponse.status()).toBe(200);
    const readback = asRecord(await readbackResponse.json());
    expect(readback.id).toBe(buildId);
    expect(readback.persisted).toBe(true);
    await expect(page.locator(action.effectLocator).first()).toBeVisible({ timeout: 30_000 });
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: await controls.count(),
      audited_control_count: 1,
      effect_observed: true,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_route_build_persisted_readback",
      details: {
        build_id: buildId,
        response_status: response.status(),
        persisted: true,
        audit_persisted: true,
        live_provider_calls: true,
        gateway_provider: payload.gateway_provider,
        direct_provider_calls: false,
      },
      passed: true,
    };
  } catch (error) {
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: await controls.count().catch(() => 0),
      audited_control_count: 0,
      effect_observed: false,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_route_build_persisted_readback",
      details: { precondition: action.precondition },
      passed: false,
      failure: safeMessage(error instanceof Error ? error.message : error),
    };
  }
}

async function auditPreverifiedWorkbenchBuild(
  page: Page,
  context: BrowserContext,
  route: string,
  family: ActionFamily,
  action: ActionMember,
  build: PersistedBuild,
  productAcceptanceSpecSource: string,
  productAcceptanceReportSha256: string,
): Promise<ActionAudit> {
  const controls = page.locator(action.locator);
  try {
    expect(route).toBe("/workbench");
    expect(action.id).toBe("workbench-build");
    expect(action.locator).toBe(`[data-testid="ws-build"]`);
    expect(action.evidence.some((item) => item.source === "product-acceptance")).toBe(true);
    expect(productAcceptanceSpecSource).toContain('await page.getByTestId("ws-build").click();');
    await gotoRoute(page, route, build.id);
    await controls.first().waitFor({ state: "visible", timeout: 30_000 });
    const readbackResponse = await context.request.get(`${baseUrl}/api/v1/build/${encodeURIComponent(build.id)}`);
    expect(readbackResponse.status()).toBe(200);
    const readback = asRecord(await readbackResponse.json());
    expect(readback.id).toBe(build.id);
    expect(readback.persisted).toBe(true);
    expect(readback.live_provider_calls).toBe(true);
    expect(readback.gateway_provider).toBe("cloudflare-workers-ai");
    await expect(page.locator(action.effectLocator).first()).toBeVisible({ timeout: 30_000 });
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: await controls.count(),
      audited_control_count: 1,
      effect_observed: true,
      click_only: false,
      proof_kind: "preverified_exact_control",
      trigger: "preverified_exact_p0_ws_build_control",
      details: {
        exact_control: `[data-testid="ws-build"]`,
        p0_build_id: build.id,
        p0_product_acceptance_report_sha256: productAcceptanceReportSha256,
        p0_spec_contains_exact_click: true,
        persisted_readback: true,
      },
      passed: true,
    };
  } catch (error) {
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: await controls.count().catch(() => 0),
      audited_control_count: 0,
      effect_observed: false,
      click_only: false,
      proof_kind: "preverified_exact_control",
      trigger: "preverified_exact_p0_ws_build_control",
      details: { exact_control: action.locator },
      passed: false,
      failure: safeMessage(error instanceof Error ? error.message : error),
    };
  }
}

const PAGE_LOCAL_INTERACTIVE_SELECTOR = [
  "main button:not([disabled])",
  'main input:not([disabled]):not([type="hidden"])',
  "main textarea:not([disabled])",
  "main select:not([disabled])",
  "main a[href]",
].join(", ");

async function findUnregisteredPageLocalControls(
  page: Page,
  entry: PageActionEntry,
): Promise<{
  unregistered: readonly JsonRecord[];
  registeredMatchCounts: Readonly<Record<string, number>>;
}> {
  const registeredLocators = [
    ...entry.families.flatMap((family) => family.memberActions.map((action) => action.locator)),
    ...entry.excludedGates.map((gate) => gate.locator),
  ];
  if (entry.route === "/apps" || entry.route === "/games") {
    // BuildsGallery renders "Lädt…" until its /api/v1/builds fetch resolves, so a snapshot taken
    // during that window sees zero build-card controls and the coverage assertion below would
    // fail on a timing artefact rather than on missing coverage. Wait for the first card to
    // attach. A registry that genuinely has no cards still fails — the wait times out and the
    // assertion is reached with a count of zero.
    await page
      .locator(".builds-gallery .bg-open")
      .first()
      .waitFor({ state: "attached", timeout: 20_000 })
      .catch(() => undefined);
  }
  if (entry.route === "/organism/map") {
    // The topology contract is fetched and strictly validated client-side. Do not snapshot
    // dynamic controls while the map still reports its explicit pending state.
    await waitForTopologyMap(page);
  }
  const snapshot = await page.evaluate(({ candidateSelector, selectors }) => {
      const splitSelectorList = (value: string): string[] => {
        const parts: string[] = [];
        let start = 0;
        let quote = "";
        let bracketDepth = 0;
        let parenthesisDepth = 0;
        for (let index = 0; index < value.length; index += 1) {
          const character = value[index];
          if (quote) {
            if (character === quote && value[index - 1] !== "\\") quote = "";
            continue;
          }
          if (character === '"' || character === "'") {
            quote = character;
            continue;
          }
          if (character === "[") bracketDepth += 1;
          else if (character === "]") bracketDepth = Math.max(0, bracketDepth - 1);
          else if (character === "(") parenthesisDepth += 1;
          else if (character === ")") parenthesisDepth = Math.max(0, parenthesisDepth - 1);
          else if (character === "," && bracketDepth === 0 && parenthesisDepth === 0) {
            parts.push(value.slice(start, index).trim());
            start = index + 1;
          }
        }
        parts.push(value.slice(start).trim());
        return parts.filter(Boolean);
      };
      const matchingElements = (rawSelector: string): Element[] => {
        const textMatch = rawSelector.match(/^(.*):has-text\((["'])(.*)\2\)$/);
        try {
          if (!textMatch) return Array.from(document.querySelectorAll(rawSelector));
          const css = textMatch[1].trim();
          const expectedText = textMatch[3].replace(/\\([\\"'])/g, "$1").replace(/\s+/g, " ").trim();
          return Array.from(document.querySelectorAll(css)).filter((element) =>
            (element.textContent || "").replace(/\s+/g, " ").trim().includes(expectedText),
          );
        } catch {
          // Human-readable exclusions such as "not mounted" intentionally
          // match no DOM control and never broaden the registered set.
          return [];
        }
      };

      // Resolve registry coverage and candidate controls synchronously in one
      // browser task. React cannot hydrate another build card between snapshots.
      const covered = new Set<Element>();
      const registeredMatchCounts: Record<string, number> = {};
      for (const selector of selectors) {
        const matches = new Set<Element>();
        for (const selectorPart of splitSelectorList(selector)) {
          for (const element of matchingElements(selectorPart)) matches.add(element);
        }
        registeredMatchCounts[selector] = matches.size;
        for (const element of matches) covered.add(element);
      }
      const unregistered = Array.from(document.querySelectorAll(candidateSelector)).flatMap((element) => {
        const html = element as HTMLElement;
        const style = window.getComputedStyle(element);
        const rect = html.getBoundingClientRect();
        const visible = style.display !== "none"
          && style.visibility !== "hidden"
          && style.opacity !== "0"
          && rect.width > 0
          && rect.height > 0;
        const href = element.getAttribute("href");
        const selfLink = element.tagName === "A" && href
          ? new URL(href, window.location.href).pathname === window.location.pathname
          : false;
        if (!visible || covered.has(element) || selfLink) return [];
        return [{
          tag: element.tagName.toLowerCase(),
          id: element.id || null,
          testid: element.getAttribute("data-testid"),
          aria_label: element.getAttribute("aria-label"),
          href,
          text: (element.textContent || "").replace(/\s+/g, " ").trim().slice(0, 160),
           class_name: typeof html.className === "string" ? html.className.slice(0, 160) : "",
         }];
       });
      return { unregistered, registeredMatchCounts };
    }, { candidateSelector: PAGE_LOCAL_INTERACTIVE_SELECTOR, selectors: registeredLocators });

  if (entry.route === "/apps") {
    for (const selector of [
      ".builds-gallery .bg-open",
      ".builds-gallery .bg-edit",
      '.builds-gallery [data-testid^="build-delete-"]',
    ]) {
      expect(
        snapshot.registeredMatchCounts[selector],
        `/apps registry selector must cover a hydrated dynamic build-card control: ${selector}`,
      ).toBeGreaterThan(0);
    }
  }
  return snapshot;
}

async function auditNetcodeSequence(page: Page, route: string, family: ActionFamily, action: ActionMember): Promise<ActionAudit> {
  const sequence = ["create", "join", "host-ready", "guest-ready", "start", "tick", "disconnect", "close"];
  const state = page.getByTestId("phase6-netcode-state");
  let previous = await snapshot(state);
  let audited = 0;
  try {
    for (const suffix of sequence) {
      const control = page.getByTestId(`phase6-netcode-${suffix}`);
      await expect(control).toBeVisible();
      await expect(control).toBeEnabled();
      await control.click();
      previous = await waitForSnapshotChange(state, previous);
      audited += 1;
    }
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "state",
      control_count: sequence.length,
      audited_control_count: audited,
      effect_observed: true,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_ordered_loopback_control_sequence",
      details: { controls: sequence, final_state: previous.text },
      passed: true,
    };
  } catch (error) {
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "state",
      control_count: sequence.length,
      audited_control_count: audited,
      effect_observed: false,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_ordered_loopback_control_sequence",
      details: { controls: sequence },
      passed: false,
      failure: safeMessage(error instanceof Error ? error.message : error),
    };
  }
}

async function auditLiveEndpointLoad(
  page: Page,
  route: string,
  family: ActionFamily,
  action: ActionMember,
): Promise<ActionAudit> {
  const controls = page.locator(action.locator);
  const consolePanel = page.getByTestId("live-console");
  const status = consolePanel.locator(".lc-status");
  const output = consolePanel.locator(".lc-out");
  try {
    await expect(controls.first()).toBeVisible();
    await expect(controls.first()).toBeEnabled();
    const endpoint = await controls.first().getAttribute("data-endpoint");
    expect(endpoint).toMatch(/^\/api\/v1\/[A-Za-z0-9_./-]+$/);
    const responsePromise = page.waitForResponse((response) => {
      const url = new URL(response.url());
      return response.request().method() === "GET"
        && url.pathname === endpoint
        && url.search === "";
    }, { timeout: 30_000 });
    await controls.first().click();
    const response = await responsePromise;
    expect(response.status()).toBe(200);
    const responseText = await response.text();
    let visibleText = responseText;
    try {
      visibleText = JSON.stringify(JSON.parse(responseText), null, 2);
    } catch {}
    if (visibleText.length > 6_000) visibleText = `${visibleText.slice(0, 6_000)}\n… (gekürzt)`;
    await expect(status).toHaveText("200 OK");
    await expect(output).toHaveText(visibleText, { timeout: 10_000 });
    await expect(consolePanel.locator(".lc-meta")).toBeVisible();
    const afterStatus = await status.textContent() ?? "";
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: await controls.count(),
      audited_control_count: 1,
      effect_observed: true,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_selected_endpoint_get_and_visible_response_binding",
      details: {
        endpoint,
        method: "GET",
        response_status: response.status(),
        visible_status: afterStatus,
        response_body_sha256: sha256(responseText),
        response_body_bound_to_visible_output: true,
        causal_user_click: true,
      },
      passed: true,
    };
  } catch (error) {
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: await controls.count().catch(() => 0),
      audited_control_count: 0,
      effect_observed: false,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_selected_endpoint_get_and_visible_response_binding",
      details: { endpoint: await controls.first().getAttribute("data-endpoint").catch(() => null), method: "GET" },
      passed: false,
      failure: safeMessage(error instanceof Error ? error.message : error),
    };
  }
}

async function auditPerformanceFinish(
  page: Page,
  route: string,
  family: ActionFamily,
  action: ActionMember,
): Promise<ActionAudit> {
  const start = page.getByTestId("phase6-performance-start");
  const finish = page.getByTestId("phase6-performance-finish");
  const reset = page.getByTestId("phase6-performance-reset");
  const state = page.getByTestId("phase6-performance-state");
  const result = page.getByTestId("phase6-performance-result");
  try {
    await expect(state).toBeVisible();
    const currentState = await state.textContent() ?? "";
    if (!currentState.includes("status=sampling") && !(await finish.isEnabled())) {
      if (await reset.isEnabled()) {
        await reset.click();
        await expect(start).toBeEnabled();
      }
      await start.click();
      await expect(state).toContainText("status=sampling");
    }
    await expect(finish).toBeEnabled({ timeout: 19_000 });
    const before = await snapshot(result);
    await finish.evaluate((element) => (element as HTMLButtonElement).click());
    const after = await waitForSnapshotChange(result, before, 5_000);
    await expect(state).not.toContainText("status=sampling");
    await expect(result).toHaveAttribute("data-sample-count", "12");
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: 1,
      audited_control_count: 1,
      effect_observed: true,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_performance_finish_after_12_samples",
      details: {
        sample_count: 12,
        result: after.text,
        network: false,
        local_only: true,
      },
      passed: true,
    };
  } catch (error) {
    const sampleCount = Number(await result.getAttribute("data-sample-count").catch(() => "0")) || 0;
    const currentState = await state.textContent().catch(() => "");
    return {
      route,
      family_id: family.id,
      action_id: action.id,
      availability: action.availability,
      registry_status: action.status,
      expected_effect: action.expectedEffect,
      effect_type: "data",
      control_count: await finish.count().catch(() => 0),
      audited_control_count: 0,
      effect_observed: false,
      click_only: false,
      proof_kind: "direct_effect",
      trigger: "direct_performance_finish_after_12_samples",
      details: { sample_count: sampleCount, state: currentState, network: false, local_only: true },
      passed: false,
      failure: safeMessage(error instanceof Error ? error.message : error),
    };
  }
}

async function auditMember(
  page: Page,
  context: BrowserContext,
  route: string,
  family: ActionFamily,
  action: ActionMember,
  build: PersistedBuild,
  productAcceptanceSpecSource: string,
  productAcceptanceReportSha256: string,
): Promise<ActionAudit> {
  if (action.id === "home-build" || action.id === "games-build-run") {
    return auditDirectBuild(page, context, route, family, action);
  }
  if (action.verificationMode === "preverified_exact_control") {
    return auditPreverifiedWorkbenchBuild(
      page,
      context,
      route,
      family,
      action,
      build,
      productAcceptanceSpecSource,
      productAcceptanceReportSha256,
    );
  }
  if (EXAMPLE_SELECTION_ACTIONS.has(action.id) || action.id.startsWith("games-history-")) {
    await gotoRoute(page, route);
  } else if (PERSISTED_BUILD_ACTIONS.has(action.id)) {
    const current = new URL(page.url());
    if (current.pathname !== route || current.searchParams.get("build") !== build.id) {
      await gotoRoute(page, route, build.id);
    }
  }
  expect(action.verificationMode, `${route}/${action.id} must be directly interactive`).toBe("interactive");

  const effectType = classifyEffect(action);
  const baseResult = {
    route,
    family_id: family.id,
    action_id: action.id,
    availability: action.availability,
    registry_status: action.status,
    expected_effect: action.expectedEffect,
    effect_type: effectType,
    click_only: false,
    proof_kind: "direct_effect",
  } as const;

  let controlCount = 0;
  let audited = 0;
  const detailRows: JsonRecord[] = [];
  const normalizedId = normalizedOrganismActionId(action.id);
  try {
    if (effectType === "navigation") await gotoRoute(page, route, build.id);
    if (normalizedId === "organism-performance-finish") {
      return auditPerformanceFinish(page, route, family, action);
    }
    await prepareMember(page, context, action);
    if (normalizedId.endsWith("organism-netcode-session")) {
      return auditNetcodeSequence(page, route, family, action);
    }
    if (action.id.endsWith("-live-load")) {
      return auditLiveEndpointLoad(page, route, family, action);
    }

    const controls = page.locator(action.locator);
    await controls.first().waitFor({ state: "visible", timeout: action.id.startsWith("games-history-") ? 60_000 : 15_000 });
    const visibleCandidates: number[] = [];
    const totalControls = await controls.count();
    for (let index = 0; index < totalControls; index += 1) {
      if (await controls.nth(index).isVisible().catch(() => false)) visibleCandidates.push(index);
    }
    controlCount = visibleCandidates.length;
    if (visibleCandidates.length === 0 && totalControls > 0) visibleCandidates.push(0);
    expect(visibleCandidates.length, `${route}/${action.id} must have a stable locator`).toBeGreaterThan(0);
    // A registry member represents one handler/semantic action. Repeated chips,
    // rows, or options share that handler, so exercise one non-default sample
    // while still reporting the complete visible control count.
    let selectedIndex = (action.id.includes("hub-select") || action.id === "media-tab") && visibleCandidates.length > 1
      ? visibleCandidates[1]
      : visibleCandidates[0];
    if (visibleCandidates.length > 1) {
      for (const candidateIndex of visibleCandidates) {
        const candidate = controls.nth(candidateIndex);
        const classTokens = (await candidate.getAttribute("class") ?? "").split(/\s+/);
        const active = classTokens.includes("active")
          || classTokens.includes("btn-primary")
          || await candidate.getAttribute("aria-pressed") === "true"
          || await candidate.getAttribute("aria-selected") === "true";
        if (!active && await candidate.isEnabled().catch(() => false)) {
          selectedIndex = candidateIndex;
          break;
        }
      }
    }
    if (action.id === "technology-provider-filter") {
      const historicalOnlyIndex = await controls.evaluateAll((items) =>
        items.findIndex((item) => item.getAttribute("data-filter") === "historical_only")
      );
      expect(historicalOnlyIndex, "technology provider filtering needs a guaranteed contract-backed subset").toBeGreaterThanOrEqual(0);
      selectedIndex = historicalOnlyIndex;
    }
    const visibleIndexes = [selectedIndex];
    for (const originalIndex of visibleIndexes) {
      if (audited > 0 && effectType === "navigation") {
        await gotoRoute(page, route, build.id);
        await prepareMember(page, context, action);
      }
      const refreshed = page.locator(action.locator);
      const control = refreshed.nth(Math.min(originalIndex, Math.max(0, (await refreshed.count()) - 1)));
      await expect(control).toBeVisible();
      const tag = await control.evaluate((element) => element.tagName.toLowerCase());
      const inputType = await control.getAttribute("type");
      const initiallyActive = (await control.getAttribute("class") ?? "").split(/\s+/).includes("active")
        || await control.getAttribute("aria-pressed") === "true"
        || await control.getAttribute("aria-selected") === "true";
      const beforeControl = await snapshot(control);
      const beforeEffect = await snapshot(page.locator(action.effectLocator));
      let trigger = "click";
      let afterEffect = beforeEffect;
      let detail: JsonRecord = { control_index: originalIndex, tag };

      if (tag === "input" || tag === "textarea") {
        trigger = "fill";
        if (inputType === "checkbox" || inputType === "radio") {
          await control.click();
        } else if (inputType === "range") {
          const minimum = Number(await control.getAttribute("min") ?? "0");
          const maximum = Number(await control.getAttribute("max") ?? "100");
          const current = Number(await control.inputValue());
          const next = current >= maximum ? minimum : Math.min(maximum, current + Math.max(1, (maximum - minimum) / 4));
          await control.fill(String(next));
        } else {
          await control.fill(`P2 ${action.id} ${originalIndex + 1}`);
        }
        const afterControl = await snapshot(control);
        expect(afterControl.digest).not.toBe(beforeControl.digest);
        afterEffect = await snapshot(page.locator(action.effectLocator));
        detail = { ...detail, control_delta: true };
      } else if (tag === "select") {
        trigger = "select";
        const options = await control.locator("option").evaluateAll((items) =>
          items.map((item) => (item as HTMLOptionElement).value).filter(Boolean),
        );
        expect(options.length).toBeGreaterThan(1);
        const current = await control.inputValue();
        const next = options.find((value) => value !== current);
        expect(next).toBeTruthy();
        await control.selectOption(next as string);
        expect(await control.inputValue()).toBe(next);
        afterEffect = await snapshot(page.locator(action.effectLocator));
        detail = { ...detail, selected_value: next };
      } else if (EXAMPLE_SELECTION_ACTIONS.has(action.id)) {
        trigger = "prompt_example_selection";
        await control.click();
        afterEffect = await waitForSnapshotChange(page.locator(action.effectLocator), beforeEffect);
        const selectedPrompt = await page.locator(action.effectLocator).first().inputValue();
        expect(selectedPrompt.trim().length).toBeGreaterThan(0);
        detail = {
          ...detail,
          prompt_changed: afterEffect.digest !== beforeEffect.digest,
          selected_prompt_length: selectedPrompt.length,
        };
      } else if (isExplicitClipboardAction(action)) {
        trigger = "clipboard";
        const beforeClipboard = await page.evaluate(() => navigator.clipboard.readText().catch(() => ""));
        await control.click();
        const afterClipboard = await page.evaluate(() => navigator.clipboard.readText());
        expect(afterClipboard.length).toBeGreaterThan(0);
        const expectedOutput = (await page.locator(action.effectLocator).first().textContent())?.trim() ?? "";
        if (action.id.endsWith("-copy") && expectedOutput) {
          const normalizedClipboard = afterClipboard.replace(/\s+/g, " ").trim();
          const normalizedExpected = expectedOutput.replace(/\s+/g, " ").trim();
          expect(normalizedClipboard).toContain(normalizedExpected.slice(0, Math.min(normalizedExpected.length, 80)));
        }
        afterEffect = await snapshot(page.locator(action.effectLocator));
        detail = { ...detail, clipboard_changed: beforeClipboard !== afterClipboard, clipboard_length: afterClipboard.length };
      } else if (effectType === "download") {
        trigger = "download";
        const downloadPromise = page.waitForEvent("download", { timeout: 15_000 });
        await control.click();
        const download = await downloadPromise;
        expect(download.suggestedFilename()).not.toBe("");
        afterEffect = await snapshot(page.locator(action.effectLocator));
        detail = { ...detail, filename: download.suggestedFilename() };
      } else if (effectType === "navigation") {
        const target = await control.getAttribute("target");
        const href = await control.getAttribute("href");
        const startUrl = page.url();
        if (target === "_blank" || /new (?:tab|window)|opens in/i.test(action.expectedEffect)) {
          trigger = "popup_navigation";
          let popup: Page | null = null;
          for (let attempt = 0; attempt < 2 && popup === null; attempt += 1) {
            if (attempt > 0) {
              await gotoRoute(page, route, build.id);
              await prepareMember(page, context, action);
            }
            const popupControls = page.locator(action.locator);
            await popupControls.first().waitFor({ state: "visible", timeout: 60_000 }).catch(() => undefined);
            const popupControl = popupControls.nth(
              Math.min(originalIndex, Math.max(0, (await popupControls.count()) - 1)),
            );
            try {
              await expect(popupControl).toBeVisible({ timeout: 60_000 });
              // Attach the rejection handler before clicking. Dynamic build galleries can
              // re-render between locator discovery and the click; an unhandled page-event
              // timeout must not abort the retry that re-hydrates the route.
              const popupPromise = page.waitForEvent("popup", { timeout: 30_000 }).catch(() => null);
              await popupControl.click({ timeout: 30_000 });
              popup = await popupPromise;
            } catch {
              popup = null;
            }
          }
          expect(popup, `${route}/${action.id} must open a browser page`).not.toBeNull();
          if (popup === null) throw new Error(`${route}/${action.id} did not open a browser page`);
          await popup.waitForLoadState("domcontentloaded", { timeout: 15_000 }).catch(() => {});
          expect(popup.url()).not.toBe("");
          detail = { ...detail, target_url: popup.url() };
          await popup.close();
        } else if (tag === "a" && href) {
          trigger = "native_anchor_navigation";
          const targetUrl = new URL(href, startUrl).toString();
          expect(targetUrl).not.toBe(startUrl);
          const response = await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 60_000 });
          expect(response?.status()).toBeLessThan(400);
          expect(page.url()).not.toBe(startUrl);
          detail = { ...detail, target_url: page.url(), href };
        } else {
          trigger = "same_tab_navigation";
          await control.click();
          await expect.poll(() => page.url(), { timeout: 20_000 }).not.toBe(startUrl);
          detail = { ...detail, target_url: page.url() };
        }
        afterEffect = { count: 1, visibleCount: 1, digest: JSON.stringify(detail), text: String(detail.target_url) };
      } else {
        if (action.id.includes("delete")) page.once("dialog", (dialog) => dialog.accept());
        await expect(control).toBeEnabled({ timeout: 15_000 });
        await control.click();
        if (action.id === "agents-run") {
          await expect(page.getByTestId("ar-result")).toBeVisible({ timeout: 180_000 });
        }
        const deltaTimeout = action.id.startsWith("agents-")
          ? 180_000
          : action.id.startsWith("technology-")
            ? 60_000
          : normalizedId.startsWith("organism-")
            ? 15_000
            : 5_000;
        let afterControl = await snapshot(control);
        if (normalizedId === "organism-focus-scene") {
          await expect(page.getByTestId("phase6-accessible-scene")).toBeFocused({ timeout: deltaTimeout });
          afterEffect = await snapshot(page.locator(action.effectLocator));
        } else {
          await expect.poll(async () => {
            afterControl = await snapshot(control);
            afterEffect = await snapshot(page.locator(action.effectLocator));
            const effectChanged = afterEffect.digest !== beforeEffect.digest
              || (beforeEffect.visibleCount === 0 && afterEffect.visibleCount > 0);
            return action.requireEffectDelta
              ? effectChanged
              : effectChanged || afterControl.digest !== beforeControl.digest;
          }, {
            message: action.requireEffectDelta
              ? "control must produce a concrete effect-target delta"
              : "control must produce a concrete visible/state/data/error delta",
            timeout: deltaTimeout,
            intervals: [100, 250, 500],
          }).toBe(true);
        }
        if (action.id === "agents-run") {
          const result = page.getByTestId("ar-result");
          await expect(result).toHaveAttribute("data-contract-version", "agent-research-run-v3");
          await expect(result).toHaveAttribute("data-live-provider-calls", /^(true|false)$/);
          await expect(result).toHaveAttribute("data-audit-persisted", /^(true|false)$/);
          await expect(result).toHaveAttribute("data-analysis-only", "true");
          await expect(result).toHaveAttribute("data-role-count", "4");
          await expect(result.locator(".ar-step")).toHaveCount(4);
          for (const role of ["planner", "coder", "tester", "devops"]) {
            await expect(result.locator(`.ar-${role}`)).toBeVisible();
          }
        }
        const explicitBlocked = BLOCKED_ERROR_PATTERN.test(afterEffect.text);
        detail = {
          ...detail,
          state_or_data_delta: afterEffect.digest !== beforeEffect.digest,
          control_delta: afterControl.digest !== beforeControl.digest,
          already_active_state: initiallyActive,
          explicit_blocked_or_error: explicitBlocked,
        };
      }

      const effectTargetChanged = afterEffect.digest !== beforeEffect.digest
        || (beforeEffect.visibleCount === 0 && afterEffect.visibleCount > 0);
      const effectObserved = action.requireEffectDelta
        ? effectTargetChanged
        : effectType === "navigation"
        || effectType === "download"
        || trigger === "clipboard"
        || tag === "input"
        || tag === "textarea"
        || tag === "select"
        || Boolean(detail.control_delta)
        || normalizedId === "organism-focus-scene"
        || effectTargetChanged;
      expect(effectObserved, `${route}/${action.id} cannot pass on click alone`).toBe(true);
      if (effectType === "blocked_error") expect(BLOCKED_ERROR_PATTERN.test(afterEffect.text)).toBe(true);
      detailRows.push({ ...detail, trigger, effect_visible_count: afterEffect.visibleCount });
      audited += 1;
    }

    return {
      ...baseResult,
      control_count: controlCount,
      audited_control_count: audited,
      effect_observed: audited === visibleIndexes.length && audited > 0,
      click_only: false,
      trigger: "direct_route_control_effect",
      details: { controls: detailRows },
      passed: audited === visibleIndexes.length && audited > 0,
    };
  } catch (error) {
    return {
      ...baseResult,
      control_count: controlCount,
      audited_control_count: audited,
      effect_observed: false,
      click_only: false,
      trigger: "direct_route_control_effect",
      details: {
        precondition: action.precondition,
        effect_locator: action.effectLocator,
        completed_controls: detailRows,
      },
      passed: false,
      failure: safeMessage(error instanceof Error ? error.message : error),
    };
  }
}

test.describe.configure({ mode: "serial" });

test("all 22 canonical pages directly prove every enabled page-local action and reject unregistered controls", async ({ page, context }, testInfo) => {
  test.setTimeout(75 * 60_000);
  page.setDefaultTimeout(15_000);
  page.setDefaultNavigationTimeout(60_000);
  validateActionMatrix();

  const artifactDir = process.env.PAGE_ACTIONS_ARTIFACT_DIR?.trim()
    ? path.resolve(process.env.PAGE_ACTIONS_ARTIFACT_DIR)
    : testInfo.outputDir;
  const reportPath = path.join(artifactDir, "report.json");
  await mkdir(artifactDir, { recursive: true });
  await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(baseUrl).origin });

  const origin = new URL(baseUrl);
  const consoleErrors: string[] = [];
  const pendingConsoleErrors: Array<{ text: string; locationUrl: string }> = [];
  const expectedBlockedConsoleErrors: string[] = [];
  const expectedBlockedResponses: string[] = [];
  const pageErrors: string[] = [];
  const providerRequests: string[] = [];
  const liveProviderResponses: string[] = [];
  const responseInspections: Promise<void>[] = [];
  const audits: ActionAudit[] = [];
  const visitedRoutes = new Set<string>();
  const unregisteredByRoute = new Map<string, readonly JsonRecord[]>();
  const registeredMatchCountsByRoute = new Map<string, Readonly<Record<string, number>>>();
  let failure: unknown = null;

  page.on("console", (message) => {
    if (message.type() !== "error") return;
    pendingConsoleErrors.push({
      text: safeMessage(message.text()),
      locationUrl: message.location().url,
    });
  });
  page.on("pageerror", (error) => pageErrors.push(safeMessage(error.message)));
  page.on("request", (request) => {
    if (isProviderRequest(request.url(), request.method())) {
      providerRequests.push(`${request.method()} ${new URL(request.url()).pathname}`);
    }
  });
  context.on("response", (response) => {
    const responseUrl = new URL(response.url());
    if (
      response.request().method() === "DELETE"
      && response.status() === 403
      && /^\/api\/v1\/build\/[A-Za-z0-9_-]{1,64}$/.test(responseUrl.pathname)
    ) {
      expectedBlockedResponses.push(response.url());
    }
  });
  page.on("response", (response) => {
    const contentType = response.headers()["content-type"] ?? "";
    if (response.request().method() === "GET" || !contentType.includes("application/json")) return;
    const inspection = response.json().then((payload) => {
      if (JSON.stringify(payload).includes('"live_provider_calls":true')) {
        liveProviderResponses.push(new URL(response.url()).pathname);
      }
    }).catch(() => {});
    responseInspections.push(inspection);
  });

  const registeredRoutes = ACTION_MATRIX.map((entry) => entry.route);
  const canonicalRoutes = WORKSPACE_PAGES.map((entry) => entry.route);
  const enabledFamilies = ACTION_MATRIX.flatMap((entry) =>
    entry.families.filter((family) => family.memberActions.some((action) => action.availability === "enabled")),
  );
  const enabledMembers = ACTION_MATRIX.flatMap((entry) => entry.families)
    .flatMap((family) => family.memberActions)
    .filter((action) => action.availability === "enabled");
  const allMembers = ACTION_MATRIX.flatMap((entry) => entry.families).flatMap((family) => family.memberActions);
  const availabilityCounts = Object.fromEntries(
    (["enabled", "spec_only", "contract_only", "provider_gated", "conditional"] as const)
      .map((availability) => [availability, allMembers.filter((action) => action.availability === availability).length]),
  );
  const excludedMembers = allMembers.filter((action) => action.availability !== "enabled");
  const excludedGateCount = ACTION_MATRIX.reduce((total, entry) => total + entry.excludedGates.length, 0);
  const repoRoot = path.resolve(path.dirname(testInfo.file), "../../..");
  const productAcceptanceReportPath = process.env.PAGE_ACTIONS_PRODUCT_REPORT_PATH?.trim()
    ? path.resolve(process.env.PAGE_ACTIONS_PRODUCT_REPORT_PATH)
    : path.join(repoRoot, ".codex/runs/CURRENT/product-acceptance/report.json");
  const sourcePaths = {
    action_spec: testInfo.file,
    action_matrix: path.join(repoRoot, "apps/frontend/lib/actionMatrix.ts"),
    workspace_nav: path.join(repoRoot, "apps/frontend/lib/nav.tsx"),
    product_acceptance_spec: path.join(repoRoot, "apps/frontend/e2e/product-acceptance.spec.ts"),
    product_acceptance_report: productAcceptanceReportPath,
  };
  const sourceContents = Object.fromEntries(await Promise.all(
    Object.entries(sourcePaths).map(async ([name, filePath]) => [name, await readFile(filePath)] as const),
  ));
  const sourceFileSha256 = Object.fromEntries(
    Object.entries(sourceContents).map(([name, content]) => [name, sha256(content)]),
  );
  const sourceBindingSha256 = sha256(
    Object.entries(sourceFileSha256).sort(([left], [right]) => left.localeCompare(right))
      .map(([name, digest]) => `${name}:${digest}`).join("\n"),
  );
  const productAcceptanceSpecSource = sourceContents.product_acceptance_spec.toString("utf8");
  const productAcceptanceReportSha256 = sourceFileSha256.product_acceptance_report;
  const hostedProof = proofScope === "hosted_https";
  const report: JsonRecord = {
    contract_version: "22-page-action-acceptance-v2",
    registry_contract_version: ACTION_MATRIX_CONTRACT_VERSION,
    status: "running",
    started_at: new Date().toISOString(),
    completed_at: null,
    base_url: baseUrl,
    dev_only: !hostedProof,
    hosted_proof: hostedProof,
    proof_scope: proofScope,
    source_binding_sha256: sourceBindingSha256,
    source_binding: {
      git_head: process.env.PAGE_ACTIONS_GIT_HEAD ?? null,
      source_commit_sha: expectedSourceCommitSha || null,
      source_archive_sha256: expectedSourceArchiveSha256 || null,
      deployment_id: expectedDeploymentId || null,
      product_acceptance_report_path: path.relative(repoRoot, productAcceptanceReportPath).replaceAll("\\", "/"),
      product_acceptance_report_sha256: productAcceptanceReportSha256,
      files_sha256: sourceFileSha256,
    },
    registered_route_count: registeredRoutes.length,
    visited_route_count: 0,
    route_registry_parity: false,
    registry_summary: ACTION_MATRIX_SUMMARY,
    registered_enabled_family_count: enabledFamilies.length,
    audited_enabled_family_count: 0,
    effect_verified_family_count: 0,
    registered_enabled_member_action_count: enabledMembers.length,
    audited_enabled_member_action_count: 0,
    direct_effect_count: 0,
    preverified_exact_control_count: 0,
    non_direct_pass_count: 0,
    registered_member_counts_by_availability: availabilityCounts,
    excluded_member_action_count: excludedMembers.length,
    excluded_spec_only_count: availabilityCounts.spec_only,
    excluded_contract_only_count: availabilityCounts.contract_only,
    excluded_provider_gated_count: availabilityCounts.provider_gated,
    excluded_conditional_count: availabilityCounts.conditional,
    excluded_gate_count: excludedGateCount,
    unregistered_page_local_action_count: 0,
    unregistered_page_local_actions: [],
    dead_action_count: 0,
    dead_actions: [],
    click_only_passes: 0,
    provider_request_count: 0,
    allowed_build_request_count: 0,
    live_provider_response_count: 0,
    unexpected_provider_request_count: 0,
    mocks_used: false,
    route_interception_used: false,
    appshell_controls_excluded_from_page_local_scope: true,
    page_local_control_scope: PAGE_LOCAL_INTERACTIVE_SELECTOR,
    secret_output: false,
    routes: [],
    actions: audits,
  };

  try {
    expect(["dev_only_localhost", "hosted_https"]).toContain(proofScope);
    if (hostedProof) {
      expect(origin.protocol).toBe("https:");
      expect(origin.hostname.endsWith(".vercel.app")).toBe(true);
      expect(origin.port || "443").toBe("443");
      expect(expectedSourceCommitSha).toMatch(/^[0-9a-f]{40}$/);
      expect(expectedSourceArchiveSha256).toMatch(/^[0-9a-f]{64}$/);
      expect(expectedDeploymentId).toMatch(/^dpl_[A-Za-z0-9]+$/);
    } else {
      expect(["localhost", "127.0.0.1", "::1"]).toContain(origin.hostname);
      expect(origin.port || (origin.protocol === "https:" ? "443" : "80")).toBe("8081");
      expect(expectedSourceCommitSha).toBe("");
      expect(expectedSourceArchiveSha256).toBe("");
      expect(expectedDeploymentId).toBe("");
    }
    expect(origin.username || origin.password).toBe("");
    expect(registeredRoutes).toEqual(canonicalRoutes);
    expect(registeredRoutes).toHaveLength(22);
    expect(new Set(registeredRoutes).size).toBe(22);
    report.route_registry_parity = true;

    await gotoRoute(page, "/login");
    await setSession(page, context, true);
    const persistedBuild = await loadPersistedBuild(context);

    for (const entry of ACTION_MATRIX as readonly PageActionEntry[]) {
      await gotoRoute(page, entry.route, persistedBuild.id);
      visitedRoutes.add(entry.route);
      for (const family of entry.families) {
        const enabled = family.memberActions.filter((action) => action.availability === "enabled");
        if (enabled.length > 0 && new URL(page.url()).pathname !== entry.route) {
          await gotoRoute(page, entry.route, persistedBuild.id);
        }
        for (const action of enabled) {
          if (new URL(page.url()).pathname !== entry.route) {
            await gotoRoute(page, entry.route, persistedBuild.id);
          }
          const audit = await auditMember(
            page,
            context,
            entry.route,
            family,
            action,
            persistedBuild,
            productAcceptanceSpecSource,
            productAcceptanceReportSha256,
          );
          audits.push(audit);
        }
      }
      await gotoRoute(page, entry.route, persistedBuild.id);
      const registrySnapshot = await findUnregisteredPageLocalControls(page, entry);
      unregisteredByRoute.set(entry.route, registrySnapshot.unregistered);
      registeredMatchCountsByRoute.set(entry.route, registrySnapshot.registeredMatchCounts);
    }

    await Promise.allSettled(responseInspections);
    for (const item of pendingConsoleErrors) {
      const expected403Text = /^Failed to load resource: the server responded with a status of 403 \((?:Forbidden)?\)$/;
      const matchingResponseCount = expectedBlockedResponses.filter((url) => url === item.locationUrl).length;
      const matchedConsoleCount = expectedBlockedConsoleErrors.filter((url) => url === item.locationUrl).length;
      if (
        expected403Text.test(item.text)
        && /^https?:\/\/[^/]+\/api\/v1\/build\/[A-Za-z0-9_-]{1,64}$/.test(item.locationUrl)
        && matchedConsoleCount < matchingResponseCount
      ) {
        expectedBlockedConsoleErrors.push(item.locationUrl);
      } else {
        consoleErrors.push(item.text);
      }
    }
    const auditedFamilyIds = new Set(audits.map((audit) => audit.family_id));
    const effectFamilyIds = new Set(audits.filter((audit) => audit.passed && audit.effect_observed).map((audit) => audit.family_id));
    const failedActions = audits.filter((audit) => !audit.passed);
    const clickOnlyPasses = audits.filter((audit) => audit.passed && (!audit.effect_observed || audit.click_only));
    const directEffects = audits.filter((audit) => audit.passed && audit.effect_observed && audit.proof_kind === "direct_effect");
    const preverifiedExactControls = audits.filter((audit) =>
      audit.passed && audit.effect_observed && audit.proof_kind === "preverified_exact_control"
    );
    const nonDirectPasses = audits.filter((audit) =>
      audit.passed && audit.proof_kind !== "direct_effect" && audit.proof_kind !== "preverified_exact_control"
    );
    const unregisteredActions = [...unregisteredByRoute.entries()].flatMap(([route, controls]) =>
      controls.map((control) => ({ route, ...control }))
    );
    const allowedBuildRequests = providerRequests.filter((request) => request === "POST /api/v1/build");
    const unexpectedProviderRequests = providerRequests.filter((request) => request !== "POST /api/v1/build");

    report.visited_route_count = visitedRoutes.size;
    report.audited_enabled_family_count = auditedFamilyIds.size;
    report.effect_verified_family_count = effectFamilyIds.size;
    report.audited_enabled_member_action_count = audits.length;
    report.direct_effect_count = directEffects.length;
    report.preverified_exact_control_count = preverifiedExactControls.length;
    report.non_direct_pass_count = nonDirectPasses.length;
    report.unregistered_page_local_action_count = unregisteredActions.length;
    report.unregistered_page_local_actions = unregisteredActions;
    report.dead_action_count = failedActions.length;
    report.dead_actions = failedActions.map((audit) => ({
      route: audit.route,
      action_id: audit.action_id,
      failure: audit.failure ?? "no concrete effect",
    }));
    report.click_only_passes = clickOnlyPasses.length;
    report.provider_request_count = providerRequests.length;
    report.allowed_build_request_count = allowedBuildRequests.length;
    report.live_provider_response_count = liveProviderResponses.length;
    report.unexpected_provider_request_count = unexpectedProviderRequests.length;
    report.provider_requests = providerRequests;
    report.live_provider_responses = liveProviderResponses;
    report.routes = ACTION_MATRIX.map((entry) => ({
      route: entry.route,
      visited: visitedRoutes.has(entry.route),
      enabled_family_count: entry.families.filter((family) =>
        family.memberActions.some((action) => action.availability === "enabled"),
      ).length,
      enabled_member_action_count: entry.families.flatMap((family) => family.memberActions)
        .filter((action) => action.availability === "enabled").length,
      member_counts_by_availability: Object.fromEntries(
        (["enabled", "spec_only", "contract_only", "provider_gated", "conditional"] as const).map((availability) => [
          availability,
          entry.families.flatMap((family) => family.memberActions)
            .filter((action) => action.availability === availability).length,
        ]),
      ),
      excluded_gates: entry.excludedGates.map((gate) => gate.id),
      registered_page_local_match_counts: registeredMatchCountsByRoute.get(entry.route) ?? {},
      unregistered_page_local_controls: unregisteredByRoute.get(entry.route) ?? [],
      zero_page_local_reason: entry.zeroPageLocalReason ?? null,
    }));

    expect(visitedRoutes.size).toBe(22);
    expect(auditedFamilyIds.size).toBe(enabledFamilies.length);
    expect(effectFamilyIds.size, "every enabled page-local family needs a concrete effect proof").toBe(enabledFamilies.length);
    expect(audits).toHaveLength(enabledMembers.length);
    expect(directEffects).toHaveLength(enabledMembers.length - 1);
    expect(preverifiedExactControls.map((audit) => audit.action_id)).toEqual(["workbench-build"]);
    expect(nonDirectPasses).toEqual([]);
    expect(allowedBuildRequests, "Home and Games must each use their own visible build control").toHaveLength(2);
    expect(unexpectedProviderRequests, "no direct provider/LLM endpoint may bypass /api/v1/build").toEqual([]);
    expect(liveProviderResponses, "both direct route builds must report live_provider_calls=true").toHaveLength(2);
    expect(unregisteredActions, "visible page-local controls missing from the action registry").toEqual([]);
    expect(consoleErrors).toEqual([]);
    expect(pageErrors).toEqual([]);
    expect(clickOnlyPasses).toEqual([]);
    expect(
      failedActions.map((audit) => `${audit.route}/${audit.action_id}: ${audit.failure ?? "no concrete effect"}`),
      "dead, missing, or unproven page-local actions",
    ).toEqual([]);
    report.status = "verified";
  } catch (error) {
    failure = error;
    report.status = "failed";
    report.failure = safeMessage(error instanceof Error ? error.message : error);
    throw error;
  } finally {
    await Promise.allSettled(responseInspections);
    report.completed_at = new Date().toISOString();
    report.visited_route_count = visitedRoutes.size;
    report.console_errors = consoleErrors;
    report.console_error_count = consoleErrors.length;
    report.expected_blocked_console_errors = expectedBlockedConsoleErrors;
    report.expected_blocked_console_error_count = expectedBlockedConsoleErrors.length;
    report.expected_blocked_responses = expectedBlockedResponses;
    report.page_errors = pageErrors;
    report.page_error_count = pageErrors.length;
    report.provider_requests = providerRequests;
    report.live_provider_responses = liveProviderResponses;
    report.provider_request_count = providerRequests.length;
    report.allowed_build_request_count = providerRequests.filter((request) => request === "POST /api/v1/build").length;
    report.live_provider_response_count = liveProviderResponses.length;
    report.unexpected_provider_request_count = providerRequests.filter((request) => request !== "POST /api/v1/build").length;
    report.audited_enabled_member_action_count = audits.length;
    report.audited_enabled_family_count = new Set(audits.map((audit) => audit.family_id)).size;
    report.effect_verified_family_count = new Set(
      audits.filter((audit) => audit.passed && audit.effect_observed).map((audit) => audit.family_id),
    ).size;
    report.direct_effect_count = audits.filter(
      (audit) => audit.passed && audit.effect_observed && audit.proof_kind === "direct_effect",
    ).length;
    report.preverified_exact_control_count = audits.filter(
      (audit) => audit.passed && audit.effect_observed && audit.proof_kind === "preverified_exact_control",
    ).length;
    report.non_direct_pass_count = audits.filter(
      (audit) => audit.passed
        && audit.proof_kind !== "direct_effect"
        && audit.proof_kind !== "preverified_exact_control",
    ).length;
    const finalUnregisteredActions = [...unregisteredByRoute.entries()].flatMap(([route, controls]) =>
      controls.map((control) => ({ route, ...control }))
    );
    report.unregistered_page_local_action_count = finalUnregisteredActions.length;
    report.unregistered_page_local_actions = finalUnregisteredActions;
    report.dead_action_count = audits.filter((audit) => !audit.passed).length;
    report.dead_actions = audits.filter((audit) => !audit.passed).map((audit) => ({
      route: audit.route,
      action_id: audit.action_id,
      failure: audit.failure ?? "no concrete effect",
    }));
    report.click_only_passes = audits.filter((audit) => audit.passed && (!audit.effect_observed || audit.click_only)).length;
    report.actions = audits;
    if (failure === null && report.status !== "verified") report.status = "failed";
    await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  }
});
