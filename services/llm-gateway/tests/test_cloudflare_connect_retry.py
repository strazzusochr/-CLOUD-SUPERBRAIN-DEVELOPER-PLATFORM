from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx


MODULE_PATH = Path(__file__).resolve().parents[1] / "app" / "main.py"
SPEC = importlib.util.spec_from_file_location("superbrain_llm_gateway_cloudflare_retry", MODULE_PATH)
if SPEC is None or SPEC.loader is None:  # pragma: no cover - import bootstrap guard
    raise RuntimeError(f"Unable to load LLM Gateway module from {MODULE_PATH}")
gateway = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gateway
SPEC.loader.exec_module(gateway)


def request_payload():
    return gateway.ChatCompletionRequest(
        model="@cf/qwen/qwen2.5-coder-32b-instruct",
        messages=[gateway.ChatMessage(role="user", content="bounded connect retry proof")],
        max_tokens=32,
    )


class CloudflareConnectRetryTests(unittest.TestCase):
    def test_connect_failure_retries_once_and_returns_the_verified_payload(self) -> None:
        calls: list[str] = []
        upstream_request = httpx.Request("POST", "https://provider.invalid/ai/run/model")
        upstream_response = httpx.Response(
            200,
            request=upstream_request,
            json={
                "result": {
                    "response": "verified retry result",
                    "usage": {"prompt_tokens": 4, "completion_tokens": 3},
                }
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
                calls.append(endpoint)
                if len(calls) == 1:
                    raise httpx.ConnectError("transient connect failure", request=upstream_request)
                return upstream_response

        with (
            patch.object(gateway, "cloudflare_workers_ai_token", return_value="unit-token"),
            patch.object(gateway, "cloudflare_workers_ai_account_id", return_value="unit-account"),
            patch.object(gateway.httpx, "Client", FakeClient),
        ):
            payload = gateway.call_cloudflare_workers_ai_chat_completion(request_payload())

        self.assertEqual(len(calls), 2)
        self.assertEqual(payload["choices"][0]["message"]["content"], "verified retry result")
        self.assertEqual(payload["usage"]["total_tokens"], 7)

    def test_http_status_rejection_is_not_retried(self) -> None:
        calls: list[str] = []
        upstream_request = httpx.Request("POST", "https://provider.invalid/ai/run/model")
        upstream_response = httpx.Response(429, request=upstream_request, text="rate limited")

        class FakeClient:
            def __init__(self, *, timeout: float) -> None:
                self.timeout = timeout

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback) -> None:
                return None

            def post(self, endpoint: str, *, headers, json):
                calls.append(endpoint)
                return upstream_response

        with (
            patch.object(gateway, "cloudflare_workers_ai_token", return_value="unit-token"),
            patch.object(gateway, "cloudflare_workers_ai_account_id", return_value="unit-account"),
            patch.object(gateway.httpx, "Client", FakeClient),
            self.assertRaises(gateway.HTTPException) as raised,
        ):
            gateway.call_cloudflare_workers_ai_chat_completion(request_payload())

        self.assertEqual(len(calls), 1)
        self.assertEqual(raised.exception.status_code, 429)


if __name__ == "__main__":
    unittest.main()
