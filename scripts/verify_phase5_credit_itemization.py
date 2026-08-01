from __future__ import annotations

import json
import hashlib
import math
import re
import subprocess
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
CURRENT_BLOCKED_IDS = {"I1", "I5"}
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


def require_runtime_source_parity(
    source_sha: str,
    manifest: dict[str, Any],
    itemization: dict[str, Any],
    computed_percent: int,
) -> None:
    diff = run_git(
        "diff",
        "--name-only",
        "--diff-filter=ACMRTUXB",
        "-z",
        f"{source_sha}..HEAD",
        "--",
        *RUNTIME_SOURCE_PATHS,
    )
    require(diff.returncode == 0, "could not compare candidate runtime source with HEAD")
    changed_paths = {path for path in diff.stdout.split("\0") if path}
    if not changed_paths:
        return

    require(
        changed_paths == QUALIFICATION_TRUTH_PATHS,
        "active candidate has committed runtime-source drift outside the exact post-qualification truth transition",
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
        {item_id for item_id, answer in row_map.items() if answer == "NEIN"} == CURRENT_BLOCKED_IDS,
        "candidate NEIN rows must be exactly I1 and I5",
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
    require(set(readiness.get("blocked_item_ids", [])) == CURRENT_BLOCKED_IDS, "readiness blocked IDs mismatch")

    workflow = readiness.get("ci_workflow", {})
    require(workflow.get("status") == "success", "candidate CI workflow must be successful")
    require(workflow.get("head_sha") == source_sha, "candidate CI workflow SHA mismatch")
    require(
        isinstance(workflow.get("run_url"), str)
        and re.fullmatch(r"https://github\.com/[^/\s]+/[^/\s]+/actions/runs/\d+", workflow["run_url"]),
        "candidate CI workflow URL is invalid",
    )

    local = readiness.get("local_verification", {})
    # "static" is deliberately NOT required here. That entry records `npm run verify`, which
    # runs this very check - requiring it made the mandatory gate demand its own passing
    # output as its input. A chain cannot be its own evidence. The remaining five are
    # independent chains and stay required.
    for key in (
        "runtime",
        "browser",
        "candidate_images",
        "candidate_runtime",
        "security",
    ):
        entry = local.get(key, {})
        require(entry.get("status") == "passed", f"candidate local verification {key} must pass")
        require(
            isinstance(entry.get("command"), str) and entry["command"].strip(),
            f"candidate local verification {key} command is missing",
        )
        artifact_path, artifact_target = resolve_repo_file(
            entry.get("artifact"), f"candidate local verification {key}"
        )
        require(
            isinstance(entry.get("sha256"), str)
            and re.fullmatch(r"[0-9A-F]{64}", entry["sha256"]),
            f"candidate local verification {key} SHA-256 is invalid",
        )
        require(
            entry["sha256"] != "0" * 64,
            f"candidate local verification {key} SHA-256 may not be the all-zero placeholder",
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
        for index, anchor in enumerate(success_anchors):
            require_anchor(
                artifact_target,
                anchor,
                f"candidate local verification {key} success anchor #{index + 1}",
            )

        if key in {"candidate_images", "candidate_runtime"}:
            proof = load_json(artifact_target)
            require(proof.get("status") == "verified", f"candidate local verification {key} status mismatch")
            require(
                proof.get("source_commit_sha") == source_sha,
                f"candidate local verification {key} source SHA mismatch",
            )
            require(proof.get("service_count") == 6, f"candidate local verification {key} service count mismatch")
            if key == "candidate_images":
                require(proof.get("release_id") == release_id, "candidate image proof release_id mismatch")

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
    require(blocked_ids == CURRENT_BLOCKED_IDS, "current blocked items must be exactly I1 and I5")
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
    require(computed_percent == 89, "current evidence must derive Phase 5 as 89")

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

    release_id = str(itemization.get("active_release_id", ""))
    source_sha = str(itemization.get("active_source_commit_sha", ""))
    require(
        re.fullmatch(r"prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+", release_id) is not None,
        "active release ID is invalid",
    )
    require(re.fullmatch(r"[0-9a-f]{40}", source_sha) is not None, "active source SHA is invalid")
    require(current_candidate.get("active_release_id") == release_id, "current candidate pointer mismatch")
    require(current_candidate.get("production_rollout_claimed") is False, "current candidate may not claim rollout")

    auth_gate = gates.get("production_auth_identity", {})
    require(auth_gate.get("owner_granted") is False, "I5 may remain blocked only while auth owner grant is false")
    require(auth_gate.get("live_verified") is False, "I5 may remain blocked only while auth live proof is false")
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
