from __future__ import annotations

import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import progress_credit_scorer_common as common  # noqa: E402
import score_layer5_registry_release_credit as l5  # noqa: E402
import score_phase3_oauth_credit as p3  # noqa: E402
import score_phase5_market_ready_credit as p5  # noqa: E402


CANDIDATE = "a" * 40
CONTROL = "b" * 40
EVIDENCE = "c" * 40
RELEASE = "prod-candidate-2026-09-02-local-rc99"
SERVICES = tuple(sorted(l5.EXPECTED_SERVICES))


def encoded(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def digest(value: object) -> str:
    return hashlib.sha256(encoded(value)).hexdigest()


def sha(label: str) -> str:
    return hashlib.sha256(label.encode("utf-8")).hexdigest()


def candidate_pointer() -> dict[str, object]:
    return {
        "active_release_id": RELEASE,
        "source_commit_sha": CANDIDATE,
        "production_rollout_claimed": False,
    }


def request(command: str, cell: str, old: int, new: int, path: str, payload: dict[str, object]) -> dict[str, object]:
    return {
        "contract_version": common.REQUEST_CONTRACT,
        "verifier_command": command,
        "scope": "vertical" if cell.startswith("layer_") else "horizontal",
        "cell_id": cell,
        "source_sha": EVIDENCE,
        "artifact_path": path,
        "artifact_sha256": digest(payload),
        "old_percent": old,
        "new_percent": new,
        "overall_percent": 100 if cell == "phase_5" else 89,
        "previous_projection_sha256": "d" * 64,
        "projection_sha256": "e" * 64,
        "read_only_required": True,
        "provider_writes_allowed": False,
        "secret_output_allowed": False,
    }


class BlobStore:
    def __init__(self, values: dict[str, object]) -> None:
        self.values = values

    def load(self, source: str, path: str) -> bytes:
        if source != EVIDENCE or path not in self.values:
            raise common.ScoreError(f"missing fixture blob: {path}")
        value = self.values[path]
        return value if isinstance(value, bytes) else encoded(value)


def l5_fixture() -> tuple[dict[str, object], BlobStore, dict[str, object]]:
    aggregate_path = f"docs/release-artifacts/{RELEASE}-evidence/registry/layer5-registry-release-credit-evidence.json"
    root = aggregate_path.rsplit("/", 1)[0]
    images = []
    for service in SERVICES:
        images.append(
            {
                "service": service,
                "digest": f"sha256:{sha(service + '-top')}",
                "index_platforms": [
                    {"platform": "linux/amd64", "digest": f"sha256:{sha(service + '-amd64')}"},
                    {"platform": "linux/arm64", "digest": f"sha256:{sha(service + '-arm64')}"},
                ],
            }
        )
    manifest = {
        "contract_version": l5.ARTIFACT_CONTRACTS["ghcr_manifest"],
        "status": "verified",
        "candidate_sha": CANDIDATE,
        "control_sha": CONTROL,
        "active_release_candidate": {"release_id": RELEASE, "source_commit_sha": CANDIDATE},
        "service_count": 6,
        "services": list(SERVICES),
        "unique_top_digest_count": 6,
        "publication_complete": True,
        "inspection_read_only": True,
        "registry_write_performed": False,
        "images": images,
    }
    remote = {
        "contract_version": l5.ARTIFACT_CONTRACTS["remote_image_scan"],
        "status": "verified",
        "credit_eligible": True,
        "release_id": RELEASE,
        "source_commit_sha": CANDIDATE,
        "control_commit_sha": CONTROL,
        "scan_count": 12,
        "secret_findings": 0,
        "high_vulnerabilities": 0,
        "critical_vulnerabilities": 0,
        "registry_write_performed": False,
        "secret_output": False,
    }
    review = {
        "contract_version": l5.ARTIFACT_CONTRACTS["registry_publication_review"],
        "status": "verified",
        "release_id": RELEASE,
        "source_commit_sha": CANDIDATE,
        "control_commit_sha": CONTROL,
        "environment": "registry-publication",
        "publish_job_count": 6,
        "all_publish_jobs_successful": True,
        "all_publish_steps_executed": True,
        "approval_required_before_publish_jobs": True,
        "workflow": {"event": "workflow_dispatch", "run_attempt": 1, "triggering_actor": "dispatcher"},
        "review": {"state": "approved", "reviewer_distinct_from_triggering_actor": True,
                   "reviewer": {"login": "release-owner", "type": "User"}},
        "production_deploy": False,
        "release_promotion": False,
        "provider_writes": False,
        "secret_output": False,
    }
    sbom = {
        "contract_version": l5.ARTIFACT_CONTRACTS["candidate_sbom"],
        "status": "verified",
        "credit_eligible": True,
        "release_id": RELEASE,
        "source_commit_sha": CANDIDATE,
        "service_count": 6,
        "sbom_count": 6,
        "immutable_registry_digests_bound": True,
        "secret_output": False,
    }
    refs = {
        "ghcr_manifest": {"contract_version": l5.ARTIFACT_CONTRACTS["ghcr_manifest"], "path": "ghcr-candidate-manifest.json", "sha256": digest(manifest)},
        "remote_image_scan": {"contract_version": l5.ARTIFACT_CONTRACTS["remote_image_scan"], "path": "remote-image-scan.json", "sha256": digest(remote)},
        "candidate_sbom": {"contract_version": l5.ARTIFACT_CONTRACTS["candidate_sbom"], "path": "candidate-sbom-report.json", "sha256": digest(sbom)},
        "registry_publication_review": {"contract_version": l5.ARTIFACT_CONTRACTS["registry_publication_review"], "path": "registry-publication-review.json", "sha256": digest(review)},
    }
    registry = {
        "contract_version": l5.ARTIFACT_CONTRACTS["candidate_registry_digests"],
        "status": "verified",
        "release_id": RELEASE,
        "source_commit_sha": CANDIDATE,
        "control_commit_sha": CONTROL,
        "service_count": 6,
        "top_digest_count": 6,
        "platform_digest_count": 12,
        "registry_publish_verified": True,
        "remote_scan_verified": True,
        "protected_publish_review_verified": True,
        "mutable_reference_used": False,
        "ghcr_manifest": {"sha256": refs["ghcr_manifest"]["sha256"]},
        "remote_image_scan": {"sha256": refs["remote_image_scan"]["sha256"]},
        "publication_review": {"sha256": refs["registry_publication_review"]["sha256"]},
    }
    refs["candidate_registry_digests"] = {
        "contract_version": l5.ARTIFACT_CONTRACTS["candidate_registry_digests"],
        "path": "candidate-registry-digests.json",
        "sha256": digest(registry),
    }
    expected = {
        "immutable_registry_digests": (3, refs["ghcr_manifest"]["sha256"]),
        "candidate_sbom": (3, refs["candidate_sbom"]["sha256"]),
        "remote_image_scan": (2, refs["remote_image_scan"]["sha256"]),
        "protected_publish": (6, refs["registry_publication_review"]["sha256"]),
    }
    aggregate: dict[str, object] = {
        "contract_version": l5.AGGREGATE_CONTRACT,
        "status": "verified",
        "scope": "vertical",
        "cell_id": "layer_5",
        "old_percent": 86,
        "new_percent": 100,
        "points_awarded": 14,
        "credit_eligible": True,
        "release_id": RELEASE,
        "source_commit_sha": CANDIDATE,
        "control_commit_sha": CONTROL,
        "criteria": [
            {"id": key, "points": value[0], "status": "verified", "evidence_sha256": value[1]}
            for key, value in expected.items()
        ],
        "artifacts": refs,
        "registry_publish_performed": True,
        "production_deploy": False,
        "release_promotion": False,
        "provider_writes": False,
        "secret_output": False,
    }
    values: dict[str, object] = {
        aggregate_path: aggregate,
        common.CURRENT_CANDIDATE_PATH: candidate_pointer(),
        f"{root}/ghcr-candidate-manifest.json": manifest,
        f"{root}/candidate-registry-digests.json": registry,
        f"{root}/remote-image-scan.json": remote,
        f"{root}/candidate-sbom-report.json": sbom,
        f"{root}/registry-publication-review.json": review,
    }
    gate = {
        "contract_version": "capability-gate-state-v1",
        "gates": {
            "docker_registry_publish": {
                "owner_granted": True,
                "live_verified": True,
                "provider": "ghcr",
                "paid_provider": False,
                "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O3",
                "verifier": l5.GATE_VERIFIER,
                "evidence_artifact": aggregate_path,
                "evidence_sha256": digest(aggregate),
            }
        },
    }
    values[l5.GATE_PATH] = gate
    return aggregate, BlobStore(values), request(l5.SCORER_COMMAND, "layer_5", 86, 100, aggregate_path, aggregate)


def p5_fixture() -> tuple[dict[str, object], BlobStore, dict[str, object]]:
    aggregate_path = f"docs/release-artifacts/{RELEASE}-evidence/phase5/phase5-market-ready-credit-evidence.json"
    i1_path = f"docs/release-artifacts/{RELEASE}-evidence/i1/i1-hosted-candidate-parity.json"
    auth_path = f"docs/release-artifacts/{RELEASE}-evidence/oauth/production-auth-identity.json"
    i1_images = [
        {
            "service": service,
            "top_digest": f"sha256:{sha(service + '-top')}",
            "amd64_manifest_digest": f"sha256:{sha(service + '-amd')}",
            "config_digest": f"sha256:{sha(service + '-config')}",
            "runtime_image_id": f"sha256:{sha(service + '-config')}",
            "oci_revision": CANDIDATE,
            "source_bind_mount_count": 0,
            "running": True,
            "healthy": True,
        }
        for service in sorted(p5.EXPECTED_SERVICES)
    ]
    i1 = {
        "contract_version": p5.I1_CONTRACT,
        "status": "verified",
        "release_id": RELEASE,
        "source_commit_sha": CANDIDATE,
        "base_url": "https://example-8080.app.github.dev",
        "hosting": {"provider": "github_codespaces"},
        "service_count": 6,
        "images": i1_images,
        "registry_digest_readback_verified": True,
        "runtime_image_identity_verified": True,
        "oci_source_revision_verified": True,
        "same_origin_https_verified": True,
        "sse_verified": True,
        "digest_only_compose_verified": True,
        "source_bind_mounts_absent": True,
        "builds_absent": True,
        "live_provider_calls": False,
        "registry_write_performed": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }
    auth: dict[str, object] = {
        "contract_version": p5.AUTH_CONTRACT,
        "status": "verified",
        "oauth_scope": "read:user",
        "human_flow_verified_steps": [
            "anonymous_login_no_identity", "github_start_exact_query", "github_cancel_no_credentials",
            "github_authorize_owner_identity", "callback_one_time_state", "auth_me_verified_identity",
            "reload_session_continuity", "refresh_atomic_rotation", "old_refresh_replay_rejected",
            "callback_replay_rejected", "logout_revocation_audited", "post_logout_refresh_rejected",
        ],
        "source_binding": {
            "source_commit_sha": CANDIDATE,
            "frontend_source_commit_sha": CANDIDATE,
            "auth_runtime_source_commit_sha": CANDIDATE,
            "immutable_frontend_deployment_verified": True,
            "immutable_auth_runtime_deployment_verified": True,
            "callback_origin": "https://frontend.example.vercel.app",
            "callback_url": "https://frontend.example.vercel.app/api/v1/auth/callback",
        },
    }
    auth.update({key: True for key in p5.AUTH_TRUE_FIELDS})
    auth.update({key: False for key in p5.AUTH_FALSE_FIELDS})
    capability_path = "docs/runtime-state/capability-gates.json"
    capability = {
        "contract_version": p5.CAPABILITY_CONTRACT,
        "gates": {
            "production_auth_identity": {
                "owner_granted": True,
                "live_verified": True,
                "paid_provider": False,
                "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O1",
                "verifier": p5.AUTH_VERIFIER,
                "evidence_artifact": auth_path,
                "evidence_sha256": digest(auth),
            }
        },
    }
    refs = {
        "hosted_candidate_parity": {"contract_version": p5.I1_CONTRACT, "path": i1_path, "sha256": digest(i1)},
        "production_auth_identity": {"contract_version": p5.AUTH_CONTRACT, "path": auth_path, "sha256": digest(auth)},
        "capability_gates": {"contract_version": p5.CAPABILITY_CONTRACT, "path": capability_path, "sha256": digest(capability)},
    }
    aggregate: dict[str, object] = {
        "contract_version": p5.AGGREGATE_CONTRACT,
        "status": "verified",
        "scope": "horizontal",
        "cell_id": "phase_5",
        "old_percent": 89,
        "new_percent": 100,
        "percent_delta": 11,
        "credit_eligible": True,
        "release_id": RELEASE,
        "candidate_source_commit_sha": CANDIDATE,
        "verified_item_ids": ["I1", "I5"],
        "evidence": refs,
        "claims": {"hosted_candidate_parity_verified": True, "production_auth_identity_verified": True, "verified_item_count": 2},
        "live_provider_calls_verified": True,
        "provider_writes": False,
        "registry_write_performed": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }
    values = {
        aggregate_path: aggregate,
        common.CURRENT_CANDIDATE_PATH: candidate_pointer(),
        i1_path: i1,
        auth_path: auth,
        capability_path: capability,
    }
    return aggregate, BlobStore(values), request(p5.SCORER_COMMAND, "phase_5", 89, 100, aggregate_path, aggregate)


def p3_fixture() -> tuple[dict[str, object], BlobStore, dict[str, object]]:
    aggregate_path = f"docs/release-artifacts/{RELEASE}-evidence/oauth/phase3-oauth-credit-evidence.json"
    flow_path = f"docs/release-artifacts/{RELEASE}-evidence/oauth/cloudflare-oauth-flow.json"
    auth_path = f"docs/release-artifacts/{RELEASE}-evidence/oauth/production-auth-identity.json"
    capability_path = "docs/runtime-state/capability-gates.json"
    session_a = sha("p3-session-a")
    session_b = sha("p3-session-b")
    steps = []
    for index, (name, status) in enumerate(zip(p3.STEP_NAMES, p3.STEP_STATUSES), start=1):
        if index <= 4:
            session = None
        elif index <= 10:
            session = session_a
        else:
            session = session_b
        steps.append(
            {
                "sequence": index,
                "name": name,
                "http_status": status,
                "human_click_count": 1,
                "secret_value_count": 0,
                "request_correlation_sha256": sha(f"p3-request-{index}"),
                "session_correlation_sha256": session,
            }
        )
    flow = {
        "contract_version": p3.FLOW_CONTRACT,
        "status": "evidence_envelope_complete",
        "architecture": "cloudflare_native",
        "source_binding": {
            "candidate_source_commit_sha": CANDIDATE,
            "frontend_source_commit_sha": CANDIDATE,
            "worker_source_commit_sha": CANDIDATE,
            "worker_source_archive_sha256": sha("worker-archive"),
            "frontend_origin": "https://frontend.example.vercel.app",
            "worker_origin": "https://worker.example.workers.dev",
            "callback_url": "https://frontend.example.vercel.app/api/v1/auth/callback",
        },
        "execution": {
            "target": "production",
            "transport": "hosted_https",
            "browser_execution": "real_chrome",
            "human_click_count": 12,
            "oauth_scope": "read:user",
            "provider_call_count": 2,
            "provider_write_count": 0,
            "deployment_write_count": 0,
            "localhost_transport_count": 0,
        },
        "human_flow_steps": steps,
        "token_families": {
            "contract_version": "cloudflare-oauth-token-families-v1",
            "distinct_family_count": 2,
            "distinct_family_ids_verified": True,
            "secret_value_count": 0,
            "families": [
                {
                    "label": "family_a",
                    "purpose": "refresh_replay",
                    "family_id_sha256": sha("p3-family-a"),
                    "session_correlation_sha256": session_a,
                    "credential_issue_after_terminal_count": 0,
                },
                {
                    "label": "family_b",
                    "purpose": "logout",
                    "family_id_sha256": sha("p3-family-b"),
                    "session_correlation_sha256": session_b,
                    "credential_issue_after_terminal_count": 0,
                },
            ],
        },
        "atomic_replay_evidence": {
            "parallel_attempt_count": 2,
            "successful_rotation_count": 1,
            "rejected_rotation_count": 1,
            "old_refresh_replay_http_status": 401,
            "callback_replay_http_status": 401,
            "family_revocation_row_count": 1,
            "replacement_refresh_rejection_count": 1,
            "callback_state_consumption_count": 1,
            "cancel_state_consumption_count": 1,
            "callback_replay_credential_issue_count": 0,
            "secret_value_count": 0,
        },
        "audit_correlations": [
            {
                "step": step_name,
                "event_type": event_type,
                "persisted_row_count": 1,
                "d1_readback_match_count": 1,
                "persisted_sequence": 1,
                "credential_boundary_sequence": 2,
                "sensitive_field_count": 0,
                "secret_value_count": 0,
            }
            for step_name, event_type in p3.AUDIT_EVENTS
        ],
        "redaction": {
            "identity_representation": "sha256_only",
            "sensitive_key_count": 0,
            "sensitive_value_count": 0,
            "log_scan_finding_count": 0,
            "secret_scan_finding_count": 0,
        },
        "gate_transition": {
            "verifier_mutation_count": 0,
            "gate_promotion_count": 0,
            "live_verified_mutation_count": 0,
            "percentage_change_count": 0,
        },
    }
    _, p5_store, _ = p5_fixture()
    auth = copy.deepcopy(p5_store.values[f"docs/release-artifacts/{RELEASE}-evidence/oauth/production-auth-identity.json"])
    capability = {
        "contract_version": p3.CAPABILITY_CONTRACT,
        "gates": {
            "production_auth_identity": {
                "owner_granted": True,
                "live_verified": True,
                "paid_provider": False,
                "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O1",
                "verifier": p3.AUTH_VERIFIER_PATH,
                "evidence_artifact": auth_path,
                "evidence_sha256": digest(auth),
            }
        },
    }
    raw_verifier = b"# immutable phase3 raw verifier fixture\n"
    evidence = {
        "flow": {"contract_version": p3.FLOW_CONTRACT, "path": flow_path, "sha256": digest(flow)},
        "production_auth_identity": {"contract_version": p3.AUTH_CONTRACT, "path": auth_path, "sha256": digest(auth)},
        "capability_gates": {"contract_version": p3.CAPABILITY_CONTRACT, "path": capability_path, "sha256": digest(capability)},
        "raw_verifier": {"path": p3.RAW_VERIFIER_PATH, "sha256": hashlib.sha256(raw_verifier).hexdigest()},
    }
    aggregate: dict[str, object] = {
        "contract_version": p3.AGGREGATE_CONTRACT,
        "status": "verified",
        "scope": "horizontal",
        "cell_id": "phase_3",
        "old_percent": 44,
        "new_percent": 100,
        "points_awarded": 56,
        "credit_eligible": True,
        "release_id": RELEASE,
        "candidate_source_commit_sha": CANDIDATE,
        "criteria": [
            {"id": criterion_id, "points": points, "status": "verified"}
            for criterion_id, points in p3.CRITERIA.items()
        ],
        "evidence": evidence,
        "live_github_oauth_calls": 2,
        "provider_writes": False,
        "production_deploy": False,
        "release_promotion": False,
        "secret_output": False,
    }
    values = {
        aggregate_path: aggregate,
        common.CURRENT_CANDIDATE_PATH: candidate_pointer(),
        flow_path: flow,
        auth_path: auth,
        capability_path: capability,
        p3.RAW_VERIFIER_PATH: raw_verifier,
    }
    return aggregate, BlobStore(values), request(p3.SCORER_COMMAND, "phase_3", 44, 100, aggregate_path, aggregate)


class NewProgressCreditScorerTests(unittest.TestCase):
    def test_phase3_scorer_accepts_exact_oauth_transition(self) -> None:
        _, store, req = p3_fixture()
        result = p3.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)
        self.assertTrue(result["credit_allowed"])
        self.assertEqual((result["old_percent"], result["new_percent"]), (44, 100))

    def test_phase3_scorer_rejects_token_family_alias(self) -> None:
        aggregate, store, req = p3_fixture()
        flow_ref = aggregate["evidence"]["flow"]  # type: ignore[index]
        flow = copy.deepcopy(store.values[flow_ref["path"]])
        flow["token_families"]["families"][1]["family_id_sha256"] = flow["token_families"]["families"][0]["family_id_sha256"]  # type: ignore[index]
        store.values[flow_ref["path"]] = flow
        flow_ref["sha256"] = digest(flow)
        req["artifact_sha256"] = digest(aggregate)
        with self.assertRaisesRegex(common.ScoreError, "identity hashes are not distinct"):
            p3.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)

    def test_phase3_scorer_rejects_frontend_outside_evidence_lineage(self) -> None:
        frontend_source = "f" * 40
        aggregate, store, req = p3_fixture()
        flow_ref = aggregate["evidence"]["flow"]  # type: ignore[index]
        auth_ref = aggregate["evidence"]["production_auth_identity"]  # type: ignore[index]
        capability_ref = aggregate["evidence"]["capability_gates"]  # type: ignore[index]
        flow = copy.deepcopy(store.values[flow_ref["path"]])
        auth = copy.deepcopy(store.values[auth_ref["path"]])
        capability = copy.deepcopy(store.values[capability_ref["path"]])
        flow["source_binding"]["frontend_source_commit_sha"] = frontend_source  # type: ignore[index]
        auth["source_binding"]["frontend_source_commit_sha"] = frontend_source  # type: ignore[index]
        capability["gates"]["production_auth_identity"]["evidence_sha256"] = digest(auth)  # type: ignore[index]
        store.values[flow_ref["path"]] = flow
        store.values[auth_ref["path"]] = auth
        store.values[capability_ref["path"]] = capability
        flow_ref["sha256"] = digest(flow)
        auth_ref["sha256"] = digest(auth)
        capability_ref["sha256"] = digest(capability)
        req["artifact_sha256"] = digest(aggregate)
        with self.assertRaisesRegex(
            common.ScoreError, "OAuth frontend source is not an ancestor of the evidence source"
        ):
            p3.score_request(
                req,
                load_blob=store.load,
                is_ancestor=lambda older, _newer: older != frontend_source,
            )

    def test_layer5_registry_scorer_accepts_exact_bound_transition(self) -> None:
        _, store, req = l5_fixture()
        result = l5.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)
        self.assertTrue(result["credit_allowed"])
        self.assertEqual((result["old_percent"], result["new_percent"]), (86, 100))

    def test_layer5_registry_scorer_rejects_unpromoted_gate(self) -> None:
        _, store, req = l5_fixture()
        store.values[l5.GATE_PATH]["gates"]["docker_registry_publish"]["live_verified"] = False  # type: ignore[index]
        with self.assertRaisesRegex(common.ScoreError, "gate is not promoted"):
            l5.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)

    def test_layer5_registry_scorer_rejects_self_review_with_rebound_hashes(self) -> None:
        for distinct, actor in ((False, "release-owner"), (True, "RELEASE-OWNER"), (True, None)):
            with self.subTest(distinct=distinct, actor=actor):
                aggregate, store, req = l5_fixture()
                refs = aggregate["artifacts"]
                parent = str(Path(req["artifact_path"]).parent).replace("\\", "/")
                review_path = parent + "/" + refs["registry_publication_review"]["path"]
                registry_path = parent + "/" + refs["candidate_registry_digests"]["path"]
                review = store.values[review_path]
                review["review"]["reviewer_distinct_from_triggering_actor"] = distinct
                review["workflow"]["triggering_actor"] = actor
                refs["registry_publication_review"]["sha256"] = digest(review)
                registry = store.values[registry_path]
                registry["publication_review"]["sha256"] = digest(review)
                refs["candidate_registry_digests"]["sha256"] = digest(registry)
                aggregate["criteria"][3]["evidence_sha256"] = digest(review)
                req["artifact_sha256"] = digest(aggregate)
                with self.assertRaisesRegex(common.ScoreError, "reviewer separation|triggering actor"):
                    l5.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)

    def test_phase5_scorer_accepts_exact_i1_i5_transition(self) -> None:
        _, store, req = p5_fixture()
        result = p5.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)
        self.assertTrue(result["credit_allowed"])
        self.assertEqual((result["old_percent"], result["new_percent"]), (89, 100))

    def test_phase5_scorer_rejects_runtime_image_identity_drift(self) -> None:
        aggregate, store, req = p5_fixture()
        ref = aggregate["evidence"]["hosted_candidate_parity"]  # type: ignore[index]
        i1_path = ref["path"]
        bad_i1 = copy.deepcopy(store.values[i1_path])
        bad_i1["images"][0]["runtime_image_id"] = f"sha256:{'f' * 64}"  # type: ignore[index]
        store.values[i1_path] = bad_i1
        ref["sha256"] = digest(bad_i1)
        req["artifact_sha256"] = digest(aggregate)
        with self.assertRaisesRegex(common.ScoreError, "runtime identity mismatch"):
            p5.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)

    def test_phase5_scorer_rejects_frontend_outside_evidence_lineage(self) -> None:
        frontend_source = "f" * 40
        aggregate, store, req = p5_fixture()
        auth_ref = aggregate["evidence"]["production_auth_identity"]  # type: ignore[index]
        capability_ref = aggregate["evidence"]["capability_gates"]  # type: ignore[index]
        auth = copy.deepcopy(store.values[auth_ref["path"]])
        capability = copy.deepcopy(store.values[capability_ref["path"]])
        auth["source_binding"]["frontend_source_commit_sha"] = frontend_source  # type: ignore[index]
        capability["gates"]["production_auth_identity"]["evidence_sha256"] = digest(auth)  # type: ignore[index]
        store.values[auth_ref["path"]] = auth
        store.values[capability_ref["path"]] = capability
        auth_ref["sha256"] = digest(auth)
        capability_ref["sha256"] = digest(capability)
        req["artifact_sha256"] = digest(aggregate)
        with self.assertRaisesRegex(
            common.ScoreError,
            "production auth frontend source is not an ancestor of the evidence source",
        ):
            p5.score_request(
                req,
                load_blob=store.load,
                is_ancestor=lambda older, _newer: older != frontend_source,
            )


if __name__ == "__main__":
    unittest.main()
