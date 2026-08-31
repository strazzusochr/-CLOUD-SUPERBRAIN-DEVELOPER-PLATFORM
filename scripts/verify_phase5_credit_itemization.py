from __future__ import annotations

import json
import hashlib
import io
import math
import re
import subprocess
import urllib.error
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs/project-progress.manifest.json"
ITEMIZATION_PATH = ROOT / "docs/runtime-state/phase5-credit-itemization.json"
CHECKLIST_PATH = ROOT / "docs/release-checklist.md"
CURRENT_CANDIDATE_PATH = ROOT / "docs/release-artifacts/current-release-candidate.json"
CAPABILITY_GATES_PATH = ROOT / "docs/runtime-state/capability-gates.json"

EXPECTED_ITEMS = {
    "C1": "code",
    "C2": "code",
    "C3": "code",
    "C4": "code",
    "C5": "code",
    "I1": "infrastructure",
    "I2": "infrastructure",
    "I3": "infrastructure",
    "I4": "infrastructure",
    "I5": "infrastructure",
    "V1": "observability",
    "V2": "observability",
    "V3": "observability",
    "V4": "observability",
    "O1": "operations",
    "O2": "operations",
    "O3": "operations",
    "O4": "operations",
    "O5": "operations",
}
LEGACY_MISSING_IDS = {"I1", "I2", "I4", "I5", "V1", "O4"}
BASELINE_BLOCKED_IDS = {"I1"}
PRODUCTION_AUTH_VERIFIER_PATH = "scripts/verify-production-auth-identity-evidence.ps1"
RETIRED_RC1_MARKERS = {
    "candidate_browser_bridge_retired_current_hosted_blocked",
    "candidate_browser_evidence_retired_current_hosted_blocked",
    "candidate_post_rollback_browser_revalidation_retired_current_hosted_blocked",
    "candidate_final_browser_e2e_retired_current_hosted_blocked",
    "candidate_full_verifier_sweep_retired_current_hosted_blocked",
    "candidate_truth_mirror_rebaseline_retired_current_hosted_blocked",
}
RUNTIME_SOURCE_PATHS = [
    ".dockerignore",
    "apps/frontend",
    "services/agent-api",
    "services/agent-worker",
    "services/memory-worker",
    "services/mcp-gateway",
    "services/llm-gateway",
    "PROJECT_STATE.md",
    "docs/project-progress.manifest.json",
    "docs/runtime-state/external-gate-summary.json",
    "docs/codex-integration/autonomous-agent-roster.json",
]
QUALIFICATION_TRUTH_PATHS = {
    "PROJECT_STATE.md",
    "apps/frontend/lib/endpoint-snapshot.json",
    "apps/frontend/lib/platform.ts",
    "docs/project-progress.manifest.json",
}
NO_CREDIT_REQUALIFICATION_RUNTIME_PATHS = {
    "PROJECT_STATE.md",
    "apps/frontend/lib/endpoint-snapshot.json",
    "apps/frontend/lib/platform.ts",
    "docs/project-progress.manifest.json",
    "docs/runtime-state/external-gate-summary.json",
}
NO_CREDIT_REQUALIFICATION_SAME_DAY_RUNTIME_PATHS = {
    "PROJECT_STATE.md",
    "apps/frontend/lib/endpoint-snapshot.json",
    "docs/runtime-state/external-gate-summary.json",
}
CURRENT_RELEASE_CANDIDATE_REPO_PATH = "docs/release-artifacts/current-release-candidate.json"
PHASE5_ITEMIZATION_REPO_PATH = "docs/runtime-state/phase5-credit-itemization.json"
PROJECT_PROGRESS_MANIFEST_REPO_PATH = "docs/project-progress.manifest.json"
ENDPOINT_SNAPSHOT_REPO_PATH = "apps/frontend/lib/endpoint-snapshot.json"
PLATFORM_MANIFEST_REPO_PATH = "apps/frontend/lib/platform.ts"
EXTERNAL_GATE_SUMMARY_REPO_PATH = "docs/runtime-state/external-gate-summary.json"
LOCAL_VERIFICATION_FILES = {
    "runtime": "runtime.json",
    "browser": "browser.json",
    "candidate_images": "candidate-images.json",
    "candidate_runtime": "candidate-runtime.json",
    "security": "security.json",
}
SOURCE_PREQUALIFICATION_CONTROL_PATHS = {
    ".github/workflows/pr-check.yml",
    "scripts/tests/test_verify_phase5_credit_itemization.py",
    "scripts/verify-main-deploy-transition.ps1",
    "scripts/verify-supply-chain-pins.ps1",
    "scripts/verify_phase5_credit_itemization.py",
}
LEGACY_DIRECT_CI_BINDINGS = {
    (
        "prod-candidate-2026-07-31-local-rc11",
        "bae3cdc1692e1e99e7f546f72664a3c747958b8c",
    ),
}
LEGACY_EVIDENCE_BINDINGS = {
    (
        "prod-candidate-2026-07-31-local-rc11",
        "bae3cdc1692e1e99e7f546f72664a3c747958b8c",
    ),
}
EXPECTED_GITHUB_REPOSITORY = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
EXPECTED_GITHUB_WORKFLOW_NAME = "pr-check"
EXPECTED_GITHUB_WORKFLOW_PATH = ".github/workflows/pr-check.yml"
# These sets are compared with == , not as a subset. Every writer that produces a v2 summary
# must declare exactly this list for its chain, or the evidence it writes cannot be credited:
#   runtime, browser -> scripts/write-phase5-local-verification-evidence.ps1
#   security         -> scripts/write-phase5-security-evidence.ps1
# Exit anchors (RUNTIME_EXIT=0, BROWSER_EXIT=0) are log-integrity lines and are deliberately NOT
# part of a declared set. When a line is added or renamed here, the corresponding writer has to
# change in the same commit — they drifted apart once and every chain silently failed to verify.
CANONICAL_SUCCESS_ANCHORS = {
    "runtime": [
        "[runtime] compose status",
        "[runtime] phase1 runtime checks completed",
    ],
    "browser": [
        "[browser-contract] checks completed",
        "[product-acceptance] PASS DEV-ONLY; hosted proof still blocked",
        "[22-page-actions] PASS DEV-ONLY; hosted proof still blocked",
        "[o4-write] status=verified gates=live_agent_tool_writes,live_mcp_writes",
    ],
    "security": [
        "PHASE5_SECURITY_EVIDENCE_V2",
        "[phase5-security] source_boundary=committed_git_archive_only",
        "[phase5-security] npm_audit_verified=true",
        "NPM_AUDIT_EXIT=0",
        "[phase5-security] gitleaks_config=.gitleaks.toml",
        "[phase5-security] gitleaks_verified=true",
        "GITLEAKS_EXIT=0",
        "PHASE5_SECURITY_EXIT=0",
    ],
    "candidate-images": [
        "[phase5-candidate-local] status=verified service_count=6",
    ],
    "candidate-runtime": [
        "[phase5-candidate-local] api_contract_verified=true",
        "[phase5-candidate-local] local_image_identity_verified=true",
        "[phase5-candidate-local] embedded_source_hash_parity_verified=true",
        "[phase5-candidate-local] candidate_runtime_source_parity_verified=true",
        "[phase5-candidate-local] browser_click_verified=true",
        "[phase5-candidate-local] playwright_passed=1",
        "[phase5-candidate-local] status=verified service_count=6",
    ],
}
SUMMARY_CHAINS = {"runtime", "browser", "security"}
SUMMARY_COMMANDS = {
    "runtime": "npm run verify:runtime",
    "browser": "npm run verify:browser",
}
EXPECTED_CANDIDATE_SERVICES = {
    "frontend",
    "agent-api",
    "agent-worker",
    "memory-worker",
    "mcp-gateway",
    "llm-gateway",
}
EXPECTED_OCI_SOURCE = (
    "https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
)
EXPECTED_CANDIDATE_IMAGE_FILES = {
    "frontend": (
        "apps/frontend/Dockerfile",
        "apps/frontend/package.json",
        "/app/package.json",
    ),
    "agent-api": (
        "services/agent-api/Dockerfile",
        "services/agent-api/app/main.py",
        "/app/app/main.py",
    ),
    "agent-worker": (
        "services/agent-worker/Dockerfile",
        "services/agent-worker/app/worker.py",
        "/app/app/worker.py",
    ),
    "memory-worker": (
        "services/memory-worker/Dockerfile",
        "services/memory-worker/app/worker.py",
        "/app/app/worker.py",
    ),
    "mcp-gateway": (
        "services/mcp-gateway/Dockerfile",
        "services/mcp-gateway/app/main.py",
        "/app/app/main.py",
    ),
    "llm-gateway": (
        "services/llm-gateway/Dockerfile",
        "services/llm-gateway/app/main.py",
        "/app/app/main.py",
    ),
}
SHA256_UPPER_RE = re.compile(r"[0-9A-F]{64}")
SHA256_LOWER_RE = re.compile(r"[0-9a-f]{64}")
EVIDENCE_RUN_ID_RE = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
)


def fail(message: str) -> None:
    raise SystemExit(f"[phase5-credit] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"missing {path.relative_to(ROOT).as_posix()}")
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"invalid JSON in {path.relative_to(ROOT).as_posix()}: {exc}")
    require(isinstance(value, dict), f"{path.relative_to(ROOT).as_posix()} must contain an object")
    return value


def load_json_value(path: Path) -> Any:
    require(path.is_file(), f"missing {path.relative_to(ROOT).as_posix()}")
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"invalid JSON in {path.relative_to(ROOT).as_posix()}: {exc}")


def run_git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def resolve_repo_file(raw_path: Any, label: str) -> tuple[str, Path]:
    require(isinstance(raw_path, str) and raw_path, f"{label} path must be non-empty")
    normalized = raw_path.replace("\\", "/")
    pure = PurePosixPath(normalized)
    require(not pure.is_absolute(), f"{label} path must be repo-relative")
    require(".." not in pure.parts, f"{label} path may not escape the repository")
    require(normalized == pure.as_posix(), f"{label} path must be normalized")
    target = (ROOT / Path(*pure.parts)).resolve()
    require(target.is_relative_to(ROOT.resolve()), f"{label} path resolves outside the repository")
    require(target.is_file(), f"{label} evidence is missing: {normalized}")
    return normalized, target


def require_tracked_repo_path(raw_path: Any, label: str) -> str:
    normalized, _ = resolve_repo_file(raw_path, label)
    tracked = run_git("ls-files", "--error-unmatch", "--", normalized)
    require(tracked.returncode == 0, f"{label} evidence is not tracked: {normalized}")
    return normalized


def require_anchor(target: Path, raw_anchor: Any, label: str) -> str:
    require(isinstance(raw_anchor, str), f"{label} anchor must be a string")
    anchor = raw_anchor.strip()
    require(len(anchor) >= 8, f"{label} anchor must contain at least eight characters")
    artifact = target.read_bytes().decode("utf-8-sig", errors="replace")
    require(anchor in artifact, f"{label} anchor is not present in the evidence artifact")
    return anchor


def sha256_file(target: Path) -> str:
    digest = hashlib.sha256()
    with target.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def expected_blocked_ids(*, auth_transition_verified: bool) -> set[str]:
    blocked = set(BASELINE_BLOCKED_IDS)
    if not auth_transition_verified:
        blocked.add("I5")
    return blocked


def validate_production_auth_transition(gate: Any, source_sha: str) -> bool:
    require(isinstance(gate, dict), "production auth capability gate must be an object")
    owner_granted = gate.get("owner_granted") is True
    live_verified = gate.get("live_verified") is True
    require(
        not live_verified or owner_granted,
        "production auth gate may not be live-verified without an Owner grant",
    )
    if not (owner_granted and live_verified):
        return False

    require(gate.get("paid_provider") is False, "production auth proof must remain free-only")
    require(
        isinstance(gate.get("owner_grant_ref"), str) and gate["owner_grant_ref"].strip(),
        "production auth gate is missing its Owner grant reference",
    )
    require(
        isinstance(gate.get("provider"), str) and gate["provider"].strip(),
        "production auth gate is missing its provider identity",
    )
    require(
        gate.get("verifier") == PRODUCTION_AUTH_VERIFIER_PATH,
        "production auth gate must name the dedicated non-mutating verifier",
    )

    verifier_path = require_tracked_repo_path(
        PRODUCTION_AUTH_VERIFIER_PATH,
        "production auth verifier",
    )
    require(
        run_git("diff", "--quiet", "HEAD", "--", verifier_path).returncode == 0,
        "production auth verifier must be clean relative to HEAD",
    )
    evidence_path = require_tracked_repo_path(
        gate.get("evidence_artifact"),
        "production auth gate",
    )
    require(
        run_git("diff", "--quiet", "HEAD", "--", evidence_path).returncode == 0,
        "production auth evidence must be clean relative to HEAD",
    )
    evidence_sha = gate.get("evidence_sha256")
    require(
        isinstance(evidence_sha, str) and re.fullmatch(r"[0-9A-Fa-f]{64}", evidence_sha) is not None,
        "production auth evidence SHA-256 is invalid",
    )
    require(
        sha256_file(ROOT / evidence_path) == evidence_sha.upper(),
        "production auth evidence SHA-256 mismatch",
    )

    command = [
        "pwsh",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ROOT / PRODUCTION_AUTH_VERIFIER_PATH),
        "-EvidencePath",
        evidence_path,
        "-ExpectedCandidateSha",
        source_sha,
        "-ValidateOnly",
    ]
    try:
        completed = subprocess.run(
            command,
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except OSError as exc:
        fail(f"production auth verifier could not run: {exc}")
    marker = "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false"
    require(completed.returncode == 0, "production auth evidence failed dedicated validation")
    require(marker in completed.stdout, "production auth verifier omitted the read-only validation marker")
    return True


def require_exact_lines(lines: list[str], expected: list[str], label: str) -> None:
    require(len(expected) == len(set(expected)), f"{label} canonical anchors are duplicated")
    for anchor in expected:
        require(
            lines.count(anchor) == 1,
            f"{label} canonical anchor must occur as one exact line: {anchor}",
        )


def github_api_json(url: str, label: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "cloud-superbrain-phase5-verifier",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            require(response.status == 200, f"{label} returned HTTP {response.status}")
            payload = response.read()
    except (OSError, urllib.error.HTTPError, urllib.error.URLError) as exc:
        fail(f"{label} live GitHub readback failed closed: {exc}")
    try:
        value = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"{label} live GitHub readback is invalid JSON: {exc}")
    require(isinstance(value, dict), f"{label} live GitHub readback must be an object")
    return value


def github_api_bytes(url: str, label: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "cloud-superbrain-phase5-verifier",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            require(response.status == 200, f"{label} returned HTTP {response.status}")
            return response.read()
    except (OSError, urllib.error.HTTPError, urllib.error.URLError) as exc:
        fail(f"{label} live GitHub artifact download failed closed: {exc}")


def load_git_blob(source_sha: str, path: str) -> bytes:
    result = subprocess.run(
        ["git", "show", f"{source_sha}:{path}"],
        cwd=ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(result.returncode == 0, f"candidate source file is not readable at {source_sha}:{path}")
    return result.stdout


def git_archive_sha256(source_sha: str) -> str:
    result = subprocess.run(
        ["git", "archive", "--format=tar", source_sha],
        cwd=ROOT,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    require(result.returncode == 0, f"candidate git archive cannot be reproduced for {source_sha}")
    return hashlib.sha256(result.stdout).hexdigest()


def require_upper_sha256(value: Any, label: str) -> str:
    require(
        isinstance(value, str) and SHA256_UPPER_RE.fullmatch(value) is not None,
        f"{label} must be an uppercase SHA-256",
    )
    require(value != "0" * 64, f"{label} may not be the all-zero placeholder")
    return value


def require_lower_sha256(value: Any, label: str) -> str:
    require(
        isinstance(value, str) and SHA256_LOWER_RE.fullmatch(value) is not None,
        f"{label} must be a lowercase SHA-256",
    )
    require(value != "0" * 64, f"{label} may not be the all-zero placeholder")
    return value


def require_non_claims(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} non_claims must not be empty")
    claims: list[str] = []
    for index, raw_claim in enumerate(value):
        require(
            isinstance(raw_claim, str) and raw_claim.strip(),
            f"{label} non_claim #{index + 1} must be a non-empty string",
        )
        claims.append(raw_claim.strip())
    normalized = "\n".join(claims).lower()
    require("dev-only" in normalized, f"{label} must retain the DEV-ONLY non-claim")
    require("hosted" in normalized, f"{label} must retain the hosted-proof non-claim")
    require("production" in normalized, f"{label} must retain the production non-claim")
    return claims


def is_legacy_evidence_binding(release_id: str, source_sha: str) -> bool:
    return (release_id, source_sha) in LEGACY_EVIDENCE_BINDINGS


def require_hashed_tracked_file(
    metadata: Any,
    expected_path: str,
    label: str,
) -> Path:
    require(isinstance(metadata, dict), f"{label} metadata is missing")
    path = require_tracked_repo_path(metadata.get("path"), label)
    require(path == expected_path, f"{label} path mismatch")
    recorded_sha256 = require_upper_sha256(metadata.get("sha256"), f"{label} SHA-256")
    target = ROOT / path
    require(sha256_file(target) == recorded_sha256, f"{label} SHA-256 mismatch")
    return target


def validate_v2_raw_log(
    chain: str,
    proof: dict[str, Any],
    readiness_entry: Any,
    release_id: str,
    source_sha: str,
) -> Path:
    label = f"candidate local verification {chain}"
    require(isinstance(readiness_entry, dict), f"{label} readiness entry is missing")
    command = proof.get("command")
    require(
        isinstance(command, str) and command.strip(),
        f"{label} command is missing",
    )
    require(command == readiness_entry.get("command"), f"{label} command does not match readiness")

    run_id = proof.get("evidence_run_id")
    require(
        isinstance(run_id, str) and EVIDENCE_RUN_ID_RE.fullmatch(run_id) is not None,
        f"{label} evidence_run_id is invalid",
    )
    require(
        readiness_entry.get("evidence_run_id") == run_id,
        f"{label} evidence run does not match readiness",
    )

    expected_raw_path = (
        f"docs/release-artifacts/{release_id}-evidence/raw/{chain}.log"
    )
    raw_path = require_tracked_repo_path(proof.get("raw_log_path"), f"{label} raw log")
    require(raw_path == expected_raw_path, f"{label} raw log path mismatch")
    require(
        readiness_entry.get("raw_log_path") == raw_path,
        f"{label} raw log path does not match readiness",
    )
    raw_target = ROOT / raw_path
    raw_sha256 = require_upper_sha256(proof.get("raw_log_sha256"), f"{label} raw_log_sha256")
    require(
        readiness_entry.get("raw_log_sha256") == raw_sha256,
        f"{label} raw log SHA-256 does not match readiness",
    )
    require(sha256_file(raw_target) == raw_sha256, f"{label} raw log SHA-256 mismatch")

    raw_text = raw_target.read_bytes().decode("utf-8-sig", errors="replace")
    lines = [line.rstrip("\r") for line in raw_text.splitlines()]
    non_empty = [line for line in lines if line.strip()]
    require(
        bool(non_empty) and non_empty[0] == "PHASE5_EVIDENCE_RAW_V2",
        f"{label} raw log contract marker is missing",
    )
    expected_bindings = {
        "chain": chain,
        "release_id": release_id,
        "source_commit_sha": source_sha,
        "evidence_run_id": run_id,
        "command": command,
        "exit_code": "0",
    }
    for field, expected in expected_bindings.items():
        marker = f"[phase5-evidence] {field}={expected}"
        require(
            lines.count(marker) == 1,
            f"{label} raw log {field} binding must occur exactly once",
        )

    observed = proof.get("observed_success_anchors")
    expected = readiness_entry.get("success_anchors")
    canonical = CANONICAL_SUCCESS_ANCHORS.get(chain)
    require(canonical is not None, f"{label} has no verifier-owned canonical anchor set")
    require(
        isinstance(observed, list) and observed,
        f"{label} observed_success_anchors must not be empty",
    )
    require(observed == canonical, f"{label} observed anchors are not canonical")
    require(expected == canonical, f"{label} readiness anchors are not canonical")
    require_exact_lines(lines, canonical, f"{label} raw log")
    return raw_target


def validate_ci_workflow(
    workflow: Any,
    release_id: str,
    source_sha: str,
) -> None:
    label = "candidate CI workflow"
    require(isinstance(workflow, dict), f"{label} must be an object")
    require(workflow.get("name") == "pr-check", f"{label} name mismatch")
    require(workflow.get("status") == "success", f"{label} must be successful")

    run_id = workflow.get("run_id")
    require(type(run_id) is int and run_id > 0, f"{label} run_id is invalid")
    run_url = workflow.get("run_url")
    require(
        run_url
        == f"https://github.com/{EXPECTED_GITHUB_REPOSITORY}/actions/runs/{run_id}",
        f"{label} URL is invalid",
    )

    head_sha = workflow.get("head_sha")
    require(
        isinstance(head_sha, str) and re.fullmatch(r"[0-9a-f]{40}", head_sha) is not None,
        f"{label} head SHA is invalid",
    )
    binding_mode = workflow.get("binding_mode")
    if binding_mode in (None, "direct_head_v1"):
        require(
            (release_id, source_sha) in LEGACY_DIRECT_CI_BINDINGS,
            f"{label} legacy direct binding is not allowed for this candidate",
        )
        require(head_sha == source_sha, f"{label} SHA mismatch")
        return

    require(
        binding_mode == "source_checkout_attestation_v1",
        f"{label} binding mode is invalid",
    )
    control_sha = workflow.get("control_sha")
    candidate_sha = workflow.get("candidate_sha")
    checked_out_sha = workflow.get("checked_out_sha")
    require(control_sha == head_sha, f"{label} control SHA must equal run head SHA")
    require(control_sha != source_sha, f"{label} control SHA must remain distinct from source SHA")
    require(candidate_sha == source_sha, f"{label} candidate SHA mismatch")
    require(checked_out_sha == source_sha, f"{label} checked-out SHA mismatch")
    require(workflow.get("event_name") == "workflow_dispatch", f"{label} event mismatch")
    require(workflow.get("source_prequalification") is True, f"{label} prequalification flag is missing")

    require(
        run_git("cat-file", "-e", f"{control_sha}^{{commit}}").returncode == 0,
        f"{label} control commit does not exist",
    )
    require(
        run_git("merge-base", "--is-ancestor", source_sha, control_sha).returncode == 0,
        f"{label} source is not an ancestor of control",
    )
    require(
        run_git("merge-base", "--is-ancestor", control_sha, "HEAD").returncode == 0,
        f"{label} control is not an ancestor of HEAD",
    )

    attestation_entry = workflow.get("attestation")
    require(isinstance(attestation_entry, dict), f"{label} attestation metadata is missing")
    expected_path = (
        f"docs/release-artifacts/{release_id}-evidence/ci-source-checkout-attestation.json"
    )
    artifact_path = require_tracked_repo_path(
        attestation_entry.get("artifact"),
        f"{label} attestation",
    )
    require(artifact_path == expected_path, f"{label} attestation path mismatch")
    artifact_target = ROOT / artifact_path
    recorded_sha256 = require_upper_sha256(
        attestation_entry.get("sha256"),
        f"{label} attestation SHA-256",
    )
    require(
        sha256_file(artifact_target) == recorded_sha256,
        f"{label} attestation SHA-256 mismatch",
    )

    artifact_id = attestation_entry.get("github_artifact_id")
    require(type(artifact_id) is int and artifact_id > 0, f"{label} artifact ID is invalid")
    artifact_url = attestation_entry.get("github_artifact_url")
    require(
        artifact_url == f"{run_url}/artifacts/{artifact_id}",
        f"{label} artifact URL is invalid",
    )
    artifact_digest = attestation_entry.get("github_artifact_digest")
    require(
        isinstance(artifact_digest, str)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", artifact_digest) is not None,
        f"{label} artifact digest is invalid",
    )

    readback_entry = workflow.get("github_readback")
    require(isinstance(readback_entry, dict), f"{label} GitHub readback metadata is missing")
    expected_readback_path = (
        f"docs/release-artifacts/{release_id}-evidence/"
        "ci-source-checkout-github-readback.json"
    )
    readback_path = require_tracked_repo_path(
        readback_entry.get("artifact"),
        f"{label} GitHub readback",
    )
    require(readback_path == expected_readback_path, f"{label} GitHub readback path mismatch")
    readback_target = ROOT / readback_path
    recorded_readback_sha256 = require_upper_sha256(
        readback_entry.get("sha256"),
        f"{label} GitHub readback SHA-256",
    )
    require(
        sha256_file(readback_target) == recorded_readback_sha256,
        f"{label} GitHub readback SHA-256 mismatch",
    )

    attestation = load_json(artifact_target)
    require(
        attestation.get("contract_version") == "pr-check-source-checkout-attestation-v1",
        f"{label} attestation contract mismatch",
    )
    for field, expected in (
        ("binding_mode", binding_mode),
        ("candidate_sha", source_sha),
        ("checked_out_sha", source_sha),
        ("control_sha", control_sha),
        ("run_sha", control_sha),
        ("event_name", "workflow_dispatch"),
        ("run_id", run_id),
        ("run_url", run_url),
        ("source_prequalification", True),
        ("github_actions_artifact_upload", True),
        ("registry_publish", False),
        ("production_deploy", False),
        ("release_promotion", False),
        ("secret_output", False),
    ):
        require(attestation.get(field) == expected, f"{label} attestation {field} mismatch")

    run_attempt = attestation.get("run_attempt")
    require(type(run_attempt) is int and run_attempt > 0, f"{label} run attempt is invalid")
    expected_artifact_name = f"pr-check-source-checkout-attestation-{run_id}-{run_attempt}"
    require(
        attestation_entry.get("github_artifact_name") == expected_artifact_name,
        f"{label} artifact name mismatch",
    )
    require(
        isinstance(attestation.get("ref"), str)
        and re.fullmatch(r"refs/heads/[^\s]+", attestation["ref"]) is not None,
        f"{label} attestation ref is invalid",
    )
    require_non_claims(attestation.get("non_claims"), f"{label} attestation")

    readback = load_json(readback_target)
    require(
        readback.get("contract_version") == "github-actions-source-attestation-readback-v1",
        f"{label} GitHub readback contract mismatch",
    )
    repository = EXPECTED_GITHUB_REPOSITORY
    require(readback.get("repository") == repository, f"{label} GitHub readback repository mismatch")
    require(readback.get("secret_output") is False, f"{label} GitHub readback secret flag mismatch")
    readback_run = readback.get("run")
    require(isinstance(readback_run, dict), f"{label} GitHub run readback is missing")
    for field, expected in (
        ("id", run_id),
        ("run_attempt", run_attempt),
        ("event", "workflow_dispatch"),
        ("status", "completed"),
        ("conclusion", "success"),
        ("head_sha", control_sha),
        ("html_url", run_url),
    ):
        require(readback_run.get(field) == expected, f"{label} GitHub run {field} mismatch")
    require(
        isinstance(readback_run.get("head_branch"), str) and readback_run["head_branch"],
        f"{label} GitHub run head branch is missing",
    )
    require(
        attestation.get("ref") == f"refs/heads/{readback_run['head_branch']}",
        f"{label} attestation ref does not match the GitHub run head branch",
    )

    readback_artifact = readback.get("artifact")
    require(isinstance(readback_artifact, dict), f"{label} GitHub artifact readback is missing")
    for field, expected in (
        ("id", artifact_id),
        ("name", expected_artifact_name),
        ("expired", False),
        ("digest", artifact_digest),
    ):
        require(
            readback_artifact.get(field) == expected,
            f"{label} GitHub artifact {field} mismatch",
        )
    require(
        readback_artifact.get("url")
        == f"https://api.github.com/repos/{repository}/actions/artifacts/{artifact_id}",
        f"{label} GitHub artifact API URL mismatch",
    )
    require(
        readback_artifact.get("archive_download_url")
        == f"https://api.github.com/repos/{repository}/actions/artifacts/{artifact_id}/zip",
        f"{label} GitHub artifact archive URL mismatch",
    )
    artifact_workflow = readback_artifact.get("workflow_run")
    require(isinstance(artifact_workflow, dict), f"{label} artifact workflow readback is missing")
    require(artifact_workflow.get("id") == run_id, f"{label} artifact workflow run mismatch")
    require(
        artifact_workflow.get("head_sha") == control_sha,
        f"{label} artifact workflow head SHA mismatch",
    )
    downloaded_archive_sha = require_lower_sha256(
        readback.get("downloaded_archive_sha256"),
        f"{label} downloaded archive SHA-256",
    )
    require(
        artifact_digest == f"sha256:{downloaded_archive_sha}",
        f"{label} downloaded artifact archive digest mismatch",
    )
    require(
        readback.get("downloaded_attestation_sha256") == recorded_sha256,
        f"{label} downloaded attestation SHA-256 mismatch",
    )

    delta = run_git(
        "diff",
        "--name-only",
        "--diff-filter=ACDMRTUXB",
        "-z",
        source_sha,
        control_sha,
        "--",
    )
    require(delta.returncode == 0, f"{label} control delta cannot be resolved")
    actual_delta = sorted({path for path in delta.stdout.split("\0") if path})
    require(actual_delta, f"{label} control delta must not be empty")
    require(
        set(actual_delta).issubset(SOURCE_PREQUALIFICATION_CONTROL_PATHS),
        f"{label} control delta contains non-control paths",
    )
    require(
        attestation.get("control_delta") == actual_delta,
        f"{label} attested control delta mismatch",
    )


def validate_summary_proof(
    chain: str,
    proof: dict[str, Any],
    readiness_entry: dict[str, Any],
    release_id: str,
    source_sha: str,
) -> None:
    label = f"candidate local verification {chain}"
    legacy = is_legacy_evidence_binding(release_id, source_sha)
    require(
        proof.get("contract_version")
        == ("phase5-local-verification-summary-v1" if legacy else "phase5-local-verification-summary-v2"),
        f"{label} contract mismatch",
    )
    require(proof.get("chain") == chain, f"{label} chain mismatch")
    require(proof.get("release_id") == release_id, f"{label} release_id mismatch")
    require(proof.get("source_commit_sha") == source_sha, f"{label} source SHA mismatch")
    command = proof.get("command")
    require(
        isinstance(command, str) and command.strip(),
        f"{label} command is missing",
    )
    require(command == readiness_entry.get("command"), f"{label} command does not match readiness")
    if chain in SUMMARY_COMMANDS:
        require(command == SUMMARY_COMMANDS[chain], f"{label} command is not canonical")
    if chain == "security":
        if legacy:
            require(
                "scripts/write-rc11-security-evidence.ps1" in command
                or ("npm audit" in command and "gitleaks" in command.lower()),
                f"{label} command must use the canonical security generator or name npm audit and gitleaks",
            )
        else:
            require(
                "scripts/write-phase5-security-evidence.ps1" in command,
                f"{label} command must use the v2 security evidence generator",
            )
    require(proof.get("status") == "passed", f"{label} status mismatch")
    require(type(proof.get("exit_code")) is int and proof["exit_code"] == 0, f"{label} exit_code must be 0")
    require(proof.get("dev_only") is True, f"{label} must be explicitly DEV-ONLY")
    require(proof.get("hosted_proof") is False, f"{label} may not claim hosted proof")
    require(proof.get("secret_output") is False, f"{label} may not claim secret output")
    if legacy:
        require_upper_sha256(proof.get("raw_log_sha256"), f"{label} raw_log_sha256")
        observed = proof.get("observed_success_anchors")
        expected = readiness_entry.get("success_anchors")
        require(
            isinstance(observed, list) and observed,
            f"{label} observed_success_anchors must not be empty",
        )
        require(observed == expected, f"{label} observed anchors do not match readiness")
        for index, anchor in enumerate(observed):
            require(
                isinstance(anchor, str) and len(anchor.strip()) >= 8,
                f"{label} observed anchor #{index + 1} is invalid",
            )
    else:
        validate_v2_raw_log(chain, proof, readiness_entry, release_id, source_sha)
    require_non_claims(proof.get("non_claims"), label)


def validate_candidate_images_proof(
    proof: dict[str, Any],
    release_id: str,
    source_sha: str,
    readiness_entry: dict[str, Any] | None = None,
) -> None:
    label = "candidate local verification candidate_images"
    legacy = is_legacy_evidence_binding(release_id, source_sha)
    require(
        proof.get("contract_version")
        == ("phase5-production-candidate-local-v1" if legacy else "phase5-production-candidate-local-v2"),
        f"{label} contract mismatch",
    )
    require(
        proof.get("evidence_ref") == "phase5_local_production_candidate_verified",
        f"{label} evidence_ref mismatch",
    )
    require(proof.get("status") == "verified", f"{label} status mismatch")
    require(proof.get("release_id") == release_id, f"{label} release_id mismatch")
    require(proof.get("source_commit_sha") == source_sha, f"{label} source SHA mismatch")
    if not legacy:
        validate_v2_raw_log("candidate-images", proof, readiness_entry, release_id, source_sha)
    require(
        proof.get("source_boundary") == "committed_git_archive_only",
        f"{label} source boundary mismatch",
    )
    archive_sha256 = require_lower_sha256(
        proof.get("git_archive_sha256"),
        f"{label} git archive SHA-256",
    )
    if not legacy:
        require(
            git_archive_sha256(source_sha) == archive_sha256,
            f"{label} git archive SHA-256 cannot be reproduced from source",
        )
    require(proof.get("service_count") == 6, f"{label} service count mismatch")

    images = proof.get("images")
    require(isinstance(images, list) and len(images) == 6, f"{label} must contain six images")
    services: set[str] = set()
    tags: set[str] = set()
    image_ids: set[str] = set()
    for index, image in enumerate(images):
        item_label = f"{label} image #{index + 1}"
        require(isinstance(image, dict), f"{item_label} must be an object")
        service = image.get("service")
        require(service in EXPECTED_CANDIDATE_SERVICES, f"{item_label} service is invalid")
        require(service not in services, f"{item_label} service is duplicated")
        services.add(service)

        expected_tag = f"cloud-superbrain-production-candidate/{service}:{source_sha}"
        image_tag = image.get("image_tag")
        require(image_tag == expected_tag, f"{item_label} image tag mismatch")
        require(image_tag not in tags, f"{item_label} image tag is duplicated")
        tags.add(image_tag)

        image_id = image.get("image_id")
        require(
            isinstance(image_id, str) and re.fullmatch(r"sha256:[0-9a-f]{64}", image_id) is not None,
            f"{item_label} image ID is invalid",
        )
        require(image_id != f"sha256:{'0' * 64}", f"{item_label} image ID may not be all zeroes")
        require(image_id not in image_ids, f"{item_label} image ID is duplicated")
        image_ids.add(image_id)
        require(
            type(image.get("image_size_bytes")) is int and image["image_size_bytes"] > 0,
            f"{item_label} image size must be positive",
        )

        expected_dockerfile, expected_source_file, expected_embedded_file = (
            EXPECTED_CANDIDATE_IMAGE_FILES[service]
        )
        for field, expected_path in (
            ("dockerfile", expected_dockerfile),
            ("source_file", expected_source_file),
            ("embedded_file", expected_embedded_file),
        ):
            require(image.get(field) == expected_path, f"{item_label} {field} mismatch")
        dockerfile_hash = require_lower_sha256(
            image.get("dockerfile_sha256"),
            f"{item_label} dockerfile SHA-256",
        )
        source_hash = require_lower_sha256(
            image.get("source_file_sha256"),
            f"{item_label} source-file SHA-256",
        )
        embedded_hash = require_lower_sha256(
            image.get("embedded_file_sha256"),
            f"{item_label} embedded-file SHA-256",
        )
        require(source_hash == embedded_hash, f"{item_label} embedded source hash mismatch")
        require(image.get("oci_revision") == source_sha, f"{item_label} OCI revision mismatch")
        require(image.get("oci_version") == release_id, f"{item_label} OCI version mismatch")
        require(
            image.get("oci_source") == EXPECTED_OCI_SOURCE,
            f"{item_label} OCI source is invalid",
        )

        if not legacy:
            require(
                hashlib.sha256(load_git_blob(source_sha, expected_dockerfile)).hexdigest()
                == dockerfile_hash,
                f"{item_label} dockerfile SHA-256 cannot be reproduced from source",
            )
            require(
                hashlib.sha256(load_git_blob(source_sha, expected_source_file)).hexdigest()
                == source_hash,
                f"{item_label} source-file SHA-256 cannot be reproduced from source",
            )

    require(services == EXPECTED_CANDIDATE_SERVICES, f"{label} service set mismatch")
    if not legacy:
        raw_evidence = proof.get("raw_evidence")
        require(isinstance(raw_evidence, dict), f"{label} raw_evidence is missing")
        raw_images = raw_evidence.get("images")
        require(
            isinstance(raw_images, list) and len(raw_images) == 6,
            f"{label} raw_evidence must contain six images",
        )
        raw_by_service: dict[str, dict[str, Any]] = {}
        for raw_image in raw_images:
            require(isinstance(raw_image, dict), f"{label} raw image metadata must be an object")
            raw_service = raw_image.get("service")
            require(raw_service in EXPECTED_CANDIDATE_SERVICES, f"{label} raw image service is invalid")
            require(raw_service not in raw_by_service, f"{label} raw image service is duplicated")
            raw_by_service[raw_service] = raw_image

        image_by_service = {str(image["service"]): image for image in images}
        raw_root = f"docs/release-artifacts/{release_id}-evidence/raw/candidate-images"
        for service in sorted(EXPECTED_CANDIDATE_SERVICES):
            raw_image = raw_by_service[service]
            image = image_by_service[service]
            inspect_target = require_hashed_tracked_file(
                raw_image.get("inspect"),
                f"{raw_root}/{service}-inspect.json",
                f"{label} {service} inspect",
            )
            inspect_value = load_json_value(inspect_target)
            if isinstance(inspect_value, list):
                require(len(inspect_value) == 1, f"{label} {service} inspect must contain one image")
                inspect_value = inspect_value[0]
            require(isinstance(inspect_value, dict), f"{label} {service} inspect must be an object")
            require(inspect_value.get("Id") == image.get("image_id"), f"{label} {service} raw image ID mismatch")
            require(inspect_value.get("Size") == image.get("image_size_bytes"), f"{label} {service} raw image size mismatch")
            repo_tags = inspect_value.get("RepoTags")
            require(
                isinstance(repo_tags, list) and image.get("image_tag") in repo_tags,
                f"{label} {service} raw image tag mismatch",
            )
            config = inspect_value.get("Config")
            require(isinstance(config, dict), f"{label} {service} inspect config is missing")
            labels = config.get("Labels")
            require(isinstance(labels, dict), f"{label} {service} inspect labels are missing")
            for field, expected in (
                ("org.opencontainers.image.revision", source_sha),
                ("org.opencontainers.image.version", release_id),
                ("org.opencontainers.image.ref.name", release_id),
                ("org.opencontainers.image.source", image.get("oci_source")),
            ):
                require(labels.get(field) == expected, f"{label} {service} raw OCI {field} mismatch")

            embedded_target = require_hashed_tracked_file(
                raw_image.get("embedded_hash"),
                f"{raw_root}/{service}-embedded-sha256.txt",
                f"{label} {service} embedded hash",
            )
            embedded_text = embedded_target.read_text(encoding="utf-8-sig").strip()
            embedded_match = re.fullmatch(r"([0-9a-f]{64})\s+\*?(.+)", embedded_text)
            require(embedded_match is not None, f"{label} {service} embedded hash output is invalid")
            require(
                embedded_match.group(1) == image.get("embedded_file_sha256")
                and embedded_match.group(2) == image.get("embedded_file"),
                f"{label} {service} raw embedded hash mismatch",
            )

            if service == "frontend":
                build_id_target = require_hashed_tracked_file(
                    raw_image.get("frontend_build_id"),
                    f"{raw_root}/frontend-build-id.txt",
                    f"{label} frontend build ID",
                )
                build_id = build_id_target.read_text(encoding="utf-8-sig").strip()
                require(bool(build_id), f"{label} frontend raw build ID is empty")
                require(build_id == image.get("frontend_build_id"), f"{label} frontend raw build ID mismatch")
    require(
        type(proof.get("phase5_progress_before_proof")) is int
        and proof.get("phase5_progress_after_proof") == proof["phase5_progress_before_proof"],
        f"{label} Phase-5 proof values must preserve source truth",
    )
    require(proof.get("progress_credit_claimed") is False, f"{label} may not claim progress credit")
    require(
        isinstance(proof.get("rollback_target"), str)
        and re.fullmatch(r"[0-9a-f]{40}", proof["rollback_target"]) is not None,
        f"{label} rollback target is invalid",
    )
    require(
        proof.get("rollback_target_source") == "active_release_candidate",
        f"{label} rollback target source mismatch",
    )
    for field in (
        "registry_publish",
        "hosted_staging_parity",
        "production_deploy",
        "release_promotion",
        "owner_review_approved",
        "secret_output",
    ):
        require(proof.get(field) is False, f"{label} {field} must remain false")
    non_claims = require_non_claims(proof.get("non_claims"), label)
    normalized_non_claims = "\n".join(non_claims).lower()
    require("ghcr" in normalized_non_claims, f"{label} must retain the GHCR non-claim")
    require("release promotion" in normalized_non_claims, f"{label} must retain the promotion non-claim")


def validate_candidate_runtime_proof(
    proof: dict[str, Any],
    release_id: str,
    source_sha: str,
    readiness_entry: dict[str, Any] | None = None,
    candidate_images_entry: dict[str, Any] | None = None,
) -> None:
    label = "candidate local verification candidate_runtime"
    legacy = is_legacy_evidence_binding(release_id, source_sha)
    require(
        proof.get("contract_version")
        == (
            "phase5-production-candidate-local-verification-v1"
            if legacy
            else "phase5-production-candidate-local-verification-v2"
        ),
        f"{label} contract mismatch",
    )
    require(
        proof.get("evidence_ref") == "phase5_local_production_candidate_verified",
        f"{label} evidence_ref mismatch",
    )
    require(proof.get("status") == "verified", f"{label} status mismatch")
    require(proof.get("verification_scope") == "full_with_browser", f"{label} must use full browser scope")
    require(proof.get("release_id") == release_id, f"{label} release_id mismatch")
    require(proof.get("source_commit_sha") == source_sha, f"{label} source SHA mismatch")
    if not legacy:
        raw_target = validate_v2_raw_log(
            "candidate-runtime",
            proof,
            readiness_entry,
            release_id,
            source_sha,
        )
    require(proof.get("service_count") == 6, f"{label} service count mismatch")
    for field in (
        "api_contract_verified",
        "local_image_identity_verified",
        "embedded_source_hash_parity_verified",
        "candidate_runtime_source_parity_verified",
        "browser_click_verified",
    ):
        require(proof.get(field) is True, f"{label} {field} must be true")
    for field in (
        "registry_publish",
        "hosted_staging_parity",
        "production_deploy",
        "release_promotion",
        "secret_output",
    ):
        require(proof.get(field) is False, f"{label} {field} must remain false")
    require(
        isinstance(proof.get("rollback_target"), str)
        and re.fullmatch(r"[0-9a-f]{40}", proof["rollback_target"]) is not None,
        f"{label} rollback target is invalid",
    )
    if not legacy:
        raw_evidence = proof.get("raw_evidence")
        require(isinstance(raw_evidence, dict), f"{label} raw_evidence is missing")
        candidate_images_target = require_hashed_tracked_file(
            raw_evidence.get("candidate_images"),
            f"docs/release-artifacts/{release_id}-evidence/candidate-images.json",
            f"{label} candidate images",
        )
        require(isinstance(candidate_images_entry, dict), f"{label} candidate-images readiness entry is missing")
        require(
            raw_evidence["candidate_images"].get("sha256") == candidate_images_entry.get("sha256"),
            f"{label} candidate-images SHA-256 does not match readiness",
        )
        candidate_images = load_json(candidate_images_target)
        require(
            candidate_images.get("contract_version") == "phase5-production-candidate-local-v2",
            f"{label} linked candidate-images contract mismatch",
        )
        require(candidate_images.get("release_id") == release_id, f"{label} linked release mismatch")
        require(candidate_images.get("source_commit_sha") == source_sha, f"{label} linked source mismatch")

        api_target = require_hashed_tracked_file(
            raw_evidence.get("api_contract"),
            f"docs/release-artifacts/{release_id}-evidence/raw/candidate-runtime-api-contract.json",
            f"{label} API contract",
        )
        api_contract = load_json(api_target)
        require(
            api_contract.get("contract_version") == "phase5-production-candidate-local-v1",
            f"{label} API contract version mismatch",
        )
        require(
            api_contract.get("evidence_ref") == "phase5_local_production_candidate_verified",
            f"{label} API evidence_ref mismatch",
        )
        require(api_contract.get("service_count") == 6, f"{label} API service count mismatch")
        for field in (
            "registry_publish",
            "hosted_staging_parity",
            "production_deploy",
            "release_promotion",
            "owner_review_approved",
            "secret_output",
        ):
            require(api_contract.get(field) is False, f"{label} API {field} must remain false")

        screenshot_target = require_hashed_tracked_file(
            raw_evidence.get("browser_screenshot"),
            (
                f"docs/release-artifacts/{release_id}-evidence/raw/"
                "candidate-runtime-browser.png"
            ),
            f"{label} browser screenshot",
        )
        screenshot_bytes = screenshot_target.read_bytes()
        require(
            len(screenshot_bytes) >= 1024 and screenshot_bytes.startswith(b"\x89PNG\r\n\x1a\n"),
            f"{label} browser screenshot is not a non-empty PNG",
        )
        screenshot_size = raw_evidence["browser_screenshot"].get("size_bytes")
        require(
            type(screenshot_size) is int and screenshot_size == len(screenshot_bytes),
            f"{label} browser screenshot size mismatch",
        )


def rounded_binary_percent(verified: int, total: int) -> int:
    require(total > 0, "rubric denominator must be positive")
    return math.floor((verified * 100 / total) + 0.5)


def load_git_json(source_sha: str, path: str) -> dict[str, Any]:
    result = run_git("show", f"{source_sha}:{path}")
    require(result.returncode == 0, f"candidate source is missing {path}")
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in candidate source {path}: {exc}")
    require(isinstance(value, dict), f"candidate source {path} must contain an object")
    return value


def load_git_text(source_sha: str, path: str) -> str:
    result = run_git("show", f"{source_sha}:{path}")
    require(result.returncode == 0, f"candidate source is missing {path}")
    return result.stdout


def load_index_text(path: str) -> str:
    result = run_git("show", f":{path}")
    require(result.returncode == 0, f"staged qualification truth is missing {path}")
    return result.stdout


def load_index_json(path: str) -> dict[str, Any]:
    text = load_index_text(path)
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in staged qualification truth {path}: {exc}")
    require(isinstance(value, dict), f"staged qualification truth {path} must contain an object")
    return value


def canonical_text_sha256(value: str) -> str:
    return hashlib.sha256(value.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")).hexdigest()


def phase5_credit_projection(payload: dict[str, Any]) -> dict[str, Any]:
    items = payload.get("items", [])
    projected_items: list[dict[str, Any]] = []
    if isinstance(items, list):
        for item in items:
            if not isinstance(item, dict):
                projected_items.append({"invalid": True})
                continue
            projected_items.append(
                {
                    key: item.get(key)
                    for key in (
                        "id",
                        "section",
                        "title",
                        "status",
                        "credit_awarded",
                        "blocker_id",
                        "owner_action",
                        "policy_basis",
                    )
                    if key in item
                }
            )
    return {
        "contract_version": payload.get("contract_version"),
        "mode": payload.get("mode"),
        "credit_blocked_until_candidate_qualified": payload.get(
            "credit_blocked_until_candidate_qualified"
        ),
        "cell_id": payload.get("cell_id"),
        "checklist_path": payload.get("checklist_path"),
        "rubric": payload.get("rubric"),
        "scoring_rule": payload.get("scoring_rule"),
        "legacy_gap_reconstruction": payload.get("legacy_gap_reconstruction"),
        "rulings_applied": payload.get("rulings_applied"),
        "current_score": payload.get("current_score"),
        "items": projected_items,
        "retired_noncriteria": payload.get("retired_noncriteria"),
    }


def external_gate_truth_projection(payload: dict[str, Any]) -> dict[str, Any]:
    keys = (
        "contract_version",
        "source_contract_version",
        "status",
        "active_target_gate",
        "active_release_candidate_sha",
        "ghcr_published_manifest_ref",
        "ghcr_candidate_readback_source_artifact",
        "gate_ids",
        "frontend_preview_claim_allowed",
        "hosted_staging_claim_allowed",
        "branch_protection_claim_allowed",
        "ghcr_image_digest_claim_allowed",
        "vercel_backend_origins_claim_allowed",
        "canonical_gitleaks_claim_allowed",
        "cloudflare_native_zero_card_hosted_runtime_claim_allowed",
        "gitlab_identity_claim_allowed",
        "huggingface_identity_claim_allowed",
        "grafana_cloud_claim_allowed",
        "production_deploy_claim_allowed",
        "missing_or_failed_gates",
        "failed_hosted_required_probe_ids",
        "failed_vercel_origin_probe_ids",
        "legacy_provenance",
    )
    return {key: payload.get(key) for key in keys}


def require_no_credit_requalification(
    source_sha: str,
    manifest: dict[str, Any],
    itemization: dict[str, Any],
    computed_percent: int,
    *,
    same_day_transition: bool,
) -> None:
    source_manifest = load_git_json(source_sha, PROJECT_PROGRESS_MANIFEST_REPO_PATH)
    index_manifest = load_index_json(PROJECT_PROGRESS_MANIFEST_REPO_PATH)
    require(
        manifest == index_manifest,
        "working-tree project progress must exactly match the staged qualification truth",
    )
    require(
        {key: value for key, value in index_manifest.items() if key != "last_verified"}
        == {key: value for key, value in source_manifest.items() if key != "last_verified"},
        "no-credit requalification may change only project progress last_verified",
    )
    require(
        index_manifest.get("overall_percent") == source_manifest.get("overall_percent"),
        "no-credit requalification may not change overall progress",
    )
    source_phase5 = next(
        (
            entry
            for entry in source_manifest.get("horizontal", {}).get("items", [])
            if entry.get("id") == "phase_5"
        ),
        None,
    )
    index_phase5 = next(
        (
            entry
            for entry in index_manifest.get("horizontal", {}).get("items", [])
            if entry.get("id") == "phase_5"
        ),
        None,
    )
    require(source_phase5 is not None and index_phase5 is not None, "no-credit requalification requires phase_5")
    require(
        source_phase5.get("percent") == index_phase5.get("percent") == computed_percent,
        "no-credit requalification may not change Phase-5 credit",
    )

    source_itemization = load_git_json(source_sha, PHASE5_ITEMIZATION_REPO_PATH)
    index_itemization = load_index_json(PHASE5_ITEMIZATION_REPO_PATH)
    require(
        itemization == index_itemization,
        "working-tree Phase-5 truth must exactly match the staged qualification truth",
    )
    require(
        phase5_credit_projection(index_itemization) == phase5_credit_projection(source_itemization),
        "no-credit requalification may not change the Phase-5 score, blockers, or rulings",
    )
    require(
        index_itemization.get("mode") == "fully_itemized"
        and index_itemization.get("credit_blocked_until_candidate_qualified") is False,
        "no-credit requalification requires fully itemized, already-qualified credit truth",
    )
    require(
        index_itemization.get("active_source_commit_sha") == source_sha,
        "no-credit requalification must select the exact candidate source",
    )

    source_pointer = load_git_json(source_sha, CURRENT_RELEASE_CANDIDATE_REPO_PATH)
    index_pointer = load_index_json(CURRENT_RELEASE_CANDIDATE_REPO_PATH)
    release_id = str(index_itemization.get("active_release_id", ""))
    require(
        re.fullmatch(r"prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+", release_id) is not None,
        "no-credit requalification release ID is invalid",
    )
    require(
        release_id != source_pointer.get("active_release_id"),
        "no-credit requalification must advance the active release ID",
    )
    require(
        index_pointer.get("active_release_id") == release_id
        and index_pointer.get("source_commit_sha") == source_sha,
        "no-credit requalification pointer must select the exact release and source",
    )
    require(
        index_pointer.get("updated_at") == index_itemization.get("updated_at_utc"),
        "no-credit requalification pointer and itemization timestamps must match",
    )
    pointer_updated_at = str(index_pointer.get("updated_at", ""))
    require(
        re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", pointer_updated_at) is not None,
        "no-credit requalification pointer timestamp is invalid",
    )
    current_verified_date = str(index_manifest.get("last_verified", ""))
    source_verified_date = str(source_manifest.get("last_verified", ""))
    require(
        current_verified_date == pointer_updated_at[:10],
        "no-credit requalification manifest last_verified must match the candidate date",
    )
    require(
        re.fullmatch(r"\d{4}-\d{2}-\d{2}", source_verified_date) is not None,
        "candidate source manifest last_verified is invalid",
    )
    if same_day_transition:
        require(
            current_verified_date == source_verified_date,
            "same-day no-credit requalification must keep the manifest date unchanged",
        )
    else:
        require(
            current_verified_date > source_verified_date,
            "cross-day no-credit requalification must advance the manifest date",
        )

    source_platform = load_git_text(source_sha, PLATFORM_MANIFEST_REPO_PATH)
    index_platform = load_index_text(PLATFORM_MANIFEST_REPO_PATH)
    source_snapshot_token = f'snapshot: "{source_verified_date}"'
    current_snapshot_token = f'snapshot: "{current_verified_date}"'
    source_dated_token = f"dated {source_verified_date}"
    current_dated_token = f"dated {current_verified_date}"
    require(
        source_platform.count(source_snapshot_token) == 1
        and source_platform.count(source_dated_token) == 1,
        "candidate source platform manifest date markers are ambiguous",
    )
    expected_platform = source_platform.replace(
        source_snapshot_token,
        current_snapshot_token,
        1,
    ).replace(source_dated_token, current_dated_token, 1)
    require(
        index_platform == expected_platform,
        "no-credit requalification platform may change only the manifest snapshot date",
    )
    require(
        index_pointer.get("production_rollout_claimed") is False,
        "no-credit requalification may not claim production rollout",
    )
    require(
        source_pointer.get("source_commit_sha") == source_itemization.get("active_source_commit_sha"),
        "source candidate pointer and source Phase-5 truth are inconsistent",
    )

    source_external = load_git_json(source_sha, EXTERNAL_GATE_SUMMARY_REPO_PATH)
    index_external = load_index_json(EXTERNAL_GATE_SUMMARY_REPO_PATH)
    require(
        external_gate_truth_projection(index_external) == external_gate_truth_projection(source_external),
        "no-credit requalification may not inflate external gate truth",
    )
    require(
        index_external.get("requested_release_candidate_selector") == source_sha,
        "no-credit requalification external selector must equal the candidate source",
    )
    require(
        index_external.get("status") == "blocked"
        and index_external.get("active_release_candidate_sha") == ""
        and index_external.get("production_deploy_claim_allowed") is False,
        "no-credit requalification must preserve blocked external production truth",
    )

    snapshot = load_index_json(ENDPOINT_SNAPSHOT_REPO_PATH)
    metadata = snapshot.get("__snapshot_metadata", {})
    require(isinstance(metadata, dict), "no-credit requalification snapshot metadata is missing")
    endpoint_keys = [key for key in snapshot if key != "__snapshot_metadata"]
    require(
        len(endpoint_keys) == 34 and all(key.startswith("/api/v1/") for key in endpoint_keys),
        "no-credit requalification requires the full 34-endpoint snapshot",
    )
    require(
        snapshot.get("/api/v1/project/progress") == index_manifest,
        "no-credit requalification snapshot progress must equal the unchanged manifest",
    )
    for field, expected in (
        ("contract_version", "endpoint-snapshot-metadata-v1"),
        ("refresh_scope", "full"),
        ("payload_epoch_complete", True),
        ("current", False),
        ("current_reason", "runtime_source_unattested_prequalification"),
        ("qualification_state", "prequalification"),
        ("source_scope", "DEV-ONLY"),
        ("target_scope", "localhost_only"),
        ("endpoint_count", 34),
        ("refreshed_endpoint_count", 34),
        ("gate_refresh_atomic", True),
        ("active_release_id", release_id),
        ("candidate_source_commit_sha", source_sha),
        ("runtime_source_commit_sha", None),
        ("runtime_source_attested", False),
        ("candidate_source_parity", False),
    ):
        require(metadata.get(field) == expected, f"no-credit requalification snapshot {field} mismatch")

    candidate_artifact_path = f"docs/release-artifacts/{release_id}.md"
    expected_hashes = {
        "current_release_candidate_sha256": canonical_text_sha256(
            load_index_text(CURRENT_RELEASE_CANDIDATE_REPO_PATH)
        ),
        "release_candidate_artifact_sha256": canonical_text_sha256(
            load_index_text(candidate_artifact_path)
        ),
        "project_progress_manifest_sha256": canonical_text_sha256(
            load_index_text(PROJECT_PROGRESS_MANIFEST_REPO_PATH)
        ),
        "external_gate_summary_sha256": canonical_text_sha256(
            load_index_text(EXTERNAL_GATE_SUMMARY_REPO_PATH)
        ),
    }
    for field, expected in expected_hashes.items():
        require(metadata.get(field) == expected, f"no-credit requalification snapshot {field} mismatch")

    project_state = load_index_text("PROJECT_STATE.md")
    current_anchor = project_state.split("### Session", 2)[1] if "### Session" in project_state else ""
    require(
        release_id in current_anchor and source_sha in current_anchor,
        "no-credit requalification project anchor must name the exact release and source",
    )
    require(
        "Overall `89%`" in current_anchor
        and "MARKET_READY:false" in current_anchor
        and "I1" in current_anchor
        and "I5" in current_anchor,
        "no-credit requalification project anchor must preserve progress and Owner blockers",
    )


def require_runtime_source_parity(
    source_sha: str,
    manifest: dict[str, Any],
    itemization: dict[str, Any],
    computed_percent: int,
) -> None:
    diff = run_git(
        "diff",
        "--cached",
        "--name-only",
        "--diff-filter=ACDMRTUXB",
        "-z",
        source_sha,
        "--",
        *RUNTIME_SOURCE_PATHS,
    )
    require(diff.returncode == 0, "could not compare candidate runtime source with the current index")
    changed_paths = {path for path in diff.stdout.split("\0") if path}
    if not changed_paths:
        return

    if changed_paths in (
        NO_CREDIT_REQUALIFICATION_RUNTIME_PATHS,
        NO_CREDIT_REQUALIFICATION_SAME_DAY_RUNTIME_PATHS,
    ):
        require_no_credit_requalification(
            source_sha,
            manifest,
            itemization,
            computed_percent,
            same_day_transition=(
                changed_paths == NO_CREDIT_REQUALIFICATION_SAME_DAY_RUNTIME_PATHS
            ),
        )
        print(
            "[phase5-credit] runtime_source_parity_mode=no_credit_requalification "
            "progress_credit_changed=false"
        )
        return

    require(
        changed_paths == QUALIFICATION_TRUTH_PATHS,
        "active candidate has committed or staged runtime-source drift outside the exact post-qualification or no-credit requalification truth transition",
    )
    require(
        itemization.get("mode") == "fully_itemized",
        "post-qualification truth transition requires fully_itemized mode",
    )
    require(
        itemization.get("credit_blocked_until_candidate_qualified") is False,
        "post-qualification truth transition must clear the credit block",
    )

    source_manifest = load_git_json(source_sha, "docs/project-progress.manifest.json")
    source_phase5 = next(
        (
            item
            for item in source_manifest.get("horizontal", {}).get("items", [])
            if item.get("id") == "phase_5"
        ),
        None,
    )
    current_phase5 = next(
        (
            item
            for item in manifest.get("horizontal", {}).get("items", [])
            if item.get("id") == "phase_5"
        ),
        None,
    )
    require(source_phase5 is not None, "candidate source manifest is missing phase_5")
    require(current_phase5 is not None, "current manifest is missing phase_5")
    legacy_percent = itemization.get("legacy_gap_reconstruction", {}).get("recorded_percent")
    require(source_phase5.get("percent") == legacy_percent, "candidate source must carry the pre-proof Phase-5 value")
    require(current_phase5.get("percent") == computed_percent, "current Phase-5 value must equal the qualified score")
    source_overall = source_manifest.get("overall_percent")
    current_overall = manifest.get("overall_percent")
    require(isinstance(source_overall, int), "candidate source overall percent is invalid")
    require(isinstance(current_overall, int), "current overall percent is invalid")
    require(
        current_overall - source_overall == (computed_percent - legacy_percent) // 7,
        "post-qualification overall delta does not match the Phase-5-only score transition",
    )


def extract_field(artifact: str, field: str) -> str:
    match = re.search(rf"(?m)^{re.escape(field)}:\s*`([^`]+)`\s*$", artifact)
    require(match is not None, f"active candidate missing field {field}")
    return match.group(1)


def validate_candidate(
    release_id: str,
    source_sha: str,
    computed_percent: int,
    verified_count: int,
    blocked_count: int,
    expected_blocked_item_ids: set[str],
    manifest: dict[str, Any],
    itemization: dict[str, Any],
) -> None:
    candidate_path = ROOT / f"docs/release-artifacts/{release_id}.md"
    readiness_path = ROOT / f"docs/release-artifacts/{release_id}-readiness.json"
    require_tracked_repo_path(candidate_path.relative_to(ROOT).as_posix(), "active candidate")
    require_tracked_repo_path(readiness_path.relative_to(ROOT).as_posix(), "active candidate readiness")

    artifact = candidate_path.read_text(encoding="utf-8")
    require(extract_field(artifact, "release_id") == release_id, "candidate release_id mismatch")
    require(
        extract_field(artifact, "environment") == "production-candidate",
        "candidate environment must be production-candidate",
    )
    require(extract_field(artifact, "source_commit_sha") == source_sha, "candidate source SHA mismatch")
    require(
        extract_field(artifact, "immutable_image_commit_sha") == source_sha,
        "candidate immutable image SHA mismatch",
    )
    require(extract_field(artifact, "review_gate") == "pending", "candidate review gate must remain pending")
    require(extract_field(artifact, "owner_decision") == "no-release", "candidate owner decision must be no-release")
    require(
        extract_field(artifact, "hosted_staging_parity") == "false",
        "candidate hosted parity must remain false while I1 is blocked",
    )
    require(
        extract_field(artifact, "production_rollout_claimed") == "false",
        "candidate may not claim production rollout",
    )
    require(
        int(extract_field(artifact, "checklist_verified_count")) == verified_count,
        "candidate verified-count mismatch",
    )
    require(
        int(extract_field(artifact, "checklist_blocked_count")) == blocked_count,
        "candidate blocked-count mismatch",
    )
    require(
        int(extract_field(artifact, "phase5_computed_percent")) == computed_percent,
        "candidate Phase-5 percent mismatch",
    )
    require(
        "This artifact does not claim a production rollout." in artifact,
        "candidate production non-claim is missing",
    )

    table_rows = re.findall(r"(?m)^\|\s*([CIVO]\d)\s*\|\s*(JA|NEIN)\s*\|", artifact)
    require(len(table_rows) == 19, "candidate must contain exactly 19 JA/NEIN checklist rows")
    row_map = {item_id: answer for item_id, answer in table_rows}
    require(set(row_map) == set(EXPECTED_ITEMS), "candidate checklist row IDs mismatch")
    require(
        {item_id for item_id, answer in row_map.items() if answer == "NEIN"}
        == expected_blocked_item_ids,
        "candidate NEIN rows must match the validated blocked-item set",
    )

    readiness = load_json(readiness_path)
    require(
        readiness.get("contract_version") == "phase5-candidate-readiness-evidence-v1",
        "candidate readiness contract mismatch",
    )
    require(readiness.get("release_id") == release_id, "readiness release_id mismatch")
    require(readiness.get("source_commit_sha") == source_sha, "readiness source SHA mismatch")
    require(readiness.get("status") == "verified_with_owner_blocks", "readiness status mismatch")
    require(readiness.get("verified_item_count") == verified_count, "readiness verified count mismatch")
    require(readiness.get("blocked_item_count") == blocked_count, "readiness blocked count mismatch")
    require(
        set(readiness.get("blocked_item_ids", [])) == expected_blocked_item_ids,
        "readiness blocked IDs mismatch",
    )

    validate_ci_workflow(readiness.get("ci_workflow"), release_id, source_sha)

    local = readiness.get("local_verification", {})
    require(isinstance(local, dict), "candidate local verification must be an object")
    require(
        set(local) == set(LOCAL_VERIFICATION_FILES),
        "candidate readiness must contain exactly the five independent local verification chains",
    )
    # "static" is deliberately NOT required here. That entry records `npm run verify`, which
    # runs this very check - requiring it made the mandatory gate demand its own passing
    # output as its input. A chain cannot be its own evidence. The remaining five are
    # independent chains and stay required.
    for key, evidence_filename in LOCAL_VERIFICATION_FILES.items():
        entry = local.get(key, {})
        require(entry.get("status") == "passed", f"candidate local verification {key} must pass")
        require(
            isinstance(entry.get("command"), str) and entry["command"].strip(),
            f"candidate local verification {key} command is missing",
        )
        artifact_path = require_tracked_repo_path(
            entry.get("artifact"),
            f"candidate local verification {key}",
        )
        expected_artifact_path = (
            f"docs/release-artifacts/{release_id}-evidence/{evidence_filename}"
        )
        require(
            artifact_path == expected_artifact_path,
            f"candidate local verification {key} must use {expected_artifact_path}",
        )
        artifact_target = ROOT / artifact_path
        require_upper_sha256(
            entry.get("sha256"),
            f"candidate local verification {key} SHA-256",
        )
        require(
            sha256_file(artifact_target) == entry["sha256"],
            f"candidate local verification {key} SHA-256 does not match {artifact_path}",
        )
        success_anchors = entry.get("success_anchors")
        require(
            isinstance(success_anchors, list) and success_anchors,
            f"candidate local verification {key} success_anchors must not be empty",
        )
        if is_legacy_evidence_binding(release_id, source_sha):
            for index, anchor in enumerate(success_anchors):
                require_anchor(
                    artifact_target,
                    anchor,
                    f"candidate local verification {key} success anchor #{index + 1}",
                )
        else:
            for index, anchor in enumerate(success_anchors):
                require(
                    isinstance(anchor, str) and len(anchor.strip()) >= 8,
                    f"candidate local verification {key} success anchor #{index + 1} is invalid",
                )

        proof = load_json(artifact_target)
        require(
            proof.get("release_id") == release_id,
            f"candidate local verification {key} release_id mismatch",
        )
        require(
            proof.get("source_commit_sha") == source_sha,
            f"candidate local verification {key} source SHA mismatch",
        )
        if key in SUMMARY_CHAINS:
            validate_summary_proof(key, proof, entry, release_id, source_sha)
        elif key == "candidate_images":
            validate_candidate_images_proof(proof, release_id, source_sha, entry)
        else:
            validate_candidate_runtime_proof(
                proof,
                release_id,
                source_sha,
                entry,
                local.get("candidate_images"),
            )

    require(
        run_git("cat-file", "-e", f"{source_sha}^{{commit}}").returncode == 0,
        "candidate source commit does not exist",
    )
    require(
        run_git("merge-base", "--is-ancestor", source_sha, "HEAD").returncode == 0,
        "candidate source commit is not an ancestor of HEAD",
    )
    require_runtime_source_parity(source_sha, manifest, itemization, computed_percent)


def main() -> int:
    manifest = load_json(MANIFEST_PATH)
    itemization = load_json(ITEMIZATION_PATH)
    current_candidate = load_json(CURRENT_CANDIDATE_PATH)
    gates = load_json(CAPABILITY_GATES_PATH).get("gates", {})

    require(
        itemization.get("contract_version") == "phase5-credit-itemization-v2",
        "itemization contract must be phase5-credit-itemization-v2",
    )
    # Two modes exist so that credit can follow proof instead of preceding it.
    #
    #   legacy_reconstruction - the 19-item rubric is recorded and the historical 68 is
    #       reproduced from it, but the active candidate is not yet qualified. The cell
    #       stays at the proven legacy value. This is the honest resting state.
    #   fully_itemized - the candidate carries its own passing qualification runs, so the
    #       cell may carry the freshly computed score.
    #
    # Without the first mode the gate was unreachable: it demanded a qualified candidate
    # before it would let the chain that qualifies the candidate run at all.
    mode = itemization.get("mode")
    require(
        mode in {"legacy_reconstruction", "fully_itemized"},
        "itemization mode must be legacy_reconstruction or fully_itemized",
    )
    require(itemization.get("cell_id") == "phase_5", "itemization cell must be phase_5")
    require(
        itemization.get("checklist_path") == "docs/release-checklist.md",
        "itemization checklist path mismatch",
    )

    release_id = str(itemization.get("active_release_id", ""))
    source_sha = str(itemization.get("active_source_commit_sha", ""))
    require(
        re.fullmatch(r"prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+", release_id) is not None,
        "active release ID is invalid",
    )
    require(re.fullmatch(r"[0-9a-f]{40}", source_sha) is not None, "active source SHA is invalid")
    require(current_candidate.get("active_release_id") == release_id, "current candidate pointer mismatch")
    require(current_candidate.get("production_rollout_claimed") is False, "current candidate may not claim rollout")

    auth_transition_verified = validate_production_auth_transition(
        gates.get("production_auth_identity", {}),
        source_sha,
    )
    expected_blocked_item_ids = expected_blocked_ids(
        auth_transition_verified=auth_transition_verified,
    )

    checklist = CHECKLIST_PATH.read_text(encoding="utf-8")
    require(
        "Rubrik: `phase5-release-readiness-19-v2`" in checklist,
        "release checklist rubric version is missing",
    )
    require(
        len(re.findall(r"(?m)^- \[ \] ", checklist)) == 19,
        "release checklist must contain exactly 19 binary items",
    )

    legacy = itemization.get("legacy_gap_reconstruction", {})
    require(legacy.get("recorded_percent") == 68, "legacy recorded percent must be 68")
    require(legacy.get("verified_item_count") == 13, "legacy verified count must be 13")
    require(legacy.get("missing_item_count") == 6, "legacy missing count must be 6")
    require(set(legacy.get("missing_item_ids", [])) == LEGACY_MISSING_IDS, "legacy missing IDs mismatch")
    require(
        legacy.get("reconstructed_percent") == rounded_binary_percent(13, 19),
        "legacy reconstructed percent mismatch",
    )
    require(
        legacy.get("rounded_gap_points") == 100 - rounded_binary_percent(13, 19),
        "legacy gap must reconstruct the missing 32 points",
    )

    items = itemization.get("items", [])
    require(isinstance(items, list) and len(items) == 19, "itemization must contain exactly 19 items")
    by_id: dict[str, dict[str, Any]] = {}
    for item in items:
        require(isinstance(item, dict), "itemization entries must be objects")
        item_id = str(item.get("id", ""))
        require(item_id in EXPECTED_ITEMS, f"unknown checklist item {item_id}")
        require(item_id not in by_id, f"duplicate checklist item {item_id}")
        by_id[item_id] = item
        require(item.get("section") == EXPECTED_ITEMS[item_id], f"{item_id} section mismatch")
        require(item.get("status") in {"verified", "blocked_owner"}, f"{item_id} status is invalid")
        require(
            item.get("credit_awarded") is (item.get("status") == "verified"),
            f"{item_id} credit_awarded must match status",
        )
        evidence = item.get("evidence", [])
        require(isinstance(evidence, list) and evidence, f"{item_id} evidence must not be empty")
        for index, entry in enumerate(evidence):
            require(isinstance(entry, dict), f"{item_id} evidence #{index + 1} must be an object")
            normalized = require_tracked_repo_path(entry.get("path"), f"{item_id} evidence #{index + 1}")
            require(
                isinstance(entry.get("claim"), str) and entry["claim"].strip(),
                f"{item_id} evidence #{index + 1} claim is missing",
            )
            require_anchor(
                ROOT / normalized,
                entry.get("anchor"),
                f"{item_id} evidence #{index + 1}",
            )

    require(set(by_id) == set(EXPECTED_ITEMS), "itemization IDs do not cover the full checklist")
    blocked_ids = {item_id for item_id, item in by_id.items() if item["status"] == "blocked_owner"}
    require(
        blocked_ids == expected_blocked_item_ids,
        "current blocked items must match the validated gate transitions",
    )
    require(
        by_id["I2"].get("policy_basis") == "E3_release_candidate_ready_ghcr_post_market",
        "I2 must encode the E3 post-market ruling",
    )
    require(by_id["I2"]["status"] == "verified", "I2 immutable candidate proof must be verified")

    retired = itemization.get("retired_noncriteria", [])
    require(isinstance(retired, list) and len(retired) == 6, "six retired RC1 markers must be recorded")
    retired_ids = {str(entry.get("marker")) for entry in retired if isinstance(entry, dict)}
    require(retired_ids == RETIRED_RC1_MARKERS, "retired RC1 marker set mismatch")
    for entry in retired:
        require(entry.get("status") == "retired_noncriterion", "retired marker status mismatch")
        require(entry.get("credit_awarded") is False, "retired markers may not receive credit")

    verified_count = sum(item["status"] == "verified" for item in items)
    blocked_count = len(items) - verified_count
    computed_percent = rounded_binary_percent(verified_count, len(items))
    current = itemization.get("current_score", {})
    require(current.get("total_item_count") == 19, "current rubric denominator mismatch")
    require(current.get("verified_item_count") == verified_count, "current verified count mismatch")
    require(current.get("blocked_item_count") == blocked_count, "current blocked count mismatch")
    require(current.get("computed_percent") == computed_percent, "current computed percent mismatch")
    expected_percent = rounded_binary_percent(
        len(EXPECTED_ITEMS) - len(expected_blocked_item_ids),
        len(EXPECTED_ITEMS),
    )
    require(
        computed_percent == expected_percent,
        "current evidence must derive the Phase-5 score from validated blockers",
    )

    phase5 = next(
        (item for item in manifest.get("horizontal", {}).get("items", []) if item.get("id") == "phase_5"),
        None,
    )
    require(phase5 is not None, "manifest is missing phase_5")

    legacy_percent = rounded_binary_percent(13, 19)
    if mode == "legacy_reconstruction":
        # The rubric already computes a higher score, but the candidate that would prove it
        # has not been qualified. Recording the higher number here would be crediting an
        # unfinished proof, so the cell stays at the reconstructed legacy value.
        require(
            phase5.get("percent") == legacy_percent,
            "legacy mode requires manifest phase_5 to stay at the reconstructed legacy percent",
        )
        require(
            itemization.get("credit_blocked_until_candidate_qualified") is True,
            "legacy mode must state that credit is blocked until the candidate qualifies",
        )
        require(
            "phase5_release_readiness_19_item_score_pending_candidate_qualification"
            in str(phase5.get("status", "")),
            "legacy mode requires the pending-qualification marker, not a verified marker",
        )
    else:
        require(phase5.get("percent") == computed_percent, "manifest phase_5 must equal computed percent")
        require(
            itemization.get("credit_blocked_until_candidate_qualified") is False,
            "fully_itemized mode must clear the candidate qualification credit block",
        )
        require(
            "phase5_release_readiness_19_item_score_verified" in str(phase5.get("status", "")),
            "manifest is missing the Phase-5 itemization marker",
        )

    require(
        (by_id["I5"]["status"] == "verified") is auth_transition_verified,
        "I5 status must match the validated production-auth transition",
    )
    registry_gate = gates.get("docker_registry_publish", {})
    require(registry_gate.get("owner_granted") is False, "E3 must not silently grant registry publication")
    require(registry_gate.get("live_verified") is False, "E3 must not silently verify registry publication")

    if mode == "fully_itemized":
        validate_candidate(
            release_id,
            source_sha,
            computed_percent,
            verified_count,
            blocked_count,
            expected_blocked_item_ids,
            manifest,
            itemization,
        )
    credited = legacy_percent if mode == "legacy_reconstruction" else computed_percent
    print(
        f"[phase5-credit] verified mode={mode} legacy_gap=32 "
        f"computed={computed_percent} credited={credited} verified={verified_count}/19 "
        f"blocked={','.join(sorted(blocked_ids))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
