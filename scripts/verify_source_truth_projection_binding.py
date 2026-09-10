from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
BINDING_PATH = PurePosixPath("docs/runtime-state/source-truth-projection-binding.json")
CONTRACT_VERSION = "source-truth-projection-binding-v1"
BINDING_SCHEMA = "../../runtime-contracts/source-truth-projection-binding.schema.json"

TRUTH_PROJECTION_PATHS = {
    "PROJECT_STATE.md",
    "apps/frontend/lib/endpoint-snapshot.json",
    "apps/frontend/lib/platform.ts",
    "docs/project-progress.manifest.json",
}

POST_SOURCE_EXACT_PATHS = TRUTH_PROJECTION_PATHS | {
    "AI_HANDOFF.md",
    "CODEX_UEBERGABE_MASTER_2026-08-29.md",
    "CODEX_ZIEL_MASTER_2026-08-29.md",
    "LAYER_MATRIX.md",
    "PROJECT_ANCHOR_CURRENT.md",
    "docs/screen-inventory.md",
    "docs/verification-register.md",
}

POST_SOURCE_PREFIXES = (
    ".codex/runs/CURRENT/",
    ".phase1-artifacts/",
    "docs/release-artifacts/",
    "docs/runtime-state/",
)

RECEIPT_EXACT_PATHS = {
    "AI_HANDOFF.md",
    "PROJECT_ANCHOR_CURRENT.md",
    "docs/verification-register.md",
}

RECEIPT_PREFIXES = (
    ".codex/runs/CURRENT/",
    ".phase1-artifacts/",
    "docs/release-artifacts/",
    "docs/runtime-state/",
)

RUNTIME_PREFIXES = (
    ".github/workflows/",
    "apps/frontend/",
    "services/",
    "scripts/",
)

RUNTIME_EXACT_PATHS = {
    ".dockerignore",
    "docker-compose.cloud.yml",
    "docker-compose.yml",
    "package.json",
    "package-lock.json",
}


class VerificationError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def run_git(*args: str, text: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        capture_output=True,
        text=text,
        encoding="utf-8" if text else None,
        errors="strict" if text else None,
        check=False,
    )


def require_commit(value: str, label: str) -> str:
    require(re.fullmatch(r"[0-9a-f]{40}", value) is not None, f"{label} must be a lowercase 40-character SHA")
    result = run_git("cat-file", "-e", f"{value}^{{commit}}")
    require(result.returncode == 0, f"{label} does not exist as a local commit")
    return value


def require_ancestor(older: str, newer: str, label: str) -> None:
    result = run_git("merge-base", "--is-ancestor", older, newer)
    require(result.returncode == 0, f"{label}: {older} is not an ancestor of {newer}")


def normalize_path(value: str) -> str:
    normalized = PurePosixPath(value.replace("\\", "/")).as_posix()
    require(not normalized.startswith("../"), f"path escapes repository: {value}")
    return normalized


def diff_name_status(older: str, newer: str) -> list[tuple[str, str]]:
    result = run_git("diff", "--name-status", "--find-renames=100%", older, newer)
    require(result.returncode == 0, f"could not compare {older}..{newer}")
    rows: list[tuple[str, str]] = []
    for raw_line in result.stdout.splitlines():
        if not raw_line.strip():
            continue
        fields = raw_line.split("\t")
        status = fields[0]
        require(len(fields) >= 2, f"invalid git diff row: {raw_line}")
        if status.startswith(("R", "C")):
            require(len(fields) == 3, f"invalid rename/copy row: {raw_line}")
            rows.append((status, normalize_path(fields[1])))
            rows.append((status, normalize_path(fields[2])))
        else:
            rows.append((status, normalize_path(fields[1])))
    return rows


def allowed(path: str, exact: set[str], prefixes: tuple[str, ...]) -> bool:
    return path in exact or any(path.startswith(prefix) for prefix in prefixes)


def is_runtime_path(path: str) -> bool:
    if path in TRUTH_PROJECTION_PATHS:
        return False
    return path in RUNTIME_EXACT_PATHS or any(path.startswith(prefix) for prefix in RUNTIME_PREFIXES)


def require_allowlisted_diff(
    rows: list[tuple[str, str]],
    *,
    exact: set[str],
    prefixes: tuple[str, ...],
    label: str,
) -> set[str]:
    changed: set[str] = set()
    for status, path in rows:
        require(not status.startswith(("D", "R", "C")), f"{label} forbids deletion/rename/copy: {status} {path}")
        require(allowed(path, exact, prefixes), f"{label} contains a non-allowlisted path: {path}")
        changed.add(path)
    return changed


def git_json(commit: str, path: str) -> dict[str, Any]:
    result = run_git("show", f"{commit}:{path}")
    require(result.returncode == 0, f"missing JSON at {commit}:{path}")
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise VerificationError(f"invalid JSON at {commit}:{path}: {exc}") from exc
    require(isinstance(value, dict), f"JSON object required at {commit}:{path}")
    return value


def projection_hash(manifest: dict[str, Any]) -> str:
    projection = {
        "overall_percent": manifest.get("overall_percent"),
        "horizontal": [
            {"id": item.get("id"), "percent": item.get("percent")}
            for item in manifest.get("horizontal", {}).get("items", [])
        ],
        "vertical": [
            {"id": item.get("id"), "percent": item.get("percent")}
            for item in manifest.get("vertical", {}).get("items", [])
        ],
    }
    payload = json.dumps(projection, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def verify(runtime_sha: str, projection_sha: str, receipt_sha: str, require_ready: bool) -> dict[str, Any]:
    runtime_sha = require_commit(runtime_sha, "runtime_candidate_sha")
    projection_sha = require_commit(projection_sha, "truth_projection_sha")
    receipt_sha = require_commit(receipt_sha, "receipt_sha")
    require_ancestor(runtime_sha, projection_sha, "runtime-to-projection ancestry")
    require_ancestor(projection_sha, receipt_sha, "projection-to-receipt ancestry")

    source_rows = diff_name_status(runtime_sha, projection_sha)
    source_changed = require_allowlisted_diff(
        source_rows,
        exact=POST_SOURCE_EXACT_PATHS,
        prefixes=POST_SOURCE_PREFIXES,
        label="runtime-to-projection transition",
    )
    runtime_drift = sorted(path for _, path in source_rows if is_runtime_path(path))
    require(not runtime_drift, f"runtime product drift exists after source freeze: {','.join(runtime_drift)}")

    receipt_rows = diff_name_status(projection_sha, receipt_sha)
    receipt_changed = require_allowlisted_diff(
        receipt_rows,
        exact=RECEIPT_EXACT_PATHS,
        prefixes=RECEIPT_PREFIXES,
        label="projection-to-receipt transition",
    )
    require(
        not (receipt_changed & TRUTH_PROJECTION_PATHS),
        "receipt must not modify truth projection paths",
    )

    binding = git_json(receipt_sha, BINDING_PATH.as_posix())
    require(binding.get("contract_version") == CONTRACT_VERSION, "binding contract_version mismatch")
    require(binding.get("$schema") == BINDING_SCHEMA, "binding schema reference mismatch")
    require(binding.get("runtime_candidate_sha") == runtime_sha, "binding runtime_candidate_sha mismatch")
    require(binding.get("truth_projection_sha") == projection_sha, "binding truth_projection_sha mismatch")
    require(binding.get("source_ancestor_truth_projection") is True, "binding must attest source ancestry")
    require(binding.get("production_alias_mutated") is False, "binding may not claim a production-alias mutation")

    manifest = git_json(projection_sha, "docs/project-progress.manifest.json")
    computed_projection_hash = projection_hash(manifest)
    require(
        binding.get("truth_projection_sha256") == computed_projection_hash,
        "binding truth_projection_sha256 mismatch",
    )

    if require_ready:
        require(manifest.get("overall_percent") == 100, "final truth projection overall must be 100")
        horizontal = manifest.get("horizontal", {}).get("items", [])
        vertical = manifest.get("vertical", {}).get("items", [])
        require(len(horizontal) == 7 and all(item.get("percent") == 100 for item in horizontal), "all seven horizontal cells must be 100")
        require(len(vertical) == 7 and all(item.get("percent") == 100 for item in vertical), "all seven vertical cells must be 100")
        require(TRUTH_PROJECTION_PATHS <= source_changed, "final transition must change all four truth projection paths")

    return {
        "contract_version": CONTRACT_VERSION,
        "status": "verified",
        "runtime_candidate_sha": runtime_sha,
        "truth_projection_sha": projection_sha,
        "receipt_sha": receipt_sha,
        "source_ancestor_truth_projection": True,
        "runtime_product_drift": False,
        "runtime_to_projection_changed_path_count": len(source_changed),
        "projection_to_receipt_changed_path_count": len(receipt_changed),
        "truth_projection_sha256": computed_projection_hash,
        "market_ready_projection_required": require_ready,
        "production_alias_mutated": False,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify immutable runtime S, truth projection T, and receipt R.")
    parser.add_argument("--runtime-sha", required=True)
    parser.add_argument("--projection-sha", required=True)
    parser.add_argument("--receipt-sha", default="HEAD")
    parser.add_argument("--require-ready", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    receipt = args.receipt_sha
    if receipt == "HEAD":
        result = run_git("rev-parse", "HEAD")
        require(result.returncode == 0, "could not resolve HEAD")
        receipt = result.stdout.strip()
    report = verify(args.runtime_sha, args.projection_sha, receipt, args.require_ready)
    if args.json:
        print(json.dumps(report, sort_keys=True, separators=(",", ":")))
    else:
        print(
            "[source-truth-projection] verified "
            f"runtime={report['runtime_candidate_sha']} "
            f"projection={report['truth_projection_sha']} "
            f"receipt={report['receipt_sha']} "
            f"source_paths={report['runtime_to_projection_changed_path_count']} "
            f"receipt_paths={report['projection_to_receipt_changed_path_count']} "
            f"ready={str(report['market_ready_projection_required']).lower()}"
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except VerificationError as exc:
        print(f"[source-truth-projection] {exc}", file=sys.stderr)
        raise SystemExit(1)
