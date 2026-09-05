#!/usr/bin/env python3
"""Build the exact Phase-5 89->100 I1/I5 scorer input."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

from score_phase5_market_ready_credit import (
    AGGREGATE_CONTRACT,
    AUTH_CONTRACT,
    AUTH_VERIFIER,
    CAPABILITY_CONTRACT,
    I1_CONTRACT,
    _validate_auth,
    _validate_i1,
)


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
        raise BuildError("Phase-5 evidence input must stay inside the repository") from exc


def ref(path: Path, contract: str, raw: bytes) -> dict[str, str]:
    return {"contract_version": contract, "path": repo_path(path), "sha256": hashlib.sha256(raw).hexdigest()}


def build_input(
    *,
    release_id: str,
    candidate_sha: str,
    i1_path: Path,
    auth_path: Path,
    capability_path: Path,
) -> dict[str, Any]:
    require(re.fullmatch(r"prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+", release_id) is not None, "release id is invalid")
    require(re.fullmatch(r"[0-9a-f]{40}", candidate_sha) is not None, "candidate SHA is invalid")
    i1, i1_raw = read_json(i1_path, "I1 candidate parity")
    auth, auth_raw = read_json(auth_path, "production auth identity")
    capability, capability_raw = read_json(capability_path, "capability gates")
    _validate_i1(i1, release_id, candidate_sha)
    _validate_auth(auth, candidate_sha)
    require(capability.get("contract_version") == CAPABILITY_CONTRACT, "capability gate contract mismatch")
    auth_reference = ref(auth_path, AUTH_CONTRACT, auth_raw)
    gate = capability.get("gates", {}).get("production_auth_identity", {})
    require(gate.get("owner_granted") is True and gate.get("live_verified") is True, "production auth gate is not promoted")
    require(gate.get("paid_provider") is False and gate.get("verifier") == AUTH_VERIFIER, "production auth gate verifier mismatch")
    require(str(gate.get("evidence_artifact", "")).replace("\\", "/") == auth_reference["path"], "production auth gate evidence path mismatch")
    require(str(gate.get("evidence_sha256", "")).lower() == auth_reference["sha256"], "production auth gate evidence hash mismatch")
    return {
        "contract_version": AGGREGATE_CONTRACT,
        "status": "verified",
        "scope": "horizontal",
        "cell_id": "phase_5",
        "old_percent": 89,
        "new_percent": 100,
        "percent_delta": 11,
        "credit_eligible": True,
        "release_id": release_id,
        "candidate_source_commit_sha": candidate_sha,
        "verified_item_ids": ["I1", "I5"],
        "evidence": {
            "hosted_candidate_parity": ref(i1_path, I1_CONTRACT, i1_raw),
            "production_auth_identity": auth_reference,
            "capability_gates": ref(capability_path, CAPABILITY_CONTRACT, capability_raw),
        },
        "claims": {
            "hosted_candidate_parity_verified": True,
            "production_auth_identity_verified": True,
            "verified_item_count": 2,
        },
        "live_provider_calls_verified": True,
        "provider_writes": False,
        "registry_write_performed": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }


def write_exclusive(path: Path, value: Mapping[str, Any]) -> None:
    require(path.parent.is_dir(), "Phase-5 output parent must already exist")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(value, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise BuildError("Phase-5 output already exists; immutable evidence is never overwritten") from exc


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--hosted-candidate-parity", type=Path, required=True)
    parser.add_argument("--production-auth-identity", type=Path, required=True)
    parser.add_argument("--capability-gates", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        value = build_input(
            release_id=args.release_id,
            candidate_sha=args.candidate_sha,
            i1_path=args.hosted_candidate_parity,
            auth_path=args.production_auth_identity,
            capability_path=args.capability_gates,
        )
        write_exclusive(args.output, value)
    except (BuildError, ValueError, OSError) as exc:
        print(f"[phase5-market-ready-credit-input] ERROR: {exc}", file=sys.stderr)
        return 1
    print("[phase5-market-ready-credit-input] PASS credit_eligible=true items=I1,I5 transition=89->100")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
