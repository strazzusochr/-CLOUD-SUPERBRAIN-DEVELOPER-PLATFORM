// Release server launcher — starts the prebuilt Next app wired to the local
// 7-layer runtime (nginx → agent-api) at http://localhost:8081 by default, so every
// page projects live, layer-verified data. Override AGENT_API_INTERNAL_URL or PORT.
//
//   npm run release:build   # next build (once)
//   npm run release         # start, wired to the 7-layer runtime
//
// On hosts without the local runtime (e.g. Vercel) the pages fall back to their
// clearly-labelled spec/mock data — this launcher only sets the default target.
import { spawn } from "node:child_process";

const PORT = process.env.PORT || "3000";
const AGENT_API = process.env.AGENT_API_INTERNAL_URL || "http://localhost:8081";

const env = {
  ...process.env,
  NODE_ENV: "production",
  AGENT_API_INTERNAL_URL: AGENT_API,
  NEXT_PUBLIC_AGENT_API_URL: process.env.NEXT_PUBLIC_AGENT_API_URL || "/api",
};

console.log(`[release] Cloud Superbrain v1.0.0 — wiring pages to ${AGENT_API} (7-layer runtime)`);
console.log(`[release] listening on http://localhost:${PORT}`);

const child = spawn(process.execPath, ["node_modules/next/dist/bin/next", "start", "-p", PORT], {
  stdio: "inherit",
  env,
});
child.on("exit", (code) => process.exit(code ?? 0));
