import { expect, test } from "@playwright/test";

const base = process.env.GOAL_B_PRODUCT_BASE_URL ?? "";

test("F2 agents page runs the real multi-agent research pipeline", async ({ page }) => {
  test.setTimeout(180_000);
  const seen: string[] = [];
  page.on("requestfinished", (request) => seen.push(request.url()));

  const response = await page.goto(`${base}/agents`, { waitUntil: "domcontentloaded" });
  expect(response?.status()).toBe(200);
  await page.getByLabel("Forschungsziel").fill("Erkläre kurz, wofür Vektordatenbanken in einer Agentenplattform verwendet werden.");
  await page.getByTestId("ar-run").click();
  const result = page.getByTestId("ar-result");
  await expect(result).toBeVisible({ timeout: 180_000 });
  await expect(result.locator(".ar-step")).toHaveCount(3);
  await expect(result.locator(".ar-answer-body")).not.toBeEmpty();
  await expect(result.locator(".ar-answer-body")).toContainText(/Vektor|Embedding|Ähnlichkeit/i);
  await expect(page.getByText("echt · Workers AI")).toBeVisible();
  expect(seen.some((url) => url.includes("/api/v1/agent-run"))).toBeTruthy();
});
