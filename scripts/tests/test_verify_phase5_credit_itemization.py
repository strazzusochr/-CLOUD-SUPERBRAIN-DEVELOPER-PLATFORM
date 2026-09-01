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
        "run_url": f"https://github.com/{verifier.EXPECTED_GITHUB_REPOSITORY}/actions/runs/{RUN_ID}",
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
                f"https://github.com/{verifier.EXPECTED_GITHUB_REPOSITORY}/actions/runs/{RUN_ID}/artifacts/987654321"
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
        "run_url": f"https://github.com/{verifier.EXPECTED_GITHUB_REPOSITORY}/actions/runs/{RUN_ID}",
        "secret_output": False,
        "source_prequalification": True,
    }


def github_source_attestation_readback() -> dict[str, object]:
    artifact_id = 987654321
    repository = verifier.EXPECTED_GITHUB_REPOSITORY
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
    # Mirror the verifier's own canonical set instead of inventing anchor text here. The
    # verifier requires equality, so a hand-written placeholder made every v2 summary test
    # fail on "observed anchors are not canonical" before reaching what it meant to assert.
    anchors = list(verifier.CANONICAL_SUCCESS_ANCHORS[chain])
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
    # The canonical set already carries the five boolean anchors, the playwright count and the
    # service-count line, in the order the verifier compares against. Deriving from it keeps the
    # fixture and the contract in one place; omit_boolean_anchor then removes exactly one line so
    # the rejection tests still exercise a genuinely incomplete log.
    omitted_prefix = (
        f"[phase5-candidate-local] {omit_boolean_anchor}="
        if omit_boolean_anchor is not None
        else None
    )
    anchors = list(verifier.CANONICAL_SUCCESS_ANCHORS["candidate-runtime"])
    # The declared anchor set always stays canonical — omit_boolean_anchor drops the line from
    # the RAW LOG only. That is the fabrication these tests exist to catch: evidence that claims
    # a complete anchor set while the log it hashes does not actually contain it.
    logged_anchors = [
        line
        for line in anchors
        if omitted_prefix is None or not line.startswith(omitted_prefix)
    ]
    extra: list[str] = []
    raw_log_path = (
        f"docs/release-artifacts/{V2_RELEASE_ID}-evidence/raw/candidate-runtime.log"
    )
    raw_log = v2_raw_log("candidate-runtime", command, logged_anchors, extra_lines=extra)
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

    def test_i5_closes_only_after_validated_auth_transition(self) -> None:
        self.assertEqual(
            verifier.expected_blocked_ids(auth_transition_verified=False),
            {"I1", "I5"},
        )
        self.assertEqual(
            verifier.expected_blocked_ids(auth_transition_verified=True),
            {"I1"},
        )
        self.assertEqual(verifier.rounded_binary_percent(18, 19), 95)

    def test_i5_rejects_live_flags_without_the_dedicated_evidence_verifier(self) -> None:
        self.assertFalse(
            verifier.validate_production_auth_transition(
                {
                    "owner_granted": False,
                    "live_verified": False,
                },
                SOURCE_SHA,
            )
        )
        self.assert_rejected(
            lambda: verifier.validate_production_auth_transition(
                {
                    "owner_granted": True,
                    "live_verified": True,
                    "paid_provider": False,
                    "owner_grant_ref": "owner-approved-auth-scope",
                    "provider": "github_oauth",
                    "verifier": "",
                },
                SOURCE_SHA,
            ),
            "dedicated non-mutating verifier",
        )

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
                "run_url": f"https://github.com/{verifier.EXPECTED_GITHUB_REPOSITORY}/actions/runs/{RUN_ID}",
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
                    "run_url": f"https://github.com/{verifier.EXPECTED_GITHUB_REPOSITORY}/actions/runs/{RUN_ID}",
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

    def test_pr_check_installs_stateful_runtime_before_oauth_boundary(self) -> None:
        source = (REPO_ROOT / ".github" / "workflows" / "pr-check.yml").read_text(
            encoding="utf-8"
        )
        install = "npm ci --ignore-scripts --prefix services/cloudflare-stateful-runtime"
        oauth = "run: npm run verify:oauth-boundary"
        stateful_test = "run: npm test --prefix services/cloudflare-stateful-runtime"

        self.assertEqual(source.count(install), 1)
        self.assertEqual(source.count(oauth), 1)
        self.assertEqual(source.count(stateful_test), 1)
        self.assertLess(source.index(install), source.index(oauth))
        self.assertLess(source.index(oauth), source.index(stateful_test))

    def test_candidate_runtime_accepts_only_exact_no_credit_requalification_truth(self) -> None:
        source = (
            REPO_ROOT / "scripts" / "verify-phase5-production-candidate-local.ps1"
        ).read_text(encoding="utf-8-sig")

        no_credit_start = source.index("$noCreditRequalificationPaths = @(")
        no_credit_end = source.index("  # Compare the candidate tree with the index.", no_credit_start)
        no_credit_paths = source[no_credit_start:no_credit_end]
        for path in (
            '"PROJECT_STATE.md"',
            '"apps/frontend/lib/endpoint-snapshot.json"',
            '"apps/frontend/lib/platform.ts"',
            '"docs/project-progress.manifest.json"',
            '"docs/runtime-state/external-gate-summary.json"',
        ):
            self.assertIn(path, no_credit_paths)

        for marker in (
            "$noCreditRequalificationPaths = @(",
            '"PROJECT_STATE.md"',
            '"apps/frontend/lib/endpoint-snapshot.json"',
            '"docs/runtime-state/external-gate-summary.json"',
            "$isNoCreditRequalification = Test-ExactPathSet",
            "$noCreditRequalification = $true",
            "$runtimeSourceMatchesHead -or $qualificationTruthTransition -or $noCreditRequalification",
            'Assert-Equal "no-credit candidate source"',
            'Assert-Equal "no-credit external selector"',
            'Assert-Equal "no-credit snapshot source"',
            'Assert-Equal "no-credit manifest last_verified"',
            'Assert-Equal "no-credit manifest immutable projection"',
            'Assert-Equal "no-credit platform snapshot mirror"',
            'Assert-False "no-credit production rollout"',
            "$candidateConfigText = Get-Content",
            "$candidateUpdatedAtText = $Matches[1]",
            "[Globalization.CultureInfo]::InvariantCulture",
            "[Globalization.DateTimeStyles]::RoundtripKind",
            "$evidenceCreditTransition = $false",
            'Assert-True "evidence-credit delta-ledger verifier"',
            "$runtimeSourceMatchesHead -or $qualificationTruthTransition -or $noCreditRequalification -or $evidenceCreditTransition",
        ):
            self.assertIn(marker, source)

        self.assertNotIn("$runtimeChangedPaths.Count -eq 3", source)
        self.assertNotIn(
            "[DateTimeOffset]::Parse([string]$candidateConfig.updated_at)", source
        )

        current = (REPO_ROOT / "scripts" / "verify-current-release-candidate.ps1").read_text(
            encoding="utf-8-sig"
        )
        current_start = current.index("$noCreditRequalificationPaths = @(")
        current_end = current.index("function Test-ExactPathSet", current_start)
        current_paths = current[current_start:current_end]
        for path in (
            '"PROJECT_STATE.md"',
            '"apps/frontend/lib/endpoint-snapshot.json"',
            '"apps/frontend/lib/platform.ts"',
            '"docs/project-progress.manifest.json"',
            '"docs/runtime-state/external-gate-summary.json"',
        ):
            self.assertIn(path, current_paths)
        for marker in (
            "$noCreditRequalificationSameDayPaths = @(",
            '"PROJECT_STATE.md"',
            '"apps/frontend/lib/endpoint-snapshot.json"',
            '"docs/runtime-state/external-gate-summary.json"',
            "$isNoCreditRequalificationSameDay = Test-ExactPathSet",
            "$isNoCreditRequalification = $isNoCreditRequalification -or $isNoCreditRequalificationSameDay",
            "$evidenceCreditTransition = $false",
            "evidence_credit_transition=",
        ):
            self.assertIn(marker, current)
        self.assertIn("scripts\\verify_phase5_credit_itemization.py", current)

    def test_pr_check_prequalification_accepts_only_clean_or_exact_post_selection_manifest_drift(self) -> None:
        source = (REPO_ROOT / ".github" / "workflows" / "pr-check.yml").read_text(
            encoding="utf-8"
        )
        step_start = source.index("      - name: Project progress delta-ledger replay regression")
        step_end = source.index("      - name: Phase 3 and Phase 6 draft credit rubric integrity", step_start)
        step = source[step_start:step_end]
        expected_drift = (
            "[phase5-credit] active candidate has committed or staged runtime-source drift "
            "outside the exact post-qualification or no-credit requalification truth transition\\n"
            "[project-progress] Phase-5 credit itemization is invalid"
        )

        self.assertIn(
            "SOURCE_PREQUALIFICATION: ${{ steps.source-binding.outputs.source_prequalification }}",
            step,
        )
        self.assertIn("set -euo pipefail", step)
        self.assertIn(f"expected_progress_drift=$'{expected_drift}'", step)
        self.assertIn('progress_output="$(python scripts/verify_project_progress_manifest.py 2>&1)"', step)
        self.assertIn("progress_exit=$?", step)
        self.assertIn('case "$progress_exit" in', step)
        self.assertIn("source_truth_clean=true", step)
        self.assertIn('if [[ "$progress_output" != "$expected_progress_drift" ]]; then', step)
        self.assertIn("unexpected project-progress exit", step)
        self.assertEqual(step.count("python scripts/verify_project_progress_manifest.py"), 2)
        self.assertNotIn("python scripts/verify_project_progress_manifest.py || true", step)

        unit_index = step.index("python -m unittest scripts.tests.test_verify_project_progress_manifest -v")
        branch_index = step.index('if [[ "$SOURCE_PREQUALIFICATION" == "true" ]]; then')
        endpoint_index = step.index("node --test scripts/tests/endpoint-snapshot-metadata.test.mjs")
        self.assertLess(unit_index, branch_index)
        self.assertGreater(endpoint_index, step.rindex("          fi"))

        transition = (REPO_ROOT / "scripts" / "verify-main-deploy-transition.ps1").read_text(
            encoding="utf-8-sig"
        )
        for marker in (
            "project-progress source prequalification env is bound",
            "project-progress prequalification accepts verifier-clean truth",
            "project-progress prequalification requires exact drift output",
            "project-progress normal validation is retained",
            "project-progress manifest has no blanket bypass",
        ):
            self.assertIn(marker, transition)

    def test_five_axis_prequalification_accepts_only_clean_or_exact_post_selection_manifest_drift(self) -> None:
        source = (REPO_ROOT / ".github" / "workflows" / "pr-check.yml").read_text(
            encoding="utf-8"
        )
        step_start = source.index("      - name: Five-axis delta-ledger integration")
        step_end = source.index("      - name: Backend auth security unit contract", step_start)
        step = source[step_start:step_end]
        expected_drift = (
            "[five-axis-audit] project progress verifier failed via python3: "
            "[phase5-credit] active candidate has committed or staged runtime-source drift "
            "outside the exact post-qualification or no-credit requalification truth transition\\n"
            "[project-progress] Phase-5 credit itemization is invalid"
        )
        negative_pattern = (
            "^(rejects the retired v1 permanent-empty ledger contract without browser evidence|"
            "rejects a structurally typed but unauthenticated v2 ledger entry|"
            "keeps future evidence-backed vertical deltas reachable)$"
        )

        self.assertIn(
            "SOURCE_PREQUALIFICATION: ${{ steps.source-binding.outputs.source_prequalification }}",
            step,
        )
        self.assertIn("set -euo pipefail", step)
        self.assertIn('case "$SOURCE_PREQUALIFICATION" in', step)
        self.assertIn(f"--test-name-pattern='{negative_pattern}'", step)
        self.assertIn(f"expected_five_axis_drift=$'{expected_drift}'", step)
        self.assertIn("await import(\"./scripts/verify-five-axis-substance-audit.mjs\")", step)
        self.assertIn("five_axis_exit=$?", step)
        self.assertIn('case "$five_axis_exit" in', step)
        self.assertIn("source_truth_clean=true", step)
        self.assertIn('if [[ "$five_axis_output" != "$expected_five_axis_drift" ]]; then', step)
        self.assertIn("unexpected five-axis exit", step)
        self.assertIn("            false)", step)
        self.assertIn("            *)", step)
        self.assertIn("unexpected SOURCE_PREQUALIFICATION value", step)
        self.assertEqual(
            step.count("node --test scripts/tests/five-axis-delta-ledger-regression.test.mjs"),
            2,
        )
        self.assertEqual(step.count("node scripts/verify-five-axis-substance-audit.mjs"), 1)
        self.assertNotIn("|| true", step)
        self.assertNotIn("continue-on-error", step)

        transition = (REPO_ROOT / "scripts" / "verify-main-deploy-transition.ps1").read_text(
            encoding="utf-8-sig"
        )
        for marker in (
            "five-axis source prequalification env is bound",
            "five-axis prequalification accepts verifier-clean truth",
            "five-axis prequalification requires exact drift output",
            "five-axis normal validation is retained",
            "five-axis prequalification rejects unexpected mode values",
            "five-axis audit has no blanket bypass",
        ):
            self.assertIn(marker, transition)

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
                    # The verifier rejects the missing line as a canonical-anchor violation.
                    # Match the field name and the exact-line requirement rather than the whole
                    # sentence, so a future rewording cannot silently turn this into a test that
                    # passes for the wrong reason.
                    "canonical anchor must occur as one exact line: "
                    r"\[phase5-candidate-local\] browser_click_verified=true",
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
                "runtime-source drift outside the exact post-qualification or no-credit requalification truth transition",
            )

        self.assertIn("--diff-filter=ACDMRTUXB", captured_args)

    def test_no_credit_requalification_is_exact_source_bound_and_hash_bound(self) -> None:
        source_sha = "c" * 40
        previous_sha = "d" * 40
        release_id = "prod-candidate-2026-08-31-local-rc24"
        previous_release_id = "prod-candidate-2026-08-29-local-rc23"

        def build_fixture(*, same_day: bool = False) -> tuple[
            dict[str, object],
            dict[str, object],
            dict[tuple[str, ...], subprocess.CompletedProcess[str]],
        ]:
            manifest: dict[str, object] = {
                "overall_percent": 89,
                "horizontal": {"items": [{"id": "phase_5", "percent": 89}]},
                "vertical": {"items": []},
                "last_verified": "2026-08-31",
            }
            source_manifest = copy.deepcopy(manifest)
            source_date = "2026-08-31" if same_day else "2026-08-29"
            source_manifest["last_verified"] = source_date
            score = {
                "total_item_count": 19,
                "verified_item_count": 17,
                "blocked_item_count": 2,
                "blocked_item_ids": ["I1", "I5"],
                "computed_percent": 89,
            }
            base_itemization: dict[str, object] = {
                "contract_version": "phase5-credit-itemization-v2",
                "mode": "fully_itemized",
                "credit_blocked_until_candidate_qualified": False,
                "cell_id": "phase_5",
                "checklist_path": "docs/release-checklist.md",
                "rubric": "phase5-release-readiness-19-v2",
                "scoring_rule": "binary",
                "legacy_gap_reconstruction": {"recorded_percent": 68},
                "rulings_applied": {"no_gate_mutation": True},
                "current_score": score,
                "items": [
                    {
                        "id": "I1",
                        "section": "infrastructure",
                        "title": "hosted parity",
                        "status": "blocked_owner",
                        "credit_awarded": False,
                        "blocker_id": "hosted_candidate_parity",
                        "owner_action": "owner",
                        "evidence": [{"path": "old", "claim": "old"}],
                    },
                    {
                        "id": "I5",
                        "section": "infrastructure",
                        "title": "auth",
                        "status": "blocked_owner",
                        "credit_awarded": False,
                        "blocker_id": "production_auth_identity",
                        "owner_action": "owner",
                        "evidence": [{"path": "old", "claim": "old"}],
                    },
                ],
                "retired_noncriteria": [{"marker": "historical", "credit_awarded": False}],
            }
            source_itemization = copy.deepcopy(base_itemization)
            source_itemization.update(
                {
                    "active_release_id": previous_release_id,
                    "active_source_commit_sha": previous_sha,
                    "updated_at_utc": "2026-08-29T11:03:10Z",
                }
            )
            index_itemization = copy.deepcopy(base_itemization)
            index_itemization.update(
                {
                    "active_release_id": release_id,
                    "active_source_commit_sha": source_sha,
                    "updated_at_utc": "2026-08-31T18:00:00Z",
                }
            )
            for item in index_itemization["items"]:  # type: ignore[index]
                item["evidence"] = [{"path": "new", "claim": "new"}]

            source_pointer = {
                "active_release_id": previous_release_id,
                "source_commit_sha": previous_sha,
                "updated_at": "2026-08-29T11:03:10Z",
                "production_rollout_claimed": False,
            }
            index_pointer = {
                "active_release_id": release_id,
                "source_commit_sha": source_sha,
                "updated_at": "2026-08-31T18:00:00Z",
                "production_rollout_claimed": False,
            }
            source_external = {
                "contract_version": "external-gate-summary-v2",
                "source_contract_version": "external-gate-audit-v2",
                "status": "blocked",
                "active_target_gate": "cloudflare_native_zero_card_hosted_runtime",
                "requested_release_candidate_selector": previous_sha,
                "active_release_candidate_sha": "",
                "production_deploy_claim_allowed": False,
                "gate_ids": ["a", "b"],
                "missing_or_failed_gates": ["a", "b"],
            }
            index_external = copy.deepcopy(source_external)
            index_external["requested_release_candidate_selector"] = source_sha
            candidate_artifact = f"release_id: `{release_id}`\nsource_commit_sha: `{source_sha}`\n"
            source_platform = (
                f"/* Project manifest, dated {source_date}. */\n"
                f'export const MANIFEST = {{ snapshot: "{source_date}", overall: 89 }};\n'
            )
            index_platform = (
                "/* Project manifest, dated 2026-08-31. */\n"
                'export const MANIFEST = { snapshot: "2026-08-31", overall: 89 };\n'
            )

            texts = {
                verifier.PROJECT_PROGRESS_MANIFEST_REPO_PATH: json.dumps(manifest),
                verifier.PLATFORM_MANIFEST_REPO_PATH: index_platform,
                verifier.PHASE5_ITEMIZATION_REPO_PATH: json.dumps(index_itemization),
                verifier.CURRENT_RELEASE_CANDIDATE_REPO_PATH: json.dumps(index_pointer),
                verifier.EXTERNAL_GATE_SUMMARY_REPO_PATH: json.dumps(index_external),
                f"docs/release-artifacts/{release_id}.md": candidate_artifact,
                "PROJECT_STATE.md": (
                    "# State\n### Session current\n"
                    f"{release_id} {source_sha} Overall `89%` MARKET_READY:false I1 I5\n"
                    "### Session history\n"
                ),
            }
            snapshot: dict[str, object] = {
                f"/api/v1/test/{index}": {"ok": True} for index in range(33)
            }
            snapshot["/api/v1/project/progress"] = manifest
            snapshot["__snapshot_metadata"] = {
                "contract_version": "endpoint-snapshot-metadata-v1",
                "refresh_scope": "full",
                "payload_epoch_complete": True,
                "current": False,
                "current_reason": "runtime_source_unattested_prequalification",
                "qualification_state": "prequalification",
                "source_scope": "DEV-ONLY",
                "target_scope": "localhost_only",
                "endpoint_count": 34,
                "refreshed_endpoint_count": 34,
                "gate_refresh_atomic": True,
                "active_release_id": release_id,
                "candidate_source_commit_sha": source_sha,
                "runtime_source_commit_sha": None,
                "runtime_source_attested": False,
                "candidate_source_parity": False,
                "current_release_candidate_sha256": verifier.canonical_text_sha256(
                    texts[verifier.CURRENT_RELEASE_CANDIDATE_REPO_PATH]
                ),
                "release_candidate_artifact_sha256": verifier.canonical_text_sha256(candidate_artifact),
                "project_progress_manifest_sha256": verifier.canonical_text_sha256(
                    texts[verifier.PROJECT_PROGRESS_MANIFEST_REPO_PATH]
                ),
                "external_gate_summary_sha256": verifier.canonical_text_sha256(
                    texts[verifier.EXTERNAL_GATE_SUMMARY_REPO_PATH]
                ),
            }
            texts[verifier.ENDPOINT_SNAPSHOT_REPO_PATH] = json.dumps(snapshot)

            responses: dict[tuple[str, ...], subprocess.CompletedProcess[str]] = {}
            source_payloads = {
                verifier.PROJECT_PROGRESS_MANIFEST_REPO_PATH: source_manifest,
                verifier.PHASE5_ITEMIZATION_REPO_PATH: source_itemization,
                verifier.CURRENT_RELEASE_CANDIDATE_REPO_PATH: source_pointer,
                verifier.EXTERNAL_GATE_SUMMARY_REPO_PATH: source_external,
            }
            for path, payload in source_payloads.items():
                args = ("show", f"{source_sha}:{path}")
                responses[args] = subprocess.CompletedProcess(args, 0, json.dumps(payload), "")
            platform_args = ("show", f"{source_sha}:{verifier.PLATFORM_MANIFEST_REPO_PATH}")
            responses[platform_args] = subprocess.CompletedProcess(platform_args, 0, source_platform, "")
            for path, text in texts.items():
                args = ("show", f":{path}")
                responses[args] = subprocess.CompletedProcess(args, 0, text, "")
            return manifest, index_itemization, responses

        def run_fixture(
            manifest: dict[str, object],
            itemization: dict[str, object],
            responses: dict[tuple[str, ...], subprocess.CompletedProcess[str]],
            changed_paths: set[str] | None = None,
        ) -> None:
            selected_paths = changed_paths or verifier.NO_CREDIT_REQUALIFICATION_RUNTIME_PATHS

            def fake_run_git(*args: str) -> subprocess.CompletedProcess[str]:
                if args[:3] == ("diff", "--cached", "--name-only"):
                    return subprocess.CompletedProcess(args, 0, "\0".join(sorted(selected_paths)) + "\0", "")
                return responses.get(args, subprocess.CompletedProcess(args, 1, "", "missing fixture"))

            with patch.object(verifier, "run_git", side_effect=fake_run_git):
                verifier.require_runtime_source_parity(source_sha, manifest, itemization, 89)

        manifest, itemization, responses = build_fixture()
        run_fixture(manifest, itemization, responses)

        same_day_manifest, same_day_itemization, same_day_responses = build_fixture(same_day=True)
        run_fixture(
            same_day_manifest,
            same_day_itemization,
            same_day_responses,
            verifier.NO_CREDIT_REQUALIFICATION_SAME_DAY_RUNTIME_PATHS,
        )

        cross_day_manifest, cross_day_itemization, cross_day_responses = build_fixture()
        self.assert_rejected(
            lambda: run_fixture(
                cross_day_manifest,
                cross_day_itemization,
                cross_day_responses,
                verifier.NO_CREDIT_REQUALIFICATION_SAME_DAY_RUNTIME_PATHS,
            ),
            "same-day no-credit requalification must keep the manifest date unchanged",
        )

        inflated_manifest, inflated_itemization, inflated_responses = build_fixture()
        inflated_itemization["current_score"]["computed_percent"] = 90  # type: ignore[index]
        inflated_responses[("show", f":{verifier.PHASE5_ITEMIZATION_REPO_PATH}")] = subprocess.CompletedProcess(
            (), 0, json.dumps(inflated_itemization), ""
        )
        self.assert_rejected(
            lambda: run_fixture(inflated_manifest, inflated_itemization, inflated_responses),
            "may not change the Phase-5 score, blockers, or rulings",
        )

        bad_hash_manifest, bad_hash_itemization, bad_hash_responses = build_fixture()
        snapshot_key = ("show", f":{verifier.ENDPOINT_SNAPSHOT_REPO_PATH}")
        bad_snapshot = json.loads(bad_hash_responses[snapshot_key].stdout)
        bad_snapshot["__snapshot_metadata"]["current_release_candidate_sha256"] = "0" * 64
        bad_hash_responses[snapshot_key] = subprocess.CompletedProcess((), 0, json.dumps(bad_snapshot), "")
        self.assert_rejected(
            lambda: run_fixture(bad_hash_manifest, bad_hash_itemization, bad_hash_responses),
            "snapshot current_release_candidate_sha256 mismatch",
        )

        extra_manifest, extra_itemization, extra_responses = build_fixture()
        self.assert_rejected(
            lambda: run_fixture(
                extra_manifest,
                extra_itemization,
                extra_responses,
                verifier.NO_CREDIT_REQUALIFICATION_RUNTIME_PATHS | {"apps/frontend/app/page.tsx"},
            ),
            "runtime-source drift outside the exact post-qualification or no-credit requalification truth transition",
        )

    def test_evidence_credited_progress_transition_is_ledger_scored_and_phase5_immutable(self) -> None:
        source_sha = "c" * 40
        evidence_sha = "e" * 40
        release_id = "prod-candidate-2026-09-01-local-rc30"
        baseline = verifier.progress_truth.expected_baseline_projection()

        def as_manifest(projection: dict[str, object]) -> dict[str, object]:
            return {
                "overall_percent": projection["overall_percent"],
                "progress_source": "docs/project-progress.manifest.json",
                "horizontal": {
                    "label": "Phase progress",
                    "items": [
                        {**copy.deepcopy(item), "status": "verified"}
                        for item in projection["horizontal"]  # type: ignore[index]
                    ],
                },
                "vertical": {
                    "label": "Architecture-layer progress",
                    "items": [
                        {**copy.deepcopy(item), "status": "verified"}
                        for item in projection["vertical"]  # type: ignore[index]
                    ],
                },
                "truth_policy": "Evidence-based only",
                "binding_document": "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md",
                "last_verified": "2026-09-01",
                "non_claims": ["No production release."],
            }

        source_manifest = as_manifest(baseline)
        index_manifest = copy.deepcopy(source_manifest)
        next(item for item in index_manifest["vertical"]["items"] if item["id"] == "layer_5")["percent"] = 86  # type: ignore[index]
        itemization = {"mode": "fully_itemized", "current_score": {"computed_percent": 89}}
        source_itemization = copy.deepcopy(itemization)
        manifest_text = json.dumps(index_manifest)
        snapshot = {
            "/api/v1/project/progress": index_manifest,
            "__snapshot_metadata": {
                "active_release_id": release_id,
                "candidate_source_commit_sha": source_sha,
                "runtime_source_attested": False,
                "candidate_source_parity": False,
                "current": False,
                "project_progress_manifest_sha256": verifier.canonical_text_sha256(manifest_text),
            },
        }
        external = {
            "status": "blocked",
            "requested_release_candidate_selector": source_sha,
            "active_release_candidate_sha": "",
            "production_deploy_claim_allowed": False,
        }
        index_payloads = {
            verifier.PROJECT_PROGRESS_MANIFEST_REPO_PATH: index_manifest,
            verifier.PHASE5_ITEMIZATION_REPO_PATH: itemization,
            verifier.PROJECT_PROGRESS_DELTA_LEDGER_REPO_PATH: {
                "contract_version": "project-progress-delta-ledger-v2",
                "entries": [{"source_sha": evidence_sha}],
            },
            verifier.ENDPOINT_SNAPSHOT_REPO_PATH: snapshot,
            verifier.PROJECT_PROGRESS_DELTA_SCHEMA_REPO_PATH: {"type": "object"},
            verifier.CURRENT_RELEASE_CANDIDATE_REPO_PATH: {
                "active_release_id": release_id,
                "source_commit_sha": source_sha,
                "production_rollout_claimed": False,
            },
            verifier.EXTERNAL_GATE_SUMMARY_REPO_PATH: external,
        }
        source_payloads = {
            verifier.PROJECT_PROGRESS_MANIFEST_REPO_PATH: source_manifest,
            verifier.PHASE5_ITEMIZATION_REPO_PATH: source_itemization,
            verifier.EXTERNAL_GATE_SUMMARY_REPO_PATH: copy.deepcopy(external),
        }
        index_texts = {
            verifier.PROJECT_PROGRESS_MANIFEST_REPO_PATH: manifest_text,
            verifier.PLATFORM_MANIFEST_REPO_PATH: "export const MANIFEST = {} as const;\n",
            "PROJECT_STATE.md": (
                "# State\n### Session current\n"
                f"{release_id} {source_sha} Overall `89%` MARKET_READY:false I1 I5\n"
                "### Session history\n"
            ),
        }

        def load_index_json(path: str) -> dict[str, object]:
            return copy.deepcopy(index_payloads[path])

        def load_git_json(_sha: str, path: str) -> dict[str, object]:
            return copy.deepcopy(source_payloads[path])

        def load_index_text(path: str) -> str:
            return index_texts[path]

        with (
            patch.object(verifier, "load_index_json", side_effect=load_index_json),
            patch.object(verifier, "load_git_json", side_effect=load_git_json),
            patch.object(verifier, "load_index_text", side_effect=load_index_text),
            patch.object(
                verifier,
                "run_git",
                return_value=subprocess.CompletedProcess(("git", "diff"), 0, "", ""),
            ),
            patch.object(verifier.progress_truth, "git_commit_is_ancestor", return_value=True),
            patch.object(verifier.progress_truth, "validate_progress_truth") as validate_progress,
        ):
            verifier.require_evidence_credited_progress_transition(
                source_sha,
                index_manifest,
                itemization,
                89,
            )
            validate_progress.assert_called_once()

        inflated = copy.deepcopy(index_manifest)
        next(item for item in inflated["horizontal"]["items"] if item["id"] == "phase_5")["percent"] = 95  # type: ignore[index]
        index_payloads[verifier.PROJECT_PROGRESS_MANIFEST_REPO_PATH] = inflated
        with (
            patch.object(verifier, "load_index_json", side_effect=load_index_json),
            patch.object(verifier, "load_git_json", side_effect=load_git_json),
        ):
            self.assert_rejected(
                lambda: verifier.require_evidence_credited_progress_transition(
                    source_sha,
                    inflated,
                    itemization,
                    89,
                ),
                "may not alter the independently scored Phase-5 percent",
            )


if __name__ == "__main__":
    unittest.main()
