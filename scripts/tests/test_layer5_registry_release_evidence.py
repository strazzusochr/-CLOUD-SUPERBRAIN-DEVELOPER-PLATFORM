from __future__ import annotations

import json
import sys
import tempfile
import unittest
from copy import deepcopy
from hashlib import sha256
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from build_layer5_registry_release_input import (  # noqa: E402
    VerificationError as AggregateVerificationError,
    build_layer5_registry_release_input,
    _validate_review,
)
from verify_layer5_registry_release_evidence import validate_layer5_registry_release_evidence
from collect_ghcr_publication_evidence import (  # noqa: E402
    VerificationError as PublicationVerificationError,
    build_publication_evidence,
)
from verify_ghcr_remote_scan import (  # noqa: E402
    TRIVY_BINARY_SHA256,
    TRIVY_VERSION,
    VerificationError as RemoteScanVerificationError,
    build_remote_scan_evidence,
    report_filename,
)


SERVICES = (
    "agent-api",
    "mcp-gateway",
    "frontend",
    "llm-gateway",
    "agent-worker",
    "memory-worker",
)
PLATFORMS = ("linux/amd64", "linux/arm64")
CANDIDATE_SHA = "a" * 40
CONTROL_SHA = "b" * 40
RELEASE_ID = "prod-candidate-test-rc1"
REPOSITORY = "example/cloud-superbrain"
NAMESPACE = "ghcr.io/example/cloud-superbrain"
RUN_ID = "123456789"
ARTIFACT_ID = "987654321"
ARTIFACT_DIGEST = "sha256:" + "c" * 64


def digest(label: str) -> str:
    return "sha256:" + sha256(label.encode("utf-8")).hexdigest()


def write_json(path: Path, value: object) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Keep fixture bytes platform-independent. Production evidence writers use
    # canonical LF-delimited UTF-8 bytes and the binding intentionally hashes
    # those exact bytes.
    path.write_bytes((json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8"))
    return path


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def make_manifest() -> dict[str, object]:
    images: list[dict[str, object]] = []
    for service in SERVICES:
        platform_entries: list[dict[str, object]] = []
        for platform in PLATFORMS:
            platform_digest = digest(f"{service}-{platform}")
            platform_entries.append(
                {
                    "platform": platform,
                    "digest": platform_digest,
                    "digest_ref": f"{NAMESPACE}/{service}@{platform_digest}",
                    "oci_labels": {
                        "org.opencontainers.image.source": f"https://github.com/{REPOSITORY}",
                        "org.opencontainers.image.revision": CANDIDATE_SHA,
                        "org.opencontainers.image.version": f"candidate-{CANDIDATE_SHA}",
                    },
                }
            )
        images.append(
            {
                "service": service,
                "tag": CANDIDATE_SHA,
                "image_ref": f"{NAMESPACE}/{service}:{CANDIDATE_SHA}",
                "digest": digest(f"top-{service}"),
                "index_platforms": platform_entries,
            }
        )
    return {
        "contract_version": "ghcr-release-manifest-v1",
        "status": "verified",
        "registry": "ghcr.io",
        "namespace": NAMESPACE,
        "candidate_sha": CANDIDATE_SHA,
        "control_sha": CONTROL_SHA,
        "active_release_candidate": {
            "release_id": RELEASE_ID,
            "source_commit_sha": CANDIDATE_SHA,
            "image_tag": CANDIDATE_SHA,
        },
        "service_count": 6,
        "services": list(SERVICES),
        "required_platforms": list(PLATFORMS),
        "unique_top_digest_count": 6,
        "workflow": {
            "repository": REPOSITORY,
            "name": "main-deploy",
            "run_id": RUN_ID,
            "run_attempt": 1,
            "run_url": f"https://github.com/{REPOSITORY}/actions/runs/{RUN_ID}",
            "ref": "refs/heads/chore/repo-bootstrap",
            "head_sha": CONTROL_SHA,
            "candidate_sha": CANDIDATE_SHA,
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
        "selected_tag_is_exact_candidate_sha": True,
        "mutable_tag_fallback_used": False,
        "registry_write_performed": False,
        "registry_delete_performed": False,
        "secret_output": False,
        "publication_complete": True,
    }


def write_scan_fixture(root: Path, *, secret: bool = False, severity: str | None = None) -> tuple[Path, Path, Path]:
    manifest_path = write_json(root / "ghcr-candidate-manifest.json", make_manifest())
    reports_dir = root / "trivy-reports"
    reports_dir.mkdir()
    first = True
    for image in make_manifest()["images"]:  # type: ignore[index]
        service = image["service"]  # type: ignore[index]
        for item in image["index_platforms"]:  # type: ignore[index]
            results: list[dict[str, object]] = []
            if first and (secret or severity):
                result: dict[str, object] = {"Target": "fixture", "Class": "os-pkgs", "Type": "debian"}
                if secret:
                    result["Secrets"] = [{"RuleID": "fixture-secret", "Severity": "CRITICAL"}]
                if severity:
                    result["Vulnerabilities"] = [{"VulnerabilityID": "CVE-FIXTURE", "Severity": severity}]
                results.append(result)
            first = False
            write_json(
                reports_dir / report_filename(service, item["platform"]),  # type: ignore[index]
                {
                    "SchemaVersion": 2,
                    "CreatedAt": "2026-09-02T10:00:00Z",
                    "ArtifactName": item["digest_ref"],  # type: ignore[index]
                    "ArtifactType": "container_image",
                    "Metadata": {"RepoDigests": [item["digest_ref"]]},  # type: ignore[index]
                    "Results": results,
                },
            )
    db_path = write_json(
        root / "trivy-db-metadata.json",
        {
            "Version": 2,
            "UpdatedAt": "2026-09-02T08:00:00Z",
            "NextUpdate": "2026-09-02T14:00:00Z",
            "DownloadedAt": "2026-09-02T09:59:00Z",
        },
    )
    return manifest_path, reports_dir, db_path


def make_run(*, actor: str = "dispatcher") -> dict[str, object]:
    return {
        "id": int(RUN_ID),
        "run_attempt": 1,
        "name": "main-deploy",
        "event": "workflow_dispatch",
        "status": "in_progress",
        "conclusion": None,
        "head_sha": CONTROL_SHA,
        "head_branch": "chore/repo-bootstrap",
        "html_url": f"https://github.com/{REPOSITORY}/actions/runs/{RUN_ID}",
        "actor": {"login": actor, "id": 10, "type": "User"},
        # GitHub's workflow-run REST response currently omits dispatch inputs.
        "inputs": None,
    }


def make_jobs(*, skip_service: str | None = None, preflight_conclusion: str = "success") -> dict[str, object]:
    jobs: list[dict[str, object]] = [
        {
            "id": 999,
            "run_id": int(RUN_ID),
            "name": "Bind control SHA to tracked candidate truth",
            "status": "completed",
            "conclusion": preflight_conclusion,
            "head_sha": CONTROL_SHA,
            "started_at": "2026-09-02T10:00:00Z",
            "completed_at": "2026-09-02T10:01:00Z",
            "steps": [
                {
                    "name": "Validate control branch and active candidate",
                    "status": "completed",
                    "conclusion": preflight_conclusion,
                    "started_at": "2026-09-02T10:00:10Z",
                    "completed_at": "2026-09-02T10:00:20Z",
                }
            ],
        }
    ]
    for index, service in enumerate(SERVICES, start=1):
        jobs.append(
            {
                "id": 1000 + index,
                "run_id": int(RUN_ID),
                "name": f"Publish immutable {service} candidate ({service})",
                "status": "completed",
                "conclusion": "success",
                "head_sha": CONTROL_SHA,
                "started_at": "2026-09-02T10:01:00Z",
                "completed_at": "2026-09-02T10:05:00Z",
                "steps": [
                    {
                        "name": "Build and push absent candidate tag once",
                        "status": "completed",
                        "conclusion": "skipped" if service == skip_service else "success",
                        "started_at": "2026-09-02T10:02:00Z",
                        "completed_at": "2026-09-02T10:04:00Z",
                    }
                ],
            }
        )
    return {"total_count": len(jobs), "jobs": jobs}


def make_approvals(*, environment: str = "registry-publication", reviewer: str = "release-owner") -> list[dict[str, object]]:
    return [
        {
            "state": "approved",
            "comment": "fixture comment is intentionally not persisted",
            "environments": [{"id": 44, "name": environment}],
            "user": {"login": reviewer, "id": 20, "node_id": "fixture-node", "type": "User"},
        }
    ]


def make_environment(*, prevent_self_review: bool = True, reviewer: str = "release-owner") -> dict[str, object]:
    return {
        "id": 44,
        "name": "registry-publication",
        "protection_rules": [
            {
                "id": 1,
                "type": "required_reviewers",
                "prevent_self_review": prevent_self_review,
                "reviewers": [
                    {
                        "type": "User",
                        "reviewer": {"login": reviewer, "id": 20, "type": "User"},
                    }
                ],
            }
        ],
        "deployment_branch_policy": {"protected_branches": True, "custom_branch_policies": False},
    }


def make_artifact() -> dict[str, object]:
    return {
        "id": int(ARTIFACT_ID),
        "name": f"ghcr-candidate-{CANDIDATE_SHA}-{RUN_ID}-1",
        "size_in_bytes": 4096,
        "expired": False,
        "digest": ARTIFACT_DIGEST,
        "archive_download_url": f"https://api.github.com/repos/{REPOSITORY}/actions/artifacts/{ARTIFACT_ID}/zip",
        "workflow_run": {"id": int(RUN_ID), "head_sha": CONTROL_SHA},
    }


def make_capability_gates() -> dict[str, object]:
    return {
        "contract_version": "capability-gate-state-v1",
        "gates": {
            "docker_registry_publish": {
                "owner_granted": True,
                "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O3:docker_registry_publish",
                "live_verified": False,
                "paid_provider": False,
            }
        },
    }


class Layer5RegistryReleaseEvidenceTests(unittest.TestCase):
    def test_remote_scan_requires_exact_twelve_clean_platform_reports(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest_path, reports_dir, db_path = write_scan_fixture(root)
            evidence = build_remote_scan_evidence(
                manifest_path,
                reports_dir,
                db_path,
                trivy_version=TRIVY_VERSION,
                trivy_binary_sha256=TRIVY_BINARY_SHA256,
            )
            self.assertEqual(evidence["scan_count"], 12)
            self.assertEqual(evidence["platform_digest_count"], 12)
            self.assertEqual(evidence["secret_findings"], 0)
            self.assertEqual(evidence["high_vulnerabilities"], 0)
            self.assertEqual(evidence["critical_vulnerabilities"], 0)
            self.assertTrue(evidence["credit_eligible"])

    def test_remote_scan_rejects_secret_high_critical_and_missing_report(self) -> None:
        for kwargs, expected in (
            ({"secret": True}, "secret"),
            ({"severity": "HIGH"}, "HIGH"),
            ({"severity": "CRITICAL"}, "CRITICAL"),
        ):
            with self.subTest(kwargs=kwargs), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                manifest_path, reports_dir, db_path = write_scan_fixture(root, **kwargs)
                with self.assertRaisesRegex(RemoteScanVerificationError, expected):
                    build_remote_scan_evidence(
                        manifest_path,
                        reports_dir,
                        db_path,
                        trivy_version=TRIVY_VERSION,
                        trivy_binary_sha256=TRIVY_BINARY_SHA256,
                    )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            manifest_path, reports_dir, db_path = write_scan_fixture(root)
            next(reports_dir.glob("*.json")).unlink()
            with self.assertRaisesRegex(RemoteScanVerificationError, "missing"):
                build_remote_scan_evidence(
                    manifest_path,
                    reports_dir,
                    db_path,
                    trivy_version=TRIVY_VERSION,
                    trivy_binary_sha256=TRIVY_BINARY_SHA256,
                )

    def _publication_inputs(self, root: Path) -> dict[str, Path | str]:
        manifest_path, reports_dir, db_path = write_scan_fixture(root)
        remote = build_remote_scan_evidence(
            manifest_path,
            reports_dir,
            db_path,
            trivy_version=TRIVY_VERSION,
            trivy_binary_sha256=TRIVY_BINARY_SHA256,
        )
        remote_path = write_json(root / "remote-image-scan.json", remote)
        return {
            "manifest_path": manifest_path,
            "remote_scan_path": remote_path,
            "run_path": write_json(root / "run.json", make_run()),
            "jobs_path": write_json(root / "jobs.json", make_jobs()),
            "approvals_path": write_json(root / "approvals.json", make_approvals()),
            "environment_path": write_json(root / "environment.json", make_environment()),
            "artifact_path": write_json(root / "artifact.json", make_artifact()),
            "capability_gates_path": write_json(root / "capability-gates.json", make_capability_gates()),
            "workflow_path": ROOT / ".github" / "workflows" / "main-deploy.yml",
            "expected_artifact_id": ARTIFACT_ID,
            "expected_artifact_digest": ARTIFACT_DIGEST,
        }

    def test_publication_collector_binds_real_review_six_pushes_and_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            inputs = self._publication_inputs(Path(temporary))
            review, registry = build_publication_evidence(**inputs)
            self.assertEqual(review["environment"], "registry-publication")
            self.assertEqual(review["review"]["state"], "approved")
            self.assertTrue(review["review"]["reviewer_distinct_from_triggering_actor"])
            self.assertEqual(review["publish_job_count"], 6)
            self.assertTrue(review["all_publish_steps_executed"])
            self.assertEqual(review["artifact"]["digest"], ARTIFACT_DIGEST)
            self.assertEqual(registry["top_digest_count"], 6)
            self.assertEqual(registry["platform_digest_count"], 12)
            self.assertTrue(registry["registry_publish_verified"])

    def test_owner_review_is_valid_when_environment_explicitly_allows_self_review(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            inputs = self._publication_inputs(root)
            inputs["run_path"] = write_json(root / "owner-run.json", make_run(actor="release-owner"))
            inputs["approvals_path"] = write_json(
                root / "owner-approval.json", make_approvals(reviewer="release-owner")
            )
            inputs["environment_path"] = write_json(
                root / "owner-environment.json",
                make_environment(prevent_self_review=False, reviewer="release-owner"),
            )
            review, registry = build_publication_evidence(**inputs)
            self.assertFalse(review["review"]["reviewer_distinct_from_triggering_actor"])
            self.assertFalse(review["review"]["prevent_self_review"])
            self.assertTrue(review["review"]["required_reviewers_configured"])
            self.assertTrue(registry["protected_publish_review_verified"])

    def test_publication_collector_rejects_static_or_incomplete_review_proof(self) -> None:
        cases: list[tuple[str, object, str]] = [
            ("approvals_path", [], "approved"),
            ("approvals_path", make_approvals(environment="production"), "registry-publication"),
            (
                "environment_path",
                make_environment(reviewer="different-release-owner"),
                "configured required reviewer",
            ),
            ("jobs_path", make_jobs(skip_service="frontend"), "push step"),
            ("jobs_path", make_jobs(preflight_conclusion="failure"), "candidate preflight"),
        ]
        for key, value, expected in cases:
            with self.subTest(key=key, expected=expected), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                inputs = self._publication_inputs(root)
                inputs[key] = write_json(root / f"bad-{key}.json", value)
                with self.assertRaisesRegex(PublicationVerificationError, expected):
                    build_publication_evidence(**inputs)

    def test_credit_requires_distinct_reviewer_even_when_environment_allows_self_review(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            inputs = self._publication_inputs(Path(temporary))
            review, _ = build_publication_evidence(**inputs)
            # Environment policy and credit eligibility are separate contracts.
            review["review"]["prevent_self_review"] = False
            _validate_review(review, RELEASE_ID, CANDIDATE_SHA, CONTROL_SHA)
            cases = (
                (False, "dispatcher", "release-owner"),
                (True, "release-owner", "release-owner"),
                (True, "RELEASE-OWNER", "release-owner"),
                (True, None, "release-owner"),
                (True, "", "release-owner"),
                (True, "dispatcher", ""),
                (1, "dispatcher", "release-owner"),
                ("true", "dispatcher", "release-owner"),
            )
            for distinct, actor, reviewer in cases:
                with self.subTest(distinct=distinct, actor=actor, reviewer=reviewer):
                    bad = deepcopy(review)
                    bad["review"]["reviewer_distinct_from_triggering_actor"] = distinct
                    bad["workflow"]["triggering_actor"] = actor
                    bad["review"]["reviewer"]["login"] = reviewer
                    with self.assertRaises(AggregateVerificationError):
                        _validate_review(bad, RELEASE_ID, CANDIDATE_SHA, CONTROL_SHA)

    def test_layer5_input_is_exact_four_criterion_fourteen_point_transition(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            inputs = self._publication_inputs(root)
            review, registry = build_publication_evidence(**inputs)
            registry_path = write_json(root / "candidate-registry-digests.json", registry)
            review_path = write_json(root / "registry-publication-review.json", review)
            sbom_images = []
            for image in registry["images"]:
                sbom_path = root / f"{image['service']}.cdx.json"
                write_json(sbom_path, {"bomFormat": "CycloneDX", "specVersion": "1.6", "components": [{"name": image["service"]}]})
                sbom_images.append(
                    {
                        "service": image["service"],
                        "registry_digest": image["digest"],
                        "immutable_registry_reference": image["immutable_reference"],
                        "remote_scan_sha256": image["remote_scan"]["report_sha256"],
                        "sbom_path": sbom_path.name,
                        "sbom_sha256": file_sha(sbom_path),
                        "bom_format": "CycloneDX",
                    }
                )
            sbom_path = write_json(
                root / "candidate-sbom-report.json",
                {
                    "contract_version": "mcp-candidate-sbom-evidence-v2",
                    "status": "verified",
                    "release_id": RELEASE_ID,
                    "source_commit_sha": CANDIDATE_SHA,
                    "service_count": 6,
                    "sbom_count": 6,
                    "sbom_format": "CycloneDX JSON",
                    "syft_version": "1.51.0",
                    "syft_binary_sha256": "75adfff66c266adac51fe8addeca97702f82b4d822d02bf70b79f556c84d3a46",
                    "images": sbom_images,
                    "immutable_registry_digests_bound": True,
                    "credit_eligible": True,
                    "registry_publish_performed": False,
                    "provider_writes": False,
                    "production_deploy": False,
                    "secret_output": False,
                },
            )
            aggregate = build_layer5_registry_release_input(
                inputs["manifest_path"],
                registry_path,
                inputs["remote_scan_path"],
                sbom_path,
                review_path,
            )
            self.assertEqual((aggregate["old_percent"], aggregate["new_percent"]), (86, 100))
            self.assertEqual(aggregate["points_awarded"], 14)
            self.assertEqual(
                [(item["id"], item["points"]) for item in aggregate["criteria"]],
                [
                    ("immutable_registry_digests", 3),
                    ("candidate_sbom", 3),
                    ("remote_image_scan", 2),
                    ("protected_publish", 6),
                ],
            )
            self.assertTrue(aggregate["credit_eligible"])

            aggregate_path = write_json(root / "layer5-registry-release-credit-evidence.json", aggregate)
            validate_layer5_registry_release_evidence(
                aggregate_path, expected_release_id=RELEASE_ID,
                expected_source_sha=CANDIDATE_SHA, expected_control_sha=CONTROL_SHA,
            )
            # Reproduce the RC38 bug with fully rebound hashes, not a hash error:
            # the raw receipt says self-review, while the old projection says true.
            original_review = deepcopy(review)
            original_registry = deepcopy(registry)
            review["review"]["prevent_self_review"] = False
            review["review"]["reviewer_distinct_from_triggering_actor"] = False
            review["workflow"]["triggering_actor"] = review["review"]["reviewer"]["login"]
            write_json(review_path, review)
            registry["publication_review"]["sha256"] = file_sha(review_path)
            write_json(registry_path, registry)
            forged = deepcopy(aggregate)
            forged["artifacts"]["registry_publication_review"]["sha256"] = file_sha(review_path)
            forged["artifacts"]["candidate_registry_digests"]["sha256"] = file_sha(registry_path)
            forged["criteria"][3]["evidence_sha256"] = file_sha(review_path)
            write_json(aggregate_path, forged)
            with self.assertRaisesRegex(AggregateVerificationError, "reviewer separation"):
                validate_layer5_registry_release_evidence(
                    aggregate_path, expected_release_id=RELEASE_ID,
                    expected_source_sha=CANDIDATE_SHA, expected_control_sha=CONTROL_SHA,
                )
            write_json(review_path, original_review)
            write_json(registry_path, original_registry)

            bad_sbom = deepcopy(json.loads(sbom_path.read_text(encoding="utf-8")))
            bad_sbom["sbom_count"] = 5
            bad_path = write_json(root / "bad-sbom.json", bad_sbom)
            with self.assertRaisesRegex(AggregateVerificationError, "sbom"):
                build_layer5_registry_release_input(
                    inputs["manifest_path"],
                    registry_path,
                    inputs["remote_scan_path"],
                    bad_path,
                    review_path,
                )


if __name__ == "__main__":
    unittest.main()
