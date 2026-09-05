from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from copy import deepcopy
from hashlib import sha256
from pathlib import Path


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = SCRIPTS_DIR.parent
sys.path.insert(0, str(SCRIPTS_DIR))

from i1_codespaces_contract import (  # noqa: E402
    EXPECTED_APP_SERVICES,
    ContractError,
    build_compose_environment,
    validate_published_manifest,
)
from collect_i1_codespaces_evidence import validate_runtime_snapshot  # noqa: E402
from verify_i1_codespaces_candidate import (  # noqa: E402
    CommandResult,
    RegistryObservation,
    validate_runtime_provenance,
    verify_registry_readback,
    write_json_exclusive,
)
from verify_i1_codespaces_static import verify_static_files  # noqa: E402


SOURCE_SHA = "a" * 40
CONTROL_SHA = "b" * 40
RELEASE_ID = "prod-candidate-test-rc1"
REPOSITORY = "example/cloud-superbrain"
NAMESPACE = "ghcr.io/example/cloud-superbrain-developer-platform"


def digest(label: str) -> str:
    return f"sha256:{sha256(label.encode('utf-8')).hexdigest()}"


def published_manifest() -> dict[str, object]:
    images: list[dict[str, object]] = []
    for service in EXPECTED_APP_SERVICES:
        images.append(
            {
                "service": service,
                "tag": SOURCE_SHA,
                "image_ref": f"{NAMESPACE}/{service}:{SOURCE_SHA}",
                "digest": digest(f"top-{service}"),
                "index_platforms": [
                    {
                        "platform": "linux/amd64",
                        "digest": digest(f"amd64-{service}"),
                        "digest_ref": f"{NAMESPACE}/{service}@{digest(f'amd64-{service}')}",
                        "oci_labels": {
                            "org.opencontainers.image.source": f"https://github.com/{REPOSITORY}",
                            "org.opencontainers.image.revision": SOURCE_SHA,
                            "org.opencontainers.image.version": f"candidate-{SOURCE_SHA}",
                        },
                    },
                    {
                        "platform": "linux/arm64",
                        "digest": digest(f"arm64-{service}"),
                        "digest_ref": f"{NAMESPACE}/{service}@{digest(f'arm64-{service}')}",
                        "oci_labels": {
                            "org.opencontainers.image.source": f"https://github.com/{REPOSITORY}",
                            "org.opencontainers.image.revision": SOURCE_SHA,
                            "org.opencontainers.image.version": f"candidate-{SOURCE_SHA}",
                        },
                    },
                ],
            }
        )
    return {
        "contract_version": "ghcr-release-manifest-v1",
        "status": "verified",
        "registry": "ghcr.io",
        "namespace": NAMESPACE,
        "candidate_sha": SOURCE_SHA,
        "control_sha": CONTROL_SHA,
        "active_release_candidate": {
            "release_id": RELEASE_ID,
            "source_commit_sha": SOURCE_SHA,
            "image_tag": SOURCE_SHA,
            "truth_contract_version": "source-qualification-control-v1",
            "truth_path": "docs/runtime-state/source-qualification-control.json",
            "truth_sha256": "c" * 64,
            "control_truth_sha256": "d" * 64,
        },
        "service_count": 6,
        "services": list(EXPECTED_APP_SERVICES),
        "required_platforms": ["linux/amd64", "linux/arm64"],
        "unique_top_digest_count": 6,
        "workflow": {
            "repository": REPOSITORY,
            "name": "main-deploy",
            "run_id": "123456789",
            "run_attempt": 1,
            "run_url": f"https://github.com/{REPOSITORY}/actions/runs/123456789",
            "ref": "refs/heads/chore/repo-bootstrap",
            "head_sha": CONTROL_SHA,
            "candidate_sha": SOURCE_SHA,
            "event_name": "workflow_dispatch",
        },
        "images": images,
        "registry_readback": {
            "mode": "publication-verification",
            "source_manifest_bound": False,
            "digest_readback_matches_publication": True,
            "inspected_image_count": 6,
            "inspected_platform_manifest_count": 12,
        },
        "inspection_read_only": True,
        "selected_tag_is_exact_candidate_sha": True,
        "registry_write_performed": False,
        "registry_delete_performed": False,
        "secret_output": False,
        "publication_complete": True,
    }


def compose_config() -> dict[str, object]:
    manifest = published_manifest()
    by_service = {entry["service"]: entry for entry in manifest["images"]}  # type: ignore[index]
    services: dict[str, object] = {}
    for service in EXPECTED_APP_SERVICES:
        top = by_service[service]["digest"]  # type: ignore[index]
        services[service] = {
            "image": f"{NAMESPACE}/{service}@{top}",
            "pull_policy": "always",
            "read_only": True,
            "volumes": (
                [{"type": "volume", "source": "mcp_workspace", "target": "/tmp/agent-workspace"}]
                if service == "mcp-gateway"
                else []
            ),
        }
    services.update(
        {
            "postgres": {"image": f"pgvector/pgvector@{digest('postgres')}"},
            "redis": {"image": f"redis@{digest('redis')}"},
            "ingress": {"image": f"nginxinc/nginx-unprivileged@{digest('nginx')}"},
            "evidence-publisher": {
                "image": f"nginxinc/nginx-unprivileged@{digest('nginx')}",
                "profiles": ["evidence"],
            },
        }
    )
    return {"name": f"sb-i1-{SOURCE_SHA[:12]}", "services": services}


def runtime_inspections(*, image_id_service: str | None = None) -> dict[str, dict[str, object]]:
    manifest = published_manifest()
    by_service = {entry["service"]: entry for entry in manifest["images"]}  # type: ignore[index]
    inspections: dict[str, dict[str, object]] = {}
    for service in EXPECTED_APP_SERVICES:
        top = by_service[service]["digest"]  # type: ignore[index]
        image_id = digest(f"config-{service}")
        if service == image_id_service:
            image_id = digest("wrong-config")
        inspections[service] = {
            "Id": f"container-{service}",
            "Image": image_id,
            "Config": {
                "Image": f"{NAMESPACE}/{service}@{top}",
                "Labels": {
                    "org.opencontainers.image.source": f"https://github.com/{REPOSITORY}",
                    "org.opencontainers.image.revision": SOURCE_SHA,
                },
            },
            "State": {"Running": True, "Health": {"Status": "healthy"}},
            "Mounts": [],
        }
    return inspections


def runtime_provenance() -> dict[str, object]:
    manifest = published_manifest()
    by_service = {entry["service"]: entry for entry in manifest["images"]}  # type: ignore[index]
    images: list[dict[str, object]] = []
    for service in EXPECTED_APP_SERVICES:
        top = by_service[service]["digest"]  # type: ignore[index]
        images.append(
            {
                "service": service,
                "image_ref": f"{NAMESPACE}/{service}@{top}",
                "top_digest": top,
                "runtime_image_id": digest(f"config-{service}"),
                "container_image_ref": f"{NAMESPACE}/{service}@{top}",
                "oci_revision": SOURCE_SHA,
                "oci_source": f"https://github.com/{REPOSITORY}",
                "running": True,
                "healthy": True,
                "source_bind_mount_count": 0,
            }
        )
    return {
        "contract_version": "i1-codespaces-runtime-provenance-v1",
        "status": "collected",
        "release_id": RELEASE_ID,
        "source_commit_sha": SOURCE_SHA,
        "control_commit_sha": CONTROL_SHA,
        "repository": REPOSITORY,
        "hosting": {"provider": "github_codespaces", "primary": True},
        "service_count": 6,
        "images": images,
        "compose_contract": {
            "digest_only_apps": True,
            "supporting_images_digest_pinned": True,
            "builds_absent": True,
            "source_bind_mounts_absent": True,
            "same_origin_ingress": True,
        },
        "registry_write_performed": False,
        "secret_output": False,
    }


class FakeRegistryRunner:
    def __init__(self) -> None:
        self.calls: list[tuple[str, ...]] = []

    def __call__(self, command: tuple[str, ...]) -> CommandResult:
        self.calls.append(command)
        manifest = published_manifest()
        by_service = {entry["service"]: entry for entry in manifest["images"]}  # type: ignore[index]
        ref = command[-1]
        service = next(service for service in EXPECTED_APP_SERVICES if f"/{service}@" in ref)
        image = by_service[service]
        top = image["digest"]
        amd64 = next(
            entry["digest"]
            for entry in image["index_platforms"]  # type: ignore[index]
            if entry["platform"] == "linux/amd64"
        )
        if command[4:5] == ("--raw",) and ref.endswith(str(top)):
            payload = {
                "schemaVersion": 2,
                "mediaType": "application/vnd.oci.image.index.v1+json",
                "manifests": [
                    {
                        "mediaType": "application/vnd.oci.image.manifest.v1+json",
                        "digest": amd64,
                        "size": 1000,
                        "platform": {"os": "linux", "architecture": "amd64"},
                    },
                    {
                        "mediaType": "application/vnd.oci.image.manifest.v1+json",
                        "digest": digest(f"arm64-{service}"),
                        "size": 1001,
                        "platform": {"os": "linux", "architecture": "arm64"},
                    },
                ],
            }
            return CommandResult(0, json.dumps(payload))
        if command[4:5] == ("--raw",) and ref.endswith(str(amd64)):
            payload = {
                "schemaVersion": 2,
                "mediaType": "application/vnd.oci.image.manifest.v1+json",
                "config": {"digest": digest(f"config-{service}"), "size": 900},
                "layers": [{"digest": digest(f"layer-{service}"), "size": 1}],
            }
            return CommandResult(0, json.dumps(payload))
        if command[4:6] == ("--format", "{{json .Image}}"):
            payload = {
                "os": "linux",
                "architecture": "amd64",
                "config": {
                    "Labels": {
                        "org.opencontainers.image.source": f"https://github.com/{REPOSITORY}",
                        "org.opencontainers.image.revision": SOURCE_SHA,
                    }
                },
            }
            return CommandResult(0, json.dumps(payload))
        if command[4:] == (ref,):
            return CommandResult(0, f"Name: {ref}\nDigest: {top}\n")
        return CommandResult(1, "", "unexpected fixture command")


class I1CodespacesContractTests(unittest.TestCase):
    def test_manifest_binds_exact_release_source_and_six_services(self) -> None:
        binding = validate_published_manifest(
            published_manifest(),
            release_id=RELEASE_ID,
            source_sha=SOURCE_SHA,
            repository=REPOSITORY,
        )
        self.assertEqual(binding.namespace, NAMESPACE)
        self.assertEqual(set(binding.images), set(EXPECTED_APP_SERVICES))
        self.assertTrue(all("@sha256:" in image.digest_ref for image in binding.images.values()))

    def test_manifest_rejects_mutable_or_stale_tag_binding(self) -> None:
        manifest = published_manifest()
        manifest["images"][0]["tag"] = "latest"  # type: ignore[index]
        with self.assertRaisesRegex(ContractError, "exact candidate tag"):
            validate_published_manifest(
                manifest,
                release_id=RELEASE_ID,
                source_sha=SOURCE_SHA,
                repository=REPOSITORY,
            )

    def test_compose_environment_contains_only_public_binding_values(self) -> None:
        binding = validate_published_manifest(
            published_manifest(),
            release_id=RELEASE_ID,
            source_sha=SOURCE_SHA,
            repository=REPOSITORY,
        )
        values = build_compose_environment(binding, ingress_port=8080)
        self.assertEqual(values["I1_SOURCE_SHA"], SOURCE_SHA)
        self.assertEqual(values["I1_FRONTEND_DIGEST_HEX"], digest("top-frontend").split(":", 1)[1])
        self.assertFalse(any("TOKEN" in key or "SECRET" in key or "PASSWORD" in key for key in values))

    def test_runtime_snapshot_rejects_builds_and_app_bind_mounts(self) -> None:
        binding = validate_published_manifest(
            published_manifest(), release_id=RELEASE_ID, source_sha=SOURCE_SHA, repository=REPOSITORY
        )
        config = compose_config()
        config["services"]["agent-api"]["build"] = {"context": "."}  # type: ignore[index]
        with self.assertRaisesRegex(ContractError, "build"):
            validate_runtime_snapshot(binding, config, runtime_inspections(), hosting_provider="github_codespaces")

        config = compose_config()
        config["services"]["frontend"]["volumes"] = [  # type: ignore[index]
            {"type": "bind", "source": "/workspaces/repo", "target": "/app"}
        ]
        with self.assertRaisesRegex(ContractError, "bind mount"):
            validate_runtime_snapshot(binding, config, runtime_inspections(), hosting_provider="github_codespaces")

    def test_runtime_snapshot_records_exact_image_ids_and_oci_binding(self) -> None:
        binding = validate_published_manifest(
            published_manifest(), release_id=RELEASE_ID, source_sha=SOURCE_SHA, repository=REPOSITORY
        )
        proof = validate_runtime_snapshot(
            binding, compose_config(), runtime_inspections(), hosting_provider="github_codespaces"
        )
        self.assertEqual(proof["service_count"], 6)
        self.assertTrue(proof["compose_contract"]["digest_only_apps"])
        self.assertEqual(
            {entry["runtime_image_id"] for entry in proof["images"]},
            {digest(f"config-{service}") for service in EXPECTED_APP_SERVICES},
        )

    def test_registry_readback_checks_top_amd64_config_and_labels(self) -> None:
        binding = validate_published_manifest(
            published_manifest(), release_id=RELEASE_ID, source_sha=SOURCE_SHA, repository=REPOSITORY
        )
        runner = FakeRegistryRunner()
        observed = verify_registry_readback(binding, runner)
        self.assertEqual(len(observed), 6)
        self.assertEqual(observed["frontend"].config_digest, digest("config-frontend"))
        self.assertEqual(observed["frontend"].amd64_manifest_digest, digest("amd64-frontend"))
        self.assertTrue(all(call[:4] == ("docker", "buildx", "imagetools", "inspect") for call in runner.calls))

    def test_runtime_provenance_rejects_image_id_not_equal_to_config_digest(self) -> None:
        binding = validate_published_manifest(
            published_manifest(), release_id=RELEASE_ID, source_sha=SOURCE_SHA, repository=REPOSITORY
        )
        observed = verify_registry_readback(binding, FakeRegistryRunner())
        proof = runtime_provenance()
        proof["images"][0]["runtime_image_id"] = digest("wrong")  # type: ignore[index]
        with self.assertRaisesRegex(ContractError, "runtime image ID"):
            validate_runtime_provenance(binding, observed, proof)

    def test_runtime_provenance_accepts_exact_config_image_ids(self) -> None:
        binding = validate_published_manifest(
            published_manifest(), release_id=RELEASE_ID, source_sha=SOURCE_SHA, repository=REPOSITORY
        )
        observed = verify_registry_readback(binding, FakeRegistryRunner())
        validated = validate_runtime_provenance(binding, observed, runtime_provenance())
        self.assertEqual(len(validated), 6)
        self.assertTrue(all(item.runtime_image_id == item.config_digest for item in validated))

    def test_exclusive_evidence_writer_never_overwrites(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "evidence.json"
            write_json_exclusive(output, {"status": "verified"})
            with self.assertRaisesRegex(ContractError, "already exists"):
                write_json_exclusive(output, {"status": "changed"})
            self.assertEqual(json.loads(output.read_text(encoding="utf-8"))["status"], "verified")

    def test_repository_static_surface_is_digest_only_and_non_mutating(self) -> None:
        report = verify_static_files(REPO_ROOT)
        self.assertEqual(report["app_service_count"], 6)
        self.assertTrue(report["codespaces_primary"])
        self.assertTrue(report["named_tunnel_static_only"])
        self.assertTrue(report["workflow_read_only"])

    def test_static_verifier_command_entrypoint_succeeds(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "verify_i1_codespaces_static.py")],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("I1 Codespaces static verification passed", completed.stdout)


if __name__ == "__main__":
    unittest.main()
