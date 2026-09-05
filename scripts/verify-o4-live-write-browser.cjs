const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

function parseArgs(argv) {
  const args = {
    baseUrl: "http://localhost:8081",
    out: ".phase1-artifacts/o4-live-writes/browser-proof.json",
    allowLocalhost: false,
  };
  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--base-url") args.baseUrl = argv[++index];
    else if (arg === "--out") args.out = argv[++index];
    else if (arg === "--allow-localhost") args.allowLocalhost = true;
    else if (arg === "--browser-channel") args.browserChannel = argv[++index];
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return args;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

function git(repoRoot, args) {
  return execFileSync("git", args, {
    cwd: repoRoot,
    encoding: "utf8",
    windowsHide: true,
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
}

function assertCanonicalRemote(remote) {
  const normalized = remote
    .replace(/^git@github\.com:/, "https://github.com/")
    .replace(/\.git$/, "");
  assert(
    normalized === "https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
    "Origin repository is outside the O4 allowlist",
  );
}

async function browserJson(page, url, options = {}) {
  return page.evaluate(async ({ target, init }) => {
    const response = await fetch(target, init);
    let body;
    try {
      body = await response.json();
    } catch {
      body = null;
    }
    return {
      status: response.status,
      source: response.headers.get("x-superbrain-source"),
      boundary: response.headers.get("x-superbrain-boundary"),
      body,
    };
  }, { target: url, init: options });
}

async function main() {
  const args = parseArgs(process.argv);
  const base = new URL(args.baseUrl);
  const localHosts = new Set(["localhost", "127.0.0.1", "::1"]);
  assert(base.protocol === "http:" && localHosts.has(base.hostname) && args.allowLocalhost, "O4 browser proof is DEV-ONLY and requires --allow-localhost");
  assert(!base.username && !base.password && base.pathname === "/" && !base.search && !base.hash, "Base URL must be a credential-free localhost origin");

  const repoRoot = path.resolve(__dirname, "..");
  const branch = git(repoRoot, ["branch", "--show-current"]);
  assert(branch && branch !== "main" && !branch.split("/").includes(".."), "O4 browser proof refuses main or an invalid branch");
  assertCanonicalRemote(git(repoRoot, ["remote", "get-url", "origin"]));
  const proofRuntimePaths = [
    ".dockerignore",
    "apps/frontend",
    "docker-compose.dev.yml",
    "infrastructure/nginx/dev.conf",
    "services/agent-api",
    "services/mcp-gateway",
    "scripts/start-dev-live.ps1",
    "scripts/verify-o4-live-write-browser.cjs",
    "scripts/verify-o4-live-writes.ps1",
  ];
  const runtimeStatus = git(repoRoot, [
    "status",
    "--porcelain=v1",
    "--untracked-files=all",
    "--",
    ...proofRuntimePaths,
  ]);
  assert(runtimeStatus === "", "O4 proof generation requires a clean tracked and untracked runtime worktree");

  const outPath = path.resolve(repoRoot, args.out);
  const artifactRoot = path.resolve(repoRoot, ".phase1-artifacts", "o4-live-writes");
  assert(outPath.startsWith(`${artifactRoot}${path.sep}`), "Browser evidence must stay inside .phase1-artifacts/o4-live-writes");
  fs.mkdirSync(path.dirname(outPath), { recursive: true });

  const workspaceRoot = path.resolve(repoRoot, ".phase1-artifacts", "o4-live-write-workspace");
  const probePath = path.resolve(workspaceRoot, "o4-live-write", "browser.json");
  assert(probePath.startsWith(`${workspaceRoot}${path.sep}`), "Browser probe path escaped the O4 workspace");
  assert(!probePath.toLowerCase().includes(`${path.sep}.codex${path.sep}`), "Browser probe path entered .codex");
  assert(!probePath.toLowerCase().includes(`${path.sep}secrets${path.sep}`), "Browser probe path entered a secrets directory");

  const { chromium } = require(path.join(repoRoot, "apps", "frontend", "node_modules", "playwright"));
  const launchOptions = { headless: true };
  if (args.browserChannel) launchOptions.channel = args.browserChannel;
  const browser = await chromium.launch(launchOptions);
  const context = await browser.newContext({ viewport: { width: 1440, height: 960 } });
  const page = await context.newPage();
  const consoleErrors = [];
  const pageErrors = [];
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push("console_error");
  });
  page.on("pageerror", () => pageErrors.push("page_error"));

  try {
    const toolsResponse = await page.goto(new URL("/tools", base).href, {
      waitUntil: "networkidle",
      timeout: 60_000,
    });
    assert(toolsResponse && toolsResponse.status() === 200, "Tools page did not load");

    const contract = await browserJson(page, new URL("/api/v1/tools/live-write/probe", base).href);
    assert(contract.status === 200, "O4 browser contract was not reachable");
    assert(contract.body?.contract_version === "o4-live-agent-mcp-write-v1", "O4 browser contract mismatch");
    assert(contract.body?.enabled === true, "O4 browser contract is not enabled in the DEV runtime");
    assert(contract.body?.arbitrary_paths_allowed === false, "O4 browser contract permits arbitrary paths");
    assert(contract.body?.main_write_allowed === false, "O4 browser contract permits main writes");
    assert(contract.body?.audit_fail_closed === true, "O4 browser contract is not audit fail-closed");
    assert(contract.body?.secret_output === false, "O4 browser contract reports secret output");

    const negativeKey = `o4-browser-${crypto.randomBytes(16).toString("hex")}`;
    const unauthenticatedContext = await browser.newContext();
    let unauthenticated;
    try {
      const response = await unauthenticatedContext.request.post(new URL("/api/v1/tools/live-write/probe", base).href, {
        data: {
          repository: "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
          branch,
          channel: "browser",
          idempotency_key: negativeKey,
          confirm_owner_scope: true,
        },
      });
      unauthenticated = {
        status: response.status(),
        body: await response.json(),
      };
    } finally {
      await unauthenticatedContext.close();
    }
    assert([401, 403].includes(unauthenticated.status), "Unauthenticated O4 browser write was not blocked");
    assert(unauthenticated.body?.accepted === false, "Unauthenticated O4 browser write reported acceptance");
    assert(unauthenticated.body?.secret_output === false, "Unauthenticated O4 browser write reported secret output");

    const signIn = await context.request.post(new URL("/api/v1/auth/session", base).href, {
      data: { provider: "guest" },
    });
    assert(signIn.status() === 200, "O4 browser proof could not create a bounded local session");
    const signInBody = await signIn.json();
    assert(signInBody.status === "signed_in", "O4 browser session was not signed in");
    assert(signInBody.secret_output === false, "O4 browser session reports secret output");

    const idempotencyKey = `o4-browser-${crypto.randomBytes(16).toString("hex")}`;
    const proof = await browserJson(page, new URL("/api/v1/tools/live-write/probe", base).href, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        repository: "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
        branch,
        channel: "browser",
        idempotency_key: idempotencyKey,
        confirm_owner_scope: true,
      }),
    });
    assert(proof.status === 200, `O4 browser write expected HTTP 200, got ${proof.status}`);
    assert(proof.source === "o4-live-write-verified", "O4 browser source header mismatch");
    assert(proof.boundary === "agent-api-boundary", "O4 browser boundary header mismatch");
    const body = proof.body;
    assert(body?.contract_version === "o4-live-agent-mcp-write-v1", "O4 browser response contract mismatch");
    for (const field of [
      "write_performed",
      "readback_verified",
      "audit_persisted",
      "audit_fail_closed",
      "rollback_on_audit_failure",
      "agent_audit_readback_verified",
      "live_agent_tool_writes",
      "live_mcp_writes",
      "owner_scope_approved",
      "branch_protection_verified",
      "DEV_ONLY",
    ]) {
      assert(body?.[field] === true, `O4 browser response expected ${field}=true`);
    }
    for (const field of ["main_write", "force_push", "live_provider_calls", "direct_provider_calls", "production_deploy", "secret_output"]) {
      assert(body?.[field] === false, `O4 browser response expected ${field}=false`);
    }
    assert(body.repository === "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM", "O4 browser repository mismatch");
    assert(body.branch === branch && body.channel === "browser", "O4 browser branch/channel mismatch");
    assert(body.write_path === "/tmp/agent-workspace/o4-live-write/browser.json", "O4 browser write path mismatch");
    assert(/^[a-f0-9]{64}$/.test(body.content_sha256), "O4 browser content hash missing");
    for (const field of ["prewrite_audit_event_id", "mcp_audit_event_id", "agent_audit_event_id"]) {
      assert(typeof body[field] === "string" && /^[a-f0-9-]{36}$/.test(body[field]), `O4 browser ${field} invalid`);
    }

    const probeBytes = fs.readFileSync(probePath);
    assert(sha256(probeBytes) === body.content_sha256, "O4 browser host-workspace readback hash mismatch");
    const probePayload = JSON.parse(probeBytes.toString("utf8"));
    assert(probePayload.idempotency_key === idempotencyKey, "O4 browser host-workspace idempotency mismatch");
    assert(probePayload.live_agent_tool_writes === true && probePayload.live_mcp_writes === true, "O4 browser host-workspace claims mismatch");
    assert(probePayload.production_deploy === false && probePayload.secret_output === false, "O4 browser host-workspace safety mismatch");

    await page.evaluate((result) => {
      const pre = document.createElement("pre");
      pre.id = "o4-live-write-browser-proof";
      pre.textContent = [
        "O4 LIVE WRITE VERIFIED",
        `branch=${result.branch}`,
        `mcp_audit=${result.mcp_audit_event_id}`,
        `agent_audit=${result.agent_audit_event_id}`,
        "secret_output=false",
        "production_deploy=false",
      ].join("\n");
      pre.style.cssText = "position:fixed;right:16px;bottom:16px;z-index:99999;padding:16px;background:#07140d;color:#8fffb3;border:1px solid #42d77d;max-width:680px;white-space:pre-wrap";
      document.body.appendChild(pre);
    }, body);
    const screenshotPath = path.join(path.dirname(outPath), "browser-proof.png");
    await page.screenshot({ path: screenshotPath, fullPage: true, animations: "disabled" });

    assert(consoleErrors.length === 0, "O4 browser proof emitted console errors");
    assert(pageErrors.length === 0, "O4 browser proof emitted page errors");
    const report = {
      contract_version: "o4-live-write-browser-proof-v1",
      status: "verified",
      evidence_ref: "o4_live_write_browser_verified",
      verified_at_utc: new Date().toISOString(),
      source_commit: git(repoRoot, ["rev-parse", "HEAD"]),
      repository: "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
      branch,
      browser: "chromium",
      browser_version: browser.version(),
      real_browser: true,
      page: "/tools",
      endpoint: "POST /api/v1/tools/live-write/probe",
      unauthenticated_write_blocked: true,
      signed_session_verified: true,
      write_performed: true,
      readback_verified: true,
      host_workspace_readback_verified: true,
      audit_persisted: true,
      audit_fail_closed: true,
      live_agent_tool_writes: true,
      live_mcp_writes: true,
      owner_scope_approved: true,
      branch_protection_verified: true,
      proof_worktree_clean_verified: true,
      main_write: false,
      force_push: false,
      live_provider_calls: false,
      direct_provider_calls: false,
      production_deploy: false,
      secret_output: false,
      DEV_ONLY: true,
      write_path: body.write_path,
      content_sha256: body.content_sha256,
      prewrite_audit_event_id: body.prewrite_audit_event_id,
      mcp_audit_event_id: body.mcp_audit_event_id,
      agent_audit_event_id: body.agent_audit_event_id,
      screenshot: path.relative(repoRoot, screenshotPath).replaceAll("\\", "/"),
      non_claims: [
        "DEV-ONLY; hosted proof still blocked.",
        "No main write, force push, provider write, release, production deployment, or secret output occurred.",
      ],
    };
    fs.writeFileSync(outPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
    console.log(`[o4-browser] status=verified branch=${branch} audit_persisted=true secret_output=false`);
    console.log(`[o4-browser] evidence=${path.relative(repoRoot, outPath).replaceAll("\\", "/")}`);
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((error) => {
  console.error(`[o4-browser] failed: ${error.message}`);
  process.exit(1);
});
