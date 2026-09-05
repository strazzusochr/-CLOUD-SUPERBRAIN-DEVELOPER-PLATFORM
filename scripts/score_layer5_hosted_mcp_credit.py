#!/usr/bin/env python3
"""Fail-closed delta scorer for the verified RC30 hosted MCP credit slice.

The project-progress verifier executes this program with a single JSON request on
stdin.  The scorer reads only Git blobs from the entry's source commit, validates
the Owner-approved rubric, candidate/Owner ancestry, capability gate, aggregate
evidence, and the four immutable hosted verifier reports, then echoes the exact
request bindings in the delta-scorer result contract.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import PurePosixPath
from typing import Any, Callable


REQUEST_CONTRACT = "project-progress-delta-scorer-request-v1"
RESULT_CONTRACT = "project-progress-delta-scorer-result-v1"
SCORER_COMMAND = "python scripts/score_layer5_hosted_mcp_credit.py --score-v1"
AGGREGATE_CONTRACT = "layer5-hosted-mcp-credit-evidence-v1"
AGGREGATE_EVIDENCE_REF = "rc30_hosted_mcp_four_verifiers_credit_bound"
RELEASE_ID = "prod-candidate-2026-09-01-local-rc30"
CANDIDATE_SOURCE_SHA = "9e88f84ac6c4afd78e152b5dc3b5bb08cf636c68"
SOURCE_ARCHIVE_SHA256 = "71e9dafedffdadeb8407e420e9a1cfd685f8a9fabc1266372c3a794f93848599"
SOURCE_BUNDLE_SHA256 = "0c0ffdf5e4ee214d246ed7a4bbdafe866b3f2378a7c920c92b1f982e7d8196d3"
RUBRIC_APPROVAL_SHA = "e87c28a7c6cf32982caa849794042daa53ef022a"
OWNER_GRANT_SHA = RUBRIC_APPROVAL_SHA
OWNER_GRANT_REF = "docs/runtime-state/owner-input-manifest.json#O4.owner_scope_decision"
BASE_URL = "https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev"
REPOSITORY = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
BRANCH = "codex/rc30-hosted-source"
RUBRIC_PATH = "docs/runtime-contracts/layer-credit-rubric.md"
CAPABILITY_PATH = "docs/runtime-state/capability-gates.json"
CURRENT_CANDIDATE_PATH = "docs/release-artifacts/current-release-candidate.json"
EVIDENCE_ROOT = f"docs/release-artifacts/{RELEASE_ID}-evidence/hosted-layer"

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

AGGREGATE_KEYS = {
    "contract_version",
    "status",
    "evidence_ref",
    "checked_at",
    "release_id",
    "candidate_source_commit_sha",
    "candidate_source_archive_sha256",
    "candidate_source_bundle_sha256",
    "rubric_approval_commit",
    "owner_grant_commit_sha",
    "owner_grant_ref",
    "baseline_percent",
    "credited_percent",
    "credit_points_total",
    "criteria",
    "hosted_write_performed",
    "provider_writes",
    "production_deploy",
    "release_promotion",
    "registry_publish_performed",
    "secret_output",
    "non_claims",
}

CRITERION_KEYS = {
    "criterion_id",
    "points",
    "report_path",
    "report_sha256",
    "report_contract",
    "evidence_ref",
}

CRITERIA: dict[str, dict[str, Any]] = {
    "hosted_mcp_write": {
        "points": 10,
        "report_contract": "mcp-hosted-write-evidence-v2",
        "evidence_ref": "hosted_mcp_write_readback_audit_verified",
        "filename": "mcp-hosted-write.json",
    },
    "hosted_mcp_auth_scope": {
        "points": 6,
        "report_contract": "mcp-hosted-auth-scope-evidence-v2",
        "evidence_ref": "hosted_mcp_caller_auth_exact_scope_verified",
        "filename": "mcp-hosted-auth-scope.json",
    },
    "hosted_mcp_timeout_idempotency": {
        "points": 4,
        "report_contract": "mcp-hosted-timeout-idempotency-evidence-v2",
        "evidence_ref": "hosted_mcp_timeout_no_aftereffect_and_idempotency_verified",
        "filename": "mcp-hosted-timeout-idempotency.json",
    },
    "hosted_mcp_audit_readback_rollback": {
        "points": 10,
        "report_contract": "mcp-hosted-audit-readback-rollback-evidence-v2",
        "evidence_ref": "hosted_mcp_audit_readback_and_rollback_verified",
        "filename": "mcp-hosted-audit-readback-rollback.json",
    },
}

COMMON_REPORT_KEYS = {
    "contract_version",
    "evidence_ref",
    "checked_at",
    "base_url",
    "source_commit_sha",
    "source_archive_sha256",
    "source_bundle_sha256",
    "repository",
    "branch",
    "rubric_approval_commit",
    "owner_grant_ref_present",
    "owner_grant_commit_sha",
    "token_environment_variable",
    "token_output",
    "provider_writes",
    "production_deploy",
    "secret_output",
    "status",
    "credit_eligible",
    "live_mcp_writes",
}

REPORT_EXTRA_KEYS: dict[str, set[str]] = {
    "hosted_mcp_write": {
        "write_performed",
        "server_readback_verified",
        "audit_prewrite_persisted",
        "audit_postwrite_persisted",
        "content_sha256",
        "prewrite_audit_event_ref",
        "mcp_audit_event_ref",
    },
    "hosted_mcp_auth_scope": {
        "missing_auth_http_status",
        "invalid_auth_http_status",
        "off_scope_http_status",
        "exact_scope_http_status",
        "caller_authentication_verified",
        "exact_scope_verified",
        "write_performed",
    },
    "hosted_mcp_timeout_idempotency": {
        "timeout_http_status",
        "timeout_audit_event_ref",
        "timeout_no_aftereffect_verified",
        "initial_write_http_status",
        "replay_http_status",
        "content_sha256",
        "idempotency_replay_verified",
        "duplicate_write_count",
    },
    "hosted_mcp_audit_readback_rollback": {
        "write_performed",
        "server_readback_verified",
        "content_sha256",
        "prewrite_audit_event_ref",
        "postwrite_audit_event_ref",
        "audit_readback_verified",
        "rollback_http_status",
        "rollback_audit_event_id",
        "rollback_state_verified",
    },
}

NON_CLAIMS = [
    "L5 credit is limited to the four verified hosted MCP criteria (30 points).",
    "Registry digests, remote scan, candidate SBOM credit, and protected publish workflow remain uncredited.",
    "No production deploy, release promotion, or registry publication was performed.",
    "Raw verifier evidence is immutable, source-bound, and secret-redacted.",
]


class ScoreError(ValueError):
    """Raised for any fail-closed scorer rejection."""


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


def require_iso_utc(value: Any, context: str) -> None:
    require(
        isinstance(value, str)
        and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", value) is not None,
        f"{context} must be an ISO UTC timestamp",
    )


def validate_repo_path(value: Any, context: str) -> str:
    require(isinstance(value, str) and value, f"{context} missing")
    require("\\" not in value, f"{context} must use POSIX separators")
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


def validate_common_report(report: dict[str, Any], criterion_id: str) -> None:
    spec = CRITERIA[criterion_id]
    require_exact_keys(report, COMMON_REPORT_KEYS | REPORT_EXTRA_KEYS[criterion_id], criterion_id)
    require(report["contract_version"] == spec["report_contract"], f"{criterion_id} contract mismatch")
    require(report["evidence_ref"] == spec["evidence_ref"], f"{criterion_id} evidence ref mismatch")
    require_iso_utc(report["checked_at"], f"{criterion_id} checked_at")
    require(report["base_url"] == BASE_URL, f"{criterion_id} base URL mismatch")
    require(report["source_commit_sha"] == CANDIDATE_SOURCE_SHA, f"{criterion_id} source mismatch")
    require(report["source_archive_sha256"] == SOURCE_ARCHIVE_SHA256, f"{criterion_id} archive mismatch")
    require(report["source_bundle_sha256"] == SOURCE_BUNDLE_SHA256, f"{criterion_id} bundle mismatch")
    require(report["repository"] == REPOSITORY, f"{criterion_id} repository mismatch")
    require(report["branch"] == BRANCH, f"{criterion_id} branch mismatch")
    require(report["rubric_approval_commit"] == RUBRIC_APPROVAL_SHA, f"{criterion_id} rubric mismatch")
    require(report["owner_grant_commit_sha"] == OWNER_GRANT_SHA, f"{criterion_id} grant commit mismatch")
    require(report["owner_grant_ref_present"] is True, f"{criterion_id} grant ref not proven")
    require(report["token_environment_variable"] == "AGENT_API_AUTH_TOKEN", f"{criterion_id} token boundary mismatch")
    require(report["token_output"] is False, f"{criterion_id} token output detected")
    require(report["provider_writes"] is False, f"{criterion_id} provider write overclaim")
    require(report["production_deploy"] is False, f"{criterion_id} production deploy overclaim")
    require(report["secret_output"] is False, f"{criterion_id} secret output detected")
    require(report["status"] == "verified", f"{criterion_id} is not verified")
    require(report["credit_eligible"] is True, f"{criterion_id} is not credit eligible")
    require(report["live_mcp_writes"] is True, f"{criterion_id} did not perform its bounded hosted write")


def validate_specific_report(report: dict[str, Any], criterion_id: str) -> None:
    hex64 = re.compile(r"[0-9a-f]{64}")
    if criterion_id == "hosted_mcp_write":
        for key in (
            "write_performed",
            "server_readback_verified",
            "audit_prewrite_persisted",
            "audit_postwrite_persisted",
        ):
            require(report[key] is True, f"hosted_mcp_write {key} is not true")
        for key in ("content_sha256", "prewrite_audit_event_ref", "mcp_audit_event_ref"):
            require(isinstance(report[key], str) and hex64.fullmatch(report[key]), f"hosted_mcp_write {key} invalid")
    elif criterion_id == "hosted_mcp_auth_scope":
        require(
            [report[key] for key in ("missing_auth_http_status", "invalid_auth_http_status", "off_scope_http_status", "exact_scope_http_status")]
            == [401, 401, 403, 200],
            "hosted_mcp_auth_scope status matrix mismatch",
        )
        for key in ("caller_authentication_verified", "exact_scope_verified", "write_performed"):
            require(report[key] is True, f"hosted_mcp_auth_scope {key} is not true")
    elif criterion_id == "hosted_mcp_timeout_idempotency":
        require(report["timeout_http_status"] == 200, "hosted_mcp_timeout_idempotency timeout status mismatch")
        require(report["initial_write_http_status"] == 200, "hosted_mcp_timeout_idempotency initial status mismatch")
        require(report["replay_http_status"] == 200, "hosted_mcp_timeout_idempotency replay status mismatch")
        require(report["timeout_no_aftereffect_verified"] is True, "hosted timeout aftereffect not rejected")
        require(report["idempotency_replay_verified"] is True, "hosted idempotency replay not verified")
        require(report["duplicate_write_count"] == 0, "hosted idempotency duplicate write detected")
        for key in ("timeout_audit_event_ref", "content_sha256"):
            require(isinstance(report[key], str) and hex64.fullmatch(report[key]), f"hosted_mcp_timeout_idempotency {key} invalid")
    elif criterion_id == "hosted_mcp_audit_readback_rollback":
        for key in (
            "write_performed",
            "server_readback_verified",
            "audit_readback_verified",
            "rollback_state_verified",
        ):
            require(report[key] is True, f"hosted_mcp_audit_readback_rollback {key} is not true")
        require(report["rollback_http_status"] == 503, "hosted rollback fail-closed status mismatch")
        require(report["rollback_audit_event_id"] == "", "hosted rollback unexpectedly persisted a post-write audit id")
        for key in ("content_sha256", "prewrite_audit_event_ref", "postwrite_audit_event_ref"):
            require(isinstance(report[key], str) and hex64.fullmatch(report[key]), f"hosted_mcp_audit_readback_rollback {key} invalid")
    else:  # pragma: no cover - guarded by the exact criterion map
        raise ScoreError("unsupported criterion")


def score_request(
    request: dict[str, Any],
    *,
    load_blob: Callable[[str, str], bytes] = git_blob,
    is_ancestor: Callable[[str, str], bool] = git_is_ancestor,
) -> dict[str, Any]:
    require_exact_keys(request, REQUEST_KEYS, "request")
    require(request["contract_version"] == REQUEST_CONTRACT, "request contract mismatch")
    require(request["verifier_command"] == SCORER_COMMAND, "scorer command mismatch")
    require(request["scope"] == "vertical" and request["cell_id"] == "layer_5", "scorer cell mismatch")
    require(request["old_percent"] == 56 and request["new_percent"] == 86, "L5 percent transition mismatch")
    require(request["overall_percent"] == 89, "vertical credit must not alter overall percent")
    require(request["read_only_required"] is True, "read-only scorer contract required")
    require(request["provider_writes_allowed"] is False, "provider writes must be forbidden")
    require(request["secret_output_allowed"] is False, "secret output must be forbidden")
    source_sha = require_lower_hex(request["source_sha"], 40, "source_sha")
    artifact_path = validate_repo_path(request["artifact_path"], "artifact_path")
    require(
        artifact_path == f"{EVIDENCE_ROOT}/layer5-hosted-mcp-credit.json",
        "unexpected L5 aggregate artifact path",
    )
    artifact_bytes = load_blob(source_sha, artifact_path)
    require(
        hashlib.sha256(artifact_bytes).hexdigest() == require_lower_hex(request["artifact_sha256"], 64, "artifact_sha256"),
        "aggregate artifact hash mismatch",
    )
    aggregate = require_exact_keys(decode_json(artifact_bytes, "aggregate"), AGGREGATE_KEYS, "aggregate")
    require(aggregate["contract_version"] == AGGREGATE_CONTRACT, "aggregate contract mismatch")
    require(aggregate["status"] == "verified", "aggregate is not verified")
    require(aggregate["evidence_ref"] == AGGREGATE_EVIDENCE_REF, "aggregate evidence ref mismatch")
    require_iso_utc(aggregate["checked_at"], "aggregate checked_at")
    require(aggregate["release_id"] == RELEASE_ID, "aggregate release mismatch")
    require(aggregate["candidate_source_commit_sha"] == CANDIDATE_SOURCE_SHA, "aggregate candidate source mismatch")
    require(aggregate["candidate_source_archive_sha256"] == SOURCE_ARCHIVE_SHA256, "aggregate archive mismatch")
    require(aggregate["candidate_source_bundle_sha256"] == SOURCE_BUNDLE_SHA256, "aggregate bundle mismatch")
    require(aggregate["rubric_approval_commit"] == RUBRIC_APPROVAL_SHA, "aggregate rubric mismatch")
    require(aggregate["owner_grant_commit_sha"] == OWNER_GRANT_SHA, "aggregate grant commit mismatch")
    require(aggregate["owner_grant_ref"] == OWNER_GRANT_REF, "aggregate grant ref mismatch")
    require(aggregate["baseline_percent"] == 56, "aggregate baseline mismatch")
    require(aggregate["credited_percent"] == 86, "aggregate credited percent mismatch")
    require(aggregate["credit_points_total"] == 30, "aggregate credit total mismatch")
    require(aggregate["hosted_write_performed"] is True, "aggregate hosted write not proven")
    for key in ("provider_writes", "production_deploy", "release_promotion", "registry_publish_performed", "secret_output"):
        require(aggregate[key] is False, f"aggregate {key} must be false")
    require(aggregate["non_claims"] == NON_CLAIMS, "aggregate non-claims mismatch")
    require(is_ancestor(RUBRIC_APPROVAL_SHA, CANDIDATE_SOURCE_SHA), "rubric approval is not a candidate ancestor")
    require(is_ancestor(OWNER_GRANT_SHA, CANDIDATE_SOURCE_SHA), "Owner grant is not a candidate ancestor")
    require(is_ancestor(CANDIDATE_SOURCE_SHA, source_sha), "candidate source is not an evidence ancestor")

    approved_rubric = load_blob(RUBRIC_APPROVAL_SHA, RUBRIC_PATH)
    candidate_rubric = load_blob(CANDIDATE_SOURCE_SHA, RUBRIC_PATH)
    require(approved_rubric == candidate_rubric, "approved rubric blob drift")
    rubric_text = approved_rubric.decode("utf-8")
    require(re.search(r"(?m)^Status:\s*`APPROVED`\s*$", rubric_text) is not None, "rubric is not approved")
    require(re.search(r"(?m)^Credit-Anwendung erlaubt:\s*`true`\s*$", rubric_text) is not None, "rubric credit is disabled")

    current = decode_json(load_blob(source_sha, CURRENT_CANDIDATE_PATH), "current candidate")
    require(current.get("active_release_id") == RELEASE_ID, "current candidate release mismatch")
    require(current.get("source_commit_sha") == CANDIDATE_SOURCE_SHA, "current candidate source mismatch")

    candidate_gates = decode_json(load_blob(CANDIDATE_SOURCE_SHA, CAPABILITY_PATH), "candidate capability gates")
    grant_gates = decode_json(load_blob(OWNER_GRANT_SHA, CAPABILITY_PATH), "grant capability gates")
    for context, state in (("candidate", candidate_gates), ("grant", grant_gates)):
        require(state.get("contract_version") == "capability-gate-state-v1", f"{context} gate contract mismatch")
        gate = state.get("gates", {}).get("live_mcp_writes", {})
        require(gate.get("owner_granted") is True, f"{context} MCP Owner gate closed")
        require(gate.get("owner_grant_ref") == OWNER_GRANT_REF, f"{context} MCP grant ref mismatch")
    require(
        candidate_gates["gates"]["live_mcp_writes"].get("live_verified") is True,
        "candidate MCP live gate is not verified",
    )

    criteria = aggregate["criteria"]
    require(isinstance(criteria, list) and len(criteria) == len(CRITERIA), "aggregate criterion count mismatch")
    observed: set[str] = set()
    total = 0
    for raw in criteria:
        criterion = require_exact_keys(raw, CRITERION_KEYS, "criterion")
        criterion_id = criterion["criterion_id"]
        require(isinstance(criterion_id, str) and criterion_id in CRITERIA, "unsupported L5 criterion")
        require(criterion_id not in observed, "duplicate L5 criterion")
        observed.add(criterion_id)
        spec = CRITERIA[criterion_id]
        expected_path = f"{EVIDENCE_ROOT}/{spec['filename']}"
        require(criterion["points"] == spec["points"], f"{criterion_id} points mismatch")
        require(criterion["report_path"] == expected_path, f"{criterion_id} report path mismatch")
        require(criterion["report_contract"] == spec["report_contract"], f"{criterion_id} report contract binding mismatch")
        require(criterion["evidence_ref"] == spec["evidence_ref"], f"{criterion_id} evidence ref binding mismatch")
        report_bytes = load_blob(source_sha, expected_path)
        require(
            hashlib.sha256(report_bytes).hexdigest() == require_lower_hex(criterion["report_sha256"], 64, f"{criterion_id} report_sha256"),
            f"{criterion_id} report hash mismatch",
        )
        report = decode_json(report_bytes, criterion_id)
        validate_common_report(report, criterion_id)
        validate_specific_report(report, criterion_id)
        total += int(spec["points"])
    require(observed == set(CRITERIA), "aggregate L5 criterion set mismatch")
    require(total == 30 and aggregate["credit_points_total"] == total, "aggregate L5 point sum mismatch")

    return {
        "contract_version": RESULT_CONTRACT,
        **{key: request[key] for key in BINDING_KEYS},
        "read_only": True,
        "provider_writes": False,
        "secret_output": False,
        "evidence_verified": True,
        "credit_allowed": True,
    }


def main(argv: list[str]) -> int:
    if argv != ["--score-v1"]:
        print("[layer5-scorer] unsupported invocation", file=sys.stderr)
        return 2
    try:
        request = json.load(sys.stdin)
        result = score_request(request)
    except (ScoreError, json.JSONDecodeError, UnicodeError, OSError) as exc:
        print(f"[layer5-scorer] rejected: {exc}", file=sys.stderr)
        return 2
    json.dump(result, sys.stdout, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
