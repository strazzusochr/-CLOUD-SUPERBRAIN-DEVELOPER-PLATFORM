from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import patch

from scripts import verify_project_progress_manifest as verifier


REPO_ROOT = Path(__file__).resolve().parents[2]
SYNTHETIC_P3_SCORER_COMMAND = "python scripts/tests/synthetic_p3_progress_delta_scorer.py --score-v1"
SYNTHETIC_P3_SCORER_ARGV = (
    "synthetic-python",
    "scripts/tests/synthetic_p3_progress_delta_scorer.py",
    "--score-v1",
)
SYNTHETIC_L4_SCORER_COMMAND = "python scripts/tests/synthetic_l4_progress_delta_scorer.py --score-v1"
SYNTHETIC_L4_SCORER_ARGV = (
    "synthetic-python",
    "scripts/tests/synthetic_l4_progress_delta_scorer.py",
    "--score-v1",
)


class ProjectProgressTruthTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads((REPO_ROOT / verifier.MANIFEST_PATH).read_text(encoding="utf-8"))
        self.ledger = json.loads((REPO_ROOT / verifier.DELTA_LEDGER_PATH).read_text(encoding="utf-8"))
        self.ledger_schema = json.loads(
            (REPO_ROOT / verifier.DELTA_LEDGER_SCHEMA_PATH).read_text(encoding="utf-8")
        )
        self.snapshot = json.loads((REPO_ROOT / verifier.ENDPOINT_SNAPSHOT_PATH).read_text(encoding="utf-8"))
        self.platform = (REPO_ROOT / verifier.PLATFORM_MIRROR_PATH).read_text(encoding="utf-8")
        baseline_projection = verifier.expected_baseline_projection()
        baseline_horizontal = {
            item["id"]: item["percent"] for item in baseline_projection["horizontal"]
        }
        baseline_vertical = {
            item["id"]: item["percent"] for item in baseline_projection["vertical"]
        }
        self.baseline_manifest = copy.deepcopy(self.manifest)
        self.baseline_manifest["overall_percent"] = baseline_projection["overall_percent"]
        for item in self.baseline_manifest["horizontal"]["items"]:
            item["percent"] = baseline_horizontal[item["id"]]
        for item in self.baseline_manifest["vertical"]["items"]:
            item["percent"] = baseline_vertical[item["id"]]
        self.baseline_snapshot = copy.deepcopy(self.snapshot)
        self.baseline_snapshot["/api/v1/project/progress"] = copy.deepcopy(
            self.baseline_manifest
        )
        self.baseline_platform = self.platform.replace(
            '{ name: "MCP Gateway", layer: 5, pct: 86 }',
            '{ name: "MCP Gateway", layer: 5, pct: 56 }',
            1,
        )
        self.assertNotEqual(self.baseline_platform, self.platform)

    def assert_rejected(self, callback, expected: str) -> None:
        with self.assertRaisesRegex(SystemExit, expected):
            callback()

    def candidate_freshness_inputs(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["last_verified"] = "2026-08-29"
        current_candidate = {
            "active_release_id": "prod-candidate-2026-08-29-local-rc23",
            "source_commit_sha": "a" * 40,
            "updated_at": "2026-08-29T12:34:56Z",
            "updated_by": "synthetic-test",
            "reason": "Source-bound synthetic candidate for verifier protocol tests.",
            "production_rollout_claimed": False,
        }
        phase5_itemization = {
            "contract_version": "phase5-credit-itemization-v2",
            "cell_id": "phase_5",
            "active_release_id": current_candidate["active_release_id"],
            "active_source_commit_sha": current_candidate["source_commit_sha"],
            "updated_at_utc": current_candidate["updated_at"],
        }
        return manifest, current_candidate, phase5_itemization

    def validate_candidate_freshness(
        self,
        manifest,
        current_candidate,
        phase5_itemization,
        *,
        source_available: bool = True,
        source_is_ancestor: bool = True,
    ) -> None:
        with (
            patch.object(verifier, "git_object_is_commit", return_value=source_available),
            patch.object(verifier, "git_commit_is_ancestor", return_value=source_is_ancestor),
        ):
            verifier.validate_current_candidate_freshness(
                manifest,
                current_candidate,
                phase5_itemization,
                REPO_ROOT,
                today_utc=date(2026, 8, 30),
            )

    def validate(self, manifest=None, ledger=None, ledger_schema=None, snapshot=None, platform=None) -> None:
        verifier.validate_progress_truth(
            manifest if manifest is not None else self.manifest,
            ledger if ledger is not None else self.ledger,
            ledger_schema if ledger_schema is not None else self.ledger_schema,
            snapshot if snapshot is not None else self.snapshot,
            platform if platform is not None else self.platform,
            REPO_ROOT,
        )

    def synthetic_p3_delta(self):
        manifest = copy.deepcopy(self.baseline_manifest)
        manifest["horizontal"]["items"][3]["percent"] = 45
        manifest["overall_percent"] = round(
            sum(item["percent"] for item in manifest["horizontal"]["items"]) / 7
        )
        projection = verifier.progress_projection(manifest)
        source_sha = "a" * 40
        artifact_bytes = b'{"contract_version":"p3-progress-proof-v1","verified":true}\n'
        artifact_path = ".phase1-artifacts/project-progress/p3-44-to-45.json"
        ledger = copy.deepcopy(self.ledger)
        ledger["contract_version"] = "project-progress-delta-ledger-v2"
        ledger["entries"] = [
            {
                "entry_id": "p3-44-to-45",
                "scope": "horizontal",
                "cell_id": "phase_3",
                "old_percent": 44,
                "new_percent": 45,
                "overall_percent": manifest["overall_percent"],
                "previous_projection_sha256": verifier.BASELINE_PROJECTION_SHA256,
                "projection_sha256": verifier.canonical_json_sha256(projection),
                "source_sha": source_sha,
                "verifier_command": SYNTHETIC_P3_SCORER_COMMAND,
                "artifact_path": artifact_path,
                "artifact_sha256": hashlib.sha256(artifact_bytes).hexdigest(),
            }
        ]
        snapshot = copy.deepcopy(self.baseline_snapshot)
        snapshot["/api/v1/project/progress"] = copy.deepcopy(manifest)
        platform = self.baseline_platform.replace(
            '{ id: "P3", pct: 44 }',
            '{ id: "P3", pct: 45 }',
            1,
        )
        self.assertNotEqual(platform, self.baseline_platform)
        return manifest, ledger, snapshot, platform, artifact_bytes

    def validate_synthetic_p3_delta(
        self,
        manifest,
        ledger,
        snapshot,
        platform,
        artifact_bytes,
        *,
        source_available: bool = True,
        source_is_ancestor: bool = True,
        committed_artifact: bytes | None = None,
        artifact_missing: bool = False,
        artifact_object_type: str = "blob",
        artifact_object_mode: str = "100644",
        artifact_payloads: dict[str, bytes] | None = None,
        approved_scorers: dict[
            tuple[str, str, int, int], tuple[str, tuple[str, ...]]
        ]
        | None = None,
        scorer_stdout: str | None = None,
        scorer_returncode: int = 0,
        scorer_side_effect: BaseException | None = None,
    ):
        source_shas = {entry["source_sha"] for entry in ledger["entries"]}
        first_artifact_path = ledger["entries"][0]["artifact_path"]
        committed_artifacts = dict(artifact_payloads or {first_artifact_path: artifact_bytes})
        if committed_artifact is not None:
            committed_artifacts[first_artifact_path] = committed_artifact

        def object_is_commit(_repo_root, candidate_sha):
            if candidate_sha in source_shas:
                return source_available
            return True

        def commit_is_ancestor(_repo_root, ancestor, descendant):
            if source_shas.intersection({ancestor, descendant}):
                return source_is_ancestor
            return True

        def file_at_commit(_repo_root, candidate_sha, path):
            if artifact_missing:
                return None
            if candidate_sha in source_shas and path in committed_artifacts:
                return committed_artifacts[path]
            return None

        def object_type_at_commit(_repo_root, candidate_sha, path):
            if candidate_sha in source_shas and path in committed_artifacts:
                return artifact_object_type
            return None

        def object_mode_at_commit(_repo_root, candidate_sha, path):
            if candidate_sha in source_shas and path in committed_artifacts:
                return artifact_object_mode
            return None

        def valid_scorer_result(request):
            return {
                "contract_version": "project-progress-delta-scorer-result-v1",
                "verifier_command": request["verifier_command"],
                "scope": request["scope"],
                "cell_id": request["cell_id"],
                "source_sha": request["source_sha"],
                "artifact_path": request["artifact_path"],
                "artifact_sha256": request["artifact_sha256"],
                "old_percent": request["old_percent"],
                "new_percent": request["new_percent"],
                "overall_percent": request["overall_percent"],
                "previous_projection_sha256": request["previous_projection_sha256"],
                "projection_sha256": request["projection_sha256"],
                "read_only": True,
                "provider_writes": False,
                "secret_output": False,
                "evidence_verified": True,
                "credit_allowed": True,
            }

        def run_scorer(argv, **kwargs):
            request = json.loads(kwargs["input"])
            stdout = scorer_stdout
            if stdout is None:
                stdout = json.dumps(valid_scorer_result(request), sort_keys=True) + "\n"
            return subprocess.CompletedProcess(
                args=argv,
                returncode=scorer_returncode,
                stdout=stdout,
                stderr="synthetic scorer failure" if scorer_returncode else "",
            )

        default_approved_scorers = {
            ("horizontal", "phase_3", 44, 45): (
                SYNTHETIC_P3_SCORER_COMMAND,
                SYNTHETIC_P3_SCORER_ARGV,
            ),
            ("vertical", "layer_4", 55, 56): (
                SYNTHETIC_L4_SCORER_COMMAND,
                SYNTHETIC_L4_SCORER_ARGV,
            ),
        }
        # Protocol tests exercise chained ledger entries without weakening the
        # production allowlist. Admit only the exact synthetic transitions that
        # occur in this fixture so replay reaches the ancestry/evidence guards
        # each test is intended to cover.
        for entry in ledger["entries"]:
            key = (
                entry["scope"],
                entry["cell_id"],
                entry["old_percent"],
                entry["new_percent"],
            )
            if entry["scope"] == "horizontal" and entry["cell_id"] == "phase_3":
                default_approved_scorers[key] = (
                    SYNTHETIC_P3_SCORER_COMMAND,
                    SYNTHETIC_P3_SCORER_ARGV,
                )
            elif entry["scope"] == "vertical" and entry["cell_id"] == "layer_4":
                default_approved_scorers[key] = (
                    SYNTHETIC_L4_SCORER_COMMAND,
                    SYNTHETIC_L4_SCORER_ARGV,
                )

        with (
            patch.object(
                verifier,
                "load_pinned_baseline_projection",
                return_value=verifier.expected_baseline_projection(),
            ),
            patch.object(verifier, "git_object_is_commit", side_effect=object_is_commit),
            patch.object(verifier, "git_commit_is_ancestor", side_effect=commit_is_ancestor),
            patch.object(verifier, "git_file_at_commit", side_effect=file_at_commit),
            patch.object(verifier, "git_object_type_at_commit", side_effect=object_type_at_commit),
            patch.object(verifier, "git_object_mode_at_commit", side_effect=object_mode_at_commit),
            patch.object(
                verifier,
                "APPROVED_DELTA_SCORERS",
                approved_scorers
                if approved_scorers is not None
                else default_approved_scorers,
            ),
            patch.object(
                verifier.subprocess,
                "run",
                side_effect=scorer_side_effect if scorer_side_effect is not None else run_scorer,
            ) as scorer_run,
        ):
            self.validate(
                manifest=manifest,
                ledger=ledger,
                snapshot=snapshot,
                platform=platform,
            )
        return scorer_run

    def test_current_baseline_and_both_mirrors_are_valid_without_phase5_delegate(self) -> None:
        self.validate()

    def test_current_candidate_source_and_freshness_binding_accepts_valid_chain(self) -> None:
        manifest, current_candidate, phase5_itemization = self.candidate_freshness_inputs()
        self.validate_candidate_freshness(manifest, current_candidate, phase5_itemization)

    def test_current_candidate_rejects_schema_and_identity_drift(self) -> None:
        manifest, current_candidate, phase5_itemization = self.candidate_freshness_inputs()

        missing_source = copy.deepcopy(current_candidate)
        missing_source.pop("source_commit_sha")
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, missing_source, phase5_itemization
            ),
            "current release candidate keys mismatch",
        )

        extra_field = {**current_candidate, "unbound_claim": True}
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, extra_field, phase5_itemization
            ),
            "current release candidate keys mismatch",
        )

        bad_release = copy.deepcopy(current_candidate)
        bad_release["active_release_id"] = "production"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, bad_release, phase5_itemization
            ),
            "active_release_id is invalid",
        )

        empty_reason = copy.deepcopy(current_candidate)
        empty_reason["reason"] = "  "
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, empty_reason, phase5_itemization
            ),
            "reason must be non-empty",
        )

        rollout_claim = copy.deepcopy(current_candidate)
        rollout_claim["production_rollout_claimed"] = True
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, rollout_claim, phase5_itemization
            ),
            "may not claim production rollout",
        )

    def test_current_candidate_rejects_phase5_source_or_release_mismatch(self) -> None:
        manifest, current_candidate, phase5_itemization = self.candidate_freshness_inputs()

        uppercase_source = copy.deepcopy(current_candidate)
        uppercase_source["source_commit_sha"] = "A" * 40
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, uppercase_source, phase5_itemization
            ),
            "source_commit_sha must be a lowercase 40-character Git SHA",
        )

        source_mismatch = copy.deepcopy(phase5_itemization)
        source_mismatch["active_source_commit_sha"] = "b" * 40
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, current_candidate, source_mismatch
            ),
            "source_commit_sha does not match Phase-5 itemization",
        )

        release_mismatch = copy.deepcopy(phase5_itemization)
        release_mismatch["active_release_id"] = "prod-candidate-2026-08-29-local-rc24"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, current_candidate, release_mismatch
            ),
            "active_release_id does not match Phase-5 itemization",
        )

        wrong_contract = copy.deepcopy(phase5_itemization)
        wrong_contract["contract_version"] = "phase5-credit-itemization-v1"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, current_candidate, wrong_contract
            ),
            "Phase-5 itemization contract mismatch",
        )

    def test_current_candidate_rejects_timestamp_and_manifest_freshness_drift(self) -> None:
        manifest, current_candidate, phase5_itemization = self.candidate_freshness_inputs()

        malformed_timestamp = copy.deepcopy(current_candidate)
        malformed_timestamp["updated_at"] = "2026-08-29"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, malformed_timestamp, phase5_itemization
            ),
            "updated_at must be a whole-second UTC timestamp",
        )

        timestamp_mismatch = copy.deepcopy(phase5_itemization)
        timestamp_mismatch["updated_at_utc"] = "2026-08-29T12:34:57Z"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest, current_candidate, timestamp_mismatch
            ),
            "updated_at does not match Phase-5 itemization",
        )

        stale_manifest = copy.deepcopy(manifest)
        stale_manifest["last_verified"] = "2026-08-28"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                stale_manifest, current_candidate, phase5_itemization
            ),
            "last_verified predates the active release candidate",
        )

        future_manifest = copy.deepcopy(manifest)
        future_manifest["last_verified"] = "2026-08-31"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                future_manifest, current_candidate, phase5_itemization
            ),
            "last_verified may not be future-dated",
        )

        impossible_manifest_date = copy.deepcopy(manifest)
        impossible_manifest_date["last_verified"] = "2026-02-30"
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                impossible_manifest_date, current_candidate, phase5_itemization
            ),
            "last_verified must be a valid ISO date",
        )

    def test_current_candidate_source_must_exist_and_be_ancestor(self) -> None:
        manifest, current_candidate, phase5_itemization = self.candidate_freshness_inputs()
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest,
                current_candidate,
                phase5_itemization,
                source_available=False,
            ),
            "source commit is unavailable",
        )
        self.assert_rejected(
            lambda: self.validate_candidate_freshness(
                manifest,
                current_candidate,
                phase5_itemization,
                source_is_ancestor=False,
            ),
            "source commit is not an ancestor of HEAD",
        )

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
        self.assert_rejected(lambda: self.validate(manifest=raised), "progress projection differs from the replayed v2 delta ledger")

    def test_hand_raised_p6_fails_without_evidence_delta(self) -> None:
        raised = copy.deepcopy(self.manifest)
        raised["horizontal"]["items"][6]["percent"] += 1
        raised["overall_percent"] = round(
            sum(item["percent"] for item in raised["horizontal"]["items"]) / 7
        )
        self.assert_rejected(lambda: self.validate(manifest=raised), "progress projection differs from the replayed v2 delta ledger")

    def test_hand_raised_vertical_cells_fail_without_evidence_delta(self) -> None:
        for index, cell_id in ((3, "layer_4"), (4, "layer_5")):
            with self.subTest(cell_id=cell_id):
                raised = copy.deepcopy(self.manifest)
                raised["vertical"]["items"][index]["percent"] += 1
                self.assert_rejected(
                    lambda raised=raised: self.validate(manifest=raised),
                    "progress projection differs from the replayed v2 delta ledger",
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
            '{ name: "MCP Gateway", layer: 5, pct: 86 }',
            '{ name: "MCP Gateway", layer: 5, pct: 87 }',
            1,
        )
        self.assertNotEqual(layer_edited, self.platform)
        self.assert_rejected(lambda: self.validate(platform=layer_edited), "vertical mirror differs")

    def test_v2_replays_one_source_bound_p3_delta(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()
        scorer_run = self.validate_synthetic_p3_delta(
            manifest,
            ledger,
            snapshot,
            platform,
            artifact_bytes,
        )
        expected_request = verifier.build_delta_scorer_request(ledger["entries"][0])
        scorer_run.assert_called_once_with(
            list(SYNTHETIC_P3_SCORER_ARGV),
            cwd=REPO_ROOT,
            input=json.dumps(
                expected_request,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n",
            capture_output=True,
            text=True,
            check=False,
            timeout=verifier.DELTA_SCORER_TIMEOUT_SECONDS,
            env=verifier.delta_scorer_environment(),
            shell=False,
        )

    def test_approved_scorers_are_bound_to_exact_cell_transition(self) -> None:
        expected = {
            ("horizontal", "phase_3", 44, 100): "python scripts/score_phase3_oauth_credit.py --score-v1",
            ("horizontal", "phase_5", 89, 100): "python scripts/score_phase5_market_ready_credit.py --score-v1",
            ("horizontal", "phase_6", 90, 100): "python scripts/score_phase6_scale_credit.py --score-v1",
            ("vertical", "layer_4", 55, 100): "python scripts/score_layer4_hosted_llm_credit.py --score-v1",
            ("vertical", "layer_5", 56, 86): "python scripts/score_layer5_hosted_mcp_credit.py --score-v1",
            ("vertical", "layer_5", 86, 100): "python scripts/score_layer5_registry_release_credit.py --score-v1",
        }
        self.assertEqual(
            {key: value[0] for key, value in verifier.APPROVED_DELTA_SCORERS.items()},
            expected,
        )

    def test_v2_rejects_bad_unavailable_and_non_ancestor_entry_sources(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()

        bad = copy.deepcopy(ledger)
        bad["entries"][0]["source_sha"] = "A" * 40
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest, bad, snapshot, platform, artifact_bytes
            ),
            "source_sha must be a lowercase 40-character Git SHA",
        )

        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                source_available=False,
            ),
            "source commit is unavailable",
        )
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                source_is_ancestor=False,
            ),
            "source ancestry chain mismatch",
        )

        baseline_source = copy.deepcopy(ledger)
        baseline_source["entries"][0]["source_sha"] = verifier.BASELINE_SOURCE_SHA
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                baseline_source,
                snapshot,
                platform,
                artifact_bytes,
            ),
            "source_sha must advance beyond the pinned baseline",
        )

    def test_v2_rejects_bad_projection_hash_and_percent_above_100(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()

        bad_hash = copy.deepcopy(ledger)
        bad_hash["entries"][0]["projection_sha256"] = "f" * 64
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest, bad_hash, snapshot, platform, artifact_bytes
            ),
            "projection_sha256 does not match replay state",
        )

        above_100 = copy.deepcopy(ledger)
        above_100["entries"][0]["new_percent"] = 101
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest, above_100, snapshot, platform, artifact_bytes
            ),
            "new_percent percent must be between 0 and 100",
        )

    def test_v2_rejects_arbitrary_verifier_command(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                approved_scorers={},
            ),
            "cell has no statically approved evidence scorer",
        )
        ledger["entries"][0]["verifier_command"] = "pwsh -File scripts/fabricated.ps1"
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest, ledger, snapshot, platform, artifact_bytes
            ),
            "verifier_command is not the statically approved scorer",
        )

    def test_v2_rejects_missing_failed_or_timed_out_approved_scorer(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_side_effect=FileNotFoundError("synthetic scorer missing"),
            ),
            "approved evidence scorer is unavailable",
        )
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_returncode=7,
            ),
            "approved evidence scorer failed",
        )
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_side_effect=subprocess.TimeoutExpired(
                    cmd=list(SYNTHETIC_P3_SCORER_ARGV),
                    timeout=30,
                ),
            ),
            "approved evidence scorer timed out",
        )

    def test_v2_rejects_malformed_mismatched_or_denied_scorer_result(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_stdout="not-json\n",
            ),
            "approved evidence scorer output is malformed",
        )

        request = {
            "verifier_command": ledger["entries"][0]["verifier_command"],
            "scope": ledger["entries"][0]["scope"],
            "cell_id": ledger["entries"][0]["cell_id"],
            "source_sha": ledger["entries"][0]["source_sha"],
            "artifact_path": ledger["entries"][0]["artifact_path"],
            "artifact_sha256": ledger["entries"][0]["artifact_sha256"],
            "old_percent": ledger["entries"][0]["old_percent"],
            "new_percent": ledger["entries"][0]["new_percent"],
            "overall_percent": ledger["entries"][0]["overall_percent"],
            "previous_projection_sha256": ledger["entries"][0]["previous_projection_sha256"],
            "projection_sha256": ledger["entries"][0]["projection_sha256"],
        }
        valid_result = {
            "contract_version": "project-progress-delta-scorer-result-v1",
            **request,
            "read_only": True,
            "provider_writes": False,
            "secret_output": False,
            "evidence_verified": True,
            "credit_allowed": True,
        }
        mismatched = {**valid_result, "source_sha": "b" * 40}
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_stdout=json.dumps(mismatched) + "\n",
            ),
            "result binding mismatch for source_sha",
        )
        malformed_shape = dict(valid_result)
        malformed_shape.pop("artifact_sha256")
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_stdout=json.dumps(malformed_shape) + "\n",
            ),
            "result keys mismatch",
        )
        denied = {**valid_result, "evidence_verified": False}
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_stdout=json.dumps(denied) + "\n",
            ),
            "did not verify evidence",
        )
        writes = {**valid_result, "provider_writes": True}
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_stdout=json.dumps(writes) + "\n",
            ),
            "must report provider_writes=false",
        )

    def test_v2_scorer_process_scrubs_secrets_and_rejects_oversized_output(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()
        with patch.dict(
            verifier.os.environ,
            {
                "PATH": "synthetic-safe-path",
                "CLOUDFLARE_API_TOKEN": "must-not-be-inherited",
                "GITHUB_TOKEN": "must-not-be-inherited",
            },
            clear=False,
        ):
            scorer_run = self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
            )
        scorer_env = scorer_run.call_args.kwargs["env"]
        self.assertEqual(scorer_env["PATH"], "synthetic-safe-path")
        self.assertNotIn("CLOUDFLARE_API_TOKEN", scorer_env)
        self.assertNotIn("GITHUB_TOKEN", scorer_env)
        self.assertFalse(scorer_run.call_args.kwargs["shell"])

        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                scorer_stdout="x" * (verifier.DELTA_SCORER_MAX_OUTPUT_CHARS + 1),
            ),
            "output exceeded the bounded limit",
        )

    def test_v2_rejects_bad_overall_and_old_percent_or_baseline_chain_drift(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()

        bad_overall = copy.deepcopy(ledger)
        bad_overall["entries"][0]["overall_percent"] += 1
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest, bad_overall, snapshot, platform, artifact_bytes
            ),
            "overall_percent does not match replay state",
        )

        old_percent_drift = copy.deepcopy(ledger)
        old_percent_drift["entries"][0]["old_percent"] = 43
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest, old_percent_drift, snapshot, platform, artifact_bytes
            ),
            "old_percent does not match replay state",
        )

        baseline_chain_drift = copy.deepcopy(ledger)
        baseline_chain_drift["entries"][0]["previous_projection_sha256"] = "e" * 64
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest, baseline_chain_drift, snapshot, platform, artifact_bytes
            ),
            "previous_projection_sha256 does not match replay state",
        )

    def test_v2_rejects_missing_or_hash_mismatched_committed_artifact(self) -> None:
        manifest, ledger, snapshot, platform, artifact_bytes = self.synthetic_p3_delta()

        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                committed_artifact=b"",
            ),
            "evidence artifact hash mismatch",
        )

        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                artifact_missing=True,
            ),
            "evidence artifact is unavailable at source commit",
        )
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                artifact_object_type="tree",
            ),
            "evidence artifact must be a Git blob",
        )
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                manifest,
                ledger,
                snapshot,
                platform,
                artifact_bytes,
                artifact_object_mode="120000",
            ),
            "evidence artifact must be a regular Git file",
        )

    def test_v2_rejects_same_cell_proof_reuse_and_requires_strict_source_advancement(self) -> None:
        manifest, ledger, _snapshot, _platform, artifact_bytes = self.synthetic_p3_delta()
        final_manifest = copy.deepcopy(manifest)
        final_manifest["horizontal"]["items"][3]["percent"] = 46
        final_manifest["overall_percent"] = round(
            sum(item["percent"] for item in final_manifest["horizontal"]["items"]) / 7
        )
        second_artifact_path = ".phase1-artifacts/project-progress/p3-45-to-46.json"
        second_artifact_bytes = b'{"contract_version":"p3-progress-proof-v1","step":2,"verified":true}\n'
        second_entry = {
            **ledger["entries"][0],
            "entry_id": "p3-45-to-46",
            "old_percent": 45,
            "new_percent": 46,
            "overall_percent": final_manifest["overall_percent"],
            "previous_projection_sha256": ledger["entries"][0]["projection_sha256"],
            "projection_sha256": verifier.canonical_json_sha256(
                verifier.progress_projection(final_manifest)
            ),
            "artifact_path": second_artifact_path,
            "artifact_sha256": hashlib.sha256(second_artifact_bytes).hexdigest(),
        }
        repeated_source = copy.deepcopy(ledger)
        repeated_source["entries"].append(second_entry)
        final_snapshot = copy.deepcopy(self.baseline_snapshot)
        final_snapshot["/api/v1/project/progress"] = copy.deepcopy(final_manifest)
        final_platform = self.baseline_platform.replace(
            '{ id: "P3", pct: 44 }',
            '{ id: "P3", pct: 46 }',
            1,
        )
        artifacts = {
            ledger["entries"][0]["artifact_path"]: artifact_bytes,
            second_artifact_path: second_artifact_bytes,
        }
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                final_manifest,
                repeated_source,
                final_snapshot,
                final_platform,
                artifact_bytes,
                artifact_payloads=artifacts,
            ),
            "source_sha must advance strictly for a repeated cell",
        )

        reused_proof = copy.deepcopy(repeated_source)
        reused_proof["entries"][1]["artifact_path"] = reused_proof["entries"][0]["artifact_path"]
        reused_proof["entries"][1]["artifact_sha256"] = reused_proof["entries"][0]["artifact_sha256"]
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                final_manifest,
                reused_proof,
                final_snapshot,
                final_platform,
                artifact_bytes,
                artifact_payloads=artifacts,
            ),
            "reuses an identical evidence artifact for the same cell",
        )

        newer_source_reused_artifact = copy.deepcopy(repeated_source)
        newer_source_reused_artifact["entries"][1]["source_sha"] = "b" * 40
        newer_source_reused_artifact["entries"][1]["artifact_path"] = (
            newer_source_reused_artifact["entries"][0]["artifact_path"]
        )
        newer_source_reused_artifact["entries"][1]["artifact_sha256"] = (
            newer_source_reused_artifact["entries"][0]["artifact_sha256"]
        )
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                final_manifest,
                newer_source_reused_artifact,
                final_snapshot,
                final_platform,
                artifact_bytes,
                artifact_payloads=artifacts,
            ),
            "reuses an identical evidence artifact for the same cell",
        )

        valid_advanced_source = copy.deepcopy(repeated_source)
        valid_advanced_source["entries"][1]["source_sha"] = "b" * 40
        scorer_run = self.validate_synthetic_p3_delta(
            final_manifest,
            valid_advanced_source,
            final_snapshot,
            final_platform,
            artifact_bytes,
            artifact_payloads=artifacts,
        )
        self.assertEqual(scorer_run.call_count, 2)

    def test_v2_allows_same_source_for_different_cells_and_scores_each_entry(self) -> None:
        manifest, ledger, _snapshot, _platform, artifact_bytes = self.synthetic_p3_delta()
        final_manifest = copy.deepcopy(manifest)
        final_manifest["vertical"]["items"][3]["percent"] = 56
        second_artifact_path = ".phase1-artifacts/project-progress/l4-55-to-56.json"
        second_artifact_bytes = b'{"contract_version":"l4-progress-proof-v1","verified":true}\n'
        ledger["entries"].append(
            {
                **ledger["entries"][0],
                "entry_id": "l4-55-to-56",
                "scope": "vertical",
                "cell_id": "layer_4",
                "verifier_command": SYNTHETIC_L4_SCORER_COMMAND,
                "old_percent": 55,
                "new_percent": 56,
                "previous_projection_sha256": ledger["entries"][0]["projection_sha256"],
                "projection_sha256": verifier.canonical_json_sha256(
                    verifier.progress_projection(final_manifest)
                ),
                "artifact_path": second_artifact_path,
                "artifact_sha256": hashlib.sha256(second_artifact_bytes).hexdigest(),
            }
        )
        final_snapshot = copy.deepcopy(self.baseline_snapshot)
        final_snapshot["/api/v1/project/progress"] = copy.deepcopy(final_manifest)
        final_platform = (
            self.baseline_platform.replace('{ id: "P3", pct: 44 }', '{ id: "P3", pct: 45 }', 1)
            .replace(
                '{ name: "LLM Gateway", layer: 4, pct: 55 }',
                '{ name: "LLM Gateway", layer: 4, pct: 56 }',
                1,
            )
        )
        scorer_run = self.validate_synthetic_p3_delta(
            final_manifest,
            ledger,
            final_snapshot,
            final_platform,
            artifact_bytes,
            artifact_payloads={
                ledger["entries"][0]["artifact_path"]: artifact_bytes,
                second_artifact_path: second_artifact_bytes,
            },
        )
        self.assertEqual(scorer_run.call_count, 2)

        cross_cell_reuse = copy.deepcopy(ledger)
        cross_cell_reuse["entries"][1]["verifier_command"] = SYNTHETIC_P3_SCORER_COMMAND
        self.assert_rejected(
            lambda: self.validate_synthetic_p3_delta(
                final_manifest,
                cross_cell_reuse,
                final_snapshot,
                final_platform,
                artifact_bytes,
                artifact_payloads={
                    ledger["entries"][0]["artifact_path"]: artifact_bytes,
                    second_artifact_path: second_artifact_bytes,
                },
            ),
            "verifier_command is not the statically approved scorer for vertical/layer_4",
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
