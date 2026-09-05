#!/usr/bin/env python3
"""Collect allowlisted Docker runtime provenance for the I1 Codespaces stack.

The collector does not pull, build, push, deploy, log in, or inspect environment
variables.  It reads an already running Compose project, checks the six candidate
containers against the verified publication manifest, and writes immutable JSON.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

from i1_codespaces_contract import (
    EXPECTED_APP_SERVICES,
    CandidateBinding,
    ContractError,
    require,
    require_digest,
    validate_published_manifest,
)


RUNTIME_PROVENANCE_CONTRACT = "i1-codespaces-runtime-provenance-v1"
EXPECTED_BASE_SUPPORT_SERVICES = ("postgres", "redis", "ingress", "evidence-publisher")


def _image_is_digest_pinned(value: Any) -> bool:
    if not isinstance(value, str) or value.count("@sha256:") != 1:
        return False
    digest = "sha256:" + value.rsplit("@sha256:", 1)[1]
    try:
        require_digest(digest, "support image digest")
    except ContractError:
        return False
    return True


def _normalized_volumes(service: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    volumes = service.get("volumes", [])
    require(isinstance(volumes, list), "service volumes must be a list")
    normalized: list[Mapping[str, Any]] = []
    for volume in volumes:
        require(isinstance(volume, Mapping), "service volume entry must use long syntax")
        normalized.append(volume)
    return normalized


def validate_runtime_snapshot(
    binding: CandidateBinding,
    compose_config: Mapping[str, Any],
    inspections: Mapping[str, Mapping[str, Any]],
    *,
    hosting_provider: str,
    generated_at_utc: str | None = None,
    publication_manifest_sha256: str = "",
) -> dict[str, Any]:
    """Validate pre-collected Compose/inspect values and return allowlisted proof."""

    require(hosting_provider in {"github_codespaces", "cloudflare_named_tunnel"}, "hosting provider is invalid")
    services = compose_config.get("services")
    require(isinstance(services, Mapping), "Compose services are missing")
    require(set(EXPECTED_APP_SERVICES).issubset(services), "Compose app service set is incomplete")
    require(set(inspections) == set(EXPECTED_APP_SERVICES), "runtime inspection set must contain exactly six apps")

    for name, service in services.items():
        require(isinstance(service, Mapping), f"Compose service {name} is invalid")
        require("build" not in service, f"Compose service {name} contains a forbidden build definition")

    supporting_images: list[dict[str, str]] = []
    for support in EXPECTED_BASE_SUPPORT_SERVICES:
        require(support in services, f"supporting service is missing: {support}")
        support_config = services[support]
        require(isinstance(support_config, Mapping), f"supporting service {support} is invalid")
        support_image = support_config.get("image")
        require(_image_is_digest_pinned(support_image), f"supporting image is not digest pinned: {support}")
        supporting_images.append({"service": support, "image_ref": str(support_image)})

    images: list[dict[str, Any]] = []
    runtime_ids: set[str] = set()
    for service_name in EXPECTED_APP_SERVICES:
        image = binding.images[service_name]
        service = services[service_name]
        require(isinstance(service, Mapping), f"Compose app service {service_name} is invalid")
        require(service.get("image") == image.digest_ref, f"{service_name} does not select the published top digest")
        require(service.get("pull_policy") == "always", f"{service_name} pull policy must be always")
        require(service.get("read_only") is True, f"{service_name} root filesystem must be read-only")
        for volume in _normalized_volumes(service):
            require(volume.get("type") != "bind", f"{service_name} has a forbidden source bind mount")

        inspection = inspections[service_name]
        runtime_image_id = require_digest(inspection.get("Image"), f"{service_name} runtime image ID")
        require(runtime_image_id not in runtime_ids, f"runtime image ID is duplicated across services: {service_name}")
        runtime_ids.add(runtime_image_id)
        config = inspection.get("Config")
        require(isinstance(config, Mapping), f"{service_name} container config is missing")
        container_image_ref = config.get("Image")
        require(container_image_ref == image.digest_ref, f"{service_name} container image ref is not digest-only")
        labels = config.get("Labels")
        require(isinstance(labels, Mapping), f"{service_name} OCI labels are missing")
        oci_revision = labels.get("org.opencontainers.image.revision")
        oci_source = labels.get("org.opencontainers.image.source")
        require(oci_revision == binding.source_sha, f"{service_name} OCI revision does not equal source S")
        require(oci_source == binding.oci_source, f"{service_name} OCI source mismatch")

        state = inspection.get("State")
        require(isinstance(state, Mapping) and state.get("Running") is True, f"{service_name} is not running")
        health = state.get("Health")
        require(isinstance(health, Mapping) and health.get("Status") == "healthy", f"{service_name} is not healthy")
        mounts = inspection.get("Mounts", [])
        require(isinstance(mounts, list), f"{service_name} runtime mounts are invalid")
        bind_mount_count = sum(
            1 for mount in mounts if isinstance(mount, Mapping) and str(mount.get("Type", "")).lower() == "bind"
        )
        require(bind_mount_count == 0, f"{service_name} runtime contains a forbidden bind mount")

        images.append(
            {
                "service": service_name,
                "image_ref": image.digest_ref,
                "top_digest": image.top_digest,
                "runtime_image_id": runtime_image_id,
                "container_image_ref": str(container_image_ref),
                "oci_revision": str(oci_revision),
                "oci_source": str(oci_source),
                "running": True,
                "healthy": True,
                "source_bind_mount_count": 0,
            }
        )

    if publication_manifest_sha256:
        require(
            len(publication_manifest_sha256) == 64
            and all(character in "0123456789abcdef" for character in publication_manifest_sha256),
            "publication manifest SHA-256 is invalid",
        )
    generated = generated_at_utc or datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    return {
        "contract_version": RUNTIME_PROVENANCE_CONTRACT,
        "status": "collected",
        "generated_at_utc": generated,
        "release_id": binding.release_id,
        "source_commit_sha": binding.source_sha,
        "control_commit_sha": binding.control_sha,
        "repository": binding.repository,
        "publication_manifest_sha256": publication_manifest_sha256,
        "hosting": {
            "provider": hosting_provider,
            "primary": hosting_provider == "github_codespaces",
        },
        "service_count": 6,
        "images": images,
        "supporting_images": supporting_images,
        "compose_contract": {
            "digest_only_apps": True,
            "supporting_images_digest_pinned": True,
            "builds_absent": True,
            "source_bind_mounts_absent": True,
            "same_origin_ingress": True,
        },
        "registry_write_performed": False,
        "production_deploy": False,
        "live_provider_calls": False,
        "secret_output": False,
    }


def _run(command: Sequence[str], *, stdin: bytes | None = None) -> bytes:
    completed = subprocess.run(
        list(command),
        input=stdin,
        capture_output=True,
        check=False,
        timeout=90,
    )
    if completed.returncode != 0:
        label = " ".join(command[:4])
        raise ContractError(f"read-only runtime command failed: {label}")
    return completed.stdout


def _compose_prefix(args: argparse.Namespace) -> list[str]:
    prefix = ["docker", "compose", "--env-file", str(args.env_file), "--project-name", args.project_name]
    for compose_file in args.compose_file:
        prefix.extend(("--file", str(compose_file)))
    prefix.extend(("--profile", "evidence"))
    return prefix


def collect_from_docker(args: argparse.Namespace) -> tuple[dict[str, Any], bytes]:
    manifest_bytes = args.registry_manifest.read_bytes()
    try:
        manifest = json.loads(manifest_bytes)
    except json.JSONDecodeError as exc:
        raise ContractError("publication manifest is not valid JSON") from exc
    binding = validate_published_manifest(
        manifest,
        release_id=args.release_id,
        source_sha=args.source_sha,
        repository=args.repository,
    )
    prefix = _compose_prefix(args)
    raw_config = _run((*prefix, "config", "--format", "json"))
    try:
        compose_config = json.loads(raw_config)
    except json.JSONDecodeError as exc:
        raise ContractError("Docker Compose config output is not JSON") from exc

    inspections: dict[str, Mapping[str, Any]] = {}
    for service in EXPECTED_APP_SERVICES:
        container_id = _run((*prefix, "ps", "--quiet", service)).decode("utf-8", errors="strict").strip()
        require(bool(container_id) and "\n" not in container_id, f"{service} must have exactly one running container")
        raw_inspect = _run(("docker", "inspect", container_id))
        try:
            inspect_value = json.loads(raw_inspect)
        except json.JSONDecodeError as exc:
            raise ContractError(f"{service} Docker inspection is not JSON") from exc
        require(isinstance(inspect_value, list) and len(inspect_value) == 1, f"{service} Docker inspection is ambiguous")
        require(isinstance(inspect_value[0], Mapping), f"{service} Docker inspection is invalid")
        inspections[service] = inspect_value[0]

    proof = validate_runtime_snapshot(
        binding,
        compose_config,
        inspections,
        hosting_provider=args.hosting_provider,
        publication_manifest_sha256=hashlib.sha256(manifest_bytes).hexdigest(),
    )
    encoded = (json.dumps(proof, indent=2, sort_keys=True, ensure_ascii=True) + "\n").encode("utf-8")
    return proof, encoded


def write_exclusive(path: Path, payload: bytes) -> None:
    require(path.parent.is_dir(), "evidence output parent must already exist")
    try:
        with path.open("xb") as handle:
            handle.write(payload)
    except FileExistsError as exc:
        raise ContractError("evidence output already exists; immutable evidence is never overwritten") from exc


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry-manifest", type=Path, required=True)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--compose-file", type=Path, action="append", required=True)
    parser.add_argument("--env-file", type=Path, required=True)
    parser.add_argument("--project-name", required=True)
    parser.add_argument(
        "--hosting-provider",
        choices=("github_codespaces", "cloudflare_named_tunnel"),
        default="github_codespaces",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--publish", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        require(args.output.suffix.lower() == ".json", "evidence output must be JSON")
        require(not args.output.exists(), "evidence output already exists; immutable evidence is never overwritten")
        _, payload = collect_from_docker(args)
        if args.publish:
            prefix = _compose_prefix(args)
            _run(
                (*prefix, "run", "--rm", "--no-deps", "--no-TTY", "evidence-publisher"),
                stdin=payload,
            )
        write_exclusive(args.output, payload)
    except ContractError as exc:
        print(f"I1 runtime evidence collection failed: {exc}", file=sys.stderr)
        return 1
    print(f"I1 runtime evidence collected: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
