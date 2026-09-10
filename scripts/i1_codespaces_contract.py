#!/usr/bin/env python3
"""Shared fail-closed contracts for the I1 digest-only Codespaces candidate.

This module is deliberately free of network and Docker side effects.  It accepts
only the already verified ``ghcr-release-manifest-v1`` artifact emitted by the
separate publication workflow and turns that public provenance into immutable
Compose inputs.  It never accepts tags as runtime image selectors.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Mapping


EXPECTED_APP_SERVICES = (
    "agent-api",
    "mcp-gateway",
    "frontend",
    "llm-gateway",
    "agent-worker",
    "memory-worker",
)
EXPECTED_PLATFORMS = ("linux/amd64", "linux/arm64")
PUBLISHED_MANIFEST_CONTRACT = "ghcr-release-manifest-v1"
SOURCE_TRUTH_CONTRACT = "source-qualification-control-v1"

SHA40_RE = re.compile(r"[0-9a-f]{40}")
DIGEST_RE = re.compile(r"sha256:[0-9a-f]{64}")
RELEASE_ID_RE = re.compile(r"prod-candidate-[a-z0-9][a-z0-9._-]{2,127}")
REPOSITORY_RE = re.compile(
    r"[A-Za-z0-9](?:[A-Za-z0-9_.-]{0,98}[A-Za-z0-9])?/[A-Za-z0-9_.-]{1,100}"
)
NAMESPACE_RE = re.compile(
    r"ghcr\.io/[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?"
    r"(?:/[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?)+"
)


class ContractError(RuntimeError):
    """A verifier failure whose message contains no supplied secret values."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def require_sha40(value: Any, label: str) -> str:
    require(isinstance(value, str) and SHA40_RE.fullmatch(value) is not None, f"{label} must be lowercase 40-hex")
    require(value != "0" * 40, f"{label} may not be all zeroes")
    return value


def require_digest(value: Any, label: str) -> str:
    require(isinstance(value, str) and DIGEST_RE.fullmatch(value) is not None, f"{label} must be sha256")
    require(value != f"sha256:{'0' * 64}", f"{label} may not be all zeroes")
    return value


def require_release_id(value: Any) -> str:
    require(isinstance(value, str) and RELEASE_ID_RE.fullmatch(value) is not None, "release_id is invalid")
    return value


def require_repository(value: Any) -> str:
    require(isinstance(value, str) and REPOSITORY_RE.fullmatch(value) is not None, "repository is invalid")
    require(".." not in value and not value.endswith("."), "repository is invalid")
    return value


@dataclass(frozen=True)
class PublishedImage:
    service: str
    top_digest: str
    amd64_manifest_digest: str
    arm64_manifest_digest: str
    namespace: str
    source_sha: str

    @property
    def digest_ref(self) -> str:
        return f"{self.namespace}/{self.service}@{self.top_digest}"


@dataclass(frozen=True)
class CandidateBinding:
    release_id: str
    source_sha: str
    control_sha: str
    repository: str
    namespace: str
    publication_run_id: str
    publication_run_attempt: int
    publication_run_url: str
    images: Mapping[str, PublishedImage]

    @property
    def oci_source(self) -> str:
        return f"https://github.com/{self.repository}"


def _platform_map(entry: Mapping[str, Any], service: str, source_sha: str, repository: str) -> dict[str, str]:
    platforms = entry.get("index_platforms")
    require(isinstance(platforms, list) and len(platforms) == 2, f"{service} must expose exactly two platform manifests")
    result: dict[str, str] = {}
    expected_source = f"https://github.com/{repository}"
    for position, platform_entry in enumerate(platforms, start=1):
        label = f"{service} platform #{position}"
        require(isinstance(platform_entry, Mapping), f"{label} is invalid")
        platform = platform_entry.get("platform")
        require(platform in EXPECTED_PLATFORMS, f"{label} is not an allowed platform")
        require(platform not in result, f"{service} duplicates platform {platform}")
        child_digest = require_digest(platform_entry.get("digest"), f"{label} digest")
        expected_ref = f"{entry.get('image_ref', '').rsplit(':', 1)[0]}@{child_digest}"
        require(platform_entry.get("digest_ref") == expected_ref, f"{label} digest_ref mismatch")
        labels = platform_entry.get("oci_labels")
        require(isinstance(labels, Mapping), f"{label} OCI labels are missing")
        require(labels.get("org.opencontainers.image.revision") == source_sha, f"{label} OCI revision mismatch")
        require(labels.get("org.opencontainers.image.source") == expected_source, f"{label} OCI source mismatch")
        require(
            labels.get("org.opencontainers.image.version") == f"candidate-{source_sha}",
            f"{label} OCI version mismatch",
        )
        result[str(platform)] = child_digest
    require(set(result) == set(EXPECTED_PLATFORMS), f"{service} platform set is incomplete")
    require(len(set(result.values())) == 2, f"{service} platform digests must be unique")
    return result


def validate_published_manifest(
    manifest: Mapping[str, Any],
    *,
    release_id: str,
    source_sha: str,
    repository: str,
) -> CandidateBinding:
    """Validate the publication artifact and return immutable runtime inputs."""

    release_id = require_release_id(release_id)
    source_sha = require_sha40(source_sha, "source_sha")
    repository = require_repository(repository)
    require(isinstance(manifest, Mapping), "published manifest must be an object")
    require(manifest.get("contract_version") == PUBLISHED_MANIFEST_CONTRACT, "published manifest contract mismatch")
    require(manifest.get("status") == "verified", "published manifest is not verified")
    require(manifest.get("registry") == "ghcr.io", "published manifest registry mismatch")
    namespace = manifest.get("namespace")
    require(isinstance(namespace, str) and NAMESPACE_RE.fullmatch(namespace) is not None, "published namespace is invalid")
    require(manifest.get("candidate_sha") == source_sha, "published candidate source mismatch")
    control_sha = require_sha40(manifest.get("control_sha"), "published control_sha")
    require(control_sha != source_sha, "published control SHA must be distinct from candidate source")

    active = manifest.get("active_release_candidate")
    require(isinstance(active, Mapping), "active release binding is missing")
    require(active.get("release_id") == release_id, "published release_id mismatch")
    require(active.get("source_commit_sha") == source_sha, "active release source mismatch")
    require(active.get("image_tag") == source_sha, "active release image tag mismatch")
    require(active.get("truth_contract_version") == SOURCE_TRUTH_CONTRACT, "active release truth contract mismatch")

    require(manifest.get("service_count") == 6, "published manifest service_count must be six")
    require(set(manifest.get("services", [])) == set(EXPECTED_APP_SERVICES), "published service set mismatch")
    require(manifest.get("required_platforms") == list(EXPECTED_PLATFORMS), "published platform policy mismatch")
    require(manifest.get("unique_top_digest_count") == 6, "published unique digest count mismatch")
    require(manifest.get("publication_complete") is True, "candidate publication is incomplete")
    require(manifest.get("inspection_read_only") is True, "publication inspection was not read-only")
    require(manifest.get("selected_tag_is_exact_candidate_sha") is True, "publication did not select the exact candidate tag")
    require(manifest.get("registry_write_performed") is False, "published evidence reports a registry write during verification")
    require(manifest.get("registry_delete_performed") is False, "published evidence reports a registry delete")
    require(manifest.get("secret_output") is False, "published evidence reports secret output")

    workflow = manifest.get("workflow")
    require(isinstance(workflow, Mapping), "publication workflow binding is missing")
    require(workflow.get("repository") == repository, "publication repository mismatch")
    require(workflow.get("name") == "main-deploy", "publication workflow name mismatch")
    require(workflow.get("candidate_sha") == source_sha, "publication workflow candidate mismatch")
    require(workflow.get("head_sha") == control_sha, "publication workflow control mismatch")
    require(workflow.get("event_name") == "workflow_dispatch", "publication must originate from workflow_dispatch")
    run_id = workflow.get("run_id")
    require(isinstance(run_id, str) and run_id.isdecimal() and int(run_id) > 0, "publication run_id is invalid")
    run_attempt = workflow.get("run_attempt")
    require(type(run_attempt) is int and run_attempt > 0, "publication run_attempt is invalid")
    run_url = workflow.get("run_url")
    require(
        run_url == f"https://github.com/{repository}/actions/runs/{run_id}",
        "publication run URL mismatch",
    )

    readback = manifest.get("registry_readback")
    require(isinstance(readback, Mapping), "publication registry readback is missing")
    require(readback.get("digest_readback_matches_publication") is True, "publication digest readback mismatch")
    require(readback.get("inspected_image_count") == 6, "publication image readback count mismatch")
    require(readback.get("inspected_platform_manifest_count") == 12, "publication platform readback count mismatch")

    entries = manifest.get("images")
    require(isinstance(entries, list) and len(entries) == 6, "published manifest must contain six images")
    images: dict[str, PublishedImage] = {}
    top_digests: set[str] = set()
    for position, raw_entry in enumerate(entries, start=1):
        require(isinstance(raw_entry, Mapping), f"published image #{position} is invalid")
        service = raw_entry.get("service")
        require(service in EXPECTED_APP_SERVICES, f"published image #{position} service is invalid")
        require(service not in images, f"published image service is duplicated: {service}")
        expected_tag_ref = f"{namespace}/{service}:{source_sha}"
        require(raw_entry.get("tag") == source_sha, f"{service} does not use the exact candidate tag")
        require(raw_entry.get("image_ref") == expected_tag_ref, f"{service} published image_ref mismatch")
        top_digest = require_digest(raw_entry.get("digest"), f"{service} top digest")
        require(top_digest not in top_digests, f"top digest is duplicated across services: {service}")
        top_digests.add(top_digest)
        platforms = _platform_map(raw_entry, str(service), source_sha, repository)
        images[str(service)] = PublishedImage(
            service=str(service),
            top_digest=top_digest,
            amd64_manifest_digest=platforms["linux/amd64"],
            arm64_manifest_digest=platforms["linux/arm64"],
            namespace=str(namespace),
            source_sha=source_sha,
        )
    require(set(images) == set(EXPECTED_APP_SERVICES), "published image set is incomplete")

    return CandidateBinding(
        release_id=release_id,
        source_sha=source_sha,
        control_sha=control_sha,
        repository=repository,
        namespace=str(namespace),
        publication_run_id=str(run_id),
        publication_run_attempt=int(run_attempt),
        publication_run_url=str(run_url),
        images=images,
    )


def build_compose_environment(binding: CandidateBinding, *, ingress_port: int) -> dict[str, str]:
    """Return only public, non-secret values required by the candidate Compose file."""

    require(type(ingress_port) is int and 1024 <= ingress_port <= 65535, "ingress port is invalid")
    values = {
        "I1_RELEASE_ID": binding.release_id,
        "I1_SOURCE_SHA": binding.source_sha,
        "I1_SOURCE_SHA_SHORT": binding.source_sha[:12],
        "I1_CONTROL_SHA": binding.control_sha,
        "I1_REPOSITORY": binding.repository,
        "I1_IMAGE_NAMESPACE": binding.namespace,
        "I1_OCI_SOURCE": binding.oci_source,
        "I1_INGRESS_PORT": str(ingress_port),
    }
    for service, image in binding.images.items():
        key = f"I1_{service.upper().replace('-', '_')}_DIGEST_HEX"
        values[key] = image.top_digest.removeprefix("sha256:")
    for key, value in values.items():
        require("\n" not in value and "\r" not in value and "\x00" not in value, f"{key} contains control characters")
    require(not any(marker in key for key in values for marker in ("TOKEN", "SECRET", "PASSWORD", "KEY")), "compose environment contains a secret-like field")
    return dict(sorted(values.items()))
