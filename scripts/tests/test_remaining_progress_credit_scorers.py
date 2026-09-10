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
import score_layer4_hosted_llm_credit as l4  # noqa: E402
import score_phase6_scale_credit as p6  # noqa: E402
import validate_layer4_hosted_llm_current_evidence as l4_validator  # noqa: E402
from scripts.tests import test_layer4_hosted_llm_current_evidence as l4_data  # noqa: E402


CANDIDATE = "1" * 40
EVIDENCE = "e" * 40
RELEASE = "prod-candidate-2026-09-02-local-rc99"


def encoded(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def digest(value: object) -> str:
    raw = value if isinstance(value, bytes) else encoded(value)
    return hashlib.sha256(raw).hexdigest()


class BlobStore:
    def __init__(self, values: dict[str, object]) -> None:
        self.values = values

    def load(self, source: str, path: str) -> bytes:
        if source != EVIDENCE or path not in self.values:
            raise common.ScoreError(f"missing fixture blob: {path}")
        value = self.values[path]
        return value if isinstance(value, bytes) else encoded(value)


def request(command: str, scope: str, cell: str, old: int, new: int, path: str, payload: object) -> dict[str, object]:
    return {
        "contract_version": common.REQUEST_CONTRACT,
        "verifier_command": command,
        "scope": scope,
        "cell_id": cell,
        "source_sha": EVIDENCE,
        "artifact_path": path,
        "artifact_sha256": digest(payload),
        "old_percent": old,
        "new_percent": new,
        "overall_percent": 89,
        "previous_projection_sha256": "a" * 64,
        "projection_sha256": "b" * 64,
        "read_only_required": True,
        "provider_writes_allowed": False,
        "secret_output_allowed": False,
    }


def candidate_pointer() -> dict[str, object]:
    return {"active_release_id": RELEASE, "source_commit_sha": CANDIDATE, "production_rollout_claimed": False}


def l4_fixture() -> tuple[dict[str, object], BlobStore, dict[str, object]]:
    payloads = l4_data.reports()
    paths, blobs = l4_data.report_bytes(payloads)
    build_input = l4_data.build_input(paths)
    build_input["release_id"] = RELEASE
    aggregate = l4_validator.build_aggregate(build_input, blobs.__getitem__, checked_at=l4_data.CHECKED_AT)
    aggregate_path = f"docs/release-artifacts/{RELEASE}-evidence/hosted-layer/{l4.AGGREGATE_FILENAME}"
    values: dict[str, object] = {
        **blobs,
        aggregate_path: aggregate,
        common.CURRENT_CANDIDATE_PATH: candidate_pointer(),
    }
    store = BlobStore(values)
    return aggregate, store, request(l4.SCORER_COMMAND, "vertical", "layer_4", 55, 100, aggregate_path, aggregate)


def p6_fixture() -> tuple[dict[str, object], BlobStore, dict[str, object]]:
    artifact_path = f"docs/release-artifacts/{RELEASE}-evidence/phase6/phase6-scale-evidence.json"
    run_id = 987654
    head_sha = "c" * 40
    artifact_name = f"phase6-scale-evidence-{run_id}-1"
    read_tiers = []
    for concurrency, requests, p95 in ((1, 60, 70.0), (10, 240, 230.0), (50, 500, 300.0)):
        read_tiers.append(
            {
                "concurrency": concurrency,
                "requests": requests,
                "valid_health_200": requests,
                "invalid_health_200": 0,
                "throttled_429": 0,
                "server_5xx": 0,
                "transport_fail": 0,
                "other_status": 0,
                "p95_ms": p95,
            }
        )
    evidence: dict[str, object] = {
        "contract_version": p6.EVIDENCE_CONTRACT,
        "generated_at_utc": "2026-09-02T12:00:00.000Z",
        "run_id": "scale-fixture",
        "result": "provisional_pending_github_readback",
        "source_binding": {
            "source_commit_sha": CANDIDATE,
            "owner_granted": True,
            "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O2",
            "health_json_source_binding_verified": True,
            "preview_guard_verified": True,
            "execution_attestation": {
                "github_actions": True,
                "event_name": "workflow_dispatch",
                "run_id": run_id,
                "run_attempt": 1,
                "head_sha": head_sha,
                "source_commit_sha": CANDIDATE,
                "artifact_name": artifact_name,
                "post_run_api_readback_required": True,
                "verified": False,
            },
        },
        "request_budget": {
            "worker_cap": 900,
            "worker_requests_issued": 900,
            "read_requests_issued": 800,
            "create_requests_issued": 50,
            "cleanup_delete_requests_issued": 50,
            "control_edge_requests_issued": 244,
            "cap_respected": True,
            "exact_plan_executed": True,
        },
        "read_tiers": read_tiers,
        "health_validation": {"valid_json_count": 800, "invalid_json_or_contract_count": 0, "validation_failures": []},
        "write_tier": {
            "concurrency": 10,
            "records_planned": 50,
            "valid_post_insert_readbacks": 50,
            "record_loss_count": 0,
            "duplicate_count": 0,
            "duplicate_request_id_count": 0,
            "duplicate_audit_event_id_count": 0,
            "field_failure_count": 0,
            "hash_failure_count": 0,
            "audit_failure_count": 0,
            "throttled_429": 0,
            "server_5xx": 0,
            "transport_fail": 0,
        },
        "cleanup": {
            "verified_count": 50,
            "literal_success_count": 50,
            "required_count": 50,
            "complete": True,
            "throttled_429": 0,
            "unclean_throttle_count": 0,
            "server_5xx": 0,
            "transport_fail": 0,
        },
        "aggregate": {
            "literal_success_count": 900,
            "success_ratio": 1.0,
            "worst_p95_ms": 300.0,
            "throttled_429_total": 0,
            "server_5xx_total": 0,
            "transport_fail_total": 0,
            "http_429_counted_as_success": False,
            "failures": [],
            "criterion_met": True,
        },
        "auth": {"environment_variable_name": "AGENT_API_AUTH_TOKEN", "value_recorded": False},
        "gate_may_open": False,
        "gate_promotion_performed": False,
        "percentage_credit_awarded": 0,
    }
    evidence_hash = digest(evidence)
    readback = {
        "contract_version": p6.READBACK_CONTRACT,
        "collected_at_utc": "2026-09-02T12:30:00.000Z",
        "run": {
            "id": run_id,
            "run_attempt": 1,
            "event": "workflow_dispatch",
            "status": "completed",
            "conclusion": "success",
            "head_sha": head_sha,
        },
        "artifact": {
            "id": 123,
            "name": artifact_name,
            "expired": False,
            "digest": f"sha256:{'d' * 64}",
            "workflow_run": {"id": run_id, "head_sha": head_sha},
        },
        "downloaded_evidence_sha256": evidence_hash,
        "secret_output": False,
    }
    readback_path = f"{artifact_path}.execution-readback.json"
    readback_raw = encoded(readback)
    sidecar_path = f"{readback_path}.sha256"
    sidecar = f"{hashlib.sha256(readback_raw).hexdigest()}  {readback_path.rsplit('/', 1)[-1]}\n".encode()
    capability = {
        "contract_version": "capability-gate-state-v1",
        "gates": {
            "phase6_scale_runtime": {
                "owner_granted": True,
                "live_verified": True,
                "paid_provider": False,
                "provider": "cloudflare-workers-d1-zero-card",
                "verifier": p6.PHASE6_VERIFIER_PATH,
                "evidence_artifact": artifact_path,
                "evidence_sha256": evidence_hash,
            }
        },
    }
    values: dict[str, object] = {
        artifact_path: evidence,
        readback_path: readback_raw,
        sidecar_path: sidecar,
        common.CURRENT_CANDIDATE_PATH: candidate_pointer(),
        p6.CAPABILITY_PATH: capability,
    }
    store = BlobStore(values)
    return evidence, store, request(p6.SCORER_COMMAND, "horizontal", "phase_6", 90, 100, artifact_path, evidence)


class RemainingProgressCreditScorerTests(unittest.TestCase):
    def test_layer4_scorer_accepts_deep_validated_45_point_transition(self) -> None:
        _, store, req = l4_fixture()
        result = l4.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)
        self.assertTrue(result["credit_allowed"])

    def test_layer4_scorer_rejects_shallow_but_semantically_false_report(self) -> None:
        aggregate, store, req = l4_fixture()
        stream_criterion = next(item for item in aggregate["criteria"] if item["criterion_id"] == "hosted_stream_semantic_parity")  # type: ignore[index]
        path = stream_criterion["report_path"]
        stream = json.loads(store.values[path].decode("utf-8"))  # type: ignore[union-attr]
        stream["semantic_parity"] = False
        raw = encoded(stream)
        store.values[path] = raw
        stream_criterion["report_sha256"] = hashlib.sha256(raw).hexdigest()
        req["artifact_sha256"] = digest(aggregate)
        with self.assertRaisesRegex(common.ScoreError, "deep evidence validation"):
            l4.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)

    def test_layer4_scorer_rejects_non_release_scoped_evidence_path(self) -> None:
        aggregate, store, req = l4_fixture()
        bad_path = f".phase1-artifacts/hosted-layer/{l4.AGGREGATE_FILENAME}"
        store.values[bad_path] = aggregate
        req["artifact_path"] = bad_path
        req["artifact_sha256"] = digest(aggregate)
        with self.assertRaisesRegex(common.ScoreError, "unexpected L4 aggregate artifact path"):
            l4.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)

    def test_phase6_scorer_accepts_exact_900_request_first_attempt(self) -> None:
        _, store, req = p6_fixture()
        result = p6.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)
        self.assertTrue(result["credit_allowed"])

    def test_phase6_scorer_rejects_write_429_and_stale_readback(self) -> None:
        evidence, store, req = p6_fixture()
        evidence["write_tier"]["throttled_429"] = 1  # type: ignore[index]
        req["artifact_sha256"] = digest(evidence)
        with self.assertRaisesRegex(common.ScoreError, "throttled_429"):
            p6.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)

        _, store, req = p6_fixture()
        readback_path = f"{req['artifact_path']}.execution-readback.json"
        readback = json.loads(store.values[readback_path].decode("utf-8"))  # type: ignore[union-attr]
        readback["collected_at_utc"] = "2026-09-04T12:30:00.000Z"
        raw = encoded(readback)
        store.values[readback_path] = raw
        sidecar_path = f"{readback_path}.sha256"
        store.values[sidecar_path] = f"{hashlib.sha256(raw).hexdigest()}  {readback_path.rsplit('/', 1)[-1]}\n".encode()
        with self.assertRaisesRegex(common.ScoreError, "24-hour"):
            p6.score_request(req, load_blob=store.load, is_ancestor=lambda _a, _b: True)


if __name__ == "__main__":
    unittest.main()
