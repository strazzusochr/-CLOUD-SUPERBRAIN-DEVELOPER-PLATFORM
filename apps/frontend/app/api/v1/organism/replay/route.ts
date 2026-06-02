export const dynamic = "force-static";

/** GET /api/v1/organism/replay — MOCK replay timeline (no hosted backend here). */
export function GET() {
  return Response.json({
    contract_version: "organism-replay-v1",
    source: "mock",
    live: false,
    note: "Deterministic mock until the hosted agent-api serves /api/v1/organism/replay.",
    duration_s: 8,
    fps: 30,
    frames: [
      { t: 0.0, run_state: "planning", active: ["workbench"] },
      { t: 2.0, run_state: "executing", active: ["agents", "tools"] },
      { t: 4.0, run_state: "executing", active: ["models", "memory"] },
      { t: 6.0, run_state: "verifying", active: ["observe"] },
      { t: 8.0, run_state: "idle", active: [] },
    ],
    non_claims: ["mock data, never a live provider call", "no secret values"],
  });
}
