from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import verify_project_progress_manifest as verifier


REPO_ROOT = Path(__file__).resolve().parents[2]


class ProjectProgressTruthTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads((REPO_ROOT / verifier.MANIFEST_PATH).read_text(encoding="utf-8"))
        self.ledger = json.loads((REPO_ROOT / verifier.DELTA_LEDGER_PATH).read_text(encoding="utf-8"))
        self.ledger_schema = json.loads(
            (REPO_ROOT / verifier.DELTA_LEDGER_SCHEMA_PATH).read_text(encoding="utf-8")
        )
        self.snapshot = json.loads((REPO_ROOT / verifier.ENDPOINT_SNAPSHOT_PATH).read_text(encoding="utf-8"))
        self.platform = (REPO_ROOT / verifier.PLATFORM_MIRROR_PATH).read_text(encoding="utf-8")

    def assert_rejected(self, callback, expected: str) -> None:
        with self.assertRaisesRegex(SystemExit, expected):
            callback()

    def validate(self, manifest=None, ledger=None, ledger_schema=None, snapshot=None, platform=None) -> None:
        verifier.validate_progress_truth(
            manifest if manifest is not None else self.manifest,
            ledger if ledger is not None else self.ledger,
            ledger_schema if ledger_schema is not None else self.ledger_schema,
            snapshot if snapshot is not None else self.snapshot,
            platform if platform is not None else self.platform,
            REPO_ROOT,
        )

    def test_current_baseline_and_both_mirrors_are_valid_without_phase5_delegate(self) -> None:
        self.validate()

    def test_canonical_ids_labels_and_order_are_exact(self) -> None:
        reordered = copy.deepcopy(self.manifest)
        reordered["horizontal"]["items"][3], reordered["horizontal"]["items"][4] = (
            reordered["horizontal"]["items"][4],
            reordered["horizontal"]["items"][3],
        )
        self.assert_rejected(lambda: self.validate(manifest=reordered), "id/order mismatch")

        relabeled = copy.deepcopy(self.manifest)
        relabeled["vertical"]["items"][4]["label"] = "MCP Gateway / Tools"
        self.assert_rejected(lambda: self.validate(manifest=relabeled), "canonical label mismatch")

    def test_hand_raised_p3_fails_without_evidence_delta(self) -> None:
        raised = copy.deepcopy(self.manifest)
        raised["horizontal"]["items"][3]["percent"] += 1
        raised["overall_percent"] = round(
            sum(item["percent"] for item in raised["horizontal"]["items"]) / 7
        )
        self.assert_rejected(lambda: self.validate(manifest=raised), "progress projection differs from the pinned v1 baseline")

    def test_hand_raised_p6_fails_without_evidence_delta(self) -> None:
        raised = copy.deepcopy(self.manifest)
        raised["horizontal"]["items"][6]["percent"] += 1
        raised["overall_percent"] = round(
            sum(item["percent"] for item in raised["horizontal"]["items"]) / 7
        )
        self.assert_rejected(lambda: self.validate(manifest=raised), "progress projection differs from the pinned v1 baseline")

    def test_hand_raised_vertical_cells_fail_without_evidence_delta(self) -> None:
        for index, cell_id in ((3, "layer_4"), (4, "layer_5")):
            with self.subTest(cell_id=cell_id):
                raised = copy.deepcopy(self.manifest)
                raised["vertical"]["items"][index]["percent"] += 1
                self.assert_rejected(
                    lambda raised=raised: self.validate(manifest=raised),
                    "progress projection differs from the pinned v1 baseline",
                )

    def test_endpoint_snapshot_mirror_edit_fails(self) -> None:
        edited = copy.deepcopy(self.snapshot)
        edited["/api/v1/project/progress"]["horizontal"]["items"][3]["percent"] += 1
        self.assert_rejected(lambda: self.validate(snapshot=edited), "endpoint snapshot project-progress mirror differs")

    def test_platform_horizontal_and_vertical_mirror_edits_fail(self) -> None:
        p6_edited = self.platform.replace('{ id: "P6", pct: 90 }', '{ id: "P6", pct: 91 }', 1)
        self.assertNotEqual(p6_edited, self.platform)
        self.assert_rejected(lambda: self.validate(platform=p6_edited), "horizontal mirror differs")

        layer_edited = self.platform.replace(
            '{ name: "MCP Gateway", layer: 5, pct: 56 }',
            '{ name: "MCP Gateway", layer: 5, pct: 57 }',
            1,
        )
        self.assertNotEqual(layer_edited, self.platform)
        self.assert_rejected(lambda: self.validate(platform=layer_edited), "vertical mirror differs")

    def test_v1_runtime_and_schema_reject_every_fabricated_delta_entry(self) -> None:
        self.assertEqual(self.ledger_schema["properties"]["entries"], {"const": []})
        fabricated = copy.deepcopy(self.ledger)
        fabricated["entries"] = [
            {
                "entry_id": "progress-delta-fabricated-phase-3",
                "cell_id": "phase_3",
                "old_percent": 44,
                "new_percent": 100,
                "source_sha": "b" * 40,
                "verifier_command": "pwsh -File scripts/fabricated.ps1",
                "artifact_path": ".phase1-artifacts/fabricated.json",
                "artifact_sha256": "c" * 64,
            }
        ]
        self.assert_rejected(
            lambda: self.validate(ledger=fabricated),
            "v1 progress delta ledger entries must remain exactly empty",
        )

    def test_pinned_baseline_source_commit_must_be_available(self) -> None:
        with patch.object(verifier, "git_object_is_commit", return_value=False):
            self.assert_rejected(self.validate, "pinned baseline source commit is unavailable")

    def test_pinned_baseline_source_commit_must_be_ancestor_of_head(self) -> None:
        with (
            patch.object(verifier, "git_object_is_commit", return_value=True),
            patch.object(verifier, "git_commit_is_ancestor", return_value=False),
        ):
            self.assert_rejected(self.validate, "pinned baseline source commit is not an ancestor of HEAD")

    def test_pinned_baseline_commit_must_contain_manifest(self) -> None:
        with (
            patch.object(verifier, "git_object_is_commit", return_value=True),
            patch.object(verifier, "git_commit_is_ancestor", return_value=True),
            patch.object(verifier, "git_file_at_commit", return_value=None),
        ):
            self.assert_rejected(self.validate, "pinned baseline commit does not contain the progress manifest")

    def test_coordinated_baseline_inflation_still_fails_against_pinned_commit(self) -> None:
        inflated_manifest = copy.deepcopy(self.manifest)
        inflated_manifest["horizontal"]["items"][3]["percent"] = 100
        inflated_manifest["overall_percent"] = round(
            sum(item["percent"] for item in inflated_manifest["horizontal"]["items"]) / 7
        )
        inflated_snapshot = copy.deepcopy(self.snapshot)
        inflated_snapshot["/api/v1/project/progress"] = copy.deepcopy(inflated_manifest)
        inflated_platform = self.platform.replace("overall: 89", "overall: 97", 1).replace(
            '{ id: "P3", pct: 44 }',
            '{ id: "P3", pct: 100 }',
            1,
        )
        self.assertNotEqual(inflated_platform, self.platform)

        inflated_horizontal = list(verifier.CANONICAL_HORIZONTAL)
        item_id, label, _ = inflated_horizontal[3]
        inflated_horizontal[3] = (item_id, label, 100)
        inflated_horizontal_tuple = tuple(inflated_horizontal)
        inflated_cells = inflated_horizontal_tuple + verifier.CANONICAL_VERTICAL
        inflated_projection = {
            "overall_percent": 97,
            "horizontal": [
                {"id": cell_id, "label": cell_label, "percent": percent}
                for cell_id, cell_label, percent in inflated_horizontal_tuple
            ],
            "vertical": [
                {"id": cell_id, "label": cell_label, "percent": percent}
                for cell_id, cell_label, percent in verifier.CANONICAL_VERTICAL
            ],
        }

        with (
            patch.object(verifier, "CANONICAL_HORIZONTAL", inflated_horizontal_tuple),
            patch.object(verifier, "CANONICAL_CELLS", inflated_cells),
            patch.object(verifier, "BASELINE_OVERALL_PERCENT", 97),
            patch.object(
                verifier,
                "BASELINE_PROJECTION_SHA256",
                verifier.canonical_json_sha256(inflated_projection),
            ),
        ):
            inflated_ledger = copy.deepcopy(self.ledger)
            inflated_ledger["baseline"] = verifier.expected_baseline_payload()
            inflated_schema = copy.deepcopy(self.ledger_schema)
            inflated_schema["properties"]["baseline"] = {
                "const": verifier.expected_baseline_payload()
            }
            self.assert_rejected(
                lambda: self.validate(
                    manifest=inflated_manifest,
                    ledger=inflated_ledger,
                    ledger_schema=inflated_schema,
                    snapshot=inflated_snapshot,
                    platform=inflated_platform,
                ),
                "pinned baseline projection hash mismatch",
            )


if __name__ == "__main__":
    unittest.main()
