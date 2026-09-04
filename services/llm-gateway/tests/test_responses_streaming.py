from __future__ import annotations

import importlib.util
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient


MODULE_PATH = Path(__file__).resolve().parents[1] / "app" / "main.py"
SPEC = importlib.util.spec_from_file_location("superbrain_llm_gateway_main", MODULE_PATH)
if SPEC is None or SPEC.loader is None:  # pragma: no cover - import bootstrap guard
    raise RuntimeError(f"Unable to load LLM Gateway module from {MODULE_PATH}")
gateway = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gateway
SPEC.loader.exec_module(gateway)


EVENT_PREFIX = [
    "response.created",
    "response.in_progress",
    "response.output_item.added",
    "response.content_part.added",
]
EVENT_SUFFIX = [
    "response.output_text.done",
    "response.content_part.done",
    "response.output_item.done",
    "response.completed",
]


def parse_sse(body: str) -> list[tuple[str, dict[str, object]]]:
    normalized = body.replace("\r\n", "\n")
    frames: list[tuple[str, dict[str, object]]] = []
    for raw_frame in normalized.split("\n\n"):
        if not raw_frame:
            continue
        lines = raw_frame.splitlines()
        if len(lines) != 2 or not lines[0].startswith("event: ") or not lines[1].startswith("data: "):
            raise AssertionError(f"Malformed SSE frame: {raw_frame!r}")
        event_name = lines[0][len("event: ") :]
        payload = json.loads(lines[1][len("data: ") :])
        frames.append((event_name, payload))
    return frames


class ResponsesStreamingTests(unittest.TestCase):
    def make_terminal_response(self, text: str) -> dict[str, object]:
        normalized = gateway.normalize_responses_request(
            {
                "model": "qwen3.7-plus",
                "input": "focused Responses SSE unit proof",
                "metadata": {
                    "trace_id": "responses-stream-unit-trace",
                    "agent_type": "tester",
                    "deterministic_dry_run": True,
                    "live_provider_calls_allowed": False,
                },
                "stream": True,
            }
        )
        response = gateway.responses_adapter_payload(
            normalized,
            text,
            False,
            {"prompt_tokens": 5, "completion_tokens": 12, "total_tokens": 17},
            local_call=False,
        )
        response["audit_persisted"] = True
        return response

    def assert_event_contract(self, events: list[dict[str, object]], expected_text: str) -> None:
        event_types = [str(event["type"]) for event in events]
        delta_events = [event for event in events if event["type"] == "response.output_text.delta"]
        self.assertGreaterEqual(len(delta_events), 2)
        self.assertEqual(
            event_types,
            EVENT_PREFIX + (["response.output_text.delta"] * len(delta_events)) + EVENT_SUFFIX,
        )
        self.assertEqual(
            [event["sequence_number"] for event in events],
            list(range(len(events))),
        )

        completed = events[-1]
        completed_response = completed["response"]
        self.assertIsInstance(completed_response, dict)
        output_item = completed_response["output"][0]
        response_id = completed_response["id"]
        item_id = output_item["id"]

        self.assertEqual(events[0]["response"]["id"], response_id)
        self.assertEqual(events[1]["response"]["id"], response_id)
        self.assertEqual(events[2]["item"]["id"], item_id)
        self.assertEqual(events[3]["item_id"], item_id)
        for event in delta_events:
            self.assertEqual(event["item_id"], item_id)
            self.assertEqual(event["output_index"], 0)
            self.assertEqual(event["content_index"], 0)

        text_done = next(event for event in events if event["type"] == "response.output_text.done")
        part_done = next(event for event in events if event["type"] == "response.content_part.done")
        item_done = next(event for event in events if event["type"] == "response.output_item.done")
        reconstructed = "".join(str(event["delta"]) for event in delta_events)
        self.assertEqual(reconstructed, expected_text)
        self.assertEqual(text_done["text"], expected_text)
        self.assertEqual(part_done["part"]["text"], expected_text)
        self.assertEqual(item_done["item"]["content"][0]["text"], expected_text)
        self.assertEqual(completed_response["output_text"], expected_text)
        self.assertEqual(text_done["item_id"], item_id)
        self.assertEqual(part_done["item_id"], item_id)
        self.assertEqual(item_done["item"]["id"], item_id)
        self.assertNotIn("[DONE]", json.dumps(events, separators=(",", ":")))

    def test_helper_emits_exact_responses_native_event_sequence(self) -> None:
        text = "deterministic-response-delta-" * 8
        terminal = self.make_terminal_response(text)

        events = gateway.responses_stream_events(terminal)

        self.assert_event_contract(events, text)
        self.assertEqual(events[0]["response"]["status"], "in_progress")
        self.assertEqual(events[0]["response"]["output"], [])
        self.assertEqual(events[0]["response"]["output_text"], "")
        self.assertEqual(events[2]["item"]["status"], "in_progress")
        self.assertEqual(events[2]["item"]["content"], [])
        self.assertEqual(events[-1]["response"], terminal)

    def test_stream_endpoint_emits_audited_fail_closed_sse(self) -> None:
        trace_id = "responses-stream-endpoint-trace"
        request = {
            "model": "qwen3.7-plus",
            "input": "verify the complete deterministic Responses event stream",
            "metadata": {
                "trace_id": trace_id,
                "agent_type": "tester",
                "deterministic_dry_run": True,
                "live_provider_calls_allowed": False,
            },
            "stream": True,
        }
        with (
            patch.object(gateway, "audit_responses_event", return_value=True) as audit,
            patch.object(gateway, "call_local_chat_completion", side_effect=AssertionError("local model call")),
            patch.object(gateway, "call_hf_chat_completion", side_effect=AssertionError("live provider call")),
            TestClient(gateway.app) as client,
        ):
            response = client.post("/v1/responses", json=request)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"].split(";", 1)[0], "text/event-stream")
        self.assertEqual(response.headers["cache-control"], "no-store")
        self.assertEqual(response.headers["x-accel-buffering"], "no")
        self.assertNotIn("data: [DONE]", response.text)
        audit.assert_called_once()

        frames = parse_sse(response.text)
        self.assertTrue(frames)
        self.assertEqual([name for name, payload in frames], [payload["type"] for name, payload in frames])
        events = [payload for _, payload in frames]
        terminal = events[-1]["response"]
        self.assert_event_contract(events, terminal["output_text"])
        self.assertEqual(terminal["contract_version"], "llm-responses-adapter-contract-v2")
        self.assertEqual(terminal["trace_id"], trace_id)
        self.assertEqual(terminal["provider_name"], "deterministic-dry-run")
        self.assertTrue(terminal["audit_persisted"])
        self.assertFalse(terminal["live_provider_calls"])
        self.assertFalse(terminal["local_model_calls"])
        self.assertFalse(terminal["model_downloads"])
        self.assertFalse(terminal["secret_output"])

    def test_stream_endpoint_refuses_to_emit_when_audit_persistence_fails(self) -> None:
        request = {
            "model": "qwen3.7-plus",
            "input": "do not emit an unaudited Responses stream",
            "metadata": {
                "trace_id": "responses-stream-audit-failure",
                "agent_type": "tester",
                "deterministic_dry_run": True,
                "live_provider_calls_allowed": False,
            },
            "stream": True,
        }
        with (
            patch.object(gateway, "audit_responses_event", return_value=False),
            TestClient(gateway.app) as client,
        ):
            response = client.post("/v1/responses", json=request)

        self.assertEqual(response.status_code, 503, response.text)
        self.assertEqual(response.headers["content-type"].split(";", 1)[0], "application/json")
        self.assertNotIn("response.completed", response.text)
        self.assertNotIn("text/event-stream", response.headers["content-type"])

    def test_non_stream_response_shape_remains_compatible_and_safe(self) -> None:
        request = {
            "model": "qwen3.7-plus",
            "input": "verify non-stream compatibility",
            "metadata": {
                "trace_id": "responses-non-stream-trace",
                "agent_type": "tester",
                "deterministic_dry_run": True,
                "live_provider_calls_allowed": False,
            },
            "stream": False,
        }
        with patch.object(gateway, "audit_responses_event", return_value=True), TestClient(gateway.app) as client:
            response = client.post("/v1/responses", json=request)

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["object"], "response")
        self.assertEqual(payload["status"], "completed")
        self.assertEqual(payload["contract_version"], "llm-responses-adapter-contract-v2")
        self.assertEqual(payload["evidence_ref"], "llm_responses_adapter_contract_visible")
        self.assertEqual(payload["trace_id"], "responses-non-stream-trace")
        self.assertEqual(payload["output_text"], payload["output"][0]["content"][0]["text"])
        self.assertEqual(payload["provider_name"], "deterministic-dry-run")
        self.assertTrue(payload["audit_persisted"])
        self.assertFalse(payload["live_provider_calls"])
        self.assertFalse(payload["local_model_calls"])
        self.assertFalse(payload["model_downloads"])
        self.assertFalse(payload["secret_output"])

    def test_stream_validation_is_bounded_and_fail_closed(self) -> None:
        base = {
            "model": "qwen3.7-plus",
            "input": "bounded validation",
            "metadata": {
                "trace_id": "responses-stream-validation",
                "agent_type": "tester",
                "deterministic_dry_run": True,
                "live_provider_calls_allowed": False,
            },
            "stream": True,
        }
        invalid_cases = [
            ("metadata type", {**base, "metadata": "not-an-object"}, 422),
            ("stream type", {**base, "stream": "true"}, 422),
            ("empty input", {**base, "input": ""}, 422),
            (
                "oversize input",
                {**base, "input": "x" * (gateway.MAX_RESPONSES_INPUT_CHARS + 1)},
                422,
            ),
            ("zero output tokens", {**base, "max_output_tokens": 0}, 422),
            ("boolean output tokens", {**base, "max_output_tokens": True}, 422),
            (
                "oversize output tokens",
                {**base, "max_output_tokens": gateway.MAX_RESPONSES_OUTPUT_TOKENS + 1},
                422,
            ),
            (
                "live provider stream",
                {
                    **base,
                    "metadata": {
                        **base["metadata"],
                        "live_provider_calls_allowed": True,
                    },
                },
                403,
            ),
        ]
        with TestClient(gateway.app) as client:
            for label, payload, expected_status in invalid_cases:
                with self.subTest(label=label):
                    response = client.post("/v1/responses", json=payload)
                    self.assertEqual(response.status_code, expected_status, response.text)

    def test_output_text_limit_is_derived_from_the_gateway_constant(self) -> None:
        with self.assertRaises(gateway.HTTPException) as raised:
            gateway.validate_responses_output_text("x" * (gateway.MAX_RESPONSES_OUTPUT_CHARS + 1))
        self.assertEqual(raised.exception.status_code, 502)
        self.assertIn("character limit", str(raised.exception.detail))

    def test_instructions_and_previous_response_are_applied_to_gateway_messages(self) -> None:
        gateway.clear_responses_context_store()
        previous_id = "resp_dryrun_11111111-1111-4111-8111-111111111111"
        gateway.store_responses_context(
            previous_id,
            [
                gateway.ChatMessage(role="user", content="first bounded question"),
                gateway.ChatMessage(role="assistant", content="first bounded answer"),
            ],
        )
        normalized = gateway.normalize_responses_request(
            {
                "model": "qwen3.7-plus",
                "instructions": "Trusted role and safety instructions.",
                "input": "follow-up question",
                "previous_response_id": previous_id,
                "metadata": {"trace_id": "responses-context-unit", "agent_type": "tester"},
            }
        )

        messages = gateway.responses_input_to_messages(normalized)

        self.assertEqual(
            [(message.role, message.content) for message in messages],
            [
                ("system", "Trusted role and safety instructions."),
                ("user", "first bounded question"),
                ("assistant", "first bounded answer"),
                ("user", "follow-up question"),
            ],
        )

    def test_unknown_previous_response_id_is_rejected(self) -> None:
        gateway.clear_responses_context_store()
        normalized = gateway.normalize_responses_request(
            {
                "model": "qwen3.7-plus",
                "input": "follow-up question",
                "previous_response_id": "resp_dryrun_22222222-2222-4222-8222-222222222222",
                "metadata": {"trace_id": "responses-context-miss", "agent_type": "tester"},
            }
        )

        with self.assertRaises(gateway.HTTPException) as raised:
            gateway.responses_input_to_messages(normalized)

        self.assertEqual(raised.exception.status_code, 404)

    def test_instruction_and_previous_response_validation_is_bounded(self) -> None:
        base = {
            "model": "qwen3.7-plus",
            "input": "bounded controls",
            "metadata": {"trace_id": "responses-control-bounds", "agent_type": "tester"},
        }
        invalid_cases = [
            ({**base, "instructions": 42}, "instructions must be a string"),
            (
                {**base, "instructions": "x" * (gateway.MAX_RESPONSES_INSTRUCTIONS_CHARS + 1)},
                "instructions exceeds",
            ),
            ({**base, "previous_response_id": 42}, "previous_response_id must be a string"),
            ({**base, "previous_response_id": "not-a-response-id"}, "previous_response_id format"),
        ]
        for payload, expected_detail in invalid_cases:
            with self.subTest(expected_detail=expected_detail):
                with self.assertRaises(gateway.HTTPException) as raised:
                    gateway.normalize_responses_request(payload)
                self.assertEqual(raised.exception.status_code, 422)
                self.assertIn(expected_detail, str(raised.exception.detail))


if __name__ == "__main__":
    unittest.main()
