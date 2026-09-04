import { expect, test, type Page } from "@playwright/test";

const baseUrl = (process.env.HOSTED_O2_BASE_URL ?? "").trim().replace(/\/+$/, "");

function safeMessage(value: unknown): string {
  return String(value ?? "unknown")
    .replace(/\b(?:sk-|ghp_|github_pat_|glpat-|cfat|hf_)[A-Za-z0-9_.-]{8,}\b/gi, "[REDACTED]")
    .replace(/\b(token|secret|password|api[_-]?key)\s*[:=]\s*\S+/gi, "$1=[REDACTED]")
    .slice(0, 500);
}

async function goto(page: Page, route: string): Promise<void> {
  const response = await page.goto(`${baseUrl}${route}`, {
    waitUntil: "domcontentloaded",
    timeout: 60_000,
  });
  expect(response?.status(), `GET ${route}`).toBe(200);
  await expect(page.locator(".app-shell")).toHaveAttribute("data-hydrated", "true", { timeout: 30_000 });
}

test("hosted O2 agent, read-only tool, and technology actions have real effects", async ({ page }) => {
  test.setTimeout(6 * 60_000);
  expect(baseUrl, "HOSTED_O2_BASE_URL is required").toMatch(/^https:\/\/[^/]+\.vercel\.app$/);

  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];
  const providerRequests: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(safeMessage(message.text()));
  });
  page.on("pageerror", (error) => pageErrors.push(safeMessage(error.message)));
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (
      /\/(?:llm|v1\/chat\/completions|v1\/responses)(?:\/|$)/i.test(url.pathname)
      || /(?:api\.cloudflare\.com|workers\.ai|huggingface\.co|router\.huggingface\.co)$/i.test(url.hostname)
    ) {
      providerRequests.push(`${request.method()} ${url.origin}${url.pathname}`);
    }
  });

  const login = await page.goto(`${baseUrl}/login`, { waitUntil: "domcontentloaded", timeout: 60_000 });
  expect(login?.status()).toBe(200);
  await expect(page.getByTestId("real-login")).toHaveAttribute("data-hydrated", "true", { timeout: 30_000 });
  const current = await page.evaluate(async () => {
    const response = await fetch("/api/v1/auth/session", { cache: "no-store" });
    return { status: response.status, payload: await response.json() as Record<string, unknown> };
  });
  if (current.payload.status !== "signed_in") {
    const signedIn = await page.evaluate(async () => {
      const response = await fetch("/api/v1/auth/session", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ provider: "guest" }),
      });
      return { status: response.status, payload: await response.json() as Record<string, unknown> };
    });
    expect(signedIn.status).toBe(200);
    expect(signedIn.payload.status).toBe("signed_in");
  }

  await goto(page, "/technology");
  const technology = page.getByTestId("technology-runtime-view");
  await expect(technology).toHaveAttribute("data-state", "ready", { timeout: 30_000 });
  await expect(technology).toHaveAttribute("data-provider-count", "8");
  await expect(technology).toHaveAttribute("data-layer-count", "7");
  const refreshBefore = Number(await technology.getAttribute("data-refresh-count"));
  await page.getByTestId("technology-runtime-refresh").click();
  await expect(technology).toHaveAttribute("data-refresh-count", String(refreshBefore + 1), { timeout: 30_000 });
  await page.locator('[data-testid="technology-provider-filter"][data-filter="historical_only"]').click();
  await expect(technology).toHaveAttribute("data-visible-provider-count", "1");
  await page.locator('[data-testid="technology-provider-filter"][data-filter="all"]').click();
  await page.locator('[data-testid="technology-layer-select"][data-layer-id="layer_4"]').click();
  await expect(technology).toHaveAttribute("data-selected-layer-id", "layer_4");
  await expect(page.getByTestId("technology-layer-detail")).toContainText(/Layer 4|layer_4|LLM Gateway/i);

  await goto(page, "/agents");
  await page.getByLabel("Forschungsziel").fill("P2 providerfreier Aktionsnachweis für semantische Suche");
  const agentResponsePromise = page.waitForResponse((response) =>
    response.request().method() === "POST"
    && new URL(response.url()).pathname === "/api/v1/agent-run",
  );
  await page.getByTestId("ar-run").click();
  const agentResponse = await agentResponsePromise;
  expect(agentResponse.status()).toBe(200);
  const agentResult = page.getByTestId("ar-result");
  await expect(agentResult).toBeVisible({ timeout: 60_000 });
  await expect(agentResult).toHaveAttribute("data-contract-version", "agent-research-run-v3");
  await expect(agentResult).toHaveAttribute("data-live-provider-calls", "false");
  await expect(agentResult).toHaveAttribute("data-audit-persisted", "true");
  await expect(agentResult).toHaveAttribute("data-analysis-only", "true");
  await expect(agentResult).toHaveAttribute("data-role-count", "4");
  await expect(agentResult.locator(".ar-step")).toHaveCount(4);
  await expect(agentResult).toContainText("hosted_native_four_role_deployed_sources");

  await goto(page, "/tools");
  const toolResponsePromise = page.waitForResponse((response) =>
    response.request().method() === "POST"
    && new URL(response.url()).pathname === "/api/v1/tools/read-only/execute",
  );
  await page.getByTestId("goal-b-tool-execute").click();
  const toolResponse = await toolResponsePromise;
  expect(toolResponse.status()).toBe(200);
  const toolResult = page.getByTestId("goal-b-tool-result");
  await expect(toolResult).toContainText("✓ ausgeführt · tool=memory_read", { timeout: 30_000 });
  await expect(toolResult).toContainText("audit_persisted=true");

  expect(providerRequests).toEqual([]);
  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
});
