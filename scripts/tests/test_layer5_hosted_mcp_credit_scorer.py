from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "layer5_scorer", ROOT / "scripts" / "score_layer5_hosted_mcp_credit.py"
)
assert SPEC is not None and SPEC.loader is not None
scorer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scorer)


class Layer5HostedMcpCreditScorerTests(unittest.TestCase):
    def fixtures(self):
        reports = {
            "hosted_mcp_write": {
                "write_performed": True,
                "server_readback_verified": True,
                "audit_prewrite_persisted": True,
                "audit_postwrite_persisted": True,
                "content_sha256": "1" * 64,
                "prewrite_audit_event_ref": "2" * 64,
                "mcp_audit_event_ref": "3" * 64,
            },
            "hosted_mcp_auth_scope": {
                "missing_auth_http_status": 401,
                "invalid_auth_http_status": 401,
                "off_scope_http_status": 403,
                "exact_scope_http_status": 200,
                "caller_authentication_verified": True,
                "exact_scope_verified": True,
                "write_performed": True,
            },
            "hosted_mcp_timeout_idempotency": {
                "timeout_http_status": 200,
                "timeout_audit_event_ref": "4" * 64,
                "timeout_no_aftereffect_verified": True,
                "initial_write_http_status": 200,
                "replay_http_status": 200,
                "content_sha256": "5" * 64,
                "idempotency_replay_verified": True,
                "duplicate_write_count": 0,
            },
            "hosted_mcp_audit_readback_rollback": {
                "write_performed": True,
                "server_readback_verified": True,
                "content_sha256": "6" * 64,
                "prewrite_audit_event_ref": "7" * 64,
                "postwrite_audit_event_ref": "8" * 64,
                "audit_readback_verified": True,
                "rollback_http_status": 503,
                "rollback_audit_event_id": "",
                "rollback_state_verified": True,
            },
        }
        blobs: dict[tuple[str, str], bytes] = {}
        criteria = []
        for criterion_id, extra in reports.items():
            spec = scorer.CRITERIA[criterion_id]
            report = {
                "contract_version": spec["report_contract"],
                "evidence_ref": spec["evidence_ref"],
                "checked_at": "2026-09-01T20:00:00.000Z",
                "base_url": scorer.BASE_URL,
                "source_commit_sha": scorer.CANDIDATE_SOURCE_SHA,
                "source_archive_sha256": scorer.SOURCE_ARCHIVE_SHA256,
                "source_bundle_sha256": scorer.SOURCE_BUNDLE_SHA256,
                "repository": scorer.REPOSITORY,
                "branch": scorer.BRANCH,
                "rubric_approval_commit": scorer.RUBRIC_APPROVAL_SHA,
                "owner_grant_ref_present": True,
                "owner_grant_commit_sha": scorer.OWNER_GRANT_SHA,
                "token_environment_variable": "AGENT_API_AUTH_TOKEN",
                "token_output": False,
                "provider_writes": False,
                "production_deploy": False,
                "secret_output": False,
                "status": "verified",
                "credit_eligible": True,
                "live_mcp_writes": True,
                **extra,
            }
            report_bytes = (json.dumps(report, sort_keys=True) + "\n").encode()
            path = f"{scorer.EVIDENCE_ROOT}/{spec['filename']}"
            blobs[("evidence", path)] = report_bytes
            criteria.append(
                {
                    "criterion_id": criterion_id,
                    "points": spec["points"],
                    "report_path": path,
                    "report_sha256": hashlib.sha256(report_bytes).hexdigest(),
                    "report_contract": spec["report_contract"],
                    "evidence_ref": spec["evidence_ref"],
                }
            )
        aggregate = {
            "contract_version": scorer.AGGREGATE_CONTRACT,
            "status": "verified",
            "evidence_ref": scorer.AGGREGATE_EVIDENCE_REF,
            "checked_at": "2026-09-01T21:00:00.000Z",
            "release_id": scorer.RELEASE_ID,
            "candidate_source_commit_sha": scorer.CANDIDATE_SOURCE_SHA,
            "candidate_source_archive_sha256": scorer.SOURCE_ARCHIVE_SHA256,
            "candidate_source_bundle_sha256": scorer.SOURCE_BUNDLE_SHA256,
            "rubric_approval_commit": scorer.RUBRIC_APPROVAL_SHA,
            "owner_grant_commit_sha": scorer.OWNER_GRANT_SHA,
            "owner_grant_ref": scorer.OWNER_GRANT_REF,
            "baseline_percent": 56,
            "credited_percent": 86,
            "credit_points_total": 30,
            "criteria": criteria,
            "hosted_write_performed": True,
            "provider_writes": False,
            "production_deploy": False,
            "release_promotion": False,
            "registry_publish_performed": False,
            "secret_output": False,
            "non_claims": scorer.NON_CLAIMS,
        }
        aggregate_bytes = (json.dumps(aggregate, sort_keys=True) + "\n").encode()
        aggregate_path = f"{scorer.EVIDENCE_ROOT}/layer5-hosted-mcp-credit.json"
        blobs[("evidence", aggregate_path)] = aggregate_bytes
        rubric = (
            "Status: `APPROVED`\nCredit-Anwendung erlaubt: `true`\n"
            "scripts/verify-mcp-hosted-write.ps1\n"
        ).encode()
        blobs[(scorer.RUBRIC_APPROVAL_SHA, scorer.RUBRIC_PATH)] = rubric
        blobs[(scorer.CANDIDATE_SOURCE_SHA, scorer.RUBRIC_PATH)] = rubric
        current = {
            "active_release_id": scorer.RELEASE_ID,
            "source_commit_sha": scorer.CANDIDATE_SOURCE_SHA,
        }
        blobs[("evidence", scorer.CURRENT_CANDIDATE_PATH)] = json.dumps(current).encode()
        gate = {
            "contract_version": "capability-gate-state-v1",
            "gates": {
                "live_mcp_writes": {
                    "owner_granted": True,
                    "owner_grant_ref": scorer.OWNER_GRANT_REF,
                    "live_verified": True,
                }
            },
        }
        blobs[(scorer.CANDIDATE_SOURCE_SHA, scorer.CAPABILITY_PATH)] = json.dumps(gate).encode()
        blobs[(scorer.OWNER_GRANT_SHA, scorer.CAPABILITY_PATH)] = json.dumps(gate).encode()
        request = {
            "contract_version": scorer.REQUEST_CONTRACT,
            "verifier_command": scorer.SCORER_COMMAND,
            "scope": "vertical",
            "cell_id": "layer_5",
            "source_sha": "e" * 40,
            "artifact_path": aggregate_path,
            "artifact_sha256": hashlib.sha256(aggregate_bytes).hexdigest(),
            "old_percent": 56,
            "new_percent": 86,
            "overall_percent": 89,
            "previous_projection_sha256": "a" * 64,
            "projection_sha256": "b" * 64,
            "read_only_required": True,
            "provider_writes_allowed": False,
            "secret_output_allowed": False,
        }

        def load_blob(source_sha: str, path: str) -> bytes:
            key = ("evidence" if source_sha == request["source_sha"] else source_sha, path)
            if key not in blobs:
                raise scorer.ScoreError(f"fixture blob missing: {path}")
            return blobs[key]

        return request, aggregate, blobs, load_blob

    def score(self, request, load_blob):
        return scorer.score_request(request, load_blob=load_blob, is_ancestor=lambda _a, _b: True)

    def test_accepts_exact_four_report_credit_slice(self):
        request, _aggregate, _blobs, load_blob = self.fixtures()
        result = self.score(request, load_blob)
        self.assertTrue(result["evidence_verified"])
        self.assertTrue(result["credit_allowed"])
        self.assertFalse(result["provider_writes"])
        for key in scorer.BINDING_KEYS:
            self.assertEqual(result[key], request[key])

    def test_rejects_percent_inflation(self):
        request, _aggregate, _blobs, load_blob = self.fixtures()
        request["new_percent"] = 100
        with self.assertRaisesRegex(scorer.ScoreError, "percent transition"):
            self.score(request, load_blob)

    def test_rejects_aggregate_hash_drift(self):
        request, _aggregate, _blobs, load_blob = self.fixtures()
        request["artifact_sha256"] = "f" * 64
        with self.assertRaisesRegex(scorer.ScoreError, "aggregate artifact hash"):
            self.score(request, load_blob)

    def test_rejects_non_credit_report(self):
        request, _aggregate, blobs, load_blob = self.fixtures()
        path = f"{scorer.EVIDENCE_ROOT}/{scorer.CRITERIA['hosted_mcp_write']['filename']}"
        report = json.loads(blobs[("evidence", path)])
        report["credit_eligible"] = False
        changed = (json.dumps(report, sort_keys=True) + "\n").encode()
        blobs[("evidence", path)] = changed
        aggregate = json.loads(blobs[("evidence", request["artifact_path"])])
        aggregate["criteria"][0]["report_sha256"] = hashlib.sha256(changed).hexdigest()
        aggregate_bytes = (json.dumps(aggregate, sort_keys=True) + "\n").encode()
        blobs[("evidence", request["artifact_path"])] = aggregate_bytes
        request["artifact_sha256"] = hashlib.sha256(aggregate_bytes).hexdigest()
        with self.assertRaisesRegex(scorer.ScoreError, "not credit eligible"):
            self.score(request, load_blob)

    def test_rejects_report_hash_mismatch(self):
        request, _aggregate, blobs, load_blob = self.fixtures()
        aggregate = json.loads(blobs[("evidence", request["artifact_path"])])
        aggregate["criteria"][0]["report_sha256"] = "0" * 64
        aggregate_bytes = (json.dumps(aggregate, sort_keys=True) + "\n").encode()
        blobs[("evidence", request["artifact_path"])] = aggregate_bytes
        request["artifact_sha256"] = hashlib.sha256(aggregate_bytes).hexdigest()
        with self.assertRaisesRegex(scorer.ScoreError, "report hash mismatch"):
            self.score(request, load_blob)

    def test_rejects_duplicate_criterion(self):
        request, _aggregate, blobs, load_blob = self.fixtures()
        aggregate = json.loads(blobs[("evidence", request["artifact_path"])])
        aggregate["criteria"][1] = copy.deepcopy(aggregate["criteria"][0])
        aggregate_bytes = (json.dumps(aggregate, sort_keys=True) + "\n").encode()
        blobs[("evidence", request["artifact_path"])] = aggregate_bytes
        request["artifact_sha256"] = hashlib.sha256(aggregate_bytes).hexdigest()
        with self.assertRaisesRegex(scorer.ScoreError, "duplicate"):
            self.score(request, load_blob)

    def test_rejects_secret_output(self):
        request, _aggregate, blobs, load_blob = self.fixtures()
        aggregate = json.loads(blobs[("evidence", request["artifact_path"])])
        aggregate["secret_output"] = True
        aggregate_bytes = (json.dumps(aggregate, sort_keys=True) + "\n").encode()
        blobs[("evidence", request["artifact_path"])] = aggregate_bytes
        request["artifact_sha256"] = hashlib.sha256(aggregate_bytes).hexdigest()
        with self.assertRaisesRegex(scorer.ScoreError, "secret_output"):
            self.score(request, load_blob)

    def test_rejects_rubric_blob_drift(self):
        request, _aggregate, blobs, load_blob = self.fixtures()
        blobs[(scorer.CANDIDATE_SOURCE_SHA, scorer.RUBRIC_PATH)] = b"drift\n"
        with self.assertRaisesRegex(scorer.ScoreError, "rubric blob drift"):
            self.score(request, load_blob)


if __name__ == "__main__":
    unittest.main()
