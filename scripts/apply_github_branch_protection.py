#!/usr/bin/env python3
"""Apply and verify GitHub branch protection for PATCHED Phase 1.

Requires:
- GITHUB_TOKEN with repo administration rights
- GITHUB_REPOSITORY in owner/name form, or REPOSITORY_OWNER + REPOSITORY_NAME
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_BRANCH_NAME = "main"
EVIDENCE_REF = "branch_protection_verify_contract"


def repository(repo_override: str | None = None) -> str:
    if repo_override and "/" in repo_override:
        return repo_override
    repo = os.environ.get("GITHUB_REPOSITORY")
    if repo and "/" in repo:
        return repo
    owner = os.environ.get("REPOSITORY_OWNER")
    name = os.environ.get("REPOSITORY_NAME")
    if owner and name:
        return f"{owner}/{name}"
    raise SystemExit("GITHUB_REPOSITORY or REPOSITORY_OWNER/REPOSITORY_NAME is required")


def protection_payload() -> dict:
    return {
        "required_status_checks": {
            "strict": True,
            "contexts": [
                "verify",
            ],
        },
        "enforce_admins": False,
        "required_pull_request_reviews": {
            "dismiss_stale_reviews": True,
            "require_code_owner_reviews": False,
            "required_approving_review_count": 1,
            "require_last_push_approval": True,
        },
        "restrictions": None,
        "required_linear_history": False,
        "allow_force_pushes": False,
        "allow_deletions": False,
        "block_creations": False,
        "required_conversation_resolution": True,
        "lock_branch": False,
        "allow_fork_syncing": False,
    }


def expected_settings(payload: dict) -> dict:
    status_checks = payload["required_status_checks"]
    reviews = payload["required_pull_request_reviews"]
    return {
        "required_status_checks.strict": bool(status_checks["strict"]),
        "required_status_checks.contexts": sorted(status_checks.get("contexts") or []),
        "enforce_admins": bool(payload["enforce_admins"]),
        "required_pull_request_reviews.dismiss_stale_reviews": bool(reviews["dismiss_stale_reviews"]),
        "required_pull_request_reviews.require_code_owner_reviews": bool(reviews["require_code_owner_reviews"]),
        "required_pull_request_reviews.required_approving_review_count": int(
            reviews["required_approving_review_count"]
        ),
        "required_pull_request_reviews.require_last_push_approval": bool(reviews["require_last_push_approval"]),
        "restrictions.enabled": payload["restrictions"] is not None,
        "required_linear_history": bool(payload["required_linear_history"]),
        "allow_force_pushes": bool(payload["allow_force_pushes"]),
        "allow_deletions": bool(payload["allow_deletions"]),
        "block_creations": bool(payload["block_creations"]),
        "required_conversation_resolution": bool(payload["required_conversation_resolution"]),
        "lock_branch": bool(payload["lock_branch"]),
        "allow_fork_syncing": bool(payload["allow_fork_syncing"]),
    }


def _enabled(value: object) -> bool:
    if isinstance(value, dict):
        return bool(value.get("enabled", False))
    return bool(value)


def _restrictions_enabled(value: object) -> bool:
    if not value:
        return False
    if isinstance(value, dict):
        return any(bool(value.get(key)) for key in ("users", "teams", "apps"))
    return True


def _status_contexts(value: object) -> list[str]:
    if not isinstance(value, dict):
        return []
    contexts = set(value.get("contexts") or [])
    for check in value.get("checks") or []:
        if isinstance(check, dict):
            context = check.get("context") or check.get("name")
            if context:
                contexts.add(str(context))
    return sorted(contexts)


def actual_settings(response: dict) -> dict:
    reviews = response.get("required_pull_request_reviews") or {}
    return {
        "required_status_checks.strict": bool((response.get("required_status_checks") or {}).get("strict")),
        "required_status_checks.contexts": _status_contexts(response.get("required_status_checks")),
        "enforce_admins": _enabled(response.get("enforce_admins")),
        "required_pull_request_reviews.dismiss_stale_reviews": bool(reviews.get("dismiss_stale_reviews")),
        "required_pull_request_reviews.require_code_owner_reviews": bool(reviews.get("require_code_owner_reviews")),
        "required_pull_request_reviews.required_approving_review_count": int(
            reviews.get("required_approving_review_count") or 0
        ),
        "required_pull_request_reviews.require_last_push_approval": bool(reviews.get("require_last_push_approval")),
        "restrictions.enabled": _restrictions_enabled(response.get("restrictions")),
        "required_linear_history": _enabled(response.get("required_linear_history")),
        "allow_force_pushes": _enabled(response.get("allow_force_pushes")),
        "allow_deletions": _enabled(response.get("allow_deletions")),
        "block_creations": _enabled(response.get("block_creations")),
        "required_conversation_resolution": _enabled(response.get("required_conversation_resolution")),
        "lock_branch": _enabled(response.get("lock_branch")),
        "allow_fork_syncing": _enabled(response.get("allow_fork_syncing")),
    }


def verification_report(response: dict, payload: dict) -> dict:
    expected = expected_settings(payload)
    actual = actual_settings(response)
    mismatches = []
    for key, expected_value in expected.items():
        actual_value = actual.get(key)
        if key == "required_status_checks.contexts":
            missing = [context for context in expected_value if context not in actual_value]
            if missing:
                mismatches.append({"field": key, "expected": expected_value, "actual": actual_value, "missing": missing})
            continue
        if actual_value != expected_value:
            mismatches.append({"field": key, "expected": expected_value, "actual": actual_value})
    return {
        "evidence_ref": EVIDENCE_REF,
        "status": "verified" if not mismatches else "mismatch",
        "expected": expected,
        "actual": actual,
        "mismatches": mismatches,
    }


def synthetic_github_response(payload: dict) -> dict:
    reviews = payload["required_pull_request_reviews"]
    return {
        "required_status_checks": {
            "strict": payload["required_status_checks"]["strict"],
            "contexts": list(payload["required_status_checks"]["contexts"]),
        },
        "enforce_admins": {"enabled": payload["enforce_admins"]},
        "required_pull_request_reviews": {
            "dismiss_stale_reviews": reviews["dismiss_stale_reviews"],
            "require_code_owner_reviews": reviews["require_code_owner_reviews"],
            "required_approving_review_count": reviews["required_approving_review_count"],
            "require_last_push_approval": reviews["require_last_push_approval"],
        },
        "restrictions": payload["restrictions"],
        "required_linear_history": {"enabled": payload["required_linear_history"]},
        "allow_force_pushes": {"enabled": payload["allow_force_pushes"]},
        "allow_deletions": {"enabled": payload["allow_deletions"]},
        "block_creations": {"enabled": payload["block_creations"]},
        "required_conversation_resolution": {"enabled": payload["required_conversation_resolution"]},
        "lock_branch": {"enabled": payload["lock_branch"]},
        "allow_fork_syncing": {"enabled": payload["allow_fork_syncing"]},
    }


def self_test() -> int:
    payload = protection_payload()
    ok_report = verification_report(synthetic_github_response(payload), payload)
    if ok_report["status"] != "verified":
        raise SystemExit(f"Self-test failed: expected verified report\n{json.dumps(ok_report, indent=2)}")

    drifted = synthetic_github_response(payload)
    drifted["allow_deletions"]["enabled"] = True
    drift_report = verification_report(drifted, payload)
    if drift_report["status"] != "mismatch":
        raise SystemExit("Self-test failed: drifted branch protection response was not rejected")

    print(json.dumps({"status": "self_test_passed", "evidence_ref": EVIDENCE_REF}, indent=2))
    return 0


def request_json(method: str, url: str, token: str, payload: dict | None = None) -> dict:
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"GitHub API failed: {exc.code} {exc.reason}\n{body}") from exc


def token_from_environment() -> str | None:
    return os.environ.get("BRANCH_PROTECTION_TOKEN") or os.environ.get("GITHUB_TOKEN")


def argument_value(flag: str) -> str | None:
    if flag not in sys.argv:
        return None
    index = sys.argv.index(flag)
    try:
        return sys.argv[index + 1]
    except IndexError as exc:
        raise SystemExit(f"{flag} requires a value") from exc


def mode_from_environment() -> str:
    token = token_from_environment()
    if not token:
        return "dry-run"
    return "verify-only"


def main() -> int:
    dry_run = "--dry-run" in sys.argv
    verify_only = ("--verify-only" in sys.argv) or (mode_from_environment() == "verify-only")
    if "--self-test" in sys.argv:
        return self_test()

    repo_override = argument_value("--repo")
    repo = repository(repo_override)
    branch_name = argument_value("--branch") or os.environ.get("BRANCH_NAME") or DEFAULT_BRANCH_NAME
    payload = protection_payload()

    if dry_run or mode_from_environment() == "dry-run":
        verify_command = f"py -3 scripts/apply_github_branch_protection.py --verify-only --repo {repo} --branch {branch_name}"
        print(
            json.dumps(
                {
                    "status": "dry-run",
                    "branch_protection_verify_contract": EVIDENCE_REF,
                    "repository": repo,
                    "branch": branch_name,
                    "payload": payload,
                    "expected": expected_settings(payload),
                    "verify_command": verify_command,
                    "next_action": "set BRANCH_PROTECTION_TOKEN or GITHUB_TOKEN to enable live verification, then run: "
                    + verify_command,
                },
                indent=2,
            )
        )
        return 0

    url = f"https://api.github.com/repos/{repo}/branches/{branch_name}/protection"
    if not verify_only and not token_from_environment():
        verify_command = f"py -3 scripts/apply_github_branch_protection.py --verify-only --repo {repo} --branch {branch_name}"
        print(
            json.dumps(
                {
                    "status": "dry-run",
                    "branch_protection_verify_contract": EVIDENCE_REF,
                    "repository": repo,
                    "branch": branch_name,
                    "payload": payload,
                    "expected": expected_settings(payload),
                    "verify_command": verify_command,
                    "next_action": "set BRANCH_PROTECTION_TOKEN or GITHUB_TOKEN to apply protection; for verify-only, run: "
                    + verify_command,
                },
                indent=2,
            )
        )
        return 0

    auth_value = token_from_environment()
    if not auth_value:
        print("BRANCH_PROTECTION_TOKEN is not configured; branch protection cannot be applied or verified.", file=sys.stderr)
        return 1

    url = f"https://api.github.com/repos/{repo}/branches/{branch_name}/protection"
    if not verify_only:
        request_json("PUT", url, auth_value, payload)

    response = request_json("GET", url, auth_value)
    report = verification_report(response, payload)
    result = {
        "status": "verified" if verify_only else "applied_and_verified",
        "repository": repo,
        "branch": branch_name,
        **report,
    }
    if report["mismatches"]:
        print(json.dumps(result, indent=2), file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
