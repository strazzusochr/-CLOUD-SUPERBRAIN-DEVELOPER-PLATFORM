#!/usr/bin/env python3
"""Read-only verifier for the six immutable GHCR candidate images.

The verifier intentionally has no registry mutation capability.  It invokes only
``docker buildx imagetools inspect`` and writes one new, exclusively-created local
evidence file after every remote assertion has passed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence
from urllib.parse import urlparse


CONTRACT_VERSION = "ghcr-release-manifest-v1"
EXPECTED_SERVICES = (
    "agent-api",
    "mcp-gateway",
    "frontend",
    "llm-gateway",
    "agent-worker",
    "memory-worker",
)
EXPECTED_PLATFORMS = ("linux/amd64", "linux/arm64")
INDEX_MEDIA_TYPES = {
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
}
SHA40_RE = re.compile(r"[0-9a-f]{40}")
DIGEST_RE = re.compile(r"sha256:[0-9a-f]{64}")
NAMESPACE_RE = re.compile(
    r"ghcr\.io/[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?"
    r"(?:/[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?)+"
)
REPOSITORY_RE = re.compile(
    r"[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?/"
    r"[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?"
)


class VerificationError(RuntimeError):
    """A fail-closed candidate verification error safe to show to operators."""


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str
    stderr: str = ""


CommandRunner = Callable[[Sequence[str]], CommandResult]


@dataclass(frozen=True)
class WorkflowMetadata:
    repository: str
    workflow_name: str
    run_id: str
    run_attempt: int
    run_url: str
    ref: str
    head_sha: str
    candidate_sha: str
    event_name: str


@dataclass(frozen=True)
class VerificationConfig:
    namespace: str
    candidate_sha: str
    control_sha: str
    output: Path
    workflow: WorkflowMetadata
    services: tuple[str, ...] = EXPECTED_SERVICES


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def _require_sha40(value: str, label: str) -> str:
    _require(
        isinstance(value, str) and SHA40_RE.fullmatch(value) is not None,
        f"{label} must be an exact lowercase 40-hex SHA",
    )
    _require(value != "0" * 40, f"{label} may not be the all-zero placeholder")
    return value


def _require_digest(value: Any, label: str) -> str:
    _require(
        isinstance(value, str) and DIGEST_RE.fullmatch(value) is not None,
        f"{label} must be a sha256 digest",
    )
    _require(value != f"sha256:{'0' * 64}", f"{label} may not be all zeroes")
    return value


def _validate_services(services: Sequence[str]) -> tuple[str, ...]:
    normalized = tuple(services)
    _require(len(normalized) == len(EXPECTED_SERVICES), "exactly six services are required")
    _require(len(set(normalized)) == len(normalized), "service entries must be unique")
    _require(
        set(normalized) == set(EXPECTED_SERVICES),
        "service entries must be exactly agent-api, mcp-gateway, frontend, "
        "llm-gateway, agent-worker, memory-worker",
    )
    # Keep evidence and command order canonical even when an injected caller used
    # another valid ordering.
    return EXPECTED_SERVICES


def _validate_config(config: VerificationConfig) -> tuple[str, ...]:
    _require(
        isinstance(config.namespace, str)
        and NAMESPACE_RE.fullmatch(config.namespace) is not None,
        "namespace must be a lowercase ghcr.io owner/repository path without tag or digest",
    )
    _require(":" not in config.namespace and "@" not in config.namespace, "namespace may not contain a tag or digest")
    _require_sha40(config.candidate_sha, "candidate_sha")
    _require_sha40(config.control_sha, "control_sha")

    workflow = config.workflow
    _require(
        isinstance(workflow.repository, str)
        and REPOSITORY_RE.fullmatch(workflow.repository) is not None,
        "workflow repository must be an owner/repository pair",
    )
    _require(isinstance(workflow.workflow_name, str) and workflow.workflow_name.strip(), "workflow name is required")
    _require(isinstance(workflow.run_id, str) and re.fullmatch(r"[1-9][0-9]*", workflow.run_id) is not None, "workflow run_id must be a positive integer string")
    _require(type(workflow.run_attempt) is int and workflow.run_attempt > 0, "workflow run_attempt must be positive")
    _require(isinstance(workflow.ref, str) and workflow.ref.startswith("refs/"), "workflow ref must be an explicit refs/* value")
    _require(isinstance(workflow.event_name, str) and workflow.event_name.strip(), "workflow event_name is required")
    _require_sha40(workflow.head_sha, "workflow head_sha")
    _require_sha40(workflow.candidate_sha, "workflow candidate_sha")
    _require(workflow.head_sha == config.control_sha, "workflow head_sha does not bind control_sha")
    _require(workflow.candidate_sha == config.candidate_sha, "workflow candidate_sha does not bind candidate_sha")

    parsed_url = urlparse(workflow.run_url)
    expected_path = f"/{workflow.repository}/actions/runs/{workflow.run_id}"
    _require(
        parsed_url.scheme == "https"
        and parsed_url.netloc.lower() == "github.com"
        and parsed_url.path.rstrip("/") == expected_path
        and not parsed_url.params
        and not parsed_url.query
        and not parsed_url.fragment,
        "workflow run_url must bind the repository and run_id on github.com",
    )
    _require(config.output.name != "", "output path must name a JSON file")
    _require(config.output.suffix.lower() == ".json", "output path must end in .json")
    return _validate_services(config.services)


def subprocess_runner(command: Sequence[str]) -> CommandResult:
    """Production command runner; deliberately uses no shell and no stdin."""

    completed = subprocess.run(
        list(command),
        check=False,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=90,
    )
    return CommandResult(completed.returncode, completed.stdout, completed.stderr)


def _run_inspect(runner: CommandRunner, command: Sequence[str], label: str) -> str:
    _require(
        tuple(command[:4]) == ("docker", "buildx", "imagetools", "inspect"),
        "internal guard rejected a non-inspection Docker command",
    )
    try:
        result = runner(tuple(command))
    except (OSError, subprocess.SubprocessError, subprocess.TimeoutExpired) as exc:
        raise VerificationError(
            f"{label} unavailable; Docker/authentication/registry inspection failed"
        ) from exc
    _require(
        isinstance(result, CommandResult),
        f"{label} runner returned an invalid result",
    )
    _require(
        result.returncode == 0,
        f"{label} unavailable; Docker/authentication/registry inspection failed",
    )
    _require(isinstance(result.stdout, str) and result.stdout.strip(), f"{label} returned no inspection data")
    return result.stdout


def _load_object(raw: str, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise VerificationError(f"{label} is not valid JSON") from exc
    _require(isinstance(value, dict), f"{label} must be a JSON object")
    return value


def _parse_top_inspection(raw: str, expected_ref: str, service: str) -> str:
    # Multi-platform output also contains indented per-descriptor Name/Digest
    # lines.  Only column-zero fields belong to the inspected top-level tag.
    name_matches = re.findall(r"(?m)^Name:[ \t]*(\S+)[ \t]*$", raw)
    digest_matches = re.findall(r"(?m)^Digest:[ \t]*(sha256:[0-9a-f]{64})[ \t]*$", raw)
    _require(len(name_matches) == 1, f"{service} inspection must expose exactly one image name")
    _require(name_matches[0] == expected_ref, f"{service} inspection used a mutable or unexpected tag")
    _require(len(digest_matches) == 1, f"{service} inspection must expose exactly one top digest")
    return _require_digest(digest_matches[0], f"{service} top digest")


def _parse_index(raw: str, service: str) -> dict[str, str]:
    index = _load_object(raw, f"{service} raw index")
    _require(index.get("schemaVersion") == 2, f"{service} index schemaVersion must be 2")
    _require(index.get("mediaType") in INDEX_MEDIA_TYPES, f"{service} is not an OCI/Docker image index")
    manifests = index.get("manifests")
    _require(isinstance(manifests, list), f"{service} index manifests are unavailable")
    _require(len(manifests) == 2, f"{service} index must contain exactly two platform manifests")

    platform_digests: dict[str, str] = {}
    for position, descriptor in enumerate(manifests, start=1):
        label = f"{service} index descriptor #{position}"
        _require(isinstance(descriptor, dict), f"{label} must be an object")
        digest = _require_digest(descriptor.get("digest"), f"{label} digest")
        _require(type(descriptor.get("size")) is int and descriptor["size"] > 0, f"{label} size must be positive")
        platform = descriptor.get("platform")
        _require(isinstance(platform, dict), f"{label} platform is unavailable")
        operating_system = platform.get("os")
        architecture = platform.get("architecture")
        _require(isinstance(operating_system, str) and isinstance(architecture, str), f"{label} platform is malformed")
        platform_name = f"{operating_system}/{architecture}"
        _require(platform_name in EXPECTED_PLATFORMS, f"{label} has unexpected platform {platform_name}")
        _require(not platform.get("variant"), f"{label} must not introduce a platform variant")
        _require(platform_name not in platform_digests, f"{service} duplicates platform {platform_name}")
        platform_digests[platform_name] = digest

    _require(set(platform_digests) == set(EXPECTED_PLATFORMS), f"{service} platform set is incomplete")
    _require(len(set(platform_digests.values())) == 2, f"{service} platform digests must be unique")
    return platform_digests


def _parse_config_labels(
    raw: str,
    service: str,
    platform: str,
    expected_source: str,
    candidate_sha: str,
    expected_version: str,
) -> dict[str, str]:
    image = _load_object(raw, f"{service} {platform} image config")
    expected_os, expected_arch = platform.split("/", 1)
    _require(image.get("os") == expected_os, f"{service} {platform} config OS mismatch")
    _require(image.get("architecture") == expected_arch, f"{service} {platform} config architecture mismatch")
    config = image.get("config")
    _require(isinstance(config, dict), f"{service} {platform} config payload is unavailable")
    labels = config.get("Labels")
    if labels is None:
        labels = config.get("labels")
    _require(isinstance(labels, dict), f"{service} {platform} OCI labels are unavailable")

    required = {
        "org.opencontainers.image.source": expected_source,
        "org.opencontainers.image.revision": candidate_sha,
        "org.opencontainers.image.version": expected_version,
    }
    for key, expected_value in required.items():
        _require(labels.get(key) == expected_value, f"{service} {platform} OCI label {key} mismatch")
    return required


def verify_candidate(config: VerificationConfig, runner: CommandRunner = subprocess_runner) -> dict[str, Any]:
    """Inspect and validate the candidate, returning the evidence object in memory."""

    services = _validate_config(config)
    expected_source = f"https://github.com/{config.workflow.repository}"
    expected_version = f"candidate-{config.candidate_sha}"
    images: list[dict[str, Any]] = []
    top_digests: set[str] = set()

    for service in services:
        image_ref = f"{config.namespace}/{service}:{config.candidate_sha}"
        top_output = _run_inspect(
            runner,
            ("docker", "buildx", "imagetools", "inspect", image_ref),
            f"{service} top-level inspection",
        )
        top_digest = _parse_top_inspection(top_output, image_ref, service)
        _require(top_digest not in top_digests, f"top digest is duplicated across services: {service}")
        top_digests.add(top_digest)

        raw_index = _run_inspect(
            runner,
            ("docker", "buildx", "imagetools", "inspect", "--raw", image_ref),
            f"{service} raw-index inspection",
        )
        platform_digests = _parse_index(raw_index, service)

        platform_evidence: list[dict[str, Any]] = []
        for platform in EXPECTED_PLATFORMS:
            platform_digest = platform_digests[platform]
            digest_ref = f"{config.namespace}/{service}@{platform_digest}"
            raw_config = _run_inspect(
                runner,
                (
                    "docker",
                    "buildx",
                    "imagetools",
                    "inspect",
                    "--format",
                    "{{json .Image}}",
                    digest_ref,
                ),
                f"{service} {platform} config inspection",
            )
            labels = _parse_config_labels(
                raw_config,
                service,
                platform,
                expected_source,
                config.candidate_sha,
                expected_version,
            )
            platform_evidence.append(
                {
                    "platform": platform,
                    "digest": platform_digest,
                    "oci_labels": labels,
                }
            )

        images.append(
            {
                "service": service,
                "tag": config.candidate_sha,
                "image_ref": image_ref,
                "digest": top_digest,
                "index_platforms": platform_evidence,
            }
        )

    _require(len(images) == 6 and len(top_digests) == 6, "candidate publication must contain six unique image digests")
    return {
        "contract_version": CONTRACT_VERSION,
        "status": "verified",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "registry": "ghcr.io",
        "namespace": config.namespace,
        "candidate_sha": config.candidate_sha,
        "control_sha": config.control_sha,
        "service_count": 6,
        "services": list(EXPECTED_SERVICES),
        "required_platforms": list(EXPECTED_PLATFORMS),
        "unique_top_digest_count": 6,
        "expected_oci_labels": {
            "org.opencontainers.image.source": expected_source,
            "org.opencontainers.image.revision": config.candidate_sha,
            "org.opencontainers.image.version": expected_version,
        },
        "workflow": {
            "repository": config.workflow.repository,
            "name": config.workflow.workflow_name,
            "run_id": config.workflow.run_id,
            "run_attempt": config.workflow.run_attempt,
            "run_url": config.workflow.run_url,
            "ref": config.workflow.ref,
            "head_sha": config.workflow.head_sha,
            "candidate_sha": config.workflow.candidate_sha,
            "event_name": config.workflow.event_name,
        },
        "images": images,
        "inspection_command": "docker buildx imagetools inspect",
        "inspection_read_only": True,
        "selected_tag_is_exact_candidate_sha": True,
        "mutable_tag_fallback_used": False,
        "mutable_tag_absence_claimed": False,
        "registry_write_performed": False,
        "registry_delete_performed": False,
        "secret_output": False,
        "publication_complete": True,
    }


def write_evidence_exclusive(output: Path, evidence: Mapping[str, Any]) -> None:
    """Write evidence exactly once; never replace or truncate an existing artifact."""

    _require(output.parent.is_dir(), "output parent directory must already exist")
    try:
        with output.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(evidence, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise VerificationError("output evidence already exists; immutable evidence is never overwritten") from exc
    except OSError as exc:
        raise VerificationError("could not exclusively create the evidence file") from exc


def _env(name: str) -> str | None:
    value = os.environ.get(name)
    return value if value not in (None, "") else None


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--namespace", default=_env("GHCR_IMAGE_NAMESPACE"), required=_env("GHCR_IMAGE_NAMESPACE") is None)
    parser.add_argument("--candidate-sha", default=_env("CANDIDATE_SHA"), required=_env("CANDIDATE_SHA") is None)
    parser.add_argument("--control-sha", default=_env("CONTROL_SHA"), required=_env("CONTROL_SHA") is None)
    parser.add_argument("--output", type=Path, default=_env("GHCR_RELEASE_MANIFEST"), required=_env("GHCR_RELEASE_MANIFEST") is None)
    parser.add_argument("--repository", default=_env("GITHUB_REPOSITORY"), required=_env("GITHUB_REPOSITORY") is None)
    parser.add_argument("--workflow-name", default=_env("GITHUB_WORKFLOW"), required=_env("GITHUB_WORKFLOW") is None)
    parser.add_argument("--workflow-run-id", default=_env("GITHUB_RUN_ID"), required=_env("GITHUB_RUN_ID") is None)
    parser.add_argument("--workflow-run-attempt", type=int, default=_env("GITHUB_RUN_ATTEMPT"), required=_env("GITHUB_RUN_ATTEMPT") is None)
    parser.add_argument("--workflow-run-url", default=_env("WORKFLOW_RUN_URL"), required=_env("WORKFLOW_RUN_URL") is None)
    parser.add_argument("--workflow-ref", default=_env("GITHUB_REF"), required=_env("GITHUB_REF") is None)
    parser.add_argument("--workflow-head-sha", default=_env("GITHUB_SHA"), required=_env("GITHUB_SHA") is None)
    parser.add_argument("--workflow-candidate-sha", default=_env("WORKFLOW_CANDIDATE_SHA"), required=_env("WORKFLOW_CANDIDATE_SHA") is None)
    parser.add_argument("--workflow-event-name", default=_env("GITHUB_EVENT_NAME"), required=_env("GITHUB_EVENT_NAME") is None)
    return parser


def config_from_args(args: argparse.Namespace) -> VerificationConfig:
    return VerificationConfig(
        namespace=args.namespace,
        candidate_sha=args.candidate_sha,
        control_sha=args.control_sha,
        output=args.output,
        workflow=WorkflowMetadata(
            repository=args.repository,
            workflow_name=args.workflow_name,
            run_id=args.workflow_run_id,
            run_attempt=args.workflow_run_attempt,
            run_url=args.workflow_run_url,
            ref=args.workflow_ref,
            head_sha=args.workflow_head_sha,
            candidate_sha=args.workflow_candidate_sha,
            event_name=args.workflow_event_name,
        ),
    )


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        config = config_from_args(args)
        evidence = verify_candidate(config)
        write_evidence_exclusive(config.output, evidence)
    except VerificationError as exc:
        print(f"[ghcr-candidate] ERROR: {exc}", file=sys.stderr)
        return 1
    print(
        f"[ghcr-candidate] verified services=6 platforms=2 candidate={config.candidate_sha} "
        f"control={config.control_sha} evidence={config.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
