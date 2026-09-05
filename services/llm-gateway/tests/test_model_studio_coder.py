from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx


MODULE_PATH = Path(__file__).resolve().parents[1] / "app" / "main.py"
SPEC = importlib.util.spec_from_file_location("superbrain_llm_gateway_model_studio", MODULE_PATH)
if SPEC is None or SPEC.loader is None:  # pragma: no cover - import bootstrap guard
    raise RuntimeError(f"Unable to load LLM Gateway module from {MODULE_PATH}")
gateway = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gateway
SPEC.loader.exec_module(gateway)


MODEL_STUDIO_ENDPOINT = (
    "https://ws-unit-test.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1"
)
CODER_MODEL = "qwen3.7-plus"


def coder_request(*, live_allowed: bool = True) -> object:
    return gateway.ChatCompletionRequest(
        model=CODER_MODEL,
        messages=[gateway.ChatMessage(role="user", content="Implement one bounded coder task.")],
        max_tokens=128,
        metadata={
            "agent_type": "coder",
            "live_provider_calls_allowed": live_allowed,
        },
    )


def tool_request() -> object:
    return gateway.ChatCompletionRequest(
        model=CODER_MODEL,
        messages=[
            gateway.ChatMessage(role="user", content="Read the bounded project file."),
            gateway.ChatMessage(
                role="assistant",
                content=None,
                tool_calls=[
                    {
                        "id": "call_previous",
                        "type": "function",
                        "function": {"name": "read_file", "arguments": '{"path":"PROJECT_STATE.md"}'},
                    }
                ],
            ),
            gateway.ChatMessage(role="tool", content="bounded result", tool_call_id="call_previous"),
        ],
        tools=[
            {
                "type": "function",
                "function": {
                    "name": "read_file",
                    "description": "Read one approved project file.",
                    "parameters": {
                        "type": "object",
                        "properties": {"path": {"type": "string"}},
                        "required": ["path"],
                    },
                },
            }
        ],
        tool_choice="auto",
        parallel_tool_calls=False,
        max_tokens=128,
        metadata={"agent_type": "coder", "live_provider_calls_allowed": True},
    )


class ModelStudioCoderContractTests(unittest.TestCase):
    def test_qwen_37_is_the_coder_primary_and_resolves_to_model_studio(self) -> None:
        coder_route = next(route for route in gateway.MODEL_ROUTES if route["agent_type"] == "coder")
        self.assertEqual(coder_route["primary"], CODER_MODEL)

        with (
            patch.object(gateway, "GATEWAY_MODE", "alibaba_model_studio_live"),
            patch.object(gateway, "model_studio_api_key", return_value=None),
        ):
            resolved = gateway.resolve_route(
                gateway.RoutingResolveRequest(agent_type="coder", task_type="code")
            )

        self.assertEqual(resolved["selected_model"], CODER_MODEL)
        self.assertEqual(resolved["selected_provider"], "alibaba_model_studio")
        self.assertEqual(resolved["provider_chain"][0], "alibaba_model_studio")
        self.assertFalse(resolved["live_provider_calls"])

    def test_model_studio_capability_is_fail_closed_without_key(self) -> None:
        with (
            patch.object(gateway, "MODEL_STUDIO_BASE_URL", MODEL_STUDIO_ENDPOINT),
            patch.object(gateway, "model_studio_api_key", return_value=None),
        ):
            snapshot = gateway.model_studio_capability_snapshot()

        self.assertEqual(snapshot["provider"], "alibaba_model_studio")
        self.assertEqual(snapshot["base_url"], MODEL_STUDIO_ENDPOINT)
        self.assertEqual(snapshot["model"], CODER_MODEL)
        self.assertEqual(snapshot["auth_env"], "DASHSCOPE_API_KEY")
        self.assertFalse(snapshot["api_key_configured"])
        self.assertFalse(snapshot["live_provider_calls"])
        self.assertFalse(snapshot["secret_output"])
        self.assertNotIn("api_key", snapshot)

    def test_gateway_forwards_the_approved_coder_request_to_model_studio(self) -> None:
        calls: list[dict[str, object]] = []
        upstream_request = httpx.Request("POST", f"{MODEL_STUDIO_ENDPOINT}/chat/completions")
        upstream_response = httpx.Response(
            200,
            request=upstream_request,
            json={
                "id": "chatcmpl-unit",
                "object": "chat.completion",
                "model": CODER_MODEL,
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": "bounded coder result"},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {"prompt_tokens": 7, "completion_tokens": 3, "total_tokens": 10},
            },
        )

        class FakeClient:
            def __init__(self, *, timeout: float) -> None:
                self.timeout = timeout

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback) -> None:
                return None

            def post(self, endpoint: str, *, headers, json):
                calls.append({"endpoint": endpoint, "headers": headers, "json": json})
                return upstream_response

        with (
            patch.object(gateway, "MODEL_STUDIO_BASE_URL", MODEL_STUDIO_ENDPOINT),
            patch.object(gateway, "model_studio_api_key", return_value="unit-only-token"),
            patch.object(gateway.httpx, "Client", FakeClient),
        ):
            payload = gateway.call_model_studio_chat_completion(coder_request())

        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["endpoint"], f"{MODEL_STUDIO_ENDPOINT}/chat/completions")
        self.assertEqual(calls[0]["json"]["model"], CODER_MODEL)
        self.assertEqual(calls[0]["headers"]["Authorization"], "Bearer unit-only-token")
        self.assertEqual(payload["choices"][0]["message"]["content"], "bounded coder result")

    def test_live_model_studio_dispatch_stays_inside_the_gateway(self) -> None:
        upstream_payload = {
            "id": "chatcmpl-unit-dispatch",
            "object": "chat.completion",
            "model": CODER_MODEL,
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": "gateway dispatched result"},
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 5, "completion_tokens": 3, "total_tokens": 8},
        }
        with (
            patch.object(gateway, "GATEWAY_MODE", "alibaba_model_studio_live"),
            patch.object(gateway, "LLM_LIVE_PROVIDER_DEFAULT", True),
            patch.object(gateway, "model_studio_available", return_value=True),
            patch.object(
                gateway,
                "call_model_studio_chat_completion",
                return_value=upstream_payload,
            ) as provider_call,
            patch.object(gateway, "audit_event", return_value=True),
        ):
            response = gateway.chat_completions(coder_request())

        provider_call.assert_called_once()
        self.assertEqual(response["provider_name"], "alibaba_model_studio")
        self.assertEqual(response["requested_model"], CODER_MODEL)
        self.assertTrue(response["live_provider_calls"])
        self.assertTrue(response["audit_persisted"])
        self.assertFalse(response["secret_output"])

    def test_live_request_without_dedicated_key_fails_before_network(self) -> None:
        with (
            patch.object(gateway, "GATEWAY_MODE", "alibaba_model_studio_live"),
            patch.object(gateway, "LLM_LIVE_PROVIDER_DEFAULT", True),
            patch.object(gateway, "model_studio_available", return_value=False),
            patch.object(gateway, "call_model_studio_chat_completion") as provider_call,
            self.assertRaises(gateway.HTTPException) as raised,
        ):
            gateway.chat_completions(coder_request())

        provider_call.assert_not_called()
        self.assertEqual(raised.exception.status_code, 503)
        self.assertNotIn(MODEL_STUDIO_ENDPOINT, str(raised.exception.detail))

    def test_client_metadata_cannot_override_the_owner_live_gate(self) -> None:
        with (
            patch.object(gateway, "GATEWAY_MODE", "alibaba_model_studio_live"),
            patch.object(gateway, "LLM_LIVE_PROVIDER_DEFAULT", False),
            patch.object(gateway, "model_studio_available", return_value=True),
            patch.object(gateway, "call_model_studio_chat_completion") as provider_call,
            self.assertRaises(gateway.HTTPException) as raised,
        ):
            gateway.chat_completions(coder_request())

        provider_call.assert_not_called()
        self.assertEqual(raised.exception.status_code, 403)

    def test_model_studio_request_is_bounded(self) -> None:
        with self.assertRaises(Exception):
            gateway.ChatCompletionRequest(
                model=CODER_MODEL,
                messages=[gateway.ChatMessage(role="user", content="bounded")],
                max_tokens=8193,
            )

    def test_live_call_requires_a_persisted_preflight_audit(self) -> None:
        with (
            patch.object(gateway, "GATEWAY_MODE", "alibaba_model_studio_live"),
            patch.object(gateway, "LLM_LIVE_PROVIDER_DEFAULT", True),
            patch.object(gateway, "model_studio_available", return_value=True),
            patch.object(gateway, "audit_event", return_value=False) as audit,
            patch.object(gateway, "call_model_studio_chat_completion") as provider_call,
            self.assertRaises(gateway.HTTPException) as raised,
        ):
            gateway.chat_completions(coder_request())

        audit.assert_called_once()
        provider_call.assert_not_called()
        self.assertEqual(raised.exception.status_code, 503)

    def test_live_call_fails_closed_when_completion_audit_is_not_persisted(self) -> None:
        upstream_payload = {
            "id": "chatcmpl-unit-audit",
            "object": "chat.completion",
            "model": CODER_MODEL,
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": "audited result"},
                    "finish_reason": "stop",
                }
            ],
            "usage": {"prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7},
        }
        with (
            patch.object(gateway, "GATEWAY_MODE", "alibaba_model_studio_live"),
            patch.object(gateway, "LLM_LIVE_PROVIDER_DEFAULT", True),
            patch.object(gateway, "model_studio_available", return_value=True),
            patch.object(gateway, "audit_event", side_effect=[True, False]) as audit,
            patch.object(gateway, "call_model_studio_chat_completion", return_value=upstream_payload),
            self.assertRaises(gateway.HTTPException) as raised,
        ):
            gateway.chat_completions(coder_request())

        self.assertEqual(audit.call_count, 2)
        self.assertEqual(raised.exception.status_code, 503)

    def test_tool_calling_fields_round_trip_through_the_openai_boundary(self) -> None:
        calls: list[dict[str, object]] = []
        upstream_request = httpx.Request("POST", f"{MODEL_STUDIO_ENDPOINT}/chat/completions")
        upstream_response = httpx.Response(
            200,
            request=upstream_request,
            json={
                "id": "chatcmpl-unit-tools",
                "object": "chat.completion",
                "model": CODER_MODEL,
                "choices": [
                    {
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": None,
                            "tool_calls": [
                                {
                                    "id": "call_next",
                                    "type": "function",
                                    "function": {
                                        "name": "read_file",
                                        "arguments": '{"path":"PROJECT_STATE.md"}',
                                    },
                                }
                            ],
                        },
                        "finish_reason": "tool_calls",
                    }
                ],
                "usage": {"prompt_tokens": 10, "completion_tokens": 4, "total_tokens": 14},
            },
        )

        class FakeClient:
            def __init__(self, *, timeout: float) -> None:
                self.timeout = timeout

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback) -> None:
                return None

            def post(self, endpoint: str, *, headers, json):
                calls.append({"endpoint": endpoint, "headers": headers, "json": json})
                return upstream_response

        with (
            patch.object(gateway, "MODEL_STUDIO_BASE_URL", MODEL_STUDIO_ENDPOINT),
            patch.object(gateway, "model_studio_api_key", return_value="unit-only-token"),
            patch.object(gateway.httpx, "Client", FakeClient),
        ):
            payload = gateway.call_model_studio_chat_completion(tool_request())

        forwarded = calls[0]["json"]
        self.assertEqual(forwarded["tools"][0]["function"]["name"], "read_file")
        self.assertEqual(forwarded["tool_choice"], "auto")
        self.assertFalse(forwarded["parallel_tool_calls"])
        self.assertEqual(forwarded["messages"][1]["tool_calls"][0]["id"], "call_previous")
        self.assertEqual(forwarded["messages"][2]["tool_call_id"], "call_previous")
        self.assertEqual(payload["choices"][0]["finish_reason"], "tool_calls")

    def test_model_studio_route_never_inherits_hf_live_verification(self) -> None:
        fake_router = {
            "status": "verified",
            "live_verified": True,
            "model_count_visible": 1,
            "models": ["unrelated-hf-model"],
        }
        with (
            patch.object(gateway, "model_studio_available", return_value=True),
            patch.object(gateway, "provider_router_snapshot_for_gateway_mode", return_value=fake_router),
        ):
            resolved = gateway.resolve_route(
                gateway.RoutingResolveRequest(agent_type="coder", task_type="code")
            )

        self.assertFalse(resolved["live_verified"])
        self.assertFalse(resolved["provider_health"]["live_verified"])

    def test_direct_endpoint_in_an_agent_policy_request_is_still_denied(self) -> None:
        decision = gateway.evaluate_routing_policy(
            gateway.RoutingPolicyRequest(
                run_id="run-model-studio-policy",
                agent_slot="coder",
                model_slot="coder_primary",
                task_class="code",
                sensitivity="internal",
                max_output_tokens=8192,
                retry_index=0,
                fallback_index=0,
                trace_correlation_id="trace-model-studio-policy",
                direct_provider_url=MODEL_STUDIO_ENDPOINT,
                direct_provider_key_ref="DASHSCOPE_API_KEY",
            )
        )

        self.assertEqual(decision["decision"], "deny_direct_provider")
        self.assertEqual(decision["evidence_ref"], "llm_routing_policy_direct_provider_blocked")
        self.assertTrue(decision["policy_snapshot"]["direct_provider_bypass_blocked"])


if __name__ == "__main__":
    unittest.main()
