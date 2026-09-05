from __future__ import annotations

import copy
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import build_phase3_oauth_credit_input as build_p3  # noqa: E402
import build_phase5_market_ready_credit_input as build_p5  # noqa: E402
import build_production_auth_identity_evidence as build_auth  # noqa: E402
import score_phase3_oauth_credit as p3  # noqa: E402
import score_phase5_market_ready_credit as p5  # noqa: E402
from scripts.tests.test_new_progress_credit_scorers import (  # noqa: E402
    CANDIDATE,
    RELEASE,
    digest,
    p3_fixture,
    p5_fixture,
    sha,
)
from scripts.tests.test_production_auth_identity_evidence import (  # noqa: E402
    ProductionAuthIdentityEvidenceTests as _ProductionAuthIdentityEvidenceTests,
    valid_evidence,
)


def write_json(path: Path, value: object) -> bytes:
    raw = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def complete_auth_inputs(root: Path) -> dict[str, Path]:
    _, flow_store, _ = p3_fixture()
    flow_path_key = next(
        key
        for key, value in flow_store.values.items()
        if isinstance(value, dict) and value.get("contract_version") == p3.FLOW_CONTRACT
    )
    flow = copy.deepcopy(flow_store.values[flow_path_key])
    assert isinstance(flow, dict)
    frontend_id = "frontend-deployment-production-1"
    worker_id = "worker-deployment-production-1"
    binding = flow["source_binding"]
    assert isinstance(binding, dict)
    frontend_source_sha = "b" * 40
    binding["frontend_source_commit_sha"] = frontend_source_sha
    binding["frontend_deployment_id_sha256"] = hashlib.sha256(frontend_id.encode()).hexdigest()
    binding["worker_deployment_id_sha256"] = hashlib.sha256(worker_id.encode()).hexdigest()

    runtime = {
        "contract_version": "cloudflare-oauth-hosted-current-v1",
        "status": "verified",
        "architecture": "cloudflare_native",
        "source_commit_sha": CANDIDATE,
        "deployment_id": worker_id,
        "runtime_origin": binding["worker_origin"],
        "provider_writes": False,
        "deployment_writes": False,
        "secret_output": False,
    }
    frontend = {
        "contract_version": "frontend-hosted-current-proof-v1",
        "status": "verified",
        "source_commit_sha": frontend_source_sha,
        "deployment_id": frontend_id,
        "production_alias": binding["frontend_origin"],
        "vercel_target": "production",
        "deployment_metadata_verified": True,
        "deployment_alias_content_parity": True,
        "production_operational_deploy_verified": True,
        "production_release_claimed": False,
    }
    paths = {
        "flow": root / "flow.json",
        "runtime": root / "runtime.json",
        "frontend": root / "frontend.json",
        "architecture": root / "architecture.json",
        "ci": root / "ci.json",
    }
    write_json(paths["flow"], flow)
    write_json(paths["runtime"], runtime)
    write_json(paths["frontend"], frontend)
    architecture = {
        "contract_version": "production-auth-architecture-decision-v1",
        "status": "owner_approved",
        "owner_approved": True,
        "selected_architecture": "cloudflare_native",
        "target": "production",
        "callback_origin": binding["frontend_origin"],
        "source_commit_sha": CANDIDATE,
        "auth_runtime_evidence_ref": paths["runtime"].resolve().relative_to(ROOT).as_posix(),
        "auth_runtime_verifier_ref": "scripts/verify-cloudflare-oauth-hosted-current.ps1",
        "secret_output": False,
    }
    write_json(paths["architecture"], architecture)
    ci = {
        "contract_version": "exact-head-ci-attestation-v2",
        "status": "verified",
        "repository": "example/project",
        "default_branch": "main",
        "source_commit_sha": CANDIDATE,
        "qualification_commit_sha": "c" * 40,
        "run_head_sha": "c" * 40,
        "source_checkout_attestation_sha256": "d" * 64,
        "source_checkout_binding_mode": "source_checkout_attestation_v1",
        "source_prequalification": True,
        "run_id": 123456,
        "run_attempt": 1,
        "run_url": "https://github.com/example/project/actions/runs/123456",
        "workflow_path": ".github/workflows/pr-check.yml",
        "workflow_event": "workflow_dispatch",
        "head_branch": "codex/test",
        "job_count": 1,
        "failed_job_count": 0,
        "skipped_job_count": 0,
        "skipped_step_count": 0,
        "required_checks_passed": True,
        "branch_protection_verified": True,
        "secret_scan_verified": True,
        "oauth_regression_verified": True,
        "api_readback_complete": True,
        "provider_writes": False,
        "secret_output": False,
    }
    write_json(paths["ci"], ci)
    return paths


class ProductionAuthPipelineTests(unittest.TestCase):
    def make_repo_temp(self) -> tempfile.TemporaryDirectory[str]:
        return tempfile.TemporaryDirectory(prefix="auth-pipeline-", dir=ROOT / "scripts" / "tests")

    def test_production_auth_builder_accepts_exact_inputs(self) -> None:
        with self.make_repo_temp() as directory:
            paths = complete_auth_inputs(Path(directory))
            value = build_auth.build_evidence(
                candidate_sha=CANDIDATE,
                flow_path=paths["flow"],
                runtime_path=paths["runtime"],
                frontend_path=paths["frontend"],
                architecture_path=paths["architecture"],
                ci_path=paths["ci"],
            )
        self.assertEqual(value["contract_version"], "production-auth-identity-proof-v1")
        self.assertEqual(value["human_flow_verified_steps"], p3.STEP_NAMES)
        self.assertEqual(value["source_binding"]["frontend_source_commit_sha"], "b" * 40)
        self.assertEqual(value["source_binding"]["qualification_commit_sha"], "c" * 40)
        self.assertRegex(value["source_binding"]["exact_head_ci_attestation_sha256"], r"^[0-9a-f]{64}$")
        self.assertTrue(value["source_parity_verified"])
        self.assertFalse(value["gate_promotion_performed"])

    def test_production_auth_builder_rejects_ci_and_origin_drift(self) -> None:
        with self.make_repo_temp() as directory:
            paths = complete_auth_inputs(Path(directory))
            ci = json.loads(paths["ci"].read_text(encoding="utf-8"))
            ci["skipped_job_count"] = 1
            write_json(paths["ci"], ci)
            with self.assertRaisesRegex(build_auth.EvidenceError, "failed or skipped"):
                build_auth.build_evidence(
                    candidate_sha=CANDIDATE,
                    flow_path=paths["flow"],
                    runtime_path=paths["runtime"],
                    frontend_path=paths["frontend"],
                    architecture_path=paths["architecture"],
                    ci_path=paths["ci"],
                )

        with self.make_repo_temp() as directory:
            paths = complete_auth_inputs(Path(directory))
            ci = json.loads(paths["ci"].read_text(encoding="utf-8"))
            ci["run_head_sha"] = "e" * 40
            write_json(paths["ci"], ci)
            with self.assertRaisesRegex(build_auth.EvidenceError, "run-head mismatch"):
                build_auth.build_evidence(
                    candidate_sha=CANDIDATE,
                    flow_path=paths["flow"],
                    runtime_path=paths["runtime"],
                    frontend_path=paths["frontend"],
                    architecture_path=paths["architecture"],
                    ci_path=paths["ci"],
                )

        with self.make_repo_temp() as directory:
            paths = complete_auth_inputs(Path(directory))
            frontend = json.loads(paths["frontend"].read_text(encoding="utf-8"))
            frontend["production_alias"] = "https://drift.example.vercel.app"
            write_json(paths["frontend"], frontend)
            with self.assertRaisesRegex(build_auth.EvidenceError, "source/origin mismatch"):
                build_auth.build_evidence(
                    candidate_sha=CANDIDATE,
                    flow_path=paths["flow"],
                    runtime_path=paths["runtime"],
                    frontend_path=paths["frontend"],
                    architecture_path=paths["architecture"],
                    ci_path=paths["ci"],
                )

    def test_phase3_and_phase5_input_builders_bind_hashes(self) -> None:
        with self.make_repo_temp() as directory:
            root = Path(directory)
            paths = complete_auth_inputs(root)
            auth = build_auth.build_evidence(
                candidate_sha=CANDIDATE,
                flow_path=paths["flow"],
                runtime_path=paths["runtime"],
                frontend_path=paths["frontend"],
                architecture_path=paths["architecture"],
                ci_path=paths["ci"],
            )
            auth_path = root / "production-auth.json"
            auth_raw = write_json(auth_path, auth)
            capability = {
                "contract_version": p5.CAPABILITY_CONTRACT,
                "gates": {
                    "production_auth_identity": {
                        "owner_granted": True,
                        "live_verified": True,
                        "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O1",
                        "provider": "github-oauth-cloudflare-native",
                        "paid_provider": False,
                        "verifier": p5.AUTH_VERIFIER,
                        "evidence_artifact": auth_path.resolve().relative_to(ROOT).as_posix(),
                        "evidence_sha256": hashlib.sha256(auth_raw).hexdigest(),
                    }
                },
            }
            capability_path = root / "capability.json"
            write_json(capability_path, capability)
            p3_value = build_p3.build_input(
                release_id=RELEASE,
                candidate_sha=CANDIDATE,
                flow_path=paths["flow"],
                production_auth_path=auth_path,
                capability_path=capability_path,
                raw_verifier_path=ROOT / p3.RAW_VERIFIER_PATH,
            )
            self.assertEqual(p3_value["points_awarded"], 56)

            _, p5_store, _ = p5_fixture()
            i1 = next(
                value
                for value in p5_store.values.values()
                if isinstance(value, dict) and value.get("contract_version") == p5.I1_CONTRACT
            )
            i1_path = root / "i1.json"
            write_json(i1_path, i1)
            p5_value = build_p5.build_input(
                release_id=RELEASE,
                candidate_sha=CANDIDATE,
                i1_path=i1_path,
                auth_path=auth_path,
                capability_path=capability_path,
            )
            self.assertEqual(p5_value["verified_item_ids"], ["I1", "I5"])

            bad_capability = copy.deepcopy(capability)
            bad_capability["gates"]["production_auth_identity"]["evidence_sha256"] = "f" * 64
            write_json(capability_path, bad_capability)
            with self.assertRaisesRegex(build_p5.BuildError, "evidence hash mismatch"):
                build_p5.build_input(
                    release_id=RELEASE,
                    candidate_sha=CANDIDATE,
                    i1_path=i1_path,
                    auth_path=auth_path,
                    capability_path=capability_path,
                )

    def test_production_auth_promoter_is_atomic_and_hash_guarded(self) -> None:
        helper = _ProductionAuthIdentityEvidenceTests()
        directory, root = helper.make_repo(valid_evidence())
        with directory:
            shutil.copy2(ROOT / "scripts" / "promote-production-auth-identity-gate.ps1", root / "scripts")
            capability = {
                "contract_version": "capability-gate-state-v1",
                "status": "configured",
                "policy": "only a verifier promotes",
                "gates": {
                    "production_auth_identity": {
                        "owner_granted": True,
                        "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O1",
                        "live_verified": False,
                        "evidence_artifact": "",
                        "verified_at_utc": "",
                        "provider": "",
                        "paid_provider": False,
                        "verifier": "",
                        "note": "owner grant only",
                    },
                    "unrelated": {"live_verified": False, "sentinel": "unchanged"},
                },
                "non_claims": ["fixture"],
            }
            capability_path = root / "docs" / "runtime-state" / "capability-gates.json"
            write_json(capability_path, capability)
            subprocess.run(["git", "add", "scripts", "docs"], cwd=root, check=True)
            subprocess.run(["git", "commit", "--quiet", "-m", "add promoter fixture"], cwd=root, check=True)
            candidate_sha = subprocess.check_output(
                ["git", "rev-list", "--max-parents=0", "HEAD"], cwd=root, text=True
            ).strip()
            command = [
                "pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                str(root / "scripts" / "promote-production-auth-identity-gate.ps1"),
                "-EvidencePath", "evidence/production-auth.json",
                "-ExpectedCandidateSha", candidate_sha,
            ]
            validation = subprocess.run(command + ["-ValidateOnly"], cwd=root, text=True, capture_output=True)
            self.assertEqual(validation.returncode, 0, validation.stderr)
            state_match = re.search(r"capability_state_sha256=([0-9a-f]{64})", validation.stdout)
            gate_match = re.search(r"gate_identity_sha256=([0-9a-f]{64})", validation.stdout)
            self.assertIsNotNone(state_match)
            self.assertIsNotNone(gate_match)
            before_unrelated = copy.deepcopy(capability["gates"]["unrelated"])
            promotion = subprocess.run(
                command
                + [
                    "-Promote",
                    "-ExpectedCapabilityStateSha256", state_match.group(1),  # type: ignore[union-attr]
                    "-ExpectedGateIdentitySha256", gate_match.group(1),  # type: ignore[union-attr]
                ],
                cwd=root,
                text=True,
                capture_output=True,
            )
            self.assertEqual(promotion.returncode, 0, promotion.stderr)
            self.assertIn("status=promoted", promotion.stdout)
            promoted = json.loads(capability_path.read_text(encoding="utf-8"))
            gate = promoted["gates"]["production_auth_identity"]
            self.assertTrue(gate["live_verified"])
            self.assertEqual(gate["owner_grant_ref"], "OWNER_GRANTS_2026-09-02.json::O1")
            self.assertRegex(gate["evidence_sha256"], r"^[0-9a-f]{64}$")
            self.assertEqual(promoted["gates"]["unrelated"], before_unrelated)
            self.assertFalse(any(root.rglob("*.bak")))

    def test_production_auth_promoter_rejects_stale_identity_without_mutation(self) -> None:
        helper = _ProductionAuthIdentityEvidenceTests()
        directory, root = helper.make_repo(valid_evidence())
        with directory:
            shutil.copy2(ROOT / "scripts" / "promote-production-auth-identity-gate.ps1", root / "scripts")
            capability = {
                "contract_version": "capability-gate-state-v1",
                "status": "configured",
                "policy": "only a verifier promotes",
                "gates": {
                    "production_auth_identity": {
                        "owner_granted": True,
                        "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O1",
                        "live_verified": False,
                        "evidence_artifact": "",
                        "verified_at_utc": "",
                        "provider": "",
                        "paid_provider": False,
                        "verifier": "",
                        "note": "owner grant only",
                    }
                },
                "non_claims": ["fixture"],
            }
            capability_path = root / "docs" / "runtime-state" / "capability-gates.json"
            original = write_json(capability_path, capability)
            subprocess.run(["git", "add", "scripts", "docs"], cwd=root, check=True)
            subprocess.run(["git", "commit", "--quiet", "-m", "add promoter fixture"], cwd=root, check=True)
            candidate_sha = subprocess.check_output(
                ["git", "rev-list", "--max-parents=0", "HEAD"], cwd=root, text=True
            ).strip()
            completed = subprocess.run(
                [
                    "pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                    str(root / "scripts" / "promote-production-auth-identity-gate.ps1"),
                    "-EvidencePath", "evidence/production-auth.json",
                    "-ExpectedCandidateSha", candidate_sha,
                    "-ExpectedCapabilityStateSha256", hashlib.sha256(original).hexdigest(),
                    "-ExpectedGateIdentitySha256", "f" * 64,
                    "-Promote",
                ],
                cwd=root,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertEqual(capability_path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
