import path from "node:path";
import { expect, test } from "@playwright/test";

const base = process.env.PHASE3_AUTH_SESSION_BASE_URL ?? "http://localhost:8081";
const cookieName = "__Host-sb_session";

test("login issues a signed session and rejects a tampered cookie", async ({ page, context, request }, testInfo) => {
  const pageErrors: string[] = [];
  const consoleErrors: Array<{ text: string; url: string }> = [];
  const authContractRequests: string[] = [];
  const authMeRequests: string[] = [];
  const authMeStatuses: number[] = [];
  const authRefreshRequests: string[] = [];
  const authRefreshStatuses: number[] = [];
  const authLogoutRequests: string[] = [];
  const authLogoutStatuses: number[] = [];
  const localSessionDeleteRequests: string[] = [];
  const localSessionDeleteStatuses: number[] = [];
  const githubStartRequests: string[] = [];
  const unexpectedHttpFailures: string[] = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push({ text: message.text(), url: message.location().url });
    }
  });
  page.on("request", (candidate) => {
    const url = new URL(candidate.url());
    const exactRequest = `${candidate.method()} ${url.pathname}${url.search}`;
    if (url.pathname === "/api/v1/auth/contract") authContractRequests.push(exactRequest);
    else if (url.pathname === "/api/v1/auth/me") authMeRequests.push(exactRequest);
    else if (url.pathname === "/api/v1/auth/refresh") authRefreshRequests.push(exactRequest);
    else if (url.pathname === "/api/v1/auth/logout") authLogoutRequests.push(exactRequest);
    else if (url.pathname === "/api/v1/auth/session" && candidate.method() === "DELETE") {
      localSessionDeleteRequests.push(exactRequest);
    } else if (url.pathname === "/api/v1/auth/github") githubStartRequests.push(exactRequest);
  });
  page.on("response", (candidate) => {
    const url = new URL(candidate.url());
    if (url.pathname === "/api/v1/auth/me" && candidate.request().method() === "GET") {
      authMeStatuses.push(candidate.status());
      return;
    }
    if (url.pathname === "/api/v1/auth/refresh" && candidate.request().method() === "POST") {
      authRefreshStatuses.push(candidate.status());
      return;
    }
    if (url.pathname === "/api/v1/auth/logout" && candidate.request().method() === "POST") {
      authLogoutStatuses.push(candidate.status());
    }
    if (url.pathname === "/api/v1/auth/session" && candidate.request().method() === "DELETE") {
      localSessionDeleteStatuses.push(candidate.status());
    }
    if (candidate.status() < 400) return;
    unexpectedHttpFailures.push(`${candidate.request().method()} ${url.pathname} ${candidate.status()}`);
  });

  const automaticOauthContract = page.waitForResponse((candidate) =>
    new URL(candidate.url()).pathname === "/api/v1/auth/contract"
    && candidate.request().method() === "GET",
  );
  const response = await page.goto(`${base}/login`, { waitUntil: "networkidle" });
  expect(response?.status()).toBe(200);

  const oauthContractResponse = await automaticOauthContract;
  expect(oauthContractResponse.status()).toBe(200);
  const oauthContract = await oauthContractResponse.json();
  expect(oauthContract.contract_version).toBe("auth-github-jwt-refresh-v1");
  const oauthGateOpen = (
    oauthContract.credential_issuance_ready === true
    && oauthContract.owner_activation_granted === true
  );
  const githubButton = page.getByTestId("rl-github-signin");
  const githubForm = page.locator('form[action="/api/v1/auth/github"][method="get"]');
  await expect(githubForm).toHaveCount(1);
  if (oauthGateOpen) await expect(githubButton).toBeEnabled();
  else await expect(githubButton).toBeDisabled();

  const sessionContract = await page.evaluate(async () => {
    const result = await fetch("/api/v1/auth/session/contract", { cache: "no-store" });
    return { status: result.status, body: await result.json() };
  });
  expect(sessionContract.status).toBe(200);
  expect(sessionContract.body.contract_version).toBe("auth-session-integrity-v1");
  expect(sessionContract.body.integrity.tampered_cookie_rejected).toBe(true);
  expect(sessionContract.body.external_provider_write).toBe(false);

  await page.getByLabel("Name").fill("Local Integrity User");
  // Ensure React state settled: button must reflect the typed name before clicking
  await expect(page.getByTestId("rl-signin")).toContainText("Anmelden als Local Integrity User", { timeout: 5000 });
  const signInResponse = page.waitForResponse((candidate) =>
    candidate.url().includes("/api/v1/auth/session") && candidate.request().method() === "POST",
  );
  await page.getByTestId("rl-signin").click();
  expect((await signInResponse).status()).toBe(200);
  await expect(page.getByText("Angemeldet als")).toBeVisible({ timeout: 10000 });
  await expect(page.getByText("Local Integrity User")).toBeVisible({ timeout: 10000 });

  const issuedCookie = (await context.cookies()).find((cookie) => cookie.name === cookieName);
  expect(issuedCookie?.httpOnly).toBe(true);
  expect(issuedCookie?.secure).toBe(true);
  expect(issuedCookie?.sameSite).toBe("Strict");
  expect(issuedCookie?.value.split(".")).toHaveLength(2);

  const localSignOutResponse = page.waitForResponse((candidate) =>
    new URL(candidate.url()).pathname === "/api/v1/auth/session"
    && candidate.request().method() === "DELETE",
  );
  const oauthSignOutResponse = oauthGateOpen
    ? page.waitForResponse((candidate) =>
        new URL(candidate.url()).pathname === "/api/v1/auth/logout"
        && candidate.request().method() === "POST",
      )
    : null;
  await page.getByTestId("rl-signout").click();
  const localSignOutHttp = await localSignOutResponse;
  expect(localSignOutHttp.status()).toBe(200);
  expect(await localSignOutHttp.json()).toMatchObject({ status: "signed_out", cookies_cleared: true });
  if (oauthSignOutResponse) {
    const oauthSignOutHttp = await oauthSignOutResponse;
    expect(oauthSignOutHttp.status()).toBe(200);
    expect(await oauthSignOutHttp.json()).toMatchObject({
      status: "logged_out",
      cookies_cleared: true,
      active_refresh_token_absent: true,
      audit_persisted: true,
    });
  }
  await expect(page.getByTestId("rl-signin")).toBeVisible();
  expect((await context.cookies()).find((cookie) => cookie.name === cookieName)).toBeUndefined();

  const secondSignInResponse = page.waitForResponse((candidate) =>
    new URL(candidate.url()).pathname === "/api/v1/auth/session"
    && candidate.request().method() === "POST",
  );
  await page.getByTestId("rl-signin").click();
  expect((await secondSignInResponse).status()).toBe(200);
  await expect(page.getByText("Angemeldet als")).toBeVisible({ timeout: 10000 });
  const secondIssuedCookie = (await context.cookies()).find((cookie) => cookie.name === cookieName);
  expect(secondIssuedCookie?.value.split(".")).toHaveLength(2);

  const value = secondIssuedCookie?.value ?? "";
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
  expect((await context.cookies()).find((cookie) => cookie.name === cookieName)).toBeUndefined();

  const unsupportedProvider = await request.post(`${base}/api/v1/auth/session`, {
    data: { provider: "github", name: "Not Allowed" },
  });
  expect(unsupportedProvider.status()).toBe(400);
  expect((await unsupportedProvider.json()).error).toBe("provider_or_name_invalid");

  expect(authContractRequests, "the provider gate is read exactly once per page load").toEqual([
    "GET /api/v1/auth/contract",
    "GET /api/v1/auth/contract",
  ]);
  expect(localSessionDeleteRequests, "local revoke is never skipped or hidden").toEqual([
    "DELETE /api/v1/auth/session",
  ]);
  expect(localSessionDeleteStatuses).toEqual([200]);
  expect(githubStartRequests, "provider start is never requested without a human click").toEqual([]);
  if (oauthGateOpen) {
    expect(authMeRequests, "open OAuth gate probes identity exactly once per page load").toEqual([
      "GET /api/v1/auth/me",
      "GET /api/v1/auth/me",
    ]);
    expect(authMeStatuses, "an unintended successful identity response cannot masquerade as no request").toEqual([401, 401]);
    expect(authRefreshRequests, "each expired/absent access probe uses the seven-day refresh boundary").toEqual([
      "POST /api/v1/auth/refresh",
      "POST /api/v1/auth/refresh",
    ]);
    expect(authRefreshStatuses).toEqual([401, 401]);
    expect(authLogoutRequests).toEqual(["POST /api/v1/auth/logout"]);
    expect(authLogoutStatuses).toEqual([200]);
  } else {
    expect(authMeRequests, "closed OAuth gate must suppress /auth/me probes").toEqual([]);
    expect(authMeStatuses).toEqual([]);
    expect(authRefreshRequests, "closed OAuth gate must suppress refresh probes").toEqual([]);
    expect(authRefreshStatuses).toEqual([]);
    expect(authLogoutRequests, "closed OAuth gate is not an applicable OAuth session").toEqual([]);
    expect(authLogoutStatuses).toEqual([]);
  }

  const remainingExpectedAuthErrors = [
    ...authMeStatuses.filter((status) => status >= 400).map((status) => ({ pathname: "/api/v1/auth/me", status })),
    ...authRefreshStatuses.filter((status) => status >= 400).map((status) => ({ pathname: "/api/v1/auth/refresh", status })),
  ];
  const unexpectedConsoleErrors = consoleErrors.filter((message) => {
    let pathname = "";
    try {
      pathname = new URL(message.url).pathname;
    } catch {
      return true;
    }
    if (pathname !== "/api/v1/auth/me" && pathname !== "/api/v1/auth/refresh") return true;
    const match = message.text.match(/^Failed to load resource: the server responded with a status of (\d+) \(.+\)$/);
    if (!match) return true;
    const status = Number(match[1]);
    const expectedIndex = remainingExpectedAuthErrors.findIndex((candidate) =>
      candidate.pathname === pathname && candidate.status === status,
    );
    if (expectedIndex < 0) return true;
    remainingExpectedAuthErrors.splice(expectedIndex, 1);
    return false;
  });

  const artifactDir = process.env.PHASE3_AUTH_SESSION_ARTIFACT_DIR;
  const screenshotPath = artifactDir
    ? path.join(artifactDir, "login-auth-session-integrity.png")
    : testInfo.outputPath("login-auth-session-integrity.png");
  await page.screenshot({ path: screenshotPath, fullPage: true });
  expect(unexpectedHttpFailures, "no unexpected failed page responses").toEqual([]);
  expect(remainingExpectedAuthErrors, "every expected OAuth boundary failure has one exact console error").toEqual([]);
  expect(pageErrors, "no page errors during auth-session integrity proof").toEqual([]);
  expect(unexpectedConsoleErrors, "no unexpected console errors during auth-session integrity proof").toEqual([]);
});
