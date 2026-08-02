#!/usr/bin/env python3
"""Read-only verifier for the six immutable GHCR candidate images.

The verifier intentionally has no registry mutation capability.  It invokes only
``docker buildx imagetools inspect`` and writes one new, exclusively-created local
evidence file after every remote assertion has passed.
"""

from __future__ import annotations

import argparse
import hashlib
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
ACTIVE_TRUTH_CONTRACT_VERSION = "phase5-credit-itemization-v2"
CANONICAL_ACTIVE_TRUTH_PATH = Path("docs/runtime-state/phase5-credit-itemization.json")
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
    r"[A-Za-z0-9._-]+"
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
    active_candidate_sha: str
    active_release_id: str
    control_sha: str
    output: Path
    workflow: WorkflowMetadata
    active_truth_sha256: str
    active_truth_control_sha256: str
    baseline_manifest: Mapping[str, Any] | None = None
    baseline_manifest_path: str = ""
    baseline_manifest_sha256: str = ""
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


def _require_release_id(value: Any, label: str = "active_release_id") -> str:
    _require(
        isinstance(value, str)
        and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{2,127}", value) is not None,
        f"{label} must be a non-placeholder release identifier",
    )
    return value


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _read_json_file(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise VerificationError(f"{label} is unavailable") from exc
    try:
        value = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise VerificationError(f"{label} is not valid UTF-8 JSON") from exc
    _require(isinstance(value, dict), f"{label} must be a JSON object")
    return value, raw


def _run_git(command: Sequence[str], label: str) -> CommandResult:
    try:
        completed = subprocess.run(
            ["git", *command],
            check=False,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError, subprocess.TimeoutExpired) as exc:
        raise VerificationError(f"{label} could not be verified with git") from exc
    _require(completed.returncode == 0, f"{label} could not be verified with git")
    return CommandResult(
        completed.returncode,
        completed.stdout.decode("utf-8", errors="replace"),
        completed.stderr.decode("utf-8", errors="replace"),
    )


def _require_tracked_clean_repo_file(path: Path, label: str) -> str:
    repo_root = Path(
        _run_git(("rev-parse", "--show-toplevel"), "repository root").stdout.strip()
    ).resolve()
    try:
        resolved = path.resolve(strict=True)
        relative = resolved.relative_to(repo_root).as_posix()
    except (OSError, ValueError) as exc:
        raise VerificationError(f"{label} must be a tracked file inside the repository") from exc
    _run_git(("ls-files", "--error-unmatch", "--", relative), f"{label} tracking")
    for diff_args in (
        ("diff", "--quiet", "--", relative),
        ("diff", "--cached", "--quiet", "--", relative),
    ):
        try:
            completed = subprocess.run(
                ["git", *diff_args],
                check=False,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=30,
            )
        except (OSError, subprocess.SubprocessError, subprocess.TimeoutExpired) as exc:
            raise VerificationError(f"{label} cleanliness could not be verified") from exc
        _require(completed.returncode == 0, f"{label} has unstaged or staged drift")
    return relative


def _validate_active_truth_object(
    truth: Mapping[str, Any],
    candidate_sha: str,
    label: str,
) -> str:
    _require(
        truth.get("contract_version") == ACTIVE_TRUTH_CONTRACT_VERSION,
        f"{label} contract_version is invalid",
    )
    truth_candidate = _require_sha40(
        truth.get("active_source_commit_sha"), f"{label} active_source_commit_sha"
    )
    _require(
        truth_candidate == candidate_sha,
        f"{label} selects a stale candidate instead of the requested active candidate",
    )
    return _require_release_id(truth.get("active_release_id"), f"{label} active_release_id")


def load_active_candidate_truth(
    path: Path,
    candidate_sha: str,
    control_sha: str,
) -> tuple[str, str, str]:
    """Bind a requested candidate to clean tracked truth and the workflow control commit."""

    canonical_path = (Path.cwd() / CANONICAL_ACTIVE_TRUTH_PATH).resolve()
    try:
        requested_path = path.resolve(strict=True)
    except OSError as exc:
        raise VerificationError("active candidate truth is unavailable") from exc
    _require(
        requested_path == canonical_path,
        "active candidate truth must use docs/runtime-state/phase5-credit-itemization.json",
    )

    _require_tracked_clean_repo_file(requested_path, "active candidate truth")

    truth, truth_raw = _read_json_file(requested_path, "active candidate truth")
    active_release_id = _validate_active_truth_object(
        truth, candidate_sha, "active candidate truth"
    )

    control_snapshot = _run_git(
        ("show", f"{control_sha}:{CANONICAL_ACTIVE_TRUTH_PATH.as_posix()}"),
        "control-SHA active candidate truth",
    ).stdout.encode("utf-8")
    try:
        control_truth = json.loads(control_snapshot.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise VerificationError("control-SHA active candidate truth is invalid JSON") from exc
    _require(
        isinstance(control_truth, dict),
        "control-SHA active candidate truth must be a JSON object",
    )
    control_release_id = _validate_active_truth_object(
        control_truth, candidate_sha, "control-SHA active candidate truth"
    )
    _require(
        control_release_id == active_release_id,
        "control-SHA release id does not bind the current active release id",
    )
    return active_release_id, _sha256_bytes(truth_raw), _sha256_bytes(control_snapshot)


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
    _require_sha40(config.active_candidate_sha, "active_candidate_sha")
    _require(
        config.candidate_sha == config.active_candidate_sha,
        "candidate_sha does not equal the active release-candidate SHA",
    )
    _require_release_id(config.active_release_id)
    _require_sha40(config.control_sha, "control_sha")
    _require(
        config.candidate_sha != config.control_sha,
        "candidate_sha must remain distinct from the workflow control_sha",
    )
    _require(
        re.fullmatch(r"[0-9a-f]{64}", config.active_truth_sha256) is not None,
        "active_truth_sha256 must be a sha256 hex digest",
    )
    _require(
        re.fullmatch(r"[0-9a-f]{64}", config.active_truth_control_sha256) is not None,
        "active_truth_control_sha256 must be a sha256 hex digest",
    )

    workflow = config.workflow
    _require(
        isinstance(workflow.repository, str)
        and REPOSITORY_RE.fullmatch(workflow.repository) is not None,
        "workflow repository must be an owner/repository pair",
    )
    _require(
        workflow.workflow_name == "main-deploy",
        "workflow name must be main-deploy",
    )
    _require(isinstance(workflow.run_id, str) and re.fullmatch(r"[1-9][0-9]*", workflow.run_id) is not None, "workflow run_id must be a positive integer string")
    _require(type(workflow.run_attempt) is int and workflow.run_attempt > 0, "workflow run_attempt must be positive")
    _require(
        isinstance(workflow.ref, str) and workflow.ref.startswith("refs/heads/"),
        "workflow ref must be an explicit branch ref",
    )
    _require(
        workflow.event_name == "workflow_dispatch",
        "workflow event_name must be workflow_dispatch",
    )
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


def _manifest_digest_matrix(
    manifest: Mapping[str, Any],
    namespace: str,
    candidate_sha: str,
    label: str,
) -> dict[str, dict[str, Any]]:
    images = manifest.get("images")
    _require(isinstance(images, list) and len(images) == 6, f"{label} must contain six images")
    matrix: dict[str, dict[str, Any]] = {}
    top_digests: set[str] = set()
    for position, image in enumerate(images, start=1):
        image_label = f"{label} image #{position}"
        _require(isinstance(image, dict), f"{image_label} must be an object")
        service = image.get("service")
        _require(service in EXPECTED_SERVICES, f"{image_label} has an unexpected service")
        _require(service not in matrix, f"{label} duplicates service {service}")
        expected_ref = f"{namespace}/{service}:{candidate_sha}"
        _require(image.get("tag") == candidate_sha, f"{service} {label} uses a stale or mutable tag")
        _require(image.get("image_ref") == expected_ref, f"{service} {label} image_ref mismatch")
        top_digest = _require_digest(image.get("digest"), f"{service} {label} top digest")
        _require(top_digest not in top_digests, f"{label} duplicates a top digest")
        top_digests.add(top_digest)

        platform_entries = image.get("index_platforms")
        _require(
            isinstance(platform_entries, list) and len(platform_entries) == 2,
            f"{service} {label} must contain two platform digests",
        )
        platform_digests: dict[str, str] = {}
        for platform_entry in platform_entries:
            _require(isinstance(platform_entry, dict), f"{service} {label} platform entry must be an object")
            platform = platform_entry.get("platform")
            _require(platform in EXPECTED_PLATFORMS, f"{service} {label} has an unexpected platform")
            _require(platform not in platform_digests, f"{service} {label} duplicates platform {platform}")
            digest = _require_digest(
                platform_entry.get("digest"), f"{service} {platform} {label} digest"
            )
            expected_digest_ref = f"{namespace}/{service}@{digest}"
            digest_ref = platform_entry.get("digest_ref", expected_digest_ref)
            _require(
                digest_ref == expected_digest_ref,
                f"{service} {platform} {label} digest_ref mismatch",
            )
            platform_digests[platform] = digest
        _require(
            set(platform_digests) == set(EXPECTED_PLATFORMS),
            f"{service} {label} platform set is incomplete",
        )
        matrix[service] = {"top": top_digest, "platforms": platform_digests}
    _require(set(matrix) == set(EXPECTED_SERVICES), f"{label} service set is incomplete")
    return matrix


def load_baseline_manifest(
    path: Path,
    active_candidate_sha: str,
) -> tuple[dict[str, Any], str, str]:
    """Load a prior publication manifest used for immutable digest readback."""

    relative_path = _require_tracked_clean_repo_file(path, "published GHCR manifest")
    manifest, raw = _read_json_file(path, "published GHCR manifest")
    _require(manifest.get("contract_version") == CONTRACT_VERSION, "published GHCR manifest contract is invalid")
    _require(manifest.get("status") == "verified", "published GHCR manifest is not verified")
    _require(manifest.get("publication_complete") is True, "published GHCR manifest is incomplete")
    _require(manifest.get("registry") == "ghcr.io", "published GHCR manifest registry mismatch")
    candidate_sha = _require_sha40(manifest.get("candidate_sha"), "published manifest candidate_sha")
    _require(
        candidate_sha == active_candidate_sha,
        "published GHCR manifest selects a stale candidate",
    )
    active_binding = manifest.get("active_release_candidate")
    _require(
        isinstance(active_binding, dict),
        "published GHCR manifest active release binding is unavailable",
    )
    _require_release_id(
        active_binding.get("release_id"),
        "published GHCR manifest active release id",
    )
    _require(
        active_binding.get("source_commit_sha") == active_candidate_sha
        and active_binding.get("image_tag") == active_candidate_sha,
        "published GHCR manifest active source/tag binding mismatch",
    )
    _require(
        active_binding.get("truth_contract_version") == ACTIVE_TRUTH_CONTRACT_VERSION,
        "published GHCR manifest active truth contract mismatch",
    )
    for digest_field in ("truth_sha256", "control_truth_sha256"):
        _require(
            isinstance(active_binding.get(digest_field), str)
            and re.fullmatch(r"[0-9a-f]{64}", active_binding[digest_field]) is not None,
            f"published GHCR manifest {digest_field} is invalid",
        )
    publication_readback = manifest.get("registry_readback")
    _require(
        isinstance(publication_readback, dict)
        and publication_readback.get("mode") == "publication-verification"
        and publication_readback.get("source_manifest_bound") is False
        and publication_readback.get("digest_readback_matches_publication") is True
        and publication_readback.get("inspected_image_count") == 6
        and publication_readback.get("inspected_platform_manifest_count") == 12,
        "published GHCR manifest publication readback contract is invalid",
    )
    namespace = manifest.get("namespace")
    _require(
        isinstance(namespace, str) and NAMESPACE_RE.fullmatch(namespace) is not None,
        "published GHCR manifest namespace is invalid",
    )
    _manifest_digest_matrix(manifest, namespace, candidate_sha, "published GHCR manifest")
    return manifest, relative_path, _sha256_bytes(raw)


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
                    "digest_ref": digest_ref,
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
    readback_matrix = _manifest_digest_matrix(
        {"images": images}, config.namespace, config.candidate_sha, "registry readback"
    )
    baseline_bound = config.baseline_manifest is not None
    if baseline_bound:
        _require(
            re.fullmatch(r"[0-9a-f]{64}", config.baseline_manifest_sha256) is not None,
            "baseline_manifest_sha256 must be a sha256 hex digest",
        )
        baseline = config.baseline_manifest
        _require(baseline.get("candidate_sha") == config.candidate_sha, "baseline candidate SHA mismatch")
        _require(baseline.get("control_sha") == config.control_sha, "baseline control SHA mismatch")
        baseline_workflow = baseline.get("workflow")
        _require(isinstance(baseline_workflow, dict), "baseline workflow binding is unavailable")
        _require(
            baseline_workflow.get("run_id") == config.workflow.run_id
            and baseline_workflow.get("run_attempt") == config.workflow.run_attempt
            and baseline_workflow.get("run_url") == config.workflow.run_url
            and baseline_workflow.get("head_sha") == config.workflow.head_sha
            and baseline_workflow.get("candidate_sha") == config.workflow.candidate_sha,
            "baseline workflow run/control/source binding mismatch",
        )
        baseline_matrix = _manifest_digest_matrix(
            baseline, config.namespace, config.candidate_sha, "published GHCR manifest"
        )
        _require(
            readback_matrix == baseline_matrix,
            "registry digest readback differs from the published immutable candidate manifest",
        )

    return {
        "contract_version": CONTRACT_VERSION,
        "status": "verified",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "registry": "ghcr.io",
        "namespace": config.namespace,
        "candidate_sha": config.candidate_sha,
        "control_sha": config.control_sha,
        "active_release_candidate": {
            "release_id": config.active_release_id,
            "source_commit_sha": config.active_candidate_sha,
            "image_tag": config.active_candidate_sha,
            "truth_contract_version": ACTIVE_TRUTH_CONTRACT_VERSION,
            "truth_path": CANONICAL_ACTIVE_TRUTH_PATH.as_posix(),
            "truth_sha256": config.active_truth_sha256,
            "control_truth_sha256": config.active_truth_control_sha256,
        },
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
        "registry_readback": {
            "mode": "published-manifest-revalidation" if baseline_bound else "publication-verification",
            "source_manifest_bound": baseline_bound,
            "source_manifest_path": config.baseline_manifest_path if baseline_bound else "",
            "source_manifest_sha256": config.baseline_manifest_sha256 if baseline_bound else "",
            "digest_readback_matches_publication": True,
            "inspected_image_count": 6,
            "inspected_platform_manifest_count": 12,
        },
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
    parser.add_argument("--namespace", default=_env("GHCR_IMAGE_NAMESPACE"))
    parser.add_argument("--candidate-sha", default=_env("CANDIDATE_SHA"))
    parser.add_argument("--active-candidate-sha", default=_env("ACTIVE_RELEASE_CANDIDATE_SHA"))
    parser.add_argument(
        "--active-candidate-truth",
        type=Path,
        default=Path(_env("ACTIVE_RELEASE_CANDIDATE_TRUTH") or CANONICAL_ACTIVE_TRUTH_PATH),
    )
    parser.add_argument("--source-manifest", type=Path, default=_env("GHCR_PUBLISHED_MANIFEST"))
    parser.add_argument("--control-sha", default=_env("CONTROL_SHA"))
    parser.add_argument("--output", type=Path, default=_env("GHCR_RELEASE_MANIFEST"), required=_env("GHCR_RELEASE_MANIFEST") is None)
    parser.add_argument("--repository", default=_env("GITHUB_REPOSITORY"))
    parser.add_argument("--workflow-name", default=_env("GITHUB_WORKFLOW"))
    parser.add_argument("--workflow-run-id", default=_env("GITHUB_RUN_ID"))
    parser.add_argument("--workflow-run-attempt", type=int, default=_env("GITHUB_RUN_ATTEMPT"))
    parser.add_argument("--workflow-run-url", default=_env("WORKFLOW_RUN_URL"))
    parser.add_argument("--workflow-ref", default=_env("GITHUB_REF"))
    parser.add_argument("--workflow-head-sha", default=_env("GITHUB_SHA"))
    parser.add_argument("--workflow-candidate-sha", default=_env("WORKFLOW_CANDIDATE_SHA"))
    parser.add_argument("--workflow-event-name", default=_env("GITHUB_EVENT_NAME"))
    return parser


def config_from_args(args: argparse.Namespace) -> VerificationConfig:
    baseline: dict[str, Any] | None = None
    baseline_path = ""
    baseline_sha256 = ""
    active_candidate_sha = args.active_candidate_sha or args.candidate_sha
    _require(active_candidate_sha is not None, "active release-candidate SHA is required")
    _require_sha40(active_candidate_sha, "active release-candidate SHA")

    if args.source_manifest is not None:
        baseline, baseline_path, baseline_sha256 = load_baseline_manifest(
            args.source_manifest, active_candidate_sha
        )
        workflow_payload = baseline.get("workflow")
        _require(isinstance(workflow_payload, dict), "published GHCR manifest workflow is unavailable")

        derived = {
            "namespace": baseline.get("namespace"),
            "candidate_sha": baseline.get("candidate_sha"),
            "control_sha": baseline.get("control_sha"),
            "repository": workflow_payload.get("repository"),
            "workflow_name": workflow_payload.get("name"),
            "workflow_run_id": workflow_payload.get("run_id"),
            "workflow_run_attempt": workflow_payload.get("run_attempt"),
            "workflow_run_url": workflow_payload.get("run_url"),
            "workflow_ref": workflow_payload.get("ref"),
            "workflow_head_sha": workflow_payload.get("head_sha"),
            "workflow_candidate_sha": workflow_payload.get("candidate_sha"),
            "workflow_event_name": workflow_payload.get("event_name"),
        }
        for argument_name, derived_value in derived.items():
            explicit_value = getattr(args, argument_name)
            if explicit_value is not None:
                _require(
                    explicit_value == derived_value,
                    f"explicit {argument_name} does not match the published GHCR manifest",
                )
            setattr(args, argument_name, derived_value)

    required_values = {
        "namespace": args.namespace,
        "candidate_sha": args.candidate_sha,
        "control_sha": args.control_sha,
        "repository": args.repository,
        "workflow_name": args.workflow_name,
        "workflow_run_id": args.workflow_run_id,
        "workflow_run_attempt": args.workflow_run_attempt,
        "workflow_run_url": args.workflow_run_url,
        "workflow_ref": args.workflow_ref,
        "workflow_head_sha": args.workflow_head_sha,
        "workflow_candidate_sha": args.workflow_candidate_sha,
        "workflow_event_name": args.workflow_event_name,
    }
    missing = [name for name, value in required_values.items() if value in (None, "")]
    _require(not missing, f"missing required candidate metadata: {', '.join(missing)}")

    active_release_id, active_truth_sha256, control_truth_sha256 = load_active_candidate_truth(
        args.active_candidate_truth,
        active_candidate_sha,
        args.control_sha,
    )
    if baseline is not None:
        active_binding = baseline["active_release_candidate"]
        _require(
            active_binding.get("release_id") == active_release_id,
            "published GHCR manifest release id is stale",
        )
        _require(
            active_binding.get("control_truth_sha256") == control_truth_sha256,
            "published GHCR manifest control-truth digest mismatch",
        )
    return VerificationConfig(
        namespace=args.namespace,
        candidate_sha=args.candidate_sha,
        active_candidate_sha=active_candidate_sha,
        active_release_id=active_release_id,
        control_sha=args.control_sha,
        output=args.output,
        active_truth_sha256=active_truth_sha256,
        active_truth_control_sha256=control_truth_sha256,
        baseline_manifest=baseline,
        baseline_manifest_path=baseline_path,
        baseline_manifest_sha256=baseline_sha256,
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
