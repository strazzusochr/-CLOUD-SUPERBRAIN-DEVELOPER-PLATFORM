const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

function parseArgs(argv) {
  const args = { allowLocalhost: false };
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--allow-localhost") {
      args.allowLocalhost = true;
    } else if (arg === "--base-url") {
      args.baseUrl = argv[++i];
    }
  }
  return args;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function paethPredictor(left, up, upLeft) {
  const estimate = left + up - upLeft;
  const distanceLeft = Math.abs(estimate - left);
  const distanceUp = Math.abs(estimate - up);
  const distanceUpLeft = Math.abs(estimate - upLeft);
  if (distanceLeft <= distanceUp && distanceLeft <= distanceUpLeft) return left;
  if (distanceUp <= distanceUpLeft) return up;
  return upLeft;
}

function readPngRgba(filePath) {
  const buffer = fs.readFileSync(filePath);
  const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  assert(buffer.subarray(0, 8).equals(pngSignature), `Not a PNG: ${filePath}`);
  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  const idat = [];
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString("ascii", offset + 4, offset + 8);
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
    offset += 12 + length;
  }
  assert(width > 0 && height > 0, `PNG dimensions missing: ${filePath}`);
  assert(bitDepth === 8, `Unsupported PNG bit depth ${bitDepth}: ${filePath}`);
  assert(colorType === 2 || colorType === 6, `Unsupported PNG color type ${colorType}: ${filePath}`);
  const channels = colorType === 6 ? 4 : 3;
  const rowBytes = width * channels;
  const inflated = zlib.inflateSync(Buffer.concat(idat));
  const pixels = new Uint8Array(width * height * 4);
  let source = 0;
  let target = 0;
  let previous = new Uint8Array(rowBytes);
  for (let y = 0; y < height; y += 1) {
    const filter = inflated[source++];
    const row = new Uint8Array(rowBytes);
    for (let x = 0; x < rowBytes; x += 1) {
      const raw = inflated[source++];
      const left = x >= channels ? row[x - channels] : 0;
      const up = previous[x] || 0;
      const upLeft = x >= channels ? previous[x - channels] : 0;
      let value = raw;
      if (filter === 1) value = raw + left;
      else if (filter === 2) value = raw + up;
      else if (filter === 3) value = raw + Math.floor((left + up) / 2);
      else if (filter === 4) value = raw + paethPredictor(left, up, upLeft);
      else if (filter !== 0) throw new Error(`Unsupported PNG filter ${filter}: ${filePath}`);
      row[x] = value & 255;
    }
    for (let x = 0; x < width; x += 1) {
      const src = x * channels;
      pixels[target++] = row[src];
      pixels[target++] = row[src + 1];
      pixels[target++] = row[src + 2];
      pixels[target++] = channels === 4 ? row[src + 3] : 255;
    }
    previous = row;
  }
  return { width, height, pixels };
}

function pngVisualStats(filePath) {
  const { width, height, pixels } = readPngRgba(filePath);
  const total = width * height;
  const step = Math.max(1, Math.floor(total / 9000));
  const colors = new Set();
  let visiblePixels = 0;
  let brightPixels = 0;
  let accentPixels = 0;
  for (let index = 0; index < total; index += step) {
    const offset = index * 4;
    const red = pixels[offset];
    const green = pixels[offset + 1];
    const blue = pixels[offset + 2];
    const alpha = pixels[offset + 3];
    if (alpha > 0 && red + green + blue > 24) visiblePixels += 1;
    if (alpha > 0 && red + green + blue > 180) brightPixels += 1;
    if (alpha > 0 && (blue > 90 || green > 90) && red + green + blue > 110) accentPixels += 1;
    colors.add(`${red >> 4},${green >> 4},${blue >> 4},${alpha >> 4}`);
  }
  return {
    width,
    height,
    sampledPixels: Math.ceil(total / step),
    uniqueColorBuckets: colors.size,
    visiblePixels,
    brightPixels,
    accentPixels,
  };
}

function isLocalhost(url) {
  return /(^|\/\/)(localhost|127\.0\.0\.1|\[::1\])(?::|\/|$)/i.test(url);
}

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function gotoWithRetry(page, url, label, options = {}) {
  const attempts = options.attempts || 4;
  const transientStatuses = new Set([502, 503, 504]);
  let lastStatus = "no-response";
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const response = await page.goto(url, {
      waitUntil: options.waitUntil || "networkidle",
      timeout: options.timeout || 90000,
    });
    lastStatus = response ? response.status() : "no-response";
    if (response && (response.ok() || response.status() === 304)) {
      return response;
    }
    if (response && transientStatuses.has(response.status()) && attempt < attempts) {
      await sleep(750 * attempt);
      continue;
    }
    throw new Error(`${label} returned HTTP ${lastStatus}`);
  }
  throw new Error(`${label} did not return an OK response after ${attempts} attempts. Last status: ${lastStatus}`);
}

async function waitForBodyText(page, text, timeout = 15000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await bodyContains(page, text)) {
      return true;
    }
    await page.waitForTimeout(250);
  }
  const bodySample = await page.evaluate(() => (document.body.innerText || "").slice(0, 400)).catch(() => "");
  throw new Error(`Missing visible text "${text}". Body sample: ${bodySample}`);
}

async function bodyContains(page, text) {
  return await page.evaluate((needle) => (document.body.innerText || "").includes(needle), text);
}

async function main() {
  const args = parseArgs(process.argv);
  assert(args.baseUrl, "--base-url is required");
  const baseUrl = String(args.baseUrl).replace(/\/+$/, "");
  if (!args.allowLocalhost && isLocalhost(baseUrl)) {
    throw new Error("Reference design browser proof refuses localhost unless --allow-localhost is set.");
  }

  const repoRoot = path.resolve(__dirname, "..");
  const playwrightPath = path.join(repoRoot, "apps", "frontend", "node_modules", "playwright");
  const { chromium } = require(playwrightPath);
  const artifactDir = path.join(repoRoot, "apps", "frontend", "e2e", "__artifacts__");
  fs.mkdirSync(artifactDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
    reducedMotion: "no-preference",
  });
  const page = await context.newPage();
  const consoleErrors = [];
  page.on("pageerror", (error) => consoleErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") consoleErrors.push(`console: ${message.text()}`);
  });

  const workbenchPath = path.join(artifactDir, "reference-design-workbench.png");
  const organismPath = path.join(artifactDir, "reference-design-organism.png");
  const proofPath = path.join(repoRoot, ".phase1-artifacts", "reference-design-browser-proof-latest.json");

  try {
    await gotoWithRetry(page, `${baseUrl}/workbench`, "Workbench page");
    for (const requiredText of ["Main Workbench", "Preview / Assets", "Game View", "App Preview", "Video Preview", "Doc Preview", "RUN BINDING"]) {
      await waitForBodyText(page, requiredText);
    }
    for (const forbiddenText of ["Workspace-Surfaces", "Completion-Gate", "Gate-Matrix", "Recovery-Historie", "Metered Budget"]) {
      assert(!(await bodyContains(page, forbiddenText)), `Workbench exposed forbidden text: ${forbiddenText}`);
    }

    const workbenchProbe = await page.evaluate(() => {
      const shell = document.querySelector(".workbench-blueprint");
      const panes = Array.from(document.querySelectorAll(".workbench-blueprint .wb-pane, .workbench-blueprint .panel, .workbench-blueprint .wb-layer-board"));
      const radii = panes.map((element) => Number.parseFloat(getComputedStyle(element).borderTopLeftRadius) || 0);
      const root = getComputedStyle(document.documentElement);
      const text = document.body.innerText;
      return {
        hasShell: Boolean(shell),
        paneCount: panes.length,
        maxPanelRadius: Math.max(...radii, 0),
        bgDeep: root.getPropertyValue("--bg-deep").trim(),
        surface1: root.getPropertyValue("--surface-1").trim(),
        cyan: root.getPropertyValue("--cyan").trim(),
        hasStatusWall: /Workspace-Surfaces|Completion-Gate|Gate-Matrix|Recovery-Historie/.test(text),
      };
    });
    assert(workbenchProbe.hasShell, "Workbench blueprint shell missing.");
    assert(workbenchProbe.paneCount >= 6, `Workbench pane count too low: ${workbenchProbe.paneCount}`);
    assert(workbenchProbe.maxPanelRadius <= 16, `Workbench panel radius exceeds reference max: ${workbenchProbe.maxPanelRadius}`);
    assert(workbenchProbe.bgDeep.toLowerCase() === "#05070d", `Unexpected bg token: ${workbenchProbe.bgDeep}`);
    assert(workbenchProbe.surface1.toLowerCase() === "#0b1020", `Unexpected surface token: ${workbenchProbe.surface1}`);
    assert(workbenchProbe.cyan.toLowerCase() === "#00e5ff", `Unexpected cyan token: ${workbenchProbe.cyan}`);
    assert(!workbenchProbe.hasStatusWall, "Workbench status wall markers are visible.");
    await page.screenshot({ path: workbenchPath, fullPage: true });
    assert(fs.statSync(workbenchPath).size > 25000, "Workbench screenshot is too small to be a useful proof artifact.");

    await gotoWithRetry(page, `${baseUrl}/organism`, "Organism page");
    await page.waitForTimeout(5000);
    await page.waitForFunction(() => {
      const feed = document.querySelector('[data-testid="organism-runtime-feed"]');
      const sourceKind = feed?.getAttribute("data-source-kind") || "";
      return /spec_only|agent_api_redacted/.test(sourceKind);
    }, undefined, { timeout: 15000 });
    for (const requiredText of ["Kollektiver Organismus", "Live", "Replay", "Karte"]) {
      await waitForBodyText(page, requiredText);
    }
    const organismProbe = await page.evaluate(() => {
      const canvas = document.querySelector(".cortex-wrap canvas") || document.querySelector("canvas");
      const rect = canvas ? canvas.getBoundingClientRect() : null;
      let webgl = false;
      let nonZeroSamples = 0;
      let uniqueSamples = 0;
      if (canvas instanceof HTMLCanvasElement) {
        const gl = canvas.getContext("webgl2") || canvas.getContext("webgl");
        webgl = Boolean(gl);
        if (gl) {
          const coords = [
            [0.5, 0.5],
            [0.25, 0.25],
            [0.75, 0.25],
            [0.25, 0.75],
            [0.75, 0.75],
            [0.5, 0.2],
            [0.5, 0.8],
          ];
          const colors = new Set();
          for (const [nx, ny] of coords) {
            const px = new Uint8Array(4);
            try {
              gl.readPixels(Math.max(0, Math.floor(canvas.width * nx)), Math.max(0, Math.floor(canvas.height * ny)), 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);
              const key = `${px[0]},${px[1]},${px[2]},${px[3]}`;
              colors.add(key);
              if (px[0] || px[1] || px[2] || px[3]) nonZeroSamples += 1;
            } catch {
              // Some drivers refuse default framebuffer reads; screenshot size remains the fallback proof.
            }
          }
          uniqueSamples = colors.size;
        }
      }
      const runtimeFeed = document.querySelector('[data-testid="organism-runtime-feed"]');
      return {
        hasCanvas: Boolean(canvas),
        width: rect?.width ?? 0,
        height: rect?.height ?? 0,
        webgl,
        nonZeroSamples,
        uniqueSamples,
        runtimeFeedVisible: Boolean(runtimeFeed),
        runtimeSourceKind: runtimeFeed?.getAttribute("data-source-kind") || "",
        runtimeLive: runtimeFeed?.getAttribute("data-live") || "",
      };
    });
    assert(organismProbe.hasCanvas, "Organism canvas missing.");
    assert(organismProbe.width >= 500, `Organism canvas width too small: ${organismProbe.width}`);
    assert(organismProbe.height >= 400, `Organism canvas height too small: ${organismProbe.height}`);
    assert(organismProbe.webgl, "Organism canvas does not expose a WebGL context.");
    assert(organismProbe.runtimeFeedVisible, "Organism runtime feed missing.");
    assert(/spec_only|agent_api_redacted/.test(organismProbe.runtimeSourceKind), `Unexpected runtime source kind: ${organismProbe.runtimeSourceKind}`);
    await page.screenshot({ path: organismPath, fullPage: true });
    assert(fs.statSync(organismPath).size > 25000, "Organism screenshot is too small to be a useful proof artifact.");
    const organismPngStats = pngVisualStats(organismPath);
    assert(organismPngStats.uniqueColorBuckets >= 18, `Organism screenshot lacks visual color variance: ${organismPngStats.uniqueColorBuckets}`);
    assert(organismPngStats.visiblePixels >= 300, `Organism screenshot has too few visible pixels: ${organismPngStats.visiblePixels}`);
    assert(organismPngStats.accentPixels >= 80, `Organism screenshot has too few active accent pixels: ${organismPngStats.accentPixels}`);

    const contractResponse = await gotoWithRetry(page, `${baseUrl}/api/v1/design/reference-contract`, "Reference design contract endpoint", { waitUntil: "domcontentloaded", timeout: 30000 });
    assert(contractResponse && contractResponse.ok(), "Reference design contract endpoint is not OK.");
    const contract = await contractResponse.json();
    assert(contract.contract_version === "reference-design-conformance-v1", "Reference design contract version mismatch.");
    assert(contract.expected_page_count === 22, "Reference design expected page count mismatch.");
    assert(contract.page_count === 22, "Reference design page count mismatch.");
    assert(contract.design_rules?.visualLanguage === "industrial-developer-workbench", "Reference visual language mismatch.");
    assert(contract.organism_requirements?.no_fake_live === true, "Reference no_fake_live rule missing.");
    assert((contract.non_claims || []).some((claim) => String(claim).includes("does not claim pixel-perfect")), "Reference non-claim missing.");

    const filteredErrors = consoleErrors.filter((entry) => !/favicon|ResizeObserver loop limit exceeded/i.test(entry));
    assert(filteredErrors.length === 0, `Browser console errors: ${filteredErrors.join(" | ")}`);

    const proof = {
      contract: "reference-design-browser-proof-v1",
      base_url: baseUrl,
      localhost_dev_only: isLocalhost(baseUrl),
      screenshots: {
        workbench: path.relative(repoRoot, workbenchPath).replace(/\\/g, "/"),
        organism: path.relative(repoRoot, organismPath).replace(/\\/g, "/"),
      },
      workbench: workbenchProbe,
      organism: organismProbe,
      organism_screenshot_pixels: organismPngStats,
      reference_contract: {
        contract_version: contract.contract_version,
        expected_page_count: contract.expected_page_count,
        page_count: contract.page_count,
        visual_language: contract.design_rules.visualLanguage,
        no_fake_live: contract.organism_requirements.no_fake_live,
      },
      non_claims: [
        "Screenshot and DOM proof only; not a hosted staging proof.",
        "Localhost proof remains DEV-ONLY when base_url is localhost.",
        "No cloud mutation, live provider call, MCP write, or secret output.",
      ],
    };
    fs.mkdirSync(path.dirname(proofPath), { recursive: true });
    fs.writeFileSync(proofPath, `${JSON.stringify(proof, null, 2)}\n`, "utf8");
    console.log(`[reference-design-browser] proof=${path.relative(repoRoot, proofPath)}`);
    console.log("[reference-design-browser] checks completed");
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(`[reference-design-browser] ${error.stack || error.message}`);
  process.exit(1);
});
