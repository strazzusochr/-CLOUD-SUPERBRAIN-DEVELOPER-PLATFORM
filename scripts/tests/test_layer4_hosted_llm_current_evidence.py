from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import validate_layer4_hosted_llm_current_evidence as validator  # noqa: E402
import build_layer4_hosted_llm_current_evidence as builder  # noqa: E402


SOURCE_SHA = "1" * 40
ARCHIVE_SHA256 = "2" * 64
RUBRIC_SHA = "3" * 40
TREE_SHA = "4" * 40
RUNTIME_BLOB = "5" * 40
WRANGLER_BLOB = "6" * 40
RUBRIC_BLOB = "7" * 40
CAPABILITY_BLOB = "8" * 40
OWNER_REF_SHA256 = "9" * 64
GATE_EVIDENCE_BLOB = "a" * 40
BASE_URL = "https://cloud-superbrain-llm-gateway-preview.strazzusochr.workers.dev"
CHECKED_AT = "2026-09-02T12:00:00.000Z"


def source(verifier_blob: str = "b" * 40, *, implementation_blob: str | None = None) -> dict:
    value = {
        "commit_sha": SOURCE_SHA,
        "archive_sha256": ARCHIVE_SHA256,
        "gateway_tree_sha": TREE_SHA,
        "verifier_blob": verifier_blob,
        "runtime_blob": RUNTIME_BLOB,
        "wrangler_blob": WRANGLER_BLOB,
        "rubric_blob": RUBRIC_BLOB,
        "capability_blob": CAPABILITY_BLOB,
    }
    if implementation_blob is not None:
        value["implementation_blob"] = implementation_blob
    return value


def authority() -> dict:
    return {
        "owner_grant_ref_sha256": OWNER_REF_SHA256,
        "gate_evidence_path": ".codex/runs/CURRENT/capability/live-llm-free-provider/report.json",
        "gate_evidence_blob": GATE_EVIDENCE_BLOB,
    }


def common(contract: str, criterion: str, points: int) -> dict:
    return {
        "contract_version": contract,
        "status": "verified",
        "criterion": criterion,
        "criterion_points": points,
        "credit_eligible": True,
        "checked_at": CHECKED_AT,
        "rubric_approval_commit": RUBRIC_SHA,
        "base_url": BASE_URL,
        "source": source(),
        "authority": authority(),
        "direct_provider_calls": False,
        "provider_writes": False,
        "hosted_audit_write": True,
        "secret_output": False,
        "manifest_updated": False,
        "delta_ledger_entry_created": False,
        "production_deploy": False,
        "release_promotion": False,
    }


def reports() -> dict[str, dict]:
    current = common(
        "llm-hosted-current-evidence-chain-v2",
        "L4 current hosted generation, routing allowlist, and completion audit",
        18,
    )
    current.update(
        {
            "evidence_ref": "current_hosted_llm_generative_routing_audit_verified",
            "source": source(implementation_blob="c" * 40),
            "criteria": [
                {"claim_id": "hosted_generative_source_bound", "points": 10},
                {"claim_id": "hosted_routing_allowlist", "points": 4},
                {"claim_id": "hosted_completion_audit", "points": 4},
            ],
            "generation": {
                "model": "@cf/meta/llama-3.1-8b-instruct-fast",
                "provider": "workers-ai",
                "response_sha256": "d" * 64,
                "request_id_sha256": "e" * 64,
                "trace_id_sha256": "f" * 64,
                "gateway_log_id_sha256": "0" * 64,
                "d1_evidence_ref": "d1_audit:fixture",
                "source_bound": True,
                "gateway_log_readback_verified": True,
            },
            "routing": {
                "requested_model": "@cf/meta/llama-3.1-8b-instruct-fast",
                "selected_model": "@cf/meta/llama-3.1-8b-instruct-fast",
                "allowed_models_sha256": "1" * 64,
                "allowed_model_count": 2,
                "allowlist_verified": True,
                "gateway_only": True,
                "fallback_used": False,
            },
            "audit": {
                "persisted": True,
                "readback_verified": True,
                "source_bound": True,
                "provider_call_count": 1,
            },
            "historical_evidence": {
                "contract_version": "live-llm-bounded-evidence-chain-v1",
                "progress_credit_recommended": 0,
                "excluded_from_current_delta": True,
            },
            "live_provider_calls": True,
            "provider_call_count": 1,
        }
    )

    stream = common(
        "llm-hosted-stream-parity-evidence-v2",
        "L4 hosted stream and non-stream are semantically equal",
        10,
    )
    stream.update(
        {
            "semantic_parity": True,
            "provider_call_count": 2,
            "live_provider_calls": True,
            "nonstream": {
                "gateway_log_readback_verified": True,
                "audit_readback_verified": True,
            },
            "stream": {
                "gateway_log_readback_verified": True,
                "audit_readback_verified": True,
                "frame_count": 2,
                "done_count": 1,
                "synthetic_terminal_frame": False,
            },
        }
    )

    fallback = common(
        "llm-hosted-fallback-evidence-v2",
        "L4 hosted fallback is bounded and audited",
        3,
    )
    fallback.update(
        {
            "live_provider_calls": True,
            "provider_call_count": 2,
            "fallback": {
                "provider_attempt_count": 2,
                "gateway_log_id_sha256": ["2" * 64, "3" * 64],
                "d1_evidence_ref": "d1_audit:fallback",
                "gateway_log_readback_verified": True,
                "audit_readback_verified": True,
            },
        }
    )

    budget = common(
        "llm-hosted-budget-guard-evidence-v2",
        "L4 hosted budget guard stops before provider execution",
        3,
    )
    budget.update(
        {
            "live_provider_calls": False,
            "probe": {
                "http_status": 422,
                "error": "input_limit_exceeded",
                "provider_call_count": 0,
                "audit_readback_verified": True,
                "gateway_log_readback_required": False,
            },
        }
    )

    trace = common(
        "llm-hosted-trace-correlation-evidence-v2",
        "L4 hosted trace ID correlates gateway, provider, and immutable evidence",
        4,
    )
    trace.update(
        {
            "live_provider_calls": True,
            "provider_call_count": 1,
            "trace": {
                "trace_id": "4" * 32,
                "gateway_log_id_sha256": "5" * 64,
                "d1_evidence_ref": "d1_audit:trace",
                "gateway_log_readback_verified": True,
                "audit_readback_verified": True,
            },
        }
    )

    negative = common(
        "llm-hosted-negative-guards-evidence-v2",
        "L4 hosted auth, oversize, schema, and policy guards stop before provider execution",
        7,
    )
    negative.update(
        {
            "live_provider_calls": False,
            "provider_call_count": 0,
            "probes": [
                {"name": "missing_auth", "http_status": 401, "error": "gateway_authentication_required"},
                {"name": "invalid_auth", "http_status": 401, "error": "gateway_authentication_required"},
                {"name": "oversize", "http_status": 422, "error": "input_limit_exceeded"},
                {"name": "schema_violation", "http_status": 422, "error": "invalid_messages"},
                {"name": "policy_violation", "http_status": 403, "error": "model_not_allowed"},
            ],
        }
    )
    return {
        "current_chain": current,
        "stream": stream,
        "fallback": fallback,
        "budget": budget,
        "trace": trace,
        "negative": negative,
    }


def report_bytes(payloads: dict[str, dict]) -> tuple[dict[str, str], dict[str, bytes]]:
    paths = {
        name: f"docs/release-artifacts/fixture-evidence/hosted-layer/{name}.json"
        for name in payloads
    }
    blobs = {
        paths[name]: (json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n").encode()
        for name, payload in payloads.items()
    }
    return paths, blobs


def build_input(paths: dict[str, str]) -> dict:
    return {
        "contract_version": "layer4-hosted-llm-current-evidence-build-input-v1",
        "release_id": "fixture-release",
        "candidate_source_commit_sha": SOURCE_SHA,
        "candidate_source_archive_sha256": ARCHIVE_SHA256,
        "rubric_approval_commit": RUBRIC_SHA,
        "reports": paths,
    }


class Layer4HostedCurrentEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.payloads = reports()
        self.paths, self.blobs = report_bytes(self.payloads)

    def load(self, path: str) -> bytes:
        return self.blobs[path]

    def build(self) -> dict:
        return validator.build_aggregate(build_input(self.paths), self.load, checked_at=CHECKED_AT)

    def test_exact_seven_category_45_point_aggregate_validates(self) -> None:
        aggregate = self.build()
        summary = validator.validate_aggregate(aggregate, self.load)
        self.assertEqual(aggregate["baseline_percent"], 55)
        self.assertEqual(aggregate["credited_percent"], 100)
        self.assertEqual(aggregate["credit_points_total"], 45)
        self.assertEqual(len(aggregate["criteria"]), 7)
        self.assertEqual(summary["credit_points_total"], 45)
        self.assertTrue(summary["historical_credit_excluded"])

    def test_legacy_bounded_chain_cannot_replace_current_chain(self) -> None:
        legacy = copy.deepcopy(self.payloads)
        legacy["current_chain"] = {
            "contract_version": "live-llm-bounded-evidence-chain-v1",
            "status": "verified_bounded_evidence",
            "progress_credit_recommended": 0,
            "full_source_bound_live_call_chain": False,
        }
        paths, blobs = report_bytes(legacy)
        with self.assertRaisesRegex(validator.EvidenceError, "current_chain contract mismatch"):
            validator.build_aggregate(build_input(paths), blobs.__getitem__, checked_at=CHECKED_AT)

    def test_historical_ten_points_must_remain_excluded(self) -> None:
        aggregate = self.build()
        aggregate["historical_credit"]["excluded_from_delta"] = False
        with self.assertRaisesRegex(validator.EvidenceError, "historical credit"):
            validator.validate_aggregate(aggregate, self.load)

    def test_duplicate_or_reweighted_criterion_is_rejected(self) -> None:
        aggregate = self.build()
        aggregate["criteria"][1]["criterion_id"] = aggregate["criteria"][0]["criterion_id"]
        with self.assertRaisesRegex(validator.EvidenceError, "criterion"):
            validator.validate_aggregate(aggregate, self.load)

        aggregate = self.build()
        aggregate["criteria"][0]["points"] = 20
        aggregate["credit_points_total"] = 55
        with self.assertRaisesRegex(validator.EvidenceError, "points"):
            validator.validate_aggregate(aggregate, self.load)

    def test_only_current_generative_and_routing_claims_may_share_one_report(self) -> None:
        aggregate = self.build()
        current_path = aggregate["criteria"][0]["report_path"]
        current_hash = aggregate["criteria"][0]["report_sha256"]
        aggregate["criteria"][1]["report_path"] = current_path
        aggregate["criteria"][1]["report_sha256"] = current_hash
        with self.assertRaisesRegex(validator.EvidenceError, "report binding"):
            validator.validate_aggregate(aggregate, self.load)

    def test_report_hash_and_source_binding_are_fail_closed(self) -> None:
        aggregate = self.build()
        stream_path = self.paths["stream"]
        self.blobs[stream_path] += b" "
        with self.assertRaisesRegex(validator.EvidenceError, "hash mismatch"):
            validator.validate_aggregate(aggregate, self.load)

        self.paths, self.blobs = report_bytes(self.payloads)
        drifted = copy.deepcopy(self.payloads)
        drifted["trace"]["source"]["commit_sha"] = "f" * 40
        paths, blobs = report_bytes(drifted)
        with self.assertRaisesRegex(validator.EvidenceError, "source commit mismatch"):
            validator.build_aggregate(build_input(paths), blobs.__getitem__, checked_at=CHECKED_AT)

    def test_false_booleans_are_not_satisfied_by_zero_or_strings(self) -> None:
        broken = copy.deepcopy(self.payloads)
        broken["negative"]["secret_output"] = 0
        paths, blobs = report_bytes(broken)
        with self.assertRaisesRegex(validator.EvidenceError, "secret_output"):
            validator.build_aggregate(build_input(paths), blobs.__getitem__, checked_at=CHECKED_AT)

    def test_report_paths_must_be_normalized_repository_paths(self) -> None:
        bad_input = build_input(self.paths)
        bad_input["reports"]["trace"] = "../trace.json"
        with self.assertRaisesRegex(validator.EvidenceError, "normalized repository path"):
            validator.build_aggregate(bad_input, self.load, checked_at=CHECKED_AT)

    def test_builder_serializes_a_valid_deterministic_scorer_input(self) -> None:
        descriptor = (json.dumps(build_input(self.paths), sort_keys=True) + "\n").encode()
        payload, serialized = builder.build_document(descriptor, self.load, checked_at=CHECKED_AT)
        self.assertEqual(json.loads(serialized), payload)
        self.assertEqual(validator.validate_aggregate(payload, self.load)["credit_points_total"], 45)
        self.assertTrue(serialized.endswith(b"\n"))

    def test_builder_never_overwrites_an_existing_aggregate(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "aggregate.json"
            target.write_text("preserve", encoding="utf-8")
            with self.assertRaises(FileExistsError):
                builder.write_new_file(target, b"replacement\n")
            self.assertEqual(target.read_text(encoding="utf-8"), "preserve")


if __name__ == "__main__":
    unittest.main()
