#!/usr/bin/env python3
"""Validate a complete, immutable Layer-5 registry-release evidence envelope."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

from build_layer5_registry_release_input import (
    CONTRACT_VERSION,
    VerificationError,
    build_layer5_registry_release_input,
)


SHA40_RE = re.compile(r"[0-9a-f]{40}")


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def _read(path: Path) -> dict[str, Any]:
    _require(path.is_file(), f"Layer-5 registry evidence is missing: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise VerificationError("Layer-5 registry evidence is not valid UTF-8 JSON") from exc
    _require(isinstance(value, dict), "Layer-5 registry evidence must be an object")
    return value


def _artifact_path(root: Path, artifact: Mapping[str, Any], label: str) -> Path:
    relative = artifact.get("path")
    _require(isinstance(relative, str) and relative and "\\" not in relative, f"{label} artifact path is invalid")
    candidate = Path(relative)
    _require(not candidate.is_absolute() and ".." not in candidate.parts, f"{label} artifact path escapes evidence root")
    resolved_root = root.resolve()
    resolved = (root / candidate).resolve()
    _require(resolved_root in resolved.parents, f"{label} artifact path escapes evidence root")
    return resolved


def validate_layer5_registry_release_evidence(
    evidence_path: Path,
    *,
    expected_release_id: str,
    expected_source_sha: str,
    expected_control_sha: str,
) -> dict[str, Any]:
    evidence_path = Path(evidence_path)
    evidence = _read(evidence_path)
    _require(evidence.get("contract_version") == CONTRACT_VERSION, "Layer-5 registry evidence contract mismatch")
    _require(evidence.get("status") == "verified", "Layer-5 registry evidence is not verified")
    _require(re.fullmatch(r"prod-candidate-[A-Za-z0-9._-]+", expected_release_id) is not None, "expected release id is invalid")
    _require(SHA40_RE.fullmatch(expected_source_sha) is not None, "expected source SHA is invalid")
    _require(SHA40_RE.fullmatch(expected_control_sha) is not None, "expected control SHA is invalid")
    _require(evidence.get("release_id") == expected_release_id, "Layer-5 registry evidence release mismatch")
    _require(evidence.get("source_commit_sha") == expected_source_sha, "Layer-5 registry evidence source mismatch")
    _require(evidence.get("control_commit_sha") == expected_control_sha, "Layer-5 registry evidence control mismatch")
    artifacts = evidence.get("artifacts")
    _require(isinstance(artifacts, dict), "Layer-5 registry evidence artifacts are missing")
    required = (
        "ghcr_manifest",
        "candidate_registry_digests",
        "remote_image_scan",
        "candidate_sbom",
        "registry_publication_review",
    )
    _require(set(artifacts) == set(required), "Layer-5 registry evidence artifact set mismatch")
    paths = {name: _artifact_path(evidence_path.parent, artifacts[name], name) for name in required}
    rebuilt = build_layer5_registry_release_input(
        paths["ghcr_manifest"],
        paths["candidate_registry_digests"],
        paths["remote_image_scan"],
        paths["candidate_sbom"],
        paths["registry_publication_review"],
    )
    _require(evidence == rebuilt, "Layer-5 registry evidence does not equal its verified artifact projection")
    return evidence


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--expected-release-id", required=True)
    parser.add_argument("--expected-source-sha", required=True)
    parser.add_argument("--expected-control-sha", required=True)
    parser.add_argument("--validate-only", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        _require(args.validate_only, "--validate-only is required; this verifier never mutates evidence")
        validate_layer5_registry_release_evidence(
            args.evidence,
            expected_release_id=args.expected_release_id,
            expected_source_sha=args.expected_source_sha,
            expected_control_sha=args.expected_control_sha,
        )
    except VerificationError as exc:
        print(f"[layer5-registry-release-evidence] ERROR: {exc}", file=sys.stderr)
        return 1
    print("[layer5-registry-release-evidence] PASS credit_eligible=true points=14 transition=86->100")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
