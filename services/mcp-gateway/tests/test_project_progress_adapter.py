from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import HTTPException
from fastapi.testclient import TestClient

from app import main


TOKEN = "unit-service-token"
PHASE_IDS = [f"phase_{index}" for index in range(7)]
LAYER_IDS = [f"layer_{index}" for index in range(1, 8)]


def manifest() -> dict[str, object]:
    return {
        "overall_percent": 89,
        "progress_source": "docs/project-progress.manifest.json",
        "last_verified": "2026-08-03",
        "horizontal": {
            "label": "Phase progress",
            "items": [
                {"id": phase_id, "label": phase_id, "percent": 100 if index < 3 else 50, "status": "verified"}
                for index, phase_id in enumerate(PHASE_IDS)
            ],
        },
        "vertical": {
            "label": "Layer progress",
            "items": [
                {"id": layer_id, "label": layer_id, "percent": 100 if index < 3 else 56, "status": "verified"}
                for index, layer_id in enumerate(LAYER_IDS)
            ],
        },
    }


class ProjectProgressFilesystemAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="mcp-project-progress-")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "project-progress.manifest.json"
        self.path.write_text(json.dumps(manifest(), separators=(",", ":")), encoding="utf-8")
        try:
            self.path.chmod(0o444)
        except OSError:
            pass
        self.env = patch.dict(
            os.environ,
            {
                "AGENT_API_AUTH_TOKEN": TOKEN,
                "SUPERBRAIN_RUNTIME_MODE": "dev-only",
                "FILESYSTEM_PROJECT_PROGRESS_PATH": str(self.path),
            },
            clear=False,
        )
        self.env.start()
        self.addCleanup(self.env.stop)

    @staticmethod
    def audit_events() -> list[dict[str, object]]:
        return [
            {"event_id": "11111111-1111-4111-8111-111111111111", "severity": "info"},
            {"event_id": "22222222-2222-4222-8222-222222222222", "severity": "info"},
        ]

    def test_contract_is_fixed_bounded_internal_and_read_only(self) -> None:
        contract = main.filesystem_project_progress_contract()
        self.assertEqual(contract["contract_version"], "filesystem-project-progress-read-v1")
        self.assertEqual(contract["public_contract_endpoint"], "GET /api/v1/filesystem/project-progress/contract")
        self.assertEqual(contract["internal_execute_endpoint"], "GET /internal/v1/filesystem/project-progress")
        self.assertEqual(contract["source"], "image_baked_project_progress_manifest")
        self.assertEqual(contract["max_source_bytes"], 65_536)
        self.assertFalse(contract["caller_path_allowed"])
        self.assertFalse(contract["caller_filename_allowed"])
        self.assertTrue(contract["audit_before_read_required"])
        self.assertTrue(contract["audit_after_read_required"])
        self.assertFalse(contract["live_mcp_writes"])
        self.assertFalse(contract["direct_provider_calls"])
        self.assertFalse(contract["secret_output"])

    def test_success_returns_only_allowlisted_projection_after_two_audits(self) -> None:
        with patch.object(main, "post_audit_event", side_effect=self.audit_events()) as audit:
            result = main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
        self.assertEqual(audit.call_count, 2)
        self.assertTrue(all(call.args[0].trace_id == "trace-unit" for call in audit.call_args_list))
        before_request = audit.call_args_list[0].args[0]
        after_request = audit.call_args_list[1].args[0]
        self.assertEqual(before_request.tool_request_id, after_request.tool_request_id)
        self.assertEqual(before_request.run_id, after_request.run_id)
        self.assertEqual(before_request.session_id, after_request.session_id)
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["contract_version"], "filesystem-project-progress-read-v1")
        self.assertEqual(result["trace_id"], "trace-unit")
        self.assertEqual(result["overall_percent"], 89)
        self.assertEqual([item["id"] for item in result["horizontal"]], PHASE_IDS)
        self.assertEqual([item["id"] for item in result["vertical"]], LAYER_IDS)
        self.assertTrue(all(set(item) == {"id", "percent"} for item in result["horizontal"]))
        self.assertTrue(all(set(item) == {"id", "percent"} for item in result["vertical"]))
        self.assertRegex(result["source_sha256"], r"^[a-f0-9]{64}$")
        self.assertGreater(result["bytes_read"], 0)
        self.assertLessEqual(result["bytes_read"], 65_536)
        self.assertTrue(result["filesystem_read_performed"])
        self.assertTrue(result["audit_before_read"])
        self.assertTrue(result["audit_after_read"])
        self.assertNotIn("path", result)
        self.assertNotIn("content", result)
        for field in ("live_mcp_writes", "live_provider_calls", "direct_provider_calls", "production_deploy", "secret_output"):
            self.assertFalse(result[field])

    def test_read_uses_one_descriptor_instead_of_reopening_the_path(self) -> None:
        with (
            patch.object(Path, "read_bytes", side_effect=AssertionError("path must not be reopened")),
            patch.object(main, "post_audit_event", side_effect=self.audit_events()),
        ):
            result = main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
        self.assertTrue(result["filesystem_read_performed"])

    def test_pre_audit_failure_prevents_the_file_read(self) -> None:
        with (
            patch.object(main, "post_audit_event", return_value=None),
            patch.object(Path, "read_bytes", side_effect=AssertionError("read must not occur")),
        ):
            with self.assertRaises(HTTPException) as caught:
                main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
        self.assertEqual(caught.exception.status_code, 503)

    def test_completion_audit_failure_withholds_the_result(self) -> None:
        events = [self.audit_events()[0], None]
        with patch.object(main, "post_audit_event", side_effect=events):
            with self.assertRaises(HTTPException) as caught:
                main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
        self.assertEqual(caught.exception.status_code, 503)

    def test_wrong_token_and_non_dev_mode_fail_closed(self) -> None:
        with self.assertRaises(HTTPException) as wrong_token:
            main.execute_filesystem_project_progress_read("wrong", "trace-unit")
        self.assertEqual(wrong_token.exception.status_code, 401)
        with patch.dict(os.environ, {"SUPERBRAIN_RUNTIME_MODE": "production"}, clear=False):
            with self.assertRaises(HTTPException) as production:
                main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
        self.assertEqual(production.exception.status_code, 403)

    def test_oversize_malformed_and_schema_drift_fail_closed(self) -> None:
        missing_progress_source = manifest()
        missing_progress_source.pop("progress_source")
        missing_item_field = manifest()
        missing_item_field["horizontal"]["items"][0].pop("status")
        failures = [
            b"x" * 65_537,
            b"{not-json",
            b'{"overall_percent":89,"overall_percent":90}',
            b'{"overall_percent":89,"progress_source":"docs/project-progress.manifest.json","last_verified":"2026-08-03","horizontal":{},"vertical":{},"invalid":"\xff"}'[:-2] + b"\xff\"}",
            json.dumps({**manifest(), "overall_percent": True}).encode("utf-8"),
            json.dumps({**manifest(), "horizontal": {"items": []}}).encode("utf-8"),
            json.dumps(missing_progress_source).encode("utf-8"),
            json.dumps(missing_item_field).encode("utf-8"),
        ]
        for raw in failures:
            with self.subTest(size=len(raw)):
                self.path.chmod(0o644)
                self.path.write_bytes(raw)
                try:
                    self.path.chmod(0o444)
                except OSError:
                    pass
                with patch.object(main, "post_audit_event", return_value=self.audit_events()[0]):
                    with self.assertRaises(HTTPException):
                        main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")

    def test_writable_source_and_unsafe_trace_fail_closed(self) -> None:
        try:
            self.path.chmod(0o644)
            with patch.object(main, "post_audit_event", return_value=self.audit_events()[0]):
                with self.assertRaises(HTTPException):
                    main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
        finally:
            try:
                self.path.chmod(0o444)
            except OSError:
                pass

        with patch.object(main, "post_audit_event") as audit:
            with self.assertRaises(HTTPException) as unsafe_trace:
                main.execute_filesystem_project_progress_read(TOKEN, "bad\ntrace")
        self.assertEqual(unsafe_trace.exception.status_code, 400)
        audit.assert_not_called()

    def test_symlink_source_is_rejected_when_supported(self) -> None:
        link = Path(self.tmp.name) / "linked-progress.json"
        try:
            link.symlink_to(self.path)
        except OSError:
            self.skipTest("symlink creation is unavailable")
        with (
            patch.dict(os.environ, {"FILESYSTEM_PROJECT_PROGRESS_PATH": str(link)}, clear=False),
            patch.object(main, "post_audit_event", return_value=self.audit_events()[0]),
        ):
            with self.assertRaises(HTTPException):
                main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")

    def test_low_level_io_failures_still_persist_blocked_completion_audit(self) -> None:
        real_close = os.close

        def close_then_fail(descriptor: int) -> None:
            real_close(descriptor)
            raise OSError("unit close failure")

        for target, failure in (
            ("read", OSError("unit read failure")),
            ("fstat", OSError("unit fstat failure")),
            ("close", close_then_fail),
        ):
            with self.subTest(target=target):
                patcher = patch.object(os, target, side_effect=failure)
                with patcher, patch.object(main, "post_audit_event", side_effect=self.audit_events()) as audit:
                    with self.assertRaises(HTTPException) as caught:
                        main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
                self.assertEqual(caught.exception.status_code, 503)
                self.assertEqual(audit.call_count, 2)
                self.assertEqual(audit.call_args_list[1].args[0].audit_tags, ["read_phase:completed"])
                self.assertEqual(audit.call_args_list[1].args[1]["status"], "blocked")

    def test_vercel_asgi_boundary_hides_internal_adapter_for_all_read_methods(self) -> None:
        root = Path(__file__).resolve().parents[3]
        entrypoint = root / "api" / "mcp.py"
        spec = importlib.util.spec_from_file_location("unit_vercel_mcp_entrypoint", entrypoint)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        client = TestClient(module.app)
        for method in ("GET", "HEAD", "OPTIONS"):
            with self.subTest(method=method):
                response = client.request(method, "/mcp/internal/v1/filesystem/project-progress")
                self.assertEqual(response.status_code, 404)
        self.assertEqual(client.get("/mcp/api/v1/filesystem/project-progress/contract").status_code, 200)


if __name__ == "__main__":
    unittest.main()
