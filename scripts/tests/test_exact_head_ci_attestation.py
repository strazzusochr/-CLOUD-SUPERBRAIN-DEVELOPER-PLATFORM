from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import build_exact_head_ci_attestation as subject  # noqa: E402


SOURCE = "a" * 40
QUALIFICATION = "b" * 40
REPOSITORY = "example/project"


def fixtures() -> tuple[
    dict[str, object], dict[str, object], dict[str, object], dict[str, object], dict[str, object]
]:
    steps = [
        {"name": "Checkout", "conclusion": "success"},
        {"name": "OAuth boundary unit contract", "conclusion": "success"},
        {"name": "Secret scan", "conclusion": "success"},
    ]
    run = {
        "id": 123,
        "run_attempt": 1,
        "head_sha": QUALIFICATION,
        "head_branch": "codex/test",
        "status": "completed",
        "conclusion": "success",
        "event": "workflow_dispatch",
        "path": ".github/workflows/pr-check.yml",
        "html_url": f"https://github.com/{REPOSITORY}/actions/runs/123",
        "repository": {"full_name": REPOSITORY},
    }
    jobs = {
        "total_count": 1,
        "jobs": [{"status": "completed", "conclusion": "success", "steps": steps}],
    }
    repository = {"full_name": REPOSITORY, "default_branch": "chore/repo-bootstrap"}
    branch = {"name": "chore/repo-bootstrap", "protected": True}
    source_checkout = {
        "binding_mode": "source_checkout_attestation_v1",
        "candidate_sha": SOURCE,
        "checked_out_sha": SOURCE,
        "contract_version": "pr-check-source-checkout-attestation-v1",
        "control_delta": ["docs/runtime-state/source-qualification-control.json"],
        "control_sha": QUALIFICATION,
        "event_name": "workflow_dispatch",
        "github_actions_artifact_upload": True,
        "non_claims": [
            "This attestation proves only the exact source checkout boundary for this CI run.",
            "This attestation does not convert DEV-ONLY evidence into hosted proof.",
            "This attestation does not claim GHCR publication, production deployment, release promotion, or Owner approval.",
        ],
        "production_deploy": False,
        "ref": "refs/heads/codex/test",
        "registry_publish": False,
        "release_promotion": False,
        "run_id": 123,
        "run_attempt": 1,
        "run_sha": QUALIFICATION,
        "run_url": f"https://github.com/{REPOSITORY}/actions/runs/123",
        "secret_output": False,
        "source_prequalification": True,
    }
    return run, jobs, repository, branch, source_checkout


class ExactHeadCiAttestationTests(unittest.TestCase):
    def test_writer_downloads_and_binds_the_exact_source_checkout_artifact(self) -> None:
        writer = (ROOT / "scripts" / "write-exact-head-ci-attestation.ps1").read_text(encoding="utf-8")
        for marker in (
            "[string]$ExpectedQualificationSha",
            'pr-check-source-checkout-attestation-$RunId-1',
            "gh run download $RunId --repo $Repository --name $artifactName",
            "ci-source-checkout-attestation.json",
            "--qualification-sha $ExpectedQualificationSha",
            "--source-checkout-attestation $checkoutPath",
            'rev-parse "$ExpectedQualificationSha^"',
            "Qualification must be a direct child of the source.",
            "Qualification delta must contain only the source qualification control.",
        ):
            self.assertIn(marker, writer)

    def test_accepts_complete_exact_head_readback(self) -> None:
        run, jobs, repository, branch, source_checkout = fixtures()
        value = subject.build_attestation(
            expected_repository=REPOSITORY,
            expected_source_sha=SOURCE,
            expected_qualification_sha=QUALIFICATION,
            run=run,
            jobs_payload=jobs,
            repository=repository,
            branch=branch,
            source_checkout=source_checkout,
            source_checkout_sha256="c" * 64,
        )
        self.assertEqual(value["source_commit_sha"], SOURCE)
        self.assertEqual(value["qualification_commit_sha"], QUALIFICATION)
        self.assertEqual(value["run_head_sha"], QUALIFICATION)
        self.assertTrue(value["source_prequalification"])
        self.assertEqual(value["failed_job_count"], 0)
        self.assertEqual(value["skipped_job_count"], 0)
        self.assertTrue(value["branch_protection_verified"])
        self.assertTrue(value["secret_scan_verified"])
        self.assertTrue(value["oauth_regression_verified"])

    def test_rejects_source_skipped_step_and_unprotected_default(self) -> None:
        mutations = (
            ("qualification SHA", lambda r, _j, _repo, _b, _s: r.__setitem__("head_sha", "d" * 40)),
            (
                "CI step",
                lambda _r, j, _repo, _b, _s: j["jobs"][0]["steps"][1].__setitem__("conclusion", "skipped"),
            ),
            ("not protected", lambda _r, _j, _repo, b, _s: b.__setitem__("protected", False)),
            ("candidate mismatch", lambda _r, _j, _repo, _b, s: s.__setitem__("candidate_sha", "d" * 40)),
            ("control delta mismatch", lambda _r, _j, _repo, _b, s: s.__setitem__("control_delta", [])),
            ("non-claims mismatch", lambda _r, _j, _repo, _b, s: s.__setitem__("non_claims", [])),
        )
        for expected, mutate in mutations:
            with self.subTest(expected=expected):
                values = [copy.deepcopy(value) for value in fixtures()]
                mutate(*values)
                with self.assertRaisesRegex(subject.AttestationError, expected):
                    subject.build_attestation(
                        expected_repository=REPOSITORY,
                        expected_source_sha=SOURCE,
                        expected_qualification_sha=QUALIFICATION,
                        run=values[0],
                        jobs_payload=values[1],
                        repository=values[2],
                        branch=values[3],
                        source_checkout=values[4],
                        source_checkout_sha256="c" * 64,
                    )


if __name__ == "__main__":
    unittest.main()
