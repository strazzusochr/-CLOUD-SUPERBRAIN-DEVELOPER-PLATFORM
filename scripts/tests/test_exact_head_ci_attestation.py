from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import build_exact_head_ci_attestation as subject  # noqa: E402


SOURCE = "a" * 40
REPOSITORY = "example/project"


def fixtures() -> tuple[dict[str, object], dict[str, object], dict[str, object], dict[str, object]]:
    steps = [
        {"name": "Checkout", "conclusion": "success"},
        {"name": "OAuth boundary unit contract", "conclusion": "success"},
        {"name": "Secret scan", "conclusion": "success"},
    ]
    run = {
        "id": 123,
        "run_attempt": 1,
        "head_sha": SOURCE,
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
    return run, jobs, repository, branch


class ExactHeadCiAttestationTests(unittest.TestCase):
    def test_accepts_complete_exact_head_readback(self) -> None:
        run, jobs, repository, branch = fixtures()
        value = subject.build_attestation(
            expected_repository=REPOSITORY,
            expected_source_sha=SOURCE,
            run=run,
            jobs_payload=jobs,
            repository=repository,
            branch=branch,
        )
        self.assertEqual(value["source_commit_sha"], SOURCE)
        self.assertEqual(value["failed_job_count"], 0)
        self.assertEqual(value["skipped_job_count"], 0)
        self.assertTrue(value["branch_protection_verified"])
        self.assertTrue(value["secret_scan_verified"])
        self.assertTrue(value["oauth_regression_verified"])

    def test_rejects_source_skipped_step_and_unprotected_default(self) -> None:
        mutations = (
            ("exact-head", lambda r, _j, _repo, _b: r.__setitem__("head_sha", "b" * 40)),
            (
                "CI step",
                lambda _r, j, _repo, _b: j["jobs"][0]["steps"][1].__setitem__("conclusion", "skipped"),
            ),
            ("not protected", lambda _r, _j, _repo, b: b.__setitem__("protected", False)),
        )
        for expected, mutate in mutations:
            with self.subTest(expected=expected):
                values = [copy.deepcopy(value) for value in fixtures()]
                mutate(*values)
                with self.assertRaisesRegex(subject.AttestationError, expected):
                    subject.build_attestation(
                        expected_repository=REPOSITORY,
                        expected_source_sha=SOURCE,
                        run=values[0],
                        jobs_payload=values[1],
                        repository=values[2],
                        branch=values[3],
                    )


if __name__ == "__main__":
    unittest.main()
