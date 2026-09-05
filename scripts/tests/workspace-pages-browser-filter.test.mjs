import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const {
  filteredRouteConsoleErrors,
  isCorrelatedAnonymousAuthConsoleError,
} = require("../verify-workspace-pages-browser.cjs");

const baseUrl = "http://localhost:8081";
const login = { pageId: "login" };
const home = { pageId: "home" };
const meConsole = "console: Failed to load resource: the server responded with a status of 401 (Unauthorized) @ http://localhost:8081/api/v1/auth/me:0";
const meResponse = {
  status: 401,
  url: "http://localhost:8081/api/v1/auth/me",
  resourceType: "fetch",
};

test("accepts only a correlated same-origin anonymous auth 401 on login", () => {
  assert.equal(isCorrelatedAnonymousAuthConsoleError(login, baseUrl, meConsole, [meResponse]), true);
  assert.deepEqual(filteredRouteConsoleErrors(login, baseUrl, [meConsole], [meResponse]), []);
});

test("does not mask the same auth 401 on a non-login route", () => {
  assert.equal(isCorrelatedAnonymousAuthConsoleError(home, baseUrl, meConsole, [meResponse]), false);
  assert.deepEqual(filteredRouteConsoleErrors(home, baseUrl, [meConsole], [meResponse]), [meConsole]);
});

test("does not mask an uncorrelated or cross-origin console 401", () => {
  assert.equal(isCorrelatedAnonymousAuthConsoleError(login, baseUrl, meConsole, []), false);
  const external = meConsole.replace("http://localhost:8081", "https://example.invalid");
  assert.equal(isCorrelatedAnonymousAuthConsoleError(login, baseUrl, external, [meResponse]), false);
});

test("does not mask a different status, resource type, or auth path", () => {
  const forbidden = meConsole.replace("401 (Unauthorized)", "403 (Forbidden)");
  assert.equal(isCorrelatedAnonymousAuthConsoleError(login, baseUrl, forbidden, [meResponse]), false);
  assert.equal(
    isCorrelatedAnonymousAuthConsoleError(login, baseUrl, meConsole, [{ ...meResponse, resourceType: "document" }]),
    false,
  );
  const other = meConsole.replace("/api/v1/auth/me", "/api/v1/private");
  assert.equal(isCorrelatedAnonymousAuthConsoleError(login, baseUrl, other, [meResponse]), false);
});
