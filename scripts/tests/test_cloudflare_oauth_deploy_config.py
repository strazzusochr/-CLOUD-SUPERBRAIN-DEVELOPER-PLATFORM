from __future__ import annotations

import copy
import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Callable


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
            'preview MCP health reports healthy',
            'preview MCP health source_commit_sha rebound',
            'preview MCP health source_archive_sha256 rebound',
            'preview MCP health source_bundle_sha256 rebound',
            'preview MCP health D1 read verified',
            'preview MCP health is non-mutating',
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
            '$allowedFrontendQualificationTruthPaths = @(',
            '"apps/frontend/lib/endpoint-snapshot.json"',
            '"apps/frontend/lib/platform.ts"',
            'git diff --name-only --diff-filter=ACDMRTUXB $resolved $trackedFrontendSourceSha -- apps/frontend',
            "frontend runtime delta is limited to qualification truth paths",
            '$computedFrontendArchiveSha = Get-GitArchiveSha256 $repoRoot $trackedFrontendSourceSha',
            "candidate frontend evidence target is preview",
            "candidate frontend evidence archive matches the tracked frontend source",
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

    def test_phase6_production_mode_is_explicit_and_control_commit_bound(self) -> None:
        for marker in (
            "[switch]$Phase6Production",
            '[string]$Phase6ControlCommitSha = ""',
            "phase6 production source SHA is an explicit lowercase commit",
            "phase6 production control SHA is an explicit lowercase commit",
            "phase6 production source commit resolved exactly",
            "phase6 production control commit resolved exactly",
            "phase6 production control commit descends from the source commit",
            '& git merge-base --is-ancestor $resolvedSource $resolvedControl',
            '& git show "$resolvedControl`:$capabilityStatePath"',
            "phase6 production gate is Owner-granted but not yet live-verified",
            "phase6 production gate is non-paid",
            '^[A-Za-z0-9_.:-]+$',
            "phase6 production mode excludes preview, LLM, and hosted MCP activation arguments",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

        production_dispatch = self.wrapper.index("if ($Phase6Production)")
        preview_evidence = self.wrapper.index('$frontendEvidencePath = "docs/runtime-state/frontend-hosted-current.json"')
        self.assertLess(production_dispatch, preview_evidence)

    def test_phase6_production_validates_exact_top_level_and_isolated_preview_bindings(self) -> None:
        production = self.wrapper.split("function Invoke-Phase6ProductionDeploy", 1)[1].split(
            "function Invoke-LlmGatewayCandidateDeploy", 1
        )[0]
        for marker in (
            "phase6 production targets the canonical top-level Worker",
            "cloud-superbrain-stateful-runtime",
            "phase6 production D1 binding is exact",
            "cloud-superbrain-state-prod",
            "91520f43-5d38-4a31-9d5a-6fca890e1dd6",
            "phase6 production Durable Object binding is exact",
            "RuntimeCoordinator",
            "phase6 production migration is exact",
            "v1-cloudflare-native-coordinator",
            "phase6 production queue producer is exact",
            "phase6 production queue consumer is exact",
            "cloud-superbrain-runtime-candidate",
            "phase6 production Vectorize binding is exact",
            "cloud-superbrain-memory-v1",
            "phase6 production Workers AI binding is exact",
            "phase6 production has no R2 binding",
            "phase6 production public runtime vars are exact",
            "phase6 preview Worker is isolated",
            "phase6 preview D1 binding is isolated",
            "cloud-superbrain-state-preview",
            "phase6 preview queue is isolated",
            "cloud-superbrain-runtime-candidate-preview",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, production)

    def test_phase6_production_wrangler_is_top_level_keep_vars_and_fail_closed(self) -> None:
        production = self.wrapper.split("function Invoke-Phase6ProductionDeploy", 1)[1].split(
            "function Invoke-LlmGatewayCandidateDeploy", 1
        )[0]
        for marker in (
            '"--keep-vars"',
            '"--no-experimental-auto-create"',
            '"--var", "SOURCE_COMMIT_SHA:$resolvedSource"',
            '"--var", "SOURCE_ARCHIVE_SHA256:$archiveSha"',
            '"--var", "SOURCE_BUNDLE_SHA256:$sourceBundleSha"',
            '"--var", "HOSTED_MCP_WRITE_AUTHORIZED:false"',
            '"--var", "LIVE_MCP_WRITES_ENABLED:false"',
            'Where-Object { [string]$_ -cmatch "^PRODUCTION_AUTH_" }',
            "phase6 production source cannot overwrite remote PRODUCTION_AUTH_* values",
            "phase6 production Wrangler deploy exit code 0; command output suppressed",
            '"deployments", "status"',
            '"--name", $productionWorkerName',
            '"--json"',
            "phase6 production latest deployment is exactly the uploaded version at 100 percent",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, production)

        self.assertNotIn('"--env"', production)
        self.assertNotIn("PRODUCTION_AUTH_OWNER_GRANTED:", production)
        self.assertNotIn("PRODUCTION_AUTH_OWNER_GRANT_REF:", production)

    def test_phase6_wrangler_children_scrub_legacy_and_staged_credentials(self) -> None:
        helper = self.wrapper.split("function Invoke-ScrubbedWranglerChild", 1)[1].split(
            "function Invoke-Phase6PreviewLoopGuardDeploy", 1
        )[0]
        for marker in (
            '[void]$startInfo.Environment.Remove("CLOUDFLARE_API_TOKEN_CANDIDATE")',
            '[void]$startInfo.Environment.Remove("CLOUDFLARE_API_KEY")',
            '[void]$startInfo.Environment.Remove("CLOUDFLARE_EMAIL")',
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, helper)

        phase6 = self.wrapper.split("function Invoke-Phase6PreviewLoopGuardDeploy", 1)[1].split(
            "function Invoke-LlmGatewayCandidateDeploy", 1
        )[0]
        self.assertGreaterEqual(phase6.count("Invoke-ScrubbedWranglerChild"), 7)
        for argument_variable in (
            "d1ListArgs",
            "preflightArgs",
            "deployArgs",
            "deploymentStatusArgs",
        ):
            self.assertNotRegex(phase6, rf"&\s+node\s+\$wrangler\s+@{argument_variable}\b")

    def test_phase6_production_performs_one_redirect_free_health_read_only(self) -> None:
        production = self.wrapper.split("function Invoke-Phase6ProductionDeploy", 1)[1].split(
            "function Invoke-LlmGatewayCandidateDeploy", 1
        )[0]
        for marker in (
            "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/api/v1/health",
            "$handler.AllowAutoRedirect = $false",
            "[System.Net.Http.HttpMethod]::Get",
            "phase6 production health status code is 200",
            "phase6 production health reports healthy",
            "phase6 production health verifies D1",
            "phase6 production health source_commit_sha rebound",
            "phase6 production health source_archive_sha256 rebound",
            "phase6 production health source_bundle_sha256 rebound",
            "phase6 production deploy metadata parsed only from bounded Wrangler labels",
            "phase6 production deployment and Worker version IDs are distinct",
            'contract_version = "cloudflare-phase6-production-deploy-result-v1"',
            "base_url = $productionBaseUrl",
            "verified_at_utc = [DateTimeOffset]::UtcNow",
            "worker_version_id = $workerVersionId",
            "deployment_id = $deploymentId",
            "health_status = 200",
            "d1_read_verified = $true",
            "phase6 production issued exactly one Worker request",
            "worker_request_count = $workerRequestCount",
            "secret_output = $false",
            "Write-Output ($deployResult | ConvertTo-Json -Compress)",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, production)

        self.assertEqual(production.count(".SendAsync("), 1)
        self.assertEqual(production.count("HttpRequestMessage]::new"), 1)
        self.assertEqual(production.count('"deployments", "status"'), 1)
        self.assertEqual(production.count("Write-Output"), 1)
        self.assertLess(production.index("Remove-TransientMaterialization"), production.index("Write-Output"))
        self.assertNotIn("Invoke-WebRequest", production)
        self.assertNotIn("/mcp/", production)
        self.assertNotIn("Set-Content", production)
        self.assertNotIn("Out-File", production)

        result_block = re.search(
            r"\$deployResult = \[ordered\]@\{(?P<body>.*?)\n\s*\}", production, re.DOTALL
        )
        self.assertIsNotNone(result_block)
        result_properties = re.findall(r"^\s{6}([a-z0-9_]+)\s*=", result_block.group("body"), re.MULTILINE)
        self.assertEqual(
            result_properties,
            [
                "contract_version",
                "base_url",
                "verified_at_utc",
                "source_commit_sha",
                "source_archive_sha256",
                "source_bundle_sha256",
                "worker_version_id",
                "deployment_id",
                "health_status",
                "d1_read_verified",
                "worker_request_count",
                "secret_output",
            ],
        )

    def test_phase6_binding_shape_rejects_added_families_and_fields(self) -> None:
        self.assertIn("function Assert-Phase6WranglerConfigShape", self.wrapper)
        mutations: tuple[tuple[str, Callable[[dict], None]], ...] = (
            ("top-level services", lambda value: value.__setitem__("services", [])),
            ("top-level kv", lambda value: value.__setitem__("kv_namespaces", [])),
            ("top-level hyperdrive", lambda value: value.__setitem__("hyperdrive", [])),
            (
                "top-level analytics",
                lambda value: value.__setitem__("analytics_engine_datasets", []),
            ),
            ("top-level unsafe", lambda value: value.__setitem__("unsafe", {"bindings": []})),
            ("preview services", lambda value: value["env"]["preview"].__setitem__("services", [])),
            ("preview kv", lambda value: value["env"]["preview"].__setitem__("kv_namespaces", [])),
            (
                "preview hyperdrive",
                lambda value: value["env"]["preview"].__setitem__("hyperdrive", []),
            ),
            (
                "preview analytics",
                lambda value: value["env"]["preview"].__setitem__("analytics_engine_datasets", []),
            ),
            (
                "preview unsafe",
                lambda value: value["env"]["preview"].__setitem__("unsafe", {"bindings": []}),
            ),
            (
                "production D1 extra field",
                lambda value: value["d1_databases"][0].__setitem__("preview_database_id", "x"),
            ),
            (
                "preview queue extra field",
                lambda value: value["env"]["preview"]["queues"]["producers"][0].__setitem__(
                    "delivery_delay", 1
                ),
            ),
        )

        with tempfile.TemporaryDirectory() as directory:
            temp_root = Path(directory)
            baseline_path = temp_root / "baseline.json"
            baseline_path.write_text(json.dumps(self.config), encoding="utf-8")
            baseline = self._run_shape_validation(baseline_path)
            self.assertEqual(baseline.returncode, 0, baseline.stdout + baseline.stderr)

            for index, (label, mutate) in enumerate(mutations):
                mutated = copy.deepcopy(self.config)
                mutate(mutated)
                config_path = temp_root / f"mutation-{index}.json"
                config_path.write_text(json.dumps(mutated), encoding="utf-8")
                completed = self._run_shape_validation(config_path)
                with self.subTest(label=label):
                    self.assertNotEqual(completed.returncode, 0, completed.stdout + completed.stderr)

    @staticmethod
    def _run_shape_validation(config_path: Path) -> subprocess.CompletedProcess[str]:
        command = (
            f". '{DEPLOY_WRAPPER.as_posix()}'; "
            f"$config = Get-Content -LiteralPath '{config_path.as_posix()}' -Raw | ConvertFrom-Json; "
            "Assert-Phase6WranglerConfigShape $config"
        )
        return subprocess.run(
            ["pwsh", "-NoProfile", "-Command", command],
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_phase6_preview_loop_guard_is_explicit_and_contains_the_guard_commit(self) -> None:
        for marker in (
            "[switch]$Phase6PreviewLoopGuard",
            "function Invoke-Phase6PreviewLoopGuardDeploy",
            "c24b7bfddc37cfa0c16d1ebc7f70829417ac4080",
            '& git merge-base --is-ancestor $loopGuardCommit $resolvedSource',
            "phase6 preview loop-guard source contains the cross-origin bounce-loop fix",
            "phase6 preview loop-guard Worker tree matches the source commit",
            'git archive --format=tar "--output=$workerArchive" $resolvedSource -- $relativeWorkerRoot',
            "phase6 preview loop-guard mode excludes production, LLM, and candidate activation arguments",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, self.wrapper)

        preview_guard_dispatch = self.wrapper.index("if ($Phase6PreviewLoopGuard)")
        production_dispatch = self.wrapper.index("if ($Phase6Production)")
        default_preview = self.wrapper.index('$workerDir = Join-Path $repoRoot "services/cloudflare-stateful-runtime"')
        self.assertLess(preview_guard_dispatch, production_dispatch)
        self.assertLess(preview_guard_dispatch, default_preview)

    def test_phase6_preview_loop_guard_resolves_existing_d1_without_provisioning(self) -> None:
        preview_guard = self.wrapper.split("function Invoke-Phase6PreviewLoopGuardDeploy", 1)[1].split(
            "function Invoke-Phase6ProductionDeploy", 1
        )[0]
        for marker in (
            "phase6 preview loop-guard Worker binding is exact and isolated",
            "cloud-superbrain-stateful-runtime-preview",
            "phase6 preview loop-guard D1 declaration is exact and isolated",
            "cloud-superbrain-state-preview",
            "phase6 preview loop-guard queue binding is exact and isolated",
            "cloud-superbrain-runtime-candidate-preview",
            "phase6 preview loop-guard Durable Object binding is exact",
            "phase6 preview loop-guard Vectorize binding is exact",
            "phase6 preview loop-guard Workers AI binding is exact",
            '"d1", "list"',
            '"--json"',
            "phase6 preview loop-guard D1 list output is bounded",
            "phase6 preview loop-guard resolves exactly one existing preview D1 database",
            "phase6 preview loop-guard existing D1 database ID is a UUID",
            '$previewDatabase | Add-Member -NotePropertyName "database_id"',
            "phase6 preview loop-guard repository wrangler config remains byte-identical",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, preview_guard)

        self.assertEqual(preview_guard.count('"d1", "list"'), 1)
        self.assertNotIn('"d1", "create"', preview_guard)
        self.assertNotIn("$repositoryConfigPath | Set-Content", preview_guard)

    def test_phase6_preview_loop_guard_deploy_is_non_mutating_and_control_plane_only(self) -> None:
        preview_guard = self.wrapper.split("function Invoke-Phase6PreviewLoopGuardDeploy", 1)[1].split(
            "function Invoke-Phase6ProductionDeploy", 1
        )[0]
        for marker in (
            '"--env", "preview"',
            '"--keep-vars"',
            '"--no-experimental-auto-create"',
            '"--var", "SOURCE_COMMIT_SHA:$resolvedSource"',
            '"--var", "SOURCE_ARCHIVE_SHA256:$archiveSha"',
            '"--var", "SOURCE_BUNDLE_SHA256:$sourceBundleSha"',
            '"--var", "HOSTED_MCP_WRITE_AUTHORIZED:false"',
            '"--var", "LIVE_MCP_WRITES_ENABLED:false"',
            '"deployments", "status"',
            "phase6 preview loop-guard latest deployment is the uploaded version at 100 percent",
            "phase6 preview loop-guard deployment and Worker version IDs are distinct",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, preview_guard)

        self.assertEqual(preview_guard.count('"deployments", "status"'), 1)
        self.assertNotIn("Invoke-WebRequest", preview_guard)
        self.assertNotIn("HttpClient", preview_guard)
        self.assertNotIn("SendAsync", preview_guard)
        self.assertNotIn("PRODUCTION_AUTH_", preview_guard)

    def test_phase6_preview_loop_guard_emits_exact_machine_result(self) -> None:
        preview_guard = self.wrapper.split("function Invoke-Phase6PreviewLoopGuardDeploy", 1)[1].split(
            "function Invoke-Phase6ProductionDeploy", 1
        )[0]
        for marker in (
            'contract_version = "cloudflare-phase6-preview-guard-deploy-result-v1"',
            "base_url = $previewBaseUrl",
            "verified_at_utc = [DateTimeOffset]::UtcNow",
            "worker_version_id = $workerVersionId",
            "deployment_id = $deploymentId",
            "control_plane_verified = $true",
            "worker_request_count = 0",
            "secret_output = $false",
            "Write-Output ($deployResult | ConvertTo-Json -Compress)",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, preview_guard)

        self.assertEqual(preview_guard.count("Write-Output"), 1)
        self.assertLess(preview_guard.index("Remove-TransientMaterialization"), preview_guard.index("Write-Output"))
        result_block = re.search(
            r"\$deployResult = \[ordered\]@\{(?P<body>.*?)\n\s*\}", preview_guard, re.DOTALL
        )
        self.assertIsNotNone(result_block)
        result_properties = re.findall(r"^\s{6}([a-z0-9_]+)\s*=", result_block.group("body"), re.MULTILINE)
        self.assertEqual(
            result_properties,
            [
                "contract_version",
                "base_url",
                "verified_at_utc",
                "source_commit_sha",
                "source_archive_sha256",
                "source_bundle_sha256",
                "worker_version_id",
                "deployment_id",
                "control_plane_verified",
                "worker_request_count",
                "secret_output",
            ],
        )


if __name__ == "__main__":
    unittest.main()
