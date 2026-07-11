import { expect, test, type Page } from "@playwright/test";

const base = process.env.GOAL_B_BASE_URL ?? "http://localhost:8081";
const productBase = process.env.GOAL_B_PRODUCT_BASE_URL ?? base;

async function goto(page: Page, route: string) {
  const response = await page.goto(`${base}${route}`, { waitUntil: "domcontentloaded" });
  expect(response?.status(), route).toBe(200);
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
}

async function gotoProduct(page: Page, route: string) {
  const response = await page.goto(`${productBase}${route}`, { waitUntil: "domcontentloaded" });
  expect(response?.status(), route).toBe(200);
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
}

test.describe("Goal B action-to-result runtime proof", () => {
  test("workbench run creates visible runtime result and artifact", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    const response = await page.goto(`${productBase}/workbench`, { waitUntil: "domcontentloaded" });
    expect(response?.status()).toBe(200);
    await page.getByLabel("Beschreibung für die App-Erstellung").fill("Baue eine kleine Status-App mit Überschrift, Statusanzeige und Umschalter.");
    await page.getByTestId("ws-build").click();
    await expect(page.getByTestId("ws-log")).toContainText("Live-Vorschau bereit", { timeout: 240_000 });
    await expect(page.getByTestId("ws-log")).toContainText("Persistiert");
    await expect(page.locator(".ws-file").first()).toBeVisible();
    await expect(page.getByTestId("ws-frame")).toBeVisible();
    await expect(page.locator(".wb-artifacts")).toContainText(/\/run\//);
    expect(seen.some((url) => url.includes("/api/v1/build"))).toBeTruthy();
  });

  test("agents produce a visible real multi-agent result", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await gotoProduct(page, "/agents");
    await page.getByLabel("Forschungsziel").fill("Fasse den Nutzen von Embeddings für semantische Suche kurz zusammen.");
    await page.getByTestId("ar-run").click();
    const result = page.getByTestId("ar-result");
    await expect(result).toBeVisible({ timeout: 180_000 });
    await expect(result.locator(".ar-step")).toHaveCount(3);
    await expect(result.locator(".ar-answer-body")).not.toBeEmpty();
    await expect(page.getByText("Das Agenten-Team (Zielarchitektur)")).toBeVisible();
    await expect(page.getByText(/4 Rollen · Plan/)).toBeVisible();
    expect(seen.some((url) => url.includes("/api/v1/agent-run"))).toBeTruthy();
  });

  test("tools execute only read-only tool envelope with audit id", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await gotoProduct(page, "/tools");
    await page.getByTestId("goal-b-tool-execute").click();
    await expect(page.getByTestId("goal-b-tool-result")).toContainText("✓ ausgeführt · tool=memory_read", { timeout: 90_000 });
    await expect(page.getByText("Werkzeuge sicher ausführen (nur lesend)")).toBeVisible();
    expect(seen.some((url) => url.includes("/api/v1/tools/read-only/execute"))).toBeTruthy();
  });

  test("files search returns real memory hits created by artifact registry", async ({ page }) => {
    const seed = await page.request.post(`${base}/api/v1/workspace/artifacts`, {
      data: {
        project_id: "goal-b-local",
        source_page: "e2e",
        artifact_type: "search_seed",
        title: "Goal B phase2 searchable seed",
        summary: "phase2 memory search e2e seed",
        status: "ready",
      },
    });
    expect(seed.status()).toBe(201);

    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await goto(page, "/files");
    await page.getByLabel("Suchbegriff für das Gedächtnis").fill("phase2");
    await page.getByTestId("goal-b-files-search").click();
    await expect(page.getByTestId("goal-b-files-result")).toContainText("PASS files_search");
    await expect(page.getByTestId("goal-b-files-result")).toContainText(/results=[1-9]/);
    expect(seen.some((url) => url.includes("/api/v1/memory/search"))).toBeTruthy();
  });

  test("marketplace details and install dry-run create visible artifact plan", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await goto(page, "/marketplace");
    await page.getByTestId("goal-b-marketplace-details").click();
    await expect(page.getByTestId("goal-b-marketplace-result")).toContainText("PASS marketplace_details");
    await page.getByTestId("goal-b-marketplace-install").click();
    await expect(page.getByTestId("goal-b-marketplace-result")).toContainText("PASS marketplace_install");
    await expect(page.getByTestId("goal-b-marketplace-result")).toContainText("provider_writes=false");
    expect(seen.some((url) => url.includes("/api/v1/workspace/artifacts"))).toBeTruthy();
  });

  test("docs studio creates a real Markdown download", async ({ page }) => {
    await goto(page, "/docs-output");
    await page.getByLabel("Titel").fill("E2E Dokument");
    await page.getByLabel("Markdown").fill("# E2E Dokument\n\nPersistenter Browser-Download.");
    const downloadPromise = page.waitForEvent("download");
    await page.getByTestId("cs-doc-md").click();
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe("e2e-dokument.md");
    await expect(page.locator(".cs-preview")).toContainText("Persistenter Browser-Download.");
    await expect(page.locator("[data-testid='docs-library'], [data-testid='docs-library-empty']")).toBeVisible();
  });
});
