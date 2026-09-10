#!/usr/bin/env python3
"""Shared fail-closed primitives for project-progress delta scorers.

The helpers deliberately perform only read operations.  Every accepted artifact
is loaded from ``source_sha:path`` in Git and is SHA-256 bound by the ledger
request; working-tree files and live provider state are never trusted here.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import PurePosixPath
from typing import Any, Callable


REQUEST_CONTRACT = "project-progress-delta-scorer-request-v1"
RESULT_CONTRACT = "project-progress-delta-scorer-result-v1"
BINDING_KEYS = (
    "verifier_command",
    "scope",
    "cell_id",
    "source_sha",
    "artifact_path",
    "artifact_sha256",
    "old_percent",
    "new_percent",
    "overall_percent",
    "previous_projection_sha256",
    "projection_sha256",
)
REQUEST_KEYS = {
    "contract_version",
    *BINDING_KEYS,
    "read_only_required",
    "provider_writes_allowed",
    "secret_output_allowed",
}
CURRENT_CANDIDATE_PATH = "docs/release-artifacts/current-release-candidate.json"


class ScoreError(ValueError):
    """Raised when immutable evidence does not satisfy a scorer contract."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ScoreError(message)


def require_exact_keys(value: Any, expected: set[str], context: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{context} must be an object")
    require(set(value) == expected, f"{context} keys mismatch")
    return value


def require_lower_hex(value: Any, length: int, context: str) -> str:
    require(
        isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{length}}}", value) is not None,
        f"{context} must be lowercase hex",
    )
    return value


def require_iso_utc(value: Any, context: str) -> str:
    require(
        isinstance(value, str)
        and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", value) is not None,
        f"{context} must be an ISO UTC timestamp",
    )
    return value


def validate_repo_path(value: Any, context: str) -> str:
    require(isinstance(value, str) and value, f"{context} missing")
    require("\\" not in value and "\x00" not in value, f"{context} must use safe POSIX separators")
    path = PurePosixPath(value)
    require(
        not path.is_absolute()
        and path.as_posix() == value
        and "." not in path.parts
        and ".." not in path.parts
        and re.fullmatch(r"[A-Za-z0-9._/-]+", value) is not None,
        f"{context} is not a normalized repository path",
    )
    return value


def git_blob(source_sha: str, path: str) -> bytes:
    require_lower_hex(source_sha, 40, "source_sha")
    validate_repo_path(path, "artifact path")
    result = subprocess.run(
        ["git", "cat-file", "blob", f"{source_sha}:{path}"],
        check=False,
        capture_output=True,
    )
    require(result.returncode == 0, f"committed evidence missing: {path}")
    return bytes(result.stdout)


def git_is_ancestor(older: str, newer: str) -> bool:
    require_lower_hex(older, 40, "ancestor SHA")
    require_lower_hex(newer, 40, "descendant SHA")
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", older, newer],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def decode_json(blob: bytes, context: str) -> dict[str, Any]:
    try:
        value = json.loads(blob.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ScoreError(f"{context} is invalid JSON") from exc
    require(isinstance(value, dict), f"{context} root must be an object")
    return value


def load_hashed_json(
    source_sha: str,
    path: Any,
    expected_sha256: Any,
    *,
    context: str,
    load_blob: Callable[[str, str], bytes],
) -> tuple[dict[str, Any], bytes]:
    normalized = validate_repo_path(path, f"{context} path")
    expected_hash = require_lower_hex(expected_sha256, 64, f"{context} SHA-256")
    blob = load_blob(source_sha, normalized)
    require(hashlib.sha256(blob).hexdigest() == expected_hash, f"{context} hash mismatch")
    return decode_json(blob, context), blob


def validate_request_artifact(
    request: dict[str, Any],
    *,
    scorer_command: str,
    scope: str,
    cell_id: str,
    old_percent: int,
    new_percent: int,
    load_blob: Callable[[str, str], bytes],
) -> tuple[str, str, dict[str, Any]]:
    require_exact_keys(request, REQUEST_KEYS, "request")
    require(request["contract_version"] == REQUEST_CONTRACT, "request contract mismatch")
    require(request["verifier_command"] == scorer_command, "scorer command mismatch")
    require(request["scope"] == scope and request["cell_id"] == cell_id, "scorer cell mismatch")
    require(
        request["old_percent"] == old_percent and request["new_percent"] == new_percent,
        f"{cell_id} percent transition mismatch",
    )
    require(
        type(request["overall_percent"]) is int and 0 <= request["overall_percent"] <= 100,
        "overall_percent is invalid",
    )
    require(request["read_only_required"] is True, "read-only scorer contract required")
    require(request["provider_writes_allowed"] is False, "provider writes must be forbidden")
    require(request["secret_output_allowed"] is False, "secret output must be forbidden")
    require_lower_hex(request["previous_projection_sha256"], 64, "previous projection SHA-256")
    require_lower_hex(request["projection_sha256"], 64, "projection SHA-256")
    source_sha = require_lower_hex(request["source_sha"], 40, "source_sha")
    artifact_path = validate_repo_path(request["artifact_path"], "artifact_path")
    require(
        artifact_path.startswith(".phase1-artifacts/")
        or artifact_path.startswith("docs/release-artifacts/"),
        "ledger evidence must stay inside an approved evidence root",
    )
    aggregate, _ = load_hashed_json(
        source_sha,
        artifact_path,
        request["artifact_sha256"],
        context="aggregate artifact",
        load_blob=load_blob,
    )
    return source_sha, artifact_path, aggregate


def validate_candidate_pointer(
    *,
    evidence_source_sha: str,
    candidate_source_sha: Any,
    release_id: Any,
    load_blob: Callable[[str, str], bytes],
    is_ancestor: Callable[[str, str], bool],
) -> tuple[str, str]:
    candidate_sha = require_lower_hex(candidate_source_sha, 40, "candidate source SHA")
    require(
        isinstance(release_id, str)
        and re.fullmatch(r"prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+", release_id) is not None,
        "release_id is invalid",
    )
    require(is_ancestor(candidate_sha, evidence_source_sha), "candidate source is not an evidence ancestor")
    pointer = decode_json(load_blob(evidence_source_sha, CURRENT_CANDIDATE_PATH), "current candidate")
    require(pointer.get("active_release_id") == release_id, "current candidate release mismatch")
    require(pointer.get("source_commit_sha") == candidate_sha, "current candidate source mismatch")
    require(pointer.get("production_rollout_claimed") is False, "current candidate may not claim rollout")
    return release_id, candidate_sha


def validate_reference(
    reference: Any,
    *,
    source_sha: str,
    expected_contract: str,
    context: str,
    load_blob: Callable[[str, str], bytes],
) -> tuple[dict[str, Any], str]:
    ref = require_exact_keys(reference, {"contract_version", "path", "sha256"}, context)
    require(ref["contract_version"] == expected_contract, f"{context} contract binding mismatch")
    payload, _ = load_hashed_json(
        source_sha,
        ref["path"],
        ref["sha256"],
        context=context,
        load_blob=load_blob,
    )
    require(payload.get("contract_version") == expected_contract, f"{context} contract mismatch")
    return payload, validate_repo_path(ref["path"], f"{context} path")


def scorer_result(request: dict[str, Any]) -> dict[str, Any]:
    return {
        "contract_version": RESULT_CONTRACT,
        **{key: request[key] for key in BINDING_KEYS},
        "read_only": True,
        "provider_writes": False,
        "secret_output": False,
        "evidence_verified": True,
        "credit_allowed": True,
    }
