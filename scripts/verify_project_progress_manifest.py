from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

MANIFEST_PATH = Path("docs/project-progress.manifest.json")
DELTA_LEDGER_PATH = Path("docs/runtime-state/project-progress-delta-ledger.json")
DELTA_LEDGER_SCHEMA_PATH = Path("docs/runtime-contracts/project-progress-delta-ledger.schema.json")
ENDPOINT_SNAPSHOT_PATH = Path("apps/frontend/lib/endpoint-snapshot.json")
PLATFORM_MIRROR_PATH = Path("apps/frontend/lib/platform.ts")
PHASE5_VERIFIER_PATH = Path("scripts/verify_phase5_credit_itemization.py")
PHASE5_ITEMIZATION_PATH = Path("docs/runtime-state/phase5-credit-itemization.json")
CURRENT_RELEASE_CANDIDATE_PATH = Path("docs/release-artifacts/current-release-candidate.json")

DELTA_LEDGER_CONTRACT = "project-progress-delta-ledger-v2"
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

DELTA_ENTRY_KEYS = {
    "entry_id",
    "scope",
    "cell_id",
    "old_percent",
    "new_percent",
    "overall_percent",
    "previous_projection_sha256",
    "projection_sha256",
    "source_sha",
    "verifier_command",
    "artifact_path",
    "artifact_sha256",
}

# Empty by design. A future scorer is admitted only after its implementation is
# evidence-only, source-commit compatible, read-only, and covered by protocol tests.
# The key is the exact (scope, cell_id); the value pins both the exact ledger audit
# string and argv tuple executed without a shell. No existing project verifier currently
# satisfies that contract.
APPROVED_DELTA_SCORERS: dict[tuple[str, str], tuple[str, tuple[str, ...]]] = {}
DELTA_SCORER_TIMEOUT_SECONDS = 30
DELTA_SCORER_MAX_OUTPUT_CHARS = 65_536
DELTA_SCORER_REQUEST_CONTRACT = "project-progress-delta-scorer-request-v1"
DELTA_SCORER_RESULT_CONTRACT = "project-progress-delta-scorer-result-v1"
DELTA_SCORER_BINDING_KEYS = (
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
DELTA_SCORER_RESULT_KEYS = {
    "contract_version",
    *DELTA_SCORER_BINDING_KEYS,
    "read_only",
    "provider_writes",
    "secret_output",
    "evidence_verified",
    "credit_allowed",
}

PLATFORM_MODULE_NAMES = (
    "Frontend",
    "Orchestrator",
    "Agent Pool",
    "LLM Gateway",
    "MCP Gateway",
    "Memory",
    "Observability",
)

CURRENT_RELEASE_CANDIDATE_KEYS = {
    "active_release_id",
    "source_commit_sha",
    "updated_at",
    "updated_by",
    "reason",
    "production_rollout_claimed",
}


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


def resolve_delta_ledger_path(repo_root: Path) -> Path:
    configured = os.environ.get("PROJECT_PROGRESS_DELTA_LEDGER_PATH", "").strip()
    if not configured:
        return (repo_root / DELTA_LEDGER_PATH).resolve()
    require("\x00" not in configured, "progress delta ledger override path is invalid")
    candidate = Path(configured)
    if not candidate.is_absolute():
        candidate = repo_root / candidate
    try:
        resolved = candidate.resolve(strict=False)
    except (OSError, RuntimeError, ValueError) as exc:
        raise SystemExit("[project-progress] progress delta ledger override path is invalid") from exc
    require(resolved.suffix.lower() == ".json", "progress delta ledger override must point to a JSON file")
    return resolved


def require_exact_keys(payload: dict[str, Any], expected: set[str], context: str) -> None:
    actual = set(payload)
    require(actual == expected, f"{context} keys mismatch: expected={sorted(expected)} actual={sorted(actual)}")


def require_percent(value: Any, context: str) -> int:
    require(type(value) is int, f"{context} percent must be an integer")
    require(0 <= value <= 100, f"{context} percent must be between 0 and 100")
    return value


def require_iso_date(value: Any, context: str) -> date:
    require(
        isinstance(value, str) and re.fullmatch(r"\d{4}-\d{2}-\d{2}", value) is not None,
        f"{context} must be an ISO date",
    )
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise SystemExit(f"[project-progress] {context} must be a valid ISO date") from exc


def require_utc_timestamp(value: Any, context: str) -> datetime:
    require(
        isinstance(value, str)
        and re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", value) is not None,
        f"{context} must be a whole-second UTC timestamp",
    )
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise SystemExit(
            f"[project-progress] {context} must be a valid whole-second UTC timestamp"
        ) from exc


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


def expected_delta_entry_schema() -> dict[str, Any]:
    percent_schema = {"type": "integer", "minimum": 0, "maximum": 100}
    return {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "entry_id",
            "scope",
            "cell_id",
            "old_percent",
            "new_percent",
            "overall_percent",
            "previous_projection_sha256",
            "projection_sha256",
            "source_sha",
            "verifier_command",
            "artifact_path",
            "artifact_sha256",
        ],
        "properties": {
            "entry_id": {
                "type": "string",
                "pattern": r"^[a-z0-9][a-z0-9._-]{0,127}$",
            },
            "scope": {"enum": ["horizontal", "vertical"]},
            "cell_id": {"enum": [item_id for item_id, _label, _percent in CANONICAL_CELLS]},
            "old_percent": percent_schema,
            "new_percent": percent_schema,
            "overall_percent": percent_schema,
            "previous_projection_sha256": {
                "type": "string",
                "pattern": r"^[0-9a-f]{64}$",
            },
            "projection_sha256": {
                "type": "string",
                "pattern": r"^[0-9a-f]{64}$",
            },
            "source_sha": {
                "type": "string",
                "pattern": r"^[0-9a-f]{40}$",
            },
            "verifier_command": {
                "type": "string",
                "minLength": 1,
                "maxLength": 512,
                "pattern": r"^(?!\s)(?!.*\s$)(?!.*[\r\n]).*\S$",
                "description": (
                    "Structural audit field only; authoritative replay accepts and executes "
                    "only a statically approved scorer."
                ),
            },
            "artifact_path": {
                "type": "string",
                "pattern": (
                    r"^(?:\.phase1-artifacts|docs/release-artifacts)/"
                    r"(?!\.{1,2}(?:/|$))(?!.*\/\.{1,2}(?:/|$))"
                    r"(?!.*//)(?!.*\/$)[A-Za-z0-9._/-]+$"
                ),
            },
            "artifact_sha256": {
                "type": "string",
                "pattern": r"^[0-9a-f]{64}$",
            },
        },
    }


def expected_delta_entries_schema() -> dict[str, Any]:
    return {
        "type": "array",
        "uniqueItems": True,
        "items": expected_delta_entry_schema(),
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
    require_iso_date(payload["last_verified"], "last_verified")
    require(isinstance(payload["non_claims"], list) and payload["non_claims"], "non_claims must not be empty")
    require(all(isinstance(item, str) and item.strip() for item in payload["non_claims"]), "non_claims entries must be non-empty strings")
    return phases, layers


def validate_current_candidate_freshness(
    manifest: dict[str, Any],
    current_candidate: dict[str, Any],
    phase5_itemization: dict[str, Any],
    repo_root: Path,
    *,
    today_utc: date | None = None,
) -> None:
    """Bind progress freshness to the exact active, source-bound Phase-5 candidate."""

    require_exact_keys(
        current_candidate,
        CURRENT_RELEASE_CANDIDATE_KEYS,
        "current release candidate",
    )
    release_id = current_candidate["active_release_id"]
    require(
        isinstance(release_id, str)
        and re.fullmatch(r"prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+", release_id)
        is not None,
        "current release candidate active_release_id is invalid",
    )
    source_sha = require_lower_hex(
        current_candidate["source_commit_sha"],
        40,
        "current release candidate source_commit_sha",
    )
    require(
        isinstance(current_candidate["updated_by"], str)
        and current_candidate["updated_by"].strip(),
        "current release candidate updated_by must be non-empty",
    )
    require(
        isinstance(current_candidate["reason"], str)
        and current_candidate["reason"].strip(),
        "current release candidate reason must be non-empty",
    )
    require(
        current_candidate["production_rollout_claimed"] is False,
        "current release candidate may not claim production rollout",
    )

    require(
        phase5_itemization.get("contract_version") == "phase5-credit-itemization-v2",
        "Phase-5 itemization contract mismatch",
    )
    require(
        phase5_itemization.get("cell_id") == "phase_5",
        "Phase-5 itemization cell mismatch",
    )
    require(
        phase5_itemization.get("active_release_id") == release_id,
        "current release candidate active_release_id does not match Phase-5 itemization",
    )
    itemization_source_sha = require_lower_hex(
        phase5_itemization.get("active_source_commit_sha"),
        40,
        "Phase-5 itemization active_source_commit_sha",
    )
    require(
        itemization_source_sha == source_sha,
        "current release candidate source_commit_sha does not match Phase-5 itemization",
    )

    candidate_updated_at = require_utc_timestamp(
        current_candidate["updated_at"],
        "current release candidate updated_at",
    )
    itemization_updated_at = require_utc_timestamp(
        phase5_itemization.get("updated_at_utc"),
        "Phase-5 itemization updated_at_utc",
    )
    require(
        candidate_updated_at == itemization_updated_at,
        "current release candidate updated_at does not match Phase-5 itemization",
    )

    require(
        git_object_is_commit(repo_root, source_sha),
        "current release candidate source commit is unavailable",
    )
    require(
        git_commit_is_ancestor(repo_root, source_sha, "HEAD"),
        "current release candidate source commit is not an ancestor of HEAD",
    )

    manifest_last_verified = require_iso_date(manifest.get("last_verified"), "last_verified")
    require(
        manifest_last_verified >= candidate_updated_at.date(),
        "last_verified predates the active release candidate",
    )
    effective_today = today_utc if today_utc is not None else datetime.now(timezone.utc).date()
    require(
        manifest_last_verified <= effective_today,
        "last_verified may not be future-dated",
    )


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


def git_object_type_at_commit(repo_root: Path, source_sha: str, path: str) -> str | None:
    result = run_git(repo_root, "cat-file", "-t", f"{source_sha}:{path}")
    if result.returncode != 0 or not isinstance(result.stdout, str):
        return None
    object_type = result.stdout.strip()
    return object_type or None


def git_object_mode_at_commit(repo_root: Path, source_sha: str, path: str) -> str | None:
    result = run_git(repo_root, "ls-tree", source_sha, "--", path)
    if result.returncode != 0 or not isinstance(result.stdout, str):
        return None
    lines = [line for line in result.stdout.splitlines() if line]
    if len(lines) != 1:
        return None
    match = re.fullmatch(r"(?P<mode>[0-9]{6})\s+\S+\s+[0-9a-f]{40}\t.+", lines[0])
    return match.group("mode") if match is not None else None


def git_file_at_commit(repo_root: Path, source_sha: str, path: str) -> bytes | None:
    if (
        git_object_type_at_commit(repo_root, source_sha, path) != "blob"
        or git_object_mode_at_commit(repo_root, source_sha, path) not in {"100644", "100755"}
    ):
        return None
    result = run_git(repo_root, "cat-file", "-p", f"{source_sha}:{path}", binary=True)
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
    require_exact_keys(
        schema,
        {"$schema", "$id", "title", "type", "additionalProperties", "required", "properties"},
        "progress delta ledger schema",
    )
    require(schema["$schema"] == "https://json-schema.org/draft/2020-12/schema", "progress delta ledger JSON Schema draft mismatch")
    require(
        schema["$id"] == "https://cloud-superbrain.local/schemas/project-progress-delta-ledger-v2.json",
        "progress delta ledger schema id mismatch",
    )
    require(schema["type"] == "object", "progress delta ledger schema root type mismatch")
    require(schema["additionalProperties"] is False, "progress delta ledger schema must reject extra root fields")
    require(
        schema["required"] == ["$schema", "contract_version", "baseline", "entries"],
        "progress delta ledger schema required fields mismatch",
    )
    properties = schema.get("properties")
    require(isinstance(properties, dict), "progress delta ledger schema properties must be an object")
    require_exact_keys(
        properties,
        {"$schema", "contract_version", "baseline", "entries"},
        "progress delta ledger schema properties",
    )
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
        properties.get("entries") == expected_delta_entries_schema(),
        "progress delta ledger schema entry contract mismatch",
    )


def require_lower_hex(value: Any, length: int, context: str) -> str:
    require(
        isinstance(value, str) and re.fullmatch(rf"[0-9a-f]{{{length}}}", value) is not None,
        f"{context} must be a lowercase {length}-character {'Git SHA' if length == 40 else 'SHA-256'}",
    )
    return value


def validate_artifact_path(value: Any, context: str) -> str:
    require(isinstance(value, str) and value, f"{context} must be a non-empty string")
    require("\\" not in value, f"{context} must use repository-relative POSIX separators")
    path = PurePosixPath(value)
    require(
        not path.is_absolute()
        and path.as_posix() == value
        and "." not in path.parts
        and ".." not in path.parts,
        f"{context} must be a normalized repository-relative path",
    )
    require(
        path.parts
        and path.parts[0] in {".phase1-artifacts", "docs"}
        and (path.parts[0] != "docs" or len(path.parts) > 1 and path.parts[1] == "release-artifacts"),
        f"{context} must be inside .phase1-artifacts or docs/release-artifacts",
    )
    require(
        re.fullmatch(
            r"(?:\.phase1-artifacts|docs/release-artifacts)/"
            r"(?!\.{1,2}(?:/|$))(?!.*\/\.{1,2}(?:/|$))[A-Za-z0-9._/-]+",
            value,
        )
        is not None,
        f"{context} contains unsupported characters",
    )
    return value


def build_delta_scorer_request(entry: dict[str, Any]) -> dict[str, Any]:
    return {
        "contract_version": DELTA_SCORER_REQUEST_CONTRACT,
        **{key: entry[key] for key in DELTA_SCORER_BINDING_KEYS},
        "read_only_required": True,
        "provider_writes_allowed": False,
        "secret_output_allowed": False,
    }


def delta_scorer_environment() -> dict[str, str]:
    environment = {
        "PYTHONIOENCODING": "utf-8",
        "PYTHONUTF8": "1",
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    for key in ("PATH", "SystemRoot", "SYSTEMROOT", "TEMP", "TMP"):
        value = os.environ.get(key)
        if value:
            environment[key] = value
    return environment


def execute_approved_delta_scorer(
    entry: dict[str, Any],
    repo_root: Path,
    context: str,
) -> None:
    # Approved scorers must read evidence from source_sha:artifact_path (Git object
    # bytes), never by following the current working-tree path. The replay verifies
    # those committed bytes before invoking any scorer.
    scorer_key = (entry["scope"], entry["cell_id"])
    scorer_spec = APPROVED_DELTA_SCORERS.get(scorer_key)
    require(scorer_spec is not None, f"{context} cell has no statically approved evidence scorer")
    require(
        isinstance(scorer_spec, tuple)
        and len(scorer_spec) == 2
        and isinstance(scorer_spec[0], str)
        and isinstance(scorer_spec[1], tuple),
        f"{context} approved evidence scorer specification is invalid",
    )
    approved_command, approved_argv = scorer_spec
    require(
        entry["verifier_command"] == approved_command,
        f"{context} verifier_command is not the statically approved scorer for {scorer_key[0]}/{scorer_key[1]}",
    )
    require(
        approved_argv
        and all(isinstance(argument, str) and argument for argument in approved_argv),
        f"{context} approved evidence scorer argv is invalid",
    )

    request = build_delta_scorer_request(entry)
    request_json = json.dumps(
        request,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ) + "\n"
    try:
        result = subprocess.run(
            list(approved_argv),
            cwd=repo_root,
            input=request_json,
            capture_output=True,
            text=True,
            check=False,
            timeout=DELTA_SCORER_TIMEOUT_SECONDS,
            env=delta_scorer_environment(),
            shell=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise SystemExit(f"[project-progress] {context} approved evidence scorer timed out") from exc
    except OSError as exc:
        raise SystemExit(f"[project-progress] {context} approved evidence scorer is unavailable") from exc

    stdout = result.stdout if isinstance(result.stdout, str) else ""
    stderr = result.stderr if isinstance(result.stderr, str) else ""
    require(
        len(stdout) <= DELTA_SCORER_MAX_OUTPUT_CHARS
        and len(stderr) <= DELTA_SCORER_MAX_OUTPUT_CHARS,
        f"{context} approved evidence scorer output exceeded the bounded limit",
    )
    require(result.returncode == 0, f"{context} approved evidence scorer failed")
    require(stdout.strip() != "", f"{context} approved evidence scorer output is malformed")
    try:
        scorer_result = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"[project-progress] {context} approved evidence scorer output is malformed"
        ) from exc
    require(isinstance(scorer_result, dict), f"{context} approved evidence scorer output is malformed")
    require_exact_keys(scorer_result, DELTA_SCORER_RESULT_KEYS, f"{context} scorer result")
    require(
        scorer_result["contract_version"] == DELTA_SCORER_RESULT_CONTRACT,
        f"{context} scorer result contract mismatch",
    )
    for key in DELTA_SCORER_BINDING_KEYS:
        require(
            type(scorer_result[key]) is type(request[key])
            and scorer_result[key] == request[key],
            f"{context} scorer result binding mismatch for {key}",
        )
    require(scorer_result["read_only"] is True, f"{context} scorer must report read_only=true")
    require(
        scorer_result["provider_writes"] is False,
        f"{context} scorer must report provider_writes=false",
    )
    require(
        scorer_result["secret_output"] is False,
        f"{context} scorer must report secret_output=false",
    )
    require(
        scorer_result["evidence_verified"] is True,
        f"{context} approved evidence scorer did not verify evidence",
    )
    require(
        scorer_result["credit_allowed"] is True,
        f"{context} approved evidence scorer did not allow credit",
    )


def replay_delta_ledger_entries(
    entries: Any,
    pinned_projection: dict[str, Any],
    repo_root: Path,
) -> dict[str, Any]:
    require(isinstance(entries, list), "progress delta ledger entries must be an array")
    replayed = {
        "overall_percent": pinned_projection["overall_percent"],
        "horizontal": [dict(item) for item in pinned_projection["horizontal"]],
        "vertical": [dict(item) for item in pinned_projection["vertical"]],
    }
    seen_entry_ids: set[str] = set()
    seen_cell_artifact_hashes: set[tuple[str, str, str]] = set()
    last_source_by_cell: dict[tuple[str, str], str] = {}
    previous_source_sha = BASELINE_SOURCE_SHA

    for index, entry in enumerate(entries):
        context = f"progress delta ledger entry[{index}]"
        require(isinstance(entry, dict), f"{context} must be an object")
        require_exact_keys(entry, DELTA_ENTRY_KEYS, context)

        entry_id = entry["entry_id"]
        require(
            isinstance(entry_id, str)
            and re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,127}", entry_id) is not None,
            f"{context} entry_id is invalid",
        )
        require(entry_id not in seen_entry_ids, f"{context} entry_id is duplicated")
        seen_entry_ids.add(entry_id)

        scope = entry["scope"]
        require(
            isinstance(scope, str) and scope in {"horizontal", "vertical"},
            f"{context} scope must be horizontal or vertical",
        )
        cells = replayed[scope]
        cell_id = entry["cell_id"]
        require(isinstance(cell_id, str), f"{context} cell_id must be a string")
        matching_cells = [cell for cell in cells if cell["id"] == cell_id]
        require(len(matching_cells) == 1, f"{context} cell_id does not belong to scope {scope}")
        cell = matching_cells[0]

        old_percent = require_percent(entry["old_percent"], f"{context} old_percent")
        new_percent = require_percent(entry["new_percent"], f"{context} new_percent")
        require(cell["percent"] == old_percent, f"{context} old_percent does not match replay state")
        require(new_percent > old_percent, f"{context} new_percent must increase the replay state")

        previous_projection_sha256 = require_lower_hex(
            entry["previous_projection_sha256"],
            64,
            f"{context} previous_projection_sha256",
        )
        require(
            previous_projection_sha256 == canonical_json_sha256(replayed),
            f"{context} previous_projection_sha256 does not match replay state",
        )

        source_sha = require_lower_hex(entry["source_sha"], 40, f"{context} source_sha")
        require(
            source_sha != BASELINE_SOURCE_SHA,
            f"{context} source_sha must advance beyond the pinned baseline",
        )
        require(
            git_object_is_commit(repo_root, source_sha),
            f"{context} source commit is unavailable: {source_sha}",
        )
        require(
            git_commit_is_ancestor(repo_root, previous_source_sha, source_sha)
            and git_commit_is_ancestor(repo_root, source_sha, "HEAD"),
            f"{context} source ancestry chain mismatch",
        )

        verifier_command = entry["verifier_command"]
        require(
            isinstance(verifier_command, str)
            and verifier_command.strip() == verifier_command
            and verifier_command
            and "\n" not in verifier_command
            and "\r" not in verifier_command
            and len(verifier_command) <= 512,
            f"{context} verifier_command must be one bounded non-empty line",
        )
        artifact_path = validate_artifact_path(entry["artifact_path"], f"{context} artifact_path")
        artifact_sha256 = require_lower_hex(
            entry["artifact_sha256"],
            64,
            f"{context} artifact_sha256",
        )
        artifact_object_type = git_object_type_at_commit(repo_root, source_sha, artifact_path)
        artifact_object_mode = git_object_mode_at_commit(repo_root, source_sha, artifact_path)
        require(
            artifact_object_type is not None,
            f"{context} evidence artifact is unavailable at source commit",
        )
        require(
            artifact_object_type == "blob",
            f"{context} evidence artifact must be a Git blob",
        )
        require(
            artifact_object_mode in {"100644", "100755"},
            f"{context} evidence artifact must be a regular Git file",
        )
        committed_artifact = git_file_at_commit(repo_root, source_sha, artifact_path)
        require(
            committed_artifact is not None,
            f"{context} evidence artifact is unavailable at source commit",
        )
        require(
            hashlib.sha256(committed_artifact).hexdigest() == artifact_sha256,
            f"{context} evidence artifact hash mismatch",
        )

        cell_key = (scope, cell_id)
        proof_key = (scope, cell_id, artifact_sha256)
        require(
            proof_key not in seen_cell_artifact_hashes,
            f"{context} reuses an identical evidence artifact for the same cell",
        )
        prior_cell_source = last_source_by_cell.get(cell_key)
        if prior_cell_source is not None:
            require(
                source_sha != prior_cell_source,
                f"{context} source_sha must advance strictly for a repeated cell",
            )
            require(
                git_commit_is_ancestor(repo_root, prior_cell_source, source_sha),
                f"{context} repeated-cell source ancestry direction mismatch",
            )

        cell["percent"] = new_percent
        replayed["overall_percent"] = round(
            sum(item["percent"] for item in replayed["horizontal"])
            / len(replayed["horizontal"])
        )
        overall_percent = require_percent(entry["overall_percent"], f"{context} overall_percent")
        require(
            overall_percent == replayed["overall_percent"],
            f"{context} overall_percent does not match replay state",
        )
        projection_sha256 = require_lower_hex(
            entry["projection_sha256"],
            64,
            f"{context} projection_sha256",
        )
        require(
            projection_sha256 == canonical_json_sha256(replayed),
            f"{context} projection_sha256 does not match replay state",
        )
        execute_approved_delta_scorer(entry, repo_root, context)
        seen_cell_artifact_hashes.add(proof_key)
        last_source_by_cell[cell_key] = source_sha
        previous_source_sha = source_sha

    return replayed


def validate_delta_ledger(
    ledger: dict[str, Any],
    manifest: dict[str, Any],
    pinned_projection: dict[str, Any],
    repo_root: Path,
) -> None:
    require_exact_keys(ledger, {"$schema", "contract_version", "baseline", "entries"}, "progress delta ledger")
    require(ledger["$schema"] == DELTA_LEDGER_SCHEMA, "progress delta ledger schema path mismatch")
    require(ledger["contract_version"] == DELTA_LEDGER_CONTRACT, "progress delta ledger contract mismatch")
    require(ledger["baseline"] == expected_baseline_payload(), "progress delta baseline lock mismatch")
    require(
        canonical_json_sha256(expected_baseline_projection()) == BASELINE_PROJECTION_SHA256,
        "internal progress baseline projection hash mismatch",
    )
    replayed_projection = replay_delta_ledger_entries(ledger["entries"], pinned_projection, repo_root)
    require(
        progress_projection(manifest) == replayed_projection,
        "progress projection differs from the replayed v2 delta ledger",
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
    validate_delta_ledger(ledger, manifest, pinned_projection, repo_root)
    validate_endpoint_snapshot_mirror(manifest, endpoint_snapshot)
    validate_platform_mirror(manifest, platform_source)


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    manifest = load_json(repo_root / MANIFEST_PATH)
    ledger = load_json(resolve_delta_ledger_path(repo_root))
    ledger_schema = load_json(repo_root / DELTA_LEDGER_SCHEMA_PATH)
    endpoint_snapshot = load_json(repo_root / ENDPOINT_SNAPSHOT_PATH)
    current_candidate = load_json(repo_root / CURRENT_RELEASE_CANDIDATE_PATH)
    phase5_itemization = load_json(repo_root / PHASE5_ITEMIZATION_PATH)
    platform_source = (repo_root / PLATFORM_MIRROR_PATH).read_text(encoding="utf-8")
    validate_progress_truth(manifest, ledger, ledger_schema, endpoint_snapshot, platform_source, repo_root)
    validate_current_candidate_freshness(
        manifest,
        current_candidate,
        phase5_itemization,
        repo_root,
    )

    phase5_verifier = repo_root / PHASE5_VERIFIER_PATH
    require(phase5_verifier.is_file(), f"missing {PHASE5_VERIFIER_PATH.as_posix()}")
    phase5_result = subprocess.run([sys.executable, str(phase5_verifier)], cwd=repo_root, check=False)
    require(phase5_result.returncode == 0, "Phase-5 credit itemization is invalid")
    print(
        "[project-progress] manifest valid: "
        f"overall={manifest['overall_percent']}% deltas={len(ledger['entries'])} "
        "mirrors=2 candidate_source_bound=true freshness=verified"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
