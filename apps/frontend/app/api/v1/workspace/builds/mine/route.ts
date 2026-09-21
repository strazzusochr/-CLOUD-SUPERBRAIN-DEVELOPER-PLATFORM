import {
  boundaryUnavailable,
  proxyWorkspaceToBoundary,
  requireWorkspaceIdentity,
} from "../../../../../../lib/frontendBoundary";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

/**
 * Personal Home data. The authenticated subject is resolved from the HttpOnly
 * session on the server, then attached only to the service-authenticated
 * Agent-API request. No browser-supplied user id is accepted.
 */
export async function GET(req: Request): Promise<Response> {
  const identity = await requireWorkspaceIdentity(req);
  if (identity instanceof Response) return identity;
  const response = await proxyWorkspaceToBoundary(req, "/api/v1/workspace/builds/mine", identity);
  return response ?? boundaryUnavailable(
    "GET /api/v1/workspace/builds/mine",
    "agent-api",
    "The personal workspace boundary is unavailable; no shared build list was substituted.",
  );
}
