from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from copy import deepcopy
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
    build_parser,
    config_from_args,
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
        active_candidate_sha=CANDIDATE_SHA,
        active_release_id="prod-candidate-test-rc1",
        control_sha=CONTROL_SHA,
        output=output,
        active_truth_sha256="d" * 64,
        active_truth_control_sha256="e" * 64,
        workflow=WorkflowMetadata(
            repository=REPOSITORY,
            workflow_name="main-deploy",
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
    def test_cli_config_binds_clean_tracked_truth_to_control_sha(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(
                ["git", "config", "user.email", "test@example.invalid"], cwd=repo, check=True
            )
            subprocess.run(["git", "config", "user.name", "Verifier Test"], cwd=repo, check=True)
            (repo / "candidate.txt").write_text("candidate\n", encoding="utf-8")
            subprocess.run(["git", "add", "candidate.txt"], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "candidate"], cwd=repo, check=True)
            candidate_sha = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=repo, check=True, capture_output=True, text=True
            ).stdout.strip()

            truth_path = repo / "docs" / "runtime-state" / "source-qualification-control.json"
            truth_path.parent.mkdir(parents=True)
            truth_path.write_text(
                json.dumps(
                    {
                        "$schema": "../runtime-contracts/source-qualification-control.schema.json",
                        "contract_version": "source-qualification-control-v1",
                        "release_id": "prod-candidate-test-rc1",
                        "runtime_candidate_sha": candidate_sha,
                        "source_archive_sha256": "f" * 64,
                        "production_rollout_claimed": False,
                        "percentage_credit_awarded": 0,
                        "secret_output": False,
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            subprocess.run(["git", "add", truth_path.as_posix()], cwd=repo, check=True)
            subprocess.run(["git", "commit", "-q", "-m", "control truth"], cwd=repo, check=True)
            control_sha = subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=repo, check=True, capture_output=True, text=True
            ).stdout.strip()

            previous_cwd = Path.cwd()
            try:
                os.chdir(repo)
                args = build_parser().parse_args(
                    [
                        "--namespace",
                        NAMESPACE,
                        "--candidate-sha",
                        candidate_sha,
                        "--active-candidate-sha",
                        candidate_sha,
                        "--control-sha",
                        control_sha,
                        "--output",
                        str(repo / "readback.json"),
                        "--repository",
                        "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
                        "--workflow-name",
                        "main-deploy",
                        "--workflow-run-id",
                        "123456789",
                        "--workflow-run-attempt",
                        "1",
                        "--workflow-run-url",
                        "https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/123456789",
                        "--workflow-ref",
                        "refs/heads/chore/repo-bootstrap",
                        "--workflow-head-sha",
                        control_sha,
                        "--workflow-candidate-sha",
                        candidate_sha,
                        "--workflow-event-name",
                        "workflow_dispatch",
                    ]
                )
                config = config_from_args(args)
            finally:
                os.chdir(previous_cwd)

            self.assertEqual(config.candidate_sha, candidate_sha)
            self.assertEqual(config.control_sha, control_sha)
            self.assertEqual(config.active_release_id, "prod-candidate-test-rc1")

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
            self.assertEqual(
                persisted["active_release_candidate"]["source_commit_sha"], CANDIDATE_SHA
            )
            self.assertEqual(
                persisted["active_release_candidate"]["image_tag"], CANDIDATE_SHA
            )
            self.assertEqual(
                persisted["registry_readback"]["inspected_platform_manifest_count"], 12
            )
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

    def test_stale_active_candidate_binding_fails_before_inspection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            config = replace(valid_config(output), active_candidate_sha="c" * 40)
            runner = FakeRunner(make_results())
            with self.assertRaisesRegex(VerificationError, "active release-candidate SHA"):
                verify_candidate(config, runner)
            self.assertEqual(runner.calls, [])

    def test_tag_ref_and_non_dispatch_workflow_fail_before_inspection(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "manifest.json"
            base = valid_config(output)
            cases = (
                replace(base.workflow, ref="refs/tags/release"),
                replace(base.workflow, event_name="push"),
                replace(base.workflow, workflow_name="other-workflow"),
            )
            for workflow in cases:
                with self.subTest(workflow=workflow):
                    runner = FakeRunner(make_results())
                    with self.assertRaises(VerificationError):
                        verify_candidate(replace(base, workflow=workflow), runner)
                    self.assertEqual(runner.calls, [])

    def test_stale_oci_revision_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runner = FakeRunner(make_results(stale_revision_service="frontend"))
            with self.assertRaisesRegex(VerificationError, "OCI label org.opencontainers.image.revision mismatch"):
                verify_candidate(valid_config(Path(temporary) / "manifest.json"), runner)

    def test_published_manifest_digest_drift_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = valid_config(Path(temporary) / "manifest.json")
            baseline_runner = FakeRunner(make_results())
            baseline = verify_candidate(base, baseline_runner)

            drifted_results = make_results()
            service = "frontend"
            image_ref = f"{NAMESPACE}/{service}:{CANDIDATE_SHA}"
            new_digest = digest("retargeted-frontend-top")
            prior = drifted_results[("docker", "buildx", "imagetools", "inspect", image_ref)]
            drifted_results[("docker", "buildx", "imagetools", "inspect", image_ref)] = CommandResult(
                0,
                prior.stdout.replace(digest(f"top-{service}"), new_digest, 1),
            )
            config = replace(
                base,
                baseline_manifest=baseline,
                baseline_manifest_path="docs/release-artifacts/ghcr.json",
                baseline_manifest_sha256="f" * 64,
            )
            runner = FakeRunner(drifted_results)
            with self.assertRaisesRegex(VerificationError, "differs from the published"):
                verify_candidate(config, runner)

    def test_matching_published_manifest_is_bound_in_readback(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = valid_config(Path(temporary) / "manifest.json")
            baseline = verify_candidate(base, FakeRunner(make_results()))
            config = replace(
                base,
                baseline_manifest=baseline,
                baseline_manifest_path="docs/release-artifacts/ghcr.json",
                baseline_manifest_sha256="f" * 64,
            )
            evidence = verify_candidate(config, FakeRunner(make_results()))
            self.assertTrue(evidence["registry_readback"]["source_manifest_bound"])
            self.assertTrue(
                evidence["registry_readback"]["digest_readback_matches_publication"]
            )
            self.assertTrue(
                all(
                    platform["digest_ref"].endswith(platform["digest"])
                    for image in evidence["images"]
                    for platform in image["index_platforms"]
                )
            )

    def test_published_platform_digest_drift_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = valid_config(Path(temporary) / "manifest.json")
            baseline = deepcopy(verify_candidate(base, FakeRunner(make_results())))
            baseline["images"][0]["index_platforms"][0]["digest"] = digest(
                "retargeted-platform"
            )
            baseline["images"][0]["index_platforms"][0]["digest_ref"] = (
                f"{NAMESPACE}/{EXPECTED_SERVICES[0]}@{digest('retargeted-platform')}"
            )
            config = replace(
                base,
                baseline_manifest=baseline,
                baseline_manifest_path="docs/release-artifacts/ghcr.json",
                baseline_manifest_sha256="f" * 64,
            )
            with self.assertRaisesRegex(VerificationError, "differs from the published"):
                verify_candidate(config, FakeRunner(make_results()))

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
