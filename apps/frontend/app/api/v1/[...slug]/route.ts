// Catch-all agent-api surface served by the frontend itself.
//
// Three honest modes, in priority order:
//   1. AGENT-API BOUNDARY — if a real backend origin is configured, forward the
//      request through the single approved service boundary.
//   2. PROJECT-STATE PROJECTION — no backend reachable (e.g. free Vercel deploy
//      with no origin): serve the *real* deterministic contract / file-projected
//      payloads captured from the actual agent-api into lib/endpoint-snapshot.json.
//      These are committed-state projections, identical to runtime output — not
//      fabricated data. Marked with x-superbrain-source so the source is explicit.
//   3. FAIL-CLOSED NO-BACKEND — actions that need a running backend return 503.
//
// Explicit sibling routes (organism/*, platform/verify, workspace/*, design/*)
// take precedence over this catch-all for their exact paths.

import snapshot from "../../../../lib/endpoint-snapshot.json";
import { projectedDefault, genericDefault, frontendMetrics } from "../../../../lib/endpointDefaults";
import { authorizeBoundaryWrite, authorizePublicSecurityProbe, boundaryUnavailable, proxyAuthSessionToBoundary, proxyOAuthGetToBoundary, proxyReadToBoundary, proxyToBoundary } from "../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const maxDuration = 30;

const SNAP = snapshot as Record<string, unknown>;
const OAUTH_START_BOUNDARY_TIMEOUT_MS = 8_000;
const OAUTH_CALLBACK_BOUNDARY_TIMEOUT_MS = 25_000;
const SAFE_DISPATCH_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CURRENT_PROJECTION_REQUIRED_WHEN_EDGE_ORIGIN_IS_STALE = new Set([
  "/api/v1/clouds",
  "/api/v1/clouds/layers",
  "/api/v1/clouds/deployment-preflight",
  "/api/v1/project/progress",
  "/api/v1/project/progress/layers",
  "/api/v1/project/progress/integrity",
  "/api/v1/project/progress/completion",
]);

function teamDispatchNotFound(): Response {
  return Response.json(
    {
      contract_version: "autonomous-coding-team-v1",
      dispatch_contract_version: "autonomous-task-dispatch-v1",
      team_mode: "logical_five_role_overlay_on_runtime_pool",
      status: "blocked",
      error: "dispatch_not_found",
      dispatch_id: null,
      request_id: null,
      accepted: false,
      persisted: false,
      live_provider_calls: false,
      direct_provider_calls: false,
      live_mcp_writes: false,
      provider_writes: false,
      production_deploy: false,
      production_rollout_claimed: false,
      secret_output: false,
      note: "The requested dispatch is unavailable from the read-only projection.",
    },
    {
      status: 404,
      headers: {
        "x-superbrain-source": "frontend-projection",
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
      },
    },
  );
}

async function handle(req: Request, slug: string[] | undefined, method: string): Promise<Response> {
  const pathname = `/api/v1/${(slug ?? []).join("/")}`;
  const requestedTeamDispatchId = method === "GET" && pathname === "/api/v1/team/status"
    ? new URL(req.url).searchParams.get("dispatch_id")?.trim()
    : null;
  if (requestedTeamDispatchId && !SAFE_DISPATCH_ID.test(requestedTeamDispatchId)) {
    // Reject unsafe identifiers before the service boundary sees caller-controlled input.
    return teamDispatchNotFound();
  }
  // Frontend-owned metrics must describe this deployment even when the Agent API
  // origin is reachable. Backend metrics remain available at their own origin.
  if (method === "GET" && pathname === "/api/v1/metrics") {
    return new Response(frontendMetrics(), { headers: { "content-type": "text/plain; version=0.0.4", "x-superbrain-source": "frontend-metrics" } });
  }
  if (pathname === "/api/v1/auth/github" || pathname === "/api/v1/auth/callback") {
    if (method !== "GET") {
      return Response.json(
        {
          contract_version: "frontend-oauth-method-guard-v1",
          status: "blocked",
          error: "method_not_allowed",
          credentials_issued: false,
          secret_output: false,
        },
        {
          status: 405,
          headers: {
            allow: "GET",
            "cache-control": "no-store",
            "referrer-policy": "no-referrer",
            "x-content-type-options": "nosniff",
            "x-superbrain-source": "frontend-oauth-method-guard",
          },
        },
      );
    }
    const oauthTimeoutMs = pathname === "/api/v1/auth/callback"
      ? OAUTH_CALLBACK_BOUNDARY_TIMEOUT_MS
      : OAUTH_START_BOUNDARY_TIMEOUT_MS;
    const oauth = await proxyOAuthGetToBoundary(req, pathname, oauthTimeoutMs);
    if (oauth) return oauth;
    // OAuth start/callback are security-sensitive and the callback consumes a
    // one-time state. Never retry them through the generic GET proxy or serve a
    // projected fallback after an ambiguous upstream timeout.
    return boundaryUnavailable(
      pathname,
      "agent-api",
      "The OAuth boundary did not produce a definitive response; no retry was attempted.",
      503,
    );
  }
  if (pathname === "/api/v1/auth/me" || pathname === "/api/v1/auth/refresh" || pathname === "/api/v1/auth/logout") {
    const allowedMethod = pathname === "/api/v1/auth/me" ? "GET" : "POST";
    if (method !== allowedMethod) {
      return Response.json(
        {
          contract_version: "frontend-auth-session-boundary-v1",
          status: "blocked",
          error: "method_not_allowed",
          authenticated: false,
          accepted: false,
          secret_output: false,
        },
        {
          status: 405,
          headers: {
            allow: allowedMethod,
            "cache-control": "no-store",
            "referrer-policy": "no-referrer",
            "x-content-type-options": "nosniff",
          },
        },
      );
    }
    const authSession = await proxyAuthSessionToBoundary(
      req,
      pathname as "/api/v1/auth/me" | "/api/v1/auth/refresh" | "/api/v1/auth/logout",
      6_000,
    );
    return authSession ?? boundaryUnavailable(
      `${allowedMethod} ${pathname}`,
      "agent-api",
      "The production auth-session boundary is unavailable; no retry or projection was attempted.",
      503,
    );
  }
  if (pathname === "/api/v1/security/csp/report") {
    if (method !== "POST") {
      return Response.json(
        {
          contract_version: "frontend-security-report-method-guard-v1",
          status: "blocked",
          error: "method_not_allowed",
          accepted: false,
          secret_output: false,
        },
        { status: 405, headers: { allow: "POST", "cache-control": "no-store" } },
      );
    }
    const report = await proxyToBoundary(req, "agent-api", pathname, 6_000);
    return report ?? boundaryUnavailable(
      "POST /api/v1/security/csp/report",
      "agent-api",
      "The bounded CSP report sink is unavailable; no retry or projection was attempted.",
      503,
    );
  }
  if (pathname === "/api/v1/security/csrf/probe") {
    if (method !== "POST") {
      return Response.json(
        {
          contract_version: "frontend-security-probe-method-guard-v1",
          status: "blocked",
          error: "method_not_allowed",
          accepted: false,
          secret_output: false,
        },
        { status: 405, headers: { allow: "POST", "cache-control": "no-store" } },
      );
    }
    const originBlock = authorizePublicSecurityProbe(req);
    if (originBlock) return originBlock;
    const probe = await proxyToBoundary(req, "agent-api", pathname, 6_000, { forwardCsrfMetadata: true });
    return probe ?? boundaryUnavailable(
      "POST /api/v1/security/csrf/probe",
      "agent-api",
      "The bounded CSRF probe is unavailable; no retry or projection was attempted.",
      503,
    );
  }
  const isRead = method === "GET" || method === "HEAD";
  if (!isRead) {
    const writeBlock = await authorizeBoundaryWrite(req);
    if (writeBlock) return writeBlock;
  }
  const live = isRead
    ? await proxyReadToBoundary(req, "agent-api", pathname, 6_000)
    : await proxyToBoundary(req, "agent-api", pathname, 6_000, { serviceAuth: true });
  const staleContractOrigin = live?.headers.get("x-superbrain-source") === "contract-origin-via-d1-edge"
    && CURRENT_PROJECTION_REQUIRED_WHEN_EDGE_ORIGIN_IS_STALE.has(pathname);
  if (live && !staleContractOrigin) return live;
  if (requestedTeamDispatchId) return teamDispatchNotFound();
  // projectedDefault internally covers knownDefault surfaces before generic data.
  const projected = projectedDefault(pathname, method);
  if (projected) {
    return Response.json(projected.payload, {
      status: projected.status ?? 200,
      headers: { "x-superbrain-source": "frontend-projection", "cache-control": "no-store" },
    });
  }
  // Deterministic project-state projection (real captured agent-api data).
  if (method === "GET" && pathname in SNAP) {
    return Response.json(SNAP[pathname], {
      headers: { "x-superbrain-source": "project-state-projection", "cache-control": "no-store" },
    });
  }
  if (!isRead) {
    return boundaryUnavailable(`${method} ${pathname}`, "agent-api");
  }
  return Response.json(genericDefault(pathname, method), { headers: { "x-superbrain-source": "frontend-projection", "cache-control": "no-store" } });
}

type Ctx = { params: Promise<{ slug: string[] }> };

export async function GET(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "GET");
}

export async function HEAD(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "HEAD");
}

export async function POST(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "POST");
}

export async function PUT(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "PUT");
}

export async function DELETE(req: Request, ctx: Ctx): Promise<Response> {
  return handle(req, (await ctx.params).slug, "DELETE");
}
