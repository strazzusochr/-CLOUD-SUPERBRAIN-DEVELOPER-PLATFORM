import assert from "node:assert/strict";
import test from "node:test";
import { isCorrelatedAnonymousAuthConsoleError } from "../../apps/frontend/e2e/auth-console-policy.js";

const validProbe = {
  baseUrl: "http://localhost:8081",
  pageId: "login",
  text: "Failed to load resource: the server responded with a status of 401 (Unauthorized)",
  locationUrl: "http://localhost:8081/api/v1/auth/me",
  resourceErrors: [{
    status: 401,
    url: "http://localhost:8081/api/v1/auth/me",
    resourceType: "fetch",
  }],
};

test("accepts the exact correlated anonymous login probe", () => {
  assert.equal(isCorrelatedAnonymousAuthConsoleError(validProbe), true);
});

test("rejects non-login, cross-origin, uncorrelated, and non-fetch variants", () => {
  assert.equal(isCorrelatedAnonymousAuthConsoleError({ ...validProbe, pageId: "settings" }), false);
  assert.equal(isCorrelatedAnonymousAuthConsoleError({ ...validProbe, locationUrl: "https://example.invalid/api/v1/auth/me" }), false);
  assert.equal(isCorrelatedAnonymousAuthConsoleError({ ...validProbe, resourceErrors: [] }), false);
  assert.equal(isCorrelatedAnonymousAuthConsoleError({
    ...validProbe,
    resourceErrors: [{ ...validProbe.resourceErrors[0], resourceType: "document" }],
  }), false);
});

test("rejects other statuses and paths", () => {
  assert.equal(isCorrelatedAnonymousAuthConsoleError({
    ...validProbe,
    text: "Failed to load resource: the server responded with a status of 403 (Forbidden)",
  }), false);
  assert.equal(isCorrelatedAnonymousAuthConsoleError({
    ...validProbe,
    locationUrl: "http://localhost:8081/api/v1/private",
  }), false);
});
