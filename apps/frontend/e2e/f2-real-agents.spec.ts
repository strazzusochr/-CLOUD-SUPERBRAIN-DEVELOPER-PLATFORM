import { expect, test, type Page } from "@playwright/test";

const base = process.env.GOAL_B_BASE_URL ?? "http://localhost:8081";

async function goto(page: Page, route: string) {
  const response = await page.goto(`${base}${route}`, { waitUntil: "domcontentloaded" });
  expect(response?.status(), route).toBe(200);
  await page.waitForLoadState("networkidle", { timeout: 30_000 }).catch(() => {});
}

async function runAgent(page: Page, agent: "planner" | "coder" | "tester" | "devops", expectedAction: string, expectedOutput: string) {
  const panel = page.getByTestId("goal-b-agents-panel");
  await panel.getByLabel("Agent").selectOption(agent);
  await page.getByTestId("goal-b-agent-start").click();
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("PASS agent_steer", { timeout: 180_000 });
  await expect(page.getByTestId("goal-b-agent-result")).toContainText(`agent=${agent}`);
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("local_model_calls=true");
  await expect(page.getByTestId("goal-b-agent-result")).toContainText(`action=${expectedAction}`);
  await expect(page.getByTestId("goal-b-agent-result")).toContainText(`output=${expectedOutput}`);
}

test("F2 agents page runs all four local agents with real results", async ({ page }) => {
  test.setTimeout(240_000);
  const seen: string[] = [];
  page.on("requestfinished", (request) => seen.push(request.url()));

  await goto(page, "/agents");
  await runAgent(page, "planner", "file_written", "F2/planner/");
  await runAgent(page, "coder", "file_written", "F2/workspace/");
  await runAgent(page, "tester", "command_executed", "F2/tester/");
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("exit_code=0");
  await runAgent(page, "devops", "ops_report", "F2/devops/");
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("exit_code=0");

  await page.getByTestId("goal-b-agent-status").click();
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("PASS agent_status");
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("\"agent_id\": \"planner\"");
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("\"agent_id\": \"coder\"");
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("\"agent_id\": \"tester\"");
  await expect(page.getByTestId("goal-b-agent-result")).toContainText("\"agent_id\": \"devops\"");

  expect(seen.some((url) => url.includes("/api/v1/live-agents/steer"))).toBeTruthy();
  expect(seen.some((url) => url.includes("/api/v1/live-agents/status"))).toBeTruthy();
});
