export const dynamic = "force-static";

export function GET() {
  return Response.json({
    contract_version: "organism-safety-v1",
    endpoint: "/api/v1/organism/safety",
    source: "static_runtime_contract",
    live: false,
    source_kind: "policy_contract",
    gates: [
      { id: "secret_output", status: "closed", reason: "No endpoint may return token or secret values." },
      { id: "provider_writes", status: "closed", reason: "Cloud provider writes require explicit owner gate." },
      { id: "live_llm_calls", status: "closed", reason: "Direct provider calls are forbidden outside the LLM Gateway." },
      { id: "live_mcp_writes", status: "closed", reason: "MCP write tools require explicit owner gate." },
      { id: "production_deploy", status: "closed", reason: "Production deploy/release promotion is not claimed." },
      { id: "main_push", status: "closed", reason: "Main-branch writes require review gate." },
    ],
    data_rules: {
      no_fake_live: true,
      missing_backend_state: "spec_only_or_blocked",
      secret_output: false,
      writes: false,
      provider_write: false,
      production_deploy_claimed: false,
    },
    non_claims: ["policy status only", "no permission expansion", "no live provider call"],
  });
}
