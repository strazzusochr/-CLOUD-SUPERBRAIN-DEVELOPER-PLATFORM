from __future__ import annotations

import hashlib
import os
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

from app import main


TEST_AGENT_TOKEN = "unit-agent-token"


class FakeResult:
    def __init__(self, *, row: tuple[object, ...] | None = None, rows: list[tuple[object, ...]] | None = None) -> None:
        self.row = row
        self.rows = rows or []

    def fetchone(self) -> tuple[object, ...] | None:
        return self.row

    def fetchall(self) -> list[tuple[object, ...]]:
        return list(self.rows)


class FakeConnection:
    def __init__(self, *, fail_audit: bool = False) -> None:
        self.builds: dict[str, tuple[object, ...]] = {}
        self.audit_events: list[object] = []
        self.fail_audit = fail_audit
        self._snapshot: tuple[dict[str, tuple[object, ...]], list[object]] | None = None

    def __enter__(self) -> "FakeConnection":
        self._snapshot = (dict(self.builds), list(self.audit_events))
        return self

    def __exit__(self, exc_type: object, _exc: object, _traceback: object) -> None:
        if exc_type is not None and self._snapshot is not None:
            self.builds, self.audit_events = self._snapshot
        self._snapshot = None

    def execute(self, sql: str, params: tuple[object, ...]) -> FakeResult:
        normalized = " ".join(sql.split())
        if normalized.startswith("INSERT INTO builds"):
            (
                build_id,
                project_id,
                title,
                prompt_sha256,
                model,
                html,
                gateway_mode,
                gateway_provider,
                live_provider_calls,
            ) = params
            if str(build_id) in self.builds:
                return FakeResult()
            now = datetime(2026, 7, 25, tzinfo=timezone.utc)
            row = (
                build_id,
                project_id,
                title,
                prompt_sha256,
                model,
                html,
                gateway_mode,
                gateway_provider,
                live_provider_calls,
                now,
                now,
            )
            self.builds[str(build_id)] = row
            return FakeResult(row=row)
        if normalized.startswith("INSERT INTO audit_log"):
            if self.fail_audit:
                raise RuntimeError("private database audit failure")
            self.audit_events.append(params[0])
            return FakeResult(row=("audit-id",))
        if "FROM builds WHERE project_id = %s" in normalized:
            project_id, limit = params
            rows = [row for row in self.builds.values() if row[1] == project_id][: int(limit)]
            return FakeResult(rows=rows)
        if "FROM builds WHERE id = %s" in normalized:
            return FakeResult(row=self.builds.get(str(params[0])))
        raise AssertionError(f"Unhandled SQL in build registry fake: {normalized}")


def valid_request(**overrides: object) -> main.BuildRegistryRequest:
    values: dict[str, object] = {
        "id": "build_unit_1",
        "project_id": "default",
        "title": "Unit Build",
        "prompt": "Create a bounded unit build",
        "model": "unit-model",
        "html": "<!doctype html><html><body><h1>Unit Build</h1></body></html>",
        "gateway_mode": "dry_run",
        "gateway_provider": "unit",
        "live_provider_calls": False,
    }
    values.update(overrides)
    return main.BuildRegistryRequest(**values)


class BuildRegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.connection = FakeConnection()
        self.http_request = SimpleNamespace(state=SimpleNamespace(trace_id="trace-build-unit"))

    def create(self, request: main.BuildRegistryRequest | None = None) -> dict[str, object]:
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            return main.create_build_registry_entry(
                request or valid_request(),
                self.http_request,
                TEST_AGENT_TOKEN,
            )

    def test_create_requires_configured_matching_agent_token(self) -> None:
        request = valid_request()
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(HTTPException) as unconfigured:
                main.create_build_registry_entry(request, self.http_request, TEST_AGENT_TOKEN)
        self.assertEqual(unconfigured.exception.status_code, 503)

        with patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}):
            with self.assertRaises(HTTPException) as unauthorized:
                main.create_build_registry_entry(request, self.http_request, "wrong-token")
        self.assertEqual(unauthorized.exception.status_code, 401)
        self.assertEqual(self.connection.builds, {})

    def test_create_persists_hash_only_with_atomic_audit_and_safe_flags(self) -> None:
        request = valid_request()
        result = self.create(request)

        self.assertEqual(result["id"], request.id)
        self.assertEqual(result["html"], request.html)
        self.assertEqual(result["share_path"], f"/run/{request.id}")
        self.assertTrue(result["persisted"])
        self.assertTrue(result["audit_persisted"])
        self.assertFalse(result["direct_provider_calls"])
        self.assertFalse(result["live_mcp_writes"])
        self.assertFalse(result["secret_output"])
        self.assertNotIn("prompt", result)
        self.assertEqual(result["prompt_sha256"], hashlib.sha256(request.prompt.encode()).hexdigest())
        self.assertEqual(len(self.connection.builds), 1)
        self.assertEqual(len(self.connection.audit_events), 1)
        persisted_row = self.connection.builds[request.id]
        self.assertNotIn(request.prompt, persisted_row)

    def test_list_omits_html_and_readback_returns_html(self) -> None:
        created = self.create()
        with (
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            listed = main.list_build_registry_entries(project_id="default", limit=24)
            readback = main.get_build_registry_entry("build_unit_1")

        self.assertEqual(listed["count"], 1)
        self.assertTrue(listed["persisted"])
        self.assertTrue(listed["audit_persisted"])
        self.assertNotIn("html", listed["builds"][0])
        self.assertEqual(readback["html"], created["html"])
        self.assertTrue(readback["persisted"])
        self.assertTrue(readback["audit_persisted"])
        self.assertFalse(readback["direct_provider_calls"])
        self.assertFalse(readback["live_mcp_writes"])
        self.assertFalse(readback["secret_output"])

    def test_secret_material_is_rejected_before_database_access_without_echo(self) -> None:
        fixture_secret = "sk-" + ("unitfixture" * 3)
        request = valid_request(prompt=f"Do not store {fixture_secret}")
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main.psycopg, "connect") as connect,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_build_registry_entry(request, self.http_request, TEST_AGENT_TOKEN)

        self.assertEqual(raised.exception.status_code, 400)
        self.assertNotIn(fixture_secret, str(raised.exception.detail))
        connect.assert_not_called()

    def test_known_dead_three_addons_are_rejected_before_database_access(self) -> None:
        request = valid_request(
            html=(
                '<!doctype html><html><body><script '
                'src="https://unpkg.com/three@0.160.0/examples/js/postprocessing/EffectComposer.js">'
                '</script></body></html>'
            )
        )
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main.psycopg, "connect") as connect,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_build_registry_entry(request, self.http_request, TEST_AGENT_TOKEN)

        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(raised.exception.detail, "unrunnable build html")
        connect.assert_not_called()

        module_request = valid_request(
            html=(
                '<!doctype html><html><body><script type=module '
                'src=https://unpkg.com/three@0.160.0/examples/jsm/postprocessing/EffectComposer.js>'
                '</script></body></html>'
            )
        )
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main.psycopg, "connect") as module_connect,
        ):
            with self.assertRaises(HTTPException) as module_raised:
                main.create_build_registry_entry(module_request, self.http_request, TEST_AGENT_TOKEN)

        self.assertEqual(module_raised.exception.status_code, 400)
        self.assertEqual(module_raised.exception.detail, "unrunnable build html")
        module_connect.assert_not_called()

    def test_module_addon_and_commented_legacy_reference_remain_allowed(self) -> None:
        request = valid_request(
            html=(
                '<!doctype html><html><body>'
                '<!-- <script src="https://unpkg.com/three/examples/js/controls/OrbitControls.js"></script> -->'
                '<script type=importmap>{"imports":{"three":"https://unpkg.com/three@0.160.0/build/three.module.js"}}</script>'
                '<script type=module src=https://unpkg.com/three@0.160.0/examples/jsm/controls/OrbitControls.js></script>'
                '</body></html>'
            )
        )
        result = self.create(request)
        self.assertEqual(result["html"], request.html)
        self.assertTrue(result["persisted"])

    def test_audit_failure_rolls_back_build_and_returns_no_internal_error(self) -> None:
        sentinel = "postgresql://private-user:private-password@db.internal/superbrain"
        self.connection = FakeConnection(fail_audit=True)
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_build_registry_entry(valid_request(), self.http_request, TEST_AGENT_TOKEN)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "build persistence failed")
        self.assertNotIn(sentinel, str(raised.exception.detail))
        self.assertEqual(self.connection.builds, {})
        self.assertEqual(self.connection.audit_events, [])

    def test_duplicate_id_conflict_preserves_original_and_does_not_duplicate_audit(self) -> None:
        original = self.create()
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_build_registry_entry(
                    valid_request(prompt="Different replay content"),
                    self.http_request,
                    TEST_AGENT_TOKEN,
                )

        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(len(self.connection.builds), 1)
        self.assertEqual(len(self.connection.audit_events), 1)
        with (
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            readback = main.get_build_registry_entry("build_unit_1")
        self.assertEqual(readback["prompt_sha256"], original["prompt_sha256"])


if __name__ == "__main__":
    unittest.main()
