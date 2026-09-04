#!/usr/bin/env python3
"""Offline/static verifier for the prepared I1 Codespaces candidate path."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from hashlib import sha256
from pathlib import Path
from typing import Any, Mapping, Sequence

from i1_codespaces_contract import EXPECTED_APP_SERVICES, ContractError, require


BASE_COMPOSE = Path("infrastructure/i1-codespaces/compose.yml")
TUNNEL_COMPOSE = Path("infrastructure/i1-codespaces/compose.named-tunnel.yml")
INGRESS_CONFIG = Path("infrastructure/i1-codespaces/nginx.conf")
DEVCONTAINER = Path(".devcontainer/i1-codespaces/devcontainer.json")
LAUNCHER = Path("scripts/launch_i1_codespaces_candidate.py")
COLLECTOR = Path("scripts/collect_i1_codespaces_evidence.py")
HOSTED_VERIFIER = Path("scripts/verify_i1_codespaces_candidate.py")
WORKFLOW = Path(".github/workflows/i1-codespaces-candidate-verify.yml")
SUPPORT_SERVICES = ("postgres", "redis", "ingress", "evidence-publisher")
CONTROL_IMAGE = "mcr.microsoft.com/devcontainers/universal@sha256:dca6a985ffbbc74007a13b6f56ac0fbbc5febae081350b66e865a5549338134b"


def _digest(label: str) -> str:
    return sha256(label.encode("utf-8")).hexdigest()


def _compose_environment(token_file: Path) -> dict[str, str]:
    source = "a" * 40
    values = {
        "I1_RELEASE_ID": "prod-candidate-static-rc1",
        "I1_SOURCE_SHA": source,
        "I1_SOURCE_SHA_SHORT": source[:12],
        "I1_CONTROL_SHA": "b" * 40,
        "I1_REPOSITORY": "example/cloud-superbrain",
        "I1_IMAGE_NAMESPACE": "ghcr.io/example/cloud-superbrain-developer-platform",
        "I1_OCI_SOURCE": "https://github.com/example/cloud-superbrain",
        "I1_INGRESS_PORT": "18080",
        "I1_CLOUDFLARED_DIGEST_HEX": _digest("cloudflared"),
        "I1_CLOUDFLARE_TUNNEL_TOKEN_FILE": str(token_file),
    }
    for service in EXPECTED_APP_SERVICES:
        values[f"I1_{service.upper().replace('-', '_')}_DIGEST_HEX"] = _digest(service)
    return values


def _write_env(path: Path, values: Mapping[str, str]) -> None:
    path.write_text("".join(f"{key}={value}\n" for key, value in sorted(values.items())), encoding="utf-8")


def _render_compose(repo_root: Path, *, include_tunnel: bool) -> Mapping[str, Any]:
    with tempfile.TemporaryDirectory() as temporary:
        temp = Path(temporary)
        token_file = temp / "named-tunnel-token"
        token_file.write_text("static-verifier-placeholder-not-a-live-token\n", encoding="utf-8")
        env_file = temp / "candidate.env"
        _write_env(env_file, _compose_environment(token_file))
        command = [
            "docker",
            "compose",
            "--env-file",
            str(env_file),
            "--file",
            str(repo_root / BASE_COMPOSE),
            "--profile",
            "evidence",
        ]
        if include_tunnel:
            command.extend(("--file", str(repo_root / TUNNEL_COMPOSE), "--profile", "named-tunnel"))
        command.extend(("config", "--format", "json"))
        try:
            completed = subprocess.run(command, capture_output=True, text=True, check=False, timeout=30)
        except (OSError, subprocess.SubprocessError) as exc:
            raise ContractError("Docker Compose is required for the offline I1 static verifier") from exc
        require(completed.returncode == 0, "I1 Compose configuration does not render")
        try:
            value = json.loads(completed.stdout)
        except json.JSONDecodeError as exc:
            raise ContractError("I1 Compose rendered output is not JSON") from exc
        require(isinstance(value, Mapping), "I1 Compose rendered output must be an object")
        return value


def _digest_pinned_image(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[^\s@]+(?:[:][^\s@]+)?@sha256:[0-9a-f]{64}", value) is not None


def _verify_compose(config: Mapping[str, Any], *, include_tunnel: bool) -> None:
    services = config.get("services")
    require(isinstance(services, Mapping), "I1 Compose services are missing")
    expected = set(EXPECTED_APP_SERVICES) | set(SUPPORT_SERVICES)
    if include_tunnel:
        expected.add("cloudflared")
    require(set(services) == expected, "I1 Compose service set is not exact")
    for name, raw in services.items():
        require(isinstance(raw, Mapping), f"I1 Compose service is invalid: {name}")
        require("build" not in raw, f"I1 Compose contains a forbidden build: {name}")
        require(_digest_pinned_image(raw.get("image")), f"I1 Compose image is not digest pinned: {name}")
        if name in EXPECTED_APP_SERVICES:
            expected_suffix = f"/{name}@sha256:"
            require(expected_suffix in str(raw.get("image")), f"I1 app image is not service/digest bound: {name}")
            require(raw.get("pull_policy") == "always", f"I1 app pull policy is not always: {name}")
            require(raw.get("read_only") is True, f"I1 app root filesystem is writable: {name}")
            volumes = raw.get("volumes", [])
            require(isinstance(volumes, list), f"I1 app volumes are invalid: {name}")
            require(
                all(isinstance(volume, Mapping) and volume.get("type") != "bind" for volume in volumes),
                f"I1 app contains a source bind mount: {name}",
            )
    ingress = services["ingress"]
    require(isinstance(ingress, Mapping), "I1 ingress service is invalid")
    ports = ingress.get("ports")
    require(isinstance(ports, list) and len(ports) == 1, "I1 ingress must publish exactly one port")
    port = ports[0]
    require(isinstance(port, Mapping), "I1 ingress port must use normalized long syntax")
    require(port.get("host_ip") == "127.0.0.1" and port.get("target") == 8080, "I1 ingress must bind one loopback host port")
    if include_tunnel:
        tunnel = services["cloudflared"]
        require(isinstance(tunnel, Mapping), "named tunnel service is invalid")
        require(tunnel.get("profiles") == ["named-tunnel"], "named tunnel must remain behind its explicit profile")


def _verify_text_contracts(repo_root: Path) -> None:
    ingress = (repo_root / INGRESS_CONFIG).read_text(encoding="utf-8")
    for marker in (
        "location /api/",
        "location /mcp/",
        "location /llm/",
        "location / {",
        "proxy_buffering off",
        "proxy_request_buffering off",
        "/.well-known/cloud-superbrain/i1-provenance.json",
    ):
        require(marker in ingress, f"I1 same-origin ingress marker is missing: {marker}")
    require("listen 8080" in ingress, "I1 ingress port mismatch")

    tunnel = (repo_root / TUNNEL_COMPOSE).read_text(encoding="utf-8")
    for marker in ("profiles:", "named-tunnel", "--token-file", "cloudflare/cloudflared@sha256:"):
        require(marker in tunnel, f"named-tunnel static marker is missing: {marker}")
    require("trycloudflare.com" not in tunnel and "--url" not in tunnel, "Quick Tunnel behavior is forbidden")

    devcontainer = json.loads((repo_root / DEVCONTAINER).read_text(encoding="utf-8"))
    require(devcontainer.get("image") == CONTROL_IMAGE, "Codespaces control image must be the audited immutable digest")
    require(
        devcontainer.get("hostRequirements") == {"cpus": 4, "memory": "16gb", "storage": "32gb"},
        "Codespaces host requirements must reserve the approved four-core candidate envelope",
    )
    require("build" not in devcontainer and "dockerFile" not in devcontainer, "Codespaces control container may not build from source")
    require(devcontainer.get("initializeCommand") == "python3 scripts/verify_i1_codespaces_static.py", "Codespaces must run the offline preflight first")
    require(devcontainer.get("forwardPorts") == [8080], "Codespaces must forward only the candidate ingress port")
    require(devcontainer.get("remoteEnv", {}).get("I1_HOSTING_PROVIDER") == "github_codespaces", "Codespaces must be the primary provider")

    launcher = (repo_root / LAUNCHER).read_text(encoding="utf-8")
    for marker in ("--no-build", "github_codespaces", "CODESPACES", "collect_i1_codespaces_evidence.py"):
        require(marker in launcher, f"Codespaces launcher marker is missing: {marker}")
    for forbidden in ("gh codespace create", "docker build", "docker push", "cloudflared tunnel run"):
        require(forbidden not in launcher.lower(), f"Codespaces launcher contains forbidden action: {forbidden}")

    workflow = (repo_root / WORKFLOW).read_text(encoding="utf-8")
    require("workflow_dispatch:" in workflow and "push:" not in workflow and "pull_request:" not in workflow, "I1 workflow must be manual-only")
    require("packages: read" in workflow and "actions: read" in workflow and "contents: read" in workflow, "I1 workflow permissions must be read-only")
    require("packages: write" not in workflow and "contents: write" not in workflow, "I1 workflow grants write permissions")
    for action_ref in re.findall(r"(?m)^\s*uses:\s*([^\s#]+)", workflow):
        require(re.fullmatch(r"[^@\s]+@[0-9a-f]{40}", action_ref) is not None, f"I1 workflow action is not commit pinned: {action_ref}")
    lowered = workflow.lower()
    forbidden_workflow_patterns = {
        "docker build": r"\bdocker\s+build(?:\s|$)",
        "docker push": r"\bdocker\s+push(?:\s|$)",
        "gh codespace create": r"\bgh\s+codespace\s+create(?:\s|$)",
        "cloudflared tunnel": r"\bcloudflared\s+tunnel(?:\s|$)",
    }
    for label, pattern in forbidden_workflow_patterns.items():
        require(re.search(pattern, lowered) is None, f"I1 workflow contains forbidden mutation: {label}")
    require("imagetools inspect" in workflow, "I1 workflow lacks read-only registry inspection boundary")
    require("verify_i1_codespaces_candidate.py" in workflow, "I1 workflow does not call the independent verifier")

    collector = (repo_root / COLLECTOR).read_text(encoding="utf-8")
    require("docker\", \"inspect" in collector, "I1 collector lacks Docker image-ID inspection")
    require("registry_write_performed" in collector and "secret_output" in collector, "I1 collector lacks non-claim fields")
    verifier = (repo_root / HOSTED_VERIFIER).read_text(encoding="utf-8")
    for marker in ("top_digest", "amd64_manifest_digest", "config_digest", "runtime_image_id", "text/event-stream"):
        require(marker in verifier, f"I1 hosted verifier marker is missing: {marker}")


def verify_static_files(repo_root: Path) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    for relative in (
        BASE_COMPOSE,
        TUNNEL_COMPOSE,
        INGRESS_CONFIG,
        DEVCONTAINER,
        LAUNCHER,
        COLLECTOR,
        HOSTED_VERIFIER,
        WORKFLOW,
    ):
        require((repo_root / relative).is_file(), f"required I1 file is missing: {relative.as_posix()}")
    base = _render_compose(repo_root, include_tunnel=False)
    _verify_compose(base, include_tunnel=False)
    tunnel = _render_compose(repo_root, include_tunnel=True)
    _verify_compose(tunnel, include_tunnel=True)
    _verify_text_contracts(repo_root)
    return {
        "contract_version": "i1-codespaces-static-v1",
        "status": "verified",
        "app_service_count": 6,
        "digest_only_apps": True,
        "supporting_images_digest_pinned": True,
        "builds_absent": True,
        "source_bind_mounts_absent": True,
        "same_origin_ingress": True,
        "codespaces_primary": True,
        "named_tunnel_static_only": True,
        "workflow_read_only": True,
        "external_action_performed": False,
        "secret_output": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args(argv)
    try:
        report = verify_static_files(args.repo_root)
    except (ContractError, OSError, json.JSONDecodeError) as exc:
        print(f"I1 Codespaces static verification failed: {exc}", file=sys.stderr)
        return 1
    print(
        "I1 Codespaces static verification passed: "
        f"apps={report['app_service_count']} digest_only=true builds=false bind_mounts=false "
        "codespaces_primary=true named_tunnel_static_only=true"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
