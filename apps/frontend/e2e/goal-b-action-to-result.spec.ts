import { expect, test, type Page } from "@playwright/test";

const base = process.env.GOAL_B_BASE_URL ?? "http://localhost:8081";

async function goto(page: Page, route: string) {
  const response = await page.goto(`${base}${route}`, { waitUntil: "domcontentloaded" });
  expect(response?.status(), route).toBe(200);
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
}

test.describe("Goal B action-to-result runtime proof", () => {
  test("workbench run creates visible runtime result and artifact", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await goto(page, "/workbench");
    await page.getByTestId("goal-b-workbench-run").click();
    await expect(page.getByTestId("goal-b-workbench-result")).toContainText("PASS workbench_run", { timeout: 90_000 });
    await expect(page.getByTestId("goal-b-artifact-list")).toContainText("runtime_run");
    expect(seen.some((url) => url.includes("/api/v1/phase2/runtime/start"))).toBeTruthy();
    expect(seen.some((url) => url.includes("/api/v1/workspace/artifacts"))).toBeTruthy();
  });

  test("agents start/reset/status produce visible real local state", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await goto(page, "/agents");
    await page.getByTestId("goal-b-agent-start").click();
    await expect(page.getByTestId("goal-b-agent-result")).toContainText("PASS agent_steer", { timeout: 90_000 });
    await expect(page.getByTestId("goal-b-agent-result")).toContainText("live_provider_calls=false");
    await expect(page.getByTestId("goal-b-agent-result")).toContainText("local_model_calls=true");
    await expect(page.getByTestId("goal-b-agent-result")).toContainText("action=file_written");
    await expect(page.getByTestId("goal-b-agent-result")).toContainText("output=F2/planner/");
    await page.getByTestId("goal-b-agent-reset").click();
    await expect(page.getByTestId("goal-b-agent-result")).toContainText("PASS agent_reset");
    await page.getByTestId("goal-b-agent-status").click();
    await expect(page.getByTestId("goal-b-agent-result")).toContainText("PASS agent_status");
    expect(seen.some((url) => url.includes("/api/v1/live-agents/steer"))).toBeTruthy();
  });

  test("tools execute only read-only tool envelope with audit id", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await goto(page, "/tools");
    await page.getByTestId("goal-b-tool-execute").click();
    await expect(page.getByTestId("goal-b-tool-result")).toContainText("PASS readonly_tool_execute");
    await expect(page.getByTestId("goal-b-tool-result")).toContainText("live_mcp_writes=false");
    await expect(page.getByTestId("goal-b-tool-result")).toContainText("audit=");
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
    await page.getByLabel("Memory search query").fill("phase2");
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

  test("docs export creates a real local file and starts a download", async ({ page }) => {
    const seen: string[] = [];
    page.on("requestfinished", (request) => seen.push(request.url()));
    await goto(page, "/docs-output");
    await page.getByTestId("goal-b-docs-export-md").click();
    await expect(page.getByTestId("goal-b-docs-export-result")).toContainText("PASS docs_export");
    await expect(page.getByTestId("goal-b-docs-export-result")).toContainText("runtime_store=/workspace/evidence/F9/docs-export/");
    await expect(page.getByTestId("goal-b-docs-export-result")).toContainText("download=/exports/docs?file=");
    expect(seen.some((url) => url.includes("/exports/docs"))).toBeTruthy();
    expect(seen.some((url) => url.includes("/api/v1/workspace/artifacts"))).toBeTruthy();
  });
});
