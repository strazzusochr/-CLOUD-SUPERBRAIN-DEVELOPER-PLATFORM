from __future__ import annotations

import json
import os
import shutil
import subprocess
import unittest
import uuid
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
HOSTED_SCRIPTS = (
    "verify-mcp-hosted-write.ps1",
    "verify-mcp-hosted-auth-scope.ps1",
    "verify-mcp-hosted-timeout-idempotency.ps1",
    "verify-mcp-hosted-audit-readback-rollback.ps1",
)
SBOM_SCRIPT = "verify-mcp-candidate-sbom.ps1"
SECRET_SENTINEL = "l5-test-secret-sentinel-never-print-5e29c4f9"


class HostedMcpVerifierTests(unittest.TestCase):
    def run_pwsh(self, args: list[str], *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        command = ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", *args]
        return subprocess.run(
            command,
            cwd=REPO_ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=30,
            check=False,
        )

    def test_all_owned_scripts_parse(self) -> None:
        for name in (*HOSTED_SCRIPTS, SBOM_SCRIPT):
            path = REPO_ROOT / "scripts" / name
            command = (
                "$tokens=$null;$errors=$null;"
                f"[void][Management.Automation.Language.Parser]::ParseFile('{path}',"
                "[ref]$tokens,[ref]$errors);"
                "if($errors.Count){$errors|ForEach-Object{$_.Message};exit 1}"
            )
            result = self.run_pwsh(["-Command", command])
            self.assertEqual(result.returncode, 0, f"{name}: {result.stdout}")

    def test_hosted_scripts_block_before_network_or_write_without_dual_authorization(self) -> None:
        for name in HOSTED_SCRIPTS:
            relative_out = Path("scripts") / "tests" / f".l5-guard-{uuid.uuid4().hex}"
            absolute_out = REPO_ROOT / relative_out
            env = os.environ.copy()
            env["AGENT_API_AUTH_TOKEN"] = SECRET_SENTINEL
            env.pop("HOSTED_MCP_WRITE_AUTHORIZED", None)
            try:
                result = self.run_pwsh(
                    [
                        "-File",
                        str(REPO_ROOT / "scripts" / name),
                        "-BaseUrl",
                        "https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev",
                        "-ExpectedSourceCommitSha",
                        "1" * 40,
                        "-ExpectedSourceArchiveSha256",
                        "2" * 64,
                        "-ExpectedSourceBundleSha256",
                        "3" * 64,
                        "-Branch",
                        "codex/l5-verifier-test",
                        "-OutDir",
                        str(relative_out).replace("/", "\\"),
                    ],
                    env=env,
                )
                self.assertNotEqual(result.returncode, 0, name)
                self.assertIn("authorize_switch_required", result.stdout, name)
                self.assertNotIn(SECRET_SENTINEL, result.stdout, name)
                report_path = absolute_out / "report.json"
                digest_path = absolute_out / "report.sha256"
                self.assertTrue(report_path.is_file(), name)
                self.assertTrue(digest_path.is_file(), name)
                report = json.loads(report_path.read_text(encoding="utf-8"))
                self.assertEqual(report["status"], "blocked", name)
                self.assertFalse(report["credit_eligible"], name)
                self.assertFalse(report["write_performed"], name)
                self.assertFalse(report["live_mcp_writes"], name)
                self.assertFalse(report["secret_output"], name)
                self.assertNotIn(SECRET_SENTINEL, report_path.read_text(encoding="utf-8"), name)
            finally:
                shutil.rmtree(absolute_out, ignore_errors=True)

    def test_hosted_verifiers_are_source_bound_and_reject_dev_only_contracts(self) -> None:
        required_common = (
            "HOSTED_MCP_WRITE_AUTHORIZED",
            "HOSTED_MCP_WRITE_OWNER_GRANT_REF",
            "HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA",
            "LAYER_CREDIT_RUBRIC_APPROVAL_SHA",
            "ExpectedSourceCommitSha",
            "ExpectedSourceArchiveSha256",
            "ExpectedSourceBundleSha256",
            "source_bundle_sha256",
            "Get-RawGitBlobSha256",
            '$_`t$(Get-RawGitBlobSha256',
            '($lines -join "`n")',
            "runtime_blob_sha256",
            "rubric_blob_sha256",
            "capability_gate_blob_sha256",
            "dev_only_contract_rejected",
            "hosted_verifier_capabilities",
            "report.sha256",
            "secret_output = $false",
            "candidate_relevant_path_drift_forbidden",
            "owner_grant_commit_not_candidate_ancestor",
        )
        for name in HOSTED_SCRIPTS:
            source = (REPO_ROOT / "scripts" / name).read_text(encoding="utf-8")
            self.assertNotIn("scaffold_not_credit_bearing", source, name)
            for marker in required_common:
                self.assertIn(marker, source, f"{name}: {marker}")

    def test_hosted_verifiers_are_pinned_to_candidate_preview_and_reject_production_alias(self) -> None:
        preview = "https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev"
        production = "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev"
        for name in HOSTED_SCRIPTS:
            source = (REPO_ROOT / "scripts" / name).read_text(encoding="utf-8")
            self.assertGreaterEqual(source.count(preview), 2, name)
            self.assertNotIn(production, source, name)
            self.assertIn('$Value.Trim().TrimEnd("/") -ceq $sanctionedBaseUrl', source, name)
            self.assertIn("sanctioned_worker_hostname_required", source, name)

        write = (REPO_ROOT / "scripts" / "verify-mcp-hosted-write.ps1").read_text(encoding="utf-8")
        for marker in ("bounded_write", "server_readback", "audit_prewrite", "audit_postwrite"):
            self.assertIn(marker, write)

        auth = (REPO_ROOT / "scripts" / "verify-mcp-hosted-auth-scope.ps1").read_text(encoding="utf-8")
        for marker in ("missing_auth_must_return_401", "invalid_auth_must_return_401", "off_scope_request_must_return_403"):
            self.assertIn(marker, auth)

        timeout = (REPO_ROOT / "scripts" / "verify-mcp-hosted-timeout-idempotency.ps1").read_text(encoding="utf-8")
        for marker in ("timeout_no_aftereffect", "idempotency_replay", "duplicate_write_prevented"):
            self.assertIn(marker, timeout)

        rollback = (REPO_ROOT / "scripts" / "verify-mcp-hosted-audit-readback-rollback.ps1").read_text(encoding="utf-8")
        for marker in ("rollback_negative_probe", "rollback_state_verified", "atomic_batch_rejected_no_side_effect"):
            self.assertIn(marker, rollback)

    def test_candidate_sbom_uses_existing_images_and_writes_digest_bound_secret_safe_evidence(self) -> None:
        source = (REPO_ROOT / "scripts" / SBOM_SCRIPT).read_text(encoding="utf-8")
        self.assertNotIn("scaffold_not_credit_bearing", source)
        for marker in (
            "syft",
            "scan $tag --from docker",
            "cyclonedx-json=",
            "CycloneDX",
            "Get-FileHash",
            "aggregate_binding_sha256",
            "gitleaks",
            "Assert-NoSecretMaterial",
            "candidate-registry-digests-v1",
            "immutable_registry_reference",
            "registry_publish_performed = $false",
            "secret_output = $false",
        ):
            self.assertIn(marker, source, marker)
        for forbidden in ("docker pull", "docker build", "docker push", "syft scan registry:"):
            self.assertNotIn(forbidden, source.lower(), forbidden)


if __name__ == "__main__":
    unittest.main()
