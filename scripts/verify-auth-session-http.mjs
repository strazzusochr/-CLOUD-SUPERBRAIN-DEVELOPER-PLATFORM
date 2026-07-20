import assert from "node:assert/strict";

const flagIndex = process.argv.indexOf("--base-url");
const baseUrl = (flagIndex >= 0 ? process.argv[flagIndex + 1] : "http://localhost:8081").replace(/\/+$/, "");
const endpoint = `${baseUrl}/api/v1/auth/session`;

const issued = await fetch(endpoint, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ provider: "name", name: "Integrity Probe" }),
});
assert.equal(issued.status, 200);
const issuedBody = await issued.json();
assert.equal(issuedBody.status, "signed_in");
assert.equal(issuedBody.external_provider_write, false);
const setCookie = issued.headers.get("set-cookie") ?? "";
assert.match(setCookie, /HttpOnly/i);
assert.match(setCookie, /Secure/i);
assert.match(setCookie, /SameSite=strict/i);
const cookieMatch = setCookie.match(/__Host-sb_session=([^;\r\n]+)/);
assert.ok(cookieMatch);
const token = cookieMatch[1];
assert.equal(token.split(".").length, 2);

const valid = await fetch(endpoint, { headers: { cookie: `__Host-sb_session=${token}` } });
assert.equal(valid.status, 200);
const validBody = await valid.json();
assert.equal(validBody.status, "signed_in");
assert.equal(validBody.user.name, "Integrity Probe");

const replacement = token.endsWith("A") ? "B" : "A";
const tampered = `${token.slice(0, -1)}${replacement}`;
const invalid = await fetch(endpoint, { headers: { cookie: `__Host-sb_session=${tampered}` } });
assert.equal(invalid.status, 200);
const invalidBody = await invalid.json();
assert.equal(invalidBody.status, "anonymous");
assert.equal(invalidBody.session_invalidated, true);
assert.equal(JSON.stringify(invalidBody).includes(tampered), false);
const invalidClearCookie = invalid.headers.get("set-cookie") ?? "";
assert.match(invalidClearCookie, /__Host-sb_session=;/);
assert.match(invalidClearCookie, /expires=Thu, 01 Jan 1970|max-age=0/i);

const unsupported = await fetch(endpoint, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ provider: "github", name: "Blocked" }),
});
assert.equal(unsupported.status, 400);
assert.equal((await unsupported.json()).error, "provider_or_name_invalid");

const loggedOut = await fetch(endpoint, { method: "DELETE", headers: { cookie: `__Host-sb_session=${token}` } });
assert.equal(loggedOut.status, 200);
assert.equal((await loggedOut.json()).cookies_cleared, true);

console.log(JSON.stringify({
  status: "verified",
  valid_cookie_accepted: true,
  tampered_cookie_rejected: true,
  invalid_cookie_clear_header: true,
  unsupported_provider_rejected: true,
  logout_cookie_cleared: true,
  external_provider_write: false,
  token_output: false,
}));
