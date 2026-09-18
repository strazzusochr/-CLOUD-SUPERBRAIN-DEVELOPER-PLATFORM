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
TEST_WORKSPACE_SUBJECT = "github:101"


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
        self.pins: set[tuple[str, str]] = set()
        self.audit_events: list[object] = []
        self.fail_audit = fail_audit
        self._snapshot: tuple[dict[str, tuple[object, ...]], set[tuple[str, str]], list[object]] | None = None

    def __enter__(self) -> "FakeConnection":
        self._snapshot = (dict(self.builds), set(self.pins), list(self.audit_events))
        return self

    def __exit__(self, exc_type: object, _exc: object, _traceback: object) -> None:
        if exc_type is not None and self._snapshot is not None:
            self.builds, self.pins, self.audit_events = self._snapshot
        self._snapshot = None

    def execute(self, sql: str, params: tuple[object, ...]) -> FakeResult:
        normalized = " ".join(sql.split())
        if normalized.startswith("INSERT INTO builds"):
            (
                build_id,
                project_id,
                owner_subject,
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
                owner_subject,
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
        if normalized.startswith("INSERT INTO workspace_build_pins"):
            owner_subject, build_id = params
            self.pins.add((str(owner_subject), str(build_id)))
            return FakeResult()
        if normalized.startswith("DELETE FROM workspace_build_pins"):
            owner_subject, build_id = params
            self.pins.discard((str(owner_subject), str(build_id)))
            return FakeResult()
        if normalized.startswith("DELETE FROM builds WHERE id = %s AND owner_subject = %s"):
            build_id, owner_subject = params
            row = self.builds.get(str(build_id))
            if row and row[2] == owner_subject:
                self.builds.pop(str(build_id), None)
            return FakeResult()
        if normalized.startswith("INSERT INTO audit_log"):
            if self.fail_audit:
                raise RuntimeError("private database audit failure")
            self.audit_events.append(params[0])
            return FakeResult(row=("audit-id",))
        if "FROM builds WHERE project_id = %s" in normalized:
            project_id, limit = params
            rows = [row for row in self.builds.values() if row[1] == project_id][: int(limit)]
            return FakeResult(rows=rows)
        if "FROM workspace_build_pins p JOIN builds b" in normalized:
            owner_subject = str(params[0])
            rows = [
                row for build_id, row in self.builds.items()
                if (owner_subject, build_id) in self.pins and row[2] == owner_subject
            ]
            return FakeResult(rows=rows)
        if "FROM builds b WHERE b.owner_subject = %s" in normalized:
            owner_subject, limit = params
            rows = [
                (*row, (str(owner_subject), str(row[0])) in self.pins)
                for row in self.builds.values()
                if row[2] == owner_subject
            ][: int(limit)]
            return FakeResult(rows=rows)
        if "SELECT id FROM builds WHERE id = %s AND owner_subject = %s" in normalized:
            row = self.builds.get(str(params[0]))
            return FakeResult(row=(row[0],) if row and row[2] == params[1] else None)
        if "FROM builds WHERE id = %s AND owner_subject = %s" in normalized:
            row = self.builds.get(str(params[0]))
            return FakeResult(row=row if row and row[2] == params[1] else None)
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

    def create(
        self,
        request: main.BuildRegistryRequest | None = None,
        owner_subject: str = TEST_WORKSPACE_SUBJECT,
    ) -> dict[str, object]:
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            return main.create_build_registry_entry(
                request or valid_request(),
                self.http_request,
                TEST_AGENT_TOKEN,
                owner_subject,
            )

    def test_create_requires_configured_matching_agent_token(self) -> None:
        request = valid_request()
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(HTTPException) as unconfigured:
                main.create_build_registry_entry(request, self.http_request, TEST_AGENT_TOKEN, TEST_WORKSPACE_SUBJECT)
        self.assertEqual(unconfigured.exception.status_code, 503)

        with patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}):
            with self.assertRaises(HTTPException) as unauthorized:
                main.create_build_registry_entry(request, self.http_request, "wrong-token", TEST_WORKSPACE_SUBJECT)
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

    def test_workspace_scope_returns_only_the_server_bound_github_owner_and_keeps_pins_separate(self) -> None:
        """A personal Home list may never fall back to the shared default project.

        The workspace subject is deliberately a trusted service header rather
        than a request-body field: this test proves both owner separation and
        that a pin is a workspace record, not a marketplace-style favourite.
        """
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            main.create_build_registry_entry(
                valid_request(id="build_alice", title="Alice workspace"),
                self.http_request,
                TEST_AGENT_TOKEN,
                "github:101",
            )
            main.create_build_registry_entry(
                valid_request(id="build_bob", title="Bob workspace"),
                self.http_request,
                TEST_AGENT_TOKEN,
                "github:202",
            )
            main.set_workspace_build_pin("build_alice", "github:101", TEST_AGENT_TOKEN)
            mine = main.list_workspace_build_registry_entries("github:101", 4, TEST_AGENT_TOKEN)
            foreign = main.get_workspace_build_registry_entry("build_bob", "github:101", TEST_AGENT_TOKEN)
            foreign_delete = main.delete_workspace_build_registry_entry("build_bob", "github:101", TEST_AGENT_TOKEN)
            own_delete = main.delete_workspace_build_registry_entry("build_alice", "github:101", TEST_AGENT_TOKEN)
            after_delete = main.list_workspace_build_registry_entries("github:101", 4, TEST_AGENT_TOKEN)

        self.assertEqual(mine["contract_version"], "github-workspace-builds-v1")
        self.assertEqual([build["id"] for build in mine["builds"]], ["build_alice"])
        self.assertEqual([build["id"] for build in mine["pinned_builds"]], ["build_alice"])
        self.assertTrue(mine["builds"][0]["pinned"])
        self.assertIsNone(foreign)
        self.assertIsNone(foreign_delete)
        self.assertEqual(own_delete["status"], "deleted")
        self.assertEqual(after_delete["builds"], [])
        self.assertNotIn("github:202", str(mine))

    def test_secret_material_is_rejected_before_database_access_without_echo(self) -> None:
        fixture_secret = "sk-" + ("unitfixture" * 3)
        request = valid_request(prompt=f"Do not store {fixture_secret}")
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main.psycopg, "connect") as connect,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_build_registry_entry(request, self.http_request, TEST_AGENT_TOKEN, TEST_WORKSPACE_SUBJECT)

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
                main.create_build_registry_entry(request, self.http_request, TEST_AGENT_TOKEN, TEST_WORKSPACE_SUBJECT)

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
                main.create_build_registry_entry(module_request, self.http_request, TEST_AGENT_TOKEN, TEST_WORKSPACE_SUBJECT)

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

    def test_three_global_without_core_dependency_is_rejected_before_database_access(self) -> None:
        request = valid_request(
            html=(
                '<!doctype html><html><body><script>'
                'const scene = new THREE.Scene();'
                '</script></body></html>'
            )
        )
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main.psycopg, "connect") as connect,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_build_registry_entry(request, self.http_request, TEST_AGENT_TOKEN, TEST_WORKSPACE_SUBJECT)

        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(raised.exception.detail, "unrunnable build html")
        connect.assert_not_called()

    def test_audit_failure_rolls_back_build_and_returns_no_internal_error(self) -> None:
        sentinel = "postgresql://private-user:private-password@db.internal/superbrain"
        self.connection = FakeConnection(fail_audit=True)
        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": TEST_AGENT_TOKEN}),
            patch.object(main, "database_url", return_value="postgresql://unit"),
            patch.object(main.psycopg, "connect", return_value=self.connection),
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_build_registry_entry(valid_request(), self.http_request, TEST_AGENT_TOKEN, TEST_WORKSPACE_SUBJECT)

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
                    TEST_WORKSPACE_SUBJECT,
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
