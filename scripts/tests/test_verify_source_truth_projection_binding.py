from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "verify_source_truth_projection_binding.py"
SPEC = importlib.util.spec_from_file_location("binding_verifier", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def run(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return result.stdout.strip()


def write(repo: Path, relative: str, content: str) -> None:
    target = repo / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def manifest(percent: int) -> dict:
    return {
        "overall_percent": percent,
        "horizontal": {"items": [{"id": f"phase_{index}", "percent": percent} for index in range(7)]},
        "vertical": {"items": [{"id": f"layer_{index}", "percent": percent} for index in range(1, 8)]},
    }


def projection_hash(value: dict) -> str:
    projection = {
        "overall_percent": value["overall_percent"],
        "horizontal": [{"id": item["id"], "percent": item["percent"]} for item in value["horizontal"]["items"]],
        "vertical": [{"id": item["id"], "percent": item["percent"]} for item in value["vertical"]["items"]],
    }
    payload = json.dumps(projection, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(payload).hexdigest()


class BindingVerifierTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        run(self.repo, "init", "-q")
        run(self.repo, "config", "user.email", "test@example.invalid")
        run(self.repo, "config", "user.name", "Test")
        write(self.repo, "services/api/main.py", "SOURCE = 'S'\n")
        write(self.repo, "scripts/check.py", "print('S')\n")
        write(self.repo, "apps/frontend/page.tsx", "export default function Page() { return null }\n")
        write(self.repo, "apps/frontend/lib/endpoint-snapshot.json", '{"overall_percent":89}\n')
        write(self.repo, "apps/frontend/lib/platform.ts", "export const overall = 89\n")
        write(self.repo, "PROJECT_STATE.md", "overall 89\n")
        write(self.repo, "docs/project-progress.manifest.json", json.dumps(manifest(89)))
        run(self.repo, "add", ".")
        run(self.repo, "commit", "-qm", "source")
        self.source = run(self.repo, "rev-parse", "HEAD")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def commit_projection(self, include_runtime_drift: bool = False) -> str:
        final = manifest(100)
        write(self.repo, "PROJECT_STATE.md", "overall 100\n")
        write(self.repo, "apps/frontend/lib/endpoint-snapshot.json", '{"overall_percent":100}\n')
        write(self.repo, "apps/frontend/lib/platform.ts", "export const overall = 100\n")
        write(self.repo, "docs/project-progress.manifest.json", json.dumps(final))
        write(self.repo, "docs/runtime-state/evidence.json", '{"status":"verified"}\n')
        if include_runtime_drift:
            write(self.repo, "services/api/main.py", "SOURCE = 'T'\n")
        run(self.repo, "add", ".")
        run(self.repo, "commit", "-qm", "projection")
        return run(self.repo, "rev-parse", "HEAD")

    def commit_receipt(self, projection: str, wrong_runtime: bool = False, mutate_truth: bool = False) -> str:
        final = manifest(100)
        binding = {
            "$schema": "../../runtime-contracts/source-truth-projection-binding.schema.json",
            "contract_version": "source-truth-projection-binding-v1",
            "runtime_candidate_sha": "0" * 40 if wrong_runtime else self.source,
            "truth_projection_sha": projection,
            "truth_projection_sha256": projection_hash(final),
            "source_ancestor_truth_projection": True,
            "production_alias_mutated": False,
        }
        write(self.repo, "docs/runtime-state/source-truth-projection-binding.json", json.dumps(binding))
        write(self.repo, "docs/release-artifacts/browser-receipt.json", '{"status":"verified"}\n')
        if mutate_truth:
            write(self.repo, "apps/frontend/lib/platform.ts", "export const overall = 99\n")
        run(self.repo, "add", ".")
        run(self.repo, "commit", "-qm", "receipt")
        return run(self.repo, "rev-parse", "HEAD")

    def call(self, source: str, projection: str, receipt: str, require_ready: bool = True) -> dict:
        original = MODULE.ROOT
        MODULE.ROOT = self.repo
        try:
            return MODULE.verify(source, projection, receipt, require_ready)
        finally:
            MODULE.ROOT = original

    def test_accepts_source_projection_receipt_chain(self) -> None:
        projection = self.commit_projection()
        receipt = self.commit_receipt(projection)
        report = self.call(self.source, projection, receipt)
        self.assertEqual(report["status"], "verified")
        self.assertFalse(report["runtime_product_drift"])

    def test_rejects_runtime_code_change_after_freeze(self) -> None:
        projection = self.commit_projection(include_runtime_drift=True)
        receipt = self.commit_receipt(projection)
        with self.assertRaisesRegex(MODULE.VerificationError, "non-allowlisted path|runtime product drift"):
            self.call(self.source, projection, receipt)

    def test_rejects_wrong_source_binding(self) -> None:
        projection = self.commit_projection()
        receipt = self.commit_receipt(projection, wrong_runtime=True)
        with self.assertRaisesRegex(MODULE.VerificationError, "runtime_candidate_sha mismatch"):
            self.call(self.source, projection, receipt)

    def test_rejects_truth_mutation_in_receipt(self) -> None:
        projection = self.commit_projection()
        receipt = self.commit_receipt(projection, mutate_truth=True)
        with self.assertRaisesRegex(MODULE.VerificationError, "non-allowlisted path|truth projection"):
            self.call(self.source, projection, receipt)

    def test_rejects_non_100_final_projection(self) -> None:
        write(self.repo, "docs/runtime-state/evidence.json", '{"status":"verified"}\n')
        run(self.repo, "add", ".")
        run(self.repo, "commit", "-qm", "non-final projection")
        projection = run(self.repo, "rev-parse", "HEAD")
        current = manifest(89)
        binding = {
            "$schema": "../../runtime-contracts/source-truth-projection-binding.schema.json",
            "contract_version": "source-truth-projection-binding-v1",
            "runtime_candidate_sha": self.source,
            "truth_projection_sha": projection,
            "truth_projection_sha256": projection_hash(current),
            "source_ancestor_truth_projection": True,
            "production_alias_mutated": False,
        }
        write(self.repo, "docs/runtime-state/source-truth-projection-binding.json", json.dumps(binding))
        run(self.repo, "add", ".")
        run(self.repo, "commit", "-qm", "receipt")
        receipt = run(self.repo, "rev-parse", "HEAD")
        with self.assertRaisesRegex(MODULE.VerificationError, "overall must be 100"):
            self.call(self.source, projection, receipt)


if __name__ == "__main__":
    unittest.main()
