from __future__ import annotations

import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException
from pydantic import ValidationError

from app import main


def gateway_response(
    role: str,
    *,
    provider: str = "unit-gateway-provider",
    live_provider_calls: bool = False,
    local_model_calls: bool = True,
    audit_persisted: bool = True,
    output_text: str | None = None,
) -> dict[str, object]:
    return {
        "id": f"resp-{role}",
        "object": "response",
        "status": "completed",
        "contract_version": "llm-responses-adapter-contract-v1",
        "evidence_ref": "llm_responses_adapter_contract_visible",
        "trace_id": "trace-agent-run-unit",
        "model": f"unit-model-{role}",
        "provider_name": provider,
        "output_text": output_text or f"{role} output",
        "output": [],
        "live_provider_calls": live_provider_calls,
        "local_model_calls": local_model_calls,
        "model_downloads": False,
        "audit_persisted": audit_persisted,
        "secret_output": False,
    }


def budget_state() -> SimpleNamespace:
    return SimpleNamespace(
        level="ok",
        spent_percentage=2.5,
        total_cost_cents=5,
        budget_limit_cents=200,
    )


class AgentResearchRunTests(unittest.TestCase):
    def setUp(self) -> None:
        self.http_request = SimpleNamespace(state=SimpleNamespace(trace_id="trace-agent-run-unit"))

    def test_three_steps_use_gateway_only_and_match_frontend_shape(self) -> None:
        responses = [
            gateway_response("planner"),
            gateway_response("researcher", live_provider_calls=True, local_model_calls=False),
            gateway_response("writer"),
        ]
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses", side_effect=responses) as gateway,
        ):
            result = main.agent_research_run(
                main.AgentResearchRunRequest(goal="Explain bounded agent research"),
                self.http_request,
            )

        self.assertEqual(gateway.call_count, 3)
        self.assertEqual(result["contract_version"], main.AGENT_RESEARCH_RUN_CONTRACT_VERSION)
        self.assertEqual(result["evidence_ref"], main.AGENT_RESEARCH_RUN_EVIDENCE_REF)
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["mode"], "dev_only_gateway_pipeline")
        self.assertEqual(result["goal"], "Explain bounded agent research")
        self.assertEqual(result["provider"], "unit-gateway-provider")
        self.assertEqual([step["role"] for step in result["steps"]], ["planner", "researcher", "writer"])
        self.assertEqual([step["label"] for step in result["steps"]], ["Planner", "Researcher", "Writer"])
        self.assertEqual(result["answer"], "writer output")
        self.assertEqual(result["sources"], [])
        self.assertTrue(result["live_provider_calls"])
        self.assertTrue(result["local_model_calls"])
        self.assertTrue(result["audit_persisted"])
        self.assertFalse(result["live_mcp_writes"])
        self.assertFalse(result["direct_provider_calls"])
        self.assertFalse(result["production_deploy"])
        self.assertFalse(result["secret_output"])

        payloads = [call.args[0] for call in gateway.call_args_list]
        self.assertNotIn("live_provider_calls_allowed", payloads[0]["metadata"])
        self.assertIn("planner output", payloads[1]["input"])
        self.assertIn("planner output", payloads[2]["input"])
        self.assertIn("researcher output", payloads[2]["input"])
        self.assertTrue(all(payload["store"] is False for payload in payloads))
        self.assertTrue(all(payload["metadata"]["source_retrieval"] is False for payload in payloads))

    def test_gateway_failure_stops_pipeline_without_fallback(self) -> None:
        gateway_error = HTTPException(status_code=503, detail="gateway unavailable")
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses", side_effect=gateway_error) as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(gateway.call_count, 1)

    def test_budget_guard_blocks_before_gateway(self) -> None:
        budget_error = HTTPException(status_code=429, detail="budget guard")
        with (
            patch.object(main, "check_budget_guard", side_effect=budget_error),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 429)
        gateway.assert_not_called()

    def test_empty_gateway_output_fails_closed(self) -> None:
        response = gateway_response("planner")
        response["output_text"] = ""
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses", return_value=response) as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 502)
        self.assertEqual(gateway.call_count, 1)

    def test_goal_and_gateway_output_are_redacted_without_fake_sources(self) -> None:
        input_secret = "password=supersecretvalue"
        output_secret = "ghp_" + ("x" * 20)
        responses = [
            gateway_response("planner", output_text=f"plan {output_secret}"),
            gateway_response("researcher"),
            gateway_response("writer"),
        ]
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses", side_effect=responses) as gateway,
        ):
            result = main.agent_research_run(
                main.AgentResearchRunRequest(goal=f"Explain this safely: {input_secret}"),
                self.http_request,
            )

        serialized_result = json.dumps(result)
        serialized_payloads = json.dumps([call.args[0] for call in gateway.call_args_list])
        self.assertNotIn("supersecretvalue", serialized_result)
        self.assertNotIn("supersecretvalue", serialized_payloads)
        self.assertNotIn(output_secret, serialized_result)
        self.assertNotIn(output_secret, serialized_payloads)
        self.assertEqual(result["sources"], [])
        self.assertFalse(result["secret_output"])

    def test_request_rejects_blank_goal_and_extra_fields(self) -> None:
        with self.assertRaises(ValidationError):
            main.AgentResearchRunRequest(goal="   ")
        with self.assertRaises(ValidationError):
            main.AgentResearchRunRequest(goal="valid", live_provider_calls=True)

    def test_contract_states_dev_only_gateway_and_no_source_claims(self) -> None:
        contract = main.agent_research_run_contract_payload()
        self.assertEqual(contract["step_roles"], ["planner", "researcher", "writer"])
        self.assertEqual(contract["llm_gateway_endpoint"], "POST /llm/v1/responses")
        self.assertFalse(contract["guards"]["direct_provider_calls"])
        self.assertFalse(contract["guards"]["source_retrieval"])
        self.assertTrue(any("sources remains empty" in claim for claim in contract["non_claims"]))


if __name__ == "__main__":
    unittest.main()
