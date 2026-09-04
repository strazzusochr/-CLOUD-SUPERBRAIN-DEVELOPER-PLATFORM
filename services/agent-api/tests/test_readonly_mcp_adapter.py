from __future__ import annotations

import os
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch
from uuid import UUID

import httpx
from fastapi import HTTPException
from pydantic import ValidationError

from app import main


TOKEN = "unit-service-token"
QUERY = "canonical-project-progress"
PRE_AUDIT = "11111111-1111-4111-8111-111111111111"
POST_AUDIT = "22222222-2222-4222-8222-222222222222"
AGENT_AUDIT = "33333333-3333-4333-8333-333333333333"


def mcp_payload() -> dict[str, object]:
    return {
        "contract_version": "filesystem-project-progress-read-v1",
        "status": "success",
        "evidence_ref": "filesystem_project_progress_read_verified",
        "trace_id": "trace-filesystem-unit",
        "overall_percent": 89,
        "horizontal": [{"id": f"phase_{index}", "percent": 100 if index < 3 else 50} for index in range(7)],
        "vertical": [{"id": f"layer_{index}", "percent": 100 if index < 4 else 56} for index in range(1, 8)],
        "last_verified": "2026-08-03",
        "source_sha256": "a" * 64,
        "bytes_read": 4096,
        "filesystem_read_performed": True,
        "audit_before_read": True,
        "audit_after_read": True,
        "authorization_audit_event_id": PRE_AUDIT,
        "completion_audit_event_id": POST_AUDIT,
        "live_mcp_writes": False,
        "live_provider_calls": False,
        "direct_provider_calls": False,
        "production_deploy": False,
        "secret_output": False,
        "DEV_ONLY": True,
    }


class FakeResult:
    def __init__(self, *, row=None, rows=None) -> None:
        self.row = row
        self.rows = rows or []

    def fetchone(self):
        return self.row

    def fetchall(self):
        return list(self.rows)


class FakeConnection:
    def __init__(self, *, trace_id: str = "trace-filesystem-unit", identity_mismatch: bool = False) -> None:
        self.trace_id = trace_id
        self.identity_mismatch = identity_mismatch

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def execute(self, sql: str, _params: tuple[object, ...]):
        normalized = " ".join(sql.split())
        now = datetime(2026, 8, 7, tzinfo=timezone.utc)
        if normalized.startswith("SELECT id"):
            before_identity = {
                "tool_request_id": "filesystem-progress-request-unit",
                "run_id": "filesystem-progress-run-unit",
                "session_id": "44444444-4444-4444-8444-444444444444",
            }
            after_identity = dict(before_identity)
            if self.identity_mismatch:
                after_identity["tool_request_id"] = "filesystem-progress-request-other"
            return FakeResult(
                rows=[
                    (UUID(PRE_AUDIT), "planner", {**before_identity, "toolset": "filesystem", "capability": "read_project_progress", "audit_tags": ["read_phase:authorized"], "trace_id": self.trace_id}, now),
                    (UUID(POST_AUDIT), "planner", {**after_identity, "toolset": "filesystem", "capability": "read_project_progress", "audit_tags": ["read_phase:completed"], "trace_id": self.trace_id, "content_sha256": "a" * 64}, now),
                ]
            )
        if normalized.startswith("INSERT INTO audit_log"):
            return FakeResult(row=(UUID(AGENT_AUDIT), now))
        raise AssertionError(f"unexpected SQL: {normalized}")


class ReadOnlyMcpAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.env = patch.dict(
            os.environ,
            {
                "AGENT_API_AUTH_TOKEN": TOKEN,
                "DATABASE_URL": "postgresql://unit:unit@localhost:5432/unit",
                "SUPERBRAIN_RUNTIME_MODE": "dev-only",
                "MCP_GATEWAY_URL": "http://mcp-gateway:9000",
            },
            clear=False,
        )
        self.env.start()
        self.addCleanup(self.env.stop)
        self.http_request = SimpleNamespace(state=SimpleNamespace(trace_id="trace-filesystem-unit"))

    def test_contract_adds_only_the_fixed_filesystem_tool(self) -> None:
        contract = main.read_only_tool_execute_contract()
        self.assertIn("filesystem_project_progress", contract["supported_tools"])
        self.assertEqual(contract["filesystem_contract_version"], "filesystem-project-progress-read-v1")
        self.assertFalse(contract["caller_path_allowed"])
        self.assertFalse(contract["hosted_enabled"])
        self.assertFalse(contract["live_mcp_writes"])
        self.assertFalse(contract["direct_provider_calls"])

    def test_request_model_accepts_tool_and_rejects_unknown_tool(self) -> None:
        request = main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query=QUERY)
        self.assertEqual(request.tool_id, "filesystem_project_progress")
        with self.assertRaises(ValidationError):
            main.ReadOnlyToolExecuteRequest(tool_id="filesystem_read_any_path", query=QUERY)

    def test_fixed_tool_executes_mcp_read_and_verifies_both_audits(self) -> None:
        response = httpx.Response(
            200,
            json=mcp_payload(),
            request=httpx.Request("GET", "http://mcp-gateway:9000/internal/v1/filesystem/project-progress"),
        )
        with (
            patch.object(main.httpx, "get", return_value=response) as get,
            patch.object(main.psycopg, "connect", return_value=FakeConnection()),
        ):
            result = main.execute_read_only_tool(
                main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query=QUERY),
                self.http_request,
            )
        self.assertEqual(get.call_count, 1)
        self.assertEqual(get.call_args.args[0], "http://mcp-gateway:9000/internal/v1/filesystem/project-progress")
        self.assertEqual(get.call_args.kwargs["timeout"], 3.0)
        self.assertEqual(
            get.call_args.kwargs["headers"],
            {"x-superbrain-agent-token": TOKEN, "x-trace-id": "trace-filesystem-unit"},
        )
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["tool_id"], "filesystem_project_progress")
        self.assertEqual(result["audit_event_id"], AGENT_AUDIT)
        self.assertTrue(result["audit_persisted"])
        self.assertTrue(result["mcp_audit_readback_verified"])
        self.assertTrue(result["filesystem_read_performed"])
        self.assertEqual(result["result"]["overall_percent"], 89)
        self.assertEqual(result["result"]["bytes_read"], 4096)
        self.assertNotIn("path", result["result"])
        self.assertNotIn("content", result["result"])
        for field in ("live_mcp_writes", "live_provider_calls", "direct_provider_calls", "production_deploy", "secret_output"):
            self.assertFalse(result[field])

    def test_timeout_fails_closed_without_retry(self) -> None:
        request = main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query=QUERY)
        with patch.object(main.httpx, "get", side_effect=httpx.TimeoutException("unit timeout")) as get:
            with self.assertRaises(HTTPException) as caught:
                main.execute_read_only_tool(request, self.http_request)
        self.assertEqual(caught.exception.status_code, 503)
        self.assertEqual(get.call_count, 1)

    def test_mcp_audit_trace_mismatch_withholds_result(self) -> None:
        response = httpx.Response(
            200,
            json=mcp_payload(),
            request=httpx.Request("GET", "http://mcp-gateway:9000/internal/v1/filesystem/project-progress"),
        )
        request = main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query=QUERY)
        with (
            patch.object(main.httpx, "get", return_value=response),
            patch.object(main.psycopg, "connect", return_value=FakeConnection(trace_id="wrong-trace")),
        ):
            with self.assertRaises(HTTPException) as caught:
                main.execute_read_only_tool(request, self.http_request)
        self.assertEqual(caught.exception.status_code, 503)

    def test_mcp_audit_identity_mismatch_withholds_result(self) -> None:
        response = httpx.Response(
            200,
            json=mcp_payload(),
            request=httpx.Request("GET", "http://mcp-gateway:9000/internal/v1/filesystem/project-progress"),
        )
        request = main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query=QUERY)
        with (
            patch.object(main.httpx, "get", return_value=response),
            patch.object(main.psycopg, "connect", return_value=FakeConnection(identity_mismatch=True)),
        ):
            with self.assertRaises(HTTPException) as caught:
                main.execute_read_only_tool(request, self.http_request)
        self.assertEqual(caught.exception.status_code, 503)

    def test_wrong_query_non_dev_missing_token_and_bad_payload_fail_closed(self) -> None:
        request = main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query="../PROJECT_STATE.md")
        with self.assertRaises(HTTPException) as wrong_query:
            main.execute_read_only_tool(request, self.http_request)
        self.assertEqual(wrong_query.exception.status_code, 422)

        valid_request = main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query=QUERY)
        with patch.dict(os.environ, {"SUPERBRAIN_RUNTIME_MODE": "production"}, clear=False):
            with self.assertRaises(HTTPException) as production:
                main.execute_read_only_tool(valid_request, self.http_request)
        self.assertEqual(production.exception.status_code, 403)

        with patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": ""}, clear=False):
            with self.assertRaises(HTTPException) as missing_token:
                main.execute_read_only_tool(valid_request, self.http_request)
        self.assertEqual(missing_token.exception.status_code, 503)

        bad = {**mcp_payload(), "horizontal": [], "secret_output": True}
        response = httpx.Response(200, json=bad, request=httpx.Request("GET", "http://mcp-gateway:9000/internal/v1/filesystem/project-progress"))
        with patch.object(main.httpx, "get", return_value=response):
            with self.assertRaises(HTTPException) as invalid_response:
                main.execute_read_only_tool(valid_request, self.http_request)
        self.assertEqual(invalid_response.exception.status_code, 503)

    def test_oversize_mcp_response_is_withheld(self) -> None:
        response = httpx.Response(
            200,
            content=b"{" + (b"x" * 65_537) + b"}",
            request=httpx.Request("GET", "http://mcp-gateway:9000/internal/v1/filesystem/project-progress"),
        )
        request = main.ReadOnlyToolExecuteRequest(tool_id="filesystem_project_progress", query=QUERY)
        with patch.object(main.httpx, "get", return_value=response):
            with self.assertRaises(HTTPException) as caught:
                main.execute_read_only_tool(request, self.http_request)
        self.assertEqual(caught.exception.status_code, 503)


if __name__ == "__main__":
    unittest.main()
