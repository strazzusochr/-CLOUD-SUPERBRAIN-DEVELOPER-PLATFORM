from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

MANIFEST_PATH = Path("docs/project-progress.manifest.json")
DELTA_LEDGER_PATH = Path("docs/runtime-state/project-progress-delta-ledger.json")
DELTA_LEDGER_SCHEMA_PATH = Path("docs/runtime-contracts/project-progress-delta-ledger.schema.json")
ENDPOINT_SNAPSHOT_PATH = Path("apps/frontend/lib/endpoint-snapshot.json")
PLATFORM_MIRROR_PATH = Path("apps/frontend/lib/platform.ts")
PHASE5_VERIFIER_PATH = Path("scripts/verify_phase5_credit_itemization.py")

DELTA_LEDGER_CONTRACT = "project-progress-delta-ledger-v1"
DELTA_LEDGER_SCHEMA = "../runtime-contracts/project-progress-delta-ledger.schema.json"
BASELINE_SOURCE_SHA = "9a3776fffd226271fcd3d01fdefb0405e5303ce0"
BASELINE_PROJECTION_SHA256 = "de6c3568a200c34daac1755c25a24b51d0c792d0752e2f952e58610f3a3dee7a"
BASELINE_OVERALL_PERCENT = 89

CANONICAL_HORIZONTAL: tuple[tuple[str, str, int], ...] = (
    ("phase_0", "Phase 0 - Reboot & Goal Lock", 100),
    ("phase_1", "Phase 1 - Foundation Runtime", 100),
    ("phase_2", "Phase 2 - Core Runtime", 100),
    ("phase_3", "Phase 3 - Product Surface & Security", 44),
    ("phase_4", "Phase 4 - Integration & Hardening", 100),
    ("phase_5", "Phase 5 - Release Readiness", 89),
    ("phase_6", "Phase 6 - Scale & 3D Platform", 90),
)
CANONICAL_VERTICAL: tuple[tuple[str, str, int], ...] = (
    ("layer_1", "Frontend / Next.js", 100),
    ("layer_2", "Orchestrator / LangGraph", 100),
    ("layer_3", "Agent Pool", 100),
    ("layer_4", "LLM Gateway", 55),
    ("layer_5", "MCP Gateway", 56),
    ("layer_6", "Memory", 100),
    ("layer_7", "Observability", 100),
)
CANONICAL_CELLS = CANONICAL_HORIZONTAL + CANONICAL_VERTICAL

PLATFORM_MODULE_NAMES = (
    "Frontend",
    "Orchestrator",
    "Agent Pool",
    "LLM Gateway",
    "MCP Gateway",
    "Memory",
    "Observability",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[project-progress] {message}")


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"missing {path.as_posix()}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[project-progress] invalid JSON in {path.as_posix()}: {exc}") from exc
    require(isinstance(payload, dict), f"{path.as_posix()} root must be an object")
    return payload


def require_exact_keys(payload: dict[str, Any], expected: set[str], context: str) -> None:
    actual = set(payload)
    require(actual == expected, f"{context} keys mismatch: expected={sorted(expected)} actual={sorted(actual)}")


def require_percent(value: Any, context: str) -> int:
    require(type(value) is int, f"{context} percent must be an integer")
    require(0 <= value <= 100, f"{context} percent must be between 0 and 100")
    return value


def expected_baseline_projection() -> dict[str, Any]:
    return {
        "overall_percent": BASELINE_OVERALL_PERCENT,
        "horizontal": [
            {"id": item_id, "label": label, "percent": percent}
            for item_id, label, percent in CANONICAL_HORIZONTAL
        ],
        "vertical": [
            {"id": item_id, "label": label, "percent": percent}
            for item_id, label, percent in CANONICAL_VERTICAL
        ],
    }


def expected_baseline_payload() -> dict[str, Any]:
    def cells(scope: str, definitions: tuple[tuple[str, str, int], ...]) -> list[dict[str, Any]]:
        return [
            {"scope": scope, "id": item_id, "label": label, "percent": percent}
            for item_id, label, percent in definitions
        ]

    return {
        "source_sha": BASELINE_SOURCE_SHA,
        "projection_sha256": BASELINE_PROJECTION_SHA256,
        "overall_percent": BASELINE_OVERALL_PERCENT,
        "cells": cells("horizontal", CANONICAL_HORIZONTAL) + cells("vertical", CANONICAL_VERTICAL),
    }


def validate_items(
    raw_items: Any,
    definitions: tuple[tuple[str, str, int], ...],
    scope: str,
) -> list[dict[str, Any]]:
    require(isinstance(raw_items, list), f"{scope} items must be an array")
    require(len(raw_items) == len(definitions), f"{scope} must contain exactly {len(definitions)} items")
    for index, (item, (expected_id, expected_label, _)) in enumerate(zip(raw_items, definitions, strict=True)):
        require(isinstance(item, dict), f"{scope}[{index}] must be an object")
        require_exact_keys(item, {"id", "label", "percent", "status"}, f"{scope}[{index}]")
        require(item["id"] == expected_id, f"{scope}[{index}] id/order mismatch: expected {expected_id}")
        require(item["label"] == expected_label, f"{expected_id} canonical label mismatch")
        require_percent(item["percent"], expected_id)
        require(isinstance(item["status"], str) and item["status"].strip(), f"{expected_id} missing status")
    return raw_items


def validate_manifest_shape(payload: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    require_exact_keys(
        payload,
        {
            "overall_percent",
            "progress_source",
            "horizontal",
            "vertical",
            "truth_policy",
            "binding_document",
            "last_verified",
            "non_claims",
        },
        "progress manifest",
    )
    require(isinstance(payload["horizontal"], dict), "horizontal must be an object")
    require(isinstance(payload["vertical"], dict), "vertical must be an object")
    require_exact_keys(payload["horizontal"], {"label", "items"}, "horizontal")
    require_exact_keys(payload["vertical"], {"label", "items"}, "vertical")
    require(payload["horizontal"]["label"] == "Phase progress", "horizontal label mismatch")
    require(payload["vertical"]["label"] == "Architecture-layer progress", "vertical label mismatch")

    phases = validate_items(payload["horizontal"]["items"], CANONICAL_HORIZONTAL, "horizontal")
    layers = validate_items(payload["vertical"]["items"], CANONICAL_VERTICAL, "vertical")
    expected_overall = round(sum(item["percent"] for item in phases) / len(phases))
    require_percent(payload["overall_percent"], "overall")
    require(payload["overall_percent"] == expected_overall, "overall_percent must equal rounded phase average")
    require(payload["progress_source"] == MANIFEST_PATH.as_posix(), "progress_source must point to manifest")
    require(
        payload["binding_document"] == "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md",
        "binding document mismatch",
    )
    require("Evidence-based only" in str(payload["truth_policy"]), "truth policy must be explicit")
    require(
        isinstance(payload["last_verified"], str)
        and re.fullmatch(r"\d{4}-\d{2}-\d{2}", payload["last_verified"]) is not None,
        "last_verified must be an ISO date",
    )
    require(isinstance(payload["non_claims"], list) and payload["non_claims"], "non_claims must not be empty")
    require(all(isinstance(item, str) and item.strip() for item in payload["non_claims"]), "non_claims entries must be non-empty strings")
    return phases, layers


def progress_projection(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "overall_percent": payload["overall_percent"],
        "horizontal": [
            {"id": item["id"], "label": item["label"], "percent": item["percent"]}
            for item in payload["horizontal"]["items"]
        ],
        "vertical": [
            {"id": item["id"], "label": item["label"], "percent": item["percent"]}
            for item in payload["vertical"]["items"]
        ],
    }


def canonical_json_sha256(payload: Any) -> str:
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def run_git(repo_root: Path, *args: str, binary: bool = False) -> subprocess.CompletedProcess[Any]:
    return subprocess.run(
        ["git", *args],
        cwd=repo_root,
        capture_output=True,
        text=not binary,
        check=False,
    )


def git_object_is_commit(repo_root: Path, source_sha: str) -> bool:
    return run_git(repo_root, "cat-file", "-e", f"{source_sha}^{{commit}}").returncode == 0


def git_commit_is_ancestor(repo_root: Path, ancestor: str, descendant: str) -> bool:
    return run_git(repo_root, "merge-base", "--is-ancestor", ancestor, descendant).returncode == 0


def git_file_at_commit(repo_root: Path, source_sha: str, path: str) -> bytes | None:
    result = run_git(repo_root, "show", f"{source_sha}:{path}", binary=True)
    return result.stdout if result.returncode == 0 else None


def load_pinned_baseline_projection(repo_root: Path) -> dict[str, Any]:
    require(
        git_object_is_commit(repo_root, BASELINE_SOURCE_SHA),
        f"pinned baseline source commit is unavailable: {BASELINE_SOURCE_SHA}",
    )
    require(
        git_commit_is_ancestor(repo_root, BASELINE_SOURCE_SHA, "HEAD"),
        f"pinned baseline source commit is not an ancestor of HEAD: {BASELINE_SOURCE_SHA}",
    )
    committed_bytes = git_file_at_commit(repo_root, BASELINE_SOURCE_SHA, MANIFEST_PATH.as_posix())
    require(committed_bytes is not None, "pinned baseline commit does not contain the progress manifest")
    try:
        pinned_manifest = json.loads(committed_bytes.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"[project-progress] pinned baseline manifest is invalid UTF-8 JSON: {exc}") from exc
    require(isinstance(pinned_manifest, dict), "pinned baseline progress manifest root must be an object")
    validate_manifest_shape(pinned_manifest)

    projection = progress_projection(pinned_manifest)
    require(
        canonical_json_sha256(projection) == BASELINE_PROJECTION_SHA256,
        "pinned baseline projection hash mismatch",
    )
    require(
        projection == expected_baseline_projection(),
        "pinned baseline projection differs from the canonical baseline lock",
    )
    return projection


def validate_delta_ledger_schema(schema: dict[str, Any]) -> None:
    properties = schema.get("properties")
    require(isinstance(properties, dict), "progress delta ledger schema properties must be an object")
    require(
        properties.get("$schema") == {"const": DELTA_LEDGER_SCHEMA},
        "progress delta ledger schema path contract mismatch",
    )
    require(
        properties.get("contract_version") == {"const": DELTA_LEDGER_CONTRACT},
        "progress delta ledger schema version contract mismatch",
    )
    require(
        properties.get("baseline") == {"const": expected_baseline_payload()},
        "progress delta ledger schema baseline lock mismatch",
    )
    require(
        properties.get("entries") == {"const": []},
        "progress delta ledger schema must lock v1 entries to exactly empty",
    )


def validate_delta_ledger(
    ledger: dict[str, Any],
    manifest: dict[str, Any],
    pinned_projection: dict[str, Any],
) -> None:
    require_exact_keys(ledger, {"$schema", "contract_version", "baseline", "entries"}, "progress delta ledger")
    require(ledger["$schema"] == DELTA_LEDGER_SCHEMA, "progress delta ledger schema path mismatch")
    require(ledger["contract_version"] == DELTA_LEDGER_CONTRACT, "progress delta ledger contract mismatch")
    require(ledger["baseline"] == expected_baseline_payload(), "progress delta baseline lock mismatch")
    require(
        canonical_json_sha256(expected_baseline_projection()) == BASELINE_PROJECTION_SHA256,
        "internal progress baseline projection hash mismatch",
    )
    require(ledger["entries"] == [], "v1 progress delta ledger entries must remain exactly empty")
    require(
        progress_projection(manifest) == pinned_projection,
        "progress projection differs from the pinned v1 baseline; trusted delta evidence requires a new contract",
    )


def validate_endpoint_snapshot_mirror(manifest: dict[str, Any], snapshot: dict[str, Any]) -> None:
    mirror = snapshot.get("/api/v1/project/progress")
    require(isinstance(mirror, dict), "endpoint snapshot missing /api/v1/project/progress mirror")
    require(mirror == manifest, "endpoint snapshot project-progress mirror differs from canonical manifest")


def parse_platform_mirror(source: str) -> dict[str, Any]:
    block_match = re.search(r"export const MANIFEST\s*=\s*\{(?P<body>.*?)\}\s*as const;", source, re.DOTALL)
    require(block_match is not None, "platform.ts missing MANIFEST mirror")
    body = block_match.group("body")
    snapshot_match = re.search(r'\bsnapshot:\s*"([^"]+)"', body)
    overall_match = re.search(r"\boverall:\s*(\d+)", body)
    integrity_match = re.search(r'\bintegrity:\s*"([^"]+)"', body)
    modules_match = re.search(r"\bmodules:\s*\[(.*?)\]\s*,\s*phases:", body, re.DOTALL)
    phases_match = re.search(r"\bphases:\s*\[(.*?)\]\s*,?\s*$", body, re.DOTALL)
    require(all(match is not None for match in (snapshot_match, overall_match, integrity_match, modules_match, phases_match)), "platform.ts MANIFEST mirror shape is invalid")
    assert snapshot_match and overall_match and integrity_match and modules_match and phases_match
    modules = [
        {"name": name, "layer": int(layer), "pct": int(percent)}
        for name, layer, percent in re.findall(
            r'\{\s*name:\s*"([^"]+)",\s*layer:\s*(\d+),\s*pct:\s*(\d+)\s*\}',
            modules_match.group(1),
        )
    ]
    phases = [
        {"id": phase_id, "pct": int(percent)}
        for phase_id, percent in re.findall(
            r'\{\s*id:\s*"([^"]+)",\s*pct:\s*(\d+)\s*\}',
            phases_match.group(1),
        )
    ]
    return {
        "snapshot": snapshot_match.group(1),
        "overall": int(overall_match.group(1)),
        "integrity": integrity_match.group(1),
        "modules": modules,
        "phases": phases,
    }


def validate_platform_mirror(manifest: dict[str, Any], platform_source: str) -> None:
    mirror = parse_platform_mirror(platform_source)
    expected_modules = [
        {"name": PLATFORM_MODULE_NAMES[index], "layer": index + 1, "pct": item["percent"]}
        for index, item in enumerate(manifest["vertical"]["items"])
    ]
    expected_phases = [
        {"id": f"P{index}", "pct": item["percent"]}
        for index, item in enumerate(manifest["horizontal"]["items"])
    ]
    require(mirror["snapshot"] == manifest["last_verified"], "platform.ts MANIFEST snapshot date mismatch")
    require(mirror["overall"] == manifest["overall_percent"], "platform.ts MANIFEST overall mirror mismatch")
    require(mirror["integrity"] == "verified", "platform.ts MANIFEST integrity must remain verified")
    require(mirror["modules"] == expected_modules, "platform.ts MANIFEST vertical mirror differs from canonical manifest")
    require(mirror["phases"] == expected_phases, "platform.ts MANIFEST horizontal mirror differs from canonical manifest")


def validate_progress_truth(
    manifest: dict[str, Any],
    ledger: dict[str, Any],
    ledger_schema: dict[str, Any],
    endpoint_snapshot: dict[str, Any],
    platform_source: str,
    repo_root: Path,
) -> None:
    validate_manifest_shape(manifest)
    pinned_projection = load_pinned_baseline_projection(repo_root)
    validate_delta_ledger_schema(ledger_schema)
    validate_delta_ledger(ledger, manifest, pinned_projection)
    validate_endpoint_snapshot_mirror(manifest, endpoint_snapshot)
    validate_platform_mirror(manifest, platform_source)


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    manifest = load_json(repo_root / MANIFEST_PATH)
    ledger = load_json(repo_root / DELTA_LEDGER_PATH)
    ledger_schema = load_json(repo_root / DELTA_LEDGER_SCHEMA_PATH)
    endpoint_snapshot = load_json(repo_root / ENDPOINT_SNAPSHOT_PATH)
    platform_source = (repo_root / PLATFORM_MIRROR_PATH).read_text(encoding="utf-8")
    validate_progress_truth(manifest, ledger, ledger_schema, endpoint_snapshot, platform_source, repo_root)

    phase5_verifier = repo_root / PHASE5_VERIFIER_PATH
    require(phase5_verifier.is_file(), f"missing {PHASE5_VERIFIER_PATH.as_posix()}")
    phase5_result = subprocess.run([sys.executable, str(phase5_verifier)], cwd=repo_root, check=False)
    require(phase5_result.returncode == 0, "Phase-5 credit itemization is invalid")
    print(
        "[project-progress] manifest valid: "
        f"overall={manifest['overall_percent']}% deltas={len(ledger['entries'])} mirrors=2"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
