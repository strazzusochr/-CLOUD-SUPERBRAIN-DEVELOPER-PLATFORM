import { randomUUID } from "node:crypto";
import {
  authorizeBoundaryWrite,
  boundaryUnavailable,
  proxyToBoundary,
} from "../../../../lib/frontendBoundary";
import {
  buildHostedAgentResearchRun,
  isNativeRuntimeRun,
  nativeRuntimePrompt,
  readBoundedJsonRequest,
  readBoundedJsonResponse,
  safeBoundedText,
  sha256Text,
} from "../../../../lib/hostedO2Actions";

export const dynamic = "force-dynamic";
export const maxDuration = 180;

export async function POST(req: Request): Promise<Response> {
  const writeBlock = await authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;

  let goal: string;
  try {
    const body = await readBoundedJsonRequest(req);
    goal = safeBoundedText(body.goal, "goal", 1, 500);
  } catch {
    return Response.json(
      {
        contract_version: "agent-research-run-v3",
        status: "blocked",
        error: "invalid_agent_research_request",
        accepted: false,
        persisted: false,
        direct_provider_calls: false,
        live_provider_calls: false,
        live_mcp_writes: false,
        production_deploy: false,
        secret_output: false,
      },
      { status: 400, headers: { "cache-control": "no-store", "x-superbrain-source": "frontend-agent-run-guard" } },
    );
  }

  const requestId = randomUUID();
  const prompt = nativeRuntimePrompt(goal);
  const runtimeRequest = new Request(req.url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "x-request-id": requestId,
    },
    body: JSON.stringify({
      project_id: "hosted-agent-research",
      prompt,
      session_id: `agent-research-${randomUUID()}`,
    }),
  });
  const response = await proxyToBoundary(
    runtimeRequest,
    "agent-api",
    "/api/v1/phase2/runtime/start",
    30_000,
    { serviceAuth: true },
  );
  if (!response || response.status !== 201) {
    return boundaryUnavailable(
      "POST /api/v1/phase2/runtime/start",
      "agent-api",
      "The hosted deterministic four-role runtime did not complete; no frontend provider call was attempted.",
    );
  }

  try {
    const nativeRun = await readBoundedJsonResponse(response);
    if (!isNativeRuntimeRun(nativeRun) || nativeRun.prompt_sha256 !== sha256Text(prompt)) {
      throw new Error("invalid_native_runtime_response");
    }
    return Response.json(
      buildHostedAgentResearchRun(goal, nativeRun, requestId),
      {
        status: 200,
        headers: {
          "cache-control": "no-store",
          "x-superbrain-boundary": "agent-api-boundary",
          "x-superbrain-source": "cloudflare-d1-langgraph-agent-run",
        },
      },
    );
  } catch {
    return boundaryUnavailable(
      "POST /api/v1/phase2/runtime/start",
      "agent-api",
      "The hosted deterministic runtime response failed bounded contract validation; no result was accepted.",
    );
  }
}
