#!/usr/bin/env python3
"""Start the already published I1 candidate inside an existing Codespace.

This launcher never creates a Codespace, builds an image, publishes an image,
or changes port visibility. It accepts only the immutable publication manifest,
materializes its public digest bindings, starts Compose with ``--no-build``, and
collects the runtime provenance consumed by the independent Actions verifier.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Mapping, Sequence

from i1_codespaces_contract import (
    ContractError,
    build_compose_environment,
    require,
    validate_published_manifest,
)


BASE_COMPOSE = Path("infrastructure/i1-codespaces/compose.yml")
STATIC_VERIFIER = Path("scripts/verify_i1_codespaces_static.py")
COLLECTOR = Path("scripts/collect_i1_codespaces_evidence.py")
PROJECT_RE = re.compile(r"[a-z0-9][a-z0-9_-]{2,62}")


def _run(command: Sequence[str]) -> None:
    try:
        completed = subprocess.run(list(command), check=False, timeout=900)
    except (OSError, subprocess.SubprocessError) as exc:
        raise ContractError("I1 local control command could not be executed") from exc
    require(completed.returncode == 0, "I1 local control command failed")


def _write_env_exclusive(path: Path, values: Mapping[str, str]) -> None:
    require(path.parent.is_dir(), "I1 env parent directory must already exist")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    try:
        descriptor = os.open(path, flags, 0o600)
    except FileExistsError as exc:
        raise ContractError("I1 env file already exists; refusing a drift-prone restart") from exc
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            for key, value in sorted(values.items()):
                require("\n" not in value and "\r" not in value, "I1 env value contains a line break")
                handle.write(f"{key}={value}\n")
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry-manifest", type=Path, required=True)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--env-file", type=Path, required=True)
    parser.add_argument("--runtime-evidence", type=Path, required=True)
    parser.add_argument("--project-name", required=True)
    parser.add_argument("--ingress-port", type=int, default=8080)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        require(os.environ.get("CODESPACES", "").lower() == "true", "I1 primary launcher requires GitHub Codespaces")
        require(bool(os.environ.get("CODESPACE_NAME", "").strip()), "Codespace identity is missing")
        require(PROJECT_RE.fullmatch(args.project_name) is not None, "I1 Compose project name is invalid")
        require(args.registry_manifest.is_file(), "I1 publication manifest is missing")
        manifest_bytes = args.registry_manifest.read_bytes()
        manifest = json.loads(manifest_bytes)
        require(isinstance(manifest, dict), "I1 publication manifest must be an object")
        binding = validate_published_manifest(
            manifest,
            release_id=args.release_id,
            source_sha=args.source_sha,
            repository=args.repository,
        )
        values = build_compose_environment(binding, ingress_port=args.ingress_port)
        _write_env_exclusive(args.env_file, values)

        _run((sys.executable, str(STATIC_VERIFIER)))
        compose = (
            "docker",
            "compose",
            "--env-file",
            str(args.env_file),
            "--project-name",
            args.project_name,
            "--file",
            str(BASE_COMPOSE),
        )
        _run((*compose, "config", "--quiet"))
        _run((*compose, "up", "--detach", "--no-build", "--pull", "always", "--wait"))
        _run(
            (
                sys.executable,
                str(COLLECTOR),
                "--registry-manifest",
                str(args.registry_manifest),
                "--release-id",
                args.release_id,
                "--source-sha",
                args.source_sha,
                "--repository",
                args.repository,
                "--compose-file",
                str(BASE_COMPOSE),
                "--env-file",
                str(args.env_file),
                "--project-name",
                args.project_name,
                "--hosting-provider",
                "github_codespaces",
                "--output",
                str(args.runtime_evidence),
                "--publish",
            )
        )
    except (ContractError, OSError, json.JSONDecodeError) as exc:
        print(f"I1 Codespaces launch failed: {exc}", file=sys.stderr)
        return 1
    print(
        "I1 Codespaces candidate started: digest_only=true no_build=true "
        "runtime_evidence_published=true port_visibility_unchanged=true"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
