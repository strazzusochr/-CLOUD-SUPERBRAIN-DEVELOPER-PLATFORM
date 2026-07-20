import path from "node:path";
import { expect, test } from "@playwright/test";

const base = process.env.PHASE3_AUTH_SESSION_BASE_URL ?? "http://localhost:8081";
const cookieName = "__Host-sb_session";

test("login issues a signed session and rejects a tampered cookie", async ({ page, context, request }, testInfo) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => message.type() === "error" && errors.push(message.text()));

  const response = await page.goto(`${base}/login`, { waitUntil: "networkidle" });
  expect(response?.status()).toBe(200);

  const contract = await page.evaluate(async () => {
    const result = await fetch("/api/v1/auth/session/contract", { cache: "no-store" });
    return { status: result.status, body: await result.json() };
  });
  expect(contract.status).toBe(200);
  expect(contract.body.contract_version).toBe("auth-session-integrity-v1");
  expect(contract.body.integrity.tampered_cookie_rejected).toBe(true);
  expect(contract.body.external_provider_write).toBe(false);

  await page.getByLabel("Name").fill("Local Integrity User");
  const signInResponse = page.waitForResponse((candidate) =>
    candidate.url().includes("/api/v1/auth/session") && candidate.request().method() === "POST",
  );
  await page.getByTestId("rl-signin").click();
  expect((await signInResponse).status()).toBe(200);
  await expect(page.getByText("Angemeldet als")).toBeVisible();
  await expect(page.getByText("Local Integrity User")).toBeVisible();

  const issuedCookie = (await context.cookies()).find((cookie) => cookie.name === cookieName);
  expect(issuedCookie?.httpOnly).toBe(true);
  expect(issuedCookie?.secure).toBe(true);
  expect(issuedCookie?.sameSite).toBe("Strict");
  expect(issuedCookie?.value.split(".")).toHaveLength(2);

  const value = issuedCookie?.value ?? "";
  const replacement = value.endsWith("A") ? "B" : "A";
  const secureCookieUrl = new URL(base);
  secureCookieUrl.protocol = "https:";
  secureCookieUrl.pathname = "/";
  await context.addCookies([{
    name: cookieName,
    value: `${value.slice(0, -1)}${replacement}`,
    url: secureCookieUrl.toString(),
    httpOnly: true,
    secure: true,
    sameSite: "Strict",
  }]);
  const invalidatedResponse = page.waitForResponse((candidate) =>
    candidate.url().includes("/api/v1/auth/session") && candidate.request().method() === "GET",
  );
  await page.reload({ waitUntil: "networkidle" });
  const invalidatedHttp = await invalidatedResponse;
  const invalidated = await invalidatedHttp.json();
  expect(invalidated.status).toBe("anonymous");
  expect(invalidated.session_invalidated).toBe(true);
  await expect(page.getByTestId("rl-signin")).toBeVisible();
  await context.clearCookies({ name: cookieName });

  const unsupportedProvider = await request.post(`${base}/api/v1/auth/session`, {
    data: { provider: "github", name: "Not Allowed" },
  });
  expect(unsupportedProvider.status()).toBe(400);
  expect((await unsupportedProvider.json()).error).toBe("provider_or_name_invalid");

  const artifactDir = process.env.PHASE3_AUTH_SESSION_ARTIFACT_DIR;
  const screenshotPath = artifactDir
    ? path.join(artifactDir, "login-auth-session-integrity.png")
    : testInfo.outputPath("login-auth-session-integrity.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  expect(errors, "no console/page errors during auth-session integrity proof").toEqual([]);
});
