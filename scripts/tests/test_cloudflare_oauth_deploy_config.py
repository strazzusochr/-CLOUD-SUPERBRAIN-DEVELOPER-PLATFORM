from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
WRANGLER_CONFIG = REPO_ROOT / "services" / "cloudflare-stateful-runtime" / "wrangler.jsonc"
DEPLOY_WRAPPER = REPO_ROOT / "scripts" / "deploy-cloudflare-stateful-runtime.ps1"
CANONICAL_FRONTEND_ORIGIN = "https://frontend-seven-psi-78.vercel.app"
CANONICAL_CALLBACK = f"{CANONICAL_FRONTEND_ORIGIN}/api/v1/auth/callback"


class CloudflareOAuthDeployConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.config = json.loads(WRANGLER_CONFIG.read_text(encoding="utf-8"))
        cls.wrapper = DEPLOY_WRAPPER.read_text(encoding="utf-8")

    def test_public_oauth_routes_use_the_canonical_frontend(self) -> None:
        variables = self.config["vars"]
        self.assertEqual(variables["GITHUB_OAUTH_REDIRECT_URI"], CANONICAL_CALLBACK)
        self.assertEqual(variables["POST_LOGIN_REDIRECT"], "/workbench")
        self.assertRegex(variables["GITHUB_OAUTH_CLIENT_ID"], r"^[A-Za-z0-9_-]{1,128}$")
        self.assertRegex(variables["GITHUB_OAUTH_OWNER_IDS"], r"^[1-9][0-9]*(,[1-9][0-9]*)*$")

    def test_secret_and_candidate_source_values_are_not_committed_as_plain_vars(self) -> None:
        variables = self.config["vars"]
        for name in (
            "GITHUB_OAUTH_CLIENT_SECRET",
            "JWT_SIGNING_SECRET",
            "AGENT_API_AUTH_TOKEN",
            "SOURCE_COMMIT_SHA",
            "SOURCE_ARCHIVE_SHA256",
            "SOURCE_BUNDLE_SHA256",
            "PRODUCTION_AUTH_OWNER_GRANTED",
            "PRODUCTION_AUTH_OWNER_GRANT_REF",
            "HOSTED_MCP_WRITE_AUTHORIZED",
            "HOSTED_MCP_WRITE_OWNER_GRANT_REF",
            "HOSTED_MCP_WRITE_OWNER_GRANT_COMMIT_SHA",
            "LAYER_CREDIT_RUBRIC_APPROVAL_SHA",
            "LIVE_MCP_WRITES_ENABLED",
            "HOSTED_MCP_DEPLOYMENT_ENVIRONMENT",
            "HOSTED_MCP_PREVIEW_HOSTNAME",
            "HOSTED_MCP_WRITE_BRANCH",
            "HOSTED_MCP_VERIFIER_BLOB_SHA256",
            "HOSTED_MCP_RUNTIME_BLOB_SHA256",
            "HOSTED_MCP_RUBRIC_BLOB_SHA256",
            "HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256",
        ):
            with self.subTest(name=name):
                self.assertNotIn(name, variables)

    def test_wrapper_fails_closed_before_wrangler_invocation(self) -> None:
        required_markers = (
            "OAuth callback uses the canonical frontend origin",
            "post-login redirect is the canonical frontend path",
            "OAuth callback is not deployed directly on the Worker origin",
            '"--var", "SOURCE_COMMIT_SHA:$resolved"',
            '"--var", "SOURCE_ARCHIVE_SHA256:$archiveSha"',
            '"--var", "HOSTED_MCP_DEPLOYMENT_ENVIRONMENT:$hostedMcpDeploymentEnvironment"',
            '"--var", "HOSTED_MCP_PREVIEW_HOSTNAME:$previewWorkerHostname"',
            "validation complete; nothing was published",
        )
        for marker in required_markers:
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

        config_guard = self.wrapper.index("OAuth callback uses the canonical frontend origin")
        source_guard = self.wrapper.index("worker tree matches the deployed commit")
        wrangler_invocation = self.wrapper.index("& node @deployArgs", source_guard)
        self.assertLess(config_guard, source_guard)
        self.assertLess(source_guard, wrangler_invocation)
        self.assertNotRegex(self.wrapper, re.compile(r"--outdir.*worker-dryrun", re.IGNORECASE))

    def test_owner_gate_is_bound_only_from_the_selected_tracked_commit(self) -> None:
        for marker in (
            '$capabilityStatePath = "docs/runtime-state/capability-gates.json"',
            '& git show "$resolved`:$capabilityStatePath"',
            "$ownerGrantedProperty.Value -is [bool]",
            "$ownerGrantedProperty.Value -eq $true",
            '$ownerGrantRef.Length -le 256',
            r'$ownerGrantRef -notmatch "[\x00-\x1f\x7f]"',
            '"--var", "PRODUCTION_AUTH_OWNER_GRANTED:false"',
            '$bindingArgs[-1] = "PRODUCTION_AUTH_OWNER_GRANTED:true"',
            '$bindingArgs += @("--var", "PRODUCTION_AUTH_OWNER_GRANT_REF:$ownerGrantRef")',
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

        tracked_read = self.wrapper.index('& git show "$resolved`:$capabilityStatePath"')
        owner_binding = self.wrapper.index('"--var", "PRODUCTION_AUTH_OWNER_GRANTED:false"')
        wrangler_invocation = self.wrapper.index("& node @deployArgs", owner_binding)
        self.assertLess(tracked_read, owner_binding)
        self.assertLess(owner_binding, wrangler_invocation)
        self.assertNotIn("PRODUCTION_AUTH_LIVE_VERIFIED", self.wrapper)

    def test_owner_gate_reference_and_wrangler_output_are_not_emitted(self) -> None:
        self.assertIn("$null = & node @deployArgs 2>&1", self.wrapper)
        output_lines = [
            line
            for line in self.wrapper.splitlines()
            if "Write-Host" in line or "Write-Output" in line or "Write-Error" in line
        ]
        emitted_source = "\n".join(output_lines)
        self.assertNotIn("$ownerGrantRef", emitted_source)
        self.assertNotIn("$bindProductionAuthOwnerGrant", emitted_source)
        self.assertNotIn("live_verified:", emitted_source)

    def test_worker_source_closure_rejects_untracked_and_relevant_ignored_files(self) -> None:
        for marker in (
            "git ls-files --others --exclude-standard",
            "git ls-files --others --ignored --exclude-standard --directory",
            "worker tree has no untracked files",
            "worker tree has no runtime-relevant ignored files",
            '"services/cloudflare-stateful-runtime/node_modules/"',
            '"services/cloudflare-stateful-runtime/.wrangler/"',
            "fresh dependency tree installed from the selected integrity-pinned lock",
            "Get-GitArchiveSha256 $repoRoot $resolved",
            "source archive SHA-256 computed without a retained archive",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

    def test_deploy_builds_only_from_a_transient_selected_commit_materialization(self) -> None:
        for marker in (
            "ConvertFrom-Json -AsHashtable",
            '$trackedPackageLock["packages"]',
            '$lockPackages["node_modules/wrangler"]',
            'git archive --format=tar "--output=$workerArchive" $resolved -- services/cloudflare-stateful-runtime',
            'tar -xf $workerArchive -C $materializedWorkerDir --strip-components=2',
            'npm ci --ignore-scripts --prefer-offline --no-audit --no-fund',
            'Push-Location $materializedWorkerDir',
            '"--metafile", $preflightMetafile',
            '"--outdir", $preflightOutputDir',
            '"deploy", $preflightBundleFile,',
            '"--no-bundle", "--config", $materializedWranglerConfigPath',
            '"SOURCE_BUNDLE_SHA256:$sourceBundleSha"',
            'preview source_bundle_sha256 rebound',
            "preflight bundle inputs are confined to the selected source materialization",
            "transient source materialization removed",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

        self.assertNotIn("Push-Location $workerDir\n  try {\n    $null = & node @deployArgs", self.wrapper)

    def test_candidate_frontend_evidence_is_bound_from_a_descendant_control_commit(self) -> None:
        for marker in (
            '[string]$CandidateFrontendEvidenceCommitSha = ""',
            "frontend evidence control commit is an ancestor-descendant continuation of the selected source",
            '& git show "$frontendEvidenceCommit`:$frontendEvidencePath"',
            "candidate frontend evidence target is preview",
            "candidate frontend evidence archive matches the selected source",
            "candidate frontend evidence metadata is verified",
            "candidate frontend evidence carries no production release claim",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

        source_resolve = self.wrapper.index('$resolved = (& git rev-parse --verify "$CommitSha^{commit}").Trim()')
        evidence_read = self.wrapper.index('& git show "$frontendEvidenceCommit`:$frontendEvidencePath"')
        wrangler_invocation = self.wrapper.index("& node @deployArgs", evidence_read)
        self.assertLess(source_resolve, evidence_read)
        self.assertLess(evidence_read, wrangler_invocation)

    def test_hosted_mcp_activation_is_explicit_immutable_and_off_by_default(self) -> None:
        for marker in (
            "[switch]$EnableHostedMcpWrites",
            '"--var", "HOSTED_MCP_WRITE_AUTHORIZED:false"',
            '"--var", "LIVE_MCP_WRITES_ENABLED:false"',
            '"--var", "HOSTED_MCP_WRITE_AUTHORIZED:true"',
            '"--var", "LIVE_MCP_WRITES_ENABLED:true"',
            '"refs/remotes/origin/$CandidateBranch"',
            "hosted MCP authority commit is an ancestor of the candidate",
            "Owner grant commit authorizes the exact selected MCP scope",
            "named layer rubric commit is explicitly Owner-approved",
            "candidate uses the exact approved layer rubric blob",
            "DeployLlmGateway",
            "cloud-superbrain-llm-gateway-preview",
            "cloud-superbrain-state-preview",
            '"SOURCE_COMMIT_SHA:$resolved"',
            '"SOURCE_ARCHIVE_SHA256:$archiveSha"',
            "LLM preview source_commit_sha rebound",
            "LLM preview source_archive_sha256 rebound",
            "LLM preview gateway auth configured",
            "Get-GitBlobSha256",
            "Get-ManifestSha256",
            '"--var", "HOSTED_MCP_VERIFIER_BLOB_SHA256:$mcpVerifierManifestSha"',
            '"--var", "HOSTED_MCP_RUNTIME_BLOB_SHA256:$mcpRuntimeBlobSha"',
            '"--var", "HOSTED_MCP_RUBRIC_BLOB_SHA256:$mcpRubricBlobSha"',
            '"--var", "HOSTED_MCP_CAPABILITY_GATE_BLOB_SHA256:$mcpCapabilityGateBlobSha"',
            '"--var", "HOSTED_MCP_DEPLOYMENT_ENVIRONMENT:$hostedMcpDeploymentEnvironment"',
            '"--var", "HOSTED_MCP_PREVIEW_HOSTNAME:$previewWorkerHostname"',
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

        disabled = self.wrapper.index('"--var", "HOSTED_MCP_WRITE_AUTHORIZED:false"')
        enabled = self.wrapper.index('"--var", "HOSTED_MCP_WRITE_AUTHORIZED:true"')
        deploy = self.wrapper.index("& node @deployArgs", enabled)
        self.assertLess(disabled, enabled)
        self.assertLess(enabled, deploy)


if __name__ == "__main__":
    unittest.main()
