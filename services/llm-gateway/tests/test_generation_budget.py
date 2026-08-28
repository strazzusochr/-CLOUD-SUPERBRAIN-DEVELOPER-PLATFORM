"""Generation-budget guard for the workbench build path.

Measured 2026-08-28 against the live dev stack: every one of the 40 persisted build
artifacts was small — largest 6867 bytes / 191 lines, median 2967 bytes — while the
persistence boundary allows 160 KB. The cause was not the model. The build route asks
for 5200 completion tokens, but the gateway clamped the request with

    min(request.max_tokens or CF_WORKERS_AI_MAX_TOKENS, CF_WORKERS_AI_MAX_TOKENS)

against a default of 2048, and `CF_WORKERS_AI_MAX_TOKENS` was unset in the running
container. The caller's budget was cut roughly 60% with no error and no log line, so a
richer app could never be emitted whole — and an incomplete document is rejected
outright by the persistence boundary, which is why only small apps ever shipped.

These tests bind that exact failure: an honoured caller budget, a ceiling large enough
for a real 3D application, and a deployment that states the ceiling explicitly instead
of inheriting a silent default.
"""

from __future__ import annotations

import importlib.util
import re
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx


REPO_ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = Path(__file__).resolve().parents[1] / "app" / "main.py"
SPEC = importlib.util.spec_from_file_location("superbrain_llm_gateway_generation_budget", MODULE_PATH)
if SPEC is None or SPEC.loader is None:  # pragma: no cover - import bootstrap guard
    raise RuntimeError(f"Unable to load LLM Gateway module from {MODULE_PATH}")
gateway = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = gateway
SPEC.loader.exec_module(gateway)

# A single-file 3D game with geometry, materials, lighting, input handling and a game
# loop does not fit in 2048 completion tokens. This floor is what "a real app, whole"
# costs; it is deliberately below the route's request so the route stays authoritative.
MINIMUM_VIABLE_APP_TOKENS = 4096


def build_request(max_tokens: int | None):
    return gateway.ChatCompletionRequest(
        model="@cf/qwen/qwen2.5-coder-32b-instruct",
        messages=[gateway.ChatMessage(role="user", content="generation budget proof")],
        max_tokens=max_tokens,
    )


def capture_upstream_payload(request):
    """Runs one gateway call against a stub and returns the payload sent upstream."""
    sent: list[dict] = []
    upstream_request = httpx.Request("POST", "https://provider.invalid/ai/run/model")
    upstream_response = httpx.Response(
        200,
        request=upstream_request,
        json={"result": {"response": "ok", "usage": {"prompt_tokens": 1, "completion_tokens": 1}}},
    )

    class FakeClient:
        def __init__(self, *, timeout: float) -> None:
            self.timeout = timeout

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback) -> None:
            return None

        def post(self, endpoint: str, *, headers, json):
            sent.append(json)
            return upstream_response

    with (
        patch.object(gateway, "cloudflare_workers_ai_token", return_value="unit-token"),
        patch.object(gateway, "cloudflare_workers_ai_account_id", return_value="unit-account"),
        patch.object(gateway.httpx, "Client", FakeClient),
    ):
        gateway.call_cloudflare_workers_ai_chat_completion(request)

    return sent[0]


class GenerationBudgetTests(unittest.TestCase):
    def test_default_ceiling_can_hold_a_complete_single_file_app(self) -> None:
        self.assertGreaterEqual(
            gateway.CF_WORKERS_AI_MAX_TOKENS,
            MINIMUM_VIABLE_APP_TOKENS,
            "the default ceiling truncates any app larger than a toy",
        )

    def test_the_build_routes_requested_budget_is_not_silently_reduced(self) -> None:
        # The build route asks for this exact value; see apps/frontend/app/api/v1/build/route.ts.
        route_source = (REPO_ROOT / "apps/frontend/app/api/v1/build/route.ts").read_text(encoding="utf-8")
        match = re.search(r"max_tokens:\s*(\d+)", route_source)
        self.assertIsNotNone(match, "the build route must declare an explicit max_tokens")
        route_budget = int(match.group(1))

        payload = capture_upstream_payload(build_request(route_budget))
        self.assertEqual(
            payload["max_tokens"],
            route_budget,
            "the caller's budget reached the provider reduced, so long documents get cut mid-tag",
        )

    def test_a_caller_asking_for_less_still_gets_exactly_what_it_asked_for(self) -> None:
        payload = capture_upstream_payload(build_request(256))
        self.assertEqual(payload["max_tokens"], 256)

    def test_an_absent_caller_budget_falls_back_to_the_configured_ceiling(self) -> None:
        payload = capture_upstream_payload(build_request(None))
        self.assertEqual(payload["max_tokens"], gateway.CF_WORKERS_AI_MAX_TOKENS)

    def test_the_dev_deployment_states_the_ceiling_instead_of_inheriting_it(self) -> None:
        # An unset variable in the container is how the 2048 default became the real,
        # invisible limit. The deployment must name the value it runs with.
        compose = (REPO_ROOT / "docker-compose.dev.yml").read_text(encoding="utf-8")
        self.assertTrue(
            "CF_WORKERS_AI_MAX_TOKENS" in compose,
            "docker-compose.dev.yml inherits a silent default instead of declaring the ceiling",
        )


if __name__ == "__main__":
    unittest.main()
