#!/usr/bin/env python3
"""Build an immutable exact-head CI attestation from GitHub API readbacks."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence


CONTRACT_VERSION = "exact-head-ci-attestation-v2"
REQUIRED_STEP_NAMES = {"Secret scan", "OAuth boundary unit contract"}


class AttestationError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AttestationError(message)


def read_object(path: Path, label: str) -> dict[str, Any]:
    require(path.is_file(), f"{label} is missing")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AttestationError(f"{label} is not valid UTF-8 JSON") from exc
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def nonempty(value: Any, label: str) -> str:
    require(isinstance(value, str) and value.strip() == value and value, f"{label} is invalid")
    return value


def build_attestation(
    *,
    expected_repository: str,
    expected_source_sha: str,
    expected_qualification_sha: str,
    run: Mapping[str, Any],
    jobs_payload: Mapping[str, Any],
    repository: Mapping[str, Any],
    branch: Mapping[str, Any],
    source_checkout: Mapping[str, Any],
    source_checkout_sha256: str,
) -> dict[str, Any]:
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", expected_repository) is not None, "repository is invalid")
    require(re.fullmatch(r"[0-9a-f]{40}", expected_source_sha) is not None, "source SHA is invalid")
    require(re.fullmatch(r"[0-9a-f]{40}", expected_qualification_sha) is not None, "qualification SHA is invalid")
    require(expected_source_sha != expected_qualification_sha, "qualification must be a distinct direct child control")
    require(re.fullmatch(r"[0-9a-f]{64}", source_checkout_sha256) is not None, "source checkout hash is invalid")
    require(repository.get("full_name") == expected_repository, "repository identity mismatch")
    default_branch = nonempty(repository.get("default_branch"), "default branch")
    require(branch.get("name") == default_branch, "branch readback is not for the default branch")
    require(branch.get("protected") is True, "default branch is not protected")

    run_id = run.get("id")
    run_attempt = run.get("run_attempt")
    require(type(run_id) is int and run_id > 0, "run id is invalid")
    require(run_attempt == 1, "CI run must be attempt one")
    require(run.get("head_sha") == expected_qualification_sha, "CI run is not exact-head bound to the qualification SHA")
    require(run.get("status") == "completed" and run.get("conclusion") == "success", "CI run did not complete successfully")
    require(run.get("event") in {"workflow_dispatch", "pull_request", "push"}, "CI event is not approved")
    require(run.get("path") == ".github/workflows/pr-check.yml", "CI run used the wrong workflow")
    require(run.get("head_branch") not in {None, ""}, "CI head branch is missing")
    require(run.get("repository", {}).get("full_name") == expected_repository, "CI run repository mismatch")
    run_url = nonempty(run.get("html_url"), "run URL")
    require(run_url.startswith(f"https://github.com/{expected_repository}/actions/runs/"), "run URL mismatch")

    expected_checkout_keys = {
        "binding_mode", "candidate_sha", "checked_out_sha", "contract_version", "control_delta",
        "control_sha", "event_name", "github_actions_artifact_upload", "non_claims",
        "production_deploy", "ref", "registry_publish", "release_promotion", "run_attempt",
        "run_id", "run_sha", "run_url", "secret_output", "source_prequalification",
    }
    require(set(source_checkout) == expected_checkout_keys, "source checkout attestation fields are not exact")
    require(source_checkout.get("contract_version") == "pr-check-source-checkout-attestation-v1", "source checkout contract mismatch")
    require(source_checkout.get("binding_mode") == "source_checkout_attestation_v1", "source checkout binding mode mismatch")
    require(source_checkout.get("candidate_sha") == expected_source_sha, "source checkout candidate mismatch")
    require(source_checkout.get("checked_out_sha") == expected_source_sha, "source checkout did not check out the candidate")
    require(source_checkout.get("control_sha") == expected_qualification_sha, "source checkout control mismatch")
    require(source_checkout.get("run_sha") == expected_qualification_sha, "source checkout run SHA mismatch")
    require(source_checkout.get("control_delta") == ["docs/runtime-state/source-qualification-control.json"], "source checkout control delta mismatch")
    require(source_checkout.get("source_prequalification") is True, "source checkout is not prequalification mode")
    require(source_checkout.get("github_actions_artifact_upload") is True, "source checkout artifact upload claim is false")
    require(source_checkout.get("event_name") == run.get("event"), "source checkout event mismatch")
    require(source_checkout.get("ref") == f"refs/heads/{run.get('head_branch')}", "source checkout ref mismatch")
    require(source_checkout.get("run_id") == run_id and source_checkout.get("run_attempt") == run_attempt, "source checkout run identity mismatch")
    require(source_checkout.get("run_url") == run_url, "source checkout run URL mismatch")
    for field in ("production_deploy", "registry_publish", "release_promotion", "secret_output"):
        require(source_checkout.get(field) is False, f"source checkout {field} must be false")
    expected_non_claims = [
        "This attestation proves only the exact source checkout boundary for this CI run.",
        "This attestation does not convert DEV-ONLY evidence into hosted proof.",
        "This attestation does not claim GHCR publication, production deployment, release promotion, or Owner approval.",
    ]
    require(source_checkout.get("non_claims") == expected_non_claims, "source checkout non-claims mismatch")

    jobs = jobs_payload.get("jobs")
    require(isinstance(jobs, list) and jobs, "CI jobs are missing")
    total_count = jobs_payload.get("total_count")
    require(type(total_count) is int and total_count == len(jobs), "CI job readback is incomplete")
    failed_jobs = [job for job in jobs if isinstance(job, dict) and job.get("conclusion") not in {"success"}]
    skipped_jobs = [job for job in jobs if isinstance(job, dict) and job.get("conclusion") == "skipped"]
    require(not failed_jobs and not skipped_jobs, "CI contains failed, neutral, cancelled, or skipped jobs")

    step_conclusions: dict[str, str] = {}
    skipped_step_count = 0
    non_success_step_count = 0
    for job in jobs:
        require(isinstance(job, dict), "CI job entry is invalid")
        require(job.get("status") == "completed" and job.get("conclusion") == "success", "CI job is not successful")
        steps = job.get("steps")
        require(isinstance(steps, list) and steps, "CI job steps are missing")
        for step in steps:
            require(isinstance(step, dict), "CI step entry is invalid")
            name = nonempty(step.get("name"), "CI step name")
            conclusion = step.get("conclusion")
            require(conclusion == "success", f"CI step is not successful: {name}")
            step_conclusions[name] = str(conclusion)
            if conclusion == "skipped":
                skipped_step_count += 1
            if conclusion != "success":
                non_success_step_count += 1
    require(REQUIRED_STEP_NAMES <= set(step_conclusions), "CI is missing the secret-scan or OAuth regression step")
    require(all(step_conclusions[name] == "success" for name in REQUIRED_STEP_NAMES), "required security steps did not pass")
    require(skipped_step_count == 0 and non_success_step_count == 0, "CI steps contain a skipped or non-success result")

    return {
        "contract_version": CONTRACT_VERSION,
        "status": "verified",
        "repository": expected_repository,
        "default_branch": default_branch,
        "source_commit_sha": expected_source_sha,
        "qualification_commit_sha": expected_qualification_sha,
        "run_head_sha": expected_qualification_sha,
        "source_checkout_attestation_sha256": source_checkout_sha256,
        "source_checkout_binding_mode": "source_checkout_attestation_v1",
        "source_prequalification": True,
        "run_id": run_id,
        "run_attempt": run_attempt,
        "run_url": run_url,
        "workflow_path": ".github/workflows/pr-check.yml",
        "workflow_event": run["event"],
        "head_branch": run["head_branch"],
        "job_count": len(jobs),
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


def write_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    require(path.parent.is_dir(), "CI attestation output parent must already exist")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise AttestationError("CI attestation output already exists") from exc


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--qualification-sha", required=True)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--jobs", type=Path, required=True)
    parser.add_argument("--repository-readback", type=Path, required=True)
    parser.add_argument("--branch-readback", type=Path, required=True)
    parser.add_argument("--source-checkout-attestation", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        source_checkout_bytes = args.source_checkout_attestation.read_bytes()
        value = build_attestation(
            expected_repository=args.repository,
            expected_source_sha=args.source_sha,
            expected_qualification_sha=args.qualification_sha,
            run=read_object(args.run, "workflow run readback"),
            jobs_payload=read_object(args.jobs, "workflow jobs readback"),
            repository=read_object(args.repository_readback, "repository readback"),
            branch=read_object(args.branch_readback, "branch readback"),
            source_checkout=read_object(args.source_checkout_attestation, "source checkout attestation"),
            source_checkout_sha256=hashlib.sha256(source_checkout_bytes).hexdigest(),
        )
        write_exclusive(args.output, value)
    except (AttestationError, OSError, ValueError) as exc:
        print(f"[exact-head-ci-attestation] ERROR: {exc}", file=sys.stderr)
        return 1
    print("[exact-head-ci-attestation] PASS status=verified failed=0 skipped=0 secret_scan=true oauth_regression=true provider_writes=false secret_output=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
