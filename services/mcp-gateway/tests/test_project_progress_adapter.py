from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import HTTPException

from app import main


TOKEN = "unit-service-token"
PHASE_IDS = [f"phase_{index}" for index in range(7)]
LAYER_IDS = [f"layer_{index}" for index in range(1, 8)]


def manifest() -> dict[str, object]:
    return {
        "overall_percent": 89,
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
        self.assertFalse(contract["secret_output"])

    def test_success_returns_only_allowlisted_projection_after_two_audits(self) -> None:
        with patch.object(main, "post_audit_event", side_effect=self.audit_events()) as audit:
            result = main.execute_filesystem_project_progress_read(TOKEN, "trace-unit")
        self.assertEqual(audit.call_count, 2)
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["contract_version"], "filesystem-project-progress-read-v1")
        self.assertEqual(result["trace_id"], "trace-unit")
        self.assertEqual(result["overall_percent"], 89)
        self.assertEqual([item["id"] for item in result["horizontal"]], PHASE_IDS)
        self.assertEqual([item["id"] for item in result["vertical"]], LAYER_IDS)
        self.assertRegex(result["source_sha256"], r"^[a-f0-9]{64}$")
        self.assertGreater(result["bytes_read"], 0)
        self.assertLessEqual(result["bytes_read"], 65_536)
        self.assertTrue(result["filesystem_read_performed"])
        self.assertTrue(result["audit_before_read"])
        self.assertTrue(result["audit_after_read"])
        self.assertNotIn("path", result)
        self.assertNotIn("content", result)
        for field in ("live_mcp_writes", "live_provider_calls", "production_deploy", "secret_output"):
            self.assertFalse(result[field])

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
        failures = [
            b"x" * 65_537,
            b"{not-json",
            json.dumps({**manifest(), "overall_percent": True}).encode("utf-8"),
            json.dumps({**manifest(), "horizontal": {"items": []}}).encode("utf-8"),
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


if __name__ == "__main__":
    unittest.main()
