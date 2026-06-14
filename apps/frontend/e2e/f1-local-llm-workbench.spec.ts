import { expect, test } from "@playwright/test";

const base = process.env.GOAL_B_BASE_URL ?? "http://localhost:8081";

test("F1 workbench run renders real local llm output", async ({ page }) => {
  const seen: string[] = [];
  page.on("requestfinished", (request) => seen.push(request.url()));

  const response = await page.goto(`${base}/workbench`, { waitUntil: "domcontentloaded" });
  expect(response?.status()).toBe(200);
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});

  await page.getByTestId("batch1-workbench-run").click();
  await expect(page.getByTestId("batch1-workbench-result")).toContainText("PASS batch1_workbench_run", { timeout: 240_000 });
  await expect(page.getByTestId("batch1-workbench-result")).toContainText("local_model_calls=true");
  await expect(page.getByTestId("batch1-workbench-result")).not.toContainText("deterministic dry-run");
  await expect(page.getByTestId("batch1-workbench-result")).toContainText("text=");
  expect(seen.some((url) => url.includes("/llm/v1/chat/completions"))).toBeTruthy();
  expect(seen.some((url) => url.includes("/api/v1/workspace/artifacts"))).toBeTruthy();
});
