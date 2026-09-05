#!/usr/bin/env python3
"""Build the exact Phase-3 44->100 scorer input after OAuth gate promotion."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

from score_phase3_oauth_credit import (
    AGGREGATE_CONTRACT,
    AUTH_CONTRACT,
    AUTH_VERIFIER_PATH,
    CAPABILITY_CONTRACT,
    CRITERIA,
    FLOW_CONTRACT,
    RAW_VERIFIER_PATH,
    _validate_flow,
)
from score_phase5_market_ready_credit import _validate_auth


class BuildError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise BuildError(message)


def read_json(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    require(path.is_file(), f"{label} is missing")
    try:
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise BuildError(f"{label} is not valid UTF-8 JSON") from exc
    require(isinstance(value, dict), f"{label} must be an object")
    return value, raw


def repo_path(path: Path) -> str:
    root = Path(__file__).resolve().parents[1]
    try:
        return path.resolve().relative_to(root).as_posix()
    except ValueError as exc:
        raise BuildError("Phase-3 evidence input must stay inside the repository") from exc


def ref(path: Path, contract: str, raw: bytes) -> dict[str, str]:
    return {"contract_version": contract, "path": repo_path(path), "sha256": hashlib.sha256(raw).hexdigest()}


def build_input(
    *,
    release_id: str,
    candidate_sha: str,
    flow_path: Path,
    production_auth_path: Path,
    capability_path: Path,
    raw_verifier_path: Path,
) -> dict[str, Any]:
    require(re.fullmatch(r"prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+", release_id) is not None, "release id is invalid")
    require(re.fullmatch(r"[0-9a-f]{40}", candidate_sha) is not None, "candidate SHA is invalid")
    flow, flow_raw = read_json(flow_path, "OAuth flow")
    auth, auth_raw = read_json(production_auth_path, "production auth identity")
    capability, capability_raw = read_json(capability_path, "capability gates")
    require(raw_verifier_path.resolve() == (Path(__file__).resolve().parents[1] / RAW_VERIFIER_PATH).resolve(), "raw verifier path mismatch")
    raw_verifier = raw_verifier_path.read_bytes()
    _validate_flow(flow, candidate_sha)
    _validate_auth(auth, candidate_sha)
    require(capability.get("contract_version") == CAPABILITY_CONTRACT, "capability gate contract mismatch")
    gate = capability.get("gates", {}).get("production_auth_identity", {})
    auth_reference = ref(production_auth_path, AUTH_CONTRACT, auth_raw)
    require(gate.get("owner_granted") is True and gate.get("live_verified") is True, "production auth gate is not promoted")
    require(gate.get("paid_provider") is False and gate.get("verifier") == AUTH_VERIFIER_PATH, "production auth gate verifier mismatch")
    require(str(gate.get("evidence_artifact", "")).replace("\\", "/") == auth_reference["path"], "production auth gate evidence path mismatch")
    require(str(gate.get("evidence_sha256", "")).lower() == auth_reference["sha256"], "production auth gate evidence hash mismatch")
    return {
        "contract_version": AGGREGATE_CONTRACT,
        "status": "verified",
        "scope": "horizontal",
        "cell_id": "phase_3",
        "old_percent": 44,
        "new_percent": 100,
        "points_awarded": 56,
        "credit_eligible": True,
        "release_id": release_id,
        "candidate_source_commit_sha": candidate_sha,
        "criteria": [{"id": criterion_id, "points": points, "status": "verified"} for criterion_id, points in CRITERIA.items()],
        "evidence": {
            "flow": ref(flow_path, FLOW_CONTRACT, flow_raw),
            "production_auth_identity": auth_reference,
            "capability_gates": ref(capability_path, CAPABILITY_CONTRACT, capability_raw),
            "raw_verifier": {"path": RAW_VERIFIER_PATH, "sha256": hashlib.sha256(raw_verifier).hexdigest()},
        },
        "live_github_oauth_calls": 2,
        "provider_writes": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }


def write_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    require(path.parent.is_dir(), "Phase-3 output parent must already exist")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise BuildError("Phase-3 output already exists; immutable evidence is never overwritten") from exc


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--flow", type=Path, required=True)
    parser.add_argument("--production-auth-identity", type=Path, required=True)
    parser.add_argument("--capability-gates", type=Path, required=True)
    parser.add_argument("--raw-verifier", type=Path, default=Path(RAW_VERIFIER_PATH))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        value = build_input(
            release_id=args.release_id,
            candidate_sha=args.candidate_sha,
            flow_path=args.flow,
            production_auth_path=args.production_auth_identity,
            capability_path=args.capability_gates,
            raw_verifier_path=args.raw_verifier,
        )
        write_exclusive(args.output, value)
    except (BuildError, ValueError, OSError) as exc:
        print(f"[phase3-oauth-credit-input] ERROR: {exc}", file=sys.stderr)
        return 1
    print("[phase3-oauth-credit-input] PASS credit_eligible=true points=56 transition=44->100")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
