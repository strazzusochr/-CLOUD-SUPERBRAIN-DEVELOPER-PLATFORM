from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def write_json(path: Path, value: object) -> bytes:
    raw = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


class RegistryGatePromoterTests(unittest.TestCase):
    def test_registry_gate_promotion_is_hash_guarded_and_atomic(self) -> None:
        with tempfile.TemporaryDirectory(prefix="registry-promoter-") as temporary:
            repo = Path(temporary)
            (repo / "scripts").mkdir()
            shutil.copy2(
                ROOT / "scripts" / "promote-docker-registry-publish-gate.ps1",
                repo / "scripts" / "promote-docker-registry-publish-gate.ps1",
            )
            (repo / "scripts" / "verify_layer5_registry_release_evidence.py").write_text(
                "import sys\n"
                "required = {'--evidence', '--expected-release-id', '--expected-source-sha', "
                "'--expected-control-sha', '--validate-only'}\n"
                "ok = required.issubset(set(sys.argv[1:]))\n"
                "print('[layer5-registry-release-evidence] PASS' if ok else 'invalid')\n"
                "raise SystemExit(0 if ok else 2)\n",
                encoding="utf-8",
            )
            subprocess.run(["git", "init", "--quiet"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "Registry Test"], cwd=repo, check=True)
            (repo / "source.txt").write_text("candidate\n", encoding="utf-8")
            subprocess.run(["git", "add", "source.txt"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "--quiet", "-m", "candidate"], cwd=repo, check=True)
            candidate_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()

            capability = {
                "contract_version": "capability-gate-state-v1",
                "status": "configured",
                "policy": "only a verifier promotes",
                "gates": {
                    "docker_registry_publish": {
                        "owner_granted": True,
                        "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O3:docker_registry_publish",
                        "live_verified": False,
                        "evidence_artifact": "",
                        "verified_at_utc": "",
                        "provider": "ghcr",
                        "paid_provider": False,
                        "verifier": "",
                        "note": "owner grant only",
                    },
                    "unrelated": {"live_verified": False, "sentinel": "unchanged"},
                },
                "non_claims": ["fixture"],
            }
            capability_path = repo / "docs" / "runtime-state" / "capability-gates.json"
            write_json(capability_path, capability)
            subprocess.run(["git", "add", "scripts", "docs"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "--quiet", "-m", "control"], cwd=repo, check=True)
            control_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()

            evidence = {
                "contract_version": "layer5-registry-release-credit-evidence-v1",
                "status": "verified",
                "release_id": "prod-candidate-test-rc1",
                "source_commit_sha": candidate_sha,
                "control_commit_sha": control_sha,
            }
            evidence_path = repo / "evidence" / "layer5.json"
            evidence_raw = write_json(evidence_path, evidence)
            subprocess.run(["git", "add", "evidence"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "--quiet", "-m", "evidence"], cwd=repo, check=True)

            base = [
                "pwsh",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(repo / "scripts" / "promote-docker-registry-publish-gate.ps1"),
                "-EvidencePath",
                "evidence/layer5.json",
                "-ExpectedReleaseId",
                evidence["release_id"],
                "-ExpectedCandidateSha",
                candidate_sha,
                "-ExpectedControlSha",
                control_sha,
            ]
            validation = subprocess.run(base + ["-ValidateOnly"], cwd=repo, text=True, capture_output=True)
            self.assertEqual(validation.returncode, 0, validation.stderr)
            state_match = re.search(r"capability_state_sha256=([0-9a-f]{64})", validation.stdout)
            gate_match = re.search(r"gate_identity_sha256=([0-9a-f]{64})", validation.stdout)
            self.assertIsNotNone(state_match)
            self.assertIsNotNone(gate_match)

            original = capability_path.read_bytes()
            stale = subprocess.run(
                base
                + [
                    "-Promote",
                    "-ExpectedCapabilityStateSha256",
                    "0" * 64,
                    "-ExpectedGateIdentitySha256",
                    gate_match.group(1),  # type: ignore[union-attr]
                ],
                cwd=repo,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(stale.returncode, 0)
            self.assertEqual(capability_path.read_bytes(), original)

            promoted = subprocess.run(
                base
                + [
                    "-Promote",
                    "-ExpectedCapabilityStateSha256",
                    state_match.group(1),  # type: ignore[union-attr]
                    "-ExpectedGateIdentitySha256",
                    gate_match.group(1),  # type: ignore[union-attr]
                ],
                cwd=repo,
                text=True,
                capture_output=True,
            )
            self.assertEqual(promoted.returncode, 0, promoted.stderr)
            self.assertIn("status=promoted", promoted.stdout)
            current = json.loads(capability_path.read_text(encoding="utf-8"))
            gate = current["gates"]["docker_registry_publish"]
            self.assertTrue(gate["live_verified"])
            self.assertEqual(gate["provider"], "ghcr")
            self.assertEqual(gate["evidence_sha256"], hashlib.sha256(evidence_raw).hexdigest())
            self.assertEqual(current["gates"]["unrelated"], capability["gates"]["unrelated"])
            self.assertFalse(any(repo.rglob("*.bak")))


if __name__ == "__main__":
    unittest.main()
