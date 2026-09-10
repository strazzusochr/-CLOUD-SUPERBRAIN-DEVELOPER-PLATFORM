import {
  authorizeBoundaryWrite,
  boundaryUnavailable,
  proxyToBoundary,
} from "../../../../../../lib/frontendBoundary";
import {
  readBoundedJsonRequest,
  readBoundedJsonResponse,
} from "../../../../../../lib/hostedO2Actions";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";
export const maxDuration = 30;

type JsonRecord = Record<string, unknown>;

const CONTRACT_VERSION = "o4-live-agent-mcp-write-v1";
const EVIDENCE_REF = "o4_live_agent_mcp_write_audit_verified";
const ALLOWED_REPOSITORY = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM";
const BROWSER_KEY = /^o4-browser-[a-f0-9]{32}$/;
const BRANCH = /^[A-Za-z0-9._/-]{1,160}$/;

function blocked(status: 400 | 403 | 503, error: string): Response {
  return Response.json(
    {
      contract_version: CONTRACT_VERSION,
      status: "blocked",
      error,
      accepted: false,
      write_performed: false,
      audit_persisted: false,
      live_agent_tool_writes: false,
      live_mcp_writes: false,
      live_provider_calls: false,
      direct_provider_calls: false,
      production_deploy: false,
      secret_output: false,
      DEV_ONLY: true,
    },
    {
      status,
      headers: {
        "cache-control": "no-store",
        "x-superbrain-source": "o4-live-write-guard",
      },
    },
  );
}

function isRecord(value: unknown): value is JsonRecord {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export async function GET(): Promise<Response> {
  return Response.json(
    {
      contract_version: CONTRACT_VERSION,
      endpoint: "POST /api/v1/tools/live-write/probe",
      mode: "DEV-ONLY bounded verifier probe",
      enabled: process.env.O4_LIVE_WRITE_PROBE_ENABLED === "true",
      browser_channel_only: true,
      repository: ALLOWED_REPOSITORY,
      arbitrary_paths_allowed: false,
      main_write_allowed: false,
      audit_fail_closed: true,
      rollback_on_audit_failure: true,
      evidence_ref: EVIDENCE_REF,
      live_provider_calls: false,
      direct_provider_calls: false,
      production_deploy: false,
      secret_output: false,
    },
    {
      headers: {
        "cache-control": "no-store",
        "x-superbrain-source": "o4-live-write-contract",
      },
    },
  );
}

export async function POST(req: Request): Promise<Response> {
  if (process.env.O4_LIVE_WRITE_PROBE_ENABLED !== "true") {
    return blocked(403, "o4_live_write_probe_disabled");
  }
  const writeBlock = await authorizeBoundaryWrite(req);
  if (writeBlock) return writeBlock;

  let body: JsonRecord;
  try {
    const candidate = await readBoundedJsonRequest(req);
    if (!isRecord(candidate)) throw new Error("invalid body");
    const keys = Object.keys(candidate).sort();
    if (keys.join(",") !== "branch,channel,confirm_owner_scope,idempotency_key,repository") {
      throw new Error("unexpected fields");
    }
    if (
      candidate.repository !== ALLOWED_REPOSITORY
      || candidate.channel !== "browser"
      || candidate.confirm_owner_scope !== true
      || typeof candidate.branch !== "string"
      || !BRANCH.test(candidate.branch)
      || candidate.branch === "main"
      || candidate.branch.split("/").includes("..")
      || typeof candidate.idempotency_key !== "string"
      || !BROWSER_KEY.test(candidate.idempotency_key)
    ) {
      throw new Error("scope rejected");
    }
    body = candidate;
  } catch {
    return blocked(400, "invalid_o4_live_write_request");
  }

  const boundaryRequest = new Request(req.url, {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      origin: new URL(req.url).origin,
    },
    body: JSON.stringify(body),
  });
  const response = await proxyToBoundary(
    boundaryRequest,
    "agent-api",
    "/api/v1/tools/live-write/probe",
    20_000,
    { serviceAuth: true },
  );
  if (!response) {
    return boundaryUnavailable(
      "POST /api/v1/tools/live-write/probe",
      "agent-api",
      "The bounded O4 write was not accepted because the Agent API boundary is unavailable.",
    );
  }
  if (response.status !== 200) {
    return blocked(503, "o4_live_write_boundary_failed");
  }

  try {
    const payload = await readBoundedJsonResponse(response);
    if (
      !isRecord(payload)
      || payload.contract_version !== CONTRACT_VERSION
      || payload.status !== "verified"
      || payload.evidence_ref !== EVIDENCE_REF
      || payload.repository !== ALLOWED_REPOSITORY
      || payload.branch !== body.branch
      || payload.channel !== "browser"
      || payload.agent_role !== "coder"
      || payload.toolset !== "filesystem"
      || payload.write_path !== "/tmp/agent-workspace/o4-live-write/browser.json"
      || payload.write_performed !== true
      || payload.readback_verified !== true
      || payload.audit_persisted !== true
      || payload.audit_fail_closed !== true
      || payload.rollback_on_audit_failure !== true
      || payload.agent_audit_readback_verified !== true
      || payload.live_agent_tool_writes !== true
      || payload.live_mcp_writes !== true
      || payload.owner_scope_approved !== true
      || payload.branch_protection_verified !== true
      || payload.main_write !== false
      || payload.force_push !== false
      || payload.live_provider_calls !== false
      || payload.direct_provider_calls !== false
      || payload.production_deploy !== false
      || payload.secret_output !== false
      || payload.DEV_ONLY !== true
      || typeof payload.content_sha256 !== "string"
      || !/^[a-f0-9]{64}$/.test(payload.content_sha256)
      || typeof payload.prewrite_audit_event_id !== "string"
      || typeof payload.mcp_audit_event_id !== "string"
      || typeof payload.agent_audit_event_id !== "string"
    ) {
      throw new Error("invalid boundary response");
    }
    return Response.json(
      {
        contract_version: CONTRACT_VERSION,
        status: "verified",
        evidence_ref: EVIDENCE_REF,
        repository: payload.repository,
        branch: payload.branch,
        channel: payload.channel,
        agent_role: payload.agent_role,
        toolset: payload.toolset,
        write_path: payload.write_path,
        write_performed: true,
        readback_verified: true,
        content_sha256: payload.content_sha256,
        prewrite_audit_event_id: payload.prewrite_audit_event_id,
        mcp_audit_event_id: payload.mcp_audit_event_id,
        agent_audit_event_id: payload.agent_audit_event_id,
        audit_persisted: true,
        audit_fail_closed: true,
        rollback_on_audit_failure: true,
        agent_audit_readback_verified: true,
        live_agent_tool_writes: true,
        live_mcp_writes: true,
        owner_scope_approved: true,
        branch_protection_verified: true,
        main_write: false,
        force_push: false,
        live_provider_calls: false,
        direct_provider_calls: false,
        production_deploy: false,
        secret_output: false,
        DEV_ONLY: true,
      },
      {
        status: 200,
        headers: {
          "cache-control": "no-store",
          "x-superbrain-boundary": "agent-api-boundary",
          "x-superbrain-source": "o4-live-write-verified",
        },
      },
    );
  } catch {
    return blocked(503, "o4_live_write_response_validation_failed");
  }
}
