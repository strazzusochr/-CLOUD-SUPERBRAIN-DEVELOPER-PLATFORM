#!/usr/bin/env python3
"""Validate candidate publication receipts offline without awarding release credit."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from build_layer5_registry_release_input import _validate_registry, _validate_review
from collect_ghcr_publication_evidence import VerificationError, _read_json, _require, _sha256, _validate_remote_scan
from verify_ghcr_remote_scan import _manifest_matrix


REPOSITORY = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
RECOVERY_CONTRACT = "ghcr-publication-receipt-recovery-v1"
RECOVERY_KEYS = {
    "candidate_sha",
    "collected_at_utc",
    "contract_version",
    "production_deploy",
    "publication_receipt_sha256",
    "recovery_control_sha",
    "recovery_run_attempt",
    "recovery_run_id",
    "registry_digest_contract_sha256",
    "registry_write_performed",
    "release_promotion",
    "repository",
    "secret_output",
    "source_artifact_digest",
    "source_artifact_id",
    "source_control_sha",
    "source_run_attempt",
    "source_run_id",
    "status",
}


def _field(candidate: str, name: str) -> str:
    values = re.findall(rf"^{re.escape(name)}:\s*`([^`\r\n]+)`\s*$", candidate, re.MULTILINE)
    _require(len(values) == 1, f"candidate {name} must occur exactly once")
    return values[0]


def _positive_integer_string(value: object, context: str) -> str:
    rendered = str(value)
    _require(re.fullmatch(r"[1-9][0-9]*", rendered) is not None, f"{context} must be a positive integer")
    return rendered


def _git_is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    for revision in (ancestor, descendant):
        exists = subprocess.run(
            ["git", "-C", str(root), "cat-file", "-e", f"{revision}^{{commit}}"],
            capture_output=True,
            check=False,
        )
        if exists.returncode != 0:
            return False
    result = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant],
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def _validate_recovery(
    root: Path,
    recovery: dict[str, object],
    *,
    release_id: str,
    source_sha: str,
    control_sha: str,
    review: dict[str, object],
    review_sha: str,
    registry_sha: str,
) -> None:
    _require(set(recovery) == RECOVERY_KEYS, "recovery provenance fields mismatch")
    _require(recovery.get("contract_version") == RECOVERY_CONTRACT, "recovery provenance contract mismatch")
    _require(recovery.get("status") == "verified", "recovery provenance is not verified")
    _require(recovery.get("repository") == REPOSITORY, "recovery repository mismatch")
    _require(recovery.get("candidate_sha") == source_sha, "recovery candidate source mismatch")
    _require(recovery.get("source_control_sha") == control_sha, "recovery source control mismatch")
    _require(recovery.get("source_run_attempt") == 1, "recovery source run attempt mismatch")
    _require(recovery.get("recovery_run_attempt") == 1, "recovery run attempt mismatch")

    source_run_id = _positive_integer_string(recovery.get("source_run_id"), "recovery source_run_id")
    recovery_run_id = _positive_integer_string(recovery.get("recovery_run_id"), "recovery recovery_run_id")
    _require(source_run_id != recovery_run_id, "recovery run must differ from source publication run")
    workflow = review.get("workflow")
    artifact = review.get("artifact")
    _require(isinstance(workflow, dict), "publication review workflow binding is missing")
    _require(isinstance(artifact, dict), "publication review artifact binding is missing")
    _require(str(workflow.get("run_id")) == source_run_id, "recovery source run mismatch")
    _require(workflow.get("run_attempt") == 1, "publication review run attempt mismatch")
    _require(workflow.get("head_sha") == control_sha, "publication review control mismatch")
    _require(workflow.get("candidate_sha") == source_sha, "publication review candidate mismatch")
    _require(str(artifact.get("id")) == _positive_integer_string(recovery.get("source_artifact_id"), "recovery source_artifact_id"), "recovery source artifact id mismatch")
    _require(artifact.get("digest") == recovery.get("source_artifact_digest"), "recovery source artifact digest mismatch")
    _require(re.fullmatch(r"sha256:[0-9a-f]{64}", str(recovery.get("source_artifact_digest"))) is not None, "recovery source artifact digest is invalid")
    _require(recovery.get("publication_receipt_sha256") == review_sha, "recovery publication receipt hash mismatch")
    _require(recovery.get("registry_digest_contract_sha256") == registry_sha, "recovery registry contract hash mismatch")

    collected = recovery.get("collected_at_utc")
    _require(isinstance(collected, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", collected) is not None, "recovery timestamp must be whole-second UTC")
    try:
        datetime.fromisoformat(collected.replace("Z", "+00:00"))
    except ValueError as exc:
        raise VerificationError("recovery timestamp is invalid") from exc

    recovery_control = recovery.get("recovery_control_sha")
    _require(isinstance(recovery_control, str) and re.fullmatch(r"[0-9a-f]{40}", recovery_control) is not None, "recovery control SHA is invalid")
    # The production candidate verifier runs in a Git checkout and therefore
    # must prove ancestry. Unit fixtures and extracted evidence bundles may be
    # Git-less; their hash/run bindings remain fully validated above.
    if (root / ".git").exists():
        _require(_git_is_ancestor(root, control_sha, recovery_control), "recovery control must descend from publication control")
    for field in ("registry_write_performed", "production_deploy", "release_promotion", "secret_output"):
        _require(recovery.get(field) is False, f"recovery {field} non-claim mismatch")


def validate_candidate_registry_receipts(root: Path, candidate_path: Path, release_id: str, source_sha: str) -> str:
    _require(re.fullmatch(r"prod-candidate-[A-Za-z0-9._-]+", release_id) is not None, "invalid expected release id")
    _require(re.fullmatch(r"[0-9a-f]{40}", source_sha) is not None, "invalid expected source SHA")
    candidate = candidate_path.read_text(encoding="utf-8")
    _require(_field(candidate, "release_id") == release_id, "candidate release mismatch")
    _require(_field(candidate, "source_commit_sha") == source_sha, "candidate source mismatch")
    _require(_field(candidate, "immutable_image_commit_sha") == source_sha, "candidate image source mismatch")
    status = _field(candidate, "immutable_tag_publish_status")
    _require(status in {"unpublished", "verified_candidate"}, "unsupported candidate publication status")
    if status == "unpublished":
        return status

    relative_root = f"docs/release-artifacts/{release_id}-evidence/registry"
    evidence_root = (root / relative_root).resolve()
    _require(root.resolve() in evidence_root.parents, "candidate receipt root escapes repository")
    for field, filename in (
        ("registry_publication_review", "registry-publication-review.json"),
        ("registry_digest_contract", "candidate-registry-digests.json"),
        ("registry_receipt_recovery", "receipt-recovery-provenance.json"),
    ):
        _require(_field(candidate, field) == f"{relative_root}/{filename}", f"candidate {field} path mismatch")
    paths = {name: evidence_root / name for name in (
        "ghcr-candidate-manifest.json", "remote-image-scan.json",
        "registry-publication-review.json", "candidate-registry-digests.json",
        "receipt-recovery-provenance.json",
    )}
    for path in paths.values():
        _require(evidence_root in path.resolve().parents, "candidate receipt file escapes evidence directory")
    manifest, manifest_raw = _read_json(paths["ghcr-candidate-manifest.json"], "GHCR manifest")
    manifest_release, manifest_source, control_sha, namespace, matrix = _manifest_matrix(manifest)
    _require((manifest_release, manifest_source) == (release_id, source_sha), "published manifest candidate binding mismatch")
    _require(_field(candidate, "immutable_tag_set") == f"{namespace}/<service>:{source_sha}", "candidate immutable tag set mismatch")
    remote, remote_raw = _read_json(paths["remote-image-scan.json"], "remote image scan")
    _require((remote.get("release_id"), remote.get("source_commit_sha"), remote.get("control_commit_sha")) == (release_id, source_sha, control_sha), "remote scan candidate binding mismatch")
    _validate_remote_scan(remote, paths["remote-image-scan.json"], _sha256(manifest_raw), matrix)
    review, review_raw = _read_json(paths["registry-publication-review.json"], "publication review")
    _validate_review(review, release_id, source_sha, control_sha)
    registry, registry_raw = _read_json(paths["candidate-registry-digests.json"], "candidate registry digests")
    _validate_registry(registry, manifest, remote, review, manifest_sha=_sha256(manifest_raw), remote_sha=_sha256(remote_raw), review_sha=_sha256(review_raw))
    recovery, _ = _read_json(paths["receipt-recovery-provenance.json"], "receipt recovery provenance")
    _validate_recovery(
        root,
        recovery,
        release_id=release_id,
        source_sha=source_sha,
        control_sha=control_sha,
        review=review,
        review_sha=_sha256(review_raw),
        registry_sha=_sha256(registry_raw),
    )
    for field in ("production_deploy", "release_promotion", "secret_output"):
        _require(registry.get(field) is False, f"candidate registry {field} non-claim mismatch")
    return status


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--expected-release-id", required=True)
    parser.add_argument("--expected-source-sha", required=True)
    args = parser.parse_args()
    try:
        status = validate_candidate_registry_receipts(args.repository_root, args.candidate, args.expected_release_id, args.expected_source_sha)
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"[candidate-registry-receipts] ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"[candidate-registry-receipts] status={status} offline=true registry_write=false release_promotion=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
