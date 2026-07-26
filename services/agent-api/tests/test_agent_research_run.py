from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path
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
        self.source_tmp = tempfile.TemporaryDirectory(prefix="agent-research-source-")
        self.addCleanup(self.source_tmp.cleanup)
        source_root = Path(self.source_tmp.name)
        project_state = source_root / "PROJECT_STATE.md"
        progress_manifest = source_root / "docs" / "project-progress.manifest.json"
        agent_roster = (
            source_root
            / "docs"
            / "codex-integration"
            / "autonomous-agent-roster.json"
        )
        progress_manifest.parent.mkdir(parents=True)
        agent_roster.parent.mkdir(parents=True)
        self.long_hex_sentinel = "0123456789abcdef" * 4
        project_state.write_text(
            (
                "# Current Project State\n\n"
                "Cloud Superbrain uses bounded agent research, pgvector embeddings, and lexical memory search.\n"
                f"Build fingerprint {self.long_hex_sentinel}\n"
                "password=source-secret-value\n"
            ),
            encoding="utf-8",
        )
        progress_manifest.write_text(
            json.dumps(
                {
                    "overall_percent": 86,
                    "memory": "embedding consistency and Vectorize remain fail-closed",
                }
            ),
            encoding="utf-8",
        )
        agent_roster.write_text(
            json.dumps(
                {
                    "roles": ["planner", "researcher", "writer"],
                    "policy": "read-only bounded source work",
                }
            ),
            encoding="utf-8",
        )
        self.project_state = project_state
        self.progress_manifest = progress_manifest
        self.agent_roster = agent_roster
        for patcher in (
            patch.object(main, "project_state_path", return_value=project_state),
            patch.object(main, "project_progress_manifest_path", return_value=progress_manifest),
            patch.object(main, "autonomous_agent_roster_path", return_value=agent_roster),
        ):
            patcher.start()
            self.addCleanup(patcher.stop)

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
        self.assertEqual(result["mode"], "dev_only_gateway_repo_sources")
        self.assertEqual(result["goal"], "Explain bounded agent research")
        self.assertEqual(result["provider"], "unit-gateway-provider")
        self.assertEqual([step["role"] for step in result["steps"]], ["planner", "researcher", "writer"])
        self.assertEqual([step["label"] for step in result["steps"]], ["Planner", "Researcher", "Writer"])
        self.assertEqual(result["answer"], "writer output")
        self.assertGreaterEqual(len(result["sources"]), 1)
        self.assertEqual(result["source_binding"]["status"], "bound")
        self.assertEqual(result["source_binding"]["mode"], main.AGENT_RESEARCH_SOURCE_BINDING)
        self.assertTrue(result["source_binding"]["read_only"])
        self.assertFalse(result["source_binding"]["external_network"])
        self.assertFalse(result["source_binding"]["arbitrary_path_input"])
        self.assertFalse(result["source_binding"]["filesystem_writes"])
        self.assertFalse(result["source_binding"]["source_retrieval_audit_persisted"])
        self.assertFalse(result["source_binding"]["file_wide_secret_absence_certified"])
        self.assertTrue(all("url" not in source for source in result["sources"]))
        self.assertTrue(all(source["canonical_path"] for source in result["sources"]))
        self.assertTrue(any("bounded agent research" in source["extract"] for source in result["sources"]))
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
        self.assertTrue(all(payload["metadata"]["source_retrieval"] is True for payload in payloads))
        self.assertTrue(all(payload["metadata"]["source_binding"] == main.AGENT_RESEARCH_SOURCE_BINDING for payload in payloads))
        self.assertTrue(all(payload["metadata"]["source_ids"] for payload in payloads))
        self.assertTrue(all("Bound read-only project sources" in payload["input"] for payload in payloads))
        self.assertNotIn("source-secret-value", json.dumps(payloads))
        self.assertNotIn("source-secret-value", json.dumps(result))
        self.assertNotIn(self.long_hex_sentinel, json.dumps(payloads))
        self.assertNotIn(self.long_hex_sentinel, json.dumps(result))

    def test_three_source_context_is_exact_and_hash_bound_in_every_gateway_payload(self) -> None:
        self.project_state.write_text(
            "pgvector " + ("alpha project context " * 120),
            encoding="utf-8",
        )
        self.progress_manifest.write_text(
            "Vectorize " + ("beta progress context " * 120),
            encoding="utf-8",
        )
        self.agent_roster.write_text(
            "planner " + ("gamma roster context " * 120),
            encoding="utf-8",
        )
        responses = [
            gateway_response("planner"),
            gateway_response("researcher"),
            gateway_response("writer"),
        ]
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses", side_effect=responses) as gateway,
        ):
            result = main.agent_research_run(
                main.AgentResearchRunRequest(goal="pgvector Vectorize planner"),
                self.http_request,
            )

        self.assertEqual(len(result["sources"]), 3)
        self.assertEqual(gateway.call_count, 3)
        payloads = [call.args[0] for call in gateway.call_args_list]
        for source in result["sources"]:
            extract = str(source["extract"])
            self.assertGreaterEqual(len(extract), 850)
            self.assertLessEqual(len(extract), main.AGENT_RESEARCH_SOURCE_EXTRACT_CHARS)
            extract_sha256 = hashlib.sha256(extract.encode("utf-8")).hexdigest()
            self.assertEqual(source["extract_sha256"], extract_sha256)
            for payload in payloads:
                self.assertIn(extract, payload["input"])
                self.assertIn(
                    f"raw_sha256={source['raw_document_sha256']}",
                    payload["input"],
                )
                self.assertIn(
                    f"sanitized_sha256={source['sanitized_document_sha256']}",
                    payload["input"],
                )
                self.assertIn(f"extract_sha256={extract_sha256}", payload["input"])
        for payload in payloads:
            source_context = str(payload["input"]).split(
                "\n\nPlanner output:",
                maxsplit=1,
            )[0]
            self.assertLessEqual(
                len(source_context),
                main.AGENT_RESEARCH_SOURCE_CONTEXT_CHARS
                + len("Research goal:\npgvector Vectorize planner\n\nBound read-only project sources:\n"),
            )

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
            patch.object(main, "_read_agent_research_source") as source_read,
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 429)
        source_read.assert_not_called()
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

    def test_goal_gateway_output_and_bound_sources_are_redacted(self) -> None:
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
        self.assertNotIn("source-secret-value", serialized_result)
        self.assertNotIn("source-secret-value", serialized_payloads)
        self.assertNotIn(self.long_hex_sentinel, serialized_result)
        self.assertNotIn(self.long_hex_sentinel, serialized_payloads)
        self.assertGreaterEqual(len(result["sources"]), 1)
        self.assertFalse(result["secret_output"])

    def test_request_rejects_blank_goal_and_extra_fields(self) -> None:
        with self.assertRaises(ValidationError):
            main.AgentResearchRunRequest(goal="   ")
        with self.assertRaises(ValidationError):
            main.AgentResearchRunRequest(goal="valid", live_provider_calls=True)

    def test_contract_states_dev_only_gateway_and_bounded_source_claims(self) -> None:
        contract = main.agent_research_run_contract_payload()
        self.assertEqual(contract["step_roles"], ["planner", "researcher", "writer"])
        self.assertEqual(contract["llm_gateway_endpoint"], "POST /llm/v1/responses")
        self.assertFalse(contract["guards"]["direct_provider_calls"])
        self.assertTrue(contract["guards"]["source_retrieval"])
        self.assertFalse(contract["guards"]["source_prompt_instructions_trusted"])
        self.assertEqual(contract["source_binding"]["source_ids"], list(main.AGENT_RESEARCH_SOURCE_CATALOG))
        self.assertEqual(contract["source_binding"]["minimum_sources_per_run"], 1)
        self.assertFalse(contract["source_binding"]["external_network"])
        self.assertFalse(contract["source_binding"]["arbitrary_path_input"])
        self.assertFalse(contract["source_binding"]["filesystem_writes"])
        self.assertFalse(contract["source_binding"]["source_retrieval_audit_persisted"])
        self.assertIn("raw_document_sha256", contract["source_binding"]["hash_semantics"])
        self.assertTrue(any("does not browse" in claim for claim in contract["non_claims"]))

    def test_source_loading_is_bounded_redacted_and_hash_explicit(self) -> None:
        result = main._read_agent_research_source("project-state")
        document = str(result["document"])
        self.assertEqual(result["canonical_path"], "PROJECT_STATE.md")
        self.assertEqual(
            result["raw_document_sha256"],
            hashlib.sha256(self.project_state.read_bytes()).hexdigest(),
        )
        self.assertEqual(
            result["sanitized_document_sha256"],
            hashlib.sha256(document.encode("utf-8")).hexdigest(),
        )
        self.assertNotIn("source-secret-value", json.dumps(result))
        self.assertNotIn(self.long_hex_sentinel, document)
        self.assertIn("[REDACTED_LONG_HEX]", document)
        self.assertGreaterEqual(result["sensitive_lines_removed"], 1)
        self.assertEqual(result["content_transform"], "utf8_source_sanitize_v1")

        with self.assertRaises(HTTPException) as raised:
            main._read_agent_research_source("../../private-secret")
        self.assertEqual(raised.exception.status_code, 404)

    def test_no_lexical_match_uses_one_explicit_baseline_source(self) -> None:
        sources = main.retrieve_agent_research_sources("zzzznonmatchingtopic")
        self.assertEqual(len(sources), 1)
        self.assertEqual(sources[0]["source_id"], "project-state")
        self.assertEqual(sources[0]["match_score"], 0)
        self.assertEqual(sources[0]["retrieval_reason"], "baseline_fallback")
        self.assertNotIn("url", sources[0])
        self.assertEqual(
            sources[0]["extract_sha256"],
            hashlib.sha256(str(sources[0]["extract"]).encode("utf-8")).hexdigest(),
        )

    def test_tampered_extract_hash_stops_before_gateway(self) -> None:
        source = main.retrieve_agent_research_sources("bounded agent research")[0]
        source["extract_sha256"] = "0" * 64
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "retrieve_agent_research_sources", return_value=[source]),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(
            raised.exception.detail,
            "curated research source failed extract hash guard",
        )
        gateway.assert_not_called()

    def test_source_context_overflow_stops_before_gateway(self) -> None:
        sources = main.retrieve_agent_research_sources("bounded agent research")
        with (
            patch.object(main, "AGENT_RESEARCH_SOURCE_CONTEXT_CHARS", 1),
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "retrieve_agent_research_sources", return_value=sources),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(
            raised.exception.detail,
            "curated research source failed context size guard",
        )
        gateway.assert_not_called()

    def test_required_source_missing_stops_before_gateway(self) -> None:
        self.project_state.unlink()
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "curated research source unavailable")
        gateway.assert_not_called()

    def test_one_source_outside_fixed_layout_stops_before_gateway(self) -> None:
        outside_layout = Path(self.source_tmp.name) / "renamed-progress.json"
        outside_layout.write_text("{}", encoding="utf-8")
        with (
            patch.object(main, "project_progress_manifest_path", return_value=outside_layout),
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "curated research source failed path guard")
        gateway.assert_not_called()

    def test_parent_link_guard_stops_before_gateway(self) -> None:
        def link_probe(path: Path) -> bool:
            return path.name == "docs"

        with (
            patch.object(main, "_agent_research_path_is_link", side_effect=link_probe),
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "curated research source failed path guard")
        gateway.assert_not_called()

    def test_terminal_link_guard_stops_before_gateway(self) -> None:
        def link_probe(path: Path) -> bool:
            return path.name == "PROJECT_STATE.md"

        with (
            patch.object(main, "_agent_research_path_is_link", side_effect=link_probe),
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "curated research source failed path guard")
        gateway.assert_not_called()

    def test_oversize_source_reads_only_max_plus_one_and_fails(self) -> None:
        with (
            patch.object(main, "AGENT_RESEARCH_SOURCE_MAX_BYTES", 32),
            self.assertRaises(HTTPException) as raised,
        ):
            main._read_agent_research_source("project-state")

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "curated research source failed size guard")

    def test_invalid_utf8_source_fails_before_gateway(self) -> None:
        self.progress_manifest.write_bytes(b"\xff\xfe\xff")
        with (
            patch.object(main, "check_budget_guard", return_value=budget_state()),
            patch.object(main, "call_llm_gateway_responses") as gateway,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.agent_research_run(main.AgentResearchRunRequest(goal="test"), self.http_request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "curated research source failed encoding guard")
        gateway.assert_not_called()


if __name__ == "__main__":
    unittest.main()
