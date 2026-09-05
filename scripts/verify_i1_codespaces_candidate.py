#!/usr/bin/env python3
"""Independently verify I1 candidate HTTPS, SSE, and immutable image identity.

The verifier is intended for a separate GitHub Actions run.  It performs only
read-only registry inspections and public HTTPS requests.  It never deploys,
pulls a runtime container, writes to GHCR, or consumes application credentials.
"""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Mapping, Sequence

from i1_codespaces_contract import (
    EXPECTED_APP_SERVICES,
    CandidateBinding,
    ContractError,
    require,
    require_digest,
    require_sha40,
    validate_published_manifest,
)


EVIDENCE_CONTRACT = "i1-hosted-candidate-parity-v1"
RUNTIME_PROVENANCE_CONTRACT = "i1-codespaces-runtime-provenance-v1"
INDEX_MEDIA_TYPES = {
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
}
MANIFEST_MEDIA_TYPES = {
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
}


@dataclass(frozen=True)
class CommandResult:
    returncode: int
    stdout: str
    stderr: str = ""


RegistryRunner = Callable[[tuple[str, ...]], CommandResult]


@dataclass(frozen=True)
class RegistryObservation:
    service: str
    image_ref: str
    top_digest: str
    amd64_manifest_digest: str
    config_digest: str
    oci_revision: str
    oci_source: str


@dataclass(frozen=True)
class VerifiedRuntimeImage:
    service: str
    image_ref: str
    top_digest: str
    amd64_manifest_digest: str
    config_digest: str
    runtime_image_id: str
    oci_revision: str
    oci_source: str


@dataclass(frozen=True)
class HttpObservation:
    status: int
    content_type: str
    final_url: str
    body: bytes


def _subprocess_registry_runner(command: tuple[str, ...]) -> CommandResult:
    try:
        completed = subprocess.run(
            list(command),
            capture_output=True,
            text=True,
            check=False,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise ContractError("read-only registry inspection is unavailable") from exc
    return CommandResult(completed.returncode, completed.stdout, completed.stderr)


def _inspect(runner: RegistryRunner, command: tuple[str, ...], label: str) -> str:
    require(command[:4] == ("docker", "buildx", "imagetools", "inspect"), "internal registry command is not read-only")
    try:
        result = runner(command)
    except (OSError, subprocess.SubprocessError) as exc:
        raise ContractError(f"{label} registry inspection failed") from exc
    require(isinstance(result, CommandResult), f"{label} registry runner result is invalid")
    require(result.returncode == 0, f"{label} registry inspection failed")
    require(bool(result.stdout.strip()), f"{label} registry inspection returned no data")
    return result.stdout


def _json_object(raw: str, label: str) -> Mapping[str, Any]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ContractError(f"{label} is not valid JSON") from exc
    require(isinstance(value, Mapping), f"{label} must be an object")
    return value


def _parse_top(raw: str, expected_ref: str, expected_digest: str, service: str) -> None:
    names = re.findall(r"(?m)^Name:[ \t]*(\S+)[ \t]*$", raw)
    digests = re.findall(r"(?m)^Digest:[ \t]*(sha256:[0-9a-f]{64})[ \t]*$", raw)
    require(names == [expected_ref], f"{service} top-level inspection did not use the digest ref")
    require(digests == [expected_digest], f"{service} top digest readback mismatch")


def _amd64_child(raw: str, expected_digest: str, service: str) -> str:
    index = _json_object(raw, f"{service} top index")
    require(index.get("schemaVersion") == 2, f"{service} top index schema mismatch")
    require(index.get("mediaType") in INDEX_MEDIA_TYPES, f"{service} top object is not an image index")
    manifests = index.get("manifests")
    require(isinstance(manifests, list) and len(manifests) == 2, f"{service} index must contain two platforms")
    platform_map: dict[str, str] = {}
    for descriptor in manifests:
        require(isinstance(descriptor, Mapping), f"{service} index descriptor is invalid")
        platform = descriptor.get("platform")
        require(isinstance(platform, Mapping), f"{service} index platform is missing")
        name = f"{platform.get('os')}/{platform.get('architecture')}"
        require(name in {"linux/amd64", "linux/arm64"}, f"{service} index platform is unexpected")
        require(name not in platform_map, f"{service} index platform is duplicated")
        platform_map[name] = require_digest(descriptor.get("digest"), f"{service} {name} child digest")
    require(set(platform_map) == {"linux/amd64", "linux/arm64"}, f"{service} index platform set is incomplete")
    require(platform_map["linux/amd64"] == expected_digest, f"{service} amd64 child digest mismatch")
    return platform_map["linux/amd64"]


def _config_digest(raw: str, service: str) -> str:
    manifest = _json_object(raw, f"{service} amd64 manifest")
    require(manifest.get("schemaVersion") == 2, f"{service} amd64 manifest schema mismatch")
    require(manifest.get("mediaType") in MANIFEST_MEDIA_TYPES, f"{service} amd64 object is not an image manifest")
    config = manifest.get("config")
    require(isinstance(config, Mapping), f"{service} config descriptor is missing")
    require(type(config.get("size")) is int and config["size"] > 0, f"{service} config descriptor size is invalid")
    return require_digest(config.get("digest"), f"{service} config digest")


def _config_labels(raw: str, binding: CandidateBinding, service: str) -> tuple[str, str]:
    image = _json_object(raw, f"{service} amd64 config")
    require(image.get("os") == "linux" and image.get("architecture") == "amd64", f"{service} config platform mismatch")
    config = image.get("config")
    require(isinstance(config, Mapping), f"{service} image config payload is missing")
    labels = config.get("Labels", config.get("labels"))
    require(isinstance(labels, Mapping), f"{service} OCI labels are missing")
    revision = labels.get("org.opencontainers.image.revision")
    source = labels.get("org.opencontainers.image.source")
    require(revision == binding.source_sha, f"{service} OCI revision does not equal source S")
    require(source == binding.oci_source, f"{service} OCI source mismatch")
    return str(revision), str(source)


def verify_registry_readback(
    binding: CandidateBinding,
    runner: RegistryRunner = _subprocess_registry_runner,
) -> dict[str, RegistryObservation]:
    """Read back top, amd64 child, config digest, and OCI source/revision."""

    observations: dict[str, RegistryObservation] = {}
    config_digests: set[str] = set()
    for service in EXPECTED_APP_SERVICES:
        published = binding.images[service]
        digest_ref = published.digest_ref
        top_text = _inspect(
            runner,
            ("docker", "buildx", "imagetools", "inspect", digest_ref),
            f"{service} top",
        )
        _parse_top(top_text, digest_ref, published.top_digest, service)
        raw_index = _inspect(
            runner,
            ("docker", "buildx", "imagetools", "inspect", "--raw", digest_ref),
            f"{service} top index",
        )
        amd64_digest = _amd64_child(raw_index, published.amd64_manifest_digest, service)
        child_ref = f"{binding.namespace}/{service}@{amd64_digest}"
        raw_child = _inspect(
            runner,
            ("docker", "buildx", "imagetools", "inspect", "--raw", child_ref),
            f"{service} amd64 child",
        )
        config_digest = _config_digest(raw_child, service)
        require(config_digest not in config_digests, f"config digest is duplicated across services: {service}")
        config_digests.add(config_digest)
        raw_config = _inspect(
            runner,
            (
                "docker",
                "buildx",
                "imagetools",
                "inspect",
                "--format",
                "{{json .Image}}",
                child_ref,
            ),
            f"{service} amd64 config",
        )
        revision, source = _config_labels(raw_config, binding, service)
        observations[service] = RegistryObservation(
            service=service,
            image_ref=digest_ref,
            top_digest=published.top_digest,
            amd64_manifest_digest=amd64_digest,
            config_digest=config_digest,
            oci_revision=revision,
            oci_source=source,
        )
    require(set(observations) == set(EXPECTED_APP_SERVICES), "registry readback is incomplete")
    return observations


def validate_runtime_provenance(
    binding: CandidateBinding,
    registry: Mapping[str, RegistryObservation],
    provenance: Mapping[str, Any],
) -> list[VerifiedRuntimeImage]:
    require(provenance.get("contract_version") == RUNTIME_PROVENANCE_CONTRACT, "runtime provenance contract mismatch")
    require(provenance.get("status") == "collected", "runtime provenance was not collected")
    require(provenance.get("release_id") == binding.release_id, "runtime release_id mismatch")
    require(provenance.get("source_commit_sha") == binding.source_sha, "runtime source mismatch")
    require(provenance.get("control_commit_sha") == binding.control_sha, "runtime publication control mismatch")
    require(provenance.get("repository") == binding.repository, "runtime repository mismatch")
    require(provenance.get("service_count") == 6, "runtime service_count mismatch")
    require(provenance.get("registry_write_performed") is False, "runtime collector reports a registry write")
    require(provenance.get("secret_output") is False, "runtime collector reports secret output")
    require(provenance.get("production_deploy", False) is False, "runtime collector reports production deployment")
    require(provenance.get("live_provider_calls", False) is False, "runtime collector reports live provider calls")
    compose_contract = provenance.get("compose_contract")
    require(isinstance(compose_contract, Mapping), "runtime Compose contract is missing")
    for field in (
        "digest_only_apps",
        "supporting_images_digest_pinned",
        "builds_absent",
        "source_bind_mounts_absent",
        "same_origin_ingress",
    ):
        require(compose_contract.get(field) is True, f"runtime Compose contract failed: {field}")

    entries = provenance.get("images")
    require(isinstance(entries, list) and len(entries) == 6, "runtime provenance must contain six images")
    by_service: dict[str, Mapping[str, Any]] = {}
    for entry in entries:
        require(isinstance(entry, Mapping), "runtime image entry is invalid")
        service = entry.get("service")
        require(service in EXPECTED_APP_SERVICES, "runtime image service is invalid")
        require(service not in by_service, f"runtime image service is duplicated: {service}")
        by_service[str(service)] = entry
    require(set(by_service) == set(EXPECTED_APP_SERVICES), "runtime image set is incomplete")
    require(set(registry) == set(EXPECTED_APP_SERVICES), "registry observation set is incomplete")

    verified: list[VerifiedRuntimeImage] = []
    for service in EXPECTED_APP_SERVICES:
        observation = registry[service]
        entry = by_service[service]
        require(entry.get("image_ref") == observation.image_ref, f"{service} runtime image_ref mismatch")
        require(entry.get("container_image_ref") == observation.image_ref, f"{service} container did not retain digest ref")
        require(entry.get("top_digest") == observation.top_digest, f"{service} runtime top digest mismatch")
        runtime_image_id = require_digest(entry.get("runtime_image_id"), f"{service} runtime image ID")
        require(runtime_image_id == observation.config_digest, f"{service} runtime image ID does not equal amd64 config digest")
        require(entry.get("oci_revision") == binding.source_sha, f"{service} runtime OCI revision mismatch")
        require(entry.get("oci_source") == binding.oci_source, f"{service} runtime OCI source mismatch")
        require(entry.get("running") is True and entry.get("healthy") is True, f"{service} is not running and healthy")
        require(entry.get("source_bind_mount_count") == 0, f"{service} runtime has source bind mounts")
        verified.append(
            VerifiedRuntimeImage(
                service=service,
                image_ref=observation.image_ref,
                top_digest=observation.top_digest,
                amd64_manifest_digest=observation.amd64_manifest_digest,
                config_digest=observation.config_digest,
                runtime_image_id=runtime_image_id,
                oci_revision=observation.oci_revision,
                oci_source=observation.oci_source,
            )
        )
    return verified


def _origin(url: str) -> tuple[str, str, int]:
    parsed = urllib.parse.urlsplit(url)
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    return parsed.scheme.lower(), (parsed.hostname or "").lower(), port


def validate_base_url(base_url: str, hosting_provider: str) -> str:
    parsed = urllib.parse.urlsplit(base_url)
    require(parsed.scheme == "https", "I1 base URL must use HTTPS")
    require(bool(parsed.hostname), "I1 base URL hostname is missing")
    require(parsed.username is None and parsed.password is None, "I1 base URL may not contain credentials")
    require(not parsed.query and not parsed.fragment, "I1 base URL may not contain query or fragment")
    require(parsed.path in {"", "/"}, "I1 base URL must be an origin without a path")
    require(parsed.port in {None, 443}, "I1 base URL must use the default HTTPS port")
    host = str(parsed.hostname).lower().rstrip(".")
    require(host not in {"localhost", "localhost.localdomain"} and not host.endswith(".local"), "I1 base URL may not be local")
    try:
        address = ipaddress.ip_address(host.strip("[]"))
    except ValueError:
        address = None
    if address is not None:
        require(address.is_global, "I1 base URL may not use a non-global IP address")
    require(not host.endswith(".trycloudflare.com"), "Quick Tunnels are forbidden for I1")
    if hosting_provider == "github_codespaces":
        require(host.endswith(".app.github.dev"), "primary I1 origin must be a GitHub Codespaces forwarded port")
    elif hosting_provider == "cloudflare_named_tunnel":
        require(not host.endswith(".app.github.dev"), "named-tunnel fallback must use its configured hostname")
    else:
        raise ContractError("hosting provider is invalid")
    return f"https://{host}"


class _SameOriginRedirectHandler(urllib.request.HTTPRedirectHandler):
    def __init__(self, expected_origin: tuple[str, str, int]) -> None:
        super().__init__()
        self.expected_origin = expected_origin

    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[no-untyped-def]
        absolute = urllib.parse.urljoin(req.full_url, newurl)
        if _origin(absolute) != self.expected_origin:
            raise ContractError("HTTPS probe attempted a cross-origin redirect")
        return super().redirect_request(req, fp, code, msg, headers, absolute)


def _request(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    body: bytes | None = None,
    content_type: str = "",
    limit: int = 1_048_576,
    timeout: int = 30,
) -> HttpObservation:
    url = urllib.parse.urljoin(base_url + "/", path.lstrip("/"))
    headers = {
        "Accept": "text/event-stream" if method == "POST" else "application/json, text/html;q=0.8",
        "Origin": base_url,
        "Sec-Fetch-Site": "same-origin",
        "User-Agent": "cloud-superbrain-i1-readonly-verifier/1",
    }
    if content_type:
        headers["Content-Type"] = content_type
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    opener = urllib.request.build_opener(_SameOriginRedirectHandler(_origin(base_url)))
    try:
        with opener.open(request, timeout=timeout) as response:
            payload = response.read(limit + 1)
            require(len(payload) <= limit, f"HTTPS response exceeds the verifier limit: {path}")
            final_url = response.geturl()
            require(_origin(final_url) == _origin(base_url), f"HTTPS response left the same origin: {path}")
            return HttpObservation(
                status=int(response.status),
                content_type=str(response.headers.get("Content-Type", "")).split(";", 1)[0].strip().lower(),
                final_url=final_url,
                body=payload,
            )
    except ContractError:
        raise
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise ContractError(f"HTTPS probe failed: {path}") from exc


def verify_https_and_sse(
    base_url: str,
    *,
    hosting_provider: str,
    provenance_url_path: str,
) -> tuple[Mapping[str, Any], list[dict[str, Any]], dict[str, Any], str]:
    normalized = validate_base_url(base_url, hosting_provider)
    require(provenance_url_path == "/.well-known/cloud-superbrain/i1-provenance.json", "runtime provenance path is not canonical")
    provenance_response = _request(normalized, provenance_url_path)
    require(provenance_response.status == 200, "runtime provenance endpoint is not HTTP 200")
    require(provenance_response.content_type == "application/json", "runtime provenance content type mismatch")
    try:
        provenance = json.loads(provenance_response.body)
    except json.JSONDecodeError as exc:
        raise ContractError("runtime provenance endpoint is not valid JSON") from exc
    require(isinstance(provenance, Mapping), "runtime provenance endpoint must return an object")
    hosting = provenance.get("hosting")
    require(isinstance(hosting, Mapping) and hosting.get("provider") == hosting_provider, "runtime hosting provider mismatch")
    require(hosting.get("primary") is (hosting_provider == "github_codespaces"), "runtime hosting primary flag mismatch")

    endpoint_results: list[dict[str, Any]] = []
    for path, kind in (
        ("/", "frontend"),
        ("/api/v1/health", "agent-api"),
        ("/mcp/api/v1/health", "mcp-gateway"),
        ("/llm/api/v1/health", "llm-gateway"),
    ):
        response = _request(normalized, path)
        require(response.status == 200, f"{kind} HTTPS probe is not HTTP 200")
        if path == "/":
            require(response.content_type == "text/html", "frontend root is not HTML")
        else:
            require(response.content_type == "application/json", f"{kind} health response is not JSON")
            try:
                health = json.loads(response.body)
            except json.JSONDecodeError as exc:
                raise ContractError(f"{kind} health response is not valid JSON") from exc
            require(isinstance(health, Mapping) and health.get("status") == "healthy", f"{kind} health is not healthy")
            if kind == "llm-gateway":
                require(health.get("live_provider_calls") is False, "LLM health reports live provider calls")
        endpoint_results.append(
            {
                "path": path,
                "status": response.status,
                "content_type": response.content_type,
                "same_origin": True,
            }
        )

    session_id = str(uuid.uuid4())
    request_payload = json.dumps(
        {
            "project_id": "i1-codespaces-verifier",
            "prompt": "I1 candidate parity deterministic dry-run proof",
            "session_id": session_id,
        },
        separators=(",", ":"),
    ).encode("utf-8")
    stream = _request(
        normalized,
        "/api/v1/orchestrator/dry-run/stream",
        method="POST",
        body=request_payload,
        content_type="application/json",
        limit=4_194_304,
        timeout=45,
    )
    require(stream.status == 200, "SSE endpoint is not HTTP 200")
    require(stream.content_type == "text/event-stream", "SSE endpoint content type mismatch")
    stream_text = stream.body.decode("utf-8", errors="strict")
    events = re.findall(r"(?m)^event:\s*([^\r\n]+)\s*$", stream_text)
    event_ids = re.findall(r"(?m)^id:\s*([^\r\n]+)\s*$", stream_text)
    required_events = {"graph_status", "heartbeat", "agent_status", "done"}
    require(required_events.issubset(events), "SSE stream is missing required event types")
    require(events[-1] == "done", "SSE stream has no terminal done event")
    require("error" not in events, "SSE stream emitted an error event")
    require(bool(event_ids), "SSE stream contains no event IDs")
    require("phase2-sse-event-contract-v1" in stream_text, "SSE contract marker is missing")
    require('"live_provider_calls":true' not in stream_text.replace(" ", "").lower(), "SSE stream reports live provider calls")
    sse_result = {
        "path": "/api/v1/orchestrator/dry-run/stream",
        "status": 200,
        "content_type": "text/event-stream",
        "event_types": sorted(set(events)),
        "event_id_count": len(event_ids),
        "terminal_event": "done",
        "contract_version": "phase2-sse-event-contract-v1",
        "live_provider_calls": False,
    }
    return provenance, endpoint_results, sse_result, hashlib.sha256(provenance_response.body).hexdigest()


def write_json_exclusive(path: Path, payload: Mapping[str, Any]) -> None:
    require(path.parent.is_dir(), "evidence output parent must already exist")
    try:
        with path.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True, ensure_ascii=True)
            handle.write("\n")
    except FileExistsError as exc:
        raise ContractError("evidence output already exists; immutable evidence is never overwritten") from exc


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--release-id", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--control-sha", required=True)
    parser.add_argument("--registry-manifest", type=Path, required=True)
    parser.add_argument("--publication-run-id", required=True)
    parser.add_argument("--publication-run-attempt", type=int, required=True)
    parser.add_argument(
        "--hosting-provider",
        choices=("github_codespaces", "cloudflare_named_tunnel"),
        default="github_codespaces",
    )
    parser.add_argument(
        "--runtime-provenance-path",
        default="/.well-known/cloud-superbrain/i1-provenance.json",
    )
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        control_sha = require_sha40(args.control_sha, "verifier control_sha")
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
        require(binding.publication_run_id == args.publication_run_id, "publication run_id input mismatch")
        require(binding.publication_run_attempt == args.publication_run_attempt, "publication run_attempt input mismatch")
        registry = verify_registry_readback(binding)
        provenance, endpoints, sse, provenance_sha256 = verify_https_and_sse(
            args.base_url,
            hosting_provider=args.hosting_provider,
            provenance_url_path=args.runtime_provenance_path,
        )
        runtime_images = validate_runtime_provenance(binding, registry, provenance)
        normalized_url = validate_base_url(args.base_url, args.hosting_provider)
        evidence = {
            "contract_version": EVIDENCE_CONTRACT,
            "status": "verified",
            "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
            "release_id": binding.release_id,
            "source_commit_sha": binding.source_sha,
            "control_commit_sha": control_sha,
            "publication_control_commit_sha": binding.control_sha,
            "repository": binding.repository,
            "base_url": normalized_url,
            "hosting": {
                "provider": args.hosting_provider,
                "primary": args.hosting_provider == "github_codespaces",
                "same_origin_ingress": True,
            },
            "publication_manifest": {
                "contract_version": "ghcr-release-manifest-v1",
                "sha256": hashlib.sha256(manifest_bytes).hexdigest(),
                "run_id": binding.publication_run_id,
                "run_attempt": binding.publication_run_attempt,
                "run_url": binding.publication_run_url,
            },
            "runtime_provenance": {
                "contract_version": RUNTIME_PROVENANCE_CONTRACT,
                "path": args.runtime_provenance_path,
                "sha256": provenance_sha256,
            },
            "service_count": 6,
            "services": list(EXPECTED_APP_SERVICES),
            "images": [
                {
                    "service": item.service,
                    "image_ref": item.image_ref,
                    "top_digest": item.top_digest,
                    "amd64_manifest_digest": item.amd64_manifest_digest,
                    "config_digest": item.config_digest,
                    "runtime_image_id": item.runtime_image_id,
                    "oci_revision": item.oci_revision,
                    "oci_source": item.oci_source,
                    "container_image_ref": item.image_ref,
                    "source_bind_mount_count": 0,
                    "running": True,
                    "healthy": True,
                }
                for item in runtime_images
            ],
            "https": {
                "base_url": normalized_url,
                "same_origin": True,
                "endpoints": endpoints,
            },
            "sse": sse,
            "registry_digest_readback_verified": True,
            "runtime_image_identity_verified": True,
            "oci_source_revision_verified": True,
            "same_origin_https_verified": True,
            "sse_verified": True,
            "digest_only_compose_verified": True,
            "supporting_images_digest_pinned": True,
            "source_bind_mounts_absent": True,
            "builds_absent": True,
            "live_provider_calls": False,
            "registry_write_performed": False,
            "production_deploy": False,
            "release_promotion": False,
            "secret_output": False,
            "non_claims": [
                "This evidence verifies candidate-bound staging parity only; it is not a production deployment or release promotion.",
                "The verifier made read-only registry and HTTPS requests and performed no GHCR write.",
                "No live LLM provider, live MCP write, Codespace creation, tunnel activation, or secret output is claimed.",
            ],
        }
        write_json_exclusive(args.output, evidence)
    except (ContractError, OSError) as exc:
        print(f"I1 hosted candidate verification failed: {exc}", file=sys.stderr)
        return 1
    print(
        f"I1 hosted candidate parity verified: release={args.release_id} "
        f"source={args.source_sha} services=6 evidence={args.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
