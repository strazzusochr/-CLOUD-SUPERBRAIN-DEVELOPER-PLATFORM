from __future__ import annotations

import json
import sys
import tempfile
import unittest
from dataclasses import replace
from hashlib import sha256
from pathlib import Path
from typing import Sequence

sys.path.insert(0, str(Path(__file__).resolve().parent))

from verify_ghcr_candidate import (
    CommandResult,
    EXPECTED_SERVICES,
    VerificationConfig,
    VerificationError,
    WorkflowMetadata,
    verify_candidate,
    write_evidence_exclusive,
)


CANDIDATE_SHA = "a" * 40
CONTROL_SHA = "b" * 40
REPOSITORY = "example/cloud-superbrain"
NAMESPACE = "ghcr.io/example/cloud-superbrain"


def digest(label: str) -> str:
    return f"sha256:{sha256(label.encode('utf-8')).hexdigest()}"


class FakeRunner:
    def __init__(self, results: dict[tuple[str, ...], CommandResult]) -> None:
        self.results = results
        self.calls: list[tuple[str, ...]] = []

    def __call__(self, command: Sequence[str]) -> CommandResult:
        key = tuple(command)
        self.calls.append(key)
        return self.results.get(key, CommandResult(1, "", "fixture command unavailable"))


def valid_config(output: Path) -> VerificationConfig:
    return VerificationConfig(
        namespace=NAMESPACE,
        candidate_sha=CANDIDATE_SHA,
        control_sha=CONTROL_SHA,
        output=output,
        workflow=WorkflowMetadata(
            repository=REPOSITORY,
            workflow_name="Publish immutable candidate images",
            run_id="123456789",
            run_attempt=2,
            run_url=f"https://github.com/{REPOSITORY}/actions/runs/123456789",
            ref="refs/heads/main",
            head_sha=CONTROL_SHA,
            candidate_sha=CANDIDATE_SHA,
            event_name="workflow_dispatch",
        ),
    )


def make_results(
    *,
    stale_revision_service: str | None = None,
    missing_platform_service: str | None = None,
    wrong_platform_service: str | None = None,
    duplicate_digest_service: str | None = None,
    mutable_name_service: str | None = None,
    malformed_digest_service: str | None = None,
) -> dict[tuple[str, ...], CommandResult]:
    results: dict[tuple[str, ...], CommandResult] = {}
    first_digest = digest(f"top-{EXPECTED_SERVICES[0]}")
    for service in EXPECTED_SERVICES:
        image_ref = f"{NAMESPACE}/{service}:{CANDIDATE_SHA}"
        top_digest = digest(f"top-{service}")
        if service == duplicate_digest_service:
            top_digest = first_digest
        if service == malformed_digest_service:
            top_digest = "sha256:not-a-digest"
        inspected_name = f"{NAMESPACE}/{service}:latest" if service == mutable_name_service else image_ref
        descriptor_lines = (
            "Manifests:\n"
            f"  Name:      {NAMESPACE}/{service}@{digest(f'{service}-amd64')}\n"
            f"  Digest:    {digest(f'{service}-amd64')}\n"
            "  Platform:  linux/amd64\n"
            f"  Name:      {NAMESPACE}/{service}@{digest(f'{service}-arm64')}\n"
            f"  Digest:    {digest(f'{service}-arm64')}\n"
            "  Platform:  linux/arm64\n"
        )
        results[("docker", "buildx", "imagetools", "inspect", image_ref)] = CommandResult(
            0,
            f"Name: {inspected_name}\n"
            "MediaType: application/vnd.oci.image.index.v1+json\n"
            f"Digest: {top_digest}\n"
            f"{descriptor_lines}",
        )

        descriptors = [
            {
                "mediaType": "application/vnd.oci.image.manifest.v1+json",
                "digest": digest(f"{service}-amd64"),
                "size": 1024,
                "platform": {"os": "linux", "architecture": "amd64"},
            },
            {
                "mediaType": "application/vnd.oci.image.manifest.v1+json",
                "digest": digest(f"{service}-arm64"),
                "size": 1025,
                "platform": {"os": "linux", "architecture": "arm64"},
            },
        ]
        if service == missing_platform_service:
            descriptors = descriptors[:1]
        if service == wrong_platform_service:
            descriptors[1]["platform"] = {"os": "linux", "architecture": "arm", "variant": "v7"}
        raw_index = {
            "schemaVersion": 2,
            "mediaType": "application/vnd.oci.image.index.v1+json",
            "manifests": descriptors,
        }
        results[("docker", "buildx", "imagetools", "inspect", "--raw", image_ref)] = CommandResult(
            0, json.dumps(raw_index)
        )

        for descriptor in descriptors:
            platform = descriptor["platform"]
            platform_name = f"{platform['os']}/{platform['architecture']}"
            revision = "c" * 40 if service == stale_revision_service and platform_name == "linux/amd64" else CANDIDATE_SHA
            image_config = {
                "os": platform["os"],
                "architecture": platform["architecture"],
                "config": {
                    "Labels": {
                        "org.opencontainers.image.source": f"https://github.com/{REPOSITORY}",
                        "org.opencontainers.image.revision": revision,
                        "org.opencontainers.image.version": f"candidate-{CANDIDATE_SHA}",
                    }
                },
            }
            digest_ref = f"{NAMESPACE}/{service}@{descriptor['digest']}"
            results[
                (
                    "docker",
                    "buildx",
                    "imagetools",
                    "inspect",
                    "--format",
                    "{{json .Image}}",
                    digest_ref,
                )
            ] = CommandResult(0, json.dumps(image_config))
    return results


class GhcrCandidateVerifierTests(unittest.TestCase):
    def test_valid_six_image_candidate_and_exclusive_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            runner = FakeRunner(make_results())
            evidence = verify_candidate(valid_config(output), runner)
            write_evidence_exclusive(output, evidence)

            persisted = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(persisted["contract_version"], "ghcr-release-manifest-v1")
            self.assertTrue(persisted["publication_complete"])
            self.assertFalse(persisted["secret_output"])
            self.assertFalse(persisted["mutable_tag_fallback_used"])
            self.assertFalse(persisted["mutable_tag_absence_claimed"])
            self.assertEqual(persisted["candidate_sha"], CANDIDATE_SHA)
            self.assertEqual(persisted["control_sha"], CONTROL_SHA)
            self.assertEqual(persisted["workflow"]["head_sha"], CONTROL_SHA)
            self.assertEqual(len(persisted["images"]), 6)
            self.assertEqual(len({image["digest"] for image in persisted["images"]}), 6)
            self.assertEqual(len(runner.calls), 24)
            self.assertTrue(all(call[:4] == ("docker", "buildx", "imagetools", "inspect") for call in runner.calls))

            with self.assertRaisesRegex(VerificationError, "never overwritten"):
                write_evidence_exclusive(output, evidence)

    def test_malformed_candidate_sha_fails_before_inspection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            runner = FakeRunner(make_results())
            config = replace(valid_config(output), candidate_sha="A" * 40)
            with self.assertRaisesRegex(VerificationError, "candidate_sha"):
                verify_candidate(config, runner)
            self.assertEqual(runner.calls, [])
            self.assertFalse(output.exists())

    def test_stale_control_workflow_binding_fails_before_inspection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            base = valid_config(output)
            config = replace(base, workflow=replace(base.workflow, head_sha="c" * 40))
            runner = FakeRunner(make_results())
            with self.assertRaisesRegex(VerificationError, "does not bind control_sha"):
                verify_candidate(config, runner)
            self.assertEqual(runner.calls, [])

    def test_stale_candidate_workflow_binding_fails_before_inspection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            base = valid_config(output)
            config = replace(base, workflow=replace(base.workflow, candidate_sha="c" * 40))
            runner = FakeRunner(make_results())
            with self.assertRaisesRegex(VerificationError, "does not bind candidate_sha"):
                verify_candidate(config, runner)
            self.assertEqual(runner.calls, [])

    def test_stale_oci_revision_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(make_results(stale_revision_service="frontend"))
            with self.assertRaisesRegex(VerificationError, "OCI label org.opencontainers.image.revision mismatch"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_missing_platform_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(make_results(missing_platform_service="agent-api"))
            with self.assertRaisesRegex(VerificationError, "exactly two platform manifests"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_wrong_platform_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(make_results(wrong_platform_service="mcp-gateway"))
            with self.assertRaisesRegex(VerificationError, "unexpected platform"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_missing_unknown_and_duplicate_services_fail_before_inspection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = valid_config(Path(temporary) / "manifest.json")
            cases = (
                EXPECTED_SERVICES[:-1],
                EXPECTED_SERVICES[:-1] + ("unknown-service",),
                EXPECTED_SERVICES[:-1] + (EXPECTED_SERVICES[0],),
            )
            for services in cases:
                with self.subTest(services=services):
                    runner = FakeRunner(make_results())
                    with self.assertRaises(VerificationError):
                        verify_candidate(replace(base, services=services), runner)
                    self.assertEqual(runner.calls, [])

    def test_duplicate_top_digest_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(make_results(duplicate_digest_service="mcp-gateway"))
            with self.assertRaisesRegex(VerificationError, "duplicated across services"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_malformed_top_digest_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(make_results(malformed_digest_service="agent-api"))
            with self.assertRaisesRegex(VerificationError, "exactly one top digest"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_indented_descriptor_digest_cannot_replace_mutated_top_digest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            results = make_results()
            service = "agent-api"
            image_ref = f"{NAMESPACE}/{service}:{CANDIDATE_SHA}"
            results[("docker", "buildx", "imagetools", "inspect", image_ref)] = CommandResult(
                0,
                f"Name: {image_ref}\n"
                "MediaType: application/vnd.oci.image.index.v1+json\n"
                "Digest: sha256:mutated\n"
                "Manifests:\n"
                f"  Name:      {NAMESPACE}/{service}@{digest(f'{service}-amd64')}\n"
                f"  Digest:    {digest(f'{service}-amd64')}\n"
                "  Platform:  linux/amd64\n"
                f"  Name:      {NAMESPACE}/{service}@{digest(f'{service}-arm64')}\n"
                f"  Digest:    {digest(f'{service}-arm64')}\n"
                "  Platform:  linux/arm64\n",
            )
            runner = FakeRunner(results)
            with self.assertRaisesRegex(VerificationError, "exactly one top digest"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_mutable_tag_fallback_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(make_results(mutable_name_service="llm-gateway"))
            with self.assertRaisesRegex(VerificationError, "mutable or unexpected tag"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_unavailable_inspection_or_auth_fails_without_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            runner = FakeRunner({})
            with self.assertRaisesRegex(VerificationError, "authentication/registry inspection failed"):
                verify_candidate(valid_config(output), runner)
            self.assertFalse(output.exists())

    def test_missing_oci_labels_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            results = make_results()
            service = "agent-api"
            platform_digest = digest(f"{service}-amd64")
            digest_ref = f"{NAMESPACE}/{service}@{platform_digest}"
            results[
                (
                    "docker",
                    "buildx",
                    "imagetools",
                    "inspect",
                    "--format",
                    "{{json .Image}}",
                    digest_ref,
                )
            ] = CommandResult(0, json.dumps({"os": "linux", "architecture": "amd64", "config": {}}))
            runner = FakeRunner(results)
            with self.assertRaisesRegex(VerificationError, "OCI labels are unavailable"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)


if __name__ == "__main__":
    unittest.main()
