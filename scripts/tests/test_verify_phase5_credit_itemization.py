from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import verify_phase5_credit_itemization as verifier


RELEASE_ID = "prod-candidate-2026-07-31-local-rc11"
SOURCE_SHA = "bae3cdc1692e1e99e7f546f72664a3c747958b8c"
V2_RELEASE_ID = "prod-candidate-2026-08-02-local-rc12"
V2_SOURCE_SHA = "a" * 40
CONTROL_SHA = "b" * 40
RUN_ID = 123456789
EVIDENCE_RUN_ID = "12345678-1234-4123-8123-123456789abc"
REPO_ROOT = Path(__file__).resolve().parents[2]


def summary_proof(chain: str, command: str) -> tuple[dict[str, object], dict[str, object]]:
    anchors = ["successful verification anchor"]
    entry: dict[str, object] = {
        "command": command,
        "success_anchors": anchors,
    }
    proof: dict[str, object] = {
        "contract_version": "phase5-local-verification-summary-v1",
        "chain": chain,
        "release_id": RELEASE_ID,
        "source_commit_sha": SOURCE_SHA,
        "command": command,
        "status": "passed",
        "exit_code": 0,
        "dev_only": True,
        "hosted_proof": False,
        "secret_output": False,
        "raw_log_sha256": "A" * 64,
        "observed_success_anchors": anchors,
        "non_claims": [
            "DEV-ONLY; hosted proof still blocked.",
            "This evidence does not claim production readiness.",
        ],
    }
    return proof, entry


def candidate_images_proof() -> dict[str, object]:
    images: list[dict[str, object]] = []
    for index, service in enumerate(sorted(verifier.EXPECTED_CANDIDATE_SERVICES), start=1):
        dockerfile, source_file, embedded_file = verifier.EXPECTED_CANDIDATE_IMAGE_FILES[service]
        images.append(
            {
                "service": service,
                "image_tag": f"cloud-superbrain-production-candidate/{service}:{SOURCE_SHA}",
                "image_id": f"sha256:{index:064x}",
                "image_size_bytes": 1024 + index,
                "dockerfile": dockerfile,
                "dockerfile_sha256": f"{index + 10:064x}",
                "source_file": source_file,
                "embedded_file": embedded_file,
                "source_file_sha256": f"{index + 20:064x}",
                "embedded_file_sha256": f"{index + 20:064x}",
                "oci_revision": SOURCE_SHA,
                "oci_source": verifier.EXPECTED_OCI_SOURCE,
                "oci_version": RELEASE_ID,
            }
        )
    return {
        "contract_version": "phase5-production-candidate-local-v1",
        "evidence_ref": "phase5_local_production_candidate_verified",
        "status": "verified",
        "release_id": RELEASE_ID,
        "source_commit_sha": SOURCE_SHA,
        "source_boundary": "committed_git_archive_only",
        "git_archive_sha256": "b" * 64,
        "service_count": 6,
        "images": images,
        "phase5_progress_before_proof": 68,
        "phase5_progress_after_proof": 68,
        "progress_credit_claimed": False,
        "rollback_target": "c" * 40,
        "rollback_target_source": "active_release_candidate",
        "registry_publish": False,
        "hosted_staging_parity": False,
        "production_deploy": False,
        "release_promotion": False,
        "owner_review_approved": False,
        "secret_output": False,
        "non_claims": [
            "Local image IDs are not GHCR digests.",
            "DEV-ONLY; hosted proof still blocked.",
            "No production deployment or release promotion was performed.",
        ],
    }


def candidate_runtime_proof() -> dict[str, object]:
    return {
        "contract_version": "phase5-production-candidate-local-verification-v1",
        "evidence_ref": "phase5_local_production_candidate_verified",
        "status": "verified",
        "verification_scope": "full_with_browser",
        "release_id": RELEASE_ID,
        "source_commit_sha": SOURCE_SHA,
        "service_count": 6,
        "api_contract_verified": True,
        "local_image_identity_verified": True,
        "embedded_source_hash_parity_verified": True,
        "candidate_runtime_source_parity_verified": True,
        "browser_click_verified": True,
        "rollback_target": "b" * 40,
        "registry_publish": False,
        "hosted_staging_parity": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }


def attested_ci_workflow() -> dict[str, object]:
    return {
        "name": "pr-check",
        "binding_mode": "source_checkout_attestation_v1",
        "run_id": RUN_ID,
        "run_url": f"https://github.com/example/project/actions/runs/{RUN_ID}",
        "head_sha": CONTROL_SHA,
        "control_sha": CONTROL_SHA,
        "candidate_sha": SOURCE_SHA,
        "checked_out_sha": SOURCE_SHA,
        "event_name": "workflow_dispatch",
        "source_prequalification": True,
        "status": "success",
        "attestation": {
            "artifact": (
                f"docs/release-artifacts/{RELEASE_ID}-evidence/"
                "ci-source-checkout-attestation.json"
            ),
            "sha256": "D" * 64,
            "github_artifact_id": 987654321,
            "github_artifact_name": f"pr-check-source-checkout-attestation-{RUN_ID}-1",
            "github_artifact_url": (
                f"https://github.com/example/project/actions/runs/{RUN_ID}/artifacts/987654321"
            ),
            "github_artifact_digest": f"sha256:{'e' * 64}",
        },
        "github_readback": {
            "artifact": (
                f"docs/release-artifacts/{RELEASE_ID}-evidence/"
                "ci-source-checkout-github-readback.json"
            ),
            "sha256": "F" * 64,
        },
    }


def source_checkout_attestation() -> dict[str, object]:
    delta = sorted(verifier.SOURCE_PREQUALIFICATION_CONTROL_PATHS)
    return {
        "binding_mode": "source_checkout_attestation_v1",
        "candidate_sha": SOURCE_SHA,
        "checked_out_sha": SOURCE_SHA,
        "contract_version": "pr-check-source-checkout-attestation-v1",
        "control_delta": delta,
        "control_sha": CONTROL_SHA,
        "event_name": "workflow_dispatch",
        "github_actions_artifact_upload": True,
        "non_claims": [
            "This attestation does not convert DEV-ONLY evidence into hosted proof.",
            "This attestation does not claim production deployment or release promotion.",
        ],
        "production_deploy": False,
        "ref": "refs/heads/feature/source-control",
        "registry_publish": False,
        "release_promotion": False,
        "run_attempt": 1,
        "run_id": RUN_ID,
        "run_sha": CONTROL_SHA,
        "run_url": f"https://github.com/example/project/actions/runs/{RUN_ID}",
        "secret_output": False,
        "source_prequalification": True,
    }


def github_source_attestation_readback() -> dict[str, object]:
    artifact_id = 987654321
    repository = "example/project"
    return {
        "contract_version": "github-actions-source-attestation-readback-v1",
        "repository": repository,
        "run": {
            "id": RUN_ID,
            "run_attempt": 1,
            "event": "workflow_dispatch",
            "status": "completed",
            "conclusion": "success",
            "head_branch": "feature/source-control",
            "head_sha": CONTROL_SHA,
            "html_url": f"https://github.com/{repository}/actions/runs/{RUN_ID}",
        },
        "artifact": {
            "id": artifact_id,
            "name": f"pr-check-source-checkout-attestation-{RUN_ID}-1",
            "expired": False,
            "digest": f"sha256:{'e' * 64}",
            "url": f"https://api.github.com/repos/{repository}/actions/artifacts/{artifact_id}",
            "archive_download_url": (
                f"https://api.github.com/repos/{repository}/actions/artifacts/{artifact_id}/zip"
            ),
            "workflow_run": {
                "id": RUN_ID,
                "head_sha": CONTROL_SHA,
            },
        },
        "downloaded_archive_sha256": "e" * 64,
        "downloaded_attestation_sha256": "D" * 64,
        "secret_output": False,
    }


def sha256_upper(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def write_repo_file(root: Path, relative: str, value: bytes) -> Path:
    target = root / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(value)
    return target


def tracked_git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args, 0, "", "")


def v2_raw_log(
    chain: str,
    command: str,
    anchors: list[str],
    *,
    release_id: str = V2_RELEASE_ID,
    source_sha: str = V2_SOURCE_SHA,
    evidence_run_id: str = EVIDENCE_RUN_ID,
    extra_lines: list[str] | None = None,
    exit_code: int = 0,
) -> bytes:
    lines = [
        "PHASE5_EVIDENCE_RAW_V2",
        f"[phase5-evidence] chain={chain}",
        f"[phase5-evidence] release_id={release_id}",
        f"[phase5-evidence] source_commit_sha={source_sha}",
        f"[phase5-evidence] evidence_run_id={evidence_run_id}",
        f"[phase5-evidence] command={command}",
    ]
    lines.extend(extra_lines or [])
    lines.extend(anchors)
    lines.append(f"[phase5-evidence] exit_code={exit_code}")
    return ("\n".join(lines) + "\n").encode("utf-8")


def v2_summary_fixture(
    root: Path,
    chain: str = "runtime",
    command: str = "npm run verify:runtime",
) -> tuple[dict[str, object], dict[str, object], Path]:
    anchors = ["successful verification anchor"]
    relative = f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/raw/{chain}.log"
    raw = v2_raw_log(chain, command, anchors)
    target = write_repo_file(root, relative, raw)
    raw_sha = sha256_upper(raw)
    entry: dict[str, object] = {
        "command": command,
        "success_anchors": anchors,
        "evidence_run_id": EVIDENCE_RUN_ID,
        "raw_log_path": relative,
        "raw_log_sha256": raw_sha,
    }
    proof: dict[str, object] = {
        "contract_version": "phase5-local-verification-summary-v2",
        "chain": chain,
        "release_id": V2_RELEASE_ID,
        "source_commit_sha": V2_SOURCE_SHA,
        "command": command,
        "status": "passed",
        "exit_code": 0,
        "dev_only": True,
        "hosted_proof": False,
        "secret_output": False,
        "evidence_run_id": EVIDENCE_RUN_ID,
        "raw_log_path": relative,
        "raw_log_sha256": raw_sha,
        "observed_success_anchors": anchors,
        "non_claims": [
            "DEV-ONLY; hosted proof still blocked.",
            "This evidence does not claim production readiness.",
        ],
    }
    return proof, entry, target


def v2_candidate_images_fixture(
    root: Path,
) -> tuple[
    dict[str, object],
    dict[str, object],
    dict[str, bytes],
]:
    command = (
        "pwsh -NoProfile -ExecutionPolicy Bypass -File "
        "scripts/build-phase5-production-candidate-local.ps1"
    )
    anchors = ["[phase5-candidate-local] status=verified service_count=6"]
    raw_log_path = (
        f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/raw/candidate-images.log"
    )
    raw_log = v2_raw_log("candidate-images", command, anchors)
    write_repo_file(root, raw_log_path, raw_log)
    raw_log_sha = sha256_upper(raw_log)
    readiness = {
        "command": command,
        "success_anchors": anchors,
        "evidence_run_id": EVIDENCE_RUN_ID,
        "raw_log_path": raw_log_path,
        "raw_log_sha256": raw_log_sha,
    }

    git_blobs: dict[str, bytes] = {}
    images: list[dict[str, object]] = []
    raw_images: list[dict[str, object]] = []
    raw_root = f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/raw/candidate-images"
    for index, service in enumerate(sorted(verifier.EXPECTED_CANDIDATE_SERVICES), start=1):
        dockerfile, source_file, embedded_file = verifier.EXPECTED_CANDIDATE_IMAGE_FILES[service]
        dockerfile_bytes = f"dockerfile:{service}\n".encode()
        source_bytes = f"source:{service}\n".encode()
        git_blobs[dockerfile] = dockerfile_bytes
        git_blobs[source_file] = source_bytes
        dockerfile_sha = hashlib.sha256(dockerfile_bytes).hexdigest()
        source_sha = hashlib.sha256(source_bytes).hexdigest()
        tag = f"cloud-superbrain-production-candidate/{service}:{V2_SOURCE_SHA}"
        image_id = f"sha256:{index:064x}"
        size = 1000 + index
        inspect = [
            {
                "Id": image_id,
                "Size": size,
                "RepoTags": [tag],
                "Config": {
                    "Labels": {
                        "org.opencontainers.image.revision": V2_SOURCE_SHA,
                        "org.opencontainers.image.version": V2_RELEASE_ID,
                        "org.opencontainers.image.ref.name": V2_RELEASE_ID,
                        "org.opencontainers.image.source": verifier.EXPECTED_OCI_SOURCE,
                    }
                },
            }
        ]
        inspect_bytes = json.dumps(inspect, sort_keys=True).encode()
        inspect_path = f"{raw_root}/{service}-inspect.json"
        write_repo_file(root, inspect_path, inspect_bytes)
        embedded_bytes = f"{source_sha}  {embedded_file}\n".encode()
        embedded_path = f"{raw_root}/{service}-embedded-sha256.txt"
        write_repo_file(root, embedded_path, embedded_bytes)
        raw_image: dict[str, object] = {
            "service": service,
            "inspect": {"path": inspect_path, "sha256": sha256_upper(inspect_bytes)},
            "embedded_hash": {
                "path": embedded_path,
                "sha256": sha256_upper(embedded_bytes),
            },
        }
        frontend_build_id = ""
        if service == "frontend":
            frontend_build_id = "build-123"
            build_bytes = (frontend_build_id + "\n").encode()
            build_path = f"{raw_root}/frontend-build-id.txt"
            write_repo_file(root, build_path, build_bytes)
            raw_image["frontend_build_id"] = {
                "path": build_path,
                "sha256": sha256_upper(build_bytes),
            }
        raw_images.append(raw_image)
        images.append(
            {
                "service": service,
                "image_tag": tag,
                "image_id": image_id,
                "image_size_bytes": size,
                "dockerfile": dockerfile,
                "dockerfile_sha256": dockerfile_sha,
                "source_file": source_file,
                "embedded_file": embedded_file,
                "source_file_sha256": source_sha,
                "embedded_file_sha256": source_sha,
                "oci_revision": V2_SOURCE_SHA,
                "oci_source": verifier.EXPECTED_OCI_SOURCE,
                "oci_version": V2_RELEASE_ID,
                "frontend_build_id": frontend_build_id,
            }
        )

    proof: dict[str, object] = {
        "contract_version": "phase5-production-candidate-local-v2",
        "evidence_ref": "phase5_local_production_candidate_verified",
        "status": "verified",
        "release_id": V2_RELEASE_ID,
        "source_commit_sha": V2_SOURCE_SHA,
        "source_boundary": "committed_git_archive_only",
        "git_archive_sha256": "b" * 64,
        "service_count": 6,
        "images": images,
        "phase5_progress_before_proof": 89,
        "phase5_progress_after_proof": 89,
        "progress_credit_claimed": False,
        "rollback_target": "c" * 40,
        "rollback_target_source": "active_release_candidate",
        "registry_publish": False,
        "hosted_staging_parity": False,
        "production_deploy": False,
        "release_promotion": False,
        "owner_review_approved": False,
        "secret_output": False,
        "command": command,
        "evidence_run_id": EVIDENCE_RUN_ID,
        "raw_log_path": raw_log_path,
        "raw_log_sha256": raw_log_sha,
        "observed_success_anchors": anchors,
        "raw_evidence": {"images": raw_images},
        "non_claims": [
            "Local image IDs are not GHCR digests.",
            "DEV-ONLY; hosted proof still blocked.",
            "No production deployment or release promotion was performed.",
        ],
    }
    return proof, readiness, git_blobs


def v2_candidate_runtime_fixture(
    root: Path,
    *,
    omit_boolean_anchor: str | None = None,
) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    command = "npm run verify:phase5-candidate-local"
    anchors = ["1 passed", "[phase5-candidate-local] status=verified service_count=6"]
    booleans = [
        "api_contract_verified",
        "local_image_identity_verified",
        "embedded_source_hash_parity_verified",
        "candidate_runtime_source_parity_verified",
        "browser_click_verified",
    ]
    extra = [
        f"[phase5-candidate-local] {field}=true"
        for field in booleans
        if field != omit_boolean_anchor
    ]
    raw_log_path = (
        f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/raw/candidate-runtime.log"
    )
    raw_log = v2_raw_log("candidate-runtime", command, anchors, extra_lines=extra)
    write_repo_file(root, raw_log_path, raw_log)
    raw_log_sha = sha256_upper(raw_log)
    readiness: dict[str, object] = {
        "command": command,
        "success_anchors": anchors,
        "evidence_run_id": EVIDENCE_RUN_ID,
        "raw_log_path": raw_log_path,
        "raw_log_sha256": raw_log_sha,
    }

    candidate_images_path = (
        f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/candidate-images.json"
    )
    candidate_images_bytes = json.dumps(
        {
            "contract_version": "phase5-production-candidate-local-v2",
            "release_id": V2_RELEASE_ID,
            "source_commit_sha": V2_SOURCE_SHA,
        },
        sort_keys=True,
    ).encode()
    write_repo_file(root, candidate_images_path, candidate_images_bytes)
    candidate_images_sha = sha256_upper(candidate_images_bytes)
    candidate_images_entry: dict[str, object] = {"sha256": candidate_images_sha}

    api_path = (
        f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/raw/"
        "candidate-runtime-api-contract.json"
    )
    api_bytes = json.dumps(
        {
            "contract_version": "phase5-production-candidate-local-v1",
            "evidence_ref": "phase5_local_production_candidate_verified",
            "service_count": 6,
            "registry_publish": False,
            "hosted_staging_parity": False,
            "production_deploy": False,
            "release_promotion": False,
            "owner_review_approved": False,
            "secret_output": False,
        },
        sort_keys=True,
    ).encode()
    write_repo_file(root, api_path, api_bytes)
    screenshot_path = (
        f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/raw/"
        "candidate-runtime-browser.png"
    )
    screenshot_bytes = b"\x89PNG\r\n\x1a\n" + b"x" * 2048
    write_repo_file(root, screenshot_path, screenshot_bytes)
    proof: dict[str, object] = {
        "contract_version": "phase5-production-candidate-local-verification-v2",
        "evidence_ref": "phase5_local_production_candidate_verified",
        "status": "verified",
        "verification_scope": "full_with_browser",
        "release_id": V2_RELEASE_ID,
        "source_commit_sha": V2_SOURCE_SHA,
        "service_count": 6,
        "api_contract_verified": True,
        "local_image_identity_verified": True,
        "embedded_source_hash_parity_verified": True,
        "candidate_runtime_source_parity_verified": True,
        "browser_click_verified": True,
        "rollback_target": "b" * 40,
        "registry_publish": False,
        "hosted_staging_parity": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
        "command": command,
        "evidence_run_id": EVIDENCE_RUN_ID,
        "raw_log_path": raw_log_path,
        "raw_log_sha256": raw_log_sha,
        "observed_success_anchors": anchors,
        "raw_evidence": {
            "candidate_images": {
                "path": candidate_images_path,
                "sha256": candidate_images_sha,
            },
            "api_contract": {"path": api_path, "sha256": sha256_upper(api_bytes)},
            "browser_screenshot": {
                "path": screenshot_path,
                "sha256": sha256_upper(screenshot_bytes),
                "size_bytes": len(screenshot_bytes),
            },
        },
    }
    return proof, readiness, candidate_images_entry


class Phase5CreditEvidenceTests(unittest.TestCase):
    def assert_rejected(self, callback, expected: str) -> None:
        with self.assertRaisesRegex(SystemExit, expected):
            callback()

    def test_summary_proof_accepts_bound_canonical_runtime(self) -> None:
        proof, entry = summary_proof("runtime", "npm run verify:runtime")
        verifier.validate_summary_proof("runtime", proof, entry, RELEASE_ID, SOURCE_SHA)

    def test_v2_summary_recomputes_tracked_raw_log_and_reads_anchors_from_it(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proof, entry, _ = v2_summary_fixture(root)
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
            ):
                verifier.validate_summary_proof(
                    "runtime",
                    proof,
                    entry,
                    V2_RELEASE_ID,
                    V2_SOURCE_SHA,
                )

    def test_v2_summary_rejects_self_reference_missing_modified_and_untracked_raw_logs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proof, entry, target = v2_summary_fixture(root)
            self_referenced = copy.deepcopy(proof)
            self_referenced["raw_log_path"] = (
                f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/runtime.json"
            )
            write_repo_file(
                root,
                str(self_referenced["raw_log_path"]),
                json.dumps(self_referenced, sort_keys=True).encode(),
            )
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_summary_proof(
                        "runtime",
                        self_referenced,
                        entry,
                        V2_RELEASE_ID,
                        V2_SOURCE_SHA,
                    ),
                    "raw log path mismatch",
                )

                target.unlink()
                self.assert_rejected(
                    lambda: verifier.validate_summary_proof(
                        "runtime", proof, entry, V2_RELEASE_ID, V2_SOURCE_SHA
                    ),
                    "raw log evidence is missing",
                )

                _, _, target = v2_summary_fixture(root)
                target.write_bytes(target.read_bytes() + b"tampered\n")
                self.assert_rejected(
                    lambda: verifier.validate_summary_proof(
                        "runtime", proof, entry, V2_RELEASE_ID, V2_SOURCE_SHA
                    ),
                    "raw log SHA-256 mismatch",
                )

            proof, entry, _ = v2_summary_fixture(root)

            def untracked_git(*args: str) -> subprocess.CompletedProcess[str]:
                if args and args[0] == "ls-files":
                    return subprocess.CompletedProcess(args, 1, "", "not tracked")
                return subprocess.CompletedProcess(args, 0, "", "")

            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=untracked_git),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_summary_proof(
                        "runtime", proof, entry, V2_RELEASE_ID, V2_SOURCE_SHA
                    ),
                    "raw log evidence is not tracked",
                )

    def test_v2_summary_rejects_relabeling_and_nonzero_raw_exit(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proof, entry, _ = v2_summary_fixture(root)
            proof["source_commit_sha"] = "c" * 40
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_summary_proof(
                        "runtime", proof, entry, V2_RELEASE_ID, V2_SOURCE_SHA
                    ),
                    "source SHA mismatch",
                )

            proof, entry, target = v2_summary_fixture(root)
            raw = v2_raw_log(
                "runtime",
                "npm run verify:runtime",
                ["successful verification anchor"],
                exit_code=1,
            )
            target.write_bytes(raw)
            proof["raw_log_sha256"] = sha256_upper(raw)
            entry["raw_log_sha256"] = sha256_upper(raw)
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_summary_proof(
                        "runtime", proof, entry, V2_RELEASE_ID, V2_SOURCE_SHA
                    ),
                    "raw log exit_code binding must occur exactly once",
                )

    def test_ci_workflow_accepts_legacy_direct_head_binding(self) -> None:
        legacy_source = "bae3cdc1692e1e99e7f546f72664a3c747958b8c"
        verifier.validate_ci_workflow(
            {
                "name": "pr-check",
                "run_id": RUN_ID,
                "run_url": f"https://github.com/example/project/actions/runs/{RUN_ID}",
                "head_sha": legacy_source,
                "status": "success",
            },
            RELEASE_ID,
            legacy_source,
        )

    def test_ci_workflow_rejects_unattested_direct_binding_for_new_candidate(self) -> None:
        self.assert_rejected(
            lambda: verifier.validate_ci_workflow(
                {
                    "name": "pr-check",
                    "run_id": RUN_ID,
                    "run_url": f"https://github.com/example/project/actions/runs/{RUN_ID}",
                    "head_sha": SOURCE_SHA,
                    "status": "success",
                },
                "prod-candidate-2026-08-02-local-rc12",
                SOURCE_SHA,
            ),
            "legacy direct binding is not allowed",
        )

    def test_ci_workflow_accepts_fail_closed_source_checkout_attestation(self) -> None:
        workflow = attested_ci_workflow()
        attestation = source_checkout_attestation()
        readback = github_source_attestation_readback()
        delta_text = "\0".join(sorted(verifier.SOURCE_PREQUALIFICATION_CONTROL_PATHS)) + "\0"

        def fake_run_git(*args: str) -> subprocess.CompletedProcess[str]:
            if args and args[0] == "diff":
                return subprocess.CompletedProcess(args, 0, delta_text, "")
            return subprocess.CompletedProcess(args, 0, "", "")

        with (
            patch.object(
                verifier,
                "require_tracked_repo_path",
                side_effect=[
                    workflow["attestation"]["artifact"],
                    workflow["github_readback"]["artifact"],
                ],
            ),
            patch.object(verifier, "sha256_file", side_effect=["D" * 64, "F" * 64]),
            patch.object(verifier, "load_json", side_effect=[attestation, readback]),
            patch.object(verifier, "run_git", side_effect=fake_run_git),
        ):
            verifier.validate_ci_workflow(workflow, RELEASE_ID, SOURCE_SHA)

    def test_ci_workflow_rejects_relabeling_and_non_control_delta(self) -> None:
        relabeled = attested_ci_workflow()
        relabeled["checked_out_sha"] = "c" * 40
        self.assert_rejected(
            lambda: verifier.validate_ci_workflow(relabeled, RELEASE_ID, SOURCE_SHA),
            "checked-out SHA mismatch",
        )

        workflow = attested_ci_workflow()
        attestation = source_checkout_attestation()
        readback = github_source_attestation_readback()
        attestation["control_delta"] = ["services/agent-api/app/main.py"]

        def fake_run_git(*args: str) -> subprocess.CompletedProcess[str]:
            if args and args[0] == "diff":
                return subprocess.CompletedProcess(args, 0, "services/agent-api/app/main.py\0", "")
            return subprocess.CompletedProcess(args, 0, "", "")

        with (
            patch.object(
                verifier,
                "require_tracked_repo_path",
                side_effect=[
                    workflow["attestation"]["artifact"],
                    workflow["github_readback"]["artifact"],
                ],
            ),
            patch.object(verifier, "sha256_file", side_effect=["D" * 64, "F" * 64]),
            patch.object(verifier, "load_json", side_effect=[attestation, readback]),
            patch.object(verifier, "run_git", side_effect=fake_run_git),
        ):
            self.assert_rejected(
                lambda: verifier.validate_ci_workflow(workflow, RELEASE_ID, SOURCE_SHA),
                "control delta contains non-control paths",
            )

    def test_pr_check_prequalification_is_explicit_and_runner_temp_bounded(self) -> None:
        source = (REPO_ROOT / ".github" / "workflows" / "pr-check.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("source_prequalification:", source)
        self.assertIn('event_name != "workflow_dispatch"', source)
        self.assertIn('event_ref.startswith("refs/heads/")', source)
        self.assertIn('os.environ["RUNNER_TEMP"]', source)
        self.assertNotIn("source_prequalification = candidate_sha != control_sha", source)

    def test_summary_proof_rejects_anchor_or_source_relabeling(self) -> None:
        proof, entry = summary_proof("browser", "npm run verify:browser")
        relabeled = copy.deepcopy(proof)
        relabeled["source_commit_sha"] = "b" * 40
        self.assert_rejected(
            lambda: verifier.validate_summary_proof("browser", relabeled, entry, RELEASE_ID, SOURCE_SHA),
            "source SHA mismatch",
        )
        proof["observed_success_anchors"] = ["different successful anchor"]
        self.assert_rejected(
            lambda: verifier.validate_summary_proof("browser", proof, entry, RELEASE_ID, SOURCE_SHA),
            "observed anchors do not match readiness",
        )

    def test_security_summary_requires_both_scanners(self) -> None:
        proof, entry = summary_proof("security", "npm audit --audit-level=moderate")
        self.assert_rejected(
            lambda: verifier.validate_summary_proof("security", proof, entry, RELEASE_ID, SOURCE_SHA),
            "canonical security generator or name npm audit and gitleaks",
        )
        command = "pwsh -File scripts/write-rc11-security-evidence.ps1"
        generator_proof, generator_entry = summary_proof("security", command)
        verifier.validate_summary_proof(
            "security",
            generator_proof,
            generator_entry,
            RELEASE_ID,
            SOURCE_SHA,
        )

    def test_candidate_images_accepts_six_bound_unique_images(self) -> None:
        verifier.validate_candidate_images_proof(candidate_images_proof(), RELEASE_ID, SOURCE_SHA)

    def test_candidate_images_rejects_duplicate_service_and_oci_drift(self) -> None:
        duplicate = candidate_images_proof()
        images = duplicate["images"]
        assert isinstance(images, list)
        assert isinstance(images[0], dict) and isinstance(images[1], dict)
        images[1]["service"] = images[0]["service"]
        self.assert_rejected(
            lambda: verifier.validate_candidate_images_proof(duplicate, RELEASE_ID, SOURCE_SHA),
            "service is duplicated",
        )

        oci_drift = candidate_images_proof()
        drift_images = oci_drift["images"]
        assert isinstance(drift_images, list) and isinstance(drift_images[0], dict)
        drift_images[0]["oci_revision"] = "b" * 40
        self.assert_rejected(
            lambda: verifier.validate_candidate_images_proof(oci_drift, RELEASE_ID, SOURCE_SHA),
            "OCI revision mismatch",
        )

    def test_v2_candidate_images_recomputes_source_and_raw_docker_claims(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proof, entry, git_blobs = v2_candidate_images_fixture(root)
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
                patch.object(verifier, "git_archive_sha256", return_value="b" * 64),
                patch.object(
                    verifier,
                    "load_git_blob",
                    side_effect=lambda _sha, path: git_blobs[path],
                ),
            ):
                verifier.validate_candidate_images_proof(
                    proof,
                    V2_RELEASE_ID,
                    V2_SOURCE_SHA,
                    entry,
                )

    def test_v2_candidate_images_rejects_fabricated_inspect_and_source_hash(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proof, entry, git_blobs = v2_candidate_images_fixture(root)
            raw_images = proof["raw_evidence"]["images"]
            assert isinstance(raw_images, list) and isinstance(raw_images[0], dict)
            inspect_meta = raw_images[0]["inspect"]
            assert isinstance(inspect_meta, dict)
            inspect_target = root / str(inspect_meta["path"])
            inspect = json.loads(inspect_target.read_text())
            inspect[0]["Id"] = f"sha256:{'f' * 64}"
            forged_bytes = json.dumps(inspect, sort_keys=True).encode()
            inspect_target.write_bytes(forged_bytes)
            inspect_meta["sha256"] = sha256_upper(forged_bytes)
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
                patch.object(verifier, "git_archive_sha256", return_value="b" * 64),
                patch.object(
                    verifier,
                    "load_git_blob",
                    side_effect=lambda _sha, path: git_blobs[path],
                ),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_candidate_images_proof(
                        proof, V2_RELEASE_ID, V2_SOURCE_SHA, entry
                    ),
                    "raw image ID mismatch",
                )

            proof, entry, git_blobs = v2_candidate_images_fixture(root)
            images = proof["images"]
            assert isinstance(images, list) and isinstance(images[0], dict)
            images[0]["source_file_sha256"] = "f" * 64
            images[0]["embedded_file_sha256"] = "f" * 64
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
                patch.object(verifier, "git_archive_sha256", return_value="b" * 64),
                patch.object(
                    verifier,
                    "load_git_blob",
                    side_effect=lambda _sha, path: git_blobs[path],
                ),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_candidate_images_proof(
                        proof, V2_RELEASE_ID, V2_SOURCE_SHA, entry
                    ),
                    "source-file SHA-256 cannot be reproduced",
                )

    def test_candidate_runtime_requires_full_browser_click_and_source_parity(self) -> None:
        verifier.validate_candidate_runtime_proof(candidate_runtime_proof(), RELEASE_ID, SOURCE_SHA)
        no_click = candidate_runtime_proof()
        no_click["browser_click_verified"] = False
        self.assert_rejected(
            lambda: verifier.validate_candidate_runtime_proof(no_click, RELEASE_ID, SOURCE_SHA),
            "browser_click_verified must be true",
        )
        no_parity = candidate_runtime_proof()
        no_parity["candidate_runtime_source_parity_verified"] = False
        self.assert_rejected(
            lambda: verifier.validate_candidate_runtime_proof(no_parity, RELEASE_ID, SOURCE_SHA),
            "candidate_runtime_source_parity_verified must be true",
        )

    def test_v2_candidate_runtime_requires_raw_api_image_browser_and_boolean_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proof, entry, image_entry = v2_candidate_runtime_fixture(root)
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
            ):
                verifier.validate_candidate_runtime_proof(
                    proof,
                    V2_RELEASE_ID,
                    V2_SOURCE_SHA,
                    entry,
                    image_entry,
                )

            proof, entry, image_entry = v2_candidate_runtime_fixture(
                root,
                omit_boolean_anchor="browser_click_verified",
            )
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_candidate_runtime_proof(
                        proof,
                        V2_RELEASE_ID,
                        V2_SOURCE_SHA,
                        entry,
                        image_entry,
                    ),
                    "browser_click_verified raw proof anchor is not present",
                )

    def test_v2_candidate_runtime_rejects_boolean_fabrication_in_raw_api(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            proof, entry, image_entry = v2_candidate_runtime_fixture(root)
            raw_evidence = proof["raw_evidence"]
            assert isinstance(raw_evidence, dict)
            api_meta = raw_evidence["api_contract"]
            assert isinstance(api_meta, dict)
            api_target = root / str(api_meta["path"])
            api = json.loads(api_target.read_text())
            api["production_deploy"] = True
            forged = json.dumps(api, sort_keys=True).encode()
            api_target.write_bytes(forged)
            api_meta["sha256"] = sha256_upper(forged)
            with (
                patch.object(verifier, "ROOT", root),
                patch.object(verifier, "run_git", side_effect=tracked_git),
            ):
                self.assert_rejected(
                    lambda: verifier.validate_candidate_runtime_proof(
                        proof,
                        V2_RELEASE_ID,
                        V2_SOURCE_SHA,
                        entry,
                        image_entry,
                    ),
                    "API production_deploy must remain false",
                )

    def test_expected_tracked_evidence_paths_are_exact(self) -> None:
        expected = {
            f"docs/release-artifacts/{RELEASE_ID}-evidence/{filename}"
            for filename in verifier.LOCAL_VERIFICATION_FILES.values()
        }
        self.assertEqual(
            expected,
            {
                f"docs/release-artifacts/{RELEASE_ID}-evidence/runtime.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/browser.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/security.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/candidate-images.json",
                f"docs/release-artifacts/{RELEASE_ID}-evidence/candidate-runtime.json",
            },
        )

    def test_release_readiness_does_not_depend_on_ignored_runtime_artifacts(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-phase5-release-readiness.ps1").read_text(
            encoding="utf-8-sig"
        )
        self.assertNotIn(".phase1-artifacts", source)
        self.assertIn("verify-main-deploy-transition.ps1", source)
        self.assertIn("verify_project_progress_manifest.py", source)

    def test_runtime_source_parity_includes_and_rejects_deletions(self) -> None:
        deleted_path = "apps/frontend/app/page.tsx"
        captured_args: tuple[str, ...] = ()

        def fake_run_git(*args: str) -> subprocess.CompletedProcess[str]:
            nonlocal captured_args
            captured_args = args
            return subprocess.CompletedProcess(args, 0, f"{deleted_path}\0", "")

        with patch.object(verifier, "run_git", side_effect=fake_run_git):
            self.assert_rejected(
                lambda: verifier.require_runtime_source_parity(SOURCE_SHA, {}, {}, 89),
                "runtime-source drift outside the exact post-qualification truth transition",
            )

        self.assertIn("--diff-filter=ACDMRTUXB", captured_args)


if __name__ == "__main__":
    unittest.main()
